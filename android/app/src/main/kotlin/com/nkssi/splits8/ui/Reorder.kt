package com.nkssi.splits8.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlin.math.roundToInt

// 17번: 줄 순서 바꾸기 (트레이닝 목록 · 친구 목록 · 빌더 구간 줄 공용).
// - 끄는 줄은 살짝 커지고(1.03배) 그림자 + 배경 #2C2C2E, 손가락을 따라감
// - 다른 줄은 놓일 자리 기준으로 미리 비켜 줌 (한 칸 넘을 때마다 작은 진동)
// - 목록: 0.4초쯤 꾹 누르면 "툭"(LongPress 진동) 하고 떠오름. 그 전에 움직이면 그냥 스크롤, 짧게 누르면 그냥 탭
// - 화면 위 · 아래 끝으로 끌면 저절로 스크롤 (Scroll8 안에서)
// 줄 높이가 서로 달라도 됨 (트레이닝 카드는 칩 줄 수에 따라 높이가 다름)

class ReorderState internal constructor(private val gapPx: Float) {
    /** 끄는 줄 (원래 번호). null = 안 끄는 중 */
    var from by mutableStateOf<Int?>(null)
        private set
    /** 놓일 자리 */
    var to by mutableIntStateOf(0)
        private set
    /** 손가락이 움직인 거리 (px, 아래 +) */
    var dy by mutableFloatStateOf(0f)
        private set
    /** 손가락 위치 (창 기준 y) — 자동 스크롤에 씀 */
    internal var fingerY = 0f
    private var count = 0
    private val heights = HashMap<Int, Int>()
    private val tops = HashMap<Int, Float>()
    internal var tick: () -> Unit = {}
    internal var lift: () -> Unit = {}

    /** 끄는 동안 그릴 순서 (원래 번호 목록) — 끄는 줄을 놓일 자리에 미리 넣음 */
    fun order(n: Int): List<Int> = (0 until n).toMutableList().also { o ->
        val f = from
        if (f != null && f in o.indices) { val x = o.removeAt(f); o.add(to.coerceIn(0, o.size), x) }
    }

    fun dragging(i: Int): Boolean = from == i

    private fun h(k: Int): Float = (heights[k] ?: 0) + gapPx

    /** i 를 t 자리에 놓으면 i 가 움직이는 거리 (아래 +, 위 −) */
    private fun shift(i: Int, t: Int): Float = when {
        t > i -> (i + 1..t).fold(0f) { a, k -> a + h(k) }
        t < i -> -(t until i).fold(0f) { a, k -> a + h(k) }
        else -> 0f
    }

    /** 그 줄을 그릴 때 더 옮길 거리 (끄는 줄만: 놓일 자리에서 손가락 자리까지) */
    fun offset(i: Int): Float = if (from == i) dy - shift(i, to) else 0f

    internal fun measured(i: Int, height: Int, windowTop: Float) {
        heights[i] = height
        if (from == null) tops[i] = windowTop
    }

    internal fun start(i: Int, n: Int, localY: Float) {
        count = n; from = i; to = i; dy = 0f
        fingerY = (tops[i] ?: 0f) + localY
        lift()
    }

    /** d 만큼 끌기 (손가락 또는 자동 스크롤). 목록 밖으로는 안 나가게 */
    internal fun moveBy(d: Float) {
        val f = from ?: return
        dy = (dy + d).coerceIn(shift(f, 0), shift(f, count - 1))
        var t = f
        // 다음 줄의 절반을 넘으면 한 칸
        while (t < count - 1 && dy > shift(f, t) + h(t + 1) / 2) t++
        while (t > 0 && dy < shift(f, t) - h(t - 1) / 2) t--
        if (t != to) { to = t; tick() }
    }

    /** 손을 뗌 → (원래 번호, 놓을 자리). 안 움직였으면 null */
    internal fun end(): Pair<Int, Int>? {
        val f = from
        val t = to
        from = null; dy = 0f; to = 0
        return if (f != null && f != t) f to t else null
    }

    internal fun cancel() { from = null; dy = 0f; to = 0 }
}

/** gap = 줄 사이 빈칸 (Column spacedBy 값) */
@Composable
fun rememberReorder(gap: Dp = 0.dp): ReorderState {
    val px = with(LocalDensity.current) { gap.toPx() }
    val st = remember(px) { ReorderState(px) }
    val haptic = LocalHapticFeedback.current
    st.tick = { haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
    st.lift = { haptic.performHapticFeedback(HapticFeedbackType.LongPress) }
    AutoScroll(st)
    return st
}

/**
 * 줄 바깥에 붙임: 높이 · 자리 재기 + 끄는 줄 모양 (위로 그려짐 · 1.03배 · 그림자 · #2C2C2E).
 * Column 의 바로 아래 자식에 붙여야 위로 그려짐 (zIndex)
 */
@Composable
fun Modifier.reorderItem(st: ReorderState, i: Int, corner: Dp = 14.dp): Modifier {
    val on = st.dragging(i)
    return this
        .zIndex(if (on) 1f else 0f)
        .onGloballyPositioned { c -> st.measured(i, c.size.height, c.positionInWindow().y) }
        .dragLift(on, corner) { st.offset(i) }
}

/** 끄는 줄 모양 (빌더 구간 줄과 같음): 손가락 따라 옮김 · 1.03배 · 그림자 · 배경 #2C2C2E */
@Composable
fun Modifier.dragLift(dragging: Boolean, corner: Dp = 14.dp, offsetPx: () -> Float): Modifier {
    val sc by animateFloatAsState(if (dragging) 1.03f else 1f, tween(150), label = "drag")
    val shape = RoundedCornerShape(if (dragging) corner else 0.dp)
    return this
        .offset { IntOffset(0, offsetPx().roundToInt()) }
        .scale(sc)
        .then(if (dragging) Modifier.shadow(12.dp, shape) else Modifier)
        .clip(shape)
        .background(if (dragging) C.segOn else Color.Transparent)
}

/**
 * 꾹 눌러 끌기. 탭 처리(tap · clickable)보다 뒤(안쪽)에 붙여야 꾹 누른 뒤 그냥 뗐을 때 탭이 같이 안 눌림.
 * onMove(원래 번호, 놓을 자리) — 손을 뗄 때 한 번
 */
fun Modifier.reorderLongPress(st: ReorderState, i: Int, n: Int, onMove: (from: Int, to: Int) -> Unit): Modifier =
    if (n < 2) this else this.pointerInput(st, i, n) {
        detectDragGesturesAfterLongPress(
            onDragStart = { p -> st.start(i, n, p.y) },
            onDragEnd = { st.end()?.let { (f, t) -> onMove(f, t) } },
            onDragCancel = { st.cancel() },
        ) { ch, d ->
            ch.consume()
            st.fingerY += d.y
            st.moveBy(d.y)
        }
    }

/** 끄는 동안 손가락이 보이는 영역 위 · 아래 끝(64dp 안)에 있으면 그쪽으로 스크롤 (깊이 들어갈수록 빠르게) */
@Composable
private fun AutoScroll(st: ReorderState) {
    val area = LocalScrollArea.current ?: return
    val density = LocalDensity.current
    val zone = with(density) { 64.dp.toPx() }
    val maxStep = with(density) { 14.dp.toPx() }
    val on = st.from != null
    LaunchedEffect(on) {
        if (!on) return@LaunchedEffect
        while (st.from != null) {
            val y = st.fingerY
            val v = when {
                y < area.top + zone -> -maxStep * ((area.top + zone - y) / zone).coerceIn(0f, 1f)
                y > area.bottom - zone -> maxStep * ((y - (area.bottom - zone)) / zone).coerceIn(0f, 1f)
                else -> 0f
            }
            if (v != 0f) {
                // 화면이 움직인 만큼 끄는 줄도 같이 (손가락 밑에 그대로 있게)
                val used = area.state.scrollBy(v)
                if (used != 0f) st.moveBy(used)
            }
            withFrameNanos { }
        }
    }
}
