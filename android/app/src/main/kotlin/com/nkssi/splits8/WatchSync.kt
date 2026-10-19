package com.nkssi.splits8

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SyncKey
import com.nkssi.splits8.shared.WatchWire
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * 폰 쪽 워치 연결 (아이폰 Store 의 WCSession 부분).
 * - 설정 · 트레이닝 · 기록이 바뀌면 워치로 묶음(/ctx)을 보냄 (0.4초 모아서 한 번)
 * - 워치가 보낸 기록(/record/<id>)을 받아 저장 + Health Connect + 끝 카드, 그다음 그 DataItem 을 지워 "받음" 확인
 */
object WatchSync {
    /** 워치 상태 (설정 › Device 줄) */
    enum class State { Unknown, NoWatch, NoApp, Ready }

    var state by mutableStateOf(State.Unknown)
        private set

    /** 워치 앱이 알리는 능력 이름 (wear/res/values/wear.xml 과 같아야 함) */
    const val CAPABILITY = "splits8_wear"

    /** 시험용: 실제 워치 대신 보낸 묶음을 여기로 */
    var testSink: ((String) -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val main = Handler(Looper.getMainLooper())
    private val pushNow = Runnable { push() }
    @Volatile private var lastSent: String? = null

    private val context: Context? get() = Reminders.context

    /** Store 가 바뀔 때마다 부름 — 짧은 시간 안의 여러 변경은 한 번으로 */
    fun dirty() {
        if (Store.demo && testSink == null) return
        main.removeCallbacks(pushNow)
        main.postDelayed(pushNow, 400)
    }

    /** 지금 묶음을 워치로 (같은 내용이면 다시 안 보냄) */
    fun push(force: Boolean = false) {
        main.removeCallbacks(pushNow)
        val json = WatchWire.ctxJson(WatchWire.context(Store.settings, Store.programs, Store.friend, Store.book))
        if (!force && json == lastSent) return
        testSink?.let { it(json); lastSent = json; return }
        val ctx = context ?: return
        scope.launch {
            runCatching {
                val req = PutDataMapRequest.create(SyncKey.context).apply { dataMap.putString(WatchWire.KEY, json) }
                    .asPutDataRequest().setUrgent()
                Wearable.getDataClient(ctx).putDataItem(req).await()
                lastSent = json
            }
        }
    }

    /** 워치가 연결돼 있고 워치 앱이 깔려 있는지 */
    fun refreshState() {
        val ctx = context ?: return
        if (Store.demo) return
        scope.launch {
            state = runCatching {
                val nodes = Wearable.getNodeClient(ctx).connectedNodes.await()
                if (nodes.isEmpty()) return@runCatching State.NoWatch
                val cap = Wearable.getCapabilityClient(ctx)
                    .getCapability(CAPABILITY, com.google.android.gms.wearable.CapabilityClient.FILTER_REACHABLE).await()
                if (cap.nodes.isEmpty()) State.NoApp else State.Ready
            }.getOrDefault(State.NoWatch)
            // 워치가 다시 보이면 최신 묶음을 한 번 더 (지난번에 못 갔을 수 있음)
            if (state == State.Ready) push(force = true)
        }
    }

    /**
     * 워치에서 온 기록 하나. 새 기록이면 저장 · Health Connect · 끝 카드.
     * 이미 있는 기록이어도 true (DataItem 을 지워 확인해 줘야 워치 보관함에서 빠짐). 글자가 깨졌으면 false.
     */
    fun receiveRecord(json: String?, nowMs: Long = System.currentTimeMillis()): Boolean {
        val r: Record = WatchWire.record(json) ?: return false
        val fresh = Store.records.none { it.id.equals(r.id, ignoreCase = true) }
        Store.add(r)
        if (!fresh) return true
        Health.save(r)
        // 방금 끝난 운동만 카드 (오래 전 기록이 늦게 도착한 것은 조용히 저장만)
        val ageMin = (nowMs - r.end.toEpochMilli()) / 60_000
        if (ageMin in -5..30) main.post { Router.showFinish(r, Router.scr.takeIf { it != Scr.WatchLive } ?: Scr.Home) }
        WatchMirror.recordArrived(r)
        return true
    }

    /**
     * 98번(빌드 28): 워치에서 끝낸 횟수 보정 결과 → 설정에 저장 (설정이 바뀌면 워치로 다시 내려감).
     * 글자가 깨졌어도 true (DataItem 을 지워야 다시 안 옴)
     */
    fun receiveCalib(json: String?): Boolean {
        val c = WatchWire.calib(json) ?: return true
        Store.update { s -> s.copy(repCal = (s.repCal ?: emptyMap()) + (c.icon to c.tune)) }
        return true
    }

    /**
     * 98번: 워치 앱을 켜서 그 종목 보정 화면으로 (아이폰 startWatchApp + sendMessage 와 같은 역할).
     * 워치 앱 열기(RemoteActivityHelper) + 이미 켜져 있으면 메시지로도 알림
     */
    fun startCalibration(icon: String) {
        val ctx = context ?: return
        if (Store.demo) return
        scope.launch {
            runCatching {
                val nodes = Wearable.getNodeClient(ctx).connectedNodes.await()
                val helper = androidx.wear.remote.interactions.RemoteActivityHelper(ctx)
                for (n in nodes) {
                    runCatching {
                        val i = android.content.Intent(android.content.Intent.ACTION_VIEW)
                            .addCategory(android.content.Intent.CATEGORY_BROWSABLE)
                            .setData(Uri.parse("splits8://calib?icon=$icon"))
                        val f = helper.startRemoteActivity(i, n.id)
                        kotlinx.coroutines.withContext(Dispatchers.IO) { f.get(10, java.util.concurrent.TimeUnit.SECONDS) }
                    }
                    runCatching { Wearable.getMessageClient(ctx).sendMessage(n.id, SyncKey.calib, icon.toByteArray(Charsets.UTF_8)).await() }
                }
            }
        }
    }

    /** 받은 기록의 DataItem 지우기 = 워치에 "받았어요" */
    fun ack(uri: Uri) {
        val ctx = context ?: return
        scope.launch { runCatching { Wearable.getDataClient(ctx).deleteDataItems(uri).await() } }
    }

    /** 앱을 켤 때: 앱이 꺼져 있던 동안 쌓인 기록 받기 + 상태 확인 + 묶음 보내기 */
    fun start() {
        val ctx = context ?: return
        if (Store.demo) return
        refreshState()
        push(force = true)
        scope.launch {
            runCatching {
                val buf = Wearable.getDataClient(ctx).getDataItems(Uri.parse("wear://*" + SyncKey.record), com.google.android.gms.wearable.DataClient.FILTER_PREFIX).await()
                val items = buf.map { DataMapItem.fromDataItem(it).dataMap.getString(WatchWire.KEY) to it.uri }
                buf.release()
                for ((json, uri) in items) if (receiveRecord(json)) ack(uri)
                // 98번: 앱이 꺼져 있던 동안 온 보정 결과
                val cb = Wearable.getDataClient(ctx).getDataItems(Uri.parse("wear://*" + SyncKey.calibDone), com.google.android.gms.wearable.DataClient.FILTER_PREFIX).await()
                val cs = cb.map { DataMapItem.fromDataItem(it).dataMap.getString(WatchWire.KEY) to it.uri }
                cb.release()
                for ((json, uri) in cs) if (receiveCalib(json)) ack(uri)
            }
        }
    }
}

/** 워치가 보낸 것을 받는 곳 (앱이 꺼져 있어도 시스템이 깨워서 부름) */
class PhoneWearService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        Store.init(applicationContext)
        val got = events.filter { it.type == DataEvent.TYPE_CHANGED && WatchWire.isRecordPath(it.dataItem.uri.path) }
            .map { DataMapItem.fromDataItem(it.dataItem).dataMap.getString(WatchWire.KEY) to it.dataItem.uri }
        val cal = events.filter { it.type == DataEvent.TYPE_CHANGED && WatchWire.isCalibPath(it.dataItem.uri.path) }
            .map { DataMapItem.fromDataItem(it.dataItem).dataMap.getString(WatchWire.KEY) to it.dataItem.uri }
        events.release()
        // 저장 · 화면은 메인 스레드에서
        Handler(Looper.getMainLooper()).post {
            for ((json, uri) in got) if (WatchSync.receiveRecord(json)) WatchSync.ack(uri)
            for ((json, uri) in cal) if (WatchSync.receiveCalib(json)) WatchSync.ack(uri)
        }
    }

    override fun onMessageReceived(e: MessageEvent) {
        if (e.path != SyncKey.live) return
        Store.init(applicationContext)
        val data = e.data
        val from = e.sourceNodeId
        Handler(Looper.getMainLooper()).post { WatchMirror.received(data, from) }
    }

    override fun onCapabilityChanged(info: com.google.android.gms.wearable.CapabilityInfo) {
        Store.init(applicationContext)
        Handler(Looper.getMainLooper()).post { WatchSync.refreshState() }
    }
}
