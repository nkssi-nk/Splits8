package com.nkssi.splits8.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.nkssi.splits8.R

// 아이폰 Shared/Theme.swift 의 enum C 와 같은 값

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

    val card = Color.White.copy(alpha = 0.06f)
    val cardBorder = Color.White.copy(alpha = 0.08f)
    val line = Color.White.copy(alpha = 0.08f)
    val segTrack = Color.White.copy(alpha = 0.08f)
    val segOn = Color(0xFF2C2C2E)
    val control = Color(0xFF2C2C2E)
    val btn1A = Color(0xFF1A1A1A)
    val chev = Color(0xFF48484C)

    val zones = listOf(
        Color(0xFF8E8E93), Color(0xFF0A84FF), Color(0xFF30D158),
        Color(0xFFFF9F0A), Color(0xFFFF453A),
    )
    fun zone(z: Int): Color = zones[z.coerceIn(1, 5) - 1]
}

/** 글꼴: Pretendard (SF Pro 대신). 크기 단계는 아이폰과 같음 */
object F {
    val family = FontFamily(
        Font(R.font.pretendard_regular, FontWeight.Normal),
        Font(R.font.pretendard_medium, FontWeight.Medium),
        Font(R.font.pretendard_semibold, FontWeight.SemiBold),
        Font(R.font.pretendard_bold, FontWeight.Bold),
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
}
