package com.nkssi.splits8.screens

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
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
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.runMeters
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.hex
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// MARK: - 1.2.7 운동 중 화면 (폰으로 기록 · 워치 같이 보기) — 아이폰 LiveParts.swift 와 같은 모양 (393 × 852 기준)
// 3장 (왼쪽으로 밀기): 운동 · 목표 대비 · 구간 목록. 맨 위(상태 · TOTAL)와 아래 버튼은 세 장 모두 같은 자리.
// 배경 = 워치와 같은 뜻의 색 (스테이션 노랑 · 러닝 파랑 · Roxzone/휴식 회색) + C안 (크게 흐린 덩어리 + 위쪽 밝은 빛).

/** 구간 색 (워치 WTone 과 같은 값) */
enum class LTone {
    Station, Run, Gray;

    val dark: Boolean get() = this == Station
    val ink: Color get() = if (dark) Color.Black else Color.White
    val sub: Color get() = if (dark) Color.Black.copy(alpha = 0.53f) else Color.White.copy(alpha = 0.65f)
    val label: Color get() = if (dark) Color.Black.copy(alpha = 0.59f) else Color.White.copy(alpha = 0.69f)
    val mark: Color get() = if (dark) Color.Black.copy(alpha = 0.92f) else Color.Black.copy(alpha = 0.59f)
    val shadow: Color get() = if (dark) Color(120 / 255f, 80 / 255f, 0f, 0.22f) else Color.Black.copy(alpha = 0.35f)
    val glass: Float get() = if (dark) 0.27f else 0.18f
    val dotOff: Color get() = if (dark) Color.Black.copy(alpha = 0.24f) else Color.Black.copy(alpha = 0.49f)
    val stops: List<Color>
        get() = when (this) {
            Station -> listOf(hex(0xFFE600), hex(0xFFDE00), hex(0xFFD600))
            Run -> listOf(hex(0x1E78FA), hex(0x186AF1), hex(0x125CE8))
            Gray -> listOf(hex(0x54545C), hex(0x494951), hex(0x3E3E46))
        }
    val blob: Color get() = if (this == Station) hex(0xC87800) else Color.Black
    /** 큰 버튼 · 지금 구간 띠 (노랑 위 = 검정 바탕 노랑 글자, 그 밖 = 흰 바탕 파랑 글자) */
    val mainFill: Color get() = if (dark) Color.Black.copy(alpha = 0.69f) else Color.White.copy(alpha = 0.8f)
    val mainInk: Color get() = if (dark) C.accent else hex(0x1E78FA)

    companion object {
        /** 11-21 대표님: 심박 존에 따라 바탕색을 바꾸지 않음 */
        const val ZONE_TINT: Boolean = false

        fun of(s: Seg): LTone = when {
            s.kind == SegKind.Rox -> Gray
            s.icon == "run" -> Run
            else -> Station
        }
    }
}

/** 폰 화면 크기 맞춤 (393 × 852 기준) — 세로 자리는 화면 높이 비율, 크기는 min(가로, 세로) 비율 */
class PL(val w: Float, val h: Float) {
    val s: Float get() = min(w / 393f, h / 852f)
    fun y(v: Float): Float = v * h / 852f
    fun v(v: Float): Float = v * s
    fun dy(v: Float): Dp = y(v).dp
    fun dv(v: Float): Dp = v(v).dp
}

/** 부모(화면 전체) 안에서 가운데를 (x, y) dp 에 둠 */
fun Modifier.atP(x: Dp, y: Dp): Modifier = this.layout { m, c ->
    val p = m.measure(c.copy(minWidth = 0, minHeight = 0))
    val W = if (c.hasBoundedWidth) c.maxWidth else p.width
    val H = if (c.hasBoundedHeight) c.maxHeight else p.height
    layout(W, H) { p.place(x.roundToPx() - p.width / 2, y.roundToPx() - p.height / 2) }
}

/** 글자 그림자 (7 흐리게 · 아래로 2) */
@Composable
fun TextStyle.lShadow(t: LTone): TextStyle {
    val d = LocalDensity.current.density
    return this.copy(shadow = Shadow(t.shadow, Offset(0f, 2f * d), 7f * d))
}

/** 한 줄 글자: 폭 안에서 가운데, 모자라면 작아짐 */
@Composable
fun LText(text: String, style: TextStyle, modifier: Modifier = Modifier, minScale: Float = 0.6f) {
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val m = rememberTextMeasurer()
        val maxW = constraints.maxWidth
        val k = remember(text, style, maxW) {
            if (maxW == Constraints.Infinity) 1f else {
                var s = 1f
                while (s > minScale && m.measure(text, style.copy(fontSize = style.fontSize * s), softWrap = false, maxLines = 1).size.width > maxW) s -= 0.03f
                max(s, minScale)
            }
        }
        BasicText(text, style = style.copy(fontSize = style.fontSize * k, textAlign = TextAlign.Center), maxLines = 1, softWrap = false)
    }
}

// MARK: 장면 값

/** 화면 한 장면에 필요한 값 (엔진 · 워치에서 받은 상태 어느 쪽이든 여기로 바꿔 그림) */
data class LiveFrame8(
    val mode: com.nkssi.splits8.shared.Mode,
    val title: String,
    val seq: List<Seg>,
    val idx: Int,
    val segEl: Int,
    val total: Int,
    val running: Boolean,
    val open: Boolean,
    val segDist: Double?,
    val totalDist: Double?,
    val speed: Double? = null,
    val imperial: Boolean = false,
    val runCard: Boolean = false,
    val runGoalKm: Int = 0,
    val splits: List<Int> = emptyList(),
    /** 심박 (폰만이면 null) */
    val hr: Int? = null,
    val zone: Int = 0,
    val kcal: Int? = null,
) {
    val cur: Seg get() = seq.getOrNull(idx) ?: seq.lastOrNull() ?: Seg("run", "Run", "1KM", SegKind.Run, 0)
    val goalWord: String get() = if (mode == com.nkssi.splits8.shared.Mode.Training) "BEST" else "GOAL"
    val tone: LTone get() = if (runCard) LTone.Run else LTone.of(cur)

    /** 귀퉁이 표시 안 둘째 줄: 러닝 = "0.62 / 1.00 km", 스테이션 = 세부, Roxzone = Transition, 휴식 = to 다음 */
    val detailLine: String
        get() {
            val c = cur
            if (c.icon == "rest") {
                val nx = seq.getOrNull(idx + 1) ?: return ""
                return L10n.t("to %@", nx.name.l10n)
            }
            if (c.kind == SegKind.Rox) return "Transition".l10n
            if (c.kind == SegKind.Run) {
                val sd = segDist ?: return Units.detail(c.detail, imperial)
                val segM = runMeters(c.detail)
                return Units.dist(min(segM, sd), imperial) + " / " + Units.dist(segM, imperial) + " " + Units.distUnit(imperial)
            }
            return if (c.detail.isEmpty() || c.icon == "hiit") "" else Units.detail(c.detail, imperial)
        }

    val runDist: Double get() = totalDist?.takeIf { it > 0 } ?: (idx * 1000.0)

    val runSummary: String
        get() {
            val parts = ArrayList<String>()
            if (runGoalKm > 0) parts.add(if (imperial) L10n.t("Goal %@ mi", Units.dist(runGoalKm * 1000.0, true)) else L10n.t("Goal %@ km", "$runGoalKm"))
            val d = runDist
            if (d >= 200) {
                val avg = Units.pace((total / d * 1000).let { kotlin.math.round(it).toInt() }, imperial)
                if (avg in 1 until 3600) parts.add(L10n.t("Avg %@", Fm.t(avg)))
            }
            return parts.joinToString(" · ")
        }

    /** 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km). 마지막이면 null */
    val nextSeg: Seg?
        get() {
            seq.getOrNull(idx + 1)?.let { return it }
            if (!open) return null
            val n = seq.size + 1
            return if (cur.icon == "hiit") SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n)
        }

    val targetTotal: Int get() = seq.sumOf { it.target }
    val hasGoal: Boolean get() = !open && !runCard && targetTotal > 0 && seq.all { it.target > 0 || it.kind == SegKind.Rox }
    val delta: Int
        get() {
            val done = splits.take(idx).sum()
            val tg = seq.take(idx).sumOf { it.target }
            return done - tg + max(0, segEl - cur.target)
        }
}

// MARK: 배경 (C안)

/** 구간 색 그라데이션 + 크게 흐린 덩어리 + 위쪽 밝은 빛 */
@Composable
fun LiveBackground8(tone: LTone, seed: Int) {
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) { drawRect(Brush.verticalGradient(tone.stops)) }
        Crossfade(seed, animationSpec = tween(600), label = "liveBlobs") { sd ->
            val blobs = remember(sd) {
                val g = LRand((sd + 101).toLong() * 7919 + 17)
                val n = 2 + (g.next() % 3).toInt()
                List(n) { floatArrayOf(0.05f + 0.9f * g.unit(), 0.1f + 0.85f * g.unit(), 0.18f + 0.22f * g.unit(), 0.6f + 0.4f * g.unit()) }
            }
            val a = if (tone == LTone.Station) 0.38f else 0.22f
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val k = min(maxWidth.value / 393f, 1.3f)
                Canvas(Modifier.fillMaxSize().blur((46 * k).dp)) {
                    val w = size.width
                    val h = size.height
                    for (b in blobs) drawCircle(tone.blob.copy(alpha = a * b[3]), w * b[2], Offset(w * b[0], h * b[1]))
                }
            }
        }
        Canvas(Modifier.fillMaxSize()) {
            val c = Offset(size.width / 2, -0.05f * size.height)
            drawRect(Brush.radialGradient(listOf(Color.White.copy(alpha = if (tone == LTone.Station) 0.30f else 0.16f), Color.White.copy(alpha = 0f)),
                c, 360.dp.toPx()))
        }
    }
}

/** 같은 seed → 같은 수 (SplitMix64) */
class LRand(seed: Long) {
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

// MARK: 그린 것 (귀퉁이 · 아이콘 · 유리)

/** 귀퉁이 표시 블록 (148 ~ 340, 좌우 24) */
@Composable
fun LiveBrackets8(L: PL, tone: LTone, top: Float = 148f, bottom: Float = 340f) {
    Canvas(Modifier.fillMaxSize()) {
        val x0 = 24.dp.toPx()
        val x1 = size.width - 24.dp.toPx()
        val y0 = L.y(top).dp.toPx()
        val y1 = L.y(bottom).dp.toPx()
        val a = L.v(18f).dp.toPx()
        val p = Path()
        for ((x, sx) in listOf(x0 to 1f, x1 to -1f)) for ((y, sy) in listOf(y0 to 1f, y1 to -1f)) {
            p.moveTo(x + sx * a, y); p.lineTo(x, y); p.lineTo(x, y + sy * a)
        }
        drawPath(p, tone.mark, style = Stroke(L.v(4f).dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

fun DrawScope.lUndo(center: Offset, size: Float, color: Color) {
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

fun DrawScope.lArrow(center: Offset, w: Float, h: Float, color: Color) {
    val l = center.x - w / 2
    val t = center.y - h / 2
    val bar = h * 0.27f
    drawRoundRect(color, Offset(l, center.y - bar / 2), Size(w * 0.62f, bar), CornerRadius(bar * 0.25f))
    val p = Path().apply { moveTo(l + w * 0.48f, t); lineTo(l + w, center.y); lineTo(l + w * 0.48f, t + h); close() }
    drawPath(p, color)
}

fun DrawScope.lPause(center: Offset, size: Float, color: Color, paused: Boolean) {
    if (paused) {
        val p = Path().apply {
            moveTo(center.x - size * 0.34f, center.y - size * 0.45f); lineTo(center.x + size * 0.46f, center.y)
            lineTo(center.x - size * 0.34f, center.y + size * 0.45f); close()
        }
        drawPath(p, color); drawPath(p, color, style = Stroke(size * 0.08f, join = StrokeJoin.Round)); return
    }
    val bw = size * 0.24f
    val gap = size * 0.22f
    drawRoundRect(color, Offset(center.x - gap / 2 - bw, center.y - size / 2), Size(bw, size), CornerRadius(size * 0.08f))
    drawRoundRect(color, Offset(center.x + gap / 2, center.y - size / 2), Size(bw, size), CornerRadius(size * 0.08f))
}

fun DrawScope.lSkip(center: Offset, size: Float, color: Color) {
    val s = size / 2
    val p = Path().apply { moveTo(center.x - s * 0.8f, center.y - s * 0.8f); lineTo(center.x + s * 0.4f, center.y); lineTo(center.x - s * 0.8f, center.y + s * 0.8f); close() }
    drawPath(p, color)
    drawRoundRect(color, Offset(center.x + s * 0.5f, center.y - s * 0.8f), Size(s * 0.38f, s * 1.6f), CornerRadius(s * 0.12f))
}

fun DrawScope.lEndMark(center: Offset, size: Float, color: Color) {
    val r = size / 2
    val circle = Path().apply { addOval(Rect(center, r)) }
    val a = r * 0.45f
    val wdt = r * 0.29f
    fun bar(deg: Float): Path {
        val p = Path().apply { addRoundRect(androidx.compose.ui.geometry.RoundRect(Rect(center.x - a * 1.25f, center.y - wdt / 2, center.x + a * 1.25f, center.y + wdt / 2), CornerRadius(wdt / 2))) }
        val m = androidx.compose.ui.graphics.Matrix(); m.translate(center.x, center.y); m.rotateZ(deg); m.translate(-center.x, -center.y)
        p.transform(m); return p
    }
    drawPath(Path.combine(PathOperation.Difference, circle, Path.combine(PathOperation.Union, bar(45f), bar(-45f))), color)
}

/** 유리 (위쪽만 옅은 가장자리 빛 + 아래 그림자) */
fun DrawScope.lGlass(sz: Size, radius: Float, fill: Color, rim: Float) {
    val cr = CornerRadius(radius)
    drawRoundRect(Color.Black.copy(alpha = 0.18f), Offset(0f, 3f * density), sz, cr)
    drawRoundRect(fill, Offset.Zero, sz, cr)
    drawRoundRect(Brush.verticalGradient(0f to Color.White.copy(alpha = rim), 0.45f to Color.White.copy(alpha = 0f), startY = 0f, endY = sz.height),
        Offset(0.5f, 0.5f), Size(sz.width - 1f, sz.height - 1f), CornerRadius(max(0f, radius - 0.5f)), style = Stroke(1f * density))
}

/** 유리 알약 버튼 (누르면 살짝 커지면서 밝아짐) */
@Composable
fun GlassPill(modifier: Modifier, fill: Color, rim: Float, enabled: Boolean, tag: String, onClick: () -> Unit, content: @Composable () -> Unit) {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val sc by animateFloatAsState(if (pressed) 1.06f else 1f, spring(dampingRatio = 0.6f, stiffness = 500f), label = "glassPress")
    Box(modifier.scale(sc).drawBehind { lGlass(size, size.height / 2, if (pressed) fill.copy(alpha = min(1f, fill.alpha + 0.12f)) else fill, rim) }
        .clickable(src, indication = null, enabled = enabled, onClick = onClick).testTag(tag), contentAlignment = Alignment.Center) { content() }
}

// MARK: 맨 위: "Race · ● Watch · 168 BPM" → TOTAL 23:41

@Composable
fun LiveTop8(f: LiveFrame8, L: PL, status: String, live: Boolean, tagPrefix: String) {
    val t = f.tone
    Box(Modifier.fillMaxSize()) {
        Row(Modifier.atP((L.w / 2).dp, L.dy(70f)).widthIn(max = (L.w - 48).dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val st = F.t(L.v(13f), W600, t.label).lShadow(t)
            BasicText((if (f.mode == com.nkssi.splits8.shared.Mode.Training) f.title else f.mode.title).l10n, style = st, maxLines = 1)
            BasicText("·", style = st)
            Canvas(Modifier.size(7.dp)) { drawCircle(if (live) hex(0x34C759) else t.sub) }
            BasicText(status.l10n, Modifier.testTag("$tagPrefix.status"), style = st, maxLines = 1)
        }
        Row(Modifier.atP((L.w / 2).dp, L.dy(104f)), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BasicText((if (f.runCard) "TIME" else "TOTAL").l10n, style = F.t(L.v(13f), W700, t.label, tracking = 1f).lShadow(t))
            BasicText(Fm.t(f.total), Modifier.testTag("$tagPrefix.total"), style = F.num(L.v(30f), W600, if (f.running) t.ink else t.sub).lShadow(t))
        }
    }
}

// MARK: 칸 · 점 · 큰 숫자

/** 한 칸: 이름표 14 (줄 가운데 −20) · 값 (+20) */
@Composable
fun RowScopeCell(L: PL, label: String, value: String, tone: LTone, strong: Boolean = false, size: Float = 40f, tag: String? = null, modifier: Modifier) {
    Box(modifier.height(L.dy(80f)), contentAlignment = Alignment.Center) {
        LText(label, F.t(L.v(14f), W700, if (strong) tone.ink else tone.label, tracking = 0.8f).lShadow(tone),
            Modifier.fillMaxWidth().padding(horizontal = 4.dp).offsetY(-L.y(20f)))
        LText(value, F.num(L.v(size), W600, tone.ink).lShadow(tone),
            Modifier.fillMaxWidth().padding(horizontal = 4.dp).offsetY(L.y(20f)).let { if (tag != null) it.testTag(tag) else it }, minScale = 0.5f)
    }
}

/** 세로로 옮김 (dp) */
fun Modifier.offsetY(dy: Float): Modifier = this.layout { m, c ->
    val p = m.measure(c)
    layout(p.width, p.height) { p.place(0, (dy * density).toInt()) }
}

/** 칸 줄 (화면 폭 − 48, 높이 y 가운데) */
@Composable
fun LiveCells(L: PL, y: Float, cells: List<Cell8>, tone: LTone, tagPrefix: String) {
    Row(Modifier.atP((L.w / 2).dp, L.dy(y)).width((L.w - 48).dp)) {
        for (c in cells) RowScopeCell(L, c.label, c.value, tone, c.strong, tag = c.id?.let { "$tagPrefix.$it" }, modifier = Modifier.weight(1f))
    }
}

data class Cell8(val label: String, val value: String, val strong: Boolean = false, val id: String? = null)

/** 진행 점: 지금 막대 24 · 점 6.8 · 간격 13 (10개 이하 18) */
@Composable
fun LiveDots8(L: PL, y: Float, total: Int, current: Int, tone: LTone, currentDim: Boolean = false) {
    if (total <= 0) return
    Canvas(Modifier.fillMaxSize().testTag("live.dots")) {
        val d = L.v(6.8f).dp.toPx()
        val base = if (total <= 10) 18f else 13f
        val fit = if (total > 1) (size.width - 80.dp.toPx()) / (total - 1) else L.v(base).dp.toPx()
        val gap = min(L.v(base).dp.toPx(), fit)
        val cw = L.v(24f).dp.toPx()
        val totW = gap * (total - 1) + cw - d
        var x = size.width / 2 - totW / 2
        val yy = L.y(y).dp.toPx()
        for (i in 0 until total) {
            if (i == current) {
                drawRoundRect(tone.ink.copy(alpha = if (currentDim) 0.5f else 1f), Offset(x - d / 2, yy - d / 2), Size(cw, d), CornerRadius(d / 2))
                x += cw - d + gap
            } else {
                drawCircle(if (i < current) tone.ink else tone.dotOff, d / 2, Offset(x, yy))
                x += gap
            }
        }
    }
}

/** 넘김 점 (598) */
@Composable
fun LivePageDots8(L: PL, count: Int, page: Int, tone: LTone) {
    Row(Modifier.atP((L.w / 2).dp, L.dy(598f)), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        repeat(count) { i -> Canvas(Modifier.size(7.dp)) { drawCircle(if (i == page) tone.ink else tone.dotOff) } }
    }
}

/** 큰 숫자 블록 (이름표 17 · 숫자 84 · 단위 15 — 148~340 가운데) */
@Composable
fun LiveBigBlock8(L: PL, label: String, main: String, unit: String = "", tone: LTone, labelColor: Color? = null, tag: String? = null) {
    val hasUnit = unit.isNotEmpty()
    Box(Modifier.fillMaxSize()) {
        LText(label, F.t(L.v(17f), W700, labelColor ?: tone.sub, tracking = 1f).lShadow(tone),
            Modifier.atP((L.w / 2).dp, L.dy(if (hasUnit) 192.9f else 206.2f)).width((L.w - 80).dp), minScale = 0.7f)
        LText(main, F.num(L.v(84f), W700, tone.ink).lShadow(tone),
            Modifier.atP((L.w / 2).dp, L.dy(if (hasUnit) 244.7f else 258f)).width((L.w - 80).dp).let { if (tag != null) it.testTag(tag) else it }, minScale = 0.45f)
        if (hasUnit) LText(unit, F.t(L.v(15f), W700, tone.label, tracking = 1f).lShadow(tone),
            Modifier.atP((L.w / 2).dp, L.dy(295.9f)).width((L.w - 80).dp), minScale = 0.7f)
    }
}

/** "Next" 26 (반투명) + 다음 이름 Bold 26 (534) */
@Composable
fun LiveNext8(L: PL, name: String, tone: LTone, tag: String) {
    Row(Modifier.atP((L.w / 2).dp, L.dy(534f)).widthIn(max = (L.w - 48).dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        BasicText("Next".l10n, style = F.t(L.v(26f), W600, tone.sub).lShadow(tone), maxLines = 1)
        LText(name, F.t(L.v(26f), W700, tone.ink).lShadow(tone), Modifier.widthIn(max = (L.w - 130).dp).testTag(tag))
    }
}

// MARK: 1장: 운동 (구간 · 러닝 카드)

@Composable
fun LiveMain8(f: LiveFrame8, L: PL, tagPrefix: String) {
    val t = f.tone
    Box(Modifier.fillMaxSize()) {
        LiveBrackets8(L, t)
        if (f.runCard) {
            LiveBigBlock8(L, f.title.ifEmpty { "Run" }.l10n, Units.dist(f.runDist, f.imperial), if (f.imperial) "MI" else "KM", t, tag = "$tagPrefix.dist")
        } else {
            val one = f.detailLine.isEmpty()
            LText(f.cur.name.l10n, F.t(L.v(52f), W700, t.ink).lShadow(t),
                Modifier.atP((L.w / 2).dp, L.dy(if (one) 244f else 227.2f)).width(min(L.w - 80, L.v(300f)).dp).testTag("$tagPrefix.name"), minScale = 30f / 52f)
            if (!one) LText(f.detailLine, F.t(L.v(22f), W600, t.sub).lShadow(t),
                Modifier.atP((L.w / 2).dp, L.dy(271.4f)).width((L.w - 80).dp))
        }
        LiveCells(L, 398f, cellList(f), t, tagPrefix)
        when {
            f.runCard -> {
                val frac: Float? = if (f.runGoalKm > 0) min(1.0, f.runDist / (f.runGoalKm * 1000.0)).toFloat() else null
                Canvas(Modifier.fillMaxSize()) {
                    val w = size.width - 80.dp.toPx()
                    val h = L.v(7f).dp.toPx()
                    val x0 = 40.dp.toPx()
                    val y = L.y(472f).dp.toPx()
                    drawRoundRect(Color.Black.copy(alpha = 0.3f), Offset(x0, y - h / 2), Size(w, h), CornerRadius(h / 2))
                    if (frac != null) drawRoundRect(Color.White, Offset(x0, y - h / 2), Size(max(h, w * frac), h), CornerRadius(h / 2))
                }
                LText(f.runSummary, F.num(L.v(15f), W600, t.sub).lShadow(t), Modifier.atP((L.w / 2).dp, L.dy(494f)).width((L.w - 48).dp))
            }
            !f.open -> {
                val units = f.seq.indices.filter { f.seq[it].kind != SegKind.Rox || f.seq[it].icon == "rest" }
                val before = units.count { it < f.idx }
                val onRox = f.cur.kind == SegKind.Rox && f.cur.icon != "rest"
                LiveDots8(L, 482f, units.size, before, t, onRox)
            }
            f.cur.icon == "hiit" -> LText(L10n.t("%lld rounds done", f.idx), F.t(L.v(15f), W700, t.sub),
                Modifier.atP((L.w / 2).dp, L.dy(482f)).width((L.w - 48).dp))
        }
        if (!f.runCard) LiveNext8(L, f.nextSeg?.name?.l10n ?: "Finish".l10n, t, "live.nextName")
    }
}

private fun cellList(f: LiveFrame8): List<Cell8> {
    val c = f.cur
    val out = ArrayList<Cell8>()
    val paceLabel = (if (f.imperial) "PACE /MI" else "PACE").l10n
    if (f.runCard) {
        out.add(Cell8(paceLabel, LivePace.text(f.total, f.runDist, f.imperial, f.speed)))
    } else {
        val over = if (c.target > 0 && c.kind != SegKind.Rox) f.segEl - c.target else 0
        if (over > 0) out.add(Cell8("OVER".l10n + " +" + Fm.t(over), Fm.t(f.segEl), strong = true, id = "seg"))
        else out.add(Cell8((if (c.icon == "hiit") "ROUND" else "SPLIT").l10n, Fm.t(f.segEl), id = "seg"))
        if (c.kind == SegKind.Run) out.add(Cell8(paceLabel, LivePace.text(f.segEl, f.segDist, f.imperial, f.speed)))
        else if (c.target > 0 && c.icon != "rest") out.add(Cell8(f.goalWord.l10n, Fm.t(c.target), id = "goal"))
    }
    f.hr?.let { hr -> out.add(Cell8("♥ " + "BPM".l10n, if (hr > 0) "$hr" else "--")) }
    return out
}

// MARK: 2장: 목표 대비

@Composable
fun LiveGoalPage8(f: LiveFrame8, L: PL, maxHR: Int? = null, avgHR: Int? = null) {
    val t = f.tone
    val d = f.delta
    val vsBest = f.mode == com.nkssi.splits8.shared.Mode.Training || f.mode == com.nkssi.splits8.shared.Mode.Pft
    Box(Modifier.fillMaxSize().testTag("live.goalPage")) {
        LiveBrackets8(L, t)
        if (f.hasGoal) {
            LiveBigBlock8(L, (if (vsBest) "VS BEST" else "VS GOAL").l10n, Fm.d(d), (if (d < 0) "AHEAD" else if (d > 0) "BEHIND" else "ON PACE").l10n, t)
            LiveCells(L, 398f, listOf(Cell8("FINISH".l10n, Fm.t(f.targetTotal + d)), Cell8((if (vsBest) "BEST" else "GOAL").l10n, Fm.t(f.targetTotal))), t, "live")
        } else {
            LiveBigBlock8(L, (if (f.runCard) "TIME" else "TOTAL").l10n, Fm.t(f.total), "", t)
        }
        if (f.hr != null) {
            LiveCells(L, if (f.hasGoal) 498f else 398f, listOf(
                Cell8("MAX HR".l10n, if ((maxHR ?: 0) > 0) "${maxHR ?: 0}" else "--"),
                Cell8("AVG BPM".l10n, if ((avgHR ?: 0) > 0) "${avgHR ?: 0}" else "--"),
                Cell8("KCAL".l10n, f.kcal?.toString() ?: "--"),
            ), t, "live")
        }
    }
}

// MARK: 아래 버튼 (세 장 모두 같은 자리)

/** 큰 Next (626 ~ 700) + 알약 End · Undo · Skip · Pause (714 ~ 768) */
@Composable
fun LiveButtons8(
    L: PL, tone: LTone, tagPrefix: String, nextTitle: String?, nextOn: Boolean = true, showUndo: Boolean = true, undoOn: Boolean = false,
    showSkip: Boolean = false, skipOn: Boolean = false, running: Boolean = true, enabled: Boolean = true,
    onNext: () -> Unit, onEnd: () -> Unit, onUndo: () -> Unit, onSkip: () -> Unit = {}, onPause: () -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        if (nextTitle != null) {
            GlassPill(Modifier.atP((L.w / 2).dp, L.dy(663f)).width((L.w - 40).dp).height(L.dy(74f)), tone.mainFill, 0.22f, nextOn && enabled,
                "$tagPrefix.next", onNext) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    val ink = tone.mainInk.copy(alpha = if (nextOn) 1f else 0.45f)
                    Canvas(Modifier.size(L.dv(26f), L.dv(22f))) { lArrow(center, size.width, size.height, ink) }
                    LText(nextTitle.l10n, F.t(L.v(24f), W700, ink), Modifier.widthIn(max = (L.w - 140).dp))
                }
            }
        }
        Row(Modifier.atP((L.w / 2).dp, L.dy(741f)).width((L.w - 40).dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            val m = Modifier.weight(1f).height(L.dy(54f))
            PillBtn(L, m, "End", hex(0xFF3B30, 0.59f), 0.22f, Color.White, enabled, "$tagPrefix.end", onEnd) { c -> lEndMark(center, L.v(15f).dp.toPx(), c) }
            if (showUndo) PillBtn(L, m, "Undo", Color.White.copy(alpha = tone.glass), 0.59f, tone.ink, undoOn && enabled, "$tagPrefix.undo", onUndo) { c ->
                lUndo(center, L.v(15f).dp.toPx(), c)
            }
            if (showSkip) PillBtn(L, m, "Skip", Color.White.copy(alpha = tone.glass), 0.59f, tone.ink, skipOn && enabled, "$tagPrefix.skip", onSkip) { c ->
                lSkip(center, L.v(12f).dp.toPx(), c)
            }
            PillBtn(L, m, if (running) "Pause" else "Resume", Color.White.copy(alpha = tone.glass), 0.59f, tone.ink, enabled, "$tagPrefix.pause", onPause) { c ->
                lPause(center, L.v(12f).dp.toPx(), c, !running)
            }
        }
    }
}

@Composable
private fun PillBtn(L: PL, modifier: Modifier, t: String, fill: Color, rim: Float, fg: Color, on: Boolean, tag: String, onClick: () -> Unit,
                    icon: DrawScope.(Color) -> Unit) {
    GlassPill(modifier, fill, rim, on, tag, onClick) {
        val c = fg.copy(alpha = if (on) 1f else 0.4f)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Canvas(Modifier.size(L.dv(15f))) { icon(c) }
            LText(t.l10n, F.t(L.v(15f), W600, c), minScale = 0.7f)
        }
    }
}

// MARK: 3장: 구간 목록

/** 끝난 구간: 내 시간 + 기준과 차이. 지금 구간: 유리 띠 + 흐르는 시간. 남은 구간: 기준 시간 흐리게 */
@Composable
fun LiveSegmentList8(L: PL, tone: LTone, seq: List<Seg>, idx: Int, splits: List<Int>, skipped: Set<Int>, segEl: Int, word: String) {
    val state = rememberLazyListState()
    LaunchedEffect(idx) { if (seq.isNotEmpty()) state.animateScrollToItem(max(0, min(idx, seq.size - 1) - 3)) }
    val good = if (tone.dark) hex(0x007832) else hex(0x5BE584)
    val bad = if (tone.dark) hex(0xBE190F) else hex(0xFF8A80)
    Box(Modifier.fillMaxSize().testTag("phone.segments")) {
        Column(Modifier.fillMaxWidth().padding(top = L.dy(134f)).height(L.dy(574f - 134f))) {
            Row(Modifier.fillMaxWidth().height(L.dy(24f)).padding(horizontal = 30.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                BasicText("SEGMENTS".l10n, style = F.t(L.v(14f), W700, tone.ink, tracking = 1f))
                BasicText("${min(idx + 1, seq.size)}/${seq.size}", Modifier.weight(1f), style = F.num(L.v(14f), W600, tone.sub))
                BasicText(word.l10n, style = F.t(L.v(13f), W700, tone.label, tracking = 0.8f))
            }
            LazyColumn(Modifier.fillMaxWidth().weight(1f), state = state, contentPadding = PaddingValues(horizontal = 20.dp)) {
                items(seq.size) { i ->
                    val s = seq[i]
                    val d = i < idx
                    val c = i == idx
                    val sk = d && i in skipped
                    val my = splits.getOrElse(i) { 0 }
                    val diff: Int? = if (d && !sk && s.target > 0) my - s.target else null
                    val time = when {
                        sk -> "Skipped".l10n
                        d -> Fm.t(my)
                        c -> Fm.t(segEl)
                        else -> if (s.target > 0) Fm.t(s.target) else "–"
                    }
                    val nameColor = if (c) tone.mainInk else if (d) tone.sub else tone.ink
                    val timeColor = if (c) tone.mainInk else if (d) tone.ink else tone.sub
                    Row(Modifier.fillMaxWidth().height(L.dy(26f)).let { if (c) it.drawBehind { lGlass(size, size.height / 2, tone.mainFill, 0.22f) } else it }
                        .padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        BasicText(s.name.l10n, Modifier.weight(1f), style = F.t(L.v(16f), if (c) W700 else W600, nameColor), maxLines = 1)
                        if (diff != null) BasicText(Fm.d(diff), style = F.num(L.v(14f), W600, if (diff <= 0) good else bad))
                        BasicText(time, Modifier.widthIn(min = 58.dp), style = (if (sk) F.t(L.v(14f), FontWeight.Medium, tone.sub) else F.num(L.v(16f), W600, timeColor))
                            .copy(textAlign = TextAlign.End), maxLines = 1)
                    }
                }
            }
        }
    }
}
