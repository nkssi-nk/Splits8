package com.nkssi.splits8.screens

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.EventItem
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.GoalSplit
import com.nkssi.splits8.shared.HyroxBench
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.EmptyHistory
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Field8
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.HistoryHeader
import com.nkssi.splits8.ui.HistoryRow
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.PagedCard
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SearchField8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.SettingRow
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.Wheel8
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import java.time.LocalDate
import java.time.LocalTime
import java.time.YearMonth
import java.time.temporal.ChronoUnit

// 아이폰 SimRaceViews.swift 의 RaceView · GoalTimeSheet, EventViews.swift (대회 · 대회 찾기),
// SettingsViews.swift 의 SetGoalsView (구간 목표), DoublesPlanViews.swift (더블 구간 나누기)

// MARK: - I4 레이스 탭

@Composable
fun RaceView() {
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            GoalCard()
            PredictCard()
            RaceRowsCard()
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { StartOnPhoneButton(Mode.Race, null) }
            // 친구 순위표는 홈의 FRIENDS 로 옮김 (아이폰 빌드 20)
            HistoryHeader()
            val recs = Store.book.records(Mode.Race)
            if (recs.isEmpty()) {
                EmptyHistory()
            } else {
                PagedCard(recs.size) { i, last ->
                    val rec = recs[i]
                    val d = rec.total - (rec.goal ?: Store.settings.goalTime)
                    HistoryRow(rec.title, Fm.wdmy(rec.date), Fm.t(rec.total), delta = Fm.d(d) + " " + "vs goal".l10n,
                        deltaColor = if (d < 0) C.good else C.bad, last = last, pb = Store.book.isPB(rec), flag = rec.flag,
                        partner = rec.partner, onDelete = { Store.delete(rec) }) { Router.open(rec, Scr.Race) }
                }
            }
        }
    }
}

/** GOAL 카드: 목표 시간 52 · 오른쪽 최고 기록과의 차이 · Goal/Best 막대 · 한 줄 안내 */
@Composable
private fun GoalCard() {
    val goal = Store.settings.goalTime
    val best = Store.book.raceBest?.total
    Column(Modifier.fillMaxWidth().card8().padding(top = 20.dp, start = 18.dp, end = 18.dp, bottom = 18.dp).testTag("race.goal"),
        verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Label8("GOAL")
                T(Fm.t(goal), F.num(52, tracking = -2.34f), maxLines = 1, translate = false)
            }
            Column(Modifier.padding(top = 2.dp), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(Modifier.height(26.dp).clip(CircleShape).background(Color(0x24FFE600)).padding(horizontal = 10.dp), contentAlignment = Alignment.Center) {
                    T(best?.let { Fm.d(goal - it) } ?: "--:--", F.num(15, color = C.accent), maxLines = 1, translate = false)
                }
                T("vs best", F.t(F.foot, color = C.text3), maxLines = 1)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            GoalBar("Goal", best?.let { minOf(1f, goal.toFloat() / maxOf(1, it)) } ?: 1f, C.accent, Fm.t(goal), Color.White)
            GoalBar("Best", if (best == null) 0f else 1f, Color.White.copy(alpha = 0.35f), best?.let { Fm.t(it) } ?: "--:--", C.text2)
        }
        val line = when {
            best == null -> "Once you have a race record, we'll compare it with your best".l10n
            best > goal -> L10n.t("Cut an average of %lld sec from each of the 16 splits", kotlin.math.round((best - goal) / 16.0).toInt())
            best < goal -> L10n.t("%@ of room compared with your best", Fm.t(goal - best))
            else -> "Same as your best".l10n
        }
        T(line, F.t(F.sub, color = C.text3),
            Modifier.fillMaxWidth().drawBehind { drawLine(C.line, Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx()) }.padding(top = 12.dp),
            translate = false)
    }
}

/** 44 | 막대 | 64, 막대 4 높이 */
@Composable
private fun GoalBar(t: String, frac: Float, fill: Color, value: String, valueColor: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        T(t, F.t(13, W500, C.text2), Modifier.width(44.dp), maxLines = 1)
        Box(Modifier.weight(1f).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(alpha = 0.08f))) {
            Box(Modifier.fillMaxWidth(frac.coerceIn(0f, 1f)).fillMaxHeight().clip(RoundedCornerShape(2.dp)).background(fill))
        }
        T(value, F.num(15, color = valueColor), Modifier.width(64.dp), maxLines = 1, align = TextAlign.End, translate = false)
    }
}

/** 설정 줄 카드: Event › · Division › · (더블이면) Doubles plan › · Goal time › · Split targets (16 막대) */
@Composable
private fun RaceRowsCard() {
    val s = Store.settings
    val e = s.event
    Column(Modifier.fillMaxWidth().card8()) {
        RaceRow("Event", if (e.isSet) "${e.name} · ${Fm.wdmy(e.date)} ›" else "Not set".l10n + " ›") {
            Router.evDraft = null; Router.go(Scr.SetEvent)
        }
        RaceRow("Division", "${s.div.name} ›") { Router.sub(Scr.SetDiv, Scr.Race) }
        if (s.division.startsWith("dbl")) {
            RaceRow("Doubles plan", if (s.doublesPlan?.isDefault != false) "50:50 ›" else "Custom".l10n + " ›") { Router.raceSheet = "doubles" }
        }
        RaceRow("Goal time", Fm.t(s.goalTime) + " ›", numeric = true) { Router.raceSheet = "goal" }
        // 누르면 구간별 목표 고치는 화면
        Column(Modifier.fillMaxWidth().tap { Router.go(Scr.SetGoals) }.testTag("race.splitTargets")
            .padding(top = 14.dp, start = 18.dp, end = 18.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row {
                T("Split targets", F.t(17), Modifier.weight(1f), maxLines = 1)
                T("Edit".l10n + " ›", F.t(17, color = C.text2), maxLines = 1, translate = false)
            }
            SplitBars(s.goals, 40) { minOf(1f, maxOf(0f, it / 335f)) }
        }
    }
}

@Composable
private fun RaceRow(t: String, value: String, numeric: Boolean = false, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().rowLine(true).tap(onClick = onClick).testTag("race.$t").padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        T(t, F.t(17), maxLines = 1)
        Spacer(Modifier.weight(1f))
        T(value, if (numeric) F.num(17, W400, C.text2) else F.t(17, color = C.text2), maxLines = 1, translate = false)
    }
}

/** 16 막대 (gap 3): 러닝 #2C2C2E · 스테이션 노랑. frac = 칸 높이 비율 */
@Composable
private fun SplitBars(g: List<Int>, h: Int, frac: (Float) -> Float) {
    Row(Modifier.fillMaxWidth().height(h.dp), horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.Bottom) {
        g.forEachIndexed { i, t ->
            Box(Modifier.weight(1f).fillMaxHeight(frac(t.toFloat())).background(if (i % 2 == 0) C.control else C.accent))
        }
    }
}

// MARK: - Goal time 시트 → 구간 목표를 같은 비율로 나눔

@Composable
fun GoalTimeSheet() {
    val s = Store.settings
    var h by remember { mutableIntStateOf(s.goalTime / 3600) }
    var m by remember { mutableIntStateOf((s.goalTime % 3600) / 60) }
    var sec by remember { mutableIntStateOf(s.goalTime % 60) }
    var style by remember { mutableStateOf("keep") }
    val total = h * 3600 + m * 60 + sec
    val best = Store.book.simBest?.splits16
    val styles = GoalSplit.styles.filter { it != "best" || best != null }
    // 이동 목표: 그 시간대 실제 중간값 (2026-10-12 결정 — 30초 고정 대신)
    val roxEach = HyroxBench.roxEach(maxOf(600, total), s.division)
    val preview = GoalSplit.split(maxOf(600, total), style, s.goals, best, s.division, roxEach)

    fun save() {
        if (total > 600) {
            Store.update { it.copy(roxGoal = roxEach, goals = GoalSplit.split(total, style, it.goals, best, it.division, roxEach), goalTime = total) }
        }
        Router.raceSheet = null
    }

    Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        NavBar3("Cancel", "Goal time", right = "Save", edgeBack = false, onLeft = { Router.raceSheet = null }, onRight = { save() })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Wheel8((0..2).toList(), h, Modifier.weight(1f), { "$it " + unit("unit.h", "h") }, "goal.h") { h = it }
            Wheel8((0..59).toList(), m, Modifier.weight(1f), { "$it " + unit("unit.m", "m") }, "goal.m") { m = it }
            Wheel8((0..59).toList(), sec, Modifier.weight(1f), { "$it " + unit("unit.s", "s") }, "goal.s") { sec = it }
        }
        // 구간으로 나누는 방식: 지금 비율 · 균형형 · 러너형 · 근력형 · 내 최고 기록 비율
        Seg8(styles.map { it to GoalSplit.name(it) }, style, Modifier.fillMaxWidth().testTag("goal.style"), height = 34.dp, radius = 11.dp) { style = it }
        val mx = maxOf(1, preview.maxOrNull() ?: 1).toFloat()
        Box(Modifier.fillMaxWidth().card8(14.dp).padding(vertical = 12.dp, horizontal = 14.dp).testTag("goal.preview")) {
            SplitBars(preview, 44) { maxOf(0.08f, it / mx) }
        }
        T(GoalSplit.note(style), F.t(13, color = C.text3))
    }
}

/** 단위 글자: 한국어 표에 있으면 그것(시간 · 분 · 초), 없으면 영어 기본값 (아이폰 defaultValue) */
fun unit(key: String, def: String): String = L10n.t(key).let { if (it == key) def else it }

// MARK: - 더블 구간 나누기 시트 (디비전이 더블일 때만)

@Composable
fun DoublesPlanSheet() {
    var plan by remember { mutableStateOf(Store.settings.doublesPlan ?: DoublesPlan()) }
    val ctx = LocalContext.current
    Column(Modifier.padding(horizontal = 16.dp)) {
        NavBar3("Cancel", "Doubles plan", right = "Save", edgeBack = false, onLeft = { Router.raceSheet = null }, onRight = {
            // 반반이면 비워 둠 (아이폰 저장 파일과 같은 모양)
            val p = plan
            Store.update { it.copy(doublesPlan = if (p.isDefault) null else p) }
            Router.raceSheet = null
        })
        Column(Modifier.verticalScroll(rememberScrollState()).padding(top = 14.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Note8("Set how much of each station you take — your partner does the rest. 10% steps.")
            Column(Modifier.fillMaxWidth().card8()) {
                for (i in 0 until 8) {
                    val st = Station.all[i]
                    Row(Modifier.fillMaxWidth().rowLine(i < 7).padding(vertical = 12.dp, horizontal = 16.dp).testTag("dbl." + st.key),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon8(st.key, 20.dp, C.accent)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            T(st.name, F.t(15, W600), maxLines = 1)
                            T(plan.splitText(i), F.t(13, color = C.text2), maxLines = 1, translate = false)
                        }
                        Stepper8("${plan.share(i)}%", minWidth = 48.dp, fontSize = 15, button = 28.dp, radius = 8.dp, gap = 6.dp,
                            down = { plan = plan.set(i, plan.share(i) - 10) }, up = { plan = plan.set(i, plan.share(i) + 10) })
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.08f))
                    .press(tag = "dbl.reset") { plan = DoublesPlan() }, contentAlignment = Alignment.Center) {
                    T("Reset 50:50", F.t(15, W600), maxLines = 1)
                }
                // 계획을 글로 만들어 파트너에게 보내기 (안드로이드 공유 창)
                Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(14.dp)).background(C.accent)
                    .press(tag = "dbl.share") {
                        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, plan.shareText)
                        runCatching { ctx.startActivity(Intent.createChooser(send, null)) }
                    }, contentAlignment = Alignment.Center) {
                    T("Share as text", F.t(15, W600, Color.Black), maxLines = 1)
                }
            }
            Note8("In Doubles, you run all 8 runs together. Only stations are split.")
        }
    }
}

// MARK: - I4b 대회 (자체 머리줄 Cancel · Race event · Save, 달력 · 시간은 카드 안에서 바로 고르기)

@Composable
fun SetEventView() {
    LaunchedEffect(Unit) { if (Router.evDraft == null) Router.evDraft = Store.settings.event }
    // 서버의 대회 목록 (없거나 실패하면 앱에 들어 있는 목록)
    LaunchedEffect(Unit) { com.nkssi.splits8.Cloud.refreshEvents() }
    val ev = Router.evDraft ?: Store.settings.event
    fun set(f: (RaceEvent) -> RaceEvent) { Router.evDraft = f(Router.evDraft ?: Store.settings.event) }
    var pick by remember { mutableStateOf<String?>(null) }

    val askNotify = com.nkssi.splits8.rememberAskNotifications()
    fun save() {
        if (!ev.isSet) return
        askNotify()                             // 대회 알림 (일주일 전 · 전날)을 처음 쓸 때 허락
        Store.update { it.copy(event = ev) }
        Router.evDraft = null
        Router.go(Scr.Race)
    }

    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            NavBar3("Cancel", "Race event", right = "Save", rightColor = if (ev.isSet) C.accent else C.g3A,
                onLeft = { Router.evDraft = null; Router.go(Scr.Race) }, onRight = { save() })

            // 대회 찾기 카드 (노란 36 정사각 + 돋보기)
            Row(Modifier.padding(top = 6.dp).fillMaxWidth().card8().press(tag = "ev.find") { Router.go(Scr.FindEvent) }
                .padding(vertical = 14.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(C.accent), contentAlignment = Alignment.Center) {
                    Glyph("i_searchB", 18.dp, Color.Black)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T("Find event", F.t(17, W600), maxLines = 1)
                    T("Pick from upcoming events", F.t(13, color = C.text2), maxLines = 1)
                }
                Chevron8()
            }

            SectionLabel("EVENT", top = 6.dp)
            Field8("Event name (e.g. Incheon)", ev.name, Modifier.testTag("ev.name")) { v -> set { it.copy(name = v) } }
            Field8("Venue / City", ev.loc, Modifier.testTag("ev.loc")) { v -> set { it.copy(loc = v) } }

            SectionLabel("DATE & WAVE", top = 14.dp)
            Column(Modifier.fillMaxWidth().card8()) {
                PickRow("Date", Fm.wdmy(ev.date), pick == "date") { pick = if (pick == "date") null else "date" }
                AnimatedVisibility(pick == "date") {
                    EventCalendar(ev.date.atZone(Fm.zone).toLocalDate()) { d ->
                        set { it.copy(date = d.atStartOfDay(Fm.zone).toInstant()) }; pick = null
                    }
                }
                PickRow("Start time", timeLabel(ev), pick == "time") { pick = if (pick == "time") null else "time" }
                AnimatedVisibility(pick == "time") { EventTimeGrid(ev) { t -> set { it.copy(time = t) } } }
                Row(Modifier.fillMaxWidth().tap { Router.sub(Scr.SetDiv, Scr.SetEvent) }.testTag("ev.Division").padding(vertical = 14.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    T("Division", F.t(17), Modifier.weight(1f), maxLines = 1)
                    T("${Store.settings.div.name} ›", F.t(17, color = C.text2), maxLines = 1, translate = false)
                }
            }
            Note8("Once saved, the event name, date and division appear on the Race start screen on your watch.", Modifier.padding(top = 4.dp))
        }
    }
}

/** 시간 "09:00" → 9:00 AM (한국어: 오전 9:00) */
private fun hm12(ev: RaceEvent): String {
    val p = ev.time.split(":").mapNotNull { it.toIntOrNull() }
    val t = LocalTime.of(p.getOrElse(0) { 9 }.coerceIn(0, 23), p.getOrElse(1) { 0 }.coerceIn(0, 59))
    return Fm.time12(LocalDate.of(2026, 1, 1).atTime(t).atZone(Fm.zone).toInstant())
}

private fun timeLabel(ev: RaceEvent): String = if (ev.hasTime) hm12(ev) else "Not set".l10n

/** 값 알약: 34 높이, 좌우 12, 모서리 8, 17 숫자. 열리면 노란 0.16 바탕 + 노란 글자 */
@Composable
private fun PickRow(t: String, value: String, open: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().rowLine(true).padding(vertical = 10.dp, horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
        T(t, F.t(17), Modifier.weight(1f), maxLines = 1)
        Box(Modifier.height(34.dp).clip(RoundedCornerShape(8.dp)).background(if (open) Color(0x29FFE600) else Color.White.copy(alpha = 0.08f))
            .tap(onClick = onClick).testTag("ev.$t").padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
            T(value, F.num(17, W400, if (open) C.accent else Color.White), maxLines = 1, translate = false)
        }
    }
}

/** 달력 (일요일부터): 40 칸 · 36 원 · 17. 고른 날 = 노랑 + 검정, 오늘 = 노란 글자, 지난 날 = 흐리게(못 고름) */
@Composable
private fun EventCalendar(selected: LocalDate, onPick: (LocalDate) -> Unit) {
    var month by remember { mutableStateOf(YearMonth.from(selected)) }
    val today = Store.today()
    val dow = if (L10n.isKorean) listOf("일", "월", "화", "수", "목", "금", "토") else listOf("S", "M", "T", "W", "T", "F", "S")
    Column(Modifier.fillMaxWidth().rowLine(true).padding(top = 12.dp, start = 14.dp, end = 14.dp, bottom = 14.dp)) {
        Row(Modifier.padding(horizontal = 4.dp).padding(bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            T(Fm.monthYear(month.atDay(1).atStartOfDay(Fm.zone).toInstant()), F.t(17, W600), Modifier.weight(1f), maxLines = 1, translate = false)
            Box(Modifier.size(34.dp).tap { month = month.minusMonths(1) }.testTag("ev.calPrev"), contentAlignment = Alignment.Center) { Glyph("i_chevL", 18.dp, C.accent) }
            Box(Modifier.size(34.dp).tap { month = month.plusMonths(1) }.testTag("ev.calNext"), contentAlignment = Alignment.Center) { Glyph("i_chevR", 18.dp, C.accent) }
        }
        Row(Modifier.padding(bottom = 6.dp)) { for (d in dow) T(d, F.t(11, W600, C.text3), Modifier.weight(1f), align = TextAlign.Center, translate = false) }
        val lead = month.atDay(1).dayOfWeek.value % 7
        val cells: List<LocalDate?> = List(lead) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
        for (week in cells.chunked(7)) {
            Row {
                for (k in 0 until 7) {
                    val d = week.getOrNull(k)
                    Box(Modifier.weight(1f).height(40.dp), contentAlignment = Alignment.Center) {
                        if (d != null) {
                            val on = d == selected
                            val past = d.isBefore(today)
                            val isT = d == today
                            Box(Modifier.size(36.dp).clip(CircleShape).background(if (on) C.accent else Color.Transparent)
                                .tap(enabled = !past) { onPick(d) }.testTag("ev.day.$d"), contentAlignment = Alignment.Center) {
                                T("${d.dayOfMonth}", F.num(17, if (on || isT) W600 else W400,
                                    when { on -> Color.Black; past -> C.chev; isT -> C.accent; else -> Color.White }), translate = false)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 시간 고르기: AM/PM · 1~12시 · :00 :15 :30 :45 · (선택) 지우기 */
@Composable
private fun EventTimeGrid(ev: RaceEvent, onTime: (String) -> Unit) {
    val p = ev.time.split(":").mapNotNull { it.toIntOrNull() }
    val hh = p.getOrElse(0) { 9 }
    val mi = p.getOrElse(1) { 0 }
    val pm = hh >= 12
    val h12 = if (hh % 12 == 0) 12 else hh % 12
    fun setT(h: Int, m: Int) = onTime("%02d:%02d".format(h, m))
    Column(Modifier.fillMaxWidth().rowLine(true).padding(top = 12.dp, start = 14.dp, end = 14.dp, bottom = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // 시간이 아직 없으면 아무 칸도 고른 것처럼 보이지 않게
        Seg8(listOf("AM" to "AM", "PM" to "PM"), if (ev.hasTime) (if (pm) "PM" else "AM") else "", Modifier.fillMaxWidth()) {
            setT((h12 % 12) + (if (it == "PM") 12 else 0), mi)
        }
        for (row in (1..12).chunked(6)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (h in row) TimeCell("$h", ev.hasTime && h == h12, Modifier.weight(1f), "ev.h.$h") { setT((h % 12) + (if (pm) 12 else 0), mi) }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (m in listOf(0, 15, 30, 45)) TimeCell(":%02d".format(m), ev.hasTime && m == mi, Modifier.weight(1f), "ev.m.$m") { setT(hh, m) }
        }
        Row(Modifier.padding(horizontal = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            T("Optional. Start times are usually given at check-in.", F.t(13, color = C.text3), Modifier.weight(1f))
            if (ev.hasTime) {
                T("Clear", F.t(13, W600, C.accent), Modifier.heightIn(min = 28.dp).tap { onTime("") }.testTag("ev.time.clear"), maxLines = 1)
            }
        }
    }
}

@Composable
private fun TimeCell(t: String, on: Boolean, modifier: Modifier, tag: String, onClick: () -> Unit) {
    Box(modifier.height(40.dp).clip(RoundedCornerShape(10.dp)).background(if (on) C.accent else Color.White.copy(alpha = 0.08f))
        .tap(onClick = onClick).testTag(tag), contentAlignment = Alignment.Center) {
        T(t, F.num(17, color = if (on) Color.Black else Color.White), maxLines = 1, translate = false)
    }
}

// MARK: - I4e 대회 찾기 (위 고정 바: ‹ Race event)

@Composable
fun FindEventView() {
    LaunchedEffect(Unit) { if (Router.evDraft == null) Router.evDraft = Store.settings.event }
    // 서버의 대회 목록 (없거나 실패하면 앱에 들어 있는 목록)
    LaunchedEffect(Unit) { com.nkssi.splits8.Cloud.refreshEvents() }
    var query by remember { mutableStateOf("") }
    var region by remember { mutableStateOf("all") }
    val q = query.trim().lowercase()
    val list = Store.events.filter { (region == "all" || it.region == region) && (q.isEmpty() || (it.city + " " + it.venue).lowercase().contains(q)) }
        .sortedBy { it.start }
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SearchField8("City or venue", query, Modifier.testTag("ev.search")) { query = it }
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                for ((k, l) in EventItem.regions) {
                    val on = region == k
                    Box(Modifier.height(32.dp).clip(CircleShape).background(if (on) C.accent else Color.White.copy(alpha = 0.08f))
                        .tap { region = k }.testTag("ev.region.$k").padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
                        T(l, F.t(13, W600, if (on) Color.Black else Color.White), maxLines = 1)
                    }
                }
            }
            SectionLabel("UPCOMING", top = 8.dp)
            Column(Modifier.fillMaxWidth().card8()) {
                list.forEachIndexed { i, e -> EventRow(e, i == list.size - 1) }
                if (list.isEmpty()) {
                    T("No results", F.t(15, color = C.text2), Modifier.fillMaxWidth().padding(vertical = 22.dp, horizontal = 18.dp), align = TextAlign.Center)
                }
            }
            androidx.compose.foundation.text.BasicText(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = C.text2)) { append("Not on the list? ".l10n) }
                    withStyle(SpanStyle(color = C.accent, fontWeight = W600)) { append("Enter manually".l10n) }
                },
                Modifier.fillMaxWidth().tap { Router.go(Scr.SetEvent) }.testTag("ev.manual").padding(10.dp),
                style = F.t(15).copy(textAlign = TextAlign.Center),
            )
            T("From hyrox.com Find My Race · checked 29 Sep 2026", F.t(F.foot, color = C.chev), Modifier.fillMaxWidth(), align = TextAlign.Center)
        }
    }
}

@Composable
private fun EventRow(e: EventItem, last: Boolean) {
    val today = Store.today()
    val st = LocalDate.parse(e.start)
    val en = runCatching { LocalDate.parse(e.end) }.getOrDefault(st)
    val days = ChronoUnit.DAYS.between(today, st).toInt()
    Row(
        Modifier.fillMaxWidth().rowLine(!last).tap {
            val d = Router.evDraft ?: Store.settings.event
            Router.evDraft = d.copy(name = e.city, loc = e.venue, date = st.atStartOfDay(Fm.zone).toInstant(), dateEnd = en.atStartOfDay(Fm.zone).toInstant())
            Router.go(Scr.SetEvent)
        }.testTag("ev.item." + e.city).padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(Modifier.width(46.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            T(Fm.mon(st.atStartOfDay(Fm.zone).toInstant()).uppercase(), F.t(11, W600, C.accent, tracking = 1.1f), maxLines = 1, translate = false)
            T("${st.dayOfMonth}", F.num(20), maxLines = 1, translate = false)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(e.city, F.t(17, W600), maxLines = 1, translate = false)
            T(e.venue, F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T("D-$days", F.t(13, W600, if (days <= 60) C.accent else C.text2), maxLines = 1, translate = false)
            val ma = Fm.mon(st.atStartOfDay(Fm.zone).toInstant())
            val mb = Fm.mon(en.atStartOfDay(Fm.zone).toInstant())
            val range = if (st.monthValue == en.monthValue) L10n.t("%lld–%lld %@", st.dayOfMonth, en.dayOfMonth, mb)
            else L10n.t("%lld %@–%lld %@", st.dayOfMonth, ma, en.dayOfMonth, mb)
            T(range, F.t(F.foot, color = C.text3), maxLines = 1, translate = false)
        }
    }
}

// MARK: - I5b 구간 목표 (위 고정 바: ‹ Race · Split goals)

@Composable
fun SetGoalsView() {
    val s = Store.settings
    val g = s.goals
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 총 목표 시간을 넣고 유형을 고르면 아래 16칸이 한 번에 채워짐 (그 뒤 하나씩 고칠 수 있음)
            Column(Modifier.fillMaxWidth().card8().padding(bottom = 0.dp)) {
                SettingRow("Set from goal time", Fm.t(s.goalTime), Modifier.testTag("goals.auto"), numeric = true, last = true) { Router.raceSheet = "goal" }
            }
            Row(Modifier.fillMaxWidth().padding(top = 4.dp, start = 4.dp, end = 4.dp, bottom = 6.dp), horizontalArrangement = Arrangement.End) {
                T("TOTAL ", F.t(F.foot, W600, C.text2, tracking = 0.78f), maxLines = 1, translate = false)
                T(Fm.t(g.sum()), F.num(F.foot, color = C.accent, tracking = 0.78f), Modifier.testTag("goals.total"), maxLines = 1, translate = false)
            }
            Column(Modifier.fillMaxWidth().card8()) {
                T("Used as split targets in Race, and in Full Simulation when Compare with is set to Goal. Adjust in 5-second steps.",
                    F.t(13, color = C.text2), Modifier.fillMaxWidth().rowLine(true).padding(vertical = 12.dp, horizontal = 18.dp))
                for (i in 0 until 16) {
                    val run = i % 2 == 0
                    val st = Station.all[i / 2]
                    val t = g.getOrElse(i) { 0 }
                    Row(Modifier.fillMaxWidth().rowLine(i < 15).padding(vertical = 9.dp).padding(start = 18.dp, end = 12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon8(if (run) "run" else st.key, 20.dp, if (run) Color.White else C.accent)
                        Column(Modifier.weight(1f)) {
                            T(if (run) L10n.t("Run %lld", i / 2 + 1) else st.name, F.t(15, W500), maxLines = 1, translate = false)
                            T(if (run) "1KM" else st.detail(s.div), F.num(11, W400, C.text2), maxLines = 1, translate = false)
                        }
                        Stepper8(Fm.t(t), Modifier.testTag("goals.row.$i"), minWidth = 46.dp, fontSize = 17, button = 30.dp, radius = 9.dp, gap = 12.dp,
                            down = { changeGoal(i, -5) }, up = { changeGoal(i, 5) })
                    }
                }
            }
        }
    }
}

/** 한 칸 ±5초 (30초 아래로는 안 내려감). 목표 시간 = 16칸 합 + Roxzone 8번 */
fun changeGoal(i: Int, v: Int) {
    Store.update { s ->
        if (i !in s.goals.indices) return@update s
        val g = s.goals.toMutableList()
        g[i] = maxOf(30, g[i] + v)
        s.copy(goals = g, goalTime = g.sum() + 8 * s.roxTarget)
    }
}
