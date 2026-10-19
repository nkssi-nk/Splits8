package com.nkssi.splits8

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RoutePt
import com.nkssi.splits8.shared.RunMetrics
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.SimTarget
import com.nkssi.splits8.shared.newId
import java.time.Instant
import kotlin.math.max

/** 폰으로 기록 시작 요청 (트레이닝이면 프로그램, 끝나거나 취소하면 돌아갈 화면) */
@kotlinx.serialization.Serializable
data class PhoneRunRequest(val mode: Mode, val program: Program? = null, val from: Scr = Scr.Home)

/**
 * 진행 중인 폰 기록을 파일로 (앱이 완전히 꺼져도 다시 열면 이어서). 시간은 시계 기준이라 꺼져 있던 동안도 그대로 흐름
 */
@kotlinx.serialization.Serializable
data class PhoneRunSnapshot(
    val req: PhoneRunRequest, val savedAt: Long,
    val mode: Mode, val title: String, val sets: Int, val seq: List<Seg>, val idx: Int, val splits: List<Int>, val running: Boolean,
    val startMs: Long, val segStart: Long, val pauseAt: Long?, val segPaused: Long,
    val useGPS: Boolean, val segDist: Double, val segDists: List<Double?>,
    val division: String, val goalTime: Int, val simWord: String, val hasPFTBest: Boolean,
    val kind: String?, val runKm: Int, val place: String?, val route: List<RoutePt>,
    val steps: Double, val rawSteps: Double, val pausedSteps: Double, val pauseStepAt: Double, val segStepStart: Double,
    val segSteps: List<Double?>,
)

/**
 * 워치 없이 폰으로 기록 (아이폰 PhoneRunEngine 과 같은 규칙). 큰 Next 버튼으로 구간을 넘김. 심박 없음.
 * 시간은 시계(ms)로 계산하므로 화면이 잠깐 꺼졌다 와도 맞음. 위치 · 걸음은 화면(PhoneLiveView)이 받아서 넣어 줌.
 */
class PhoneRunEngine(private val clock: () -> Long = { System.currentTimeMillis() }) {
    var active by mutableStateOf(false); private set
    var finished by mutableStateOf(false); private set
    var mode by mutableStateOf(Mode.Sim); private set
    var title by mutableStateOf(""); private set
    var sets = 1; private set
    var seq by mutableStateOf<List<Seg>>(emptyList()); private set
    var idx by mutableIntStateOf(0); private set
    var splits by mutableStateOf<List<Int>>(emptyList()); private set
    var running by mutableStateOf(true); private set

    var startMs = 0L; private set
    private var segStart = 0L
    private var pauseAt: Long? = null
    private var segPaused = 0L

    // 야외 러닝 GPS 거리 (Settings.runMode == outdoor, 레이스 제외 — 워치와 같음)
    var useGPS by mutableStateOf(false); private set
    var segDist by mutableStateOf(0.0); private set
    private var segDists = ArrayList<Double?>()
    private var last: RoutePt? = null
    /** 빌드 27: GPS 로 잰 지금 속도(m/s, 부드럽게). 0 = 모름 (일시정지 · GPS 안 씀) */
    private var curSpeed = 0.0
    private var lastSpeedAt = Long.MIN_VALUE / 2

    /** 화면용 지금 속도: 10초 넘게 새 값이 없으면 0 (멈춰 섰는데 예전 페이스가 남지 않게) */
    fun speedNow(now: Long): Double {
        if (!useGPS || !running || curSpeed <= 0 || now - lastSpeedAt > 10_000) return 0.0
        return curSpeed
    }

    private var settings = Settings()
    /** 진행 상태가 바뀔 때 (파일에 저장) */
    var onChange: (() -> Unit)? = null
    /** 다시 열었을 때 이어 받은 걸음 (센서는 0 부터 다시 셈) */
    private var stepCarry = 0.0
    private var request: PhoneRunRequest? = null
    private var simWord = "VS BEST"
    private var hasPFTBest = false

    // HIIT · 러닝 카드
    var kind by mutableStateOf<String?>(null); private set
    private var runKm = 0
    val isHIIT: Boolean get() = kind == "hiit"
    val isRunKind: Boolean get() = kind == "run"
    /** GPS 로 잰 전체 거리(m) — 끝난 구간 + 지금 구간 */
    val totalDist: Double get() = segDists.filterNotNull().sum() + segDist
    /** 끝 없이 늘어나는 운동 (HIIT · 자유 러닝) */
    val growsOpen: Boolean get() = isHIIT || (isRunKind && runKm == 0)
    /** GPS 러닝이 총거리를 다 뛰어서 저절로 끝났을 때 (화면이 받아서 저장) */
    var autoDone by mutableStateOf<Record?>(null); private set
    /** 저절로 1 km 넘어간 횟수 (화면이 진동 · 반짝) */
    var autoSplits by mutableIntStateOf(0); private set
    var place: String? = null
    private var route = ArrayList<RoutePt>()
    private var lastRoute: RoutePt? = null

    // 러닝 카드 걸음 수 (케이던스용). 일시정지 중 걸음은 뺌
    private var steps = 0.0
    private var rawSteps = 0.0
    private var pausedSteps = 0.0
    private var pauseStepAt = 0.0
    private var segStepStart = 0.0
    private var segSteps = ArrayList<Double?>()

    // 잘못 넘김 되돌리기 (방금 넘긴 것 한 번만)
    private data class UndoPoint(val idx: Int, val segStart: Long, val segPaused: Long, val segDist: Double, val grew: Boolean, val segStepStart: Double)
    private var undoPoint: UndoPoint? = null
    var canUndo by mutableStateOf(false); private set

    // MARK: 값

    val cur: Seg get() = seq.getOrNull(idx) ?: seq.lastOrNull() ?: Seg("run", "Run", "1KM", SegKind.Run, 270)
    val hasNext: Boolean get() = idx + 1 < seq.size
    val next: Seg? get() = seq.getOrNull(idx + 1)

    fun segEl(now: Long = clock()): Int {
        val p = pauseAt?.let { now - it } ?: 0L
        return max(0L, (now - segStart - segPaused - p) / 1000).toInt()
    }
    fun doneT(): Int = splits.take(idx).sum()
    fun total(now: Long = clock()): Int = doneT() + segEl(now)

    /** Roxzone 을 뺀 구간 수 (4 / 16) */
    val countTotal: Int get() = seq.count { it.kind != SegKind.Rox }
    val countNow: Int get() = seq.take(idx + 1).count { it.kind != SegKind.Rox }

    /** 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km) */
    val nextSeg: Seg?
        get() {
            if (growsOpen && !hasNext) {
                val n = seq.size + 1
                return if (isHIIT) SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n)
            }
            return next
        }

    /** VS GOAL / VS LAST / VS JIHO / VS BEST (워치와 같음) */
    val deltaWord: String get() = when (mode) { Mode.Race -> "VS GOAL"; Mode.Sim -> simWord; else -> "VS BEST" }

    companion object {
        /** 구간 순서 (워치와 같은 규칙) */
        fun buildSeq(mode: Mode, program: Program?): List<Seg> {
            val s = Store.settings
            val book = Store.book
            return when (mode) {
                Mode.Race -> SeqBuilder.full(s.div, s.roxAuto, if (s.goals.size == 16) s.goals else com.nkssi.splits8.shared.Defaults.goals, s.roxTarget)
                Mode.Sim -> SeqBuilder.full(s.div, s.roxAuto, simPick().first, s.roxTarget)
                Mode.Pft -> PFT.seq(s.div, book.pftBest?.pftSplits)
                Mode.Training -> SeqBuilder.training(program ?: Program.presets()[0], s.div, book.segBests)
            }
        }

        /** Full Simulation 목표 16개와 비교 이름 (Full Sim 화면의 "Compare with" 를 따름) */
        fun simPick(): Pair<List<Int>, String> {
            val s = Store.settings
            val b = Store.book
            return SimTarget.pick(s.simCmp, s.goals, b.simLast?.splits16, Store.friend?.splits, Store.friend?.first, b.simBest?.splits16)
        }

        fun title(mode: Mode, program: Program?): String = when (mode) {
            Mode.Training -> (program ?: Program.presets()[0]).name
            Mode.Sim -> "Full Simulation"
            Mode.Pft -> PFT.title
            Mode.Race -> Store.settings.event.name.trim().ifEmpty { "Race" }
        }
    }

    // MARK: 시작

    fun start(req: PhoneRunRequest) {
        if (active) return
        request = req
        settings = Store.settings
        simWord = simPick().second
        hasPFTBest = Store.book.pftBest != null
        mode = req.mode
        title = title(req.mode, req.program)
        sets = if (req.mode == Mode.Training) max(1, (req.program ?: Program.presets()[0]).sets) else 1
        seq = buildSeq(req.mode, req.program)
        idx = 0; splits = emptyList(); running = true; finished = false
        segDists = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        segDist = 0.0; last = null
        curSpeed = 0.0; lastSpeedAt = Long.MIN_VALUE / 2
        segPaused = 0; pauseAt = null
        undoPoint = null; canUndo = false
        val now = clock()
        startMs = now; segStart = now
        active = true
        kind = if (req.mode == Mode.Training) req.program?.kind else null
        runKm = req.program?.runKm ?: 0
        autoDone = null; autoSplits = 0; place = null; route = ArrayList(); lastRoute = null
        segSteps = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        steps = 0.0; rawSteps = 0.0; pausedSteps = 0.0; pauseStepAt = 0.0; segStepStart = 0.0
        useGPS = if (isRunKind) !(req.program?.indoor ?: true) else req.mode != Mode.Race && settings.runMode == "outdoor"
        changed()
    }

    private fun changed() = onChange?.invoke()

    /** 지금 상태 (진행 중일 때만) */
    fun snapshot(): PhoneRunSnapshot? {
        val req = request ?: return null
        if (!active || finished) return null
        return PhoneRunSnapshot(req, clock(), mode, title, sets, seq, idx, splits, running, startMs, segStart, pauseAt, segPaused,
            useGPS, segDist, segDists.toList(), settings.division, settings.goalTime, simWord, hasPFTBest, kind, runKm, place, route.toList(),
            steps, rawSteps, pausedSteps, pauseStepAt, segStepStart, segSteps.toList())
    }

    /** 파일에서 이어 받기 (앱을 다시 열었을 때) */
    fun restore(x: PhoneRunSnapshot) {
        request = x.req
        settings = Store.settings.copy(division = x.division, goalTime = x.goalTime)
        mode = x.mode; title = x.title; sets = x.sets; seq = x.seq; idx = x.idx; splits = x.splits; running = x.running
        startMs = x.startMs; segStart = x.segStart; pauseAt = x.pauseAt; segPaused = x.segPaused
        useGPS = x.useGPS; segDist = x.segDist; segDists = ArrayList(x.segDists); last = null
        simWord = x.simWord; hasPFTBest = x.hasPFTBest; kind = x.kind; runKm = x.runKm; place = x.place
        route = ArrayList(x.route); lastRoute = x.route.lastOrNull()
        steps = x.steps; rawSteps = x.rawSteps; pausedSteps = x.pausedSteps; pauseStepAt = x.pauseStepAt; segStepStart = x.segStepStart
        segSteps = ArrayList(x.segSteps); stepCarry = x.rawSteps
        undoPoint = null; canUndo = false; autoDone = null; autoSplits = 0
        finished = false; active = true
    }

    /** HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임 */
    private fun growSeq() {
        val n = seq.size + 1
        seq = seq + (if (isHIIT) SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n))
        segDists.add(null)
        segSteps.add(null)
    }

    // MARK: 진행

    /** 다음 구간. 마지막 구간이면 끝내고 기록을 돌려줌 */
    fun advance(): Record? {
        if (!active || finished || !running) return null
        if (isRunKind && useGPS) return null            // GPS 러닝은 1km마다 저절로 넘어감
        val now = clock()
        val up = UndoPoint(idx, segStart, segPaused, segDist, growsOpen && splits.size + 1 >= seq.size, segStepStart)
        closeSeg(now)
        if (growsOpen && splits.size >= seq.size) growSeq()
        if (splits.size >= seq.size) return finish(true)
        undoPoint = up
        canUndo = true
        idx = splits.size
        segStart = now; segPaused = 0
        segDist = 0.0
        segStepStart = steps
        changed()
        return null
    }

    /** 잘못 넘겼을 때: 방금 넘긴 것을 한 번 되돌림 (앞 구간 시간이 끊기지 않고 이어짐) */
    fun undo() {
        val u = undoPoint
        if (!active || finished || !canUndo || u == null) return
        if (idx != u.idx + 1 || splits.size != u.idx + 1) { undoPoint = null; canUndo = false; return }
        val newIdx = idx
        splits = splits.dropLast(1)
        if (u.idx < segDists.size) segDists[u.idx] = null
        if (u.idx < segSteps.size) segSteps[u.idx] = null
        if (u.grew && seq.size == newIdx + 1) {
            seq = seq.dropLast(1)
            if (segDists.size > seq.size) segDists.removeAt(segDists.size - 1)
            if (segSteps.size > seq.size) segSteps.removeAt(segSteps.size - 1)
        }
        idx = u.idx
        segStart = u.segStart
        segPaused = u.segPaused + segPaused
        segDist = u.segDist + segDist
        segStepStart = u.segStepStart
        undoPoint = null
        canUndo = false
        changed()
    }

    fun togglePause() {
        if (!active || finished) return
        if (running) {
            pauseAt = clock(); running = false
            curSpeed = 0.0                                  // 빌드 27: 멈추면 속도 모름
            pauseStepAt = rawSteps
        } else {
            pauseAt?.let { segPaused += clock() - it }
            pauseAt = null; running = true
            last = null
            // 일시정지 동안 걸은 걸음은 케이던스에서 뺌
            pausedSteps += max(0.0, rawSteps - pauseStepAt)
            steps = max(0.0, rawSteps - pausedSteps)
        }
        changed()
    }

    /** End → Save: 현재 구간까지 기록하고 끝냄 */
    fun endNow(): Record? {
        if (!active || finished) return null
        if (!running) togglePause()
        closeSeg(clock())
        return finish(growsOpen || splits.size >= seq.size)
    }

    /** End → Discard */
    fun discard() {
        active = false; finished = true
        changed()
    }

    private fun closeSeg(now: Long) {
        splits = splits + segEl(now)
        if (useGPS && cur.kind == SegKind.Run && idx < segDists.size && segDist > 0) segDists[idx] = segDist
        // 이 구간 걸음 수 (러닝 카드)
        if (isRunKind && cur.kind == SegKind.Run && steps > segStepStart && idx < segSteps.size) segSteps[idx] = steps - segStepStart
    }

    private fun finish(complete: Boolean): Record {
        undoPoint = null; canUndo = false
        finished = true
        changed()
        return makeRecord(complete)
    }

    /** 워치 기록과 같은 모양 (심박 · 칼로리 없음) */
    private fun makeRecord(complete: Boolean): Record {
        val results = splits.mapIndexedNotNull { i, t ->
            val s = seq.getOrNull(i) ?: return@mapIndexedNotNull null
            SegResult(s.icon, s.name, s.detail, s.kind, t, s.target, hr = null, dist = segDists.getOrNull(i))
        }
        val total = splits.sum()
        val tg = seq.take(splits.size).sumOf { it.target }
        val start = Instant.ofEpochMilli(startMs)
        var r = Record(
            newId(), mode, title, sets, start, total, results, emptyList(), 0, 0, 0, settings.div.name,
            goal = if (mode == Mode.Race) settings.goalTime else null,
            vsWord = deltaWord, vsTarget = if (kind == null && (mode != Mode.Pft || hasPFTBest)) tg else null,
            complete = complete, endDate = start.plusSeconds(total.toLong()), place = place, kind = kind,
            route = if (isRunKind && useGPS && route.size >= 2) route.toList() else null,
            indoor = if (isRunKind && !useGPS) true else null,         // 94번
        )
        // 러닝 카드 — 케이던스 · 보폭(GPS 거리 ÷ 걸음) · 오르막 (경로 높이로)
        if (isRunKind) r = RunMetrics.fill(r, segSteps, null)
        return r
    }

    // MARK: 걸음 수 · 위치 (화면이 센서에서 받아 넣음)

    /** 운동 시작부터 걸음 수 */
    fun gotSteps(n: Double) {
        if (!active || finished) return
        rawSteps = n + stepCarry
        if (running) steps = max(0.0, rawSteps - pausedSteps)
    }

    /**
     * 위치 한 번. acc = 수평 정확도(m), vAcc = 높이 정확도(m, 없으면 null).
     * 30 m 보다 부정확하면 버림, 한 번에 100 m 넘게 튀면 거리에 넣지 않음
     */
    fun gotLocation(lat: Double, lon: Double, acc: Float, alt: Double?, vAcc: Float?, atMs: Long = clock(), speed: Float? = null) {
        if (!active || finished) return
        if (acc <= 0f || acc > 30f) return
        val p = RoutePt(lat, lon, if (vAcc != null && vAcc > 0f) alt else null, total(atMs))
        if (!running || cur.kind != SegKind.Run) { last = null; return }
        // 빌드 27: 실시간 속도 — 위치의 속도값 (정확도 20 m 미만만), 지수 이동 평균 alpha 0.3
        if (speed != null && speed >= 0f && acc < 20f) {
            val fresh = curSpeed <= 0 || atMs - lastSpeedAt > 10_000
            curSpeed = if (fresh) speed.toDouble() else 0.3 * speed + 0.7 * curSpeed
            lastSpeedAt = atMs
        }
        last?.let { prev ->
            val d = RunMetrics.meters(prev, p)
            if (d < 100) segDist += d
        }
        last = p
        if (isRunKind) {
            val lr = lastRoute
            if (lr == null || RunMetrics.meters(lr, p) >= 8) {
                lastRoute = p
                route.add(p)
            }
            autoSplitIfNeeded()
        }
    }

    /** GPS 러닝: 1km 넘으면 저절로 다음 km (총거리 다 뛰면 끝 → autoDone) */
    private fun autoSplitIfNeeded() {
        if (!isRunKind || !useGPS || !active || finished || !running || segDist < 1000) return
        val now = clock()
        undoPoint = null; canUndo = false
        closeSeg(now)
        if (runKm == 0 && splits.size >= seq.size) growSeq()
        if (splits.size >= seq.size) { autoDone = finish(true); return }
        idx = splits.size
        segStart = now; segPaused = 0
        segDist = 0.0
        segStepStart = steps
        autoSplits++
        changed()
    }
}
