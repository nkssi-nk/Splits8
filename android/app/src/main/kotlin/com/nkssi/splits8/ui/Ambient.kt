package com.nkssi.splits8.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.scale
import com.nkssi.splits8.shared.GlowTheme
import kotlin.random.Random

/**
 * 화면 뒤 배경 빛 (아이폰 Ambient · CSS radial-gradient 재현).
 * radial-gradient(RX% RY% at CX% CY%, 색 alpha, transparent 70%)
 */
data class Ambient(
    val hex: Long,
    val alpha: Float,
    /** 반지름 (화면 너비 · 높이 대비) */
    val rx: Float, val ry: Float,
    /** 가운데 (0~1) */
    val cx: Float, val cy: Float,
    /** linear-gradient(180deg, 색, transparent 40%) */
    val linear: Boolean = false,
) {
    companion object {
        val none = Ambient(0, 0f, 1f, 1f, 0.5f, 0.5f)

        /** 테마 색 빛 (기본 노랑). 파랑 · 보라는 같은 값이면 어둡게 보여서 gain 으로 보정 */
        fun y(a: Float, rx: Float, ry: Float, cx: Float, cy: Float, theme: GlowTheme): Ambient =
            Ambient(theme.hex, minOf(1f, (a * theme.gain).toFloat()), rx, ry, cx, cy)
    }
}

/** 빛 자리를 앱을 켤 때마다 조금씩 다르게 (화면 사진 찍을 때는 늘 같은 자리) */
object GlowDrift {
    var fixed = false
    private val rnd = Random(System.nanoTime())
    private val rdx = rnd.nextDouble(-0.22, 0.22).toFloat()
    private val rdy = rnd.nextDouble(-0.03, 0.07).toFloat()
    private val rs = rnd.nextDouble(0.94, 1.10).toFloat()
    val dx get() = if (fixed) 0f else rdx
    val dy get() = if (fixed) 0f else rdy
    val scale get() = if (fixed) 1f else rs
}

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
        // 원을 그린 뒤 가로로 rx/ry 만큼 늘려 타원 빛
        scale(rx / ry, 1f, pivot = center) {
            drawCircle(Brush.radialGradient(0f to c, 0.7f to clear, 1f to clear, center = center, radius = ry), radius = ry, center = center)
        }
    }
}
