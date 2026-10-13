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
    /** 요일 7칸(월…일): 그날 가장 오래 한 운동 종류(Mode raw), 없으면 "" */
    val dayMode: List<String> = List(7) { "" },
    /** 요일 7칸: 운동한 분 */
    val dayMin: List<Int> = List(7) { 0 },
) {
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

        /** 기록 목록으로 만들기. best = Full Sim · 레이스 최고 중 빠른 것 */
        fun make(records: List<Record>, settings: Settings, best: Int?, now: Instant): WidgetSnap {
            val ev = settings.event
            val today = now.atZone(Fm.zone).toLocalDate()
            val upcoming = ev.isSet && !ev.date.atZone(Fm.zone).toLocalDate().isBefore(today)
            val wk = monday(now)
            val these = records.filter { val d = it.date.atZone(Fm.zone).toLocalDate(); !d.isBefore(wk) && d.isBefore(wk.plusDays(7)) }
            val dayMin = (0 until 7).map { i -> these.filter { it.date.atZone(Fm.zone).toLocalDate() == wk.plusDays(i.toLong()) }.sumOf { it.total } / 60 }
            val dayMode = (0 until 7).map { i ->
                these.filter { it.date.atZone(Fm.zone).toLocalDate() == wk.plusDays(i.toLong()) }.maxByOrNull { it.total }?.mode?.raw ?: ""
            }
            return WidgetSnap(
                raceName = if (upcoming) ev.name else null, raceDate = if (upcoming) ev.date else null,
                division = settings.div.name, goal = settings.goalTime.takeIf { it > 0 }, best = best,
                weekStart = wk, weekCount = these.size, weekSec = these.sumOf { it.total }, weekKcal = these.sumOf { it.kcal },
                weekRunKm = these.flatMap { it.runs }.sumOf { it.dist ?: runMeters(it.detail) } / 1000,
                dayMode = dayMode, dayMin = dayMin,
            )
        }

        /** 화면 확인 · 위젯 고르는 화면의 미리보기용 예시 (아이폰 demo 와 같은 숫자) */
        fun demo(now: Instant, days: Int = 10): WidgetSnap = WidgetSnap(
            raceName = "Incheon", raceDate = now.plus(days.toLong(), ChronoUnit.DAYS), division = "Open Men", goal = 4320, best = 4565,
            weekStart = monday(now), weekCount = 3, weekSec = 9660, weekKcal = 1840, weekRunKm = 12.4,
            dayMode = listOf("training", "sim", "", "training", "", "", ""), dayMin = listOf(42, 78, 0, 34, 0, 0, 0),
        )
    }
}
