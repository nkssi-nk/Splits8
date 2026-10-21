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
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
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
import com.nkssi.splits8.shared.Units
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
import kotlin.math.roundToInt

// 운동 중 (아이폰 Views/WorkoutViews.swift): 위아래 페이지(크라운 · 베젤) = 실시간 · 조작 · 구간 목록.
// 실시간에서 왼쪽으로 밀기 · 가운데 노란 단추 = 다음 구간, 오른쪽으로 밀기 = 조작. 조작에서 왼쪽으로 밀기 = 실시간.
// 빌드 24 모양: SPLIT | GOAL(트레이닝 BEST · 러닝 PACE), 목표를 넘기면 SPLIT 빨강.

/**
 * 화면 크기별 크기 (225dp 기준 1.0). 빌드 27 (68 · 71번 확정안): 위 정보는 그대로, 아래에 NEXT 이름 + 컨트롤 줄
 * → 전체 글자를 조금 줄이고 간격을 고르게. 아이폰 WLiveMetrics(44mm 값)에서 출발, 동그란 화면이라 위아래를 조금 더 비움
 */
private class LiveMetrics(val k: Float) {
    val top = 18 * k          // TOTAL 이름표 위
    val bottom = 13 * k        // 동그란 화면 아래 가장자리에 양옆 단추가 걸리지 않게
    val totalFont = 27 * k     // 전체 시간
    val icon = 16 * k          // 지금 구간 아이콘
    val name = 14 * k          // 지금 구간 이름
    val seg = 25 * k           // SPLIT · PACE 숫자
    val nextName = 15 * k      // NEXT 아래 다음 구간 이름
    val main = 44 * k          // 가운데 노란 단추 지름
    val side = 30 * k          // 양옆 작은 단추 지름
    /** 컨트롤 줄 폭 — 동그란 화면 아래쪽은 좁아서 양옆 단추가 원 안에 들어오게 */
    val controlsW = 126 * k
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

/**
 * 빌드 27 (68-② · 71-3·5): TOTAL · 지금 구간(아이콘 + 이름) · SPLIT | PACE/GOAL/BEST · 아래 줄
 * → NEXT + 다음 구간 이름 · 목표 → 컨트롤 줄 (되돌리기 · 다음(큰 노란 단추) · 일시정지). 위아래 간격을 고르게.
 * Roxzone 은 같은 모양인데 숫자 · 이름이 회색 (점선 테두리 안 씀), 단추는 노랑 그대로. 어두운 화면에서는 단추를 숨김
 */
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
    val isRox = e.cur.kind == SegKind.Rox

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
            // TOTAL (고정, 움직이지 않음)
            T("TOTAL", F.t(10 * m.k, W600, C.text2, tracking = 1.0f))
            val tot = e.total(now)
            // 어두운 화면은 1분에 한 번만 그려짐 → 초 자리는 지움
            T(if (aod) Fm.t(tot).dropLast(2) + "––" else Fm.t(tot),
                F.num(m.totalFont, color = if (aod) C.text2 else if (isRox) C.d1 else Color.White, tracking = -0.02f * m.totalFont),
                Modifier.fillMaxWidth().height((m.totalFont * 1.18f).dp).testTag("w.total"), translate = false)
            // 지금 구간 + NEXT + 컨트롤 줄 (넘길 때 밀림: 나가는 쪽 왼쪽, 들어오는 쪽 오른쪽에서)
            val curve = CubicBezierEasing(0.32f, 0.72f, 0f, 1f)
            AnimatedContent(e.idx, Modifier.weight(1f).fillMaxWidth(), label = "seg",
                transitionSpec = {
                    (slideInHorizontally(tween(220, easing = curve)) { it * 2 / 5 } + fadeIn(tween(220))) togetherWith
                        (slideOutHorizontally(tween(220, easing = curve)) { -it } + fadeOut(tween(220)))
                }) { _ ->
                Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.weight(1f).heightIn(min = 2.dp))
                    Current(now, m, aod)
                    Spacer(Modifier.weight(1f).heightIn(min = 4.dp))
                    if (!aod) {
                        NextLabel(m)
                        Spacer(Modifier.weight(1f).heightIn(min = 4.dp))
                        Controls(m)
                    }
                }
            }
        }
    }
}

private fun Color.toHex(): Long = ((red * 255).toLong() shl 16) or ((green * 255).toLong() shl 8) or (blue * 255).toLong()

/** 구간 이름 · SPLIT | PACE(러닝) / GOAL · BEST(스테이션) · 아래 줄 */
@Composable
private fun Current(now: Long, m: LiveMetrics, aod: Boolean) {
    val e = WatchStore.engine
    val cur = e.cur
    val el = e.segEl(now)
    val isRox = cur.kind == SegKind.Rox
    val fg = if (aod) C.text3 else if (isRox) C.d1 else Color.White
    val isRun = cur.icon == "run"
    val over = cur.target > 0 && el > cur.target
    // 빌드 24: 목표를 넘기면 SPLIT 빨강
    val splitColor = if (aod) C.text3 else if (isRox) C.d1 else if (over) C.bad else C.accent
    val rightColor = if (isRox) C.text2 else fg
    val imp = e.settings.imperial
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.height((m.name + 6).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon8(cur.icon, m.icon.dp, if (aod) Tint.Dim else if (isRox) Tint.Mute else Tint.Yellow)
            T(cur.name, F.t(m.name, W600, if (isRox) C.text2 else fg), minScale = 0.8f, translate = false)
        }
        Row(Modifier.fillMaxWidth().padding(top = 2.dp), verticalAlignment = Alignment.Top) {
            Col("SPLIT", if (aod) Fm.t(el).dropLast(2) + "––" else Fm.t(el), splitColor, m.seg, "w.split")
            Box(Modifier.padding(top = 12.dp).width(1.dp).height((m.seg * 1.05f).dp).background(Color.White.copy(alpha = 0.14f)))
            when {
                isRun -> Col(if (imp) (if (curvedRun()) "PACE/MI ≈" else "PACE /MI") else (if (curvedRun()) "PACE ≈" else "PACE"),
                    e.paceText(el, e.segDist, imp) ?: wt("Measuring"), rightColor, m.seg, "w.pace")
                // 빌드 24: 차이(±) 대신 목표 시간 그대로 (Roxzone 도). 트레이닝은 최고 기록 = BEST
                cur.target > 0 -> Col(if (e.mode == Mode.Training) "BEST" else "GOAL", Fm.t(cur.target), rightColor, m.seg, "w.goal")
                else -> Col("", cur.detail, C.text2, 13f, "w.detail", small = true)
            }
        }
        T(detailLine(now), if (isRun) F.num(11, W500, C.text2) else F.t(11, W500, C.text2),
            Modifier.fillMaxWidth().height(14.dp).testTag("w.detailLine"), minScale = 0.6f, translate = false)
    }
}

/** 아래 줄: 러닝 = 거리, 스테이션 = 무게 · 거리 (더블이고 계획이 있으면 "Me 150 → 파트너 150 · 7 turns"), Roxzone = 빈 줄 */
private fun detailLine(now: Long): String {
    val e = WatchStore.engine
    val cur = e.cur
    if (cur.icon == "run") return runLine(now)
    if (cur.kind == SegKind.Rox) return ""
    doublesLine(cur, WatchStore.ctx.doublesPlan, e.settings.division)?.let { return it }
    return if (cur.target > 0) Units.detail(cur.detail, e.settings.imperial) else ""
}

/** 러닝 아래 줄: "0.62 / 1.00 km · Total 7.62 km · Avg 5:12" (빌드 27: lb · mi 설정이면 마일) */
private fun runLine(now: Long): String {
    val e = WatchStore.engine
    val imp = e.settings.imperial
    val segM = runMeters(e.cur.detail)
    val unit = if (imp) "mi" else "km"
    val seg = Units.dist(minOf(segM, e.segDist), imp) + " / " + Units.dist(segM, imp) + " " + unit
    if (!e.isRunKind || e.distance < 10) return seg
    var line = seg + " · " + wt(if (imp) "Total %@ mi" else "Total %@ km", Units.dist(e.distance, imp))
    // 84번(빌드 28): 운동 전체 평균 페이스 (1 km 마다 끊지 않고 처음부터 계속) — 200 m 뛴 뒤부터
    if (e.distance >= 200) {
        val avg = Units.pace((e.total(now) / e.distance * 1000).roundToInt(), imp)
        if (avg in 1 until 3600) line += " · " + wt("Avg %@", Fm.t(avg))
    }
    return line
}

private fun curvedRun(): Boolean = WatchStore.engine.settings.runMode == "curved" && WatchStore.engine.mode != Mode.Race

/** 작은 이름표 + 큰 숫자 (두 칸이 같은 크기) */
@Composable
private fun RowScope.Col(label: String, value: String, color: Color, size: Float, tag: String, small: Boolean = false) {
    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
        T(label, F.t(10, W600, C.text3, tracking = 0.8f), Modifier.height(12.dp))
        T(value, if (small) F.t(13, W600, color) else F.num(size, color = color, tracking = -0.01f * size),
            Modifier.fillMaxWidth().height((size * 1.12f).dp).testTag(tag), minScale = 0.55f, translate = false)
    }
}

/** 러닝 모드(거리 있음)는 1 km 마다 자동으로 넘어감 → 가운데 단추 대신 안내 */
private val autoSplitView: Boolean get() = WatchStore.engine.isRunKind && WatchStore.engine.distance > 0

/** NEXT (작게) + 다음 구간 그림 · 이름 (크게) + 그 목표 (회색). 마지막이면 FINISH · 운동 끝내기 */
@Composable
private fun NextLabel(m: LiveMetrics) {
    val e = WatchStore.engine
    val nx = e.nextSeg
    val last = e.isLast
    Column(Modifier.fillMaxWidth().testTag("w.nextName"), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        T(if (last) "FINISH" else "NEXT", F.t(9, W600, C.text3, tracking = 1.0f))
        Row(Modifier.padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            if (last) {
                Icon8("i_check", (m.nextName * 0.8f).dp, C.good)
                T("End workout", F.t(m.nextName, W700), Modifier.weight(1f, fill = false))
            } else {
                Icon8(nx.icon, m.nextName.dp, if (nx.kind == SegKind.Rox) Tint.Mute else Tint.Yellow)
                T(nx.name, F.t(m.nextName, W700), Modifier.weight(1f, fill = false), translate = false)
                if (nx.target > 0 && !autoSplitView) T(Fm.t(nx.target), F.num(m.nextName * 0.72f, W500, C.text2), translate = false)
            }
        }
    }
}

/** 컨트롤 줄: 되돌리기 (작은 회색) · 다음 (큰 노란, 삼각형 머리 화살표) · 일시정지 (작은 회색) */
@Composable
private fun Controls(m: LiveMetrics) {
    val e = WatchStore.engine
    Row(Modifier.width(m.controlsW.dp), verticalAlignment = Alignment.CenterVertically) {
        SideButton(m, e.canUndo, "w.undoLive", { c -> Sym(R.drawable.sym_undo, (m.side * 0.42f).dp, c) }) { e.undo() }
        Spacer(Modifier.weight(1f))
        if (autoSplitView) {
            // 러닝은 1 km 마다 자동 → 누를 수 없음, 안내만
            T("Auto split every 1 km", F.t(10, W600, C.text2), Modifier.width((m.main * 1.6f).dp).height(m.main.dp).testTag("w.autoSplit"),
                maxLines = 2, align = TextAlign.Center)
        } else {
            val last = e.isLast
            Box(Modifier.size(m.main.dp).clip(CircleShape).background(if (last) C.good else C.accent).press { e.advance() }.testTag("w.next"),
                contentAlignment = Alignment.Center) {
                if (last) Icon8("i_check", (m.main * 0.42f).dp, Color.Black)
                else TriArrow(Modifier.size((m.main * 0.5f).dp, (m.main * 0.42f).dp), Color.Black)
            }
        }
        Spacer(Modifier.weight(1f))
        SideButton(m, true, "w.pauseLive", { c -> Icon8(if (e.running) "i_pause" else "i_play", (m.side * 0.42f).dp, c) }) { e.togglePause() }
    }
}

@Composable
private fun SideButton(m: LiveMetrics, on: Boolean, tag: String, glyph: @Composable (Color) -> Unit, onClick: () -> Unit) {
    Box(Modifier.size(m.side.dp).clip(CircleShape).background(Color.White.copy(alpha = if (on) 0.16f else 0.07f)).press(on, onClick).testTag(tag),
        contentAlignment = Alignment.Center) {
        glyph(if (on) Color.White else C.text3)
    }
}

/** 삼각형 머리 화살표 (3-A) — 가운데 노란 단추 안 (아이폰 TriArrow 와 같은 비율) */
@Composable
private fun TriArrow(modifier: Modifier, color: Color) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val bar = h * 0.18f
        val headW = w * 0.42f
        // 막대
        drawRoundRect(color, Offset(w * 0.06f, h / 2 - bar / 2), Size(w - headW - w * 0.02f, bar), CornerRadius(bar * 0.35f))
        // 머리 (삼각형)
        val p = Path().apply {
            moveTo(w - headW - w * 0.02f, h * 0.14f)
            lineTo(w - w * 0.02f, h / 2)
            lineTo(w - headW - w * 0.02f, h - h * 0.14f)
            close()
        }
        drawPath(p, color)
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
        // 2026-10-21: 위 제목 줄 · 아래 안내 글이 동그란 테두리에 잘려서 안쪽으로
        Column(Modifier.fillMaxSize().padding(top = (28 * k).dp, bottom = (30 * k).dp), horizontalAlignment = Alignment.CenterHorizontally) {
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
            T("‹ Swipe left to go back", F.t(11, color = C.text3), Modifier.widthIn(max = roundWidth(30 * k)))
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
        // 2026-10-21: 아래 단추 줄이 동그란 테두리에 잘려서 → 조금 올리고, 맨 아래 줄은 원 안에 들어오는 폭으로
        val bottomPad = 30 * k
        val lastW = roundWidth(bottomPad)
        Column(Modifier.fillMaxSize().padding(start = (26 * k).dp, end = (26 * k).dp, top = (30 * k).dp, bottom = bottomPad.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
            if (!ask) {
                T("End workout?", F.t(15, W600))
                // 구간 수는 Roxzone 을 빼고 셈 (빌드 24 — 운동 중 화면의 n / 16 과 같게)
                val done = e.seq.take(e.idx).count { it.kind != SegKind.Rox }
                val all = e.seq.count { it.kind != SegKind.Rox }
                T(if (e.growsOpen) wt("Everything so far will be saved.") else wt("%lld/%lld segments done. The rest won't be recorded.", done, all),
                    F.t(12, color = C.text2), Modifier.fillMaxWidth(), maxLines = 3, align = TextAlign.Center, translate = false)
                Spacer(Modifier.weight(1f))
                SheetButton("Save & end", Color.Black, C.accent, Modifier.width(roundWidth(bottomPad + 39f)).testTag("w.endConfirm"), onEnd)
                Row(Modifier.width(lastW), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SheetButton("Discard", C.bad, hex(0x2A1412), Modifier.weight(1f).testTag("w.discard")) { buzz(BuzzKind.Click); ask = true }
                    SheetButton("Resume", Color.White, hex(0x1F1F1F), Modifier.weight(1f).testTag("w.resume"), onResume)
                }
            } else {
                T("Discard this workout?", F.t(15, W600))
                T("It won't be saved here, on your phone or in Health Connect.", F.t(12, color = C.text2), Modifier.fillMaxWidth(), maxLines = 3, align = TextAlign.Center)
                Spacer(Modifier.weight(1f))
                SheetButton("Discard", Color.White, C.bad, Modifier.width(roundWidth(bottomPad + 39f)).testTag("w.discardConfirm"), onDiscard)
                SheetButton("Cancel", Color.White, hex(0x1F1F1F), Modifier.width(lastW)) { ask = false }
            }
        }
    }
}

@Composable
private fun SheetButton(t: String, fg: Color, bg: Color, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(34.dp).clip(Pill).background(bg).press(onClick = onClick), contentAlignment = Alignment.Center) {
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
        // 2026-10-21: 첫 줄이 화면 가운데에서 시작해 아래 AVG · MAX · KCAL 이 잘렸음 → 첫 줄을 맨 위에 붙여 시작 (가운데 맞춤 끔)
        val state = rememberScalingLazyListState(initialCenterItemIndex = 0, initialCenterItemScrollOffset = 0)
        ScalingLazyColumn(Modifier.fillMaxSize(), state = state,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = (22 * k).dp, end = (22 * k).dp, top = (30 * k).dp, bottom = (40 * k).dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            anchorType = androidx.wear.compose.foundation.lazy.ScalingLazyListAnchorType.ItemStart,
            autoCentering = null) {
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
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Box(Modifier.width(screenFrac(0.6f)).height(36.dp).clip(Pill).background(C.accent)
                        .press { e.reset(); WNav.open(null) }.testTag("w.done"), contentAlignment = Alignment.Center) {
                        T("Done", F.t(14, W600, Color.Black))
                    }
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
