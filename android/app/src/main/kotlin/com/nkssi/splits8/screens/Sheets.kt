package com.nkssi.splits8.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.BonusRequest
import com.nkssi.splits8.PlanRequest
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PlanReminder
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.newId
import com.nkssi.splits8.ui.AskHost
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.Sheet8
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth

/** 화면 위에 뜨는 것들: HIIT · 러닝 시트, 운동 예약 시트, 확인 창 (PhoneRoot 맨 앞) */
@Composable
fun Overlays() {
    Sheet8(Router.bonus, onClose = { Router.bonus = null }) { req -> BonusSheet(req) }
    Sheet8(Router.planRequest, onClose = { Router.planRequest = null }, large = true) { req -> PlanSheet(req) }
    Sheet8(Router.testInfo, onClose = { Router.testInfo = null }, large = true) { k -> TestInfoSheet(k) }
    // 목표 시간 · 더블 시트는 아이폰처럼 더 어두운 #141414 (회색 러닝 막대가 보이게)
    Sheet8(Router.raceSheet, onClose = { Router.raceSheet = null }, large = Router.raceSheet == "doubles",
        bg = androidx.compose.ui.graphics.Color(0xFF141414)) { k ->
        if (k == "doubles") DoublesPlanSheet() else GoalTimeSheet()
    }
    Sheet8(Router.userMenu, onClose = { Router.userMenu = null }) { u -> UserMenuSheet(u) }
    Sheet8(Router.partnerFor, onClose = { Router.partnerFor = null }) { id -> PartnerSheet(id) }
    Sheet8(Router.cheerTo, onClose = { Router.cheerTo = null }, bg = androidx.compose.ui.graphics.Color(0xFF1C1C1E)) { f -> CheerSheet(f) }
    Sheet8(Router.finish, onClose = { Router.finish = null }) { rec -> FinishSheet(rec) }
    ToastHost()
    AskHost()
}

// MARK: - HIIT · 러닝 설정 시트 (아이폰 BonusViews.swift)

@Composable
private fun BonusSheet(req: BonusRequest) {
    // 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동은 BonusSheets.kt
    if (com.nkssi.splits8.shared.Kinds.isNew(req.kind)) NewBonusSheet(req) else HiitRunSheet(req)
}

@Composable
private fun HiitRunSheet(req: BonusRequest) {
    // 요청마다 처음 값으로 (같은 시트를 다시 열어도 새로)
    var km by remember(req.key) { mutableStateOf(req.existing?.runKm ?: 5) }
    var indoor by remember(req.key) { mutableStateOf(req.existing?.indoor ?: false) }
    val fresh = remember(req.key) { newId().take(6) }
    val hiit = req.kind == "hiit"
    // 82번(빌드 28): 카드 이름 (비우면 기본 이름 "HIIT" · "Run 5K" · "Free run"). 기본 이름 그대로면 칸은 비워 둠
    var name by remember(req.key) {
        val n = req.existing?.name ?: ""
        val isDefault = n == "HIIT" || n == "Free run" || (n.startsWith("Run ") && n.endsWith("K"))
        mutableStateOf(if (isDefault) "" else n)
    }
    val defaultName = if (hiit) "HIIT" else Program.runName(km)
    val cleanName = name.trim().take(24)

    // 지금 고른 값으로 만든 프로그램 (편집이면 같은 id)
    val base: Program = if (hiit) req.existing ?: Program.hiit().copy(id = "hiit.$fresh")
    else Program.run(km, indoor, req.existing?.id ?: "run.$fresh")
    val program = base.copy(name = cleanName.ifEmpty { defaultName })

    fun save() {
        Store.saveProgram(program)
        Router.bonus = null
        // 새로 만들기(트레이닝 만들기 화면)에서 왔으면 트레이닝 목록으로
        if (req.existing == null && Router.scr == Scr.Builder) { Router.editId = null; Router.go(Scr.Training) }
    }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon8(if (hiit) "hiit" else "run", 26.dp, C.accent)
            T(if (hiit) "HIIT" else "Running", F.t(F.title3, W600), Modifier.weight(1f), maxLines = 1)
            Box(Modifier.size(32.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f)).tap { Router.bonus = null }.testTag("bonus.close"),
                contentAlignment = Alignment.Center) { Glyph("i_x", 14.dp, C.text2) }
        }
        // 이름 (82번)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label8("NAME")
            Box(Modifier.fillMaxWidth().height(46.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.08f))
                .padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) {
                if (name.isEmpty()) T(defaultName, F.t(17, color = C.text3), maxLines = 1)
                androidx.compose.foundation.text.BasicTextField(name, { name = it.take(40) }, Modifier.fillMaxWidth().testTag("bonus.name"),
                    textStyle = F.t(17), singleLine = true, cursorBrush = androidx.compose.ui.graphics.SolidColor(C.accent),
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(capitalization = androidx.compose.ui.text.input.KeyboardCapitalization.Words, autoCorrectEnabled = false))
            }
        }
        if (hiit) {
            Column(Modifier.fillMaxWidth().card8(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("When a round ends, tap the yellow button or swipe left on the watch → next interval.", F.t(F.sub))  // 5번: 두 번 톡톡 안내 뺌
                T("Saved: time per round · average heart rate · calories", F.t(F.foot, color = C.text2))
            }
        } else {
            Column(Modifier.fillMaxWidth().card8(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Label8("DISTANCE")
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (k in Program.runChoices) {
                        val on = km == k
                        Box(
                            Modifier.weight(1f).height(40.dp).clip(RoundedCornerShape(10.dp))
                                .background(if (on) C.accent else Color.White.copy(alpha = 0.10f)).tap { km = k }.testTag("bonus.km.$k"),
                            contentAlignment = Alignment.Center,
                        ) {
                            T(if (k > 0) "${k}K" else "Free".l10n, F.t(F.sub, W600, if (on) Color.Black else Color.White), maxLines = 1, translate = false)
                        }
                    }
                }
                Label8("PLACE")
                Seg8(listOf("out" to "Outdoor (GPS)", "in" to "Indoor (treadmill)"), if (indoor) "in" else "out", height = 36.dp, radius = 10.dp) {
                    indoor = it == "in"
                }
                T("Saved: 1 km splits · pace · heart rate · route map outdoors", F.t(F.foot, color = C.text2))
            }
        }
        // 빌드 25 (66번): 같은 설정이 이미 목록(= 워치 목록)에 있으면 저장 단추 대신 "워치 목록에 있음"
        val onWatch = req.existing?.let { e -> e.name == program.name && (hiit || (e.runKm == km && (e.indoor ?: false) == indoor)) }
            ?: Store.programs.any { p -> p.name == program.name && (if (hiit) p.isHIIT else (p.isRun && p.runKm == km && (p.indoor ?: false) == indoor)) }
        if (onWatch) {
            Row(
                Modifier.fillMaxWidth().height(54.dp).card8(16.dp).testTag("bonus.onWatch"),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            ) {
                Check8(C.good, 18.dp)
                T("Already on your watch list", F.t(17, W600, C.good), maxLines = 1)
            }
        } else {
            YellowButton(if (req.existing != null) "Save changes" else "Save (add to watch list)", tag = "bonus.save") { save() }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (req.existing != null) {
                T("Delete", F.t(F.sub, W600, C.bad), Modifier.tap {
                    Store.deleteProgram(req.existing.id); Router.bonus = null
                }.testTag("bonus.delete"), maxLines = 1)
            }
            Spacer(Modifier.weight(1f))
            StartOnPhoneButton(Mode.Training, program, before = { Store.saveProgram(program); Router.bonus = null })
        }
    }
}

// MARK: - 운동 예약 시트 (아이폰 PlanViews.swift)

@Composable
private fun PlanSheet(req: PlanRequest) {
    val ex = req.existing
    val start = remember(req) {
        val z = req.date.atZone(Fm.zone)
        // 시간이 0:00 (달력 날짜만) 이면 오전 7시로 시작
        val t = if (ex == null && z.hour == 0 && z.minute == 0) LocalTime.of(7, 0) else z.toLocalTime().withSecond(0).withNano(0)
        z.toLocalDate() to t
    }
    var sim by remember(req) { mutableStateOf((ex?.mode ?: req.mode) == Mode.Sim) }
    var programId by remember(req) { mutableStateOf(ex?.programId ?: Store.programs.firstOrNull()?.id) }
    var day by remember(req) { mutableStateOf(start.first) }
    var time by remember(req) { mutableStateOf(start.second) }
    var reminder by remember(req) { mutableStateOf(ex?.reminder ?: PlanReminder.DayBefore) }
    /** 펼친 줄: "program" / "date" / "time" / null */
    var open by remember(req) { mutableStateOf<String?>(null) }
    val program = Store.programs.firstOrNull { it.id == programId }

    fun close() { Router.planRequest = null }
    val askNotify = com.nkssi.splits8.rememberAskNotifications()
    fun save() {
        if (reminder != PlanReminder.None) askNotify()
        val title = if (sim) "Full Simulation" else (program?.name ?: "Training")
        val at = LocalDateTime.of(day, time).atZone(Fm.zone).toInstant()
        val p = PlannedWorkout(id = ex?.id ?: newId(), mode = if (sim) Mode.Sim else Mode.Training,
            programId = if (sim) null else programId, title = title, date = at, reminder = reminder)
        Store.savePlan(p)
        close()
    }

    NavBar3("Cancel", if (ex != null) "Edit plan" else "Plan workout", Modifier.padding(horizontal = 12.dp), right = "Save",
        edgeBack = false, onLeft = { close() }, onRight = { save() })
    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 30.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionLabel("TYPE", top = 10.dp)
        Seg8(listOf("training" to "Training", "sim" to "Full Sim"), if (sim) "sim" else "training", Modifier.fillMaxWidth().testTag("plan.type")) {
            sim = it == "sim"; if (sim && open == "program") open = null
        }
        Column(Modifier.fillMaxWidth().card8(14.dp)) {
            if (!sim) {
                PlanRow("Program", false, "plan.program", { open = if (open == "program") null else "program" }) {
                    T(program?.name ?: "Choose", F.t(15, color = C.text2), Modifier.weight(1f, fill = false), maxLines = 1)
                    Chevron8()
                }
                AnimatedVisibility(open == "program") {
                    Column(Modifier.background(Color.White.copy(alpha = 0.03f)).rowLine(true)) {
                        Store.programs.forEachIndexed { i, p ->
                            Row(
                                Modifier.fillMaxWidth().heightIn(min = 44.dp).rowLine(i < Store.programs.size - 1, start = 34.dp)
                                    .tap { programId = p.id; open = null }.padding(horizontal = 18.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Box(Modifier.width(16.dp)) { if (p.id == programId) Check8(size = 16.dp) }
                                T(p.name, F.t(15), Modifier.weight(1f), maxLines = 1)
                            }
                        }
                    }
                }
            }
            PlanRow("Date", false, "plan.date", { open = if (open == "date") null else "date" }) {
                ValuePill(Fm.dmy(day.atStartOfDay(Fm.zone).toInstant()), open == "date")
            }
            AnimatedVisibility(open == "date") {
                MiniMonth(day, Modifier.rowLine(true)) { day = it; open = null }
            }
            PlanRow("Time", open != "time", "plan.time", { open = if (open == "time") null else "time" }) {
                ValuePill(Fm.time12(LocalDateTime.of(day, time).atZone(Fm.zone).toInstant()), open == "time")
            }
            AnimatedVisibility(open == "time") { TimePick(time) { time = it } }
        }
        SectionLabel("REMINDER")
        Column(Modifier.fillMaxWidth().card8(14.dp)) {
            val all = PlanReminder.entries
            all.forEachIndexed { i, x ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 50.dp).rowLine(i < all.size - 1).tap { reminder = x }
                        .testTag("plan.reminder." + x.name).padding(horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    T(x.label, F.t(17), Modifier.weight(1f), maxLines = 1)
                    if (reminder == x) Check8(size = 18.dp)
                }
            }
        }
        Note8("The first time you turn on a reminder, your phone will ask to allow notifications.")
        if (ex != null) {
            Box(
                Modifier.padding(top = 14.dp).fillMaxWidth().height(50.dp).card8(14.dp)
                    .tap { Store.deletePlan(ex.id); close() }.testTag("plan.delete"),
                contentAlignment = Alignment.Center,
            ) { T("Delete plan", F.t(17, color = C.bad)) }
        }
    }
}

@Composable
private fun PlanRow(title: String, last: Boolean, tag: String, onClick: () -> Unit, trailing: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 50.dp).rowLine(!last).tap(onClick = onClick).testTag(tag).padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        T(title, F.t(17), maxLines = 1)
        Spacer(Modifier.weight(1f))
        trailing()
    }
}

/** 날짜 · 시간 값 (회색 알약, 펼쳤으면 노란 글자) */
@Composable
private fun ValuePill(text: String, on: Boolean) {
    Box(Modifier.clip(RoundedCornerShape(8.dp)).background(Color.White.copy(alpha = 0.10f)).padding(horizontal = 11.dp, vertical = 6.dp)) {
        T(text, F.t(17, color = if (on) C.accent else Color.White), maxLines = 1, translate = false)
    }
}

/** 작은 달력 (날짜 고르기). 월요일부터 */
@Composable
private fun MiniMonth(selected: LocalDate, modifier: Modifier = Modifier, onPick: (LocalDate) -> Unit) {
    var month by remember { mutableStateOf(YearMonth.from(selected)) }
    val today = Store.today()
    Column(modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(Fm.monthYear(month.atDay(1).atStartOfDay(Fm.zone).toInstant()), F.t(15, W600), Modifier.weight(1f).padding(start = 4.dp),
                maxLines = 1, translate = false)
            Box(Modifier.size(36.dp).press(0.9f, tag = "plan.monthPrev") { month = month.minusMonths(1) }, contentAlignment = Alignment.Center) {
                Glyph("i_chevL", 14.dp, C.accent)
            }
            Box(Modifier.size(36.dp).press(0.9f, tag = "plan.monthNext") { month = month.plusMonths(1) }, contentAlignment = Alignment.Center) {
                Glyph("i_chevR", 14.dp, C.accent)
            }
        }
        Row {
            for (w in weekLetters()) T(w, F.t(11, W600, C.text3), Modifier.weight(1f), align = TextAlign.Center, translate = false)
        }
        val lead = (month.atDay(1).dayOfWeek.value + 6) % 7
        val cells: List<LocalDate?> = List(lead) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
        for (week in cells.chunked(7)) {
            Row {
                for (k in 0 until 7) {
                    val d = week.getOrNull(k)
                    Box(Modifier.weight(1f).height(38.dp), contentAlignment = Alignment.Center) {
                        if (d != null) {
                            val sel = d == selected
                            Box(
                                Modifier.size(34.dp).clip(CircleShape).background(if (sel) C.accent else Color.Transparent)
                                    .tap { onPick(d) }.testTag("plan.day.$d"),
                                contentAlignment = Alignment.Center,
                            ) {
                                T("${d.dayOfMonth}", F.num(15, if (sel || d == today) W600 else androidx.compose.ui.text.font.FontWeight.Normal,
                                    when { sel -> Color.Black; d == today -> C.accent; d.isBefore(today) -> C.text3; else -> Color.White }),
                                    translate = false)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 월~일 첫 글자 (한국어: 월 화 수 목 금 토 일) */
private fun weekLetters(): List<String> =
    if (L10n.isKorean) listOf("월", "화", "수", "목", "금", "토", "일") else listOf("M", "T", "W", "T", "F", "S", "S")

/** 시간 고르기: 시 −/+ · 분 −/+ (5분씩) · 오전/오후 */
@Composable
private fun TimePick(t: LocalTime, onChange: (LocalTime) -> Unit) {
    val h12 = if (t.hour % 12 == 0) 12 else t.hour % 12
    val pm = t.hour >= 12
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Stepper8("$h12", minWidth = 26.dp, fontSize = 20, button = 32.dp, gap = 8.dp,
            down = { onChange(t.minusHours(1)) }, up = { onChange(t.plusHours(1)) })
        T(":", F.num(20), translate = false)
        Stepper8("%02d".format(t.minute), minWidth = 26.dp, fontSize = 20, button = 32.dp, gap = 8.dp,
            down = { onChange(t.minusMinutes(if (t.minute % 5 == 0) 5 else (t.minute % 5).toLong())) },
            up = { onChange(t.plusMinutes((5 - t.minute % 5).toLong())) })
        Spacer(Modifier.weight(1f))
        Seg8(listOf("am" to (if (L10n.isKorean) "오전" else "AM"), "pm" to (if (L10n.isKorean) "오후" else "PM")), if (pm) "pm" else "am",
            minWidth = 40.dp) { k ->
            if ((k == "pm") != pm) onChange(t.plusHours(12))
        }
    }
}
