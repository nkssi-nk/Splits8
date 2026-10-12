package com.nkssi.splits8.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PlanReminder
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.localDate
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.HistoryRow
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.WeekFields
import java.util.Locale

// 아이폰 CalendarViews.swift — 홈 달력: 채운 점 = 기록, 빈 링 = 예약, 깃발 = 대회 날.
// 날짜를 누르면 아래에 그날 기록·예약이 펼쳐지고, 같은 날짜를 다시 누르면 접힘. 좌우로 밀면 달 넘김

private val raceColor = hex(Mode.Race.calendarHex)

private fun modeLabel(m: Mode) = when (m) {
    Mode.Training -> "Training"
    Mode.Pft -> "PFT"
    Mode.Sim -> "Full Sim"
    Mode.Race -> "Race"
}

private fun LocalDate.instant(): Instant = atStartOfDay(Fm.zone).toInstant()

private fun isRaceDay(d: LocalDate): Boolean {
    val ev = Store.settings.event
    return ev.isSet && ev.date.localDate() == d
}

@Composable
fun HistoryCalendar(month: YearMonth, selected: LocalDate?, onMonth: (YearMonth) -> Unit, onSelect: (LocalDate?) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CalendarCard(month, selected, onMonth, onSelect)
        if (selected != null) DaySection(selected)
    }
}

@Composable
private fun CalendarCard(month: YearMonth, selected: LocalDate?, onMonth: (YearMonth) -> Unit, onSelect: (LocalDate?) -> Unit) {
    val drag = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    Column(
        Modifier.fillMaxWidth().card8()
            .pointerInput(month) {
                detectHorizontalDragGestures(
                    onDragEnd = {
                        val dx = with(density) { drag.value.toDp().value }
                        if (dx <= -44) onMonth(month.plusMonths(1)) else if (dx >= 44) onMonth(month.minusMonths(1))
                        scope.launch { drag.animateTo(0f, tween(250)) }
                    },
                    onDragCancel = { scope.launch { drag.animateTo(0f, tween(250)) } },
                ) { _, amount -> scope.launch { drag.snapTo(drag.value + amount) } }
            }
            .padding(top = 14.dp, start = 14.dp, end = 14.dp, bottom = 10.dp),
    ) {
        // 달 이름 줄
        Row(Modifier.fillMaxWidth().padding(bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp, 32.dp).tap { onMonth(month.minusMonths(1)) }.testTag("cal.prev"), contentAlignment = Alignment.Center) {
                Glyph("i_chevL", 18.dp, C.accent)
            }
            Spacer(Modifier.weight(1f))
            T(Fm.monthYear(month.atDay(1).instant()), F.t(17, W600), Modifier.testTag("cal.month"), maxLines = 1, translate = false)
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(40.dp, 32.dp).tap { onMonth(month.plusMonths(1)) }.testTag("cal.next"), contentAlignment = Alignment.Center) {
                Glyph("i_chevR", 18.dp, C.accent)
            }
        }
        val first = WeekFields.of(Locale.getDefault()).firstDayOfWeek
        // 요일 머리글
        val letters = if (L10n.isKorean) listOf("일", "월", "화", "수", "목", "금", "토") else listOf("S", "M", "T", "W", "T", "F", "S")
        val k = first.value % 7   // 일요일 = 0
        Row(Modifier.fillMaxWidth().padding(bottom = 6.dp)) {
            for (i in 0 until 7) T(letters[(k + i) % 7], F.t(11, color = C.text2), Modifier.weight(1f), align = androidx.compose.ui.text.style.TextAlign.Center, translate = false)
        }
        // 숫자판 (달이 넘어가면 옆으로 밀려 나가고 새 달이 반대쪽에서 들어옴)
        AnimatedContent(
            month,
            Modifier.fillMaxWidth().graphicsLayer {
                translationX = drag.value * 0.6f
                alpha = 1f - minOf(0.5f, kotlin.math.abs(drag.value) / with(density) { 300.dp.toPx() })
            },
            transitionSpec = {
                val d = if (targetState > initialState) 1 else -1
                (slideInHorizontally(tween(320)) { it * d } + fadeIn(tween(320))) togetherWith
                    (slideOutHorizontally(tween(320)) { -it * d } + fadeOut(tween(320)))
            },
            label = "month",
        ) { m -> Grid(m, first.value, selected, onSelect) }
        Legend(Modifier.padding(top = 10.dp))
    }
}

@Composable
private fun Grid(month: YearMonth, firstDow: Int, selected: LocalDate?, onSelect: (LocalDate?) -> Unit) {
    val lead = (month.atDay(1).dayOfWeek.value - firstDow + 7) % 7
    val n = month.lengthOfMonth()
    val cells = ArrayList<Int>()
    repeat(lead) { cells.add(0) }
    for (d in 1..n) cells.add(d)
    while (cells.size % 7 != 0) cells.add(0)
    val today = Store.today()
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for (w in 0 until cells.size / 7) {
            Row(Modifier.fillMaxWidth()) {
                for (c in 0 until 7) {
                    val day = cells[w * 7 + c]
                    if (day == 0) {
                        Spacer(Modifier.weight(1f).height(41.dp))
                    } else {
                        val d = month.atDay(day)
                        DayCell(d, d == selected, d == today, Modifier.weight(1f)) { onSelect(if (d == selected) null else d) }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(d: LocalDate, isSel: Boolean, isToday: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val raceDay = isRaceDay(d)
    Column(modifier.tap(onClick = onClick).testTag("cal.day.${d.dayOfMonth}"), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)) {
        val bg = when {
            isSel -> C.accent
            raceDay -> raceColor.copy(alpha = 0.22f)
            else -> Color.Transparent
        }
        var m = Modifier.size(32.dp).clip(CircleShape).background(bg)
        if (raceDay && !isSel) m = m.border(1.5.dp, raceColor, CircleShape)
        else if (isToday && !isSel) m = m.border(1.dp, C.accent, CircleShape)
        Box(m, contentAlignment = Alignment.Center) {
            T("${d.dayOfMonth}", F.num(15, if (isSel) W600 else W400, if (isSel) Color.Black else Color.White), translate = false)
        }
        // 표시: 그날 한 운동 종류별 점 / 대회 깃발 / 예약 링
        val recs = Store.records(d)
        Box(Modifier.height(7.dp), contentAlignment = Alignment.Center) {
            when {
                recs.isNotEmpty() -> Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    Mode.entries.filter { m2 -> recs.any { it.mode == m2 } }.forEach {
                        Box(Modifier.size(6.dp).clip(CircleShape).background(hex(it.calendarHex)))
                    }
                }
                raceDay -> Glyph("i_race", 9.dp, raceColor)
                else -> Store.plans(d).firstOrNull()?.let {
                    Box(Modifier.size(7.dp).border(1.5.dp, hex(it.mode.calendarHex), CircleShape))
                }
            }
        }
    }
}

/** 한 줄에 들어가면 한 줄, 안 들어가면 두 줄 (모드들 / Planned · Race day) */
@Composable
private fun Legend(modifier: Modifier) {
    val measurer = rememberTextMeasurer()
    val style = F.t(13, color = C.text2)
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        val labels = Mode.entries.map { modeLabel(it).l10n } + listOf("Planned".l10n, "Race day".l10n)
        val density = LocalDensity.current
        val textW = labels.sumOf { measurer.measure(it, style).size.width }
        val need = with(density) { textW.toDp() } + (12 * (labels.size - 1) + 12 * labels.size).dp
        if (need <= maxWidth) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { ModeItems(); ExtraItems() }
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { ModeItems() }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { ExtraItems() }
            }
        }
    }
}

@Composable
private fun ModeItems() {
    Mode.entries.forEach { m ->
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(hex(m.calendarHex)))
            T(modeLabel(m), F.t(13, color = C.text2), maxLines = 1)
        }
    }
}

@Composable
private fun ExtraItems() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(7.dp).border(1.5.dp, C.text2, CircleShape))
        T("Planned", F.t(13, color = C.text2), maxLines = 1)
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Glyph("i_race", 10.dp, raceColor)
        T("Race day", F.t(13, color = C.text2), maxLines = 1)
    }
}

// MARK: 고른 날

@Composable
private fun DaySection(sel: LocalDate) {
    val recs = Store.records(sel)
    val plans = Store.plans(sel)
    val race = isRaceDay(sel)
    val past = sel.isBefore(Store.today())
    SectionLabel(Fm.wdm(sel.instant()), Modifier.testTag("cal.dayLabel"), top = 10.dp)
    if (recs.isNotEmpty()) {
        Column(Modifier.card8()) { recs.forEachIndexed { i, r -> RecordRow(r, i == recs.size - 1) } }
    }
    if (plans.isNotEmpty() || race) {
        Column(Modifier.card8()) {
            if (race) RaceRow(last = plans.isEmpty())
            plans.forEachIndexed { i, p -> PlanRow(p, i == plans.size - 1) }
        }
    }
    if (recs.isEmpty() && plans.isEmpty() && !race && past) {
        T("No records on this day", F.t(13, color = C.text2), Modifier.fillMaxWidth().card8().padding(vertical = 18.dp),
            align = androidx.compose.ui.text.style.TextAlign.Center)
    }
    if (!past) {
        YellowButton("＋ Plan a workout on this day", Modifier.padding(top = 4.dp), height = 44.dp, radius = 22.dp, tag = "cal.planButton") {
            // 예약 시트는 다음 단계 (PlanSheet)
        }
    }
}

@Composable
private fun RecordRow(rec: Record, last: Boolean) {
    val title = when (rec.mode) {
        Mode.Training -> if (rec.kind != null) rec.title.l10n else "${rec.title.l10n} × ${rec.sets}"
        Mode.Sim -> "Full Simulation".l10n
        else -> rec.title.l10n
    }
    HistoryRow(title, Fm.wdm(rec.date) + " · " + Fm.time12(rec.date), Fm.t(rec.total), last = last,
        pb = Store.book.isPB(rec), flag = rec.flag, grade = rec.pftGrade, partner = rec.partner) { Router.open(rec, Scr.Home) }
}

private fun planSub(p: PlannedWorkout): String {
    var s = "Planned".l10n + " · " + Fm.time12(p.date)
    if (p.reminder != PlanReminder.None) s += " · " + p.reminder.short.l10n
    return s
}

@Composable
private fun PlanRow(p: PlannedWorkout, last: Boolean) {
    Row(Modifier.fillMaxWidth().rowLine(!last).padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(8.dp).border(1.5.dp, hex(p.mode.calendarHex), CircleShape))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(p.title, F.t(15, W600), maxLines = 1)
            T(planSub(p), F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Chevron8()
    }
}

@Composable
private fun RaceRow(last: Boolean) {
    val ev = Store.settings.event
    Row(Modifier.fillMaxWidth().rowLine(!last).tap { Router.go(Scr.SetEvent) }.padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Glyph("i_race", 14.dp, raceColor)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(ev.name, F.t(15, W600), maxLines = 1, translate = false)
            T("Race day", F.t(13, color = C.text2), maxLines = 1)
        }
        Chevron8()
    }
}
