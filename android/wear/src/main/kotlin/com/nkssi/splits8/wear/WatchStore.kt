package com.nkssi.splits8.wear

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LivePacket
import com.nkssi.splits8.shared.LiveState
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.SimTarget
import com.nkssi.splits8.shared.SplitsJson
import com.nkssi.splits8.shared.SyncKey
import com.nkssi.splits8.shared.WatchContext
import com.nkssi.splits8.shared.WatchWire
import com.nkssi.splits8.shared.newId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.time.Instant

/**
 * 워치 저장소 (아이폰 WatchStore.swift): 폰에서 받은 설정 · 트레이닝 · 친구, 워치에서 만든 Quick training,
 * 아직 폰에 도착이 확인되지 않은 기록(w_pending.json, 최근 20개).
 */
object WatchStore {
    private var dir: File? = null
    private var appContext: Context? = null
    /** 화면 사진 · 시험 (파일 · 폰 연결 없음) */
    var demo = false
        private set

    var ctx by mutableStateOf(WatchContext(Settings(), Program.presets()))
        private set
    var quickSaved by mutableStateOf<List<Program>>(emptyList())
        private set
    /** 폰 도착이 확인되지 않은 기록 */
    var pending by mutableStateOf<List<Record>>(emptyList())
        private set

    /** 운동 엔진 (앱 하나에 하나) */
    var engine = WorkoutEngine()

    /** 시험용: 실제 폰 대신 보낸 기록 · 실시간 상태를 여기로 */
    var testRecordSink: ((Record) -> Unit)? = null
    var testLiveSink: ((LiveState) -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    const val CTX_FILE = "w_ctx.json"
    const val QUICK_FILE = "w_quick.json"
    const val PENDING_FILE = "w_pending.json"

    val settings: Settings get() = ctx.settings

    fun init(context: Context) {
        if (dir != null) return
        appContext = context.applicationContext
        dir = context.filesDir
        ctx = load(CTX_FILE, WatchContext.serializer()) ?: WatchContext(Settings(), Program.presets())
        pending = load(PENDING_FILE, ListSerializer(Record.serializer())) ?: emptyList()
        // 워치에는 마지막 Quick 하나만 남김
        quickSaved = (load(QUICK_FILE, ListSerializer(Program.serializer())) ?: emptyList()).take(1)
        applyLang()
        wire(engine)
    }

    /** 엔진의 연결부를 저장소에 이어 줌 */
    fun wire(e: WorkoutEngine) {
        e.settings = settings
        e.onRecord = { send(it) }
        e.onLive = { st -> sendLive(st) }
    }

    /** 시험 · 화면 사진: 파일 없이 이 묶음으로 */
    fun useDemo(c: WatchContext, quick: List<Program> = emptyList()) {
        demo = true
        ctx = c; quickSaved = quick; pending = emptyList()
        applyLang()
        engine.settings = c.settings
    }

    /** 시험용: 빈 저장소로 다시 시작 */
    fun resetForTest(context: Context) {
        context.filesDir.listFiles()?.forEach { it.delete() }
        dir = null; demo = false
        engine = WorkoutEngine()
        init(context)
    }

    /** 시험용: 파일은 그대로 두고 다시 읽음 (앱을 껐다 켠 것처럼) */
    fun reloadForTest(context: Context) {
        dir = null; demo = false
        init(context)
    }

    /** 목록: 폰 트레이닝 목록이 원본. 워치에는 '방금 만든 Quick' 하나만 위에 붙음 */
    val programs: List<Program>
        get() {
            val ids = ctx.programs.map { it.id }.toSet()
            return quickSaved.filter { it.id !in ids } + ctx.programs
        }

    /** Quick training: 이번 운동에 쓰는 것. 폰 목록에는 안 쌓음, 워치에는 마지막 것 하나만 */
    fun saveQuick(seq: List<ProgItem>, now: Instant = Instant.now()): Program {
        val p = Program(id = "q" + newId().take(8), name = "Quick · " + Fm.dm(now), sets = 1, seq = seq, quick = true)
        quickSaved = listOf(p)
        save(QUICK_FILE, ListSerializer(Program.serializer()), quickSaved)
        return p
    }

    // MARK: 구간 목표

    /** Full Simulation 목표 16개와 비교 이름 (폰 Full Sim 화면의 "Compare with" 를 따름) */
    val simPick: Pair<List<Int>, String>
        get() = SimTarget.pick(settings.simCmp, settings.goals, ctx.simLast, ctx.friend?.splits, ctx.friend?.first, ctx.simBest)

    fun seq(mode: Mode, program: Program?): List<Seg> {
        val s = settings
        return when (mode) {
            Mode.Race -> SeqBuilder.full(s.div, s.roxAuto, if (s.goals.size == 16) s.goals else Defaults.goals, s.roxTarget)
            Mode.Sim -> SeqBuilder.full(s.div, s.roxAuto, simPick.first, s.roxTarget)
            Mode.Training -> SeqBuilder.training(program ?: Program.presets()[0], s.div, ctx.segBests)
            Mode.Pft -> PFT.seq(s.div, ctx.pftBest)
        }
    }

    // MARK: 폰에서 받기

    /** 폰이 보낸 묶음 (설정 · 트레이닝 · 비교 기준) */
    fun apply(json: String?) {
        val v = WatchWire.ctx(json) ?: return
        ctx = v
        applyLang()                    // 앱을 다시 켜지 않아도 번역이 바로 바뀜
        save(CTX_FILE, WatchContext.serializer(), v)
        // 운동 중에는 설정을 바꾸지 않음 (목표 · 구분이 운동 도중에 바뀌면 기록이 틀어짐)
        if (!engine.active) engine.settings = v.settings
        Tiles.refresh(appContext)
    }

    private fun applyLang() {
        L10n.lang = settings.lang ?: java.util.Locale.getDefault().language
    }

    /** 앱을 켤 때: 꺼져 있던 동안 폰이 보낸 묶음 받기 + 폰이 이미 받은 기록은 보관함에서 빼기 + 남은 것 다시 보내기 */
    fun start() {
        val c = appContext ?: return
        if (demo) return
        scope.launch {
            runCatching {
                val dc = Wearable.getDataClient(c)
                val buf = dc.getDataItems(Uri.parse("wear://*" + SyncKey.context)).await()
                val json = buf.firstOrNull()?.let { DataMapItem.fromDataItem(it).dataMap.getString(WatchWire.KEY) }
                buf.release()
                json?.let { apply(it) }
                // 보관함의 기록: DataItem 이 이미 없으면 폰이 받은 것 → 뺌, 아직 있으면 그대로 (연결되면 저절로 감)
                val items = dc.getDataItems(Uri.parse("wear://*" + SyncKey.record), DataClient.FILTER_PREFIX).await()
                val there = items.mapNotNull { it.uri.path }.filter { WatchWire.isRecordPath(it) }.map { WatchWire.recordId(it) }.toSet()
                items.release()
                val gone = pending.filter { it.id !in there }
                gone.forEach { delivered(it.id) }
            }
        }
    }

    // MARK: 폰으로 보내기

    /** 기록을 폰으로. 도착이 확인될 때까지 보관함에도 남겨 둠 (폰이 꺼져 있거나 멀어도 안 잃어버리게) */
    fun send(r: Record) {
        pending = (pending + r).takeLast(20)
        save(PENDING_FILE, ListSerializer(Record.serializer()), pending)
        testRecordSink?.let { it(r); return }
        val c = appContext ?: return
        if (demo) return
        scope.launch {
            runCatching {
                val req = PutDataMapRequest.create(WatchWire.recordPath(r.id)).apply { dataMap.putString(WatchWire.KEY, WatchWire.recordJson(r)) }
                    .asPutDataRequest().setUrgent()
                Wearable.getDataClient(c).putDataItem(req).await()
            }
        }
    }

    /** 폰이 기록을 받았음 (그 DataItem 이 지워짐) → 보관함에서 뺌 */
    fun delivered(id: String) {
        if (pending.none { it.id == id }) return
        pending = pending.filterNot { it.id == id }
        save(PENDING_FILE, ListSerializer(Record.serializer()), pending)
    }

    /** 운동 중 상태를 폰으로 (연결된 폰 모두에, 못 가면 그냥 버림 — 5초 뒤에 또 감) */
    private fun sendLive(st: LiveState) {
        testLiveSink?.let { it(st); return }
        val c = appContext ?: return
        if (demo) return
        val bytes = LivePacket(state = st).bytes()
        scope.launch {
            runCatching {
                val nodes = Wearable.getNodeClient(c).connectedNodes.await()
                for (n in nodes) Wearable.getMessageClient(c).sendMessage(n.id, SyncKey.live, bytes)
            }
        }
    }

    // MARK: 파일

    private fun <T> load(name: String, ser: KSerializer<T>): T? {
        val f = File(dir ?: return null, name)
        if (!f.exists()) return null
        return runCatching { SplitsJson.decodeFromString(ser, f.readText()) }.getOrNull()
    }

    private fun <T> save(name: String, ser: KSerializer<T>, v: T) {
        if (demo) return
        val d = dir ?: return
        val tmp = File(d, "$name.tmp")
        tmp.writeText(SplitsJson.encodeToString(ser, v))
        tmp.renameTo(File(d, name))
    }
}

/** 폰이 보낸 것을 받는 곳 (앱이 꺼져 있어도 시스템이 깨워서 부름) */
class WearSyncService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        WatchStore.init(applicationContext)
        val ctxJson = events.lastOrNull { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path == SyncKey.context }
            ?.let { DataMapItem.fromDataItem(it.dataItem).dataMap.getString(WatchWire.KEY) }
        // 폰이 기록 DataItem 을 지움 = 받았다는 확인
        val delivered = events.filter { it.type == DataEvent.TYPE_DELETED && WatchWire.isRecordPath(it.dataItem.uri.path) }
            .mapNotNull { it.dataItem.uri.path?.let { p -> WatchWire.recordId(p) } }
        events.release()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            ctxJson?.let { WatchStore.apply(it) }
            delivered.forEach { WatchStore.delivered(it) }
        }
    }

    /** 폰에서 누른 Next · Undo · Pause · Resume · End */
    override fun onMessageReceived(e: MessageEvent) {
        if (e.path != SyncKey.live) return
        val c = LivePacket.read(e.data)?.command ?: return
        WatchStore.init(applicationContext)
        android.os.Handler(android.os.Looper.getMainLooper()).post { WatchStore.engine.gotCommand(c) }
    }
}
