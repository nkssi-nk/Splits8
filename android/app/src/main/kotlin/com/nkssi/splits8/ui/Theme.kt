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

/** 1.2.9 라이트 모드 — 폰 앱만 (워치 · 위젯 · 운동 중 화면 · 공유 그림은 늘 다크). 설정(Store.settings)을 따라 바뀜 */
object Appear {
    val light: Boolean get() = com.nkssi.splits8.Store.settings.light
}

object C {
    private val L: Boolean get() = Appear.light

    val bg: Color get() = if (L) Color(0xFFF2F2F4) else Color.Black
    /** 기본 글자 · 아이콘 색 (다크 = 흰색, 라이트 = 검정) */
    val ink: Color get() = if (L) Color.Black else Color.White
    /** 강조색. 라이트는 흰 위젯과 같은 올리브 */
    val accent: Color get() = if (L) Color(0xFF86752A) else Color(0xFFFFE600)
    val onAccent: Color get() = if (L) Color.White else Color.Black
    /** ink 바탕 위 글자 */
    val onInk: Color get() = if (L) Color.White else Color.Black
    val text: Color get() = ink
    val text2: Color get() = if (L) Color(0xFF6E6E72) else Color(0xFF8E8E93)
    val text3: Color get() = if (L) Color(0xFF8E8E93) else Color(0xFF6E6E73)
    val good = Color(0xFF30D158)
    val bad = Color(0xFFFF453A)
    val hr = Color(0xFFFF453A)

    // 폰 카드
    val card: Color get() = if (L) Color.White else Color.White.copy(alpha = 0.06f)
    val cardBorder: Color get() = if (L) Color.Black.copy(alpha = 0.06f) else Color.White.copy(alpha = 0.08f)
    val line: Color get() = if (L) Color.Black.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.08f)
    val segTrack: Color get() = if (L) Color.Black.copy(alpha = 0.06f) else Color.White.copy(alpha = 0.08f)
    val segOn: Color get() = if (L) Color.White else Color(0xFF2C2C2E)
    val control: Color get() = if (L) Color(0xFFE5E5EA) else Color(0xFF2C2C2E)
    val btn1A: Color get() = if (L) Color(0xFFE9E9EC) else Color(0xFF1A1A1A)
    val chev: Color get() = if (L) Color(0xFFC7C7CC) else Color(0xFF48484C)
    val d1: Color get() = if (L) Color(0xFF3A3A3C) else Color(0xFFD1D1D6)
    val aeb: Color get() = if (L) Color(0xFF6E6E72) else Color(0xFFAEAEB2)
    val g3A: Color get() = if (L) Color(0xFFD1D1D6) else Color(0xFF3A3A3C)
    /** 시트 바탕 */
    val sheet: Color get() = if (L) Color(0xFFF2F2F4) else Color(0xFF1C1C1E)

    /** 다크 전용 화면 (운동 중 · 공유 그림 · 위젯) 이 쓰는 고정 색 */
    val yellow = Color(0xFFFFE600)
    val dText2 = Color(0xFF8E8E93)
    val dText3 = Color(0xFF6E6E73)
    val dAeb = Color(0xFFAEAEB2)
    val dBtn1A = Color(0xFF1A1A1A)
    val dCard = Color.White.copy(alpha = 0.06f)
    val dLine = Color.White.copy(alpha = 0.08f)
    val dD1 = Color(0xFFD1D1D6)
    val dSheet = Color(0xFF1C1C1E)

    /** 코드에 직접 적힌 어두운 회색 → 라이트에서는 밝은 회색으로 (밝기를 뒤집음) */
    fun ad(v: Long): Color {
        if (!L) return hex(v)
        val l = maxOf((v shr 16) and 0xFF, (v shr 8) and 0xFF, v and 0xFF).toFloat()
        val o = if (l <= 22f) 242f + l / 22f * 13f else 255f - (l - 22f) / 233f * 255f
        val c = o.coerceIn(0f, 255f) / 255f
        return Color(c, c, c)
    }

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
    fun t(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = C.ink, tracking: Float = 0f): TextStyle =
        TextStyle(
            fontFamily = family, fontWeight = weight, fontSize = size.toFloat().sp, color = color,
            letterSpacing = if (tracking == 0f) TextUnit.Unspecified else tracking.sp,
            lineHeight = (size.toFloat() * 1.2f).sp,
        )

    /** 자간을 em 으로 (아이폰 .em(v, size)) */
    fun te(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = C.ink, em: Float): TextStyle =
        t(size, weight, color).copy(letterSpacing = em.em)

    /** 숫자 (고정폭 숫자 — 시간이 바뀌어도 글자가 흔들리지 않게) */
    fun num(size: Number, weight: FontWeight = FontWeight.SemiBold, color: Color = C.ink, tracking: Float = 0f): TextStyle =
        t(size, weight, color, tracking).copy(fontFeatureSettings = "tnum")
}

/** 다크 전용 화면용 글꼴 (기본 글자색이 늘 흰색) */
object FD {
    fun t(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, tracking: Float = 0f): TextStyle = F.t(size, weight, color, tracking)
    fun te(size: Number, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, em: Float): TextStyle = F.te(size, weight, color, em)
    fun num(size: Number, weight: FontWeight = FontWeight.SemiBold, color: Color = Color.White, tracking: Float = 0f): TextStyle = F.num(size, weight, color, tracking)
}

val W400 = FontWeight.Normal
val W500 = FontWeight.Medium
val W600 = FontWeight.SemiBold
val W700 = FontWeight.Bold
val W800 = FontWeight.ExtraBold
