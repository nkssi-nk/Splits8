package com.nkssi.splits8.shared

import kotlinx.serialization.Serializable
import kotlin.math.roundToInt

// 18번: 트레이닝 메뉴에 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동(웨이트) 추가.
// 지금 HIIT · 러닝 카드와 같은 길: Program.kind 하나로 나누고, 구간 순서(Seg)로 펼쳐서 폰 · 워치 엔진이 그대로 돌림.
// 시간으로 넘어가는 규칙 · 이름 · 설명 · 기록 계산은 모두 여기 (안드로이드 코드 없음 → 시험 가능).

/** Program.kind / Record.kind 값 */
object Kinds {
    const val HIIT = "hiit"
    const val RUN = "run"
    const val TABATA = "tabata"
    const val EMOM = "emom"
    const val AMRAP = "amrap"
    const val IVRUN = "ivrun"
    const val LIFT = "lift"

    /** 18번에 새로 생긴 종류 */
    val added: Set<String> = setOf(TABATA, EMOM, AMRAP, IVRUN, LIFT)
    /** 타이머 + 라운드 (시작 전 3 · 2 · 1 음성) */
    val timers: Set<String> = setOf(TABATA, EMOM, AMRAP)

    fun isNew(kind: String?): Boolean = kind != null && kind in added
    fun isTimer(kind: String?): Boolean = kind != null && kind in timers

    /** 워치 운동 종류를 HIIT 로 (러닝 · 인터벌 러닝 · 하이록스 말고) */
    fun hiitLike(kind: String?): Boolean = kind == HIIT || kind == TABATA || kind == EMOM || kind == AMRAP || kind == LIFT

    /** 러닝처럼 GPS · 거리 · 걸음을 쓰는 카드 */
    fun runLike(kind: String?): Boolean = kind == RUN || kind == IVRUN

    /** 카드 · 목록 아이콘 (있는 그림만 씀) */
    fun icon(kind: String?): String = when (kind) {
        RUN, IVRUN -> "run"
        LIFT -> "farmersCarry"
        else -> "hiit"
    }

    /** 트레이닝 만들기 메뉴 카드 순서 (하이록스 트레이닝은 만들기 화면 그 자체) */
    val menu: List<String> = listOf(RUN, IVRUN, HIIT, TABATA, EMOM, AMRAP, LIFT)

    /** 메뉴 카드 제목 (번역 키) */
    fun title(kind: String?): String = when (kind) {
        null -> "HYROX training"
        HIIT -> "HIIT"
        RUN -> "Running"
        TABATA -> "Tabata"
        EMOM -> "EMOM"
        AMRAP -> "AMRAP"
        IVRUN -> "Interval run"
        LIFT -> "Strength"
        else -> kind
    }

    /** 메뉴 카드 한 줄 설명 (번역 키) */
    fun sub(kind: String?): String = when (kind) {
        HIIT -> "High-intensity intervals"
        RUN -> "Distance · 1 km splits"
        TABATA -> "Work / rest timer"
        EMOM -> "Every minute on the minute"
        AMRAP -> "As many rounds as possible"
        IVRUN -> "Fast / easy steps × repeats"
        LIFT -> "Sets · reps · weight"
        else -> ""
    }
}

/** 인터벌 러닝 단계 하나: 거리(m) 또는 시간(초) 중 하나 */
@Serializable
data class IvStep(
    /** fast / easy / walk / rest */
    val t: String = FAST,
    /** 거리 m (시간 단계면 null) */
    val m: Int? = null,
    /** 시간 초 (거리 단계면 null) */
    val s: Int? = null,
    /** 목표 페이스 (1 km 당 초, 선택) */
    val pace: Int? = null,
) {
    /** 시간 단계 (거리가 없으면 시간). 휴식은 늘 시간 */
    val isTime: Boolean get() = t == REST || m == null || m <= 0

    /** 시간 단계의 초 (없으면 60) */
    val secs: Int get() = (s ?: 60).coerceIn(5, 3600)

    /** 거리 단계의 m */
    val meters: Int get() = (m ?: 0).coerceIn(50, 42195)

    companion object {
        const val FAST = "fast"
        const val EASY = "easy"
        const val WALK = "walk"
        const val REST = "rest"
        val types = listOf(FAST, EASY, WALK, REST)

        /** 단계 종류 이름 (번역 키) */
        fun typeName(t: String): String = when (t) {
            FAST -> "Fast"
            EASY -> "Easy"
            WALK -> "Walk"
            else -> "Rest"
        }
    }
}

/** 기능성 운동 종목 하나 */
@Serializable
data class Lift(
    val name: String,
    val sets: Int = 3,
    /** 목표 횟수 */
    val reps: Int = 10,
    /** 무게 kg (0 = 맨몸) */
    val kg: Double = 0.0,
)

/** 인터벌 러닝 · 기능성 운동 미리 만든 것 */
data class IvPreset(val name: String, val steps: List<IvStep>, val rounds: Int)

/** 시간으로 넘어갈 때: 이 구간에 기록할 초, 이미 다음 구간으로 넘어간 ms */
data class TimedCut(val time: Int, val overMs: Long)

object Bonus {
    /** 타바타 기본 20 / 10 × 8 */
    const val TABATA_WORK = 20
    const val TABATA_REST = 10
    const val TABATA_ROUNDS = 8
    const val EMOM_EVERY = 60
    const val EMOM_ROUNDS = 12
    const val AMRAP_CAP = 15 * 60
    const val LIFT_REST = 90

    /** EMOM 간격 고르기: 30초 ~ 5분 */
    val emomChoices = listOf(30, 45, 60, 90, 120, 180, 240, 300)

    /** 고를 수 있는 종목 (번역 키). 직접 입력도 됨 */
    val liftNames = listOf(
        "Squat", "Deadlift", "Bench press", "Overhead press", "Kettlebell swing",
        "Goblet squat", "Lunge", "Pull-up", "Push-up", "Barbell row",
    )

    /** 예시 바로 고르기 (스펙): 400 m × 8 (200 m 조깅) · 500 m 빠르게 / 300 m 천천히 × 6 · 1 km × 5 (2분 휴식) · 1분 / 1분 × 10 */
    val ivPresets: List<IvPreset> = listOf(
        IvPreset("400 m × 8", listOf(IvStep(IvStep.FAST, m = 400), IvStep(IvStep.EASY, m = 200)), 8),
        IvPreset("500 m / 300 m × 6", listOf(IvStep(IvStep.FAST, m = 500), IvStep(IvStep.EASY, m = 300)), 6),
        IvPreset("1 km × 5", listOf(IvStep(IvStep.FAST, m = 1000), IvStep(IvStep.REST, s = 120)), 5),
        IvPreset("1 min / 1 min × 10", listOf(IvStep(IvStep.FAST, s = 60), IvStep(IvStep.EASY, s = 60)), 10),
    )

    private fun fid(prefix: String, id: String?) = id ?: (prefix + "." + newId().take(6))

    // MARK: 카드 만들기

    fun tabata(work: Int = TABATA_WORK, rest: Int = TABATA_REST, rounds: Int = TABATA_ROUNDS, id: String? = null): Program {
        val w = work.coerceIn(5, 600)
        val r = rest.coerceIn(0, 600)
        return Program(
            id = fid("tabata", id), name = tabataName(w, r), sets = 1, seq = listOf(ProgItem("hiit")),
            kind = Kinds.TABATA, work = w, rest = r, rounds = rounds.coerceIn(1, 50),
        )
    }

    fun emom(every: Int = EMOM_EVERY, rounds: Int = EMOM_ROUNDS, tasks: List<String> = emptyList(), id: String? = null): Program {
        val e = every.coerceIn(30, 300)
        return Program(
            id = fid("emom", id), name = emomName(e), sets = 1, seq = listOf(ProgItem("hiit")),
            kind = Kinds.EMOM, every = e, rounds = rounds.coerceIn(1, 60), tasks = cleanTasks(tasks),
        )
    }

    fun amrap(cap: Int = AMRAP_CAP, tasks: List<String> = emptyList(), id: String? = null): Program = Program(
        id = fid("amrap", id), name = "AMRAP", sets = 1, seq = listOf(ProgItem("hiit")),
        kind = Kinds.AMRAP, cap = cap.coerceIn(60, 90 * 60), tasks = cleanTasks(tasks),
    )

    fun ivrun(steps: List<IvStep>, rounds: Int, indoor: Boolean, warm: IvStep? = null, cool: IvStep? = null,
              name: String = "Interval run", id: String? = null): Program = Program(
        id = fid("ivrun", id), name = name, sets = 1, seq = listOf(ProgItem("run", "1KM")),
        kind = Kinds.IVRUN, indoor = indoor, rounds = rounds.coerceIn(1, 50),
        steps = steps.ifEmpty { ivPresets[0].steps }, warm = warm, cool = cool,
    )

    fun ivrun(preset: IvPreset, indoor: Boolean, id: String? = null): Program =
        ivrun(preset.steps, preset.rounds, indoor, name = preset.name, id = id)

    fun lift(lifts: List<Lift>, rest: Int = LIFT_REST, id: String? = null): Program = Program(
        id = fid("lift", id), name = "Strength", sets = 1, seq = listOf(ProgItem("hiit")),
        kind = Kinds.LIFT, rest = rest.coerceIn(0, 600), lifts = lifts.ifEmpty { listOf(Lift("Squat")) },
    )

    private fun cleanTasks(t: List<String>): List<String>? =
        t.map { it.trim().take(40) }.filter { it.isNotEmpty() }.take(8).ifEmpty { null }

    /** "Tabata" (20/10) / "Interval timer 40/20" */
    fun tabataName(work: Int, rest: Int): String =
        if (work == TABATA_WORK && rest == TABATA_REST) "Tabata" else "Interval timer $work/$rest"

    /** "EMOM" (1분) / "E2MOM" (2분) / "EMOM 0:30" */
    fun emomName(every: Int): String = when {
        every == 60 -> "EMOM"
        every % 60 == 0 -> "E${every / 60}MOM"
        else -> "EMOM " + Fm.t(every)
    }

    // MARK: 글자

    /** 짧은 시간: 20초 / 2분 / 1:30 (번역됨) */
    fun dur(sec: Int): String = when {
        sec < 60 -> L10n.t("%lld sec", sec)
        sec % 60 == 0 -> L10n.t("%lld min", sec / 60)
        else -> Fm.t(sec)
    }

    /** 거리 글자: 400 m / 1 km / 1.5 km */
    fun distText(m: Int): String = if (m >= 1000) {
        val km = m / 1000.0
        (if (km == km.toInt().toDouble()) "${km.toInt()}" else "%.1f".format(java.util.Locale.US, km)) + " km"
    } else "$m m"

    /** 무게 글자: 60 kg / 62.5 kg */
    fun kgText(kg: Double): String =
        (if (kg == kg.toLong().toDouble()) "${kg.toLong()}" else "%.1f".format(java.util.Locale.US, kg)) + " kg"

    /** 구간 상세 글자의 거리 (runMeters 가 읽는 모양): 400M / 1KM / 1.5KM */
    fun distLabel(m: Int): String = if (m >= 1000) {
        val km = m / 1000.0
        (if (km == km.toInt().toDouble()) "${km.toInt()}" else "%.1f".format(java.util.Locale.US, km)) + "KM"
    } else "${m}M"

    /** 인터벌 러닝 단계 글자: "500 m Fast" / "1 min Easy" (번역됨) */
    fun stepText(s: IvStep): String {
        val amount = if (s.isTime) dur(s.secs) else distText(s.meters)
        return amount + " " + IvStep.typeName(s.t).l10n
    }

    /** 카드 · 워치 목록 설명 (번역됨) */
    fun metaLine(p: Program): String = when (p.kind) {
        Kinds.TABATA -> L10n.t("%@ work · %@ rest · %lld rounds", dur(p.work ?: TABATA_WORK), dur(p.rest ?: TABATA_REST), p.rounds ?: TABATA_ROUNDS)
        Kinds.EMOM -> L10n.t("Every %@ · %lld rounds", dur(p.every ?: EMOM_EVERY), p.rounds ?: EMOM_ROUNDS)
        Kinds.AMRAP -> L10n.t("%@ · as many rounds as possible", dur(p.cap ?: AMRAP_CAP))
        Kinds.IVRUN -> {
            val st = (p.steps ?: emptyList()).joinToString(" · ") { stepText(it) }
            "${p.rounds ?: 1} × ($st) · " + (if (p.indoor == true) "Indoor" else "Outdoor").l10n
        }
        Kinds.LIFT -> {
            val ls = p.lifts ?: emptyList()
            L10n.t("%lld exercises · %lld sets", ls.size, ls.sumOf { it.sets })
        }
        else -> (p.meta ?: "").l10n
    }

    /** 총 시간 (초). 정해지지 않으면 null (인터벌 러닝 거리 단계 · 기능성 운동) */
    fun plannedTime(p: Program): Int? = when (p.kind) {
        Kinds.TABATA -> seq(p).sumOf { it.target }
        Kinds.EMOM -> (p.every ?: EMOM_EVERY) * (p.rounds ?: EMOM_ROUNDS)
        Kinds.AMRAP -> p.cap ?: AMRAP_CAP
        else -> null
    }

    // MARK: 구간 순서

    /** 이 카드로 운동할 구간 순서 */
    fun seq(p: Program): List<Seg> = when (p.kind) {
        Kinds.TABATA -> tabataSeq(p.work ?: TABATA_WORK, p.rest ?: TABATA_REST, p.rounds ?: TABATA_ROUNDS)
        Kinds.EMOM -> (1..(p.rounds ?: EMOM_ROUNDS).coerceAtLeast(1)).map {
            Seg("hiit", "Round $it", "EMOM", SegKind.St, (p.every ?: EMOM_EVERY).coerceAtLeast(5), rep = it)
        }
        Kinds.AMRAP -> listOf(amrapRound(1))
        Kinds.IVRUN -> ivSeq(p)
        Kinds.LIFT -> liftSeq(p.lifts ?: emptyList(), p.rest ?: LIFT_REST)
        else -> listOf(SeqBuilder.hiitRound(1))
    }

    /** 운동 → 휴식 → 운동 … (마지막 운동 뒤 휴식 없음). 휴식 0초면 휴식 구간 없음 */
    fun tabataSeq(work: Int, rest: Int, rounds: Int): List<Seg> = buildList {
        val n = rounds.coerceAtLeast(1)
        for (r in 1..n) {
            add(Seg("hiit", "Round $r", "WORK", SegKind.St, work.coerceAtLeast(5), rep = r))
            if (r < n && rest > 0) add(Seg("rest", "Rest", "REST", SegKind.Rox, rest, rep = r))
        }
    }

    /** AMRAP 라운드 (끝 없이 늘어남, 시간이 다 되면 끝) */
    fun amrapRound(n: Int) = Seg("hiit", "Round $n", "AMRAP", SegKind.St, 0, rep = n)

    /** 인터벌 러닝: 워밍업 + (단계들 × 반복) + 쿨다운 */
    fun ivSeq(p: Program): List<Seg> = buildList {
        p.warm?.let { add(ivSeg(it, "Warm-up", null)) }
        val steps = (p.steps ?: emptyList()).ifEmpty { ivPresets[0].steps }
        for (r in 1..(p.rounds ?: 1).coerceAtLeast(1)) for (s in steps) add(ivSeg(s, IvStep.typeName(s.t), r))
        p.cool?.let { add(ivSeg(it, "Cool-down", null)) }
    }

    private fun ivSeg(s: IvStep, name: String, rep: Int?): Seg {
        val rest = s.t == IvStep.REST
        return if (s.isTime) {
            Seg(if (rest) "rest" else "run", name, "${s.secs}S", if (rest) SegKind.Rox else SegKind.Run, s.secs, rep = rep, pace = s.pace)
        } else {
            val tg = s.pace?.let { (it * s.meters / 1000.0).roundToInt() } ?: 0
            Seg("run", name, distLabel(s.meters), SegKind.Run, tg, rep = rep, pace = s.pace)
        }
    }

    /** 종목마다 세트, 세트 사이 휴식 (맨 마지막 세트 뒤 휴식 없음) */
    fun liftSeq(lifts: List<Lift>, rest: Int): List<Seg> = buildList {
        val ls = lifts.filter { it.sets > 0 }
        for ((li, l) in ls.withIndex()) {
            for (k in 1..l.sets) {
                add(Seg("lift", l.name, "SET $k/${l.sets}", SegKind.St, 0, rep = k, reps = l.reps, kg = l.kg))
                val last = li == ls.size - 1 && k == l.sets
                if (!last && rest > 0) add(Seg("rest", "Rest", "REST", SegKind.Rox, rest, rep = k))
            }
        }
    }

    /** 구간 상세가 시간 단계인지 ("90S") */
    fun isTimeDetail(d: String): Boolean = d.length >= 2 && d.endsWith("S") && d.dropLast(1).all { it.isDigit() }

    // MARK: 운동 중 규칙 (폰 · 워치 엔진이 같이 씀)

    /** 시간으로 저절로 끝나는 구간이면 그 길이(초) */
    fun timedLen(kind: String?, s: Seg): Int? {
        val len = s.target.takeIf { it > 0 } ?: return null
        return when (kind) {
            Kinds.TABATA, Kinds.EMOM -> len
            Kinds.LIFT -> if (s.icon == "rest") len else null
            Kinds.IVRUN -> if (isTimeDetail(s.detail)) len else null
            else -> null
        }
    }

    /** 거리로 저절로 끝나는 구간이면 그 거리(m) — 인터벌 러닝 거리 단계 */
    fun distLen(kind: String?, s: Seg): Double? =
        if (kind == Kinds.IVRUN && !isTimeDetail(s.detail) && s.kind == SegKind.Run) runMeters(s.detail) else null

    /** 이 구간이 시간으로 끝났는지. segMs = 이 구간에서 지난 ms (일시정지 뺀) */
    fun timedCut(kind: String?, s: Seg, segMs: Long): TimedCut? {
        val len = timedLen(kind, s) ?: return null
        val ms = len * 1000L
        return if (segMs >= ms) TimedCut(len, segMs - ms) else null
    }

    /** AMRAP: 총 시간이 다 됐는지. doneSec = 끝낸 라운드 합, segMs = 지금 라운드 ms */
    fun capCut(cap: Int?, doneSec: Int, segMs: Long): TimedCut? {
        val c = cap ?: return null
        val left = (c - doneSec).coerceAtLeast(0)
        return if (doneSec * 1000L + segMs >= c * 1000L) TimedCut(left, segMs - left * 1000L) else null
    }

    /** 시간 구간이 바뀌기 3 · 2 · 1초 전이면 그 숫자 (진동 · 소리). 5초 미만 구간은 안 함 */
    fun warnSec(kind: String?, s: Seg, segMs: Long): Int? {
        val len = timedLen(kind, s) ?: return null
        if (len < 5) return null
        val leftMs = len * 1000L - segMs
        if (leftMs <= 0) return null
        val left = ((leftMs + 999) / 1000).toInt()
        return if (left in 1..3) left else null
    }

    /** EMOM 의 "끝" 단추: 넘기지 않고 이 라운드 끝낸 시간만 적음 */
    fun tapMarksDone(kind: String?): Boolean = kind == Kinds.EMOM

    /** 끝 없이 라운드가 늘어나는 종류 */
    fun grows(kind: String?): Boolean = kind == Kinds.AMRAP

    /** 기록에 남길 기준 초 (Record.cap): AMRAP 총 시간 · EMOM 간격 · 타바타 운동 초 */
    fun recordCap(kind: String?, cap: Int?, seq: List<Seg>): Int? = when (kind) {
        Kinds.AMRAP -> cap
        Kinds.EMOM, Kinds.TABATA -> seq.firstOrNull { it.icon == "hiit" }?.target
        else -> null
    }

    /** 남은 시간 (초) — 시간 구간의 남은 초 */
    fun segLeft(kind: String?, s: Seg, segEl: Int): Int? = timedLen(kind, s)?.let { (it - segEl).coerceAtLeast(0) }

    /** AMRAP 남은 시간 (초) */
    fun capLeft(cap: Int?, total: Int): Int? = cap?.let { (it - total).coerceAtLeast(0) }

    // MARK: 기능성 운동 — 지난번 값 · 볼륨

    /** 이 종목을 지난번에 한 세트들 (횟수, 무게) — 가장 최근 기능성 운동 기록에서. 없으면 빈 목록 */
    fun lastSets(records: List<Record>, name: String, before: java.time.Instant? = null): List<Pair<Int?, Double?>> {
        val r = records.filter { it.kind == Kinds.LIFT && (before == null || it.date < before) && it.segs.any { s -> s.icon == "lift" && s.name == name } }
            .maxByOrNull { it.date } ?: return emptyList()
        return r.segs.filter { it.icon == "lift" && it.name == name }.map { it.reps to it.kg }
    }

    /**
     * 세트 끝 확인 칸에 미리 채울 값: 이번 운동에서 바로 앞 같은 종목 세트 → 지난번 같은 번째 세트 → 계획.
     * done = 이번 운동에서 지금까지 확인한 (구간 번호 → 횟수, 무게)
     */
    fun prefill(seq: List<Seg>, idx: Int, done: Map<Int, Pair<Int?, Double?>>, last: List<Pair<Int?, Double?>>): Pair<Int, Double> {
        val s = seq.getOrNull(idx) ?: return 0 to 0.0
        val plan = (s.reps ?: 0) to (s.kg ?: 0.0)
        val prevIdx = (idx - 1 downTo 0).firstOrNull { seq[it].icon == "lift" && seq[it].name == s.name && done.containsKey(it) }
        if (prevIdx != null) {
            val (r, k) = done.getValue(prevIdx)
            return (r ?: plan.first) to (k ?: plan.second)
        }
        val l = last.getOrNull((s.rep ?: 1) - 1) ?: last.lastOrNull()
        if (l != null) return (l.first ?: plan.first) to (l.second ?: plan.second)
        return plan
    }

    /** 총 들어 올린 무게 (kg) = Σ 횟수 × 무게 */
    fun volume(r: Record): Double = r.segs.filter { it.icon == "lift" }.sumOf { (it.reps ?: 0) * (it.kg ?: 0.0) }

    /** 같은 카드(제목)로 한 바로 앞 기능성 운동 기록의 볼륨. 없으면 null */
    fun prevVolume(records: List<Record>, r: Record): Double? =
        records.filter { it.kind == Kinds.LIFT && it.id != r.id && it.title == r.title && it.date < r.date }
            .maxByOrNull { it.date }?.let { volume(it) }

    /** 종목별 세트 (이름 → 세트들) — 기록 화면 표 */
    fun liftTable(r: Record): List<Pair<String, List<SegResult>>> {
        val o = LinkedHashMap<String, ArrayList<SegResult>>()
        for (s in r.segs) if (s.icon == "lift") o.getOrPut(s.name) { ArrayList() }.add(s)
        return o.map { it.key to it.value.toList() }
    }

    // MARK: 기록 계산

    /** 인터벌 러닝: 빠른 단계만 모은 평균 페이스 (초/km). 거리 모르면 null */
    fun fastPace(r: Record): Int? {
        val f = r.segs.filter { it.kind == SegKind.Run && it.name == "Fast" && (it.dist ?: 0.0) > 0 }
        val m = f.sumOf { it.dist ?: 0.0 }
        if (m < 100) return null
        return (f.sumOf { it.time } / m * 1000).r()
    }

    /** AMRAP 결과 글자: "7 rounds + 5" (번역됨) */
    fun amrapScore(r: Record): String {
        val n = r.rounds ?: (r.segs.size - 1).coerceAtLeast(0)
        val base = L10n.t("%lld rounds", n)
        return if ((r.extra ?: 0) > 0) "$base + ${r.extra}" else base
    }

    /** 타바타: 끝까지 한 라운드 수 (운동 구간 중 다 채운 것) */
    fun tabataDone(r: Record): Int = r.segs.count { it.icon == "hiit" && it.target > 0 && it.time >= it.target }

    /**
     * 끝 카드 · 공유 그림 · 기록 화면의 종류 줄 (번역됨):
     * "EMOM · 12 min" · "AMRAP · 15 min" · "Tabata" · "Interval timer 40/20 × 10" · "Strength"
     */
    fun kindLine(r: Record): String? = when (r.kind) {
        Kinds.TABATA -> {
            val rounds = r.segs.count { it.icon == "hiit" }
            r.title.l10n + " × $rounds"
        }
        Kinds.EMOM -> "EMOM · " + L10n.t("%lld min", (r.segs.sumOf { it.target } + 30) / 60)
        Kinds.AMRAP -> "AMRAP · " + L10n.t("%lld min", ((r.cap ?: r.total) + 30) / 60)
        Kinds.IVRUN -> Kinds.title(Kinds.IVRUN).l10n
        Kinds.LIFT -> Kinds.title(Kinds.LIFT).l10n
        else -> null
    }

    /** 번역 표에 없는 이름 (숫자가 들어간 것) 한국어로. 모르면 null */
    fun koName(key: String): String? {
        Regex("^Round (\\d+)$").matchEntire(key)?.let { return "라운드 " + it.groupValues[1] }
        Regex("^Interval timer (\\d+)/(\\d+)$").matchEntire(key)?.let { return "인터벌 타이머 " + it.groupValues[1] + "/" + it.groupValues[2] }
        return null
    }
}
