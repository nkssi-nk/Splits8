package com.nkssi.splits8.wear

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.animation.core.spring
import kotlinx.coroutines.launch
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.IvStep
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import kotlinx.coroutines.delay

// 운동 전 화면 (아이폰 SplitsWatchApp.swift): 홈(모드 4개) · 트레이닝 목록 · 빠른 트레이닝 · 확인 · 3 · 2 · 1
// 갤럭시 워치는 동그란 화면 → 목록은 위아래 끝에서 작아지며 지나가는 둥근 목록(ScalingLazyColumn), 크라운 · 베젤로 넘김.

enum class WScreen { Programs, Quick, Confirm, Goal }

/** 워치 화면 이동 (아이폰 WNav) */
object WNav {
    /** 첫 화면 위에 쌓인 화면들 (비면 첫 화면) */
    var path by mutableStateOf<List<WScreen>>(emptyList())
    var mode by mutableStateOf(Mode.Race)
    var program by mutableStateOf<Program?>(null)
    var quick by mutableStateOf<List<ProgItem>>(emptyList())

    /** 모드를 먼저 정한 다음 부를 것 — 확인 화면 앞에 트레이닝 목록을 둘지 모드로 정함 */
    fun open(s: WScreen?) {
        path = when (s) {
            null -> emptyList()
            WScreen.Programs -> listOf(WScreen.Programs)
            WScreen.Quick -> listOf(WScreen.Programs, WScreen.Quick)
            WScreen.Confirm -> if (mode == Mode.Training) listOf(WScreen.Programs, WScreen.Confirm) else listOf(WScreen.Confirm)
            WScreen.Goal -> listOf(WScreen.Confirm, WScreen.Goal)
        }
    }

    fun pop() { path = path.dropLast(1) }

    fun openMode(m: Mode) {
        mode = m; program = null
        open(if (m == Mode.Training) WScreen.Programs else WScreen.Confirm)
    }
}

/** 화면 크기 비율 (225dp = 큰 워치 기준 1.0) */
@Composable
fun wk(): Float = (LocalConfiguration.current.screenWidthDp / 225f).coerceIn(0.82f, 1.12f)

/** 둥근 화면 목록 (워치 기본: 두 번째 줄이 가운데, 위아래 끝에서 작아짐 · 크라운 · 베젤로 넘김) */
@Composable
fun RoundList(tag: String, modifier: Modifier = Modifier, center: Int = 1, offset: Int = 0, side: Float = 16f,
              content: androidx.wear.compose.foundation.lazy.ScalingLazyListScope.() -> Unit) {
    val state = rememberScalingLazyListState(initialCenterItemIndex = center, initialCenterItemScrollOffset = offset)
    val k = wk()
    ScalingLazyColumn(
        modifier.fillMaxSize().testTag(tag),
        state = state,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = (side * k).dp),
        verticalArrangement = Arrangement.spacedBy(5.dp),
        content = content,
    )
}

// MARK: - 1.2.7 메뉴 공통 (검정 + 테마 빛 덩어리, 유리 카드 · 버튼)

/** 유리 바탕 (목록 줄 · 카드) */
fun Modifier.glassBg(radius: androidx.compose.ui.unit.Dp, fill: Color, rim: Float = 0.55f, gloss: Float = 0f): Modifier =
    this.drawBehind { wGlass(Offset.Zero, size, radius.toPx(), fill, rim, gloss) }

/** 맑은 유리 (흰 12%) */
val GlassClear = Color.White.copy(alpha = 0.12f)
/** 노란 유리 (84%) */
val GlassYellow = hex(0xFFDC14, 0.84f)

/** 메뉴 화면 틀: 바탕 · 시계 · 노란 제목 (높이 34) */
@Composable
fun WMenuFrame(seed: Int, title: String?, tag: String, translate: Boolean = true, content: @Composable BoxWithConstraintsScope.(WScale) -> Unit) {
    Box(Modifier.fillMaxSize().testTag(tag)) {
        WMenuBackground(seed)
        WCanvas { L ->
            WClock(L, Color.White)
            if (title != null) WMenuTitle(L, title, translate)
            content(L)
        }
    }
}

// MARK: - 홈

/**
 * 1.2.7 첫 화면: 시계 → SPLITS8 로고(높이 10, 위 30) → 카드 4개 모두 같은 폭 (높이 30 · 간격 5, 로고 + 카드 묶음이 동그라미 가운데).
 * 아이콘 15 · 이름 시작 34 · 오른쪽 버튼 r9 (Training = 맑은 유리 ›, 그 밖 = 노란 유리 ▶)
 */
@Composable
fun WHome() {
    WMenuFrame(40, null, "w.home") { L ->
        Box(Modifier.at(L.dx(WScale.D / 2), L.dy(35f))) { Wordmark(10f * L.s / 0.83f) }
        val hgt = 30f
        val g = 5f
        val tot = 4 * hgt + 3 * g
        val y0 = WScale.D / 2 + 10f - tot / 2
        val w = L.rowW(y0, y0 + tot, 10f, 156f)
        val x0 = WScale.D / 2 - w / 2
        val modes = listOf(Mode.Training, Mode.Pft, Mode.Sim, Mode.Race)
        // 모든 이름 같은 크기 (가장 긴 이름이 들어가게)
        val lim = w - 34f - 6f - 18f - 6f
        val m = androidx.compose.ui.text.rememberTextMeasurer()
        val density = LocalDensity.current
        val fs = remember(L.s, lim) {
            var sz = 14f
            while (sz > 10f && modes.maxOf { md -> with(density) { m.measure(wt(md.title), wf(L, sz, W600)).size.width.toDp().value } } > lim * L.s) sz -= 0.5f
            sz
        }
        modes.forEachIndexed { i, md ->
            val y = y0 + i * (hgt + g)
            WPill(L, x0, y, w, hgt, GlassClear, 0.55f, "w.mode." + md.raw, onClick = { WNav.openMode(md) }) {
                Box(Modifier.fillMaxSize()) {
                    Box(Modifier.align(Alignment.CenterStart).padding(start = L.dv(19f - 7.5f))) { ModeIcon(md, C.accent, L.dv(15f)) }
                    T(md.title, wf(L, fs, W600), Modifier.align(Alignment.CenterStart).padding(start = L.dv(34f)).width(L.dv(lim)), align = TextAlign.Start)
                    // 오른쪽 버튼 r9
                    Box(Modifier.align(Alignment.CenterEnd).padding(end = L.dv(6f)).size(L.dv(18f))
                        .glassBg(L.dv(9f), if (md == Mode.Training) Color.White.copy(alpha = 0.16f) else GlassYellow, if (md == Mode.Training) 0.55f else 0.47f,
                            if (md == Mode.Training) 0f else 0.27f), contentAlignment = Alignment.Center) {
                        Canvas(Modifier.size(L.dv(9f))) {
                            if (md == Mode.Training) {
                                val p = androidx.compose.ui.graphics.Path().apply {
                                    moveTo(size.width * 0.35f, size.height * 0.15f); lineTo(size.width * 0.7f, size.height / 2); lineTo(size.width * 0.35f, size.height * 0.85f)
                                }
                                drawPath(p, Color.White, style = androidx.compose.ui.graphics.drawscope.Stroke(1.8f * density.density,
                                    cap = androidx.compose.ui.graphics.StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
                            } else wPlay(center + Offset(0.6f * density.density, 0f), size.width, Color.Black)
                        }
                    }
                }
            }
        }
    }
}

/** Training = modeTraining, PFT = modePFT, Full Sim = i_sim, Race = i_race (노랑) */
@Composable
fun ModeIcon(m: Mode, color: Color = C.accent, size: androidx.compose.ui.unit.Dp = 22.dp) {
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        when (m) {
            Mode.Training -> Icon8("modeTraining", size, color)
            Mode.Pft -> Icon8("modePFT", size, color)
            Mode.Sim -> Icon8("i_sim", size * 0.91f, color)
            Mode.Race -> Icon8("i_race", size * 0.91f, color)
        }
    }
}

/** 목록 안 제목 (노랑 13) */
@Composable
fun WTitle(text: String, translate: Boolean = true) {
    T(text, F.t(13 * wk(), W600, C.accent), Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 4.dp), align = TextAlign.Center, translate = translate)
}

// MARK: - 트레이닝 목록

/** 제목 → Quick training (노란 유리 30 + ＋) · 트레이닝 카드 (36, 이름 13 + 설명 10 + ›). 같은 폭, 가운데 */
@Composable
fun WPrograms() {
    val k = wk()
    Box(Modifier.fillMaxSize()) {
        WMenuBackground(51)
        RoundList("w.programs", side = 0f) {
            item { WTitle("Training") }
            item {
                Row(Modifier.width(screenFrac(0.72f)).height((30 * k).dp).glassBg((15 * k).dp, GlassYellow, 0.47f, 0.27f)
                    .press { WNav.quick = emptyList(); WNav.open(WScreen.Quick) }.padding(horizontal = (14 * k).dp).testTag("w.quick"),
                    verticalAlignment = Alignment.CenterVertically) {
                    T("Quick training", F.t(14 * k, W600, Color.Black), Modifier.weight(1f), align = TextAlign.Start)
                    Icon8("i_plus", (11 * k).dp, Color.Black)
                }
            }
            for (p in WatchStore.programs) item {
                Row(Modifier.width(screenFrac(0.72f)).heightIn(min = (36 * k).dp).glassBg((18 * k).dp, GlassClear)
                    .press { WNav.program = p; WNav.open(WScreen.Confirm) }.padding(horizontal = (14 * k).dp, vertical = (5 * k).dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        T(p.name, F.t(13 * k, W600), Modifier.fillMaxWidth(), align = TextAlign.Start, minScale = 0.8f, translate = false)
                        T(p.watchMeta, F.t(10 * k, W500, Color.White.copy(alpha = 0.6f)), Modifier.fillMaxWidth(), align = TextAlign.Start, minScale = 0.8f, translate = false)
                    }
                    Icon8("i_chevRw", (9 * k).dp, Color.White.copy(alpha = 0.5f))
                }
            }
            item { T("Edit names on your phone", F.t(11 * k, color = C.text3), Modifier.fillMaxWidth().padding(vertical = 4.dp), align = TextAlign.Center) }
        }
    }
}

// MARK: - 빠른 트레이닝

/** 러닝 4칸(높이 22) + 스테이션 4 × 2 (34 × 38, 아이콘 17 + 이름 8) 을 눌러 쌓음 (최대 16). 아래로: 쌓인 칩 · Remove last | Clear all · ▶ Start */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WQuick(buzz: (BuzzKind) -> Unit) {
    val k = wk()
    var toast by remember { mutableStateOf<String?>(null) }
    var toastId by remember { mutableIntStateOf(0) }
    LaunchedEffect(toastId) { if (toastId > 0) { delay(1100); toast = null } }

    fun show(t: String) { toast = t; toastId++ }
    fun add(q: ProgItem) {
        if (WNav.quick.size >= MAX_SEGS) {
            buzz(BuzzKind.Failure)
            show(wt("Max %lld segments", MAX_SEGS))
            return
        }
        WNav.quick = WNav.quick + q
        buzz(BuzzKind.Click)
        show("＋ " + chipLabel(q, full = true) + " · " + wt("No. %lld", WNav.quick.size))
    }

    Box(Modifier.fillMaxSize()) {
        WMenuBackground(52)
        val cw = (34 * k).dp
        val g = (4 * k).dp
        RoundList("w.quickList", side = 0f) {
            item { WTitle("Quick training") }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(g)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(g)) {
                        for (r in Defaults.runs) {
                            Box(Modifier.size(cw, (22 * k).dp).glassBg((9 * k).dp, GlassClear).press { add(ProgItem("run", r)) }.testTag("w.quick.run.$r"),
                                contentAlignment = Alignment.Center) {
                                T(r, F.t(11 * k, W600), Modifier.padding(horizontal = 1.dp), minScale = 0.7f, translate = false)
                            }
                        }
                    }
                    for (row in Station.all.chunked(4)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(g)) {
                            for (s in row) {
                                Box(Modifier.size(cw, (38 * k).dp).glassBg((9 * k).dp, GlassClear).press { add(ProgItem(s.key)) }.testTag("w.quick." + s.key)) {
                                    Icon8(s.key, (17 * k).dp, Tint.Yellow, Modifier.align(Alignment.TopCenter).padding(top = (6 * k).dp))
                                    T(chipLabel(ProgItem(s.key)), F.t(8 * k, W600, Color.White.copy(alpha = 0.6f)),
                                        Modifier.align(Alignment.BottomCenter).padding(bottom = (3 * k).dp, start = 1.dp, end = 1.dp), minScale = 0.7f, translate = false)
                                }
                            }
                        }
                    }
                }
            }
            // 쌓인 구간
            item {
                FlowRow(Modifier.width(screenFrac(0.68f)).heightIn(min = 22.dp).padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(g, Alignment.CenterHorizontally),
                    verticalArrangement = Arrangement.spacedBy(g)) {
                    if (WNav.quick.isEmpty()) T("Tap to add", F.t(12 * k, color = C.text3))
                    for (q in WNav.quick) {
                        Row(Modifier.height((20 * k).dp).glassBg((7 * k).dp, GlassClear, 0.47f).padding(horizontal = (6 * k).dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((4 * k).dp)) {
                            Icon8(q.icon, (11 * k).dp, if (q.icon == "run") Tint.White else Tint.Yellow)
                            T(chipLabel(q), F.t(11 * k, W600), translate = false)
                        }
                    }
                }
            }
            if (WNav.quick.isNotEmpty()) {
                item {
                    Row(Modifier.width(screenFrac(0.66f)), horizontalArrangement = Arrangement.spacedBy((6 * k).dp)) {
                        SmallButton("Remove last", Modifier.weight(1f).testTag("w.quickUndo")) { WNav.quick = WNav.quick.dropLast(1); buzz(BuzzKind.Click) }
                        SmallButton("Clear all", Modifier.weight(1f).testTag("w.quickClear")) { WNav.quick = emptyList(); buzz(BuzzKind.Click) }
                    }
                }
                item { Spacer(Modifier.height((64 * k).dp)) }
            }
        }
        if (WNav.quick.isNotEmpty()) {
            WCanvas { L ->
                WEdgeButton(L, wt("Start · %lld segments", WNav.quick.size), "play", "w.quickStart") {
                    val p = WatchStore.saveQuick(WNav.quick)
                    WNav.program = p; WNav.quick = emptyList(); WNav.open(WScreen.Confirm)
                }
            }
        }
        // 알림 (가운데 위쪽에 잠깐)
        AnimatedVisibility(toast != null, Modifier.align(Alignment.TopCenter).padding(top = (46 * k).dp).widthIn(max = roundWidth(46 * k)),
            enter = fadeIn() + slideInVertically { -it / 2 }, exit = fadeOut()) {
            Box(Modifier.height(26.dp).glassBg(13.dp, GlassYellow, 0.47f, 0.27f).padding(horizontal = 10.dp).testTag("w.quickToast"),
                contentAlignment = Alignment.Center) {
                T(toast ?: "", F.t(13, W600, Color.Black), translate = false)
            }
        }
    }
}

const val MAX_SEGS = 16

@Composable
private fun SmallButton(t: String, modifier: Modifier, onClick: () -> Unit) {
    val k = wk()
    Box(modifier.height((28 * k).dp).glassBg((14 * k).dp, GlassClear).press(onClick = onClick), contentAlignment = Alignment.Center) {
        T(t, F.t(11 * k, W600), Modifier.padding(horizontal = 4.dp))
    }
}

private fun chipLabel(q: ProgItem, full: Boolean = false): String {
    if (q.icon == "run") return q.run ?: "1KM"
    if (full) return q.name()
    return q.name().replace("Farmers Carry", "FC").replace("Wall Balls", "WB").replace("Sled Push", "Push").replace("Sled Pull", "Pull")
        .replace("SkiErg", "Ski")
}

// MARK: - 확인 (Start)

/**
 * 1.2.7: Race · Full Sim · 러닝 카드 = 가운데 블록 + 아래 끝 버튼 ▶ Start. PFT · 트레이닝 = 목록 (줄 높이 20) + 아래 끝 버튼.
 */
@Composable
fun WConfirm(onStart: (indoor: Boolean?) -> Unit) {
    val mode = WNav.mode
    val program = WNav.program ?: Program.presets()[0]
    val seq = WatchStore.seq(mode, if (mode == Mode.Training) program else null)
    val ev = WatchStore.settings.event
    val noEvent = mode == Mode.Race && !ev.isSet
    val title = if (mode == Mode.Training) program.name else mode.title
    val tr = mode != Mode.Training
    when {
        noEvent -> WMenuFrame(54, title, "w.confirm", tr) { L ->
            WText("No race set up", wf(L, 15f, W700), L, WScale.D / 2, 88f, 160f, translate = true)
            T("Add a race in the Race tab of the phone app and it will show up here.", wf(L, 11f, W500, Color.White.copy(alpha = 0.6f)),
                Modifier.at(L.dx(WScale.D / 2), L.dy(124f)).width(L.dv(150f)), maxLines = 4, align = TextAlign.Center)
        }
        mode == Mode.Race || mode == Mode.Sim -> WMenuFrame(if (mode == Mode.Race) 54 else 55, title, "w.confirm", tr) { L ->
            val small = if (mode == Mode.Race) Fm.wdm(ev.date) + " · " + WatchStore.settings.div.name
                else WatchStore.settings.div.name + " · " + "8 runs · 8 stations".l10n
            // 86번: 워치에서 고른 목표는 그 숫자 그대로
            val goal = if (mode == Mode.Race) Fm.t(WatchStore.settings.goalTime)
                else WatchGoal.shown(WatchStore.watchGoal, seq, WatchStore.settings.roxTarget)
            val w = WatchStore.simPick.second
            val goalWord = if (mode == Mode.Race) "GOAL" else if (w == "VS GOAL") "GOAL" else w
            // 묶음: (대회 이름 15 Bold → 7 →) 작은 줄 11 → 12 → 블록 [GOAL · 1:20:00 · (TAP TO CHANGE)]
            val c1 = wCap(15f)
            val c2 = wCap(11f)
            val tapWord = if (mode == Mode.Sim) wt("TAP TO CHANGE") else ""
            val blk = 10f + wCap(10f) + 8f + wCap(34f) + (if (tapWord.isEmpty()) 0f else 8f + wCap(9f)) + 10f
            val tot = (if (mode == Mode.Race) c1 + 7f else 0f) + c2 + 12f + blk
            var y = (45f + 168f) / 2 - tot / 2
            if (mode == Mode.Race) {
                WText(ev.name, wf(L, 15f, W700), L, WScale.D / 2, y + c1 / 2, 160f, minScale = 0.7f)
                y += c1 + 7f
            }
            WText(small, wf(L, 11f, W600, Color.White.copy(alpha = 0.6f)), L, WScale.D / 2, y + c2 / 2, 160f, minScale = 0.7f)
            y += c2 + 12f
            WBlock(L, y, y + blk, wt(goalWord), goal, tapWord, center = y + blk / 2)
            if (mode == Mode.Sim) {
                Box(Modifier.at(L.dx(WScale.D / 2), L.dy(y + blk / 2)).size(L.dv(150f), L.dv(blk)).testTag("w.simGoal")
                    .press { WNav.open(WScreen.Goal) })
            }
            WEdgeButton(L, "Start", "play", "w.start") { onStart(null) }
        }
        mode == Mode.Training && program.isRun -> WMenuFrame(58, title, "w.confirm", false) { L ->
            // 러닝 카드: [DISTANCE 5.00 · KM] → Indoor · No GPS (맑은 유리 알약 110 × 28) → 아래 끝 버튼 ▶ Outdoor · GPS (카드에 저장된 쪽이 아래 끝 버튼)
            val cardIndoor = program.indoor ?: false
            val hb = 28f
            val yb1 = 172f - 8f - hb
            val km = program.runKm ?: 0
            WBlock(L, 45f, yb1 - 4f, wt("DISTANCE"), if (km > 0) String.format(java.util.Locale.US, "%.2f", km.toDouble()) else wt("Free"), if (km > 0) "KM" else "")
            WPill(L, WScale.D / 2 - 55f, yb1, 110f, hb, GlassClear, 0.55f, if (cardIndoor) "w.startOutdoor" else "w.startIndoor",
                onClick = { onStart(!cardIndoor) }) {
                T(if (cardIndoor) wt("Outdoor") + " · GPS" else wt("Indoor") + " · " + wt("No GPS"), wf(L, 12f, W600), translate = false)
            }
            WEdgeButton(L, if (cardIndoor) wt("Indoor") + " · " + wt("No GPS") else wt("Outdoor") + " · GPS", "play",
                if (cardIndoor) "w.startIndoor" else "w.startOutdoor") { onStart(cardIndoor) }
        }
        else -> ListConfirm(mode, program, seq, title, onStart)
    }
}

/** PFT · 트레이닝 · 18번 운동: 제목 → 설명 한 줄 → 줄 (높이 20, 아이콘 12 · 이름 13 · 오른쪽 숫자) → 아래 끝 버튼 ▶ Start */
@Composable
private fun ListConfirm(mode: Mode, program: Program, seq: List<com.nkssi.splits8.shared.Seg>, title: String, onStart: (Boolean?) -> Unit) {
    val k = wk()
    val tr = mode != Mode.Training
    val rows: List<Triple<String, String, String>> = when {
        mode == Mode.Training && Kinds.isNew(program.kind) -> bonusLines(program).map { Triple(Kinds.icon(program.kind), it.first, it.second) }
        mode == Mode.Training && program.isOpen -> emptyList()
        mode == Mode.Pft -> seq.map { Triple(it.icon, it.name, it.detail.split(" · ").first()) }
        else -> seq.filter { it.kind != SegKind.Rox || it.icon == "rest" }.map { Triple(it.icon, it.name, if (it.target > 0) Fm.t(it.target) else "–") }
    }
    Box(Modifier.fillMaxSize()) {
        WMenuBackground(if (mode == Mode.Pft) 56 else 57)
        RoundList("w.confirm", side = 0f) {
            item { WTitle(title, tr) }
            item {
                when {
                    mode == Mode.Pft -> {
                        val best = WatchStore.ctx.pftBestTotal
                        Row(Modifier.width(screenFrac(0.66f)), verticalAlignment = Alignment.CenterVertically) {
                            if (best != null) {
                                T("BEST", F.t(9 * k, W700, Color.White.copy(alpha = 0.6f), tracking = 0.6f))
                                Spacer(Modifier.width((6 * k).dp))
                                T(Fm.t(best), F.num(13 * k, W600), translate = false)
                                Spacer(Modifier.weight(1f))
                                PFTBadge(PFT.grade(best), (44 * k).dp, (15 * k).dp, 9f * k)
                            } else T(wt("6 movements · for time"), F.t(11 * k, W600, Color.White.copy(alpha = 0.6f)), Modifier.fillMaxWidth(), translate = false)
                        }
                    }
                    mode == Mode.Training && Kinds.isNew(program.kind) || program.isOpen -> Column(Modifier.width(screenFrac(0.7f)),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon8(if (Kinds.isNew(program.kind)) Kinds.icon(program.kind) else if (program.isHIIT) "hiit" else "run", (26 * k).dp, Tint.Yellow)
                        T(program.watchMeta, F.t(11 * k, W600, Color.White.copy(alpha = 0.6f)), Modifier.fillMaxWidth(), maxLines = 3, align = TextAlign.Center, translate = false)
                    }
                    else -> {
                        val sets = if (program.sets == 1) wt("1 set") else wt("%lld sets", program.sets)
                        T(wt("%lld segments", seq.size) + " · " + sets, F.t(11 * k, W600, Color.White.copy(alpha = 0.6f)), Modifier.fillMaxWidth(),
                            align = TextAlign.Center, translate = false)
                    }
                }
            }
            if (rows.isNotEmpty()) item {
                Column(Modifier.width(screenFrac(0.7f))) {
                    rows.forEachIndexed { i, (ic, nm, v) ->
                        SegRow(ic, nm, v)
                        if (i < rows.size - 1) Box(Modifier.fillMaxWidth().height(0.8.dp).background(Color.White.copy(alpha = 0.09f)))
                    }
                }
            }
            item { Spacer(Modifier.height((60 * k).dp)) }
        }
        WCanvas { L -> WEdgeButton(L, "Start", "play", "w.start") { onStart(null) } }
    }
}

/** 18번 시작 화면 목록: (이름, 오른쪽 글자) — EMOM · AMRAP 할 일, 인터벌 러닝 단계, 기능성 운동 종목 (번역됨) */
private fun bonusLines(p: Program): List<Pair<String, String>> = when (p.kind) {
    Kinds.EMOM, Kinds.AMRAP -> p.tasks.orEmpty().map { it to "" }
    Kinds.IVRUN -> buildList {
        p.warm?.let { add(wt("Warm-up") to Bonus.stepText(it)) }
        for (st in p.steps.orEmpty()) add(wt(IvStep.typeName(st.t)) to (if (st.isTime) Bonus.dur(st.secs) else Bonus.distText(st.meters)))
        p.cool?.let { add(wt("Cool-down") to Bonus.stepText(it)) }
    }
    Kinds.LIFT -> p.lifts.orEmpty().map { l ->
        wt(l.name) to "${l.sets}×${l.reps}" + (if (l.kg > 0) " · " + Bonus.kgText(l.kg) else "")
    }
    else -> emptyList()
}

// MARK: - Full Sim 목표 고르기

/** 제목 "Goal time" → 휠 (줄 간격 24, 고른 줄 노랑 21 + 유리 띠) → ✓ Set (아래 끝 버튼) */
@Composable
fun WGoalPicker() {
    val k = wk()
    val range = WatchGoal.minutes
    val start = WatchGoal.initialMinutes(WatchStore.watchGoal, WatchStore.simTargets, WatchStore.settings.roxTarget)
    val state = androidx.wear.compose.material3.rememberPickerState(range.size, range.indexOf(start).coerceAtLeast(0), false)
    WMenuFrame(59, "Goal time", "w.goalPicker") { L ->
        val mid = (45f + 168f) / 2
        // 유리 띠
        Box(Modifier.at(L.dx(WScale.D / 2), L.dy(mid)).size(L.dv(124f), L.dv(24f)).glassBg(L.dv(10f), Color.White.copy(alpha = 0.13f)))
        androidx.wear.compose.material3.Picker(state, { Fm.t(range[state.selectedOptionIndex] * 60) },
            Modifier.at(L.dx(WScale.D / 2), L.dy(mid)).size(L.dv(150f), L.dv(120f)).testTag("w.goalWheel"), verticalSpacing = 0.dp) { i ->
            val sel = i == state.selectedOptionIndex
            Box(Modifier.fillMaxWidth().height(L.dv(24f)), contentAlignment = Alignment.Center) {
                T(Fm.t(range[i] * 60), wf(L, if (sel) 21f else 16f, W600, if (sel) C.accent else Color.White.copy(alpha = 0.45f), num = true), translate = false)
            }
        }
        if (WatchStore.watchGoal != null) {
            T("Use phone setting", wf(L, 11f, W500, Color.White.copy(alpha = 0.6f)),
                Modifier.at(L.dx(WScale.D / 2), L.dy(161f)).press { WatchStore.pickWatchGoal(null); WNav.pop() }.testTag("w.goalReset"))
        }
        WEdgeButton(L, "Set", "check", "w.goalSet", top = 172f) {
            WatchStore.pickWatchGoal(range[state.selectedOptionIndex] * 60); WNav.pop()
        }
    }
}

/** 목록 한 줄 (높이 20): 아이콘 12 · 이름 13 · 오른쪽 숫자 13 */
@Composable
private fun SegRow(icon: String, name: String, right: String) {
    val k = wk()
    Row(Modifier.fillMaxWidth().height((20 * k).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((7 * k).dp)) {
        Icon8(icon, (12 * k).dp, if (icon == "run") Tint.White else if (icon == "roxzone" || icon == "rest") Tint.Mute else Tint.Yellow)
        T(name, F.t(13 * k, W500), Modifier.weight(1f), align = TextAlign.Start, minScale = 0.8f, translate = false)
        T(right, F.num(13 * k, W500, Color.White.copy(alpha = 0.6f)), minScale = 0.8f, translate = false)
    }
}

// MARK: - 3 · 2 · 1

/** 노란 숫자 96 Bold 가운데 + 귀퉁이 표시, 아래 "Tap to cancel". 화면을 누르면 취소 */
@Composable
fun WCountdown(n: Int, onCancel: () -> Unit) {
    Box(Modifier.fillMaxSize().press(onClick = onCancel).testTag("w.countdown")) {
        WMenuFrame(60, null, "w.countdownFrame") { L ->
            val ch = wCap(96f)
            WBrackets(L, WScale.D / 2 - ch / 2 - 18f, WScale.D / 2 + ch / 2 + 18f, Color.White.copy(alpha = 0.47f))
            WText("$n", wf(L, 96f, W700, C.accent, num = true), L, WScale.D / 2, WScale.D / 2, 120f, tag = "w.count")
            WText("Tap to cancel", wf(L, 12f, W600, Color.White.copy(alpha = 0.6f)), L, WScale.D / 2, WScale.D - 30f, 140f, translate = true)
        }
    }
}
