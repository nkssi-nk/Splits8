package com.nkssi.splits8.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.localDate
import com.nkssi.splits8.shared.runMeters
import com.nkssi.splits8.ui.Avatar8
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.FlagPill
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.LightMode
import com.nkssi.splits8.ui.PFTBadge
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.SectionText
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowPill
import com.nkssi.splits8.ui.borderLight
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.gradeBorder
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.outerGlow
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters

// 아이폰 HomeViews.swift — 홈 (순서: 프로필 → 다음 대회 → 달력 → 주/월 요약 → 모드 → 최고 기록 → 최근 → 친구)

@Composable
fun HomeView() {
    var calMonth by remember { mutableStateOf(YearMonth.from(Store.today())) }
    var calSelected by remember { mutableStateOf<LocalDate?>(null) }
    var period by remember { mutableStateOf(Store.pref("home.summaryPeriod", "week")) }
    Scroll8 {
        Column(Modifier.padding(top = 6.dp).padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ProfileCard()
            SectionLabel("NEXT RACE")
            NextRace()
            SectionLabel("CALENDAR")
            HistoryCalendar(calMonth, calSelected, onMonth = { calMonth = it; calSelected = null }, onSelect = { calSelected = it })
            val iv = periodInterval(period != "month", calMonth, calSelected)
            SummaryHeader(period != "month", iv) { period = it; Store.setPref("home.summaryPeriod", it) }
            SummaryCard(period != "month", iv)
            SectionLabel("MODES")
            StartTiles()
            SectionLabel("PERSONAL BESTS")
            Bests()
            val rec = Store.records.sortedByDescending { it.date }.take(3)
            if (rec.isNotEmpty()) {
                SectionLabel("RECENT")
                Column(Modifier.card8()) {
                    rec.forEachIndexed { i, x -> RecentRow(x, i == rec.size - 1) }
                }
            }
            FriendsHeader()
            if (!Store.signedIn) {
                Row(Modifier.fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    T("Sign up to compare workouts and rankings with friends.", F.t(13, color = C.text2), Modifier.weight(1f))
                    YellowPill("Sign up") { Router.toAuth(Scr.Home) }
                }
            } else {
                RaceLeaderboard()
            }
        }
    }
}

// MARK: 프로필

@Composable
private fun ProfileCard() {
    val s = Store.settings
    val signed = Store.signedIn
    val nick = s.nickname.orEmpty()
    val grade = Store.book.pftGrade
    Row(
        // 빌드 26: 카드를 누르면 설정 › 프로필 (사진은 크게 보기 그대로)
        Modifier.fillMaxWidth().card8().gradeBorder(grade).tap { Router.go(Scr.Account) }.padding(vertical = 14.dp, horizontal = 16.dp).testTag("home.profile"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Avatar8(52.dp, if (signed) nick.take(1).uppercase() else "?", photo = Store.photo, bg = if (signed) C.accent else C.control,
            fg = if (signed) Color.Black else C.text2)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                T(if (signed) "@$nick" else "My profile".l10n, F.t(17, W600, tracking = -0.17f), Modifier.weight(1f, fill = false),
                    maxLines = 1, translate = false)
                if (grade != null) PFTBadge(grade)
            }
            T(s.div.name, F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        // 오른쪽 두 줄: 시간 / "★ PB · Full Sim" 등.
        // 91번(빌드 28): 무엇을 보일지 설정 › 프로필에서 고름 (HomeShow). 기본(자동) = 가장 최근에 세운 최고 기록, 없으면 목표 시간
        val hb = Store.book.homeBest()
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(Fm.t(hb.time), F.num(22, tracking = -0.44f), maxLines = 1, translate = false)
            if (hb.star) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    T("★", F.t(9, W600, C.accent), translate = false)
                    T(hb.tag, F.t(F.foot, W600, C.accent), maxLines = 1)
                    if (hb.sub.isNotEmpty()) T("· " + hb.sub.l10n, F.t(F.foot, color = C.text2), maxLines = 1, translate = false)
                }
            } else {
                T(hb.tag, F.t(F.foot, color = C.text2), maxLines = 1)
            }
        }
    }
}

// MARK: 다음 대회

private fun daysLeft(d: java.time.Instant): Int = ChronoUnit.DAYS.between(Store.today(), d.localDate()).toInt()

private fun dday(d: java.time.Instant): String {
    val n = daysLeft(d)
    return if (n == 0) "D-DAY" else if (n > 0) "D-$n" else "D+${-n}"
}

/** 대회 카드 단계: 0 = 31일 넘게 남음(또는 지남) · 1 = D-30~11 · 2 = D-10~8 · 3 = D-7~1 · 4 = D-DAY */
private fun raceStage(d: java.time.Instant): Int {
    val n = daysLeft(d)
    return when {
        n < 0 || n > 30 -> 0
        n == 0 -> 4
        n <= 7 -> 3
        n <= 10 -> 2
        else -> 1
    }
}

private fun eventSub(ev: RaceEvent): String = listOf(ev.loc, Fm.dm(ev.date)).filter { it.isNotEmpty() }.joinToString(" · ")

@Composable
private fun NextRace() {
    val ev = Store.settings.event
    if (!ev.isSet) {
        Row(Modifier.fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            T("No race added yet. Add one to start it right away from Race on your watch.", F.t(13, color = C.text2), Modifier.weight(1f))
            YellowPill("Add event") { Router.evDraft = Store.settings.event; Router.go(Scr.FindEvent) }
        }
        return
    }
    val stage = raceStage(ev.date)
    val intensity = listOf(0f, 0.38f, 0.65f, 1f, 1f)[stage]
    val lap = listOf(6f, 12f, 9f, 6f, 4f)[stage]
    val shape = RoundedCornerShape(20.dp)
    val y = Color(0xFFFFE600)
    val bg: Modifier = if (stage >= 2) {
        val fill = if (stage == 2) 0.07f else if (stage == 3) 0.20f else 0.30f
        val from = if (stage == 4) 0.1f else 0.3f
        val line = if (stage == 2) 0.20f else if (stage == 3) 0.38f else 0.55f
        val glow = if (stage == 2) 0f else if (stage == 3) 0.14f else 0.24f
        Modifier
            .then(if (glow > 0f) Modifier.outerGlow(y.copy(alpha = glow), 20.dp, if (stage == 4) 16.dp else 14.dp, 8.dp) else Modifier)
            .clip(shape)
            .background(Brush.horizontalGradient(from to Color.White.copy(alpha = 0.05f), 1f to y.copy(alpha = fill)))
            .border(1.dp, y.copy(alpha = line), shape)
    } else Modifier.card8()
    Row(
        Modifier.fillMaxWidth().then(bg)
            .borderLight(C.accent, if (stage == 0) LightMode.Off else LightMode.Loop, intensity = intensity, lapSec = lap,
                double = stage == 4, delayMs = if (Store.book.pftGrade == com.nkssi.splits8.shared.PFTGrade.Gold) 2000 else 300)
            .press { Router.go(Scr.Race) }
            .padding(vertical = 16.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f)) {
            T(ev.name, F.t(20, W600, tracking = -0.2f), maxLines = 1, translate = false)
            T(eventSub(ev), F.t(13, color = C.text2), Modifier.padding(top = 4.dp), maxLines = 1, translate = false)
            androidx.compose.foundation.text.BasicText(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = C.text2)) { append("Division".l10n + " · ") }
                    withStyle(SpanStyle(color = C.d1)) { append(Store.settings.div.name) }
                },
                Modifier.padding(top = 6.dp), style = F.t(13), maxLines = 1,
            )
        }
        T(dday(ev.date), F.num(34, color = C.accent, tracking = -1.02f), Modifier.testTag("home.dday"), maxLines = 1, translate = false)
    }
}

// MARK: 모드 · 최고 기록 · 최근

@Composable
private fun StartTiles() {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(
            Triple("Training", Mode.Training, "modeTraining"), Triple("PFT", Mode.Pft, "modePFT"),
            Triple("Full Sim", Mode.Sim, "i_sim"), Triple("Race", Mode.Race, "i_race"),
        ).forEach { (label, mode, icon) ->
            Column(
                Modifier.weight(1f).height(86.dp).card8().press(0.97f, tag = "home.start.$label") { Router.goMode(mode) },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
            ) {
                Icon8(icon, 28.dp, C.accent)
                T(label, F.t(13, W600), maxLines = 1)
            }
        }
    }
}

@Composable
private fun Bests() {
    val b = Store.book
    val sim = b.simBest
    val race = b.raceBest
    val pace = (b.records(Mode.Sim) + b.records(Mode.Race)).filter { it.counts }.mapNotNull { it.runPace }.minOrNull()
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        BestTile("FULL SIM", sim?.let { Fm.t(it.total) } ?: "--", sim?.let { Fm.dm(it.date) } ?: "No record".l10n)
        BestTile("RACE", race?.let { Fm.t(it.total) } ?: "--", race?.title?.l10n ?: "No record".l10n)
        val imp = Store.settings.imperial
        BestTile("RUN AVG", pace?.let { Fm.t(com.nkssi.splits8.shared.Units.pace(it, imp)) } ?: "--", (if (imp) "per mi" else "per km").l10n)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.BestTile(label: String, value: String, sub: String) {
    Column(Modifier.weight(1f).card8().padding(vertical = 14.dp, horizontal = 12.dp)) {
        Label8(label, spacing = 0.08f)
        T(value, F.num(20, tracking = -0.4f), Modifier.padding(top = 6.dp), maxLines = 1, translate = false)
        T(sub, F.t(F.foot, color = C.text3), Modifier.padding(top = 2.dp), maxLines = 1, translate = false)
    }
}

@Composable
private fun RecentRow(x: Record, last: Boolean) {
    val d = Fm.wdm(x.date)
    val sub = when (x.mode) {
        Mode.Training -> "Training".l10n + " · " + d
        Mode.Race -> "Race".l10n + " · " + d
        else -> d
    }
    val title = if (x.mode == Mode.Sim) "Full Simulation".l10n else x.title.l10n
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).rowLine(!last).tap { Router.goMode(x.mode) }.padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f).padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                T(title, F.t(15, W600), Modifier.weight(1f, fill = false), maxLines = 1, translate = false)
                x.pftGrade?.let { PFTBadge(it) }
                x.flag?.let { FlagPill(it) }
            }
            T(sub, F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        T(Fm.t(x.total), F.num(17, tracking = -0.34f), maxLines = 1, translate = false)
        Chevron8()
    }
}

// MARK: 친구

@Composable
private fun FriendsHeader() {
    Row(Modifier.fillMaxWidth().padding(top = 14.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        T(SectionText.shown("FRIENDS"), F.t(F.sub, W600), maxLines = 1, translate = false)
        Spacer(Modifier.weight(1f))
        val n = if (Store.signedIn) Store.incoming.size else 0
        if (n > 0) {
            Row(
                Modifier.height(28.dp).clip(CircleShape).background(C.accent)
                    .press(0.96f, tag = "home.friendRequests") { Router.friendsFrom = Scr.Home; Router.go(Scr.Friends) }
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                T(if (n == 1) L10n.t("1 request") else L10n.t("%lld requests", n), F.t(13, W600, Color.Black), maxLines = 1, translate = false)
                Chevron8(color = Color.Black)
            }
        }
    }
}

// MARK: 이번 주 / 이번 달 요약

/** [시작, 끝) 날짜 */
data class Period(val start: LocalDate, val end: LocalDate)

private fun weekOf(d: LocalDate): Period {
    val mon = d.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    return Period(mon, mon.plusDays(7))
}

/** 지금 보고 있는 기간 — 달력을 따라감. 월: 달력의 달. 주: 고른 날짜의 주 / 안 골랐으면 이번 달은 이번 주, 다른 달은 그 달 첫째 주 */
private fun periodInterval(week: Boolean, month: YearMonth, selected: LocalDate?): Period {
    if (!week) return Period(month.atDay(1), month.plusMonths(1).atDay(1))
    val today = Store.today()
    val anchor = selected ?: if (YearMonth.from(today) == month) today else month.atDay(1)
    return weekOf(anchor)
}

private fun recordsIn(p: Period): List<Record> = Store.records.filter {
    val d = it.date.localDate(); !d.isBefore(p.start) && d.isBefore(p.end)
}

@Composable
private fun SummaryHeader(week: Boolean, iv: Period, onPick: (String) -> Unit) {
    val today = Store.today()
    val title = when {
        !today.isBefore(iv.start) && today.isBefore(iv.end) -> if (week) "THIS WEEK" else "THIS MONTH"
        !week -> Fm.monthYear(iv.start.atStartOfDay(Fm.zone).toInstant())
        else -> Fm.dm(iv.start.atStartOfDay(Fm.zone).toInstant()) + " – " + Fm.dm(iv.end.minusDays(1).atStartOfDay(Fm.zone).toInstant())
    }
    Row(Modifier.fillMaxWidth().padding(top = 14.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        T(SectionText.shown(title), F.t(F.sub, W600), Modifier.testTag("home.summary.title"), maxLines = 1, translate = false)
        Spacer(Modifier.weight(1f))
        Seg8(listOf("week" to "Week", "month" to "Month"), if (week) "week" else "month", height = 28.dp, minWidth = 56.dp, onSelect = onPick)
    }
}

@Composable
private fun SummaryCard(week: Boolean, iv: Period) {
    val recs = recordsIn(iv)
    val secs = recs.sumOf { it.total }
    val kcal = recs.sumOf { it.kcal }
    val meters = recs.sumOf { x -> x.runs.sumOf { it.dist ?: runMeters(it.detail) } }
    Column(Modifier.fillMaxWidth().card8().padding(top = 16.dp, start = 18.dp, end = 18.dp, bottom = 14.dp).testTag("home.summary")) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatCell("Workouts", "${recs.size}", if (L10n.isKorean) "unit.workouts".l10n else "")
            StatCell("Time", "${secs / 3600}:" + "%02d".format((secs / 60) % 60), "h")
        }
        Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatCell("Calories", "%,d".format(java.util.Locale.US, kcal), "kcal")
            StatCell("Run distance", "%.1f".format(java.util.Locale.US, meters / 1000), "km")
        }
        BarChart(week, iv, Modifier.padding(top = 18.dp))
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.StatCell(label: String, value: String, unit: String) {
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        T(label, F.t(13, color = C.text2), maxLines = 1)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            T(value, F.num(28, tracking = -0.56f), maxLines = 1, translate = false)
            T(unit, F.t(13, W500, C.text2), Modifier.padding(bottom = 4.dp), maxLines = 1, translate = false)
        }
    }
}

/** M T W T F S S (한국어: 월 화 수 목 금 토 일) */
private fun monFirstLetters(): List<String> =
    if (L10n.isKorean) listOf("월", "화", "수", "목", "금", "토", "일") else listOf("M", "T", "W", "T", "F", "S", "S")

@Composable
private fun BarChart(week: Boolean, iv: Period, modifier: Modifier) {
    val ivs: List<Pair<String, Period>> = if (week) {
        monFirstLetters().mapIndexed { i, l -> l to Period(iv.start.plusDays(i.toLong()), iv.start.plusDays(i + 1L)) }
    } else {
        val out = ArrayList<Pair<String, Period>>()
        var cursor = iv.start
        var n = 1
        while (cursor.isBefore(iv.end) && n <= 6) {
            val wk = weekOf(cursor)
            val s = maxOf(wk.start, iv.start)
            val e = minOf(wk.end, iv.end)
            if (e.isAfter(s)) out.add(L10n.t("W%lld", n) to Period(s, e))
            cursor = wk.end
            n++
        }
        out
    }
    val bars = ivs.map { (l, p) ->
        val recs = recordsIn(p)
        val byMode = Mode.entries.associateWith { m -> recs.filter { it.mode == m }.sumOf { it.total } }
        val top = Mode.entries.maxByOrNull { byMode[it] ?: 0 } ?: Mode.Training
        Triple(l, recs.sumOf { it.total }, hex(top.calendarHex))
    }
    val mx = maxOf(1, bars.maxOfOrNull { it.second } ?: 1)
    val maxH = 26f
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
        bars.forEach { (label, secs, color) ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(Modifier.fillMaxWidth().height(maxH.dp), contentAlignment = Alignment.BottomCenter) {
                    val h = if (secs > 0) maxOf(6f, maxH * secs / mx) else 2f
                    Box(Modifier.fillMaxWidth().height(h.dp).clip(RoundedCornerShape(if (secs > 0) 4.dp else 1.dp))
                        .background(if (secs > 0) color else Color.White.copy(alpha = 0.14f)))
                }
                T(label, F.t(F.cap2, W500, C.text3), maxLines = 1, translate = false)
            }
        }
    }
}

