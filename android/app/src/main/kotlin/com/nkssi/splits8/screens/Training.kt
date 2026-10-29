package com.nkssi.splits8.screens

import android.content.Intent
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.nkssi.splits8.Ask
import com.nkssi.splits8.BonusRequest
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.ProgramLink
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.Avatar8
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
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.PagedCard
import com.nkssi.splits8.ui.Pills8
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionText
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.SwipeDelete
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.doubleChevron
import com.nkssi.splits8.ui.dragLift
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rememberReorder
import com.nkssi.splits8.ui.reorderItem
import com.nkssi.splits8.ui.reorderLongPress
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.statusTop
import com.nkssi.splits8.ui.strokeBorder
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

// 아이폰 TrainingViews.swift — I1 트레이닝 목록 · I2 만들기/고치기

// MARK: - I1 트레이닝 탭

@Composable
fun TrainingView() {
    var expanded by remember { mutableStateOf(setOf<String>()) }
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            NewTrainingButton()
            Store.friend?.let { FriendTargets(it) }
            val progs = Store.programs
            if (progs.isNotEmpty()) ListHeader(progs.size)
            // 17번: 꾹 눌러 끌어서 순서 바꾸기 (programs 순서 그대로 저장 → 워치에도 같은 순서). 지우기는 왼쪽으로 밀기
            val re = rememberReorder(10.dp)
            if (progs.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                re.order(progs.size).forEach { i ->
                    if (i in progs.indices) key(progs[i].id) {
                        val p = progs[i]
                        Box(Modifier.reorderItem(re, i, corner = 20.dp)) {
                            SwipeDelete(
                                "Delete this training?", Modifier.fillMaxWidth().testTag("training.card"), corner = 20.dp,
                                alertMessage = "Records you've done with it stay in History.",
                                onTap = { if (p.isOpen) Router.bonus = BonusRequest(p.kind ?: "run", p) else Router.edit(p) },
                                onDelete = { Store.deleteProgram(p.id) },
                                longPressDelete = false,
                                inner = Modifier.reorderLongPress(re, i, progs.size) { from, to -> Store.movePrograms(from, to) },
                            ) {
                                ProgramCard(p, p.id in expanded) { expanded = if (p.id in expanded) expanded - p.id else expanded + p.id }
                            }
                        }
                    }
                }
            }
            TrainingHistory()
        }
    }
}

/** 노란 "New training" 카드 (모서리 20, 16×18, 17/600, + 22). 5개가 꽉 차면 안내만 */
@Composable
private fun NewTrainingButton() {
    val shape = RoundedCornerShape(20.dp)
    Row(
        Modifier.fillMaxWidth().yellowFill(shape).press(tag = "training.new") {
            if (Store.programs.size >= Program.freeLimit) {
                Router.ask = Ask(L10n.t("You can save up to %lld trainings", Program.freeLimit), "Delete one to make a new training.", cancel = null)
            } else Router.newTraining()
        }.padding(vertical = 16.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        T("New training", F.t(17, W600, Color.Black, tracking = -0.17f), Modifier.weight(1f), maxLines = 1)
        Glyph("i_plus", 22.dp, Color.Black)
    }
}

/** 소제목 "My Trainings" + 오른쪽 개수 "3 / 5" (꽉 차면 노랑) */
@Composable
private fun ListHeader(n: Int) {
    Row(Modifier.fillMaxWidth().padding(top = 14.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        T(SectionText.shown("MY TRAININGS"), F.t(F.sub, W600), Modifier.weight(1f), maxLines = 1, translate = false)
        T("$n / ${Program.freeLimit}", F.num(13, W400, if (n >= Program.freeLimit) C.accent else C.text2),
            Modifier.testTag("training.count"), translate = false)
    }
}

/** 친구를 골랐을 때: 구간 목표를 내 것 / 친구 것 중에서 */
@Composable
private fun FriendTargets(f: Friend) {
    Row(Modifier.fillMaxWidth().card8().padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Avatar8(36.dp, f.ini)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Label8("SPLIT TARGETS")
            T(L10n.t("%@'s splits", f.first), F.t(15), maxLines = 1, translate = false)
        }
        Pills8(listOf("mine" to "Mine", "friend" to f.first), Store.settings.tgtSrc) { Store.setTgtSrc(it) }
    }
}

@Composable
private fun TrainingHistory() {
    val recs = Store.book.records(Mode.Training)
    HistoryHeader()
    if (recs.isEmpty()) {
        EmptyHistory()
    } else {
        PagedCard(recs.size) { i, last ->
            val rec = recs[i]
            HistoryRow(
                if (rec.kind != null) rec.title.l10n else "${rec.title.l10n} × ${rec.sets}", Fm.wdm(rec.date), Fm.t(rec.total),
                last = last, pb = Store.book.isPB(rec), flag = rec.flag, partner = rec.partner, pbLabel = Store.book.runPBLabel(rec),
                onDelete = { Store.delete(rec) },
            ) { Router.open(rec, Scr.Training) }
        }
    }
}

// MARK: 저장된 트레이닝 카드

private const val PER_ROW = 4

/**
 * 저장된 트레이닝 카드 — 기록 목록과 구분되게 옅은 노란 기운 + 노란 테두리 + 오른쪽 노란 › 동그라미.
 * 아이콘 칩은 한 줄만 보이고 나머지는 "︾ N" (누르면 그 카드만 펼쳐짐, "︽" 로 접힘)
 */
@Composable
fun ProgramCard(p: Program, expanded: Boolean, onMore: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape)
            .background(Brush.linearGradient(0f to C.accent.copy(alpha = 0.15f), 0.55f to Color.White.copy(alpha = 0.07f), 1f to Color.White.copy(alpha = 0.05f)))
            .strokeBorder(C.accent.copy(alpha = 0.28f), 20.dp)
            .padding(vertical = 16.dp, horizontal = 18.dp)
            .animateContentSize(tween(250)),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                T(p.cardMeta, F.t(13, color = C.text2), maxLines = 1, translate = false)
                T(p.name, F.t(20, W600, tracking = -0.4f), maxLines = 1)
            }
            Box(Modifier.size(30.dp).clip(CircleShape).background(C.accent), contentAlignment = Alignment.Center) {
                Glyph("i_chevR", 13.dp, Color.Black)
            }
        }
        if (p.isOpen) {
            Row(Modifier.height(34.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon8(Kinds.icon(p.kind), 18.dp, C.accent)
                T(openLine(p), F.t(13, W600, C.d1), maxLines = 1, translate = false)
            }
        } else {
            Chips(p, expanded, onMore)
        }
    }
}

/** HIIT: "Intervals" / 러닝: "5 KM · Outdoor" / 18번: 종류 이름 (타바타 · EMOM …) */
private fun openLine(p: Program): String {
    if (p.isHIIT) return "Intervals".l10n
    if (Kinds.isNew(p.kind)) return Kinds.title(p.kind).l10n
    val km = p.runKm ?: 0
    val d = if (km > 0) "$km KM" else "Free run".l10n
    return d + " · " + (if (p.indoor == true) "Indoor" else "Outdoor").l10n
}

/** 칩 라벨: 상세의 " · " 앞부분, " REPS" 제거 */
private fun chipLabel(it: ProgItem): String =
    it.detail(Store.settings.div).split(" · ").first().replace(" REPS", "").replace(" KG", "KG")

@Composable
private fun Chips(p: Program, expanded: Boolean, onMore: () -> Unit) {
    val n = p.seq.size
    val long = n > PER_ROW
    val collapsed = long && !expanded
    val shown = if (collapsed) p.seq.take(PER_ROW - 1) else p.seq
    Grid4(shown.size + if (long) 1 else 0, 6.dp) { i, m ->
        when {
            i < shown.size -> Chip(shown[i], m)
            collapsed -> MoreChip(n - (PER_ROW - 1), m, onMore)
            else -> MoreChip(null, m, onMore)
        }
    }
}

/** 4칸 격자 (빈칸은 자리만). cell(번호, 칸 크기) */
@Composable
private fun Grid4(count: Int, gap: Dp, cell: @Composable (Int, Modifier) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(gap)) {
        for (row in (0 until count).chunked(PER_ROW)) {
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (i in row) cell(i, Modifier.weight(1f))
                repeat(PER_ROW - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun Chip(it: ProgItem, modifier: Modifier) {
    Row(modifier.height(34.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally)) {
        Icon8(it.icon, 16.dp, C.accent)
        T(chipLabel(it), F.t(11, W600, C.d1, tracking = 0.22f), maxLines = 1, translate = false)
    }
}

/** 더 보기 칩: 접힘 = ︾ + 남은 개수, 펼침 = ︽ 만. 가는 실선 테두리 */
@Composable
private fun MoreChip(more: Int?, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.height(34.dp).strokeBorder(Color.White.copy(alpha = 0.16f), 10.dp).tap(onClick = onClick).testTag("training.more"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        Box(Modifier.size(10.dp, 11.dp).doubleChevron(up = more == null))
        if (more != null) T("$more", F.num(12, W600, C.aeb), maxLines = 1, translate = false)
    }
}

// MARK: 링크 · 폰으로 시작 단추

/** "Share link": 저장된 트레이닝을 링크 하나로 보냄 (안드로이드 공유 창) */
@Composable
fun ShareTrainingButton(program: Program) {
    val ctx = LocalContext.current
    Row(
        Modifier.height(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f))
            .press(0.96f, tag = "builder.shareLink") {
                val url = ProgramLink.webUrl(program) ?: return@press
                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, url)
                runCatching { ctx.startActivity(Intent.createChooser(send, null)) }
            }.padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Sym(R.drawable.sym_link, 15.dp)
        T("Share link", F.t(14, W600), maxLines = 1)
    }
}

/** "Start on phone" (아이폰 StartOnPhoneButton). 시작 전 확인: 폰 기록은 심박 등을 못 씀 */
@Composable
fun StartOnPhoneButton(mode: Mode, program: Program?, before: (() -> Unit)? = null) {
    Row(
        Modifier.height(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f))
            .press(0.96f, tag = "startOnPhone." + mode.name.lowercase()) { askStartOnPhone(mode, program, before) }
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Sym(R.drawable.sym_phone, 15.dp)
        T("Start on phone", F.t(14, W600), maxLines = 1)
    }
}

/** 폰으로 시작 전 확인 창 (폰 기록은 심박 등을 못 씀) */
fun askStartOnPhone(mode: Mode, program: Program? = null, before: (() -> Unit)? = null) {
    Router.ask = Ask(
        "Start on phone?",
        "Recording on your phone can't measure heart rate, calories or HR zones, and there are no watch vibration alerts. Only split times are recorded (plus GPS distance for outdoor runs).",
        ok = "Start",
    ) { before?.invoke(); Router.startOnPhone(mode, program) }
}

// MARK: - I2 새 트레이닝 / 고치기 (맨 위 고정 Cancel · 제목 · Save)

@Composable
fun BuilderView() {
    Box(Modifier.fillMaxSize()) {
        Scroll8(bottom = 60.dp) {
            Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                Field8("Training name", Router.draftName, Modifier.testTag("builder.name")) { Router.draftName = it.take(ProgramLink.maxName) }
                val prog = Router.editId?.let { id -> Store.programs.firstOrNull { it.id == id } }
                if (prog != null) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        // 고치는 중(아직 저장 안 함)에는 링크를 숨김 — 링크에는 저장된 내용이 들어가므로
                        if (ProgramLink.canShare(prog) && Router.draftSeq == prog.seq && Router.draftSets == prog.sets) ShareTrainingButton(prog)
                        Spacer(Modifier.weight(1f))
                        StartOnPhoneButton(Mode.Training, prog)
                    }
                }
                RunSection()
                StationSection()
                SequenceSection()
                SetsCard()
                if (Router.editId == null) BonusCards()
                val id = Router.editId
                if (id != null) {
                    Box(
                        Modifier.fillMaxWidth().height(50.dp).card8(14.dp).press(tag = "builder.delete") {
                            Store.deleteProgram(id); Router.editId = null; Router.go(Scr.Training)
                        },
                        contentAlignment = Alignment.Center,
                    ) { T("Delete training", F.t(17, W600, C.bad), maxLines = 1) }
                }
            }
        }
        BuilderBar()
    }
}

/** 맨 위 고정 머리줄 (Cancel · New training / Edit training · Save). 비었으면 Save 회색 */
@Composable
private fun BuilderBar() {
    val top = statusTop()
    Box(
        Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.82f)).padding(top = top).padding(horizontal = PageSide)
            .rowLine(true),
    ) {
        NavBar3("Cancel", if (Router.editId == null) "New training" else "Edit training", right = "Save",
            rightColor = if (Router.draftSeq.isEmpty()) C.g3A else C.accent,
            onLeft = { Router.cancelDraft() }, onRight = { Router.saveDraft() })
    }
}

// HIIT · 러닝 카드 (새로 만들 때만, 맨 아래)

// 18번: 러닝 · 인터벌 러닝 · HIIT · 타바타 · EMOM · AMRAP · 기능성 운동 (2칸씩)
@Composable
private fun BonusCards() {
    Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (row in Kinds.menu.chunked(2)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (k in row) BonusCard(k, Kinds.title(k), Kinds.sub(k), Modifier.weight(1f))
                if (row.size < 2) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun BonusCard(kind: String, title: String, sub: String, modifier: Modifier) {
    Column(modifier.card8().press(tag = "builder.bonus.$kind") { Router.bonus = BonusRequest(kind) }.padding(16.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Icon8(Kinds.icon(kind), 28.dp, C.accent)
            Spacer(Modifier.weight(1f))
            Chevron8()
        }
        T(title, F.t(17, W600), Modifier.padding(top = 12.dp), maxLines = 1)
        T(sub, F.t(13, color = C.text2), Modifier.padding(top = 3.dp), maxLines = 1)
    }
}

// RUN · STATIONS

/** 방금 누른 버튼 (노란 테두리 0.3초) */
private var flashKey by mutableStateOf<String?>(null)

@Composable
private fun RunSection() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionTitle("RUN")
        Grid4(Defaults.runs.size, 8.dp) { i, m ->
            val d = Defaults.runs[i]
            AddTile(ProgItem("run", d), "run|$d", 12.dp, m.height(46.dp), count = Router.draftSeq.count { it.icon == "run" && (it.run ?: "1KM") == d },
                tag = "builder.run.$d") {
                T(d, F.num(15), translate = false)
            }
        }
    }
}

@Composable
private fun StationSection() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionTitle("STATIONS")
        Grid4(Station.all.size, 8.dp) { i, m ->
            val s = Station.all[i]
            AddTile(ProgItem(s.key), s.key, 16.dp, m.aspectRatio(1f / 1.08f), count = Router.draftSeq.count { it.icon == s.key },
                tag = "builder.st.${s.key}") {
                Column(Modifier.padding(6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon8(s.key, 32.dp, C.accent)
                    // 버튼에서만 짧게
                    T(if (s.key == "farmersCarry") "Carry" else s.name, F.t(11, W600, tracking = 0.11f).copy(lineHeight = 13.sp), align = TextAlign.Center)
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(key: String) {
    T(SectionText.shown(key), F.t(F.sub, W600), Modifier.padding(horizontal = 4.dp), maxLines = 1, translate = false)
}

/**
 * 순서에 넣는 버튼: 누르는 동안 살짝 작아지고 밝아짐, 넣으면 가벼운 진동 + 노란 테두리 0.3초 + 오른쪽 위 횟수.
 * 16칸이 꽉 차면 넣지 않고 다른 진동
 */
@Composable
private fun AddTile(item: ProgItem, key: String, radius: Dp, modifier: Modifier, count: Int, tag: String, content: @Composable () -> Unit) {
    val haptic = LocalHapticFeedback.current
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.95f else 1f, tween(80), label = "tile")
    val shape = RoundedCornerShape(radius)
    Box(
        modifier.scale(s).card8(radius)
            .background(Color.White.copy(alpha = if (pressed) 0.07f else 0f), shape)
            .clickable(src, null) {
                if (Router.draftSeq.size >= Router.MAX_SEQ) {
                    haptic.performHapticFeedback(HapticFeedbackType.Reject)
                } else {
                    haptic.performHapticFeedback(HapticFeedbackType.VirtualKey)
                    Router.draftSeq = Router.draftSeq + item
                    flashKey = key
                }
            }
            .then(if (flashKey == key) Modifier.border(1.5.dp, C.accent, shape) else Modifier)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        content()
        if (count > 0) {
            Box(
                Modifier.align(Alignment.TopEnd).padding(5.dp).heightIn(min = 18.dp).widthIn(min = 18.dp)
                    .clip(CircleShape).background(C.accent).padding(horizontal = 5.dp),
                contentAlignment = Alignment.Center,
            ) { T("$count", F.num(12, W700, Color.Black), translate = false) }
        }
    }
    if (flashKey == key) {
        LaunchedEffect(key, count) { delay(300); if (flashKey == key) flashKey = null }
    }
}

// SEQUENCE (손잡이를 잡고 위아래로 끌면 다른 칸이 실시간으로 밀려남)

@Composable
private fun SequenceSection() {
    val seq = Router.draftSeq
    var dragFrom by remember { mutableStateOf<Int?>(null) }
    var dragY by remember { mutableFloatStateOf(0f) }
    var dragTo by remember { mutableIntStateOf(0) }
    var rowH by remember { mutableIntStateOf(0) }
    val haptic = LocalHapticFeedback.current

    // 끄는 중이면 놓일 자리 기준으로 미리 정렬한 순서 (원래 번호 목록)
    val order: List<Int> = seq.indices.toMutableList().also { o ->
        val f = dragFrom
        if (f != null && f in o.indices) { val x = o.removeAt(f); o.add(dragTo.coerceIn(0, o.size), x) }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            T(SectionText.shown(L10n.t("SEQUENCE · %lld/%lld", seq.size, Router.MAX_SEQ)), F.t(F.sub, W600), Modifier.weight(1f),
                maxLines = 1, translate = false)
            T("Clear all", F.t(13, W600, C.bad), Modifier.tap { Router.draftSeq = emptyList() }.testTag("builder.clear"), maxLines = 1)
        }
        if (seq.size >= Router.MAX_SEQ) {
            T("A set can have up to 16 segments. To repeat more, increase Sets below.", F.t(13, color = C.text2),
                Modifier.padding(horizontal = 4.dp).offset(y = (-4).dp))
        }
        Column(Modifier.fillMaxWidth().card8()) {
            if (seq.isEmpty()) {
                T("Tap runs and stations above\nto add them here in order", F.t(13, color = C.text3).copy(lineHeight = 19.sp),
                    Modifier.fillMaxWidth().padding(vertical = 22.dp, horizontal = 16.dp), align = TextAlign.Center)
            }
            Box {
                Column {
                    order.forEachIndexed { slot, i ->
                        // 74-3(안드로이드): 원래 번호로 key — 끄는 동안 줄 자리가 바뀌어도 같은 줄이 손가락을 계속 잡고 있게
                        //  (예전엔 자리 순서대로 그려서, 한 칸 넘어가는 순간 잡고 있던 줄이 바뀌며 끌기가 끊겼음)
                        if (i in seq.indices) key(i) {
                            val dragging = dragFrom == i
                            Box(Modifier.zIndex(if (dragging) 1f else 0f)) {
                                SeqRow(
                                    slot, seq[i], dragging, last = !dragging && slot == seq.size - 1,
                                    offsetPx = if (dragging) dragY - (slot - i) * rowH else 0f,
                                    onSize = { if (it > 20) rowH = it },
                                    onRemove = { if (i in Router.draftSeq.indices) Router.draftSeq = Router.draftSeq.toMutableList().also { l -> l.removeAt(i) } },
                                    handle = Modifier.pointerInput(i) {
                                        detectDragGestures(
                                            onDragStart = {
                                                dragFrom = i; dragTo = i; dragY = 0f
                                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                            },
                                            onDragEnd = {
                                                val f = dragFrom
                                                val t = dragTo.coerceIn(0, Router.draftSeq.size - 1)
                                                if (f != null && f != t && f in Router.draftSeq.indices) {
                                                    Router.draftSeq = Router.draftSeq.toMutableList().also { l -> l.add(t, l.removeAt(f)) }
                                                }
                                                dragFrom = null; dragY = 0f; dragTo = 0
                                            },
                                            onDragCancel = { dragFrom = null; dragY = 0f; dragTo = 0 },
                                        ) { ch, d ->
                                            ch.consume()
                                            dragY += d.y
                                            val steps = (dragY / maxOf(rowH, 1)).roundToInt()
                                            val t = (i + steps).coerceIn(0, Router.draftSeq.size - 1)
                                            if (t != dragTo) { dragTo = t; haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                                        }
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SeqRow(
    slot: Int, it: ProgItem, dragging: Boolean, last: Boolean, offsetPx: Float, onSize: (Int) -> Unit,
    onRemove: () -> Unit, handle: Modifier,
) {
    Row(
        Modifier.fillMaxWidth()
            // 17번: 끄는 줄 모양은 트레이닝 목록 · 친구 목록과 공용 (ui/Reorder.kt)
            .dragLift(dragging) { offsetPx }
            .onSizeChanged { s -> onSize(s.height) }
            .rowLine(!dragging && !last)
            .padding(vertical = 11.dp).padding(start = 16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        T("${slot + 1}", F.num(13, W400, C.text3), Modifier.width(18.dp), translate = false)
        Icon8(it.icon, 24.dp, C.accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(it.name(), F.t(17), maxLines = 1)
            T(com.nkssi.splits8.shared.Units.detail(it.detail(Store.settings.div), Store.settings.imperial), F.t(11, W600, C.text2, tracking = 0.66f), maxLines = 1, translate = false)
        }
        // 빼기 원 (#2A2A2A + 빨간 −)
        Box(Modifier.size(20.dp).tap(onClick = onRemove).testTag("builder.remove.$slot"), contentAlignment = Alignment.Center) {
            Box(Modifier.size(16.7.dp).clip(CircleShape).background(Color(0xFF2A2A2A)), contentAlignment = Alignment.Center) {
                Box(Modifier.size(6.7.dp, 1.85.dp).clip(CircleShape).background(C.bad))
            }
        }
        // 끌기 손잡이 (두 줄 #3A3A3C)
        Box(handle.size(44.dp, 40.dp).testTag("builder.handle.$slot"), contentAlignment = Alignment.Center) {
            Column(verticalArrangement = Arrangement.spacedBy(4.5.dp)) {
                Box(Modifier.size(12.dp, 1.5.dp).clip(CircleShape).background(C.g3A))
                Box(Modifier.size(12.dp, 1.5.dp).clip(CircleShape).background(C.g3A))
            }
        }
    }
}

@Composable
private fun SetsCard() {
    Row(Modifier.fillMaxWidth().card8().padding(vertical = 12.dp, horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        T("Sets", F.t(15), Modifier.weight(1f))
        Stepper8("${Router.draftSets}", down = { Router.draftSets = maxOf(1, Router.draftSets - 1) },
            up = { Router.draftSets = minOf(ProgramLink.maxSets, Router.draftSets + 1) })
    }
}
