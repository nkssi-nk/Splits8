package com.nkssi.splits8.wear

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.PFTGrade
import kotlin.math.max

// 워치 디자인 부품 (아이폰 Shared/Theme.swift 의 워치 쪽 값). 폰 ui/Theme.kt 와 같은 색 · 글꼴.

fun hex(v: Long, alpha: Float = 1f): Color = Color(
    red = ((v shr 16) and 0xFF).toInt() / 255f,
    green = ((v shr 8) and 0xFF).toInt() / 255f,
    blue = (v and 0xFF).toInt() / 255f,
    alpha = alpha,
)

object C {
    val accent = Color(0xFFFFE600)
    val text2 = Color(0xFF8E8E93)
    val text3 = Color(0xFF6E6E73)
    val good = Color(0xFF30D158)
    val bad = Color(0xFFFF453A)
    val hr = Color(0xFFFF453A)
    val d1 = Color(0xFFD1D1D6)
    /** 워치 카드 (#151515, 1px #222) */
    val wCard = Color(0xFF151515)
    val wBorder = Color(0xFF222222)
    val zoneHex = listOf(0x8E8E93L, 0x0A84FFL, 0x30D158L, 0xFF9F0AL, 0xFF453AL)
    fun zone(z: Int): Color = hex(zoneHex[z.coerceIn(1, 5) - 1])
}

/** 아이콘 색 (아이폰 IconTint) */
enum class Tint(val color: Color) {
    White(Color.White), Yellow(C.accent), Mute(C.text2), Dim(C.text3), Black(Color.Black)
}

object F {
    val family = FontFamily(
        Font(R.font.pretendard_regular, FontWeight.Normal),
        Font(R.font.pretendard_medium, FontWeight.Medium),
        Font(R.font.pretendard_semibold, FontWeight.SemiBold),
        Font(R.font.pretendard_bold, FontWeight.Bold),
        Font(R.font.pretendard_extrabold, FontWeight.ExtraBold),
    )

    fun t(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, tracking: Float = 0f): TextStyle =
        TextStyle(
            fontFamily = family, fontWeight = weight, fontSize = size.toFloat().sp, color = color,
            letterSpacing = if (tracking == 0f) TextUnit.Unspecified else tracking.sp,
            lineHeight = (size.toFloat() * 1.2f).sp,
        )

    /** 숫자 (고정폭 숫자 — 시간이 바뀌어도 글자가 흔들리지 않게) */
    fun num(size: Number, weight: FontWeight = FontWeight.SemiBold, color: Color = Color.White, tracking: Float = 0f): TextStyle =
        t(size, weight, color, tracking).copy(fontFeatureSettings = "tnum")
}

val W400 = FontWeight.Normal
val W500 = FontWeight.Medium
val W600 = FontWeight.SemiBold
val W700 = FontWeight.Bold
val W800 = FontWeight.ExtraBold

/** 워치에서만 뜻이 다른 낱말 (폰 표와 열쇠가 같아도 워치 화면엔 이 말) */
private val watchKo = mapOf(
    "SEGMENTS" to "구간",
)

/** 번역 (워치용 덮어쓰기 먼저) */
fun wt(key: String, vararg args: Any?): String =
    if (L10n.lang == "ko" && watchKo.containsKey(key) && args.isEmpty()) watchKo.getValue(key) else L10n.t(key, *args)

/** 글자 (번역 + 한 줄이면 자리가 모자랄 때 작아짐 — 아이폰 minimumScaleFactor) */
@Composable
fun T(
    text: String, style: TextStyle, modifier: Modifier = Modifier, maxLines: Int = 1, minScale: Float = 0.7f,
    align: TextAlign? = null, translate: Boolean = true,
) {
    val s = if (translate) wt(text) else text
    val st = if (align != null) style.copy(textAlign = align) else style
    if (maxLines != 1) {
        BasicText(s, modifier, st, maxLines = maxLines, overflow = TextOverflow.Ellipsis)
        return
    }
    val box = when (align) { TextAlign.Start, TextAlign.Left -> Alignment.CenterStart; TextAlign.End, TextAlign.Right -> Alignment.CenterEnd; else -> Alignment.Center }
    BoxWithConstraints(modifier, contentAlignment = box) {
        val m = rememberTextMeasurer()
        val maxW = constraints.maxWidth
        val k = remember(s, st, maxW) {
            if (maxW == Constraints.Infinity) 1f else {
                var x = 1f
                while (x > minScale && m.measure(s, st.copy(fontSize = st.fontSize * x), softWrap = false, maxLines = 1).size.width > maxW) x -= 0.03f
                max(x, minScale)
            }
        }
        BasicText(s, style = st.copy(fontSize = st.fontSize * k), maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis)
    }
}

/** 스테이션 · 모드 · 메뉴 아이콘 (PNG, 색은 입힘) */
@Composable
fun Icon8(name: String, size: Dp, color: Color = Color.White, modifier: Modifier = Modifier) {
    val id = WIconRes.of(name)
    if (id == null) { Spacer(modifier.size(size)); return }
    Image(painterResource(id), null, modifier.size(size), colorFilter = ColorFilter.tint(color), contentScale = ContentScale.Fit)
}

@Composable
fun Icon8(name: String, size: Dp, tint: Tint, modifier: Modifier = Modifier) = Icon8(name, size, tint.color, modifier)

/** 그린 기호 (되돌리기 ↩ 등, 벡터) */
@Composable
fun Sym(id: Int, size: Dp, color: Color = Color.White, modifier: Modifier = Modifier) {
    Image(painterResource(id), null, modifier.size(size), colorFilter = ColorFilter.tint(color), contentScale = ContentScale.Fit)
}

/** SPLITS8 로고 (높이 = 글자 크기 × 0.83, 원본 1677 × 331) */
@Composable
fun Wordmark(size: Float, modifier: Modifier = Modifier) {
    val h = (size * 0.83f).dp
    Image(painterResource(R.drawable.wordmark_yellow), "SPLITS8", modifier.size(h * 1677f / 331f, h), contentScale = ContentScale.Fit)
}

/** 워치 카드 바탕 */
fun Modifier.wCard(radius: Dp = 14.dp): Modifier {
    val s: Shape = RoundedCornerShape(radius)
    return this.clip(s).background(C.wCard).border(1.dp, C.wBorder, s)
}

/** 누르면 살짝 작아지는 단추 (워치는 물결 없이) */
fun Modifier.press(enabled: Boolean = true, onClick: () -> Unit): Modifier =
    this.clickable(enabled = enabled, interactionSource = MutableInteractionSource(), indication = null, onClick = onClick)

// MARK: 배경 빛

data class Ambient(
    val hex: Long, val alpha: Float, val rx: Float, val ry: Float, val cx: Float, val cy: Float, val linear: Boolean = false,
) {
    companion object {
        /** 테마 색 빛 (기본 노랑) */
        fun y(a: Float, rx: Float, ry: Float, cx: Float, cy: Float, theme: GlowTheme = GlowTheme.Yellow): Ambient =
            Ambient(theme.hex, minOf(1f, (a * theme.gain).toFloat()), rx, ry, cx, cy)
    }
}

/** radial-gradient(RX% RY% at CX% CY%, 색 alpha, transparent 70%) */
@Composable
fun AmbientLayer(a: Ambient, modifier: Modifier = Modifier) {
    if (a.alpha <= 0f) return
    val c = hex(a.hex, a.alpha)
    val clear = hex(a.hex, 0f)
    Canvas(modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        if (a.linear) {
            drawRect(Brush.verticalGradient(0f to c, 0.4f to clear, startY = 0f, endY = h))
            return@Canvas
        }
        val rx = maxOf(1f, a.rx * w)
        val ry = maxOf(1f, a.ry * h)
        val center = Offset(a.cx * w, a.cy * h)
        scale(rx / ry, 1f, pivot = center) {
            drawCircle(Brush.radialGradient(0f to c, 0.7f to clear, 1f to clear, center = center, radius = ry), radius = ry, center = center)
        }
    }
}

/** 항상 켜진 화면(어두움) 상태 — 어두우면 색 · 빛 · 반짝을 끄고 시간만 흐리게 */
val LocalAod = compositionLocalOf { false }

// MARK: PFT 등급 뱃지

@Composable
fun PFTBadge(grade: PFTGrade, width: Dp, height: Dp, fontSize: Float) {
    val shape = RoundedCornerShape(height * 0.32f)
    val dot = (fontSize * 0.92f).dp
    val lead = (height - dot) / 2 + 1.dp
    Row(
        Modifier.size(width, height).clip(shape)
            // Unranked = 회색 테두리만 (바탕 없음) — 아이폰 빌드 26
            .then(if (grade == PFTGrade.Unranked) Modifier.border(1.2.dp, hex(grade.hex1), shape)
                  else Modifier.background(Brush.linearGradient(listOf(hex(grade.hex1), hex(grade.hex2))))),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.padding(start = lead).size(dot).clip(CircleShape).background(Color.Black.copy(alpha = 0.28f))
            .border(maxOf(1.5f, fontSize / 6).dp, Color.White.copy(alpha = 0.55f), CircleShape))
        T(grade.label, F.t(fontSize, W800, hex(grade.inkHex), tracking = fontSize * 0.04f),
            Modifier.weight(1f).padding(start = 2.dp, end = lead * 0.7f), align = TextAlign.Center, translate = false)
    }
}

/** 눌림 효과 없이 살짝 줄어듦 (필요한 곳만) */
fun Modifier.pressScale(down: Boolean): Modifier = this.scale(if (down) 0.97f else 1f)
