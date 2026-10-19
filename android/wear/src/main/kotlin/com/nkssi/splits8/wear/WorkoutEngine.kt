package com.nkssi.splits8.wear

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nkssi.splits8.shared.HRPoint
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.LiveState
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
import com.nkssi.splits8.shared.newId
import java.time.Instant
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// 워치 운동 진행 (아이폰 WatchApp/WorkoutEngine.swift 를 그대로 옮김).
// 시간은 시계(ms)로 계산 → 화면이 꺼졌다 와도, 앱 화면이 없어도 맞음. 1초마다 tick() 은 운동 서비스가 부름.
// 측정(Health Services) · 진동 · 횟수 세기 · 폰으로 보내기는 아래 작은 연결부를 통해서만 → 시험에서는 가짜로 바꿔 끼움.

/** 진동 종류 (아이폰 WKHapticType 자리. 실제 워치로 느껴 본 뒤 Buzz.kt 의 패턴만 고치면 됨) */
enum class BuzzKind { Tick, Go, Start, Next, Undo, ZoneUp, ZoneDown, Over, Success, Click, Failure }

/** 운동 측정 설정 */
data class ExerciseCfg(
    /** HIIT 면 HIIT, 나머지는 러닝 (아이폰과 같음) */
    val hiit: Boolean,
    /** 실외(GPS) */
    val gps: Boolean,
    /** 러닝 카드: 걸음 수 (케이던스) */
    val steps: Boolean,
)

/** 측정값이 들어오는 곳 */
interface SensorSink {
    fun gotHR(bpm: Double, atMs: Long)
    fun gotEnergy(kcalTotal: Double)
    fun gotDistance(metersTotal: Double)
    fun gotSteps(total: Double)
    fun gotLocation(lat: Double, lon: Double, acc: Float, alt: Double?, vAcc: Float?, atMs: Long)
    fun gotPlace(name: String)
    /** 빌드 27: 지금 러닝 속도(m/s) — 실시간 페이스 */
    fun gotSpeed(mps: Double) {}
}

/** 운동 측정 (실제: Health Services ExerciseClient) */
interface WorkoutSensors {
    fun start(cfg: ExerciseCfg, sink: SensorSink)
    fun pause()
    fun resume()
    /** 끝 (save = false 면 버림) */
    fun end(save: Boolean)
}

/** 횟수 세기 (스키 · 로잉 · 월볼, 참고용) */
interface RepSource {
    fun start(icon: String, base: Int = 0)
    fun setPaused(p: Boolean)
    /** 멈추고 센 횟수 (세지 않는 종목이면 null) */
    fun stop(): Int?
}

/** 아무것도 안 하는 것 (시험 · 화면 사진) */
object NoSensors : WorkoutSensors {
    override fun start(cfg: ExerciseCfg, sink: SensorSink) {}
    override fun pause() {}
    override fun resume() {}
    override fun end(save: Boolean) {}
}

object NoReps : RepSource {
    override fun start(icon: String, base: Int) {}
    override fun setPaused(p: Boolean) {}
    override fun stop(): Int? = null
}

class WorkoutEngine(
    private val clock: () -> Long = { System.currentTimeMillis() },
) : SensorSink {
    var sensors: WorkoutSensors = NoSensors
    var reps: RepSource = NoReps
    var buzz: (BuzzKind) -> Unit = {}
    /** 끝난 기록 → 폰으로 (WatchStore.send) */
    var onRecord: (Record) -> Unit = {}
    /** 폰에 같이 보여 주기 (설정 › Show on phone). null 이면 안 보냄 */
    var onLive: ((LiveState) -> Unit)? = null
    /** 운동이 시작 · 끝날 때 (운동 서비스 켜고 끄기) */
    var onActive: (Boolean) -> Unit = {}

    var settings = Settings()

    // HIIT · 러닝 카드 (null = 하이록스 운동)
    var kind by mutableStateOf<String?>(null); private set
    private var runKm = 0
    private var hasPFTBest = false
    private var simWordAtStart: String? = null
    var outdoorRun = false; private set
    val isHIIT: Boolean get() = kind == "hiit"
    val isRunKind: Boolean get() = kind == "run"
    /** 끝 없이 늘어나는 운동 (HIIT · 자유 러닝) */
    val growsOpen: Boolean get() = isHIIT || (isRunKind && runKm == 0)

    private var place: String? = null
    private var routePts = ArrayList<RoutePt>()
    private var lastRoute: RoutePt? = null

    var active by mutableStateOf(false); private set
    var finished by mutableStateOf(false); private set
    var mode by mutableStateOf(Mode.Race); private set
    var title by mutableStateOf(""); private set
    var sets = 1; private set
    var seq by mutableStateOf<List<Seg>>(emptyList()); private set
    var idx by mutableIntStateOf(0); private set
    var splits by mutableStateOf<List<Int>>(emptyList()); private set
    var running by mutableStateOf(true); private set
    var lastRecord by mutableStateOf<Record?>(null); private set
    /** 구간이 넘어갈 때마다 +1 (밀기 · Next 모두 advance() 하나로 모임) → 화면 노랑 반짝 */
    var advanceCount by mutableIntStateOf(0); private set

    // 측정값
    var hr by mutableDoubleStateOf(0.0); private set
    var kcal by mutableDoubleStateOf(0.0); private set
    /** 누적 거리 m */
    var distance by mutableDoubleStateOf(0.0); private set
    private var hrSamples = ArrayList<HRPoint>()
    private var segHR = ArrayList<ArrayList<Double>>()
    private var segDistStart = 0.0
    private var segDists = ArrayList<Double?>()
    private var steps = 0.0
    private var segStepStart = 0.0
    private var segSteps = ArrayList<Double?>()
    // 빌드 27: 실시간 속도 (애플 운동 앱처럼 "지금" 페이스)
    /** 지금 속도(m/s). 0 = 모름 (일시정지 · 10초 넘게 새 값 없음) */
    var curSpeed by mutableDoubleStateOf(0.0); private set
    /** 마지막으로 속도를 받은 때 (오래되면 0 으로) */
    private var lastSpeedAt = Long.MIN_VALUE / 2

    // 시간 (일시정지 제외)
    var startMs = 0L; private set
    private var segStart = 0L
    private var pauseAt: Long? = null
    private var segPaused = 0L

    // 시작 전 3 · 2 · 1 (null = 세는 중 아님)
    var countdown by mutableStateOf<Int?>(null); private set
    private var pendingStart: (() -> Unit)? = null

    // 잘못 넘김 되돌리기 (방금 넘긴 것 한 번만)
    private data class UndoPoint(
        val idx: Int, val segStart: Long, val segPaused: Long, val segDistStart: Double,
        val grew: Boolean, val reps: Int?, val segStepStart: Double,
    )
    private var undoPoint: UndoPoint? = null
    var canUndo by mutableStateOf(false); private set

    private var segReps = ArrayList<Int?>()

    // 진동 알림 (설정: hapticZone / hapticPace)
    private var lastZone = 0
    private var lastZoneBuzz = Long.MIN_VALUE / 2
    private val paceBuzzed = HashSet<Int>()
    private var liveTicks = 0

    // MARK: 값

    /** 지금 시각 (화면도 이 시계로 — 화면 사진은 고정 시계) */
    fun now(): Long = clock()

    val cur: Seg get() = seq.getOrNull(idx) ?: seq.lastOrNull() ?: Seg("run", "Run", "1KM", SegKind.Run, 270)
    val next: Seg get() = seq.getOrNull(idx + 1) ?: cur

    fun segEl(now: Long = clock()): Int {
        val p = pauseAt?.let { now - it } ?: 0L
        return max(0L, (now - segStart - segPaused - p) / 1000).toInt()
    }
    fun doneT(): Int = splits.take(idx).sum()
    fun total(now: Long = clock()): Int = doneT() + segEl(now)

    /** 목표 대비: 끝낸 구간 합 − 목표 합 + 현재 구간 초과분 */
    fun delta(now: Long = clock()): Int {
        val tg = seq.take(idx).sumOf { it.target }
        val over = max(0, segEl(now) - cur.target)
        return doneT() - tg + over
    }

    val zone: Int get() = settings.zone(hr)

    /** 현재 러닝 구간 거리(m) */
    val segDist: Double get() = max(0.0, distance - segDistStart)

    /**
     * 빌드 27: 워치 화면의 PACE 글자 (1 km 당, imperial 이면 1 mi 당).
     * "5:12" = 지금 속도로 계산 (모르면 이 구간 평균) · null = 측정 중 ("Measuring") · "–:––" = 계산할 수 없음
     */
    fun paceText(el: Int, dist: Double, imperial: Boolean = false): String? =
        when (val r = LivePace.reading(el, dist, imperial, curSpeed)) {
            is LivePace.Reading.Pace -> LivePace.fmt(r.sec)
            LivePace.Reading.Measuring -> null
            LivePace.Reading.Unknown -> "–:––"
        }

    /** 속도 하나 받음: 부드럽게 (지수 이동 평균 0.3). 처음 값 · 10초 넘게 끊긴 뒤 값은 그대로 */
    private fun blendSpeed(v: Double, now: Long) {
        if (v < 0 || !v.isFinite()) return
        val fresh = curSpeed <= 0 || now - lastSpeedAt > 10_000
        curSpeed = if (fresh) v else 0.3 * v + 0.7 * curSpeed
        lastSpeedAt = now
    }

    /** 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km) */
    val nextSeg: Seg
        get() {
            if (growsOpen && idx >= seq.size - 1) {
                val n = seq.size + 1
                return if (isHIIT) SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n)
            }
            return next
        }

    val isLast: Boolean get() = idx >= seq.size - 1 && !growsOpen

    /** 실내 러닝인데 워치 거리값이 없으면 손으로 넘김, 그 밖의 러닝은 1km마다 저절로 */
    val autoSplit: Boolean get() = isRunKind && !(distance <= 0 && !outdoorRun)

    /** VS GOAL / VS LAST / VS JIHO / VS BEST (기록에 남는 비교 이름) */
    val deltaWord: String
        get() = when (mode) {
            Mode.Race -> "VS GOAL"
            Mode.Sim -> simWordAtStart ?: "VS BEST"
            else -> "VS BEST"
        }

    // MARK: 시작 전 3 · 2 · 1

    /** 3 · 2 · 1 을 센 뒤 시작. 숫자마다 짧은 진동, 시작 순간은 길게. countTick() 은 1초마다 (WearApp 이 부름) */
    fun startAfterCountdown(mode: Mode, title: String, sets: Int = 1, seq: List<Seg>, program: Program? = null, simWord: String? = null) {
        if (active || countdown != null) return
        pendingStart = { start(mode, title, sets, seq, program, simWord, buzzStart = false) }
        countdown = COUNT_FROM
        buzz(BuzzKind.Tick)
    }

    fun countTick() {
        val c = countdown ?: return
        if (c > 1) {
            countdown = c - 1
            buzz(BuzzKind.Tick)
        } else {
            countdown = null
            val go = pendingStart
            pendingStart = null
            go?.invoke()
            buzz(BuzzKind.Go)
        }
    }

    /** 세는 중에 취소 (화면을 누르면) */
    fun cancelCountdown() {
        countdown = null
        pendingStart = null
    }

    // MARK: 시작

    fun start(mode: Mode, title: String, sets: Int = 1, seq: List<Seg>, program: Program? = null, simWord: String? = null, buzzStart: Boolean = true) {
        if (active) return
        kind = if (mode == Mode.Training) program?.kind else null
        runKm = program?.runKm ?: 0
        outdoorRun = isRunKind && !(program?.indoor ?: true)
        hasPFTBest = mode == Mode.Pft && pftBestCount == PFT.items.size
        place = null; routePts = ArrayList(); lastRoute = null
        simWordAtStart = if (mode == Mode.Sim) simWord else null
        this.mode = mode
        this.title = title
        this.sets = sets
        this.seq = seq
        idx = 0; splits = emptyList(); running = true; finished = false; lastRecord = null
        hr = 0.0; kcal = 0.0; distance = 0.0; hrSamples = ArrayList()
        segHR = ArrayList<ArrayList<Double>>().apply { repeat(seq.size) { add(ArrayList()) } }
        segDists = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        segReps = ArrayList<Int?>().apply { repeat(seq.size) { add(null) } }
        segSteps = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        steps = 0.0; segStepStart = 0.0
        curSpeed = 0.0; lastSpeedAt = Long.MIN_VALUE / 2
        segDistStart = 0.0; segPaused = 0; pauseAt = null
        undoPoint = null; canUndo = false
        val now = clock()
        startMs = now; segStart = now
        lastZone = 0; lastZoneBuzz = Long.MIN_VALUE / 2; paceBuzzed.clear(); liveTicks = 0
        active = true
        reps.start(cur.icon)
        // 레이스는 늘 실내(GPS 안 씀) — 아이폰과 같음. 하이록스 운동의 야외 러닝은 설정의 러닝 방식이 outdoor 일 때만
        val gps = if (isRunKind) outdoorRun else (mode != Mode.Race && settings.runMode == "outdoor" && !isHIIT)
        sensors.start(ExerciseCfg(hiit = isHIIT, gps = gps, steps = isRunKind), this)
        onActive(true)
        if (buzzStart) buzz(BuzzKind.Start)
        pushLive()
    }

    /** 시작할 때 PFT 최고 기록 구간 수 (WatchStore 가 넣어 줌) */
    var pftBestCount = 0

    // MARK: 진행

    /** 다음 구간 (왼쪽으로 밀기 · NEXT · 폰의 Next) */
    fun advance() {
        if (!active || finished || !running) return
        if (isRunKind && autoSplit) return            // 러닝은 1km마다 저절로 넘어감
        val now = clock()
        val prevIdx = idx
        val prevStart = segStart
        val prevPaused = segPaused
        val prevDistStart = segDistStart
        val prevStepStart = segStepStart
        closeSeg(now)
        var grew = false
        if (splits.size >= seq.size && growsOpen) {
            growSeq()
            grew = true
        }
        if (splits.size >= seq.size) {
            finish(now, complete = true)
        } else {
            undoPoint = UndoPoint(prevIdx, prevStart, prevPaused, prevDistStart, grew, segReps.getOrNull(prevIdx), prevStepStart)
            canUndo = !isRunKind
            idx = splits.size
            segStart = now; segPaused = 0
            segDistStart = distance
            segStepStart = steps
            advanceCount++
            reps.start(cur.icon)
            buzz(BuzzKind.Next)
            pushLive()
        }
    }

    /** 잘못 넘겼을 때: 방금 넘긴 것을 한 번 되돌림 (앞 구간 시간이 끊기지 않고 이어짐) */
    fun undo() {
        val u = undoPoint
        if (!active || finished || !canUndo || u == null) return
        if (idx != u.idx + 1 || splits.size != u.idx + 1) { undoPoint = null; canUndo = false; return }
        val newIdx = idx
        splits = splits.dropLast(1)
        if (newIdx < segHR.size && u.idx < segHR.size) {
            segHR[u.idx].addAll(segHR[newIdx])
            segHR[newIdx] = ArrayList()
        }
        if (u.idx < segDists.size) segDists[u.idx] = null
        if (u.idx < segReps.size) segReps[u.idx] = null
        if (u.idx < segSteps.size) segSteps[u.idx] = null
        if (u.grew && seq.size == newIdx + 1) {          // HIIT · 자유 러닝에서 붙였던 다음 라운드를 뗌
            seq = seq.dropLast(1)
            if (segHR.size > seq.size) segHR.removeAt(segHR.size - 1)
            if (segDists.size > seq.size) segDists.removeAt(segDists.size - 1)
            if (segReps.size > seq.size) segReps.removeAt(segReps.size - 1)
            if (segSteps.size > seq.size) segSteps.removeAt(segSteps.size - 1)
        }
        idx = u.idx
        segStart = u.segStart
        segPaused = u.segPaused + segPaused        // 넘긴 뒤에 일시정지한 시간도 빼 줌
        segDistStart = u.segDistStart
        segStepStart = u.segStepStart
        paceBuzzed.remove(newIdx)
        undoPoint = null
        canUndo = false
        reps.start(cur.icon, u.reps ?: 0)
        if (!running) reps.setPaused(true)
        buzz(BuzzKind.Undo)
        pushLive()
    }

    /** HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임 */
    private fun growSeq() {
        val n = seq.size + 1
        seq = seq + (if (isHIIT) SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n))
        segHR.add(ArrayList()); segDists.add(null); segReps.add(null); segSteps.add(null)
    }

    /** 러닝: 1km 넘으면 저절로 다음 km (총거리 다 뛰면 끝) */
    private fun autoSplitIfNeeded() {
        if (!isRunKind || !active || finished || !running || segDist < 1000) return
        val now = clock()
        undoPoint = null; canUndo = false
        closeSeg(now)
        if (runKm == 0 && splits.size >= seq.size) growSeq()
        if (splits.size >= seq.size) {
            finish(now, complete = true)
        } else {
            idx = splits.size
            segStart = now; segPaused = 0
            segDistStart = distance
            segStepStart = steps
            advanceCount++
            buzz(BuzzKind.Next)
            pushLive()
        }
    }

    fun togglePause() {
        if (!active || finished) return
        if (running) {
            pauseAt = clock(); running = false
            curSpeed = 0.0                              // 빌드 27: 멈추면 속도 모름
            sensors.pause()
            reps.setPaused(true)
        } else {
            pauseAt?.let { segPaused += clock() - it }
            pauseAt = null; running = true
            sensors.resume()
            reps.setPaused(false)
        }
        pushLive()
    }

    /** End → 저장하고 끝내기: 현재 구간까지 기록 */
    fun endNow() {
        if (!active || finished) return
        if (!running) togglePause()
        val now = clock()
        closeSeg(now)
        // HIIT · 자유 러닝은 끝이 없으니 End 가 정상 종료. 그 외는 마지막 구간에서 End 눌러도 다 한 것
        finish(now, complete = growsOpen || splits.size >= seq.size)
    }

    /** 버리기: 기록 안 만듦 · 폰으로 안 보냄 · 측정도 저장 안 함 → 첫 화면 */
    fun discardNow() {
        if (!active || finished) return
        reps.stop()
        undoPoint = null; canUndo = false
        sensors.end(save = false)
        onLive?.invoke(liveState(clock()).copy(discarded = true))
        buzz(BuzzKind.Click)
        active = false; finished = false; lastRecord = null
        onActive(false)
    }

    /** 요약에서 Done */
    fun reset() {
        reps.stop()
        undoPoint = null; canUndo = false
        active = false; finished = false; lastRecord = null
    }

    // MARK: 1초마다 (운동 서비스가 부름)

    fun tick() {
        // 폰에 5초마다 심박 · 칼로리 · 시간 맞추기
        liveTicks++
        // 빌드 27: 10초 넘게 새 속도가 없으면 모름(0) — 멈춰 섰는데 예전 페이스가 남지 않게
        if (curSpeed > 0 && clock() - lastSpeedAt > 10_000) curSpeed = 0.0
        if (liveTicks % 5 == 0) pushLive()
        if (!active || finished || !running) return
        if (!settings.hapticPace || !(mode == Mode.Race || mode == Mode.Sim)) return
        val c = cur
        if (c.kind == SegKind.Rox || c.target <= 0 || idx in paceBuzzed) return
        if (segEl() > c.target) {
            paceBuzzed.add(idx)
            buzz(BuzzKind.Over)
        }
    }

    /** 심박 존이 바뀌면 진동 (첫 측정값 제외, 10초에 한 번까지) */
    private fun checkZone(bpm: Double, now: Long) {
        val z = min(5, max(1, settings.zone(bpm)))
        val prev = lastZone
        lastZone = z
        if (prev <= 0 || z == prev) return
        if (!active || finished || !running || !settings.hapticZone) return
        if (now - lastZoneBuzz < 10_000) return
        lastZoneBuzz = now
        buzz(if (z > prev) BuzzKind.ZoneUp else BuzzKind.ZoneDown)
    }

    private fun closeSeg(now: Long) {
        val t = segEl(now)
        splits = splits + t
        if (cur.kind == SegKind.Run && idx < segDists.size) segDists[idx] = segDist
        // 이 구간 걸음 수 (러닝 카드에서 걸음을 받았을 때만)
        if (isRunKind && cur.kind == SegKind.Run && steps > segStepStart && idx < segSteps.size) segSteps[idx] = steps - segStepStart
        val r = reps.stop()
        if (idx < segReps.size) segReps[idx] = r
    }

    private fun makeRecord(complete: Boolean): Record {
        val bpms = hrSamples.map { it.b }
        val results = splits.mapIndexedNotNull { i, t ->
            val s = seq.getOrNull(i) ?: return@mapIndexedNotNull null
            val h = segHR.getOrNull(i).orEmpty()
            SegResult(s.icon, s.name, s.detail, s.kind, t, s.target,
                hr = if (h.isEmpty()) null else (h.sum() / h.size).roundToInt(),
                dist = segDists.getOrNull(i), reps = segReps.getOrNull(i))
        }
        val total = splits.sum()
        val tg = seq.take(splits.size).sumOf { it.target }
        val start = Instant.ofEpochMilli(startMs)
        var r = Record(
            newId(), mode, title, sets, start, total, results, hrSamples.toList(),
            kcal.roundToInt(), if (bpms.isEmpty()) 0 else bpms.sum() / bpms.size, bpms.maxOrNull() ?: 0, settings.div.name,
            goal = if (mode == Mode.Race) settings.goalTime else null,
            vsWord = deltaWord, vsTarget = if (kind == null && (mode != Mode.Pft || hasPFTBest)) tg else null,
            complete = complete, endDate = start.plusSeconds(total.toLong()), place = place, kind = kind,
            route = if (outdoorRun && routePts.size >= 2) routePts.toList() else null,
            indoor = if (isRunKind && !outdoorRun) true else null,     // 94번
        )
        // 러닝 카드 — 케이던스 · 보폭 · 오르막 (경로 높이로)
        if (isRunKind) r = RunMetrics.fill(r, segSteps, null)
        return r
    }

    private fun finish(now: Long, complete: Boolean) {
        reps.stop()
        undoPoint = null; canUndo = false
        val r = makeRecord(complete)
        lastRecord = r
        finished = true
        pushLive()                      // 폰: "워치에서 저장 중…" → 기록이 도착하면 카드
        onRecord(r)
        buzz(BuzzKind.Success)
        sensors.end(save = true)
        onActive(false)
    }

    // MARK: 폰에 같이 보여 주기

    fun liveState(now: Long): LiveState {
        val hasTarget = kind == null && seq.any { it.target > 0 }
        return LiveState(mode, title, seq, idx, splits, segEl(now), running, hr.roundToInt(), kcal.roundToInt(),
            if (hr > 0) zone else 0, canUndo, finished, deltaWord,
            delta = if (hasTarget) delta(now) else null, open = growsOpen, autoSplit = autoSplit,
            segDist = segDist, dist = distance, spd = if (curSpeed > 0) curSpeed else null)
    }

    private fun pushLive() {
        if (!active && !finished) return
        if (!settings.mirror) return
        onLive?.invoke(liveState(clock()))
    }

    /** 폰에서 누른 단추 */
    fun gotCommand(c: LiveCommand) {
        if (!active || finished) return
        when (c) {
            LiveCommand.Next -> advance()
            LiveCommand.Undo -> undo()
            LiveCommand.Pause -> if (running) togglePause()
            LiveCommand.Resume -> if (!running) togglePause()
            LiveCommand.End -> endNow()
        }
        pushLive()
    }

    // MARK: 측정값

    override fun gotHR(bpm: Double, atMs: Long) {
        hr = bpm
        if (bpm > 0) checkZone(bpm, clock())
        if (!active || finished || !running) return
        val t = total(atMs)
        segHR.getOrNull(idx)?.add(bpm)
        val last = hrSamples.lastOrNull()
        if (last != null && t - last.t < 5) return
        hrSamples.add(HRPoint(t, bpm.roundToInt()))
    }

    override fun gotEnergy(kcalTotal: Double) { kcal = kcalTotal }

    override fun gotDistance(metersTotal: Double) {
        distance = metersTotal
        autoSplitIfNeeded()
    }

    override fun gotSteps(total: Double) {
        if (!active || finished) return
        steps = total
    }

    override fun gotLocation(lat: Double, lon: Double, acc: Float, alt: Double?, vAcc: Float?, atMs: Long) {
        if (!active || finished || !running || !outdoorRun) return
        if (acc <= 0f || acc > 30f) return
        val p = RoutePt(lat, lon, if (vAcc != null && vAcc > 0f) alt else null, total(atMs))
        val lr = lastRoute
        if (lr != null && RunMetrics.meters(lr, p) < 8) return
        lastRoute = p
        routePts.add(p)
    }

    override fun gotPlace(name: String) { if (place == null) place = name }

    /** 빌드 27: 워치가 잰 지금 러닝 속도(m/s) */
    override fun gotSpeed(mps: Double) {
        if (!active || finished || !running) return
        blendSpeed(mps, clock())
    }

    // MARK: 화면 사진용 (측정 · 타이머 없이 운동 중 / 요약 상태)

    fun demoRun(mode: Mode, title: String, seq: List<Seg>, idx: Int, elapsed: Int, hr: Double, done: Boolean, vsBest: Boolean = false,
                kind: String? = null, dist: Double = 380.0, segDist: Double = 0.0, speed: Double = 0.0, indoor: Boolean = false) {
        this.kind = kind; hasPFTBest = vsBest; runKm = if (kind == "run") 5 else 0; outdoorRun = kind == "run" && !indoor
        this.mode = mode; this.title = title; sets = 1; this.seq = seq
        running = true; finished = false; lastRecord = null
        this.hr = hr; kcal = 214.0; distance = dist
        segHR = ArrayList<ArrayList<Double>>().apply { repeat(seq.size) { add(ArrayList()) } }
        segDists = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        segReps = ArrayList<Int?>().apply { repeat(seq.size) { add(null) } }
        segSteps = ArrayList<Double?>().apply { repeat(seq.size) { add(null) } }
        steps = 0.0; segStepStart = 0.0
        curSpeed = speed; lastSpeedAt = clock()
        segDistStart = dist - segDist; segPaused = 0; pauseAt = null
        undoPoint = null; canUndo = !done && idx > 0
        val now = clock()
        if (done) {
            splits = seq.mapIndexed { i, s -> max(20, (s.target * (if (i % 2 == 0) 1.04 else 0.97)).toInt()) }
            this.idx = max(0, seq.size - 1)
            for (i in seq.indices) {
                segHR[i] = arrayListOf((150 + (i * 7) % 24).toDouble())
                if (seq[i].kind == SegKind.Run) segDists[i] = 1000.0
            }
            hrSamples = ArrayList((0 until 40).map { k -> HRPoint(k * 45, 120 + (45 * min(1.0, k / 8.0)).toInt() + (k % 5) * 3) })
            kcal = 612.0
            startMs = now - splits.sum() * 1000L
            lastRecord = makeRecord(true)
            finished = true
        } else {
            this.idx = idx
            splits = seq.take(idx).map { max(20, (it.target * 1.03).toInt()) }
            hrSamples = ArrayList()
            startMs = now - (splits.sum() + elapsed) * 1000L
            segStart = now - elapsed * 1000L
        }
        lastZone = 0
        active = true
    }

    companion object {
        const val COUNT_FROM = 3
    }
}
