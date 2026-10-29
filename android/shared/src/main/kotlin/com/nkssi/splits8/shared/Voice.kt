package com.nkssi.splits8.shared

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.roundToInt
import kotlin.random.Random

// 19번: 운동 중 음성 안내 (나이키 런 클럽식 "조각 이어 붙이기").
// 미리 녹음한 짧은 소리 조각(assets/voice/ko/<id>.m4a)을 이어서 틈 없이 재생. 여기는 어떤 조각을 어떤 순서로 말할지만 정함
// (안드로이드 코드 없음 → 시험 가능). 실제 재생은 폰 · 워치의 VoicePlayer.

/** 조각 이름 만들기 */
object VoiceClips {
    /** 응원 15개 */
    val cheers: List<String> = (1..15).map { "cheer_" + it.toString().padStart(2, '0') }

    /** 거리 조각 (m → id). half · full 은 하프 · 풀코스 완주 */
    private val dists: List<Pair<Double, String>> = buildList {
        for (m in listOf(100, 200, 300, 400, 500, 600, 800)) add(m.toDouble() to "m_$m")
        for (h in 2..20) {                                   // 1 · 1.5 · 2 … 9.5 · 10 km
            val km = h / 2.0
            add(km * 1000 to if (h % 2 == 0) "km_${h / 2}" else "km_${h / 2}_5")
        }
        for (k in 11..21) add(k * 1000.0 to "km_$k")
        add(21097.5 to "half")
        add(42195.0 to "full")
    }

    /**
     * 시간: 5:12 → [min_5, sec_12]. 0 인 칸은 말하지 않음. 1시간 넘으면 시간 + 분 (초는 뺌).
     * 0초 이하 → 빈 목록
     */
    fun duration(sec: Int): List<String> {
        if (sec <= 0) return emptyList()
        if (sec >= 3600) {
            val h = sec / 3600
            val m = (sec % 3600) / 60
            return buildList {
                add("hour_${h.coerceIn(1, 3)}")
                if (m > 0) add("min_$m")
            }
        }
        val m = sec / 60
        val s = sec % 60
        return buildList {
            if (m > 0) add("min_$m")
            if (s > 0) add("sec_$s")
        }
    }

    /** 페이스 (1 km 당 초): [pre_pace, min_5, sec_12]. 말할 수 없는 값(0 이하 · 1시간 이상)이면 빈 목록 */
    fun pace(secPerKm: Int, prefix: String = "pre_pace"): List<String> {
        if (secPerKm <= 0 || secPerKm >= 3600) return emptyList()
        return listOf(prefix) + duration(secPerKm)
    }

    /** 심박: 5 단위로 반올림, 60~200. 모르면(0 이하) null */
    fun heartRate(bpm: Int): String? {
        if (bpm <= 0) return null
        val r = ((bpm / 5.0).roundToInt() * 5).coerceIn(60, 200)
        return "hr_$r"
    }

    /** 거리: 가장 가까운 조각. 가장 가까운 것도 10% 넘게 다르면(예: 30 km) null */
    fun distance(meters: Double): String? {
        if (meters < 50) return null
        val best = dists.minByOrNull { abs(it.first - meters) } ?: return null
        if (abs(best.first - meters) > best.first * 0.1) return null
        return best.second
    }

    /** 구간 아이콘 → 종목 조각 (모르는 종목은 null) */
    fun station(icon: String): String? = when (icon) {
        "run" -> "st_run"
        "skiErg" -> "st_ski"
        "sledPush" -> "st_push"
        "sledPull" -> "st_pull"
        "burpeeBroadJump" -> "st_bbj"
        "row" -> "st_row"
        "farmersCarry" -> "st_farm"
        "sandbagLunges" -> "st_lunge"
        "wallBalls" -> "st_wb"
        "roxzone" -> "st_rox"
        else -> null
    }

    /** "첫 번째 러닝" … "여덟 번째 러닝" (9번째부터는 null) */
    fun runNo(n: Int): String? = if (n in 1..8) "run_$n" else null
}

/** 음성 안내 설정 (운동 시작 때 정해 둠) */
data class VoicePrefs(
    val on: Boolean,
    /** 러닝 알림 간격(m). 0 = 끔 */
    val everyM: Int = 1000,
    val dist: Boolean = true,
    val time: Boolean = true,
    val pace: Boolean = true,
    val hr: Boolean = true,
) {
    companion object {
        /** 지금은 한국어 조각만 있어서, 앱이 한국어가 아니면 끔 */
        fun of(s: Settings, korean: Boolean) = VoicePrefs(
            on = s.voice && korean, everyM = s.voiceEvery,
            dist = s.voiceDist, time = s.voiceTime, pace = s.voicePace, hr = s.voiceHr,
        )
    }
}

/**
 * 운동 상태를 자주(폰 0.25초 · 워치 1초) 받아서, 말할 것이 생기면 조각 목록(Line)을 돌려줌.
 * 앞 상태와 비교해서 정하므로 여러 번 불러도 같은 말을 두 번 하지 않음.
 *
 * - 시작 · 일시정지 · 다시 시작 · 끝
 * - 러닝 카드: 간격(0.5 / 1 km)마다 거리 · 지금까지 시간 · 평균 페이스 · 평균 심박
 * - 시뮬 · 레이스 · 트레이닝: 구간이 바뀌면 다음 구간 (n번째 러닝 · 종목 · 록스존 + 다음은 …),
 *   마지막 러닝 · 마지막 월볼 · 절반 왔어요, 1분 넘는 스테이션은 중간에 응원 한 번 (같은 응원 연달아 안 나옴)
 * - 응원은 구간마다 한 번, 바로 앞 안내 뒤 15초 안에는 안 함. 구간 안내(Event)가 오면 기다리던 응원은 버림 (재생기가 처리)
 */
class VoiceCoach(private val prefs: VoicePrefs, private val rnd: Random = Random.Default) {
    enum class Pri { Event, Cheer }

    data class Line(val clips: List<String>, val pri: Pri = Pri.Event)

    /** 운동 한 장면 */
    data class Obs(
        /** 운동 중 (버리기 하면 false) */
        val active: Boolean,
        /** 저장하고 끝남 */
        val finished: Boolean,
        val running: Boolean,
        val mode: Mode,
        /** null = 하이록스 운동, "run" = 러닝 카드, "hiit" */
        val kind: String?,
        val seq: List<Seg>,
        val idx: Int,
        /** 이번 구간 시간(초) */
        val segEl: Int,
        /** 전체 시간(초) */
        val total: Int,
        /** 전체 거리(m). 모르면 null */
        val dist: Double? = null,
        /** 평균 심박. 모르면 null */
        val avgHr: Int? = null,
        /** 18번 AMRAP: 정한 총 시간(초) */
        val cap: Int? = null,
        /** 18번: 이번 구간에서 지난 ms (시간 구간 10초 전 안내를 정확히). 모르면 segEl 로 */
        val segMs: Long? = null,
    )

    private var started = false
    private var ended = false
    private var lastIdx = 0
    private var lastRunning = true
    /** 다음 러닝 알림 거리(m) */
    private var nextMark = 0.0
    private var halfSaid = false
    private val cheered = HashSet<Int>()
    private var lastCheer: String? = null
    /** 마지막 안내가 끝났을 것 같은 때 (ms) */
    private var quietFrom = Long.MIN_VALUE / 2
    /** 18번: 시작 전 3 · 2 · 1 · 시작 을 말했음 → 시작 안내는 안 함 */
    private var counted = false
    /** 18번: "10초" 를 말한 구간 */
    private val tenSaid = HashSet<Int>()
    /** 18번 AMRAP: 이미 말한 남은 시간 (60 · 30 · 10) */
    private val capSaid = HashSet<Int>()

    /**
     * 18번: 타이머 운동(타바타 · EMOM · AMRAP) 시작 전 세기. n = 3 · 2 · 1, 0 = 시작.
     * 엔진이 숫자가 바뀔 때마다 부름. 시작을 말했으면 운동 시작 때 "운동 시작" 은 다시 안 함
     */
    fun countdown(n: Int, kind: String?): Line? {
        if (!prefs.on || started || !Kinds.isTimer(kind)) return null
        val clip = when (n) {
            3 -> "cd_3"
            2 -> "cd_2"
            1 -> "cd_1"
            0 -> "cd_go"
            else -> return null
        }
        if (n == 0) counted = true
        return Line(listOf(clip))
    }

    fun update(o: Obs, now: Long): Line? {
        if (!prefs.on || ended) return null
        if (!started) {
            if (!o.active || o.finished) return null
            started = true
            lastIdx = o.idx
            lastRunning = o.running
            nextMark = nextMarkAbove(o.dist ?: 0.0)
            // 앱을 다시 열어 이어 받은 운동이면 시작 안내는 안 함
            if (o.total > 5) return null
            val clips = ArrayList<String>()
            if (!(counted && Kinds.isTimer(o.kind))) clips.add("go_start")
            if (o.kind == null) clips.addAll(segIntro(o.seq, o.idx))
            if (o.kind == Kinds.IVRUN || o.kind == Kinds.TABATA) clips.addAll(bonusIntro(o.kind, o.seq, o.idx))
            if (clips.isEmpty()) return null
            return say(Line(clips), now)
        }
        if (!o.active) { ended = true; return null }          // 버림 → 말 안 함
        if (o.finished) {
            ended = true
            // 18번 AMRAP: 시간이 다 돼서 끝남 → "타임! AMRAP 끝"
            val capped = o.kind == Kinds.AMRAP && o.cap != null && o.total >= o.cap
            val clips = arrayListOf(if (capped) "amrap_end" else "go_end")
            if (o.kind == "run" || o.kind == Kinds.IVRUN) {
                o.dist?.let { d -> if (prefs.dist) VoiceClips.distance(d)?.let { clips.add(it) } }
                if (prefs.time) clips.addAll(VoiceClips.duration(o.total))
            }
            return say(Line(clips), now)
        }
        if (o.running != lastRunning) {
            lastRunning = o.running
            return say(Line(listOf(if (o.running) "go_resume" else "go_pause")), now)
        }
        if (!o.running) return null
        if (o.idx != lastIdx) {
            val forward = o.idx > lastIdx
            val from = lastIdx
            lastIdx = o.idx
            if (forward && Kinds.isNew(o.kind)) {
                val clips = bonusStep(o.kind, o.seq, from, o.idx)
                if (clips.isNotEmpty()) return say(Line(clips), now)
            }
            if (forward && o.kind == null) {
                val clips = ArrayList<String>()
                if (!halfSaid && isHalfway(o.seq, o.idx)) { halfSaid = true; clips.add("t_half") }
                clips.addAll(segIntro(o.seq, o.idx))
                if (clips.isNotEmpty()) return say(Line(clips), now)
            }
        }
        if (Kinds.isNew(o.kind)) bonusTick(o, now)?.let { return it }
        if (o.kind == "run" || o.kind == Kinds.IVRUN) {
            val d = o.dist ?: return null
            if (prefs.everyM > 0 && d >= nextMark && nextMark > 0) {
                val mark = floor(d / prefs.everyM) * prefs.everyM
                nextMark = nextMarkAbove(d)
                val clips = runLine(mark, d, o.total, o.avgHr)
                if (clips.isNotEmpty()) return say(Line(clips), now)
            }
            return null
        }
        if (o.kind == null) cheerIfDue(o, now)?.let { return it }
        return null
    }

    /** 18번: 운동 중 시간 안내 — 시간 구간 끝나기 10초 전 (30초 넘는 구간), AMRAP 남은 1분 · 30초 · 10초 */
    private fun bonusTick(o: Obs, now: Long): Line? {
        if (o.kind == Kinds.AMRAP) {
            val left = Bonus.capLeft(o.cap, o.total) ?: return null
            val cap = o.cap ?: return null
            // 가장 작은 남은 칸부터 (10 → 30 → 60): 늦게 알았을 때 지난 칸은 건너뜀
            for ((at, clip) in listOf(10 to "t_10s", 30 to "t_30s", 60 to "t_1m")) {
                if (left in 1..at && at !in capSaid) {
                    // 지나간 큰 값들도 같이 막음 (예: 10초 남았을 때 처음 들어왔으면 1분 · 30초는 안 함)
                    capSaid.addAll(listOf(60, 30, 10).filter { it >= at })
                    if (cap <= at || left < at - 3) return null      // 너무 늦게 알았으면 말 안 함
                    return say(Line(listOf(clip)), now)
                }
            }
            return null
        }
        if (o.kind == Kinds.EMOM) return null
        val seg = o.seq.getOrNull(o.idx) ?: return null
        val len = Bonus.timedLen(o.kind, seg) ?: return null
        if (len < 30 || o.idx in tenSaid) return null
        val ms = o.segMs ?: (o.segEl * 1000L)
        val leftMs = len * 1000L - ms
        if (leftMs in 1..10_000) {
            tenSaid.add(o.idx)
            if (leftMs < 8_000) return null                          // 늦게 알았으면 말 안 함
            return say(Line(listOf("t_10s")), now)
        }
        return null
    }

    private fun say(l: Line, now: Long): Line {
        // 조각 하나 약 1초로 잡고, 그 뒤 15초는 응원 안 함
        quietFrom = now + l.clips.size * 1000L
        return l
    }

    private fun nextMarkAbove(d: Double): Double {
        if (prefs.everyM <= 0) return Double.MAX_VALUE
        return (floor(d / prefs.everyM) + 1) * prefs.everyM
    }

    /** 러닝 알림 한 줄: 1킬로미터. 지금까지 5분 12초. 평균 페이스 5분 12초. 심박 155. */
    private fun runLine(mark: Double, dist: Double, total: Int, avgHr: Int?): List<String> = buildList {
        if (prefs.dist) VoiceClips.distance(mark)?.let { add(it) }
        if (prefs.time) {
            val t = VoiceClips.duration(total)
            if (t.isNotEmpty()) { add("pre_time"); addAll(t) }
        }
        if (prefs.pace && dist > 0) addAll(VoiceClips.pace((total / (dist / 1000.0)).roundToInt(), "pre_avg"))
        if (prefs.hr && avgHr != null) VoiceClips.heartRate(avgHr)?.let { add(it) }
    }

    /** 스테이션이 1분 넘게 걸리는 구간이면, 중간쯤 응원 한 번 (같은 응원 연달아 안 나옴) */
    private fun cheerIfDue(o: Obs, now: Long): Line? {
        val seg = o.seq.getOrNull(o.idx) ?: return null
        if (seg.kind != SegKind.St || seg.icon == "hiit" || o.idx in cheered) return null
        // 목표가 1분 넘으면 목표의 절반에서, 목표가 없으면 1분이 지났을 때. 1분 안쪽 목표는 응원 안 함
        val at = when {
            seg.target > 60 -> seg.target / 2
            seg.target <= 0 -> 60
            else -> return null
        }
        if (o.segEl < at) return null
        if (now - quietFrom < 15_000) return null
        cheered.add(o.idx)
        val pick = VoiceClips.cheers.filter { it != lastCheer }
        val c = pick[rnd.nextInt(pick.size)]
        lastCheer = c
        return say(Line(listOf(c), Pri.Cheer), now)
    }

    companion object {
        /** 이 구간을 시작할 때 말할 것 */
        fun segIntro(seq: List<Seg>, i: Int): List<String> {
            val seg = seq.getOrNull(i) ?: return emptyList()
            return when (seg.kind) {
                SegKind.Rox -> buildList {
                    add("st_rox")
                    val nx = (i + 1 until seq.size).firstOrNull { seq[it].kind != SegKind.Rox }
                    nx?.let { segName(seq, it) }?.let { add("pre_next"); add(it) }
                }
                SegKind.Run -> {
                    val runs = seq.indices.filter { seq[it].kind == SegKind.Run }
                    if (runs.size > 1 && i == runs.last()) listOf("sim_lastrun")
                    else listOfNotNull(segName(seq, i))
                }
                SegKind.St -> {
                    val lastMain = seq.indices.lastOrNull { seq[it].kind != SegKind.Rox }
                    val name = segName(seq, i)
                    when {
                        i == lastMain && seg.icon == "wallBalls" -> listOf("sim_wb")
                        i == lastMain && i > 0 && name != null -> listOf(name, "sim_last")
                        else -> listOfNotNull(name)
                    }
                }
            }
        }

        /** 18번: 운동을 시작할 때 첫 구간 안내 (타바타 "운동", 인터벌 러닝 "빠르게" 등) */
        fun bonusIntro(kind: String?, seq: List<Seg>, i: Int): List<String> = when (kind) {
            Kinds.TABATA -> tabataClip(seq, i)?.let { listOf(it) } ?: emptyList()
            Kinds.IVRUN -> listOfNotNull(ivClip(seq.getOrNull(i)))
            else -> emptyList()
        }

        /**
         * 18번: 구간이 앞으로 넘어갔을 때 (from → i).
         * 타바타 운동 "운동" · 마지막 운동 "마지막 세트" · 휴식 "휴식" / EMOM 매 간격 "다음 라운드" /
         * 인터벌 러닝 "빠르게" · "천천히" · 걷기 · 휴식 "휴식" (마지막 반복 첫 단계면 앞에 "마지막 세트") /
         * 기능성 운동 휴식이 끝나고 다음 세트 "다음 세트"
         */
        fun bonusStep(kind: String?, seq: List<Seg>, from: Int, i: Int): List<String> {
            val seg = seq.getOrNull(i) ?: return emptyList()
            return when (kind) {
                Kinds.TABATA -> listOfNotNull(tabataClip(seq, i))
                Kinds.EMOM -> listOf("emom_next")
                Kinds.IVRUN -> buildList {
                    val maxRep = seq.mapNotNull { it.rep }.maxOrNull() ?: 0
                    val firstOfRep = seg.rep != null && seq.indexOfFirst { it.rep == seg.rep } == i
                    if (maxRep > 1 && seg.rep == maxRep && firstOfRep) add("iv_last_set")
                    ivClip(seg)?.let { add(it) }
                }
                Kinds.LIFT -> if (seq.getOrNull(from)?.icon == "rest" && seg.icon == "lift") listOf("tabata_set") else emptyList()
                else -> emptyList()
            }
        }

        private fun tabataClip(seq: List<Seg>, i: Int): String? {
            val seg = seq.getOrNull(i) ?: return null
            if (seg.icon == "rest") return "iv_rest"
            val lastWork = seq.indexOfLast { it.icon != "rest" }
            return if (i == lastWork && i > 0) "iv_last_set" else "iv_work"
        }

        private fun ivClip(seg: Seg?): String? = when (seg?.name) {
            null -> null
            "Fast" -> "iv_fast"
            "Easy", "Warm-up", "Cool-down" -> "iv_easy"
            else -> "iv_rest"                                           // Walk · Rest
        }

        /** 구간 이름 조각: 러닝은 n번째 러닝 (9번째부터는 "러닝"), 스테이션은 종목 */
        fun segName(seq: List<Seg>, i: Int): String? {
            val seg = seq.getOrNull(i) ?: return null
            if (seg.kind == SegKind.Run) {
                val n = seq.take(i + 1).count { it.kind == SegKind.Run }
                return VoiceClips.runNo(n) ?: "st_run"
            }
            return VoiceClips.station(seg.icon)
        }

        /** 록스존을 뺀 구간 중 딱 절반을 끝내고 이 구간에 들어왔는지 (구간 4개 이상일 때) */
        fun isHalfway(seq: List<Seg>, i: Int): Boolean {
            val n = seq.count { it.kind != SegKind.Rox }
            if (n < 4) return false
            val done = seq.take(i).count { it.kind != SegKind.Rox }
            if (done != n / 2) return false
            // 록스존 다음 구간에서 또 말하지 않게, 처음 그 수가 된 자리에서만 (바로 앞이 록스존이면 이미 지나간 자리)
            return i > 0 && seq[i - 1].kind != SegKind.Rox
        }
    }
}
