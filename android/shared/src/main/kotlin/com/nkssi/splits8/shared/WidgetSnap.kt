package com.nkssi.splits8.shared

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters

/**
 * 위젯이 보여 주는 요약 (아이폰 Shared/WidgetSnap.swift 와 같은 숫자).
 * 다음 대회 D-day · 목표 · 최고 기록 / 이번 주 (월요일 시작) 운동 수 · 시간 · 칼로리 · 러닝 km · 요일 막대
 */
data class WidgetSnap(
    val raceName: String? = null,
    val raceDate: Instant? = null,
    val division: String = "",
    val goal: Int? = null,
    val best: Int? = null,
    val weekStart: LocalDate = LocalDate.MIN,
    val weekCount: Int = 0,
    val weekSec: Int = 0,
    val weekKcal: Int = 0,
    val weekRunKm: Double = 0.0,
    /** 요일 7칸(월…일): 1.2.8 그날 운동 종류 "hyrox" / "run" (예전: Mode raw), 없으면 "" */
    val dayMode: List<String> = List(7) { "" },
    /** 요일 7칸: 운동한 분 */
    val dayMin: List<Int> = List(7) { 0 },
    /** 빌드 24: 앱 빛 색 (위젯 바탕 '테마 색'에 씀) */
    val themeHex: Long? = null,
    // MARK: 1.2.8 홈 위젯 오른쪽 칸 (Today 링 · 지난 4주 · 이번 주 · 최근 운동 · 최고 vs 목표) — 아이폰 WidgetSnap 과 같은 이름
    /** 오늘 (스냅 만든 날) */
    val day: LocalDate = LocalDate.MIN,
    /** 오늘 하이록스 연습 시간(초, 러닝만 한 운동 빼고) · 러닝 km (모든 운동) · 칼로리 */
    val todayHyroxSec: Int = 0,
    val todayRunKm: Double = 0.0,
    val todayKcal: Int = 0,
    /** 링이 꽉 차는 값 = 지난 28일 중 운동한 날의 하루 평균 (운동한 날 7일 미만이면 60분 · 5 km · 500 kcal) */
    val avgHyroxSec: Int = 3600,
    val avgRunKm: Double = 5.0,
    val avgKcal: Int = 500,
    /** 지난 4주 (3주 전 월요일부터 28칸): "" = 쉰 날 · "hyrox" = 하이록스 연습 · "run" = 러닝만 */
    val last28: List<String> = List(28) { "" },
    /** 지난 4주 운동 수 · 연속 운동한 날 (오늘 또는 어제까지) */
    val count28: Int = 0,
    val streak: Int = 0,
    /** 최근 운동: 이름 · hyrox/run · 날짜 · 시간 · 목표와 차이(초, 빠르면 음수 — 레이스 · 풀 시뮬만) */
    val lastName: String? = null,
    val lastKind: String = "hyrox",
    val lastDate: Instant? = null,
    val lastSec: Int = 0,
    val lastVsGoal: Int? = null,
    /** 최고 기록에서 목표보다 가장 늦은 구간: 짧은 이름 · hyrox/run · 차이(초) */
    val weakName: String? = null,
    val weakKind: String = "hyrox",
    val weakDiff: Int = 0,
) {
    /** 날이 바뀌었으면 오늘 숫자는 0 */
    fun todayFresh(now: Instant): WidgetSnap =
        if (now.atZone(Fm.zone).toLocalDate() == day) this else copy(todayHyroxSec = 0, todayRunKm = 0.0, todayKcal = 0)

    /** 남은 날 (오늘 = 0). 대회가 없거나 지났으면 null */
    fun daysLeft(now: Instant): Int? {
        val d = raceDate ?: return null
        val n = ChronoUnit.DAYS.between(now.atZone(Fm.zone).toLocalDate(), d.atZone(Fm.zone).toLocalDate()).toInt()
        return if (n >= 0) n else null
    }

    /** 이번 주가 지났으면 이번 주 숫자는 0 으로 봄 */
    fun fresh(now: Instant): WidgetSnap {
        val wk = monday(now)
        if (wk == weekStart) return this
        return copy(weekStart = wk, weekCount = 0, weekSec = 0, weekKcal = 0, weekRunKm = 0.0,
            dayMode = List(7) { "" }, dayMin = List(7) { 0 })
    }

    companion object {
        /** 그 주 월요일 */
        fun monday(now: Instant): LocalDate =
            now.atZone(Fm.zone).toLocalDate().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))

        /** D-day 단계: 30일 넘게 0 · 30일 안 1 · 10일 안 2 · 대회 날 3 (앱 홈의 대회 카드와 같은 단계) */
        fun stage(d: Int?): Int = when {
            d == null -> 0
            d == 0 -> 3
            d <= 10 -> 2
            d <= 30 -> 1
            else -> 0
        }

        /** 러닝만 한 운동 (러닝 카드 · 인터벌 러닝) */
        fun isRunOnly(r: Record): Boolean = r.kind == "run" || r.kind == "ivrun"
        private fun runKm(r: Record): Double = r.runs.sumOf { it.dist ?: runMeters(it.detail) } / 1000

        /** 그날 운동 종류: 하이록스 연습이 하나라도 있으면 "hyrox", 러닝만이면 "run", 없으면 "" */
        fun dayKind(rs: List<Record>): String = when {
            rs.isEmpty() -> ""
            rs.any { !isRunOnly(it) } -> "hyrox"
            else -> "run"
        }

        /** 짧은 구간 이름 (BBJ 등) */
        private val shortSt = listOf("SkiErg", "Sled Push", "Sled Pull", "BBJ", "Row", "Farmers", "Lunges", "Wall Balls")

        /** 기록 목록으로 만들기. best = Full Sim · 레이스 최고 중 빠른 것 (bestRec = 그 기록) */
        fun make(records: List<Record>, settings: Settings, best: Int?, now: Instant, bestRec: Record? = null): WidgetSnap {
            val ev = settings.event
            val today = now.atZone(Fm.zone).toLocalDate()
            val upcoming = ev.isSet && !ev.date.atZone(Fm.zone).toLocalDate().isBefore(today)
            val wk = monday(now)
            val these = records.filter { val d = it.date.atZone(Fm.zone).toLocalDate(); !d.isBefore(wk) && d.isBefore(wk.plusDays(7)) }
            val dayMin = (0 until 7).map { i -> these.filter { it.date.atZone(Fm.zone).toLocalDate() == wk.plusDays(i.toLong()) }.sumOf { it.total } / 60 }
            // 1.2.8: 요일 막대 색 = 그날 운동 종류 (하이록스 연습 "hyrox" 노랑 · 러닝만 "run" 파랑)
            val dayMode = (0 until 7).map { i -> dayKind(these.filter { it.date.atZone(Fm.zone).toLocalDate() == wk.plusDays(i.toLong()) }) }
            return WidgetSnap(
                raceName = if (upcoming) ev.name else null, raceDate = if (upcoming) ev.date else null,
                division = settings.div.name, goal = settings.goalTime.takeIf { it > 0 }, best = best,
                weekStart = wk, weekCount = these.size, weekSec = these.sumOf { it.total }, weekKcal = these.sumOf { it.kcal },
                weekRunKm = these.flatMap { it.runs }.sumOf { it.dist ?: runMeters(it.detail) } / 1000,
                dayMode = dayMode, dayMin = dayMin, themeHex = settings.glow.hex,
            ).withRight(records, settings, now, bestRec)
        }

        /** 1.2.8 오른쪽 칸 숫자 채우기 */
        private fun WidgetSnap.withRight(records: List<Record>, settings: Settings, now: Instant, bestRec: Record?): WidgetSnap {
            val today = now.atZone(Fm.zone).toLocalDate()
            fun on(d: LocalDate) = records.filter { it.date.atZone(Fm.zone).toLocalDate() == d }
            val todays = on(today)
            // 지난 28일 (오늘 빼고) 운동한 날 평균
            val past = (1..28).map { on(today.minusDays(it.toLong())) }.filter { it.isNotEmpty() }
            val enough = past.size >= 7
            fun avgD(f: (List<Record>) -> Double, def: Double): Double {
                if (!enough) return def
                val v = past.map(f).average()
                return if (v > 0) v else def
            }
            val aH = avgD({ d -> d.filter { !isRunOnly(it) }.sumOf { it.total }.toDouble() }, 3600.0)
            val aR = avgD({ d -> d.sumOf { runKm(it) } }, 5.0)
            val aK = avgD({ d -> d.sumOf { it.kcal }.toDouble() }, 500.0)
            // 지난 4주 칸 (3주 전 월요일부터, 앞으로 올 날은 "")
            val start = monday(now).minusDays(21)
            val l28 = (0 until 28).map { i -> val d = start.plusDays(i.toLong()); if (d.isAfter(today)) "" else dayKind(on(d)) }
            val c28 = records.count { val d = it.date.atZone(Fm.zone).toLocalDate(); !d.isBefore(start) && !d.isAfter(today) }
            var st = 0
            var d = if (on(today).isEmpty()) today.minusDays(1) else today
            while (on(d).isNotEmpty()) { st++; d = d.minusDays(1) }
            // 최근 운동
            val last = records.maxByOrNull { it.date }
            val lastVs = last?.let { r ->
                if (r.mode == Mode.Race || r.mode == Mode.Sim) (r.goal ?: settings.goalTime.takeIf { it > 0 })?.let { r.total - it } else null
            }
            // 최고 기록에서 목표보다 가장 늦은 구간 (러닝 8 · 스테이션 8, 목표 = 구간 목표)
            var wN: String? = null; var wK = "hyrox"; var wD = 0
            val sp = bestRec?.splits16
            val gs = settings.goals
            if (sp != null && gs.size == 16) {
                for (i in 0 until 16) {
                    val diff = sp[i] - gs[i]
                    if (diff > wD) {
                        wD = diff
                        if (i % 2 == 0) { wN = "Run ${i / 2 + 1}"; wK = "run" } else { wN = shortSt[i / 2]; wK = "hyrox" }
                    }
                }
            }
            return copy(
                day = today,
                todayHyroxSec = todays.filter { !isRunOnly(it) }.sumOf { it.total },
                todayRunKm = todays.sumOf { runKm(it) },
                todayKcal = todays.sumOf { it.kcal },
                avgHyroxSec = aH.toInt(), avgRunKm = aR, avgKcal = aK.toInt(),
                last28 = l28, count28 = c28, streak = st,
                lastName = last?.title, lastKind = if (last != null && isRunOnly(last)) "run" else "hyrox",
                lastDate = last?.date, lastSec = last?.total ?: 0, lastVsGoal = lastVs,
                weakName = wN, weakKind = wK, weakDiff = wD,
            )
        }

        /** 화면 확인 · 위젯 고르는 화면의 미리보기용 예시 (아이폰 demo 와 같은 숫자) */
        fun demo(now: Instant, days: Int = 10): WidgetSnap = WidgetSnap(
            raceName = "Incheon", raceDate = now.plus(days.toLong(), ChronoUnit.DAYS), division = "Open Men", goal = 4320, best = 4565,
            weekStart = monday(now), weekCount = 3, weekSec = 9660, weekKcal = 1840, weekRunKm = 12.4,
            dayMode = listOf("hyrox", "run", "", "hyrox", "", "", ""), dayMin = listOf(42, 78, 0, 34, 0, 0, 0),
            day = now.atZone(Fm.zone).toLocalDate(), todayHyroxSec = 2880, todayRunKm = 5.2, todayKcal = 520,
            avgHyroxSec = 3600, avgRunKm = 7.0, avgKcal = 600,
            last28 = listOf("run", "", "run", "", "hyrox", "", "", "run", "run", "", "hyrox", "", "run", "",
                "", "run", "", "run", "hyrox", "", "", "run", "", "hyrox", "", "", "", ""),
            count28 = 12, streak = 3, lastName = "Full Simulation", lastKind = "hyrox", lastDate = now.minus(2, ChronoUnit.DAYS),
            lastSec = 4360, lastVsGoal = -140, weakName = "Wall Balls", weakKind = "hyrox", weakDiff = 48,
        )
    }
}
