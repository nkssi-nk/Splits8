package com.nkssi.splits8.shared

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

// 배지 (아이폰 iOSApp/Badges.swift, 빌드 24 · 26) — 폰 안 기록만으로 계산 (서버 필요 없음).
// 묶음: ① 처음 해 보기 ② 기록 ③ 꾸준함. 예전 기록으로도 소급해서 받음 (기록 날짜 순서대로 다시 계산).
// 미완료 · 확인 필요 기록은 세지 않음.

data class Badge(
    val id: String,
    /** 묶음: first / record / habit */
    val group: String,
    val title: String,
    val sub: String,
    /** 아이폰 SF Symbol 이름 (안드로이드는 이 이름으로 그림을 고름) */
    val icon: String,
)

object Badges {
    val all: List<Badge> = listOf(
        // ① 처음 해 보기
        Badge("firstSim", "first", "First Full Sim", "Finish your first Full Simulation.", "flag.checkered"),
        Badge("firstRace", "first", "Race day", "Record your first HYROX race.", "medal"),
        Badge("firstPFT", "first", "First PFT", "Finish your first PFT.", "stopwatch"),
        Badge("allStations", "first", "All 8 stations", "Do every HYROX station at least once.", "square.grid.3x3.fill"),
        // ② 기록
        Badge("sub130", "record", "Sub 1:30", "Full Simulation or race under 1:30:00.", "timer"),
        Badge("sub120", "record", "Sub 1:20", "Full Simulation or race under 1:20:00.", "timer"),
        Badge("sub110", "record", "Sub 1:10", "Full Simulation or race under 1:10:00.", "bolt.fill"),
        Badge("sub100", "record", "Sub 1:00", "Full Simulation or race under 1:00:00.", "crown.fill"),
        Badge("pb1", "record", "First PB", "Beat your best Full Simulation for the first time.", "star.fill"),
        Badge("pb5", "record", "5 PBs", "Beat your best Full Simulation 5 times.", "arrow.up.right"),
        Badge("pb10", "record", "10 PBs", "Beat your best Full Simulation 10 times.", "chart.line.uptrend.xyaxis"),
        // ③ 꾸준함
        Badge("weeks4", "habit", "4 weeks in a row", "Work out at least once a week for 4 weeks.", "calendar"),
        Badge("month12", "habit", "12 in a month", "12 workouts in one calendar month.", "calendar.badge.checkmark"),
        Badge("run100", "habit", "100 km run", "Run 100 km in total across your workouts.", "figure.run"),
        Badge("run500", "habit", "500 km run", "Run 500 km in total across your workouts.", "road.lanes"),
    )

    val groups: List<Pair<String, String>> = listOf("first" to "FIRST STEPS", "record" to "RECORDS", "habit" to "CONSISTENCY")

    /** 받은 배지 → 받은 날 (그 기준을 처음 넘긴 기록의 날짜) */
    fun earned(records: List<Record>, zone: ZoneId = ZoneId.systemDefault()): Map<String, Instant> {
        val rs = records.filter { it.counts }.sortedBy { it.date }
        val got = LinkedHashMap<String, Instant>()
        fun give(id: String, d: Instant) { if (id !in got) got[id] = d }

        val stations = HashSet<String>()
        var best: Int? = null
        var pbs = 0
        var ranM = 0.0
        val weeks = ArrayList<LocalDate>()       // 운동한 주의 월요일 (중복 없이, 순서대로) — 아이폰 ISO 8601 달력
        val monthCount = HashMap<String, Int>()

        for (r in rs) {
            val full = r.mode == Mode.Sim || r.mode == Mode.Race
            // ① 처음 해 보기
            if (r.mode == Mode.Sim && r.isComplete) give("firstSim", r.date)
            if (r.mode == Mode.Race && r.isComplete) give("firstRace", r.date)
            if (r.mode == Mode.Pft && r.isComplete) give("firstPFT", r.date)
            for (s in r.segs) if (s.kind == SegKind.St && s.time > 0 && Station.of(s.icon) != null) stations.add(s.icon)
            if (stations.size >= Station.all.size) give("allStations", r.date)
            // ② 기록 (끝까지 한 풀 시뮬 · 레이스)
            if (full && r.isComplete && r.splits16 != null) {
                if (r.total < 5400) give("sub130", r.date)
                if (r.total < 4800) give("sub120", r.date)
                if (r.total < 4200) give("sub110", r.date)
                if (r.total < 3600) give("sub100", r.date)
            }
            if (r.mode == Mode.Sim && r.isComplete && r.splits16 != null) {
                best?.let { if (r.total < it) pbs += 1 }
                best = minOf(best ?: Int.MAX_VALUE, r.total)
                if (pbs >= 1) give("pb1", r.date)
                if (pbs >= 5) give("pb5", r.date)
                if (pbs >= 10) give("pb10", r.date)
            }
            // ③ 꾸준함
            for (s in r.segs) if (s.kind == SegKind.Run) ranM += s.dist ?: runMeters(s.detail)
            if (ranM >= 100_000) give("run100", r.date)
            if (ranM >= 500_000) give("run500", r.date)
            val day = r.date.atZone(zone).toLocalDate()
            val w = day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            if (weeks.lastOrNull() != w) {
                weeks.add(w)
                // 4주 연속 = 첫 주와 넷째 주 시작일이 3주 차이
                if (weeks.size >= 4 && weeks[weeks.size - 4].plusWeeks(3) == w) give("weeks4", r.date)
            }
            val mk = "%04d-%02d".format(day.year, day.monthValue)
            val n = (monthCount[mk] ?: 0) + 1
            monthCount[mk] = n
            if (n >= 12) give("month12", r.date)
        }
        return got
    }

    /** 이 기록으로 새로 받은 배지 (운동 끝 카드에 보여 줌) */
    fun new(rec: Record, records: List<Record>, zone: ZoneId = ZoneId.systemDefault()): List<Badge> {
        val before = earned(records.filter { it.id != rec.id }, zone)
        val after = earned(if (records.any { it.id == rec.id }) records else records + rec, zone)
        return all.filter { it.id in after && it.id !in before }
    }
}
