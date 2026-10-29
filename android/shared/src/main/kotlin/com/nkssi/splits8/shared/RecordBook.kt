package com.nkssi.splits8.shared

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot

// 아이폰 앱(iOSApp) 안에 있던 기록 계산을 화면 없이 옮긴 것:
// Store.swift (PB · 최고 · 비교), DetailView.swift (vs · 페이스 · 존), FinishSheet.swift (끝 카드 입력),
// Fatigue.swift, Predict.swift, RunBests.swift, RunLaps.swift

// MARK: 기록 하나로 하는 계산

/** Roxzone 뺀 구간 */
val Record.mainSegs: List<SegResult> get() = segs.filter { it.kind != SegKind.Rox }

/** 러닝 1KM당 페이스(초) */
fun Record.pace(s: SegResult): Int {
    val m = s.dist ?: runMeters(s.detail)
    if (m <= 0) return s.time
    return (s.time / m * 1000).r()
}

/** 심박 존별 시간(초) Z1…Z5 */
fun Record.zoneSeconds(st: Settings): List<Int> {
    val z = IntArray(5)
    val p = hr.sortedBy { it.t }
    if (p.size <= 1) return z.toList()
    for (i in 0 until p.size - 1) {
        val dt = minOf(30, maxOf(0, p[i + 1].t - p[i].t))
        z[st.zone(p[i].b.toDouble()) - 1] += dt
    }
    return z.toList()
}

/** 이 기기 시간대의 날짜 */
fun Instant.localDate(): LocalDate = atZone(Fm.zone).toLocalDate()

// MARK: 러닝 최고 기록 (정해진 거리)

object RunPB {
    /** (거리 m, 화면 이름) */
    val distances: List<Pair<Double, String>> = listOf(
        1000.0 to "1 KM", 5000.0 to "5 KM", 10000.0 to "10 KM", 21097.5 to "HALF", 42195.0 to "MARATHON",
    )
    /** 이보다 빠른 페이스(1 km 2:30 미만)는 잘못 잰 기록으로 보고 뺌 */
    const val minPace = 150.0

    /** 빌드 27: PB 알약 글자 ("5K PB" 등). 기록 목록 · 기록 화면 · 끝 카드 · 공유 카드 */
    fun pbName(m: Double): String = when {
        m >= 42000 -> "FULL PB"
        m >= 21000 -> "HALF PB"
        m >= 10000 -> "10K PB"
        m >= 5000 -> "5K PB"
        else -> "1KM PB"
    }
}

/** 95번(빌드 28): 러닝 카드의 마지막 덜 뛴 구간 (계획 거리의 90% 미만에서 끝냄, 예: KM 7 · 0:08) */
fun Record.isPartialRun(s: SegResult): Boolean {
    if (!isRunKind || s.kind != SegKind.Run) return false
    val last = segs.lastOrNull { it.kind == SegKind.Run } ?: return false
    if (last !== s && last != s) return false
    val plan = runMeters(s.detail)
    if (plan <= 0) return false
    return (s.dist ?: plan) < plan * 0.9
}

/** 95번: 100 m 또는 30초도 안 되는 마지막 조각 → 구간 줄 · 페이스 막대에서 숨김 (총시간 · 총거리에는 들어감) */
fun Record.isTinyRun(s: SegResult): Boolean = isPartialRun(s) && ((s.dist ?: 0.0) < 100 || s.time < 30)

/** 러닝 구간들 (거리 m, 시간 초) 순서대로 */
val Record.runLegs: List<Pair<Double, Int>>
    get() {
        val rs = segs.filter { it.kind == SegKind.Run }
        val times = rs.map { it.time }.sorted()
        val median = if (times.isEmpty()) 0 else times[times.size / 2]
        // 거리를 못 잰 구간은 계획 거리로. 단, 중간에 끝낸 짧은 마지막 구간(보통 구간의 60% 미만)은 뺌
        return rs.mapNotNull { s ->
            val d = s.dist
            when {
                d != null -> d to s.time
                Bonus.isTimeDetail(s.detail) -> null          // 18번: 인터벌 러닝 시간 단계인데 거리를 모름
                s.time < median * 0.6 -> null
                else -> runMeters(s.detail) to s.time
            }
        }
    }

/** 달린 거리 합계 (m) */
val Record.runDistance: Double get() = runLegs.sumOf { it.first }

/** 완주한 1 km 구간의 평균 페이스(초/km). 0.5 km 미만 구간은 뺌 */
val Record.avgKmPace: Int?
    get() {
        val legs = runLegs.filter { it.first >= 500 }
        val m = legs.sumOf { it.first }
        if (m <= 0) return null
        return (legs.sumOf { it.second }.toDouble() / m * 1000).r()
    }

/** 이 기록 안에서 거리 D 를 가장 빨리 달린 시간(초). 구간 경계에서 시작하는 연속 구간 중 가장 빠른 것 */
fun Record.bestEffort(dist: Double): Int? {
    val legs = runLegs
    if (runDistance + 1 < dist || legs.isEmpty()) return null
    var best = Double.POSITIVE_INFINITY
    for (i in legs.indices) {
        var m = 0.0
        var t = 0.0
        var j = i
        while (j < legs.size && m < dist) {
            val (lm, lt) = legs[j]
            val need = dist - m
            if (lm <= need + 0.5) {
                m += lm; t += lt
            } else {
                t += lt * need / maxOf(1.0, lm)
                m = dist
            }
            j++
        }
        if (m + 1 >= dist) best = minOf(best, t)
    }
    if (!best.isFinite() || best / dist * 1000 < RunPB.minPace) return null
    return best.r()
}

// MARK: 바퀴 수 (트랙 · 공원 한 바퀴를 여러 번 돈 러닝)

object RunLaps {
    /** 출발선 칸 크기 · 돌아왔다고 보는 거리 (m) */
    const val cell = 20.0
    /** 이만큼 멀어져야 한 바퀴를 돈 것으로 봄 (m) */
    const val away = 80.0
    /** 이보다 짧은 바퀴는 GPS 흔들림 (초) */
    const val minLap = 20
    const val minLaps = 3

    private class P(val x: Double, val y: Double, val t: Int)

    /** 바퀴마다 걸린 시간(초). 시간 없는 경로 · 바퀴가 3개 미만이면 null */
    fun laps(route: List<RoutePt>?): List<Int>? {
        if (route == null) return null
        val pts = flat(route)
        if (pts.size < 10) return null
        val gate = gatePoint(pts) ?: return null

        val passes = ArrayList<Int>()
        var inGate = false
        var wentAway = false
        var bestD = Double.POSITIVE_INFINITY
        var bestT = 0
        fun closeVisit() {
            if (passes.isEmpty() || wentAway) {
                val last = passes.lastOrNull()
                if (last != null && bestT - last < minLap) return
                passes.add(bestT)
                wentAway = false
            }
        }
        for (p in pts) {
            val d = hypot(p.x - gate.first, p.y - gate.second)
            if (d <= cell) {
                if (!inGate) { inGate = true; bestD = d; bestT = p.t } else if (d < bestD) { bestD = d; bestT = p.t }
            } else {
                if (inGate) { closeVisit(); inGate = false }
                if (d > away) wentAway = true
            }
        }
        if (inGate) closeVisit()
        if (passes.size < minLaps + 1) return null
        val out = passes.zipWithNext { a, b -> b - a }
        return if (out.size >= minLaps) out else null
    }

    private fun flat(route: List<RoutePt>): List<P> {
        val o = route.firstOrNull { it.t != null } ?: return emptyList()
        val k = 111_320.0
        val kx = k * cos(o.a * Math.PI / 180)
        return route.mapNotNull { p -> p.t?.let { P((p.o - o.o) * kx, (p.a - o.a) * k, it) } }
    }

    /** 가장 여러 번 '들어간' 20 m 칸의 가운데 (같은 칸에 연달아 있는 점은 한 번) */
    private fun gatePoint(pts: List<P>): Pair<Double, Double>? {
        val visits = HashMap<Pair<Int, Int>, Int>()
        val sums = HashMap<Pair<Int, Int>, DoubleArray>()
        var prev: Pair<Int, Int>? = null
        for (p in pts) {
            val key = floor(p.x / cell).toInt() to floor(p.y / cell).toInt()
            if (key != prev) visits[key] = (visits[key] ?: 0) + 1
            prev = key
            val s = sums.getOrPut(key) { DoubleArray(3) }
            s[0] += p.x; s[1] += p.y; s[2] += 1.0
        }
        // 같은 횟수면 칸 번호가 작은 쪽 (열 때마다 같은 결과)
        val best = visits.entries.maxWithOrNull(
            compareBy<Map.Entry<Pair<Int, Int>, Int>> { it.value }
                .thenByDescending { it.key.first }
                .thenByDescending { it.key.second },
        ) ?: return null
        if (best.value < minLaps) return null
        val s = sums[best.key] ?: return null
        if (s[2] <= 0) return null
        return s[0] / s[2] to s[1] / s[2]
    }
}

// MARK: 런 피로도

/** 각 스테이션 바로 다음 1KM 러닝이 내 평균 러닝보다 얼마나 느린지 (초) */
data class FatigueResult(
    val names: List<String>,
    /** 스테이션별 차이(초). Wall Balls 다음엔 러닝이 없으므로 null */
    val deltas: List<Int?>,
    val avgRun: Int,
    val count: Int,
) {
    /** 가장 많이 느려지는 스테이션 번호 (0보다 클 때만) */
    val worst: Int?
        get() {
            var best: Int? = null
            var v = 0
            deltas.forEachIndexed { i, d -> if (d != null && d > v) { v = d; best = i } }
            return best
        }

    /** 막대 길이 기준 (가장 큰 양수 차이, 최소 1) */
    val maxDelta: Int get() = maxOf(1, deltas.filterNotNull().maxOrNull() ?: 1)
}

object Fatigue {
    val names = listOf("SkiErg", "Sled Push", "Sled Pull", "BBJ", "Row", "Farmers", "Lunges", "Wall Balls")

    fun analyze(records: List<Record>, limit: Int = 5): FatigueResult? {
        val recent = records.filter { it.splits16 != null }.sortedByDescending { it.date }.take(maxOf(1, limit))
        if (recent.isEmpty()) return null
        val sums = DoubleArray(7)
        var runSum = 0.0
        for (rec in recent) {
            val s = rec.splits16 ?: continue
            val avg = (0 until 16 step 2).sumOf { s[it] } / 8.0
            runSum += avg
            for (i in 0 until 7) sums[i] += s[2 * (i + 1)] - avg
        }
        val n = recent.size.toDouble()
        val deltas: List<Int?> = sums.map { (it / n).r() } + listOf(null)
        return FatigueResult(names, deltas, (runSum / n).r(), recent.size)
    }

}

// MARK: 91번 홈 카드 · 80번 상위 몇 %

object HomeShow {
    val keys = listOf("auto", "sim", "race", "pft", "run", "goal")
    fun name(k: String): String = mapOf(
        "auto" to "Latest best", "sim" to "Full Sim PB", "race" to "Race PB", "pft" to "PFT best",
        "run" to "Running PB", "goal" to "Race goal",
    )[k] ?: "Latest best"
}

/** time / tag("PB" · "5K PB" · "Race goal") / sub("Full Sim" · "Race" · "") / star */
data class HomeBest(val time: Int, val tag: String, val sub: String, val star: Boolean)

/**
 * 80번(빌드 28): 상위 몇 % (홈페이지 splits8/hyrox.html 과 같은 숫자 · 같은 계산).
 * Open: HyroxDataLab(2026.3, 전 세계 Open 기록 70만 건+) 상위 10 / 25 / 50 / 75% 경계, 사이는 곧게 이음.
 * Pro: Rox Lyfe 단계(Elite 15 · 세계 수준 · 경쟁 수준 · Pro 평균). 더블 · 릴레이는 자료가 없어 안 보임
 */
data class HyroxRank(
    val level: String,
    val pct: Int?,
    val group: String,
    val next: Pair<String, Int>?,
    val total: Int,
) {
    companion object {
        val open = mapOf("M" to listOf(75 * 60, 85 * 60, 100 * 60, 114 * 60), "W" to listOf(86 * 60, 98 * 60, 114 * 60, 130 * 60))
        val pro = mapOf("M" to listOf(54 * 60, 58 * 60, 65 * 60, 81 * 60 + 1), "W" to listOf(57 * 60, 62 * 60, 70 * 60, 86 * 60 + 36))

        fun of(division: String, total: Int): HyroxRank? {
            // 이름이나 키가 정확히 맞는 디비전만 (릴레이 등 모르는 값이 Open Men 으로 잡히지 않게)
            val d = Division.all.firstOrNull { it.key == division || it.name.equals(division, ignoreCase = true) } ?: return null
            if (total < 40 * 60 || total > 4 * 3600) return null
            val g = if (d.key.endsWith("W")) "W" else "M"
            if (d.key == "openM" || d.key == "openW") {
                val b = open.getValue(g)
                val names = listOf("Elite", "Advanced", "Intermediate", "Beginner")
                val i = b.indexOfFirst { total < it }.takeIf { it >= 0 }
                val level = i?.let { names[it] } ?: "First finish"
                return HyroxRank(level, maxOf(1, openPct(total, b).r()), d.name, nextStep(i, names, b), total)
            }
            if (d.key == "proM" || d.key == "proW") {
                val b = pro.getValue(g)
                val names = listOf("Elite 15 level", "World level", "Competitive level", "Faster than Pro average")
                val i = b.indexOfFirst { total < it }.takeIf { it >= 0 }
                val level = i?.let { names[it] } ?: "Slower than Pro average"
                return HyroxRank(level, null, d.name, nextStep(i, names, b), total)
            }
            return null
        }

        /** 다음 단계 (i = 지금 단계 번호, null = 마지막 경계보다 느림 → 맨 끝 단계가 다음) */
        fun nextStep(i: Int?, names: List<String>, b: List<Int>): Pair<String, Int>? {
            if (i == null) return names[3] to b[3]
            if (i == 0) return null
            return names[i - 1] to b[i - 1]
        }

        /** 홈페이지 openPct 와 같음: (경계×0.85 → 1%), 10, 25, 50, 75, (경계×1.25 → 97%) */
        fun openPct(t: Int, b: List<Int>): Double {
            val pts = listOf(b[0] * 0.85 to 1.0, b[0].toDouble() to 10.0, b[1].toDouble() to 25.0,
                b[2].toDouble() to 50.0, b[3].toDouble() to 75.0, b[3] * 1.25 to 97.0)
            val x = t.toDouble()
            if (x <= pts[0].first) return 1.0
            if (x >= pts[5].first) return 97.0
            for (i in 1 until pts.size) {
                if (x <= pts[i].first) {
                    val a = pts[i - 1]
                    val c = pts[i]
                    return a.second + (c.second - a.second) * (x - a.first) / (c.first - a.first)
                }
            }
            return 97.0
        }
    }
}

// MARK: 기록 묶음 (아이폰 Store 의 계산 부분)

/**
 * 기록 목록 + 설정으로 하는 계산. 폰 앱 저장소가 기록이 바뀔 때마다 새로 만들어 씀.
 * friend = 지금 고른 친구 (Insights 비교용)
 */
class RecordBook(val records: List<Record>, val settings: Settings, val friend: Friend? = null) {

    fun records(m: Mode): List<Record> = records.filter { it.mode == m }.sortedByDescending { it.date }

    val simLast: Record? get() = records(Mode.Sim).filter { it.counts && it.splits16 != null }.maxByOrNull { it.date }
    val simBest: Record? get() = records(Mode.Sim).filter { it.counts && it.splits16 != null }.minByOrNull { it.total }
    val raceBest: Record? get() = records(Mode.Race).filter { it.counts }.minByOrNull { it.total }

    /** 최고 PFT — 홈 프로필 뱃지는 이 기록의 등급 */
    val pftBest: Record? get() = records(Mode.Pft).filter { it.counts && it.pftSplits != null }.minByOrNull { it.total }
    val pftGrade: PFTGrade? get() = pftBest?.pftGrade

    /** ★ PB: 같은 종류 중 가장 빠른 기록. 비교할 기록이 2개 이상일 때만 */
    fun isPB(r: Record): Boolean {
        if (!r.counts || r.isHIIT) return false
        // 트레이닝은 전체 시간 PB 안 셈. 러닝은 정해진 거리 PB
        if (r.mode == Mode.Training) return r.isRunKind && runPBs(r).isNotEmpty()
        val same = pbGroup(r)
        if (same.size < 2) return false
        return same.minByOrNull { it.total }?.id == r.id
    }

    private fun pbGroup(r: Record): List<Record> = when (r.mode) {
        Mode.Training -> records(Mode.Training).filter { it.counts && it.title == r.title && it.sets == r.sets }
        Mode.Sim -> records(Mode.Sim).filter { it.counts && it.splits16 != null }
        Mode.Race -> records(Mode.Race).filter { it.counts }
        Mode.Pft -> records(Mode.Pft).filter { it.counts && it.pftSplits != null }
    }

    /** 트레이닝 구간별 최고. 93번: 러닝 카드 · HIIT 기록은 빼고 (스테이션 섞인 트레이닝끼리만 — 워치의 BEST 도 같은 기준) */
    val segBests: Map<String, Int> by lazy {
        val b = HashMap<String, Int>()
        for (r in records) {
            if (r.mode != Mode.Training || !r.counts || r.isBonus) continue
            for (s in r.segs) {
                if (s.kind == SegKind.Rox || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                val k = SegKey.of(s.icon, s.detail)
                b[k] = minOf(b[k] ?: Int.MAX_VALUE, s.time)
            }
        }
        b
    }

    /**
     * 빌드 27: 이 기록 '전'까지의 트레이닝 구간별 최고 (이 기록은 뺌). 기록 화면의 구간 차이(±)에 씀.
     * 93번(빌드 28): 자유러닝 · 러닝 카드 기록의 1 km 는 빼고, 스테이션이 섞인 트레이닝끼리만 비교
     */
    fun segBestsBefore(rec: Record): Map<String, Int> {
        val b = HashMap<String, Int>()
        for (r in records) {
            if (r.mode != Mode.Training || !r.counts || r.isBonus || r.id == rec.id || !r.date.isBefore(rec.date)) continue
            for (s in r.segs) {
                if (s.kind == SegKind.Rox || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                val k = SegKey.of(s.icon, s.detail)
                b[k] = minOf(b[k] ?: Int.MAX_VALUE, s.time)
            }
        }
        return b
    }

    /** 같은 프로그램 이전 최고 (VS BEST) */
    fun previousBest(r: Record): Int? =
        records.filter { it.mode == r.mode && it.title == r.title && it.id != r.id && it.date < r.date && it.counts }
            .minOfOrNull { it.total }

    /** 바로 이전 기록 (VS LAST) */
    fun previous(r: Record): Record? =
        records.filter { it.mode == r.mode && it.date < r.date && it.counts }.maxByOrNull { it.date }

    /** 비교 이름과 차이(초). Race = VS GOAL, Full Simulation = VS LAST, Training · PFT = VS BEST */
    fun vs(r: Record): Pair<String, Int?> = when (r.mode) {
        Mode.Race -> "VS GOAL" to (r.goal ?: r.vsTarget)?.let { r.total - it }
        Mode.Sim -> "VS LAST" to previous(r)?.let { r.total - it.total }
        Mode.Training, Mode.Pft -> "VS BEST" to previousBest(r)?.let { r.total - it }
    }

    /** 워치로 보낼 설정 묶음 */
    fun watchContext(programs: List<Program>): WatchContext {
        val best = simBest
        val pft = pftBest
        return WatchContext(
            settings = settings, programs = programs,
            friend = friend?.takeIf { it.hasSplits },
            simBest = best?.splits16, simBestTotal = best?.total, segBests = segBests,
            pftBest = pft?.pftSplits, pftBestTotal = pft?.total, simLast = simLast?.splits16,
            doublesPlan = settings.doublesPlan,
        )
    }

    // MARK: 러닝 최고 기록

    /** 거리별 (가장 빠른 시간, 그 거리를 뛴 기록 수) */
    private val runBestTable: Map<Double, Pair<Int, Int>> by lazy {
        // 94번: 실내 러닝은 거리가 짐작값이라 PB 에서 뺌
        val runs = records.filter { it.mode == Mode.Training && it.isRunKind && it.counts && it.indoor != true }
        RunPB.distances.mapNotNull { (m, _) ->
            val all = runs.mapNotNull { it.bestEffort(m) }
            all.minOrNull()?.let { m to (it to all.size) }
        }.toMap()
    }

    /** 이 러닝 기록이 최고 기록인 거리들 (같은 거리를 뛴 기록이 2개 이상일 때만) */
    fun runPBs(r: Record): List<Double> {
        if (!r.isRunKind || !r.counts || r.indoor == true) return emptyList()
        return RunPB.distances.mapNotNull { (m, _) ->
            val mine = r.bestEffort(m) ?: return@mapNotNull null
            val b = runBestTable[m] ?: return@mapNotNull null
            if (b.second >= 2 && mine <= b.first) m else null
        }
    }

    /** 빌드 27: 러닝 기록의 PB 이름 — PB 인 거리 중 가장 긴 것 ("5K PB"). 러닝 PB 가 아니면 null */
    fun runPBLabel(r: Record): String? = runPBs(r).maxOrNull()?.let { RunPB.pbName(it) }

    /** 빌드 27: 홈 프로필 카드용 — 러닝 PB 중 가장 긴 거리 (거리 m, 시간 초). 같은 거리를 2번 이상 뛰었을 때만 */
    fun longestRunPB(): Pair<Double, Int>? {
        for ((m, _) in RunPB.distances.reversed()) {
            val b = runBestTable[m] ?: continue
            if (b.second >= 2) return m to b.first
        }
        return null
    }

    /**
     * 91번(빌드 28): 홈 프로필 카드 오른쪽 (설정 › 프로필의 "홈 카드에 보일 기록").
     * 기본(자동) = 가장 최근에 세운 최고 기록, 없으면 목표 시간
     */
    fun homeBest(): HomeBest {
        val goal = HomeBest(settings.goalTime, "Race goal", "", false)
        val c = HashMap<String, Pair<HomeBest, Instant>>()
        simBest?.let { c["sim"] = HomeBest(it.total, "PB", "Full Sim", true) to it.date }
        raceBest?.let { c["race"] = HomeBest(it.total, "PB", "Race", true) to it.date }
        pftBest?.let { c["pft"] = HomeBest(it.total, "PB", "PFT", true) to it.date }
        longestRunPB()?.let { (m, t) ->
            // 그 거리 최고를 세운 기록의 날짜 (실내 러닝은 뺌)
            val whenAt = records.filter { it.mode == Mode.Training && it.isRunKind && it.counts && it.indoor != true }
                .filter { it.bestEffort(m) == t }.maxOfOrNull { it.date } ?: Instant.EPOCH
            c["run"] = HomeBest(t, RunPB.pbName(m), "", true) to whenAt
        }
        val k = settings.homeShow ?: "auto"
        if (k == "goal") return goal
        if (k != "auto") c[k]?.let { return it.first }
        // 자동: 가장 최근에 세운 최고 기록
        return c.values.maxByOrNull { it.second }?.first ?: goal
    }

    /** 빌드 27: 이 기록의 끝 카드를 닫은 지금이 앱 평가를 물어볼 좋은 순간인지 (기록 3개 이상 · PB · PFT 등급 상승 · 새 배지) */
    fun reviewMoment(rec: Record): Boolean {
        if (!rec.counts || !rec.isComplete) return false
        if (records.count { it.counts && it.isComplete } >= 3) return true
        if (isPB(rec)) return true
        if (Badges.new(rec, records).isNotEmpty()) return true
        if (rec.mode == Mode.Pft && rec.pftSplits != null) {
            val best = records.filter { it.id != rec.id && it.mode == Mode.Pft && it.counts && it.pftSplits != null }
                .maxOfOrNull { PFT.grade(it.total).rank }
            if (best != null && PFT.grade(rec.total).rank > best) return true
        }
        return false
    }

    // MARK: 예상 완주 시간

    /**
     * 최근 90일 트레이닝 · 풀 시뮬에서 구간별 최고 시간을 모아 완주 시간을 짐작.
     * 모자란 구간은 같은 완주 시간대 중간값으로 채우고 두 번 돌려 수렴. 스테이션 4개 미만이면 null
     */
    fun predictFinish(now: Instant = Instant.now()): Int? {
        val division = settings.division
        val cutoff = now.minusSeconds(90L * 86400)
        val recent = records.filter { it.date >= cutoff && it.counts && (it.mode == Mode.Training || it.mode == Mode.Sim) }
        var bestRun: Int? = null
        val bestSt = HashMap<String, Int>()
        for (r in recent) {
            for (s in r.segs) {
                if (s.kind == SegKind.Rox || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                if (s.kind == SegKind.Run) {
                    val m = s.dist ?: runMeters(s.detail)
                    if (m < 900 || m > 1100) continue
                    bestRun = minOf(bestRun ?: Int.MAX_VALUE, s.time)
                } else if (Station.of(s.icon) != null) {
                    bestSt[s.icon] = minOf(bestSt[s.icon] ?: Int.MAX_VALUE, s.time)
                }
            }
        }
        if (bestSt.size < 4) return null
        val bestSim = recent.filter { it.mode == Mode.Sim && it.splits16 != null }.minOfOrNull { it.total }
        var guess = bestSim ?: (80 * 60)
        repeat(2) {
            val (run, st) = HyroxBench.bench(division, guess)
            var sum = (bestRun ?: run) * 8
            for (i in 0 until 8) sum += bestSt[Station.all[i].key] ?: st[i]
            sum += HyroxBench.roxTotal(division, guess)
            guess = sum
        }
        return if (bestSim != null) minOf(bestSim, guess) else guess
    }

    // MARK: 운동 끝 카드 멘트 입력

    private fun sameKind(a: Record, r: Record): Boolean {
        if (a.mode != r.mode || !a.counts) return false
        return when (r.mode) {
            Mode.Training -> a.title == r.title && a.sets == r.sets && !a.isHIIT && !Kinds.isNew(a.kind)
            Mode.Sim -> a.splits16 != null
            Mode.Race -> true
            Mode.Pft -> a.pftSplits != null
        }
    }

    fun cheer(r: Record): Cheer = CheerPicker.pick(cheerInput(r))

    fun cheerInput(r: Record): CheerInput {
        val before = records.filter { it.id != r.id && it.date < r.date }
        var lastDelta: Int? = null
        var firstFullSim = false
        if (r.mode == Mode.Sim) {
            firstFullSim = r.splits16 != null && before.none { it.mode == Mode.Sim && it.splits16 != null && it.isComplete }
            before.filter { it.mode == Mode.Sim && it.counts }.maxByOrNull { it.date }?.let { lastDelta = r.total - it.total }
        }
        val goalDelta = if (r.mode == Mode.Race) (r.goal ?: r.vsTarget)?.let { r.total - it } else null
        var pbDelta: Int? = null
        if (r.counts && !r.isHIIT && !Kinds.isNew(r.kind)) {
            val best = before.filter { sameKind(it, r) }.minOfOrNull { it.total }
            if (best != null && r.total < best) pbDelta = r.total - best
        }
        var segBest: String? = null
        if (r.mode == Mode.Training && r.counts && !Kinds.isNew(r.kind)) {
            val prev = HashMap<String, Int>()
            for (b in before) {
                if (b.mode != Mode.Training || !b.counts) continue
                for (s in b.segs) {
                    if (s.kind != SegKind.St || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                    val k = SegKey.of(s.icon, s.detail)
                    prev[k] = minOf(prev[k] ?: Int.MAX_VALUE, s.time)
                }
            }
            var gain = 0
            for (s in r.segs) {
                if (s.kind != SegKind.St || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                val p = prev[SegKey.of(s.icon, s.detail)] ?: continue
                if (s.time < p && p - s.time > gain) { gain = p - s.time; segBest = s.name }
            }
        }
        val day = r.date.localDate()
        val ev = settings.event
        val daysToRace = if (ev.isSet) ChronoUnit.DAYS.between(day, ev.date.localDate()).toInt().takeIf { it >= 0 } else null
        val daysSinceLast = before.maxByOrNull { it.date }?.let { ChronoUnit.DAYS.between(it.date.localDate(), day).toInt() }
        val days = (before + r).map { it.date.localDate() }.toSet()
        var streak = 0
        var cur = day
        while (cur in days) { streak++; cur = cur.minusDays(1) }
        val mon = day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        val weekCount = (before + r).count { val d = it.date.localDate(); !d.isBefore(mon) && d.isBefore(mon.plusDays(7)) }
        var pftPrevBest: Int? = null
        var pftEverGold = false
        if (r.mode == Mode.Pft) {
            val prev = before.filter { it.mode == Mode.Pft && it.counts && it.pftSplits != null }
            pftPrevBest = prev.minOfOrNull { it.total }
            pftEverGold = prev.any { PFT.grade(it.total) == PFTGrade.Gold }
        }
        return CheerInput(
            mode = r.mode, title = r.title, total = r.total, complete = r.isComplete,
            check = r.flag == RecordFlag.Check, start = r.date, end = r.end, seed = CheerPicker.seed(r.id),
            isHIIT = r.isHIIT, isRun = r.isRunKind, hiitRounds = if (r.isHIIT) r.segs.size else 0,
            runKm = r.runs.sumOf { it.dist ?: runMeters(it.detail) } / 1000,
            hiShare = if (r.source == "phone") null else CheerPicker.hiShare(r.hr, settings),
            firstEver = before.isEmpty(), firstFullSim = firstFullSim, goalDelta = goalDelta, pbDelta = pbDelta,
            lastDelta = lastDelta, segBest = segBest, daysToRace = daysToRace, daysSinceLast = daysSinceLast,
            streak = streak, weekCount = weekCount, pftPrevBest = pftPrevBest, pftEverGold = pftEverGold,
        )
    }
}
