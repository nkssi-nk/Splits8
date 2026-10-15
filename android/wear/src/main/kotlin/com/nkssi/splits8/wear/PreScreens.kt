package com.nkssi.splits8.wear

import androidx.compose.animation.AnimatedVisibility
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
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import kotlinx.coroutines.delay

// 운동 전 화면 (아이폰 SplitsWatchApp.swift): 홈(모드 4개) · 트레이닝 목록 · 빠른 트레이닝 · 확인 · 3 · 2 · 1
// 갤럭시 워치는 동그란 화면 → 목록은 위아래 끝에서 작아지며 지나가는 둥근 목록(ScalingLazyColumn), 크라운 · 베젤로 넘김.

enum class WScreen { Programs, Quick, Confirm }

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

// MARK: - 홈

/** 첫 화면: 모드 카드 4개 (설명 줄 없음 — 아이콘 · 이름 · 단추만). 처음엔 카드 4개가 가운데. 맨 위는 시계 자리라 로고는 뺌 */
@Composable
fun WHome() {
    val k = wk()
    Box(Modifier.fillMaxSize()) {
        AmbientLayer(Ambient.y(0.22f, 0.9f, 0.4f, 0.5f, -0.06f, WatchStore.settings.glow))
        // 가운데 = PFT 와 Full Simulation 사이 (카드 반 칸만큼 내림)
        val half = with(androidx.compose.ui.platform.LocalDensity.current) { (22 * k).dp.roundToPx() }
        RoundList("w.home", center = 1, offset = half, side = 14f) {
            for (m in listOf(Mode.Training, Mode.Pft, Mode.Sim, Mode.Race)) item { ModeCard(m, k) }
        }
    }
}

@Composable
private fun ModeCard(m: Mode, k: Float) {
    Row(
        Modifier.fillMaxWidth().wCard(18.dp).press { WNav.openMode(m) }.padding(vertical = (7 * k).dp, horizontal = 12.dp)
            .testTag("w.mode." + m.raw),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        ModeIcon(m)
        T(m.title, F.t(15, W600, tracking = -0.24f), Modifier.weight(1f), align = TextAlign.Start)
        Box(Modifier.size(22.dp).clip(CircleShape).background(if (m == Mode.Training) hex(0x262626) else C.accent), contentAlignment = Alignment.Center) {
            // ▶ 는 정가운데면 왼쪽으로 쏠려 보여서 오른쪽으로 1
            if (m == Mode.Training) Icon8("i_chevRw", 10.dp, C.accent) else Icon8("i_play", 12.dp, Color.Black, Modifier.offset(x = 1.dp))
        }
    }
}

/** Training = modeTraining 22, PFT = modePFT 22, Full Sim = i_sim 20, Race = i_race 20 (노랑) */
@Composable
fun ModeIcon(m: Mode, color: Color = C.accent) {
    Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
        when (m) {
            Mode.Training -> Icon8("modeTraining", 22.dp, color)
            Mode.Pft -> Icon8("modePFT", 22.dp, color)
            Mode.Sim -> Icon8("i_sim", 20.dp, color)
            Mode.Race -> Icon8("i_race", 20.dp, color)
        }
    }
}

/** 화면 제목 (시계 아래 가운데) */
@Composable
fun WTitle(text: String, translate: Boolean = true) {
    T(text, F.t(15, W600, C.accent), Modifier.fillMaxWidth().padding(bottom = 2.dp), align = TextAlign.Center, translate = translate)
}

// MARK: - 트레이닝 목록

@Composable
fun WPrograms() {
    Box(Modifier.fillMaxSize()) {
        AmbientLayer(Ambient.y(0.16f, 0.7f, 0.45f, 1.0f, 0f, WatchStore.settings.glow))
        RoundList("w.programs") {
            item { WTitle("Training") }
            item {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(C.accent)
                        .press { WNav.quick = emptyList(); WNav.open(WScreen.Quick) }.padding(vertical = 10.dp, horizontal = 12.dp).testTag("w.quick"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    T("Quick training", F.t(15, W600, Color.Black), Modifier.weight(1f), align = TextAlign.Start)
                    Icon8("i_plus", 14.dp, Color.Black)
                }
            }
            for (p in WatchStore.programs) item {
                Column(Modifier.fillMaxWidth().wCard(14.dp).press { WNav.program = p; WNav.open(WScreen.Confirm) }.padding(vertical = 9.dp, horizontal = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T(p.name, F.t(15, W600), Modifier.fillMaxWidth(), align = TextAlign.Start, minScale = 0.85f)
                    T(p.watchMeta, F.t(13, color = C.text2), Modifier.fillMaxWidth(), align = TextAlign.Start, minScale = 0.85f, translate = false)
                }
            }
            item { T("Edit names on your phone", F.t(12, color = C.text3), Modifier.fillMaxWidth().padding(vertical = 4.dp), align = TextAlign.Center) }
        }
    }
}

// MARK: - 빠른 트레이닝

/** 러닝 4칸 + 스테이션 8칸을 눌러 쌓음 (최대 16). 누르면 "＋ Sled Push · 3번째" + 짧은 진동 */
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
        AmbientLayer(Ambient.y(0.16f, 0.7f, 0.45f, 0f, 0f, WatchStore.settings.glow))
        RoundList("w.quickList", side = 12f) {
            item { WTitle("Quick training") }
            // 러닝 4칸
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (r in Defaults.runs) {
                        Box(Modifier.weight(1f).height((32 * k).dp).wCard(10.dp).press { add(ProgItem("run", r)) }.testTag("w.quick.run.$r"),
                            contentAlignment = Alignment.Center) {
                            T(r, F.t(13, W600), Modifier.padding(horizontal = 1.dp), minScale = 0.7f, translate = false)
                        }
                    }
                }
            }
            // 스테이션 8칸 (3 · 3 · 2 — 동그란 화면 가장자리에 걸리지 않게)
            for (row in Station.all.chunked(3)) item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
                    for (s in row) {
                        Column(
                            Modifier.width((50 * k).dp).height((50 * k).dp).wCard(10.dp).press { add(ProgItem(s.key)) }.testTag("w.quick." + s.key),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
                        ) {
                            Icon8(s.key, (22 * k).dp, Tint.Yellow)
                            T(shortName(s.name), F.t(10, W600, C.text2), Modifier.padding(horizontal = 2.dp), minScale = 0.7f)
                        }
                    }
                }
            }
            // 쌓인 구간
            item {
                FlowRow(Modifier.fillMaxWidth().heightIn(min = 22.dp).padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterHorizontally),
                    verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    if (WNav.quick.isEmpty()) T("Tap to add", F.t(12, color = C.text3))
                    for (q in WNav.quick) {
                        Row(Modifier.clip(RoundedCornerShape(6.dp)).background(hex(0x1C1C1C)).padding(vertical = 2.dp, horizontal = 5.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                            Icon8(q.icon, 9.dp, if (q.icon == "run") Tint.White else Tint.Yellow)
                            T(chipLabel(q), F.t(11, W600), translate = false)
                        }
                    }
                }
            }
            if (WNav.quick.isNotEmpty()) {
                item {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        SmallButton("Remove last", Modifier.weight(1f).testTag("w.quickUndo")) { WNav.quick = WNav.quick.dropLast(1); buzz(BuzzKind.Click) }
                        SmallButton("Clear all", Modifier.weight(1f).testTag("w.quickClear")) { WNav.quick = emptyList(); buzz(BuzzKind.Click) }
                    }
                }
                item {
                    Box(Modifier.fillMaxWidth().height(36.dp).clip(RoundedCornerShape(50)).background(C.accent)
                        .press {
                            val p = WatchStore.saveQuick(WNav.quick)
                            WNav.program = p; WNav.quick = emptyList(); WNav.open(WScreen.Confirm)
                        }.testTag("w.quickStart"),
                        contentAlignment = Alignment.Center) {
                        T(wt("Start · %lld segments", WNav.quick.size), F.t(15, W600, Color.Black), Modifier.padding(horizontal = 10.dp), translate = false)
                    }
                }
            }
        }
        // 알림 (아래에서 잠깐)
        AnimatedVisibility(toast != null, Modifier.align(Alignment.BottomCenter).padding(bottom = (18 * k).dp),
            enter = fadeIn() + slideInVertically { it / 2 }, exit = fadeOut()) {
            Box(Modifier.height(26.dp).clip(RoundedCornerShape(50)).background(C.accent).padding(horizontal = 10.dp).testTag("w.quickToast"),
                contentAlignment = Alignment.Center) {
                T(toast ?: "", F.t(13, W600, Color.Black), translate = false)
            }
        }
    }
}

const val MAX_SEGS = 16

@Composable
private fun SmallButton(t: String, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(32.dp).clip(RoundedCornerShape(10.dp)).background(hex(0x1C1C1C)).press(onClick = onClick), contentAlignment = Alignment.Center) {
        T(t, F.t(12, W600, C.bad), Modifier.padding(horizontal = 4.dp))
    }
}

private fun shortName(n: String): String = n.replace("Farmers Carry", "Farmers").replace("Wall Balls", "Wall Ball")

private fun chipLabel(q: ProgItem, full: Boolean = false): String {
    if (q.icon == "run") return q.run ?: "1KM"
    if (full) return q.name()
    return q.name().replace("Farmers Carry", "FC").replace("Wall Balls", "WB").replace("Sled Push", "Push").replace("Sled Pull", "Pull")
}

// MARK: - 확인 (Start)

@Composable
fun WConfirm(onStart: () -> Unit) {
    val mode = WNav.mode
    val program = WNav.program ?: Program.presets()[0]
    val seq = WatchStore.seq(mode, if (mode == Mode.Training) program else null)
    val ev = WatchStore.settings.event
    val noEvent = mode == Mode.Race && !ev.isSet
    val k = wk()
    Box(Modifier.fillMaxSize()) {
        AmbientLayer(Ambient.y(0.22f, 1.1f, 0.5f, 0.5f, 1.08f, WatchStore.settings.glow))
        RoundList("w.confirm", side = 22f) {
            item { WTitle(if (mode == Mode.Training) program.name else mode.title) }
            when {
                mode == Mode.Training && program.isOpen -> item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon8(if (program.isHIIT) "hiit" else "run", 30.dp, Tint.Yellow)
                        T(program.meta ?: "", F.t(14, color = C.text2), Modifier.fillMaxWidth(), maxLines = 2, align = TextAlign.Center)
                    }
                }
                mode == Mode.Pft -> {
                    item {
                        val best = WatchStore.ctx.pftBestTotal
                        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                            T(if (best != null) wt("BEST") + " " + Fm.t(best) else wt("6 movements · for time"), F.num(13, W500, C.text2), translate = false)
                            if (best != null) PFTBadge(PFT.grade(best), 62.dp, 18.dp, 10f)
                        }
                    }
                    for (s in seq) item { SegRow(s.icon, s.name, s.detail.split(" · ").first()) }
                }
                mode == Mode.Training -> {
                    item {
                        val sets = if (program.sets == 1) wt("1 set") else wt("%lld sets", program.sets)
                        T(wt("%lld segments", seq.size) + " · " + sets, F.t(13, W500, C.text2), Modifier.fillMaxWidth(), align = TextAlign.Center, translate = false)
                    }
                    for (s in seq.filter { it.kind != SegKind.Rox }) item { SegRow(s.icon, s.name, if (s.target > 0) Fm.t(s.target) else "–") }
                }
                noEvent -> item {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 6.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        T("No race set up", F.t(16, W600))
                        T("Add a race in the Race tab of the phone app and it will show up here.", F.t(13, color = C.text2), Modifier.fillMaxWidth(), maxLines = 4, align = TextAlign.Center)
                    }
                }
                else -> item {
                    val small = if (mode == Mode.Race) Fm.wdm(ev.date) + " · " + WatchStore.settings.div.name
                        else WatchStore.settings.div.name + " · " + "8 runs · 8 stations".l10n
                    val goal = if (mode == Mode.Race) Fm.t(WatchStore.settings.goalTime) else Fm.t(seq.sumOf { it.target })
                    val w = WatchStore.simPick.second
                    val goalWord = if (mode == Mode.Race) "GOAL" else if (w == "VS GOAL") "GOAL" else w
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        T(if (mode == Mode.Race) ev.name else "Full Simulation", F.t(17, W600, tracking = -0.34f), Modifier.fillMaxWidth(), maxLines = 2,
                            align = TextAlign.Center, translate = mode != Mode.Race)
                        T(small, F.t(12, color = C.text2), Modifier.fillMaxWidth(), translate = false)
                        T(goal, F.num(30 * k, tracking = -0.6f), Modifier.padding(top = 6.dp).testTag("w.goal"), translate = false)
                        T(goalWord, F.t(11, W600, C.text2, tracking = 0.9f))
                    }
                }
            }
            if (!noEvent) item {
                Box(Modifier.fillMaxWidth().padding(top = 4.dp).height(40.dp).clip(RoundedCornerShape(14.dp)).background(C.accent).press(onClick = onStart).testTag("w.start"),
                    contentAlignment = Alignment.Center) {
                    T("Start", F.t(15, W600, Color.Black))
                }
            }
        }
    }
}

@Composable
private fun SegRow(icon: String, name: String, right: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp, horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon8(icon, 14.dp, Tint.Yellow)
        T(name, F.t(13), Modifier.weight(1f), align = TextAlign.Start, minScale = 0.85f, translate = false)
        T(right, F.num(13, W500, C.text2), minScale = 0.85f, translate = false)
    }
}

// MARK: - 3 · 2 · 1

/** Start 를 누르면 3 · 2 · 1 을 센 뒤 시간이 시작됨. 화면을 누르면 취소 */
@Composable
fun WCountdown(n: Int, onCancel: () -> Unit) {
    Box(Modifier.fillMaxSize().press(onClick = onCancel).testTag("w.countdown"), contentAlignment = Alignment.Center) {
        AmbientLayer(Ambient.y(0.30f, 1.0f, 0.6f, 0.5f, 0.5f, WatchStore.settings.glow))
        T("$n", F.num(96, W700, C.accent), Modifier.testTag("w.count"), translate = false)
        T("Tap to cancel", F.t(13, color = C.text3), Modifier.align(Alignment.BottomCenter).padding(bottom = 22.dp))
    }
}
