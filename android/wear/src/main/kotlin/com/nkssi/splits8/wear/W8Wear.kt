package com.nkssi.splits8.wear

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import java.time.LocalTime
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

// MARK: - 1.2.7 갤럭시 워치 새 디자인 공통 (애플워치 Shared/W8Style.swift 와 같은 색 · 규칙, 동그란 화면 자리)
// 운동 중: 스테이션 · 운동 = 노랑 / 러닝 · 빠르게 = 파랑 / Roxzone · 휴식 = 회색. 뒤에 흐린 덩어리가 비침.
// 메뉴 · 시작 전 · 끝: 검정 + 테마 빛 색 덩어리. 값은 프로젝트 문서 splits8-1.2.7-갤럭시워치-화면.md (지름 227 기준).

/** 구간 색 */
enum class WTone {
    Station, Run, Gray;

    /** 노랑 위는 검정 글자, 파랑 · 회색 위는 흰 글자 */
    val dark: Boolean get() = this == Station
    val ink: Color get() = if (dark) Color.Black else Color.White
    /** 보조 글자 (검정 53% / 흰 65%) */
    val sub: Color get() = if (dark) Color.Black.copy(alpha = 0.53f) else Color.White.copy(alpha = 0.65f)
    /** 이름표 (검정 59% / 흰 69%) */
    val label: Color get() = if (dark) Color.Black.copy(alpha = 0.59f) else Color.White.copy(alpha = 0.69f)
    /** 귀퉁이 표시 */
    val mark: Color get() = if (dark) Color.Black.copy(alpha = 0.92f) else Color.Black.copy(alpha = 0.59f)
    /** 글자 그림자 */
    val shadow: Color get() = if (dark) Color(120 / 255f, 80 / 255f, 0f, 0.22f) else Color.Black.copy(alpha = 0.35f)
    /** 유리 버튼 바탕 (흰 반투명) */
    val glass: Float get() = if (dark) 0.27f else 0.18f
    /** 남은 점 */
    val dotOff: Color get() = if (dark) Color.Black.copy(alpha = 0.24f) else Color.Black.copy(alpha = 0.49f)
    /** 바탕 그라데이션 (위 → 아래) */
    val stops: List<Color>
        get() = when (this) {
            Station -> listOf(hex(0xFFE600), hex(0xFFDE00), hex(0xFFD600))
            Run -> listOf(hex(0x1E78FA), hex(0x186AF1), hex(0x125CE8))
            Gray -> listOf(hex(0x54545C), hex(0x494951), hex(0x3E3E46))
        }
    /** 가장자리 살짝 어둡게 */
    val edge: Color get() = if (this == Station) hex(0xE1A000) else Color.Black
    /** 뒤에 비치는 덩어리 */
    val blob: Color get() = if (this == Station) hex(0xC87800) else Color.Black
    val blobAlpha: Float get() = if (this == Station) 0.45f else 0.26f
    /** 조작 화면 · 운동 중 Next 글자 (노랑 위 = 검정 바탕 노랑 글자, 그 밖 = 흰 바탕 파랑 글자) */
    val nextFg: Color get() = if (dark) C.accent else hex(0x145FEB)
    val nextBg: Color get() = if (dark) Color.Black.copy(alpha = 0.69f) else Color.White.copy(alpha = 0.8f)

    companion object {
        /**
         * 11-21 대표님 (애플워치와 같음): 심박 존에 따라 바탕색을 바꾸지 않음. 구간 색만.
         */
        const val ZONE_TINT: Boolean = false

        fun of(s: Seg): WTone = when {
            s.kind == SegKind.Rox -> Gray
            s.icon == "run" -> Run
            else -> Station
        }
    }
}

/** 손목 내렸을 때 (항상 켜짐) 색 */
object WAod {
    val text = hex(0x96969B)
    val mark = hex(0x96969B, 0.55f)
    val dotOff = hex(0x46464B)
}

// MARK: 자리 (지름 227 기준)

/** 동그란 화면 지름 227 기준 크기를 화면에 맞춤 */
class WScale(val w: Float, val h: Float) {
    val s: Float get() = min(w, h) / D
    /** 가운데 */
    val cx: Float get() = w / 2
    fun x(v: Float): Float = v * s + (w - D * s) / 2
    fun y(v: Float): Float = v * s + (h - D * s) / 2
    fun v(v: Float): Float = v * s
    fun dx(v: Float): Dp = x(v).dp
    fun dy(v: Float): Dp = y(v).dp
    fun dv(v: Float): Dp = v(v).dp

    /** 그 높이(기준 값)에서 동그라미 반 폭 (기준 값) */
    fun half(y: Float): Float {
        val dy = abs(y - D / 2)
        return sqrt(max(0f, (D / 2) * (D / 2) - dy * dy))
    }

    /** 위 · 아래 끝(기준 값) 사이 줄의 폭 (동그라미 안 [m] 안쪽, 최대 [mx]) */
    fun rowW(y0: Float, y1: Float, m: Float = 12f, mx: Float = 152f): Float = min(mx, 2 * (min(half(y0), half(y1)) - m))

    companion object { const val D = 227f }
}

/** 화면 전체를 자리로 씀 (동그란 화면 지름 227 기준) */
@Composable
fun WCanvas(modifier: Modifier = Modifier, content: @Composable BoxWithConstraintsScope.(WScale) -> Unit) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        val L = WScale(maxWidth.value, maxHeight.value)
        content(L)
    }
}

/** 부모(화면 전체) 안에서 가운데를 (x, y) dp 에 둠 */
fun Modifier.at(x: Dp, y: Dp): Modifier = this.layout { m, c ->
    val p = m.measure(c.copy(minWidth = 0, minHeight = 0))
    val W = if (c.hasBoundedWidth) c.maxWidth else p.width
    val H = if (c.hasBoundedHeight) c.maxHeight else p.height
    layout(W, H) { p.place(x.roundToPx() - p.width / 2, y.roundToPx() - p.height / 2) }
}

/** 대문자 높이 (Pretendard ≈ 0.72) */
fun wCap(size: Float): Float = size * 0.72f

/** 글자 그림자 (글자 모양을 7 흐리게 · 아래로 2) */
@Composable
fun TextStyle.wShadow(tone: WTone, L: WScale, aod: Boolean): TextStyle {
    if (aod) return this
    val d = LocalDensity.current.density
    return this.copy(shadow = Shadow(tone.shadow, Offset(0f, 2f * L.s * d), 7f * L.s * d))
}

/** 한 줄 글자 (가운데 (x, y), 폭 w 안에 맞게 작아짐) */
@Composable
fun WText(text: String, style: TextStyle, L: WScale, x: Float, y: Float, w: Float, minScale: Float = 0.6f, translate: Boolean = false, tag: String? = null) {
    var m: Modifier = Modifier.at(L.dx(x), L.dy(y)).size(L.dv(w), (style.fontSize.value * 1.3f).dp)
    if (tag != null) m = m.testTag(tag)
    T(text, style, m, minScale = minScale, translate = translate)
}

/** 글꼴 (Pretendard) 크기는 기준 값 × 화면 비율 */
fun wf(L: WScale, size: Float, weight: FontWeight = W600, color: Color = Color.White, tracking: Float = 0f, num: Boolean = false): TextStyle =
    if (num) F.num(size * L.s, weight, color, tracking) else F.t(size * L.s, weight, color, tracking)

// MARK: 시계 · TOTAL

/** 맨 위 가운데 시계 (13, 높이 13) */
@Composable
fun WClock(L: WScale, color: Color) {
    var t by remember { mutableStateOf(clockText()) }
    LaunchedEffect(Unit) { while (true) { t = clockText(); kotlinx.coroutines.delay(5_000) } }
    WText(t, wf(L, 13f, W600, color, num = true), L, WScale.D / 2, 13f, 80f)
}

private fun clockText(): String {
    val n = LocalTime.now()
    return String.format(java.util.Locale.US, "%d:%02d", n.hour, n.minute)
}

// MARK: 바탕

/** 운동 중 바탕: 그라데이션 + 가장자리 + 흐린 덩어리 (구간마다 새 모양) */
@Composable
fun WBackground(tone: WTone, seed: Int, aod: Boolean, darker: Float = 0f) {
    if (aod) { Canvas(Modifier.fillMaxSize()) { drawRect(Color.Black) }; return }
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.verticalGradient(tone.stops))
            // 가장자리 (동그라미 테두리 쪽 살짝 어둡게)
            val r = min(size.width, size.height) / 2
            drawCircle(Brush.radialGradient(0.72f to tone.edge.copy(alpha = 0f), 1f to tone.edge.copy(alpha = 0.27f),
                center = center, radius = r), radius = r * 1.02f, center = center)
        }
        Crossfade(seed, animationSpec = tween(600), label = "blobs") { sd -> WBlobs(sd, tone.blob, tone.blobAlpha) }
        if (darker > 0f) Canvas(Modifier.fillMaxSize()) { drawRect(Color.Black.copy(alpha = darker)) }
    }
}

/** 메뉴 · 시작 전 · 끝 바탕: 검정 + 테마 빛 색 덩어리 */
@Composable
fun WMenuBackground(seed: Int = 40) {
    val th = WatchStore.settings.glow
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) { drawRect(Brush.verticalGradient(listOf(hex(0x0E0E10), hex(0x08080A)))) }
        WBlobs(seed, hex(th.hex), min(0.5f, (0.30 * th.gain).toFloat()), blur = 16f)
    }
}

/** 흐린 덩어리 2~4개 (같은 seed 는 같은 모양) */
@Composable
fun WBlobs(seed: Int, color: Color, alpha: Float, blur: Float = 14f) {
    val blobs = remember(seed) {
        val g = WRand((seed.toLong() * 7919 + 17))
        val n = 2 + (g.next() % 3).toInt()
        List(n) { floatArrayOf(0.05f + 0.9f * g.unit(), 0.1f + 0.85f * g.unit(), 0.18f + 0.22f * g.unit(), 0.6f + 0.4f * g.unit()) }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val k = min(maxWidth.value, maxHeight.value) / WScale.D
        Canvas(Modifier.fillMaxSize().blur((blur * k).dp)) {
            val w = size.width
            val h = size.height
            for (b in blobs) drawCircle(color.copy(alpha = alpha * b[3]), radius = w * b[2], center = Offset(w * b[0], h * b[1]))
        }
    }
}

/** 같은 seed → 같은 수 (SplitMix64, 아이폰 W8Rand 와 같음) */
class WRand(seed: Long) {
    private var state: Long = seed + -0x61c8864680b583ebL
    fun next(): Long {
        state += -0x61c8864680b583ebL
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L
        return (z xor (z ushr 31)) and Long.MAX_VALUE
    }
    fun unit(): Float = (next() % 10_000).toFloat() / 10_000f
}

// MARK: 귀퉁이 표시 (뷰파인더) — 동그라미 안쪽 14 안에 들게 좌우 자리를 계산

@Composable
fun WBrackets(L: WScale, y0: Float, y1: Float, color: Color, m: Float = 14f, lineW: Float = 2.4f, arm: Float = 8f) {
    val h = min(L.half(y0), L.half(y1))
    val x0 = WScale.D / 2 - h + m
    val x1 = WScale.D / 2 + h - m
    Canvas(Modifier.fillMaxSize()) {
        val px = { v: Float -> L.x(v).dp.toPx() }
        val py = { v: Float -> L.y(v).dp.toPx() }
        val a = L.v(arm).dp.toPx()
        val st = Stroke(L.v(lineW).dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
        val p = Path()
        for ((x, sx) in listOf(px(x0) to 1f, px(x1) to -1f)) {
            for ((y, sy) in listOf(py(y0) to 1f, py(y1) to -1f)) {
                p.moveTo(x + sx * a, y); p.lineTo(x, y); p.lineTo(x, y + sy * a)
            }
        }
        drawPath(p, color, style = st)
    }
}

// MARK: 아이콘 (그린 것)

/** 되돌리기 (대표님 참고 그림 — 애플워치와 같은 모양) */
fun DrawScope.wUndo(center: Offset, size: Float, color: Color) {
    val sc = size / 270f
    val ox = center.x - 175.5f * sc
    val oy = center.y - 148f * sc
    fun P(x: Float, y: Float) = Offset(ox + x * sc, oy + y * sc)
    val tri = Path().apply { moveTo(P(63f, 106f).x, P(63f, 106f).y); lineTo(P(132f, 53f).x, P(132f, 53f).y); lineTo(P(132f, 159f).x, P(132f, 159f).y); close() }
    drawPath(tri, color)
    drawPath(tri, color, style = Stroke(16 * sc, join = StrokeJoin.Round))
    drawRect(color, P(128f, 82f), Size(90 * sc, 48 * sc))
    val c = P(215f, 170f)
    val r = 64 * sc
    drawArc(color, -90f, 180f, false, Offset(c.x - r, c.y - r), Size(2 * r, 2 * r), style = Stroke(48 * sc, cap = StrokeCap.Butt))
    drawRoundRect(color, P(142f, 210f), Size(75 * sc, 48 * sc), CornerRadius(8 * sc))
}

/** 다음(→) — 막대 + 삼각형 머리 (w × h 상자 가운데) */
fun DrawScope.wArrow(center: Offset, w: Float, h: Float, color: Color) {
    val l = center.x - w / 2
    val t = center.y - h / 2
    val bar = h * 0.27f
    drawRoundRect(color, Offset(l, center.y - bar / 2), Size(w * 0.62f, bar), CornerRadius(bar * 0.25f))
    val p = Path().apply { moveTo(l + w * 0.48f, t); lineTo(l + w, center.y); lineTo(l + w * 0.48f, t + h); close() }
    drawPath(p, color)
}

/** 일시정지 두 막대 / 다시 시작 세모 (size × size) */
fun DrawScope.wPause(center: Offset, size: Float, color: Color, paused: Boolean) {
    if (paused) {
        val p = Path().apply {
            moveTo(center.x - size * 0.34f, center.y - size * 0.45f)
            lineTo(center.x + size * 0.46f, center.y)
            lineTo(center.x - size * 0.34f, center.y + size * 0.45f); close()
        }
        drawPath(p, color)
        drawPath(p, color, style = Stroke(size * 0.08f, join = StrokeJoin.Round))
        return
    }
    val bw = size * 0.24f
    val gap = size * 0.22f
    drawRoundRect(color, Offset(center.x - gap / 2 - bw, center.y - size / 2), Size(bw, size), CornerRadius(size * 0.08f))
    drawRoundRect(color, Offset(center.x + gap / 2, center.y - size / 2), Size(bw, size), CornerRadius(size * 0.08f))
}

/** 건너뛰기 (▶|) */
fun DrawScope.wSkip(center: Offset, size: Float, color: Color) {
    val s = size / 2
    val p = Path().apply { moveTo(center.x - s * 0.8f, center.y - s * 0.8f); lineTo(center.x + s * 0.4f, center.y); lineTo(center.x - s * 0.8f, center.y + s * 0.8f); close() }
    drawPath(p, color)
    drawRoundRect(color, Offset(center.x + s * 0.5f, center.y - s * 0.8f), Size(s * 0.38f, s * 1.6f), CornerRadius(s * 0.12f))
}

/** 끝내기 (꽉 찬 동그라미 안 X 구멍) */
fun DrawScope.wEndMark(center: Offset, size: Float, color: Color) {
    val r = size / 2
    val circle = Path().apply { addOval(Rect(center, r)) }
    val a = r * 0.45f
    val wdt = r * 0.29f
    val x = Path().apply {
        addRoundRect(RoundRect(Rect(center.x - a * 1.25f, center.y - wdt / 2, center.x + a * 1.25f, center.y + wdt / 2), CornerRadius(wdt / 2)))
    }
    val rot = { deg: Float ->
        val pp = Path(); pp.addPath(x)
        val mm = androidx.compose.ui.graphics.Matrix(); mm.translate(center.x, center.y); mm.rotateZ(deg); mm.translate(-center.x, -center.y)
        pp.transform(mm); pp
    }
    val cross = Path.combine(PathOperation.Union, rot(45f), rot(-45f))
    drawPath(Path.combine(PathOperation.Difference, circle, cross), color)
}

/** 체크 ✓ */
fun DrawScope.wCheck(center: Offset, size: Float, color: Color) {
    val s = size / 2
    val p = Path().apply { moveTo(center.x - s, center.y); lineTo(center.x - s * 0.25f, center.y + s * 0.75f); lineTo(center.x + s, center.y - s * 0.8f) }
    drawPath(p, color, style = Stroke(size * 0.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
}

/** 시작 ▶ */
fun DrawScope.wPlay(center: Offset, size: Float, color: Color) {
    val s = size / 2
    val p = Path().apply { moveTo(center.x - s * 0.7f, center.y - s); lineTo(center.x + s, center.y); lineTo(center.x - s * 0.7f, center.y + s); close() }
    drawPath(p, color)
}

// MARK: 유리

/** 유리 (테두리 선 없이 위쪽만 옅은 가장자리 빛 + 아래 그림자). shape = 둥근 정도(반지름, px) */
fun DrawScope.wGlass(topLeft: Offset, sz: Size, radius: Float, fill: Color, rim: Float = 0.55f, gloss: Float = 0f, dim: Boolean = false) {
    val cr = CornerRadius(radius)
    if (!dim) drawRoundRect(Color.Black.copy(alpha = 0.18f), topLeft + Offset(0f, 3f * density), sz, cr)
    drawRoundRect(fill, topLeft, sz, cr)
    if (gloss > 0f) drawRoundRect(Brush.verticalGradient(0f to Color.White.copy(alpha = gloss), 0.55f to Color.White.copy(alpha = 0f),
        startY = topLeft.y, endY = topLeft.y + sz.height), topLeft, sz, cr)
    if (!dim) drawRoundRect(Brush.verticalGradient(0f to Color.White.copy(alpha = rim), 0.45f to Color.White.copy(alpha = 0f),
        startY = topLeft.y, endY = topLeft.y + sz.height), topLeft + Offset(0.5f, 0.5f), Size(sz.width - 1f, sz.height - 1f),
        CornerRadius(max(0f, radius - 0.5f)), style = Stroke(1f * density))
}

/** 누를 때 살짝 커지면서 밝아짐 (부드러운 스프링) — 동그란 유리 단추 · 알약 단추 공통 */
@Composable
fun WPressBox(modifier: Modifier, enabled: Boolean = true, onClick: () -> Unit, content: @Composable (pressed: Boolean) -> Unit) {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val sc by animateFloatAsState(if (pressed) 1.08f else 1f, spring(dampingRatio = 0.6f, stiffness = 500f), label = "press")
    Box(modifier.scale(sc).clickable(src, indication = null, enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        content(pressed)
    }
}

/** 동그란 유리 단추 (운동 중 아래 3개). r = 반지름(기준 값) */
@Composable
fun WCircleButton(L: WScale, x: Float, y: Float, r: Float, tone: WTone, aod: Boolean, on: Boolean = true, tag: String,
                  onClick: () -> Unit, icon: DrawScope.(Offset, Color) -> Unit) {
    val ic = if (aod) WAod.text else tone.ink.copy(alpha = if (on) 1f else 0.35f)
    WPressBox(Modifier.at(L.dx(x), L.dy(y)).size(L.dv(2 * r)).then(Modifier.testTag2(tag)), enabled = on && !aod, onClick = onClick) { pressed ->
        Canvas(Modifier.fillMaxSize()) {
            val R = size.minDimension / 2
            if (aod) {
                drawCircle(Color.White.copy(alpha = 0.07f), R)
                drawCircle(Color.White.copy(alpha = 0.14f), R - 0.5f * density, style = Stroke(1f * density))
            } else {
                drawCircle(Color.Black.copy(alpha = 0.16f), R, center + Offset(0f, 3f * density))
                drawCircle(Color.White.copy(alpha = tone.glass + if (pressed) 0.12f else 0f), R)
                drawCircle(Color.White.copy(alpha = 0.27f), R - 1.2f * density, style = Stroke(0.9f * density))
                drawArc(Color.White.copy(alpha = 0.75f), 200f, 140f, false, Offset(1.6f * density, 1.6f * density),
                    Size(size.width - 3.2f * density, size.height - 3.2f * density), style = Stroke(1.4f * density, cap = StrokeCap.Round))
                drawArc(Color.White.copy(alpha = 0.35f), 20f, 140f, false, Offset(1.6f * density, 1.6f * density),
                    Size(size.width - 3.2f * density, size.height - 3.2f * density), style = Stroke(1f * density, cap = StrokeCap.Round))
            }
            icon(center, ic)
        }
    }
}

/** 알약 유리 단추 (조작 화면 · 메뉴). 위치 = 왼쪽 위(기준 값), 크기(기준 값) */
@Composable
fun WPill(L: WScale, x0: Float, y0: Float, w: Float, h: Float, fill: Color, rim: Float, tag: String, enabled: Boolean = true,
          gloss: Float = 0f, onClick: () -> Unit, content: @Composable () -> Unit) {
    WPressBox(Modifier.at(L.dx(x0 + w / 2), L.dy(y0 + h / 2)).size(L.dv(w), L.dv(h)).then(Modifier.testTag2(tag)), enabled = enabled, onClick = onClick) { pressed ->
        Canvas(Modifier.fillMaxSize()) {
            wGlass(Offset.Zero, size, size.height / 2, if (pressed) fill.copy(alpha = min(1f, fill.alpha + 0.12f)) else fill, rim, gloss)
        }
        content()
    }
}

/**
 * 아래 끝 버튼 (A안): 동그라미 아래를 꽉 채우는 모양. 윗선 [top](기준 172) · 위 모서리 둥글기 18 · 노란 유리 84% + 위쪽 윤기.
 * 글자 15 SemiBold, 버튼 높이의 42% 자리, 길면 그 높이의 동그라미 폭에 맞게 11 까지 줄임. icon = "play" · "check" · null
 */
@Composable
fun WEdgeButton(L: WScale, title: String, icon: String?, tag: String, top: Float = 172f, enabled: Boolean = true, red: Boolean = false,
                onClick: () -> Unit) {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val ins = 5f
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            val circle = Path().apply {
                addOval(Rect(L.x(ins).dp.toPx(), L.y(ins).dp.toPx(), L.x(WScale.D - ins).dp.toPx(), L.y(WScale.D - ins).dp.toPx()))
            }
            val cut = Path().apply {
                addRoundRect(RoundRect(Rect(0f, L.y(top).dp.toPx(), size.width, size.height + 40 * density), CornerRadius(L.v(18f).dp.toPx())))
            }
            val shape = Path.combine(PathOperation.Intersect, circle, cut)
            clipPath(shape) {
                val a = if (!enabled) 0.35f else if (pressed) 0.95f else if (red) 0.7f else 0.84f
                drawRect(if (red) hex(0xFF3B30, a) else hex(0xFFDC14, a))
                val t0 = L.y(top).dp.toPx()
                val t1 = L.y(WScale.D - ins).dp.toPx()
                drawRect(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.27f), 0.5f to Color.White.copy(alpha = 0f), startY = t0, endY = t1))
            }
            drawPath(shape, Brush.verticalGradient(0f to Color.White.copy(alpha = 0.47f), 0.3f to Color.White.copy(alpha = 0f),
                startY = L.y(top).dp.toPx(), endY = L.y(WScale.D).dp.toPx()), style = Stroke(1f * density))
        }
        // 누르는 자리
        val cy = top + (WScale.D - ins - top) * 0.42f
        val bw = 2 * (L.half(cy) - 18f)
        Box(Modifier.at(L.dx(WScale.D / 2), L.dy((top + WScale.D) / 2)).size(L.dv(L.rowW(top, top, 0f, 220f)), L.dv(WScale.D - top))
            .clickable(src, indication = null, enabled = enabled, onClick = onClick).then(Modifier.testTag2(tag)))
        // 글자 + 아이콘
        val col = (if (red) Color.White else Color.Black).copy(alpha = if (enabled) 1f else 0.4f)
        val iw = if (icon != null) 19f else 0f
        androidx.compose.foundation.layout.Row(Modifier.at(L.dx(WScale.D / 2), L.dy(cy)), verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Canvas(Modifier.size(L.dv(iw), L.dv(14f))) {
                    val c = Offset(L.v(5f).dp.toPx(), size.height / 2)
                    if (icon == "play") wPlay(c, L.v(11f).dp.toPx(), col) else wCheck(c, L.v(12f).dp.toPx(), col)
                }
            }
            T(title, wf(L, 15f, W600, col), Modifier.size(L.dv(max(40f, bw - iw)), L.dv(20f)), minScale = 11f / 15f)
        }
    }
}

/** 메뉴 · 시작 전 · 끝 화면의 노란 제목 (높이 34, 13 가운데) */
@Composable
fun WMenuTitle(L: WScale, title: String, translate: Boolean = true) {
    WText(title, wf(L, 13f, W600, C.accent), L, WScale.D / 2, 34f, 150f, minScale = 0.75f, translate = translate)
}

/** testTag (시험용 이름) */
fun Modifier.testTag2(tag: String): Modifier = this.testTag(tag)
