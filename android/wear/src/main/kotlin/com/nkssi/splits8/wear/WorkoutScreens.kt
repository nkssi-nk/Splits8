package com.nkssi.splits8.wear

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.foundation.pager.VerticalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import com.nkssi.splits8.shared.CheerInput
import com.nkssi.splits8.shared.CheerPicker
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RecordFlag
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.runMeters
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.abs

// 운동 중 (아이폰 Views/WorkoutViews.swift): 위아래 페이지(크라운 · 베젤) = 실시간 · 조작 · 구간 목록.
// 실시간에서 왼쪽으로 밀기 · NEXT 누르기 = 다음 구간, 오른쪽으로 밀기 = 조작. 조작에서 왼쪽으로 밀기 = 실시간.
// 빌드 24 모양: SPLIT | GOAL(트레이닝 BEST · 러닝 PACE), 목표를 넘기면 SPLIT 빨강.

/** 화면 크기별 크기 (225dp 기준 1.0) */
private class LiveMetrics(k: Float) {
    val top = 20 * k
    val totalH = 58 * k
    val totalFont = 38 * k
    val icon = 20 * k
    val seg = 30 * k
    val nameTop = 4 * k
    val bottom = 10 * k
}

@Composable
fun WWorkoutPager(buzz: (BuzzKind) -> Unit, startPage: Int = 0, startEnd: Boolean = false) {
    val e = WatchStore.engine
    val pager = rememberPagerState(initialPage = startPage) { 3 }
    val scope = rememberCoroutineScope()
    var endSheet by remember { mutableStateOf(startEnd) }
    val aod = LocalAod.current
    val flash = remember { Animatable(0f) }
    LaunchedEffect(e.advanceCount) {
        if (e.advanceCount == 0 || aod) return@LaunchedEffect
        // 구간 전환 반짝: 노랑 0.42, 60ms 켜짐 → 260ms 사라짐
        flash.snapTo(0f)
        flash.animateTo(1f, tween(60, easing = LinearEasing))
        delay(30)
        flash.animateTo(0f, tween(260))
    }
    fun go(p: Int) = scope.launch { pager.animateScrollToPage(p) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        VerticalPager(pager, Modifier.fillMaxSize()) { page ->
            when (page) {
                0 -> WLive(onControls = { go(1) })
                1 -> WControls(onBack = { go(0) }, onEnd = { endSheet = true }, onNext = { e.advance(); go(0) })
                else -> WSegmentList()
            }
        }
        if (endSheet) {
            WEndSheet(
                onEnd = { endSheet = false; e.endNow() },
                onDiscard = { endSheet = false; e.discardNow(); WNav.open(null) },
                onResume = { endSheet = false },
                buzz = buzz,
            )
        }
        if (!aod && flash.value > 0f) Box(Modifier.fillMaxSize().background(Color(1f, 236f / 255f, 80f / 255f, 0.42f * flash.value)))
    }
}

// MARK: 실시간

@Composable
fun WLive(onControls: () -> Unit) {
    val e = WatchStore.engine
    val aod = LocalAod.current
    val m = LiveMetrics(wk())
    var now by remember { mutableLongStateOf(WatchStore.engine.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(250) } }

    // 존이 바뀌면 위쪽 빛이 새 존 색 0.75 로 켜졌다가 900ms 동안 평소(0.28)로
    val z = if (e.hr > 0) e.zone.coerceIn(1, 5) else 0
    val pulse = remember { Animatable(0f) }
    var lastZone by remember { mutableStateOf(0) }
    LaunchedEffect(z) {
        if (!aod && lastZone > 0 && z > 0 && z != lastZone) { pulse.snapTo(1f); delay(90); pulse.animateTo(0f, tween(900)) }
        lastZone = z
    }
    val zoneColor by animateColorAsState(C.zone(if (z == 0) 1 else z), tween(600), label = "zone")
    val swipePx = with(LocalDensity.current) { 40.dp.toPx() }

    Box(
        Modifier.fillMaxSize().testTag("w.live").pointerInput(Unit) {
            var dx = 0f
            detectHorizontalDragGestures(onDragStart = { dx = 0f }, onDragEnd = {
                if (abs(dx) >= swipePx) { if (dx < 0) e.advance() else onControls() }
            }) { _, d -> dx += d }
        },
    ) {
        if (!aod) {
            AmbientLayer(Ambient(0, 0f, 1f, 1f, 0.5f, 0.5f).copy(hex = zoneColor.toHex(), alpha = 0.28f, rx = 1.2f, ry = 0.55f, cx = 0.5f, cy = -0.14f))
            if (pulse.value > 0f) AmbientLayer(Ambient(zoneColor.toHex(), 0.75f, 1.2f, 0.6f, 0.5f, -0.1f), Modifier.alpha(pulse.value))
        }
        Column(Modifier.fillMaxSize().padding(top = m.top.dp, start = 22.dp, end = 22.dp, bottom = m.bottom.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            // TOTAL (고정)
            Column(Modifier.fillMaxWidth().height(m.totalH.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                T("TOTAL", F.t(11, W600, C.text2, tracking = 1.08f))
                val tot = e.total(now)
                // 어두운 화면은 1분에 한 번만 그려짐 → 초 자리는 지움
                T(if (aod) Fm.t(tot).dropLast(2) + "––" else Fm.t(tot), F.num(m.totalFont, color = if (aod) C.text2 else Color.White, tracking = -0.02f * m.totalFont),
                    Modifier.fillMaxWidth().testTag("w.total"), translate = false)
            }
            // 지금 + 다음 (넘길 때 밀림: 나가는 쪽 왼쪽, 들어오는 쪽 오른쪽에서)
            val curve = CubicBezierEasing(0.32f, 0.72f, 0f, 1f)
            AnimatedContent(e.idx, Modifier.weight(1f).fillMaxWidth(), label = "seg",
                transitionSpec = {
                    (slideInHorizontally(tween(220, easing = curve)) { it * 2 / 5 } + fadeIn(tween(220))) togetherWith
                        (slideOutHorizontally(tween(220, easing = curve)) { -it } + fadeOut(tween(220)))
                }) { _ ->
                Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.weight(1f))
                    Current(now, m, aod)
                    Spacer(Modifier.weight(1f))
                    if (!aod) NextRow()
                }
            }
        }
    }
}

private fun Color.toHex(): Long = ((red * 255).toLong() shl 16) or ((green * 255).toLong() shl 8) or (blue * 255).toLong()

@Composable
private fun Current(now: Long, m: LiveMetrics, aod: Boolean) {
    val e = WatchStore.engine
    val cur = e.cur
    val el = e.segEl(now)
    val fg = if (aod) C.text3 else Color.White
    val isRun = cur.kind == SegKind.Run
    val over = cur.target > 0 && el > cur.target
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.height(22.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon8(cur.icon, m.icon.dp, if (aod) Tint.Dim else if (cur.kind == SegKind.Rox) Tint.Mute else Tint.Yellow)
            T(cur.name, F.t(15, W600, fg), translate = false)
        }
        Row(Modifier.fillMaxWidth().padding(top = m.nameTop.dp), verticalAlignment = Alignment.Top) {
            Col("SPLIT", if (aod) Fm.t(el).dropLast(2) + "––" else Fm.t(el), if (aod) C.text3 else if (over) C.bad else C.accent, m.seg, "w.split")
            Box(Modifier.padding(top = 16.dp).width(1.dp).height((m.seg * 1.1f).dp).background(Color.White.copy(alpha = 0.14f)))
            when {
                isRun -> Col(if (curvedRun()) "PACE ≈" else "PACE", LivePace.text(el, e.segDist.takeIf { e.distance > 0 }), fg, m.seg, "w.pace")
                cur.target > 0 -> Col(if (e.mode == Mode.Training) "BEST" else "GOAL", Fm.t(cur.target), fg, m.seg, "w.goal")
                else -> Col("", cur.detail, C.text2, 14f, "w.detail", small = true)
            }
        }
        T(lowerLine(), if (isRun) F.num(12, W500, C.text2) else F.t(12, W500, C.text2), Modifier.fillMaxWidth().height(17.dp).padding(top = 1.dp), translate = false)
    }
}

/** 러닝 = "0.62 / 1.00 km (· 총 7.62 km)", 스테이션(목표 있음) = 세부, Roxzone · 목표 없는 구간 = 빈 줄 */
private fun lowerLine(): String {
    val e = WatchStore.engine
    val cur = e.cur
    if (cur.kind == SegKind.Rox) return ""
    if (cur.kind == SegKind.Run) {
        val km = runMeters(cur.detail) / 1000
        val d = minOf(km, e.segDist / 1000)
        val seg = String.format(Locale.US, "%.2f / %.2f km", d, km)
        if (!e.isRunKind || e.distance < 10) return seg
        return seg + " · " + wt("Total %@ km", String.format(Locale.US, "%.2f", e.distance / 1000))
    }
    return if (cur.target > 0) cur.detail else ""
}

private fun curvedRun(): Boolean = WatchStore.engine.settings.runMode == "curved" && WatchStore.engine.mode != Mode.Race

/** 작은 이름표 + 큰 숫자 (두 칸이 같은 크기) */
@Composable
private fun RowScope.Col(label: String, value: String, color: Color, size: Float, tag: String, small: Boolean = false) {
    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        T(label, F.t(10, W600, C.text3, tracking = 0.8f), Modifier.height(15.dp))
        T(value, if (small) F.t(13, W600, color) else F.num(size, color = color, tracking = -0.01f * size),
            Modifier.fillMaxWidth().height((size * 1.15f).dp).testTag(tag), minScale = 0.55f, translate = false)
    }
}

/** NEXT + 다음 아이콘 + 이름 (누르면 다음 구간) */
@Composable
private fun NextRow() {
    val e = WatchStore.engine
    val nx = e.nextSeg
    Box(Modifier.fillMaxWidth().height(1.dp).padding(horizontal = 18.dp).background(Color.White.copy(alpha = 0.10f)))
    Row(Modifier.fillMaxWidth().height(34.dp).press { e.advance() }.testTag("w.next"), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
        T("NEXT", F.t(11, W600, C.text3, tracking = 0.8f))
        if (e.isLast) {
            Icon8("i_check", 18.dp, C.d1)
            T("Finish", F.t(14, W600, C.d1))
        } else {
            Icon8(nx.icon, 18.dp, if (nx.kind == SegKind.Rox) Tint.Mute else Tint.Yellow)
            T(nx.name, F.t(14, W600, C.d1), Modifier.weight(1f, fill = false), translate = false)
        }
    }
}

// MARK: 조작

/** 끝 · 멈춤 · 되돌리기 · 다음 (동그란 화면이라 2 × 2 둥근 단추) */
@Composable
fun WControls(onBack: () -> Unit, onEnd: () -> Unit, onNext: () -> Unit) {
    val e = WatchStore.engine
    var now by remember { mutableLongStateOf(WatchStore.engine.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(500) } }
    val swipePx = with(LocalDensity.current) { 40.dp.toPx() }
    val k = wk()
    Box(Modifier.fillMaxSize().testTag("w.controls").pointerInput(Unit) {
        var dx = 0f
        detectHorizontalDragGestures(onDragStart = { dx = 0f }, onDragEnd = { if (dx <= -swipePx) onBack() }) { _, d -> dx += d }
    }) {
        AmbientLayer(Ambient(0xFFFFFF, 0.07f, 0.8f, 0.5f, 0.5f, 0.5f))
        Column(Modifier.fillMaxSize().padding(top = (24 * k).dp, bottom = (16 * k).dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                T(if (e.mode == Mode.Training) e.title else e.mode.title, F.t(12, W600, C.accent), Modifier.width((90 * k).dp), translate = e.mode != Mode.Training)
                T(Fm.t(e.total(now)), F.num(14), translate = false)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((6 * k).dp, Alignment.CenterVertically)) {
                Row(horizontalArrangement = Arrangement.spacedBy((14 * k).dp)) {
                    RoundButton("End", "i_x", C.bad, hex(0xFF453A, 0.22f), Color.White, "w.end", onClick = onEnd)
                    RoundButton(if (e.running) "Pause" else "Resume", if (e.running) "i_pause" else "i_play", Color.White,
                        Color.White.copy(alpha = 0.12f), Color.White, "w.pause") { e.togglePause() }
                }
                Row(horizontalArrangement = Arrangement.spacedBy((14 * k).dp)) {
                    val on = e.canUndo
                    RoundButton("Undo", null, if (on) Color.White else C.text3, Color.White.copy(alpha = if (on) 0.12f else 0.05f),
                        if (on) Color.White else C.text3, "w.undo", enabled = on) { e.undo(); onBack() }
                    RoundButton("Next", "i_dblChev", Color.Black, C.accent, Color.Black, "w.controlsNext", labelColor = C.accent, onClick = onNext)
                }
            }
            T("‹ Swipe left to go back", F.t(11, color = C.text3))
        }
    }
}

@Composable
private fun RoundButton(label: String, glyph: String?, fg: Color, bg: Color, glyphColor: Color, tag: String,
                        enabled: Boolean = true, labelColor: Color = fg, onClick: () -> Unit) {
    val k = wk()
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Box(Modifier.size((48 * k).dp).clip(CircleShape).background(bg).press(enabled, onClick).testTag(tag), contentAlignment = Alignment.Center) {
            if (glyph != null) Icon8(glyph, (20 * k).dp, glyphColor) else Sym(R.drawable.sym_undo, (20 * k).dp, glyphColor)
        }
        T(label, F.t(11, W600, if (labelColor == Color.Black) C.accent else labelColor), Modifier.width((60 * k).dp))
    }
}

// MARK: 구간 목록

@Composable
fun WSegmentList() {
    val e = WatchStore.engine
    var now by remember { mutableLongStateOf(WatchStore.engine.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(1000) } }
    val state = rememberScalingLazyListState(initialCenterItemIndex = e.idx + 1)
    val k = wk()
    Box(Modifier.fillMaxSize().testTag("w.segments")) {
        AmbientLayer(Ambient(0xFFE600, 0.10f, 1f, 1f, 0.5f, 0f, linear = true))
        ScalingLazyColumn(Modifier.fillMaxSize(), state = state,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = (22 * k).dp, vertical = (26 * k).dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    T("SEGMENTS", F.t(12, W600, C.accent, tracking = 1f))
                    T("${minOf(e.idx + 1, e.seq.size)}/${e.seq.size}", F.num(12, W400, C.text2), translate = false)
                }
            }
            items(e.seq.size) { i ->
                val s = e.seq[i]
                val done = i < e.idx
                val c = i == e.idx
                val tint = when { c -> Tint.Black; done -> Tint.Dim; s.kind == SegKind.Rox -> Tint.Mute; else -> Tint.White }
                val time = when {
                    done -> Fm.t(e.splits.getOrElse(i) { 0 })
                    c -> Fm.t(e.segEl(now))
                    else -> if (s.target > 0) Fm.t(s.target) else "–"
                }
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(if (c) C.accent else Color.Transparent).padding(vertical = 5.dp, horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon8(s.icon, 13.dp, tint)
                    T(s.name, F.t(12, if (c) W600 else W400, if (c) Color.Black else if (done) C.text2 else Color.White), Modifier.weight(1f),
                        align = TextAlign.Start, minScale = 0.85f, translate = false)
                    if (done) Icon8("i_check", 10.dp, C.good)
                    T(time, F.num(12, W500, if (c) Color.Black else if (done) Color.White else C.text3), translate = false)
                }
            }
        }
    }
}

// MARK: 끝내기 확인

/** 저장하고 끝내기 · 버리기 · 계속. 버리기는 한 번 더 물음 */
@Composable
fun WEndSheet(onEnd: () -> Unit, onDiscard: () -> Unit, onResume: () -> Unit, buzz: (BuzzKind) -> Unit) {
    val e = WatchStore.engine
    var ask by remember { mutableStateOf(false) }
    val k = wk()
    Box(Modifier.fillMaxSize().background(Color.Black).press { }.testTag("w.endSheet")) {
        Column(Modifier.fillMaxSize().padding(start = (30 * k).dp, end = (30 * k).dp, top = (30 * k).dp, bottom = (26 * k).dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
            if (!ask) {
                T("End workout?", F.t(15, W600))
                // 구간 수는 Roxzone 을 빼고 셈 (빌드 24 — 운동 중 화면의 n / 16 과 같게)
                val done = e.seq.take(e.idx).count { it.kind != SegKind.Rox }
                val all = e.seq.count { it.kind != SegKind.Rox }
                T(if (e.growsOpen) wt("Everything so far will be saved.") else wt("%lld/%lld segments done. The rest won't be recorded.", done, all),
                    F.t(12, color = C.text2), Modifier.fillMaxWidth(), maxLines = 3, align = TextAlign.Center, translate = false)
                Spacer(Modifier.weight(1f))
                SheetButton("Save & end", Color.Black, C.accent, Modifier.fillMaxWidth().testTag("w.endConfirm"), onEnd)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SheetButton("Discard", C.bad, hex(0x2A1412), Modifier.weight(1f).testTag("w.discard")) { buzz(BuzzKind.Click); ask = true }
                    SheetButton("Resume", Color.White, hex(0x1F1F1F), Modifier.weight(1f).testTag("w.resume"), onResume)
                }
            } else {
                T("Discard this workout?", F.t(15, W600))
                T("It won't be saved here, on your phone or in Health Connect.", F.t(12, color = C.text2), Modifier.fillMaxWidth(), maxLines = 3, align = TextAlign.Center)
                Spacer(Modifier.weight(1f))
                SheetButton("Discard", Color.White, C.bad, Modifier.fillMaxWidth().testTag("w.discardConfirm"), onDiscard)
                SheetButton("Cancel", Color.White, hex(0x1F1F1F), Modifier.fillMaxWidth()) { ask = false }
            }
        }
    }
}

@Composable
private fun SheetButton(t: String, fg: Color, bg: Color, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(34.dp).clip(RoundedCornerShape(12.dp)).background(bg).press(onClick = onClick), contentAlignment = Alignment.Center) {
        T(t, F.t(14, W600, fg), Modifier.padding(horizontal = 6.dp))
    }
}

// MARK: 요약

@Composable
fun WSummary() {
    val e = WatchStore.engine
    val r = e.lastRecord ?: return
    val k = wk()
    Box(Modifier.fillMaxSize().testTag("w.summary")) {
        AmbientLayer(Ambient(0x30D158, 0.18f, 1.2f, 0.6f, 0.5f, -0.1f))
        val state = rememberScalingLazyListState(initialCenterItemIndex = 0)
        ScalingLazyColumn(Modifier.fillMaxSize(), state = state,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = (22 * k).dp, vertical = (26 * k).dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { T(if (r.mode == Mode.Training) r.title else r.mode.title, F.t(12, W600, C.text2), translate = r.mode != Mode.Training) }
            item { Head(r) }
            item { Stats(r) }
            item {
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.wCard).padding(vertical = 4.dp)) {
                    for (s in r.segs.filter { it.kind != SegKind.Rox }) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 3.dp, horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon8(s.icon, 12.dp, Tint.Yellow)
                            T(s.name, F.t(12), Modifier.weight(1f), align = TextAlign.Start, minScale = 0.85f, translate = false)
                            T(Fm.t(s.time), F.num(12, W500), translate = false)
                        }
                    }
                }
            }
            item {
                Box(Modifier.fillMaxWidth().height(34.dp).clip(RoundedCornerShape(12.dp)).background(C.accent)
                    .press { e.reset(); WNav.open(null) }.testTag("w.done"), contentAlignment = Alignment.Center) {
                    T("Done", F.t(14, W600, Color.Black))
                }
            }
        }
    }
}

@Composable
private fun Head(r: Record) {
    val tg = r.vsTarget ?: r.total
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        // "수고했어요" 류 한 줄 (워치가 아는 것만으로 고름)
        T(cheer(r), F.t(13, W600, C.accent), Modifier.fillMaxWidth().testTag("w.cheer"), maxLines = 3, align = TextAlign.Center, translate = false)
        T(Fm.t(r.total), F.num(30, tracking = -0.9f), Modifier.padding(top = 4.dp).testTag("w.sumTotal"), translate = false)
        r.pftGrade?.let { PFTBadge(it, 84.dp, 24.dp, 13f) }
        if (r.vsTarget != null) {
            Row(Modifier.padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                T(Fm.d(r.total - tg), F.num(14, color = if (r.total > tg) C.bad else C.good), translate = false)
                T(r.vsWord, F.t(11, W600, C.text2, tracking = 0.8f))
            }
        }
    }
}

@Composable
private fun Stats(r: Record) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.wCard).padding(vertical = 7.dp, horizontal = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for ((l, v, c) in listOf(
            Triple("AVG", if (r.avgHR > 0) "${r.avgHR}" else "--", C.hr),
            Triple("MAX", if (r.maxHR > 0) "${r.maxHR}" else "--", C.hr),
            Triple("KCAL", String.format(Locale.US, "%,d", r.kcal), Color.White),
        )) {
            Column(Modifier.weight(1f)) {
                T(l, F.t(11, W600, C.text2, tracking = 0.64f), Modifier.fillMaxWidth(), align = TextAlign.Start)
                T(v, F.num(14, color = c), Modifier.fillMaxWidth(), align = TextAlign.Start, translate = false)
            }
        }
    }
}

/** 워치가 아는 것: 내 최고 Full Sim · 최고 PFT · 레이스 목표 · 대회 날짜 · 심박 */
fun cheer(r: Record): String {
    val ctx = WatchStore.ctx
    var x = CheerInput(r.mode, r.title, r.total, r.isComplete, r.flag == RecordFlag.Check, r.date, r.end, CheerPicker.seed(r.id),
        isHIIT = r.isHIIT, isRun = r.isRunKind, hiitRounds = if (r.isHIIT) r.segs.size else 0,
        runKm = r.runs.sumOf { it.dist ?: runMeters(it.detail) } / 1000, hiShare = CheerPicker.hiShare(r.hr, ctx.settings))
    if (r.mode == Mode.Race) (r.goal ?: r.vsTarget)?.let { g -> x = x.copy(goalDelta = r.total - g) }
    val sb = ctx.simBestTotal
    if (r.mode == Mode.Sim && sb != null && r.total < sb && r.counts) x = x.copy(pbDelta = r.total - sb)
    if (r.mode == Mode.Sim && sb == null && r.splits16 != null) x = x.copy(firstFullSim = true)
    if (r.mode == Mode.Pft) {
        val prev = ctx.pftBestTotal ?: ctx.pftBest?.sum()
        x = x.copy(pftPrevBest = prev, pftEverGold = (prev ?: Int.MAX_VALUE) < PFT.goldLimit)
    }
    val ev = ctx.settings.event
    if (ev.isSet) {
        val d = ChronoUnit.DAYS.between(r.date.atZone(Fm.zone).toLocalDate(), ev.date.atZone(Fm.zone).toLocalDate()).toInt()
        if (d >= 0) x = x.copy(daysToRace = d)
    }
    return CheerPicker.pick(x).line
}
