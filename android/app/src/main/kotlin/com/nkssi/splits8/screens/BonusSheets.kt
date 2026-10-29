package com.nkssi.splits8.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.BonusRequest
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.IvPreset
import com.nkssi.splits8.shared.IvStep
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Lift
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.newId
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

// 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 설정 시트 (새로 만들기 / 저장된 것 편집).
// HIIT · 러닝 시트(Sheets.kt BonusSheet)와 같은 모양: 이름 · 설정 카드 · 저장(워치 목록에 추가) · 지우기 · 폰으로 시작.

@Composable
internal fun NewBonusSheet(req: BonusRequest) {
    val kind = req.kind
    val ex = req.existing
    val fresh = remember(req.key) { newId().take(6) }
    val id = ex?.id ?: "$kind.$fresh"

    // 타바타
    var work by remember(req.key) { mutableStateOf(ex?.work ?: Bonus.TABATA_WORK) }
    var rest by remember(req.key) { mutableStateOf(ex?.rest ?: (if (kind == Kinds.LIFT) Bonus.LIFT_REST else Bonus.TABATA_REST)) }
    var rounds by remember(req.key) {
        mutableStateOf(ex?.rounds ?: when (kind) { Kinds.EMOM -> Bonus.EMOM_ROUNDS; Kinds.IVRUN -> Bonus.ivPresets[0].rounds; else -> Bonus.TABATA_ROUNDS })
    }
    var custom by remember(req.key) { mutableStateOf(ex != null && (ex.work != Bonus.TABATA_WORK || ex.rest != Bonus.TABATA_REST || ex.rounds != Bonus.TABATA_ROUNDS)) }
    // EMOM · AMRAP
    var every by remember(req.key) { mutableStateOf(ex?.every ?: Bonus.EMOM_EVERY) }
    var capMin by remember(req.key) { mutableStateOf((ex?.cap ?: Bonus.AMRAP_CAP) / 60) }
    var tasks by remember(req.key) { mutableStateOf(ex?.tasks.orEmpty().joinToString("\n")) }
    // 인터벌 러닝
    var steps by remember(req.key) { mutableStateOf(ex?.steps ?: Bonus.ivPresets[0].steps) }
    var preset by remember(req.key) {
        mutableStateOf(if (ex == null) Bonus.ivPresets[0].name else Bonus.ivPresets.firstOrNull { it.name == ex.name && it.steps == ex.steps && it.rounds == ex.rounds }?.name)
    }
    var warm by remember(req.key) { mutableStateOf(ex?.warm) }
    var cool by remember(req.key) { mutableStateOf(ex?.cool) }
    var indoor by remember(req.key) { mutableStateOf(ex?.indoor ?: false) }
    // 기능성 운동
    var lifts by remember(req.key) { mutableStateOf(ex?.lifts ?: listOf(Lift("Squat", 3, 10, 40.0))) }

    // 지금 고른 값으로 만든 프로그램 (편집이면 같은 id)
    val base: Program = when (kind) {
        Kinds.TABATA -> if (custom) Bonus.tabata(work, rest, rounds, id) else Bonus.tabata(id = id)
        Kinds.EMOM -> Bonus.emom(every, rounds, tasks.lines(), id)
        Kinds.AMRAP -> Bonus.amrap(capMin * 60, tasks.lines(), id)
        Kinds.IVRUN -> Bonus.ivrun(steps, rounds, indoor, warm, cool, name = preset ?: "Interval run", id = id)
        else -> Bonus.lift(lifts, rest, id)
    }
    // 이름 (비우면 기본 이름). 기본 이름 그대로인 카드는 칸을 비워 둠
    var name by remember(req.key) {
        val n = ex?.name ?: ""
        val isDefault = n == base.name || n == "Interval run" || Bonus.ivPresets.any { it.name == n } ||
            n == "Tabata" || n.startsWith("Interval timer ") || n == "AMRAP" || n == "Strength" || (n.startsWith("E") && n.contains("MOM"))
        mutableStateOf(if (isDefault) "" else n)
    }
    val program = base.copy(name = name.trim().take(24).ifEmpty { base.name })

    fun save() {
        Store.saveProgram(program)
        Router.bonus = null
        if (ex == null && Router.scr == Scr.Builder) { Router.editId = null; Router.go(Scr.Training) }
    }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon8(Kinds.icon(kind), 26.dp, C.accent)
            T(Kinds.title(kind), F.t(F.title3, W600), Modifier.weight(1f), maxLines = 1)
            Box(Modifier.size(32.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f)).tap { Router.bonus = null }.testTag("bonus.close"),
                contentAlignment = Alignment.Center) { Glyph("i_x", 14.dp, C.text2) }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Label8("NAME")
            TextBox(name, base.name.l10n, "bonus.name", KeyboardCapitalization.Words) { name = it.take(40) }
        }
        when (kind) {
            Kinds.TABATA -> Card {
                Seg8(listOf("classic" to "Classic 20/10 × 8", "custom" to "Custom"), if (custom) "custom" else "classic",
                    Modifier.fillMaxWidth().testTag("bonus.tabata.mode"), height = 36.dp) { custom = it == "custom" }
                if (custom) {
                    NumRow("WORK", Bonus.dur(work), "bonus.work", { work = (work - 5).coerceAtLeast(5) }, { work = (work + 5).coerceAtMost(600) })
                    NumRow("REST", Bonus.dur(rest), "bonus.rest", { rest = (rest - 5).coerceAtLeast(0) }, { rest = (rest + 5).coerceAtMost(600) })
                    NumRow("ROUNDS", "$rounds", "bonus.rounds", { rounds = (rounds - 1).coerceAtLeast(1) }, { rounds = (rounds + 1).coerceAtMost(50) })
                }
                T(L10n.t("Total %@", Fm.t(Bonus.plannedTime(program) ?: 0)), F.t(F.foot, color = C.text2), translate = false)
                T("Switches by itself. A beep and a buzz 3 · 2 · 1 seconds before each change.", F.t(F.foot, color = C.text2))
                T("Saved: heart rate and calories per round · whether you finished", F.t(F.foot, color = C.text2))
            }
            Kinds.EMOM -> Card {
                Label8("EVERY")
                ChipRow(Bonus.emomChoices.map { it to Fm.t(it) }, every, "bonus.every") { every = it }
                NumRow("ROUNDS", "$rounds", "bonus.rounds", { rounds = (rounds - 1).coerceAtLeast(1) }, { rounds = (rounds + 1).coerceAtMost(60) })
                T(L10n.t("Total %@", Fm.t(every * rounds)), F.t(F.foot, color = C.text2), translate = false)
                TasksBox(tasks) { tasks = it }
                T("A new round starts every interval. Finish early, tap Done: the rest is your break.", F.t(F.foot, color = C.text2))
            }
            Kinds.AMRAP -> Card {
                NumRow("TIME", L10n.t("%lld min", capMin), "bonus.cap", { capMin = (capMin - 1).coerceAtLeast(1) }, { capMin = (capMin + 1).coerceAtMost(90) })
                TasksBox(tasks) { tasks = it }
                T("Tap at the end of each round. Ends by itself when time is up — then add the extra reps.", F.t(F.foot, color = C.text2))
            }
            Kinds.IVRUN -> {
                Card {
                    Label8("QUICK PICK")
                    for (p in Bonus.ivPresets) PresetRow(p, preset == p.name) {
                        preset = p.name; steps = p.steps; rounds = p.rounds
                    }
                }
                Card {
                    Label8("STEPS")
                    steps.forEachIndexed { i, st ->
                        StepEditor(st, i, steps.size > 1,
                            onChange = { n -> steps = steps.toMutableList().also { it[i] = n }; preset = null },
                            onRemove = { steps = steps.filterIndexed { j, _ -> j != i }; preset = null })
                    }
                    if (steps.size < 6) {
                        T("+ Add step", F.t(F.sub, W600, C.accent), Modifier.tap {
                            steps = steps + IvStep(IvStep.EASY, m = 200); preset = null
                        }.testTag("bonus.addStep"), maxLines = 1)
                    }
                    NumRow("REPEAT", "× $rounds", "bonus.rounds", { rounds = (rounds - 1).coerceAtLeast(1) }, { rounds = (rounds + 1).coerceAtMost(50) })
                }
                Card {
                    OptStep("WARM-UP", warm, "bonus.warm") { warm = it }
                    OptStep("COOL-DOWN", cool, "bonus.cool") { cool = it }
                    Label8("PLACE")
                    Seg8(listOf("out" to "Outdoor (GPS)", "in" to "Indoor (treadmill)"), if (indoor) "in" else "out", height = 36.dp, radius = 10.dp) {
                        indoor = it == "in"
                    }
                    T(if (indoor) "Indoors, time steps move on by themselves; tap Next for distance steps."
                        else "Outdoors, steps move on by GPS distance; time steps by time.", F.t(F.foot, color = C.text2))
                    T("Saved: time · distance · pace per step, fast-step pace, route map outdoors", F.t(F.foot, color = C.text2))
                }
            }
            else -> {
                Card {
                    Label8("EXERCISES")
                    lifts.forEachIndexed { i, l ->
                        LiftEditor(l, i, lifts.size > 1,
                            onChange = { n -> lifts = lifts.toMutableList().also { it[i] = n } },
                            onRemove = { lifts = lifts.filterIndexed { j, _ -> j != i } })
                    }
                    if (lifts.size < 10) AddLift(lifts.map { it.name }) { n -> lifts = lifts + Lift(n, 3, 10, 0.0) }
                }
                Card {
                    NumRow("REST BETWEEN SETS", Bonus.dur(rest), "bonus.rest", { rest = (rest - 15).coerceAtLeast(0) }, { rest = (rest + 15).coerceAtMost(600) })
                    T("After each set, check reps and weight (filled in from last time), then the rest timer runs. On the watch: set done · rest · next.",
                        F.t(F.foot, color = C.text2))
                }
            }
        }
        YellowButton(if (ex != null) "Save changes" else "Save (add to watch list)", tag = "bonus.save") { save() }
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (ex != null) {
                T("Delete", F.t(F.sub, W600, C.bad), Modifier.tap {
                    Store.deleteProgram(ex.id); Router.bonus = null
                }.testTag("bonus.delete"), maxLines = 1)
            }
            Spacer(Modifier.weight(1f))
            StartOnPhoneButton(Mode.Training, program, before = { Store.saveProgram(program); Router.bonus = null })
        }
    }
}

// MARK: 작은 부품

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().card8(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
}

/** 이름표 · 값 −/+ */
@Composable
private fun NumRow(label: String, value: String, tag: String, down: () -> Unit, up: () -> Unit) {
    Row(Modifier.fillMaxWidth().testTag(tag), verticalAlignment = Alignment.CenterVertically) {
        Label8(label, Modifier.weight(1f))
        Stepper8(value, minWidth = 64.dp, fontSize = 17, button = 32.dp, gap = 10.dp, down = down, up = up)
    }
}

/** 칩 여러 개 중 하나 (노랑 = 고른 것) */
@Composable
private fun <V> ChipRow(items: List<Pair<V, String>>, selected: V, tag: String, onPick: (V) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for (row in items.chunked(4)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for ((v, l) in row) {
                    val on = v == selected
                    Box(Modifier.weight(1f).height(36.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (on) C.accent else Color.White.copy(alpha = 0.10f)).tap { onPick(v) }.testTag("$tag.$v"),
                        contentAlignment = Alignment.Center) {
                        T(l, F.t(F.sub, W600, if (on) Color.Black else Color.White), maxLines = 1, translate = false)
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** 한 줄 글자 칸 */
@Composable
private fun TextBox(value: String, hint: String, tag: String, cap: KeyboardCapitalization = KeyboardCapitalization.Sentences,
                    single: Boolean = true, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 46.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.08f))
        .padding(horizontal = 14.dp, vertical = 12.dp), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) T(hint, F.t(17, color = C.text3), maxLines = if (single) 1 else 4, translate = false)
        BasicTextField(value, onChange, Modifier.fillMaxWidth().testTag(tag),
            textStyle = F.t(17), singleLine = single, cursorBrush = SolidColor(C.accent),
            keyboardOptions = KeyboardOptions(capitalization = cap, autoCorrectEnabled = false))
    }
}

/** EMOM · AMRAP 할 일 (한 줄에 하나, 화면에 보이기만) */
@Composable
private fun TasksBox(tasks: String, onChange: (String) -> Unit) {
    Label8("TO DO EACH ROUND (OPTIONAL)")
    TextBox(tasks, "Burpees 10\nWall balls 15".l10n, "bonus.tasks", single = false) { onChange(it.take(320)) }
}

/** 예시 한 줄 (고르면 노란 체크) */
@Composable
private fun PresetRow(p: IvPreset, on: Boolean, onPick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 40.dp).clip(RoundedCornerShape(10.dp))
        .background(if (on) C.accent.copy(alpha = 0.16f) else Color.Transparent).tap(onClick = onPick).padding(horizontal = 10.dp)
        .testTag("bonus.preset." + p.name), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f)) {
            T(p.name, F.t(F.sub, W600, if (on) C.accent else Color.White), maxLines = 1, translate = false)
            T(p.steps.joinToString(" · ") { Bonus.stepText(it) }, F.t(F.foot, color = C.text2), maxLines = 1, translate = false)
        }
    }
}

/** 인터벌 러닝 단계 하나: 종류 · 거리/시간 · 양 · 목표 페이스 */
@Composable
private fun StepEditor(st: IvStep, i: Int, removable: Boolean, onChange: (IvStep) -> Unit, onRemove: () -> Unit) {
    Column(Modifier.fillMaxWidth().rowLine(true).padding(bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(L10n.t("Step %lld", i + 1), F.t(F.sub, W600), Modifier.weight(1f), maxLines = 1, translate = false)
            if (removable) T("Remove", F.t(F.foot, W600, C.bad), Modifier.tap(onClick = onRemove).testTag("bonus.step$i.remove"), maxLines = 1)
        }
        Seg8(IvStep.types.map { it to IvStep.typeName(it) }, st.t, Modifier.fillMaxWidth().testTag("bonus.step$i.type"), height = 32.dp) { t ->
            // 휴식은 늘 시간
            onChange(if (t == IvStep.REST) IvStep(t, s = st.s ?: 60) else st.copy(t = t))
        }
        if (st.t != IvStep.REST) {
            Seg8(listOf("m" to "Distance", "s" to "Time"), if (st.isTime) "s" else "m", Modifier.fillMaxWidth(), height = 32.dp) { k ->
                onChange(if (k == "m") st.copy(m = st.m ?: 400, s = null) else st.copy(m = null, s = st.s ?: 60))
            }
        }
        if (st.isTime) {
            NumRow("TIME", Bonus.dur(st.secs), "bonus.step$i.time",
                { onChange(st.copy(m = null, s = (st.secs - 15).coerceAtLeast(15))) }, { onChange(st.copy(m = null, s = (st.secs + 15).coerceAtMost(3600))) })
        } else {
            NumRow("DISTANCE", Bonus.distText(st.meters), "bonus.step$i.dist",
                { onChange(st.copy(m = (st.meters - 100).coerceAtLeast(100))) }, { onChange(st.copy(m = (st.meters + 100).coerceAtMost(10000))) })
        }
        if (st.t != IvStep.REST) {
            val pace = st.pace
            NumRow("TARGET PACE", if (pace == null) "–" else Fm.t(pace) + " /km", "bonus.step$i.pace",
                { onChange(st.copy(pace = pace?.let { if (it <= 150) null else it - 5 })) },
                { onChange(st.copy(pace = (pace ?: 295) + 5)) })
        }
    }
}

/** 워밍업 · 쿨다운 (켜면 시간 단계, 분 단위) */
@Composable
private fun OptStep(label: String, st: IvStep?, tag: String, onChange: (IvStep?) -> Unit) {
    Row(Modifier.fillMaxWidth().testTag(tag), verticalAlignment = Alignment.CenterVertically) {
        Label8(label, Modifier.weight(1f))
        if (st == null) {
            T("Add", F.t(F.sub, W600, C.accent), Modifier.tap { onChange(IvStep(IvStep.EASY, s = 300)) }.testTag("$tag.add"), maxLines = 1)
        } else {
            Stepper8(Bonus.dur(st.secs), minWidth = 64.dp, fontSize = 17, button = 32.dp, gap = 10.dp,
                down = { if (st.secs <= 60) onChange(null) else onChange(st.copy(s = st.secs - 60)) },
                up = { onChange(st.copy(s = (st.secs + 60).coerceAtMost(3600))) })
        }
    }
}

/** 기능성 운동 종목 하나: 이름 · 세트 · 횟수 · 무게 */
@Composable
private fun LiftEditor(l: Lift, i: Int, removable: Boolean, onChange: (Lift) -> Unit, onRemove: () -> Unit) {
    Column(Modifier.fillMaxWidth().rowLine(true).padding(bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(l.name, F.t(F.body, W600), Modifier.weight(1f), maxLines = 1)
            if (removable) T("Remove", F.t(F.foot, W600, C.bad), Modifier.tap(onClick = onRemove).testTag("bonus.lift$i.remove"), maxLines = 1)
        }
        NumRow("SETS", "${l.sets}", "bonus.lift$i.sets", { onChange(l.copy(sets = (l.sets - 1).coerceAtLeast(1))) }, { onChange(l.copy(sets = (l.sets + 1).coerceAtMost(10))) })
        NumRow("REPS", "${l.reps}", "bonus.lift$i.reps", { onChange(l.copy(reps = (l.reps - 1).coerceAtLeast(1))) }, { onChange(l.copy(reps = (l.reps + 1).coerceAtMost(100))) })
        NumRow("WEIGHT (KG)", if (l.kg > 0) Bonus.kgText(l.kg).removeSuffix(" kg") else "–", "bonus.lift$i.kg",
            { onChange(l.copy(kg = (l.kg - 2.5).coerceAtLeast(0.0))) }, { onChange(l.copy(kg = (l.kg + 2.5).coerceAtMost(500.0))) })
    }
}

/** 종목 넣기: 자주 하는 종목 칩 + 직접 입력 */
@Composable
private fun AddLift(have: List<String>, onAdd: (String) -> Unit) {
    var typed by remember { mutableStateOf("") }
    Label8("ADD EXERCISE")
    val left = Bonus.liftNames.filter { it !in have }
    for (row in left.chunked(2)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (n in row) {
                Box(Modifier.weight(1f).height(36.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.10f))
                    .tap { onAdd(n) }.testTag("bonus.addLift.$n"), contentAlignment = Alignment.Center) {
                    T("+ " + n.l10n, F.t(F.foot, W600), maxLines = 1, translate = false)
                }
            }
            if (row.size < 2) Spacer(Modifier.weight(1f))
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.weight(1f)) {
            TextBox(typed, "Other exercise".l10n, "bonus.liftName", KeyboardCapitalization.Words) { typed = it.take(30) }
        }
        T("Add", F.t(F.sub, W600, if (typed.isBlank()) C.text3 else C.accent), Modifier.tap(enabled = typed.isNotBlank()) {
            onAdd(typed.trim()); typed = ""
        }.testTag("bonus.liftAdd"), maxLines = 1)
    }
    Note8("Change weights later on the phone — the watch only marks sets done.")
}

/** 숫자만 받는 칸 (AMRAP 추가 동작 수 등) */
@Composable
internal fun NumberBox(value: String, hint: String, tag: String, onChange: (String) -> Unit) {
    Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.08f))
        .padding(horizontal = 12.dp, vertical = 9.dp), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) T(hint, F.t(17, color = C.text3), maxLines = 1, translate = false)
        BasicTextField(value, { v -> onChange(v.filter { it.isDigit() }.take(3)) }, Modifier.fillMaxWidth().testTag(tag),
            textStyle = F.num(17), singleLine = true, cursorBrush = SolidColor(C.accent),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
    }
}
