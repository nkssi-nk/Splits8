package com.nkssi.splits8.shared

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor

/** 아이폰 Fm (Shared/Theme.swift) — 시간 · 날짜 글자 */
object Fm {
    /** 1:15:03 / 4:21 */
    fun t(sec: Int): String {
        val s = maxOf(0, sec)
        val h = s / 3600
        val m = (s % 3600) / 60
        val x = s % 60
        return if (h > 0) "%d:%02d:%02d".format(Locale.ROOT, h, m, x) else "%d:%02d".format(Locale.ROOT, m, x)
    }

    fun t(sec: Double): String = t(floor(sec).toInt())

    /** ±0:00 / −0:27 / +2:46 (빼기는 진짜 빼기표 U+2212) */
    fun d(v: Int): String = if (v == 0) "±0:00" else (if (v < 0) "−" else "+") + t(abs(v))

    val zone: ZoneId get() = ZoneId.systemDefault()

    private val ymdF: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.ROOT)
    private val hmF: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT)

    /** 저장용 yyyy-MM-dd (이 기기 시간대) */
    fun ymd(i: Instant): String = ymdF.format(i.atZone(zone))
    fun ymdParse(s: String): Instant? = runCatching { LocalDate.parse(s, ymdF).atStartOfDay(zone).toInstant() }.getOrNull()
    fun hm(i: Instant): String = hmF.format(i.atZone(zone))

    /** 영어 날짜: 아이폰 en_GB 모양(일 · 월 순서)이지만 달 이름은 "Sep" (자바 en_GB 는 "Sept" 라서 ENGLISH 사용) */
    private fun df(en: String, ko: String, enLocale: Locale = Locale.ENGLISH): DateTimeFormatter =
        if (L10n.isKorean) DateTimeFormatter.ofPattern(ko, Locale.KOREAN)
        else DateTimeFormatter.ofPattern(en, enLocale)

    private fun fmt(i: Instant, en: String, ko: String, enLocale: Locale = Locale.ENGLISH) = df(en, ko, enLocale).format(i.atZone(zone))

    /** Wed 24 Sep / 9월 24일 (수) */
    fun wdm(i: Instant) = fmt(i, "EEE dd MMM", "M월 d일 (E)")
    /** Sat 13 Sep 2026 */
    fun wdmy(i: Instant) = fmt(i, "EEE dd MMM yyyy", "yyyy년 M월 d일 (E)")
    /** 13 Sep 2026 */
    fun dmy(i: Instant) = fmt(i, "d MMM yyyy", "yyyy년 M월 d일")
    /** 20 Sep 2026 (두 자리 일) */
    fun ddmy(i: Instant) = fmt(i, "dd MMM yyyy", "yyyy년 M월 d일")
    /** 14 JUN (그래프 축) */
    fun axis(i: Instant) = fmt(i, "dd MMM", "M월 d일").uppercase()
    /** 28 Sep */
    fun dm(i: Instant) = fmt(i, "d MMM", "M월 d일")
    /** Sep */
    fun mon(i: Instant) = fmt(i, "MMM", "M월")
    /** September 2026 */
    fun monthYear(i: Instant) = fmt(i, "MMMM yyyy", "yyyy년 M월")
    /** 9:00 AM / 오전 9:00 */
    fun time12(i: Instant) = fmt(i, "h:mm a", "a h:mm", Locale.US)
}
