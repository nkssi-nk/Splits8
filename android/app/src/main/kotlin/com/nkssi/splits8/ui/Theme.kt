package com.nkssi.splits8.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.R

// 아이폰 Shared/Theme.swift 의 enum C · enum F 와 같은 값

/** 0xRRGGBB → 색 */
fun hex(v: Long, alpha: Float = 1f): Color = Color(
    red = ((v shr 16) and 0xFF).toInt() / 255f,
    green = ((v shr 8) and 0xFF).toInt() / 255f,
    blue = (v and 0xFF).toInt() / 255f,
    alpha = alpha,
)

object C {
    val bg = Color.Black
    val accent = Color(0xFFFFE600)
    val onAccent = Color.Black
    val text = Color.White
    val text2 = Color(0xFF8E8E93)
    val text3 = Color(0xFF6E6E73)
    val good = Color(0xFF30D158)
    val bad = Color(0xFFFF453A)
    val hr = Color(0xFFFF453A)

    // 폰 카드
    val card = Color.White.copy(alpha = 0.06f)
    val cardBorder = Color.White.copy(alpha = 0.08f)
    val line = Color.White.copy(alpha = 0.08f)
    val segTrack = Color.White.copy(alpha = 0.08f)
    val segOn = Color(0xFF2C2C2E)
    val control = Color(0xFF2C2C2E)
    val btn1A = Color(0xFF1A1A1A)
    val chev = Color(0xFF48484C)
    val d1 = Color(0xFFD1D1D6)
    val aeb = Color(0xFFAEAEB2)
    val g3A = Color(0xFF3A3A3C)
    /** 시트 바탕 */
    val sheet = Color(0xFF1C1C1E)

    // 워치 카드
    val wCard = Color(0xFF151515)
    val wBorder = Color(0xFF222222)

    val zones = listOf(Color(0xFF8E8E93), Color(0xFF0A84FF), Color(0xFF30D158), Color(0xFFFF9F0A), Color(0xFFFF453A))
    fun zone(z: Int): Color = zones[z.coerceIn(1, 5) - 1]
}

/** 글꼴: Pretendard (SF Pro 대신). 크기 단계는 아이폰과 같음 */
object F {
    val family = FontFamily(
        Font(R.font.pretendard_regular, FontWeight.Normal),
        Font(R.font.pretendard_medium, FontWeight.Medium),
        Font(R.font.pretendard_semibold, FontWeight.SemiBold),
        Font(R.font.pretendard_bold, FontWeight.Bold),
        Font(R.font.pretendard_extrabold, FontWeight.ExtraBold),
    )

    const val largeTitle = 34
    const val title1 = 28
    const val title2 = 22
    const val title3 = 20
    const val body = 17
    const val callout = 16
    const val sub = 15
    const val foot = 13
    const val cap1 = 12
    const val cap2 = 11

    /** 글자 (아이폰 F.t). tracking = 자간(pt, 아이폰 .tracking 과 같은 값) */
    fun t(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, tracking: Float = 0f): TextStyle =
        TextStyle(
            fontFamily = family, fontWeight = weight, fontSize = size.toFloat().sp, color = color,
            letterSpacing = if (tracking == 0f) TextUnit.Unspecified else tracking.sp,
            lineHeight = (size.toFloat() * 1.2f).sp,
        )

    /** 자간을 em 으로 (아이폰 .em(v, size)) */
    fun te(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, em: Float): TextStyle =
        t(size, weight, color).copy(letterSpacing = em.em)

    /** 숫자 (고정폭 숫자 — 시간이 바뀌어도 글자가 흔들리지 않게) */
    fun num(size: Number, weight: FontWeight = FontWeight.SemiBold, color: Color = Color.White, tracking: Float = 0f): TextStyle =
        t(size, weight, color, tracking).copy(fontFeatureSettings = "tnum")
}

val W400 = FontWeight.Normal
val W500 = FontWeight.Medium
val W600 = FontWeight.SemiBold
val W700 = FontWeight.Bold
val W800 = FontWeight.ExtraBold
