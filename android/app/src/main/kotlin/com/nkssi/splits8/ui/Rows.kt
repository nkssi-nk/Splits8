package com.nkssi.splits8.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.PFTGrade
import com.nkssi.splits8.shared.RecordFlag
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// 아이폰 TrainingViews.swift 의 HistoryRow · PBPill · FlagPill, Components.swift 의 BorderLight · GradeBorder

/** ★ PB 알약 (높이 20, 모서리 6, 노랑 0.14 바탕, 노란 글자 11/600). 빌드 27: 러닝 기록은 거리까지 ("5K PB") */
@Composable
fun PBPill(label: String? = null) {
    Row(
        Modifier.height(20.dp).clip(RoundedCornerShape(6.dp)).background(Color(0x24FFE600)).padding(horizontal = 7.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        T("★", F.t(9, W600, C.accent), translate = false)
        T(label ?: "PB", F.t(11, W600, C.accent, tracking = 0.22f), translate = false)
    }
}

/** 미완료 / 확인 필요 회색 꼬리표 */
@Composable
fun FlagPill(flag: RecordFlag) {
    androidx.compose.foundation.layout.Box(
        Modifier.height(20.dp).clip(RoundedCornerShape(6.dp)).background(Color.White.copy(alpha = 0.10f)).padding(horizontal = 7.dp),
        contentAlignment = Alignment.Center,
    ) { T(flag.label, F.t(11, W600, C.text2, tracking = 0.22f), maxLines = 1) }
}

/**
 * 기록 줄 (제목 17/500 + 뱃지들, 아래 날짜 13 회색 · 오른쪽 시간 20 + 차이 13).
 * partner = 더블 파트너 닉네임 (있으면 아래 줄 끝에 " · with @닉네임")
 */
@Composable
fun HistoryRow(
    title: String, sub: String, time: String, modifier: Modifier = Modifier,
    subColor: Color = C.text2, delta: String? = null, deltaColor: Color = C.good, last: Boolean = false,
    pb: Boolean = false, flag: RecordFlag? = null, grade: PFTGrade? = null, partner: String? = null,
    /** 빌드 27: PB 알약 글자 (러닝 기록 "5K PB"). null = "PB" */
    pbLabel: String? = null,
    onDelete: (() -> Unit)? = null, onClick: () -> Unit,
) {
    if (onDelete != null) {
        // 왼쪽으로 밀면 삭제 (아이폰 HistoryRow 의 onDelete)
        SwipeDelete("Delete this record?", modifier.fillMaxWidth().rowLine(!last), onTap = onClick, onDelete = onDelete) {
            HistoryRowBody(title, sub, time, Modifier, subColor, delta, deltaColor, pb, flag, grade, partner, null, pbLabel)
        }
    } else {
        HistoryRowBody(title, sub, time, modifier.rowLine(!last), subColor, delta, deltaColor, pb, flag, grade, partner, onClick, pbLabel)
    }
}

@Composable
private fun HistoryRowBody(
    title: String, sub: String, time: String, modifier: Modifier, subColor: Color, delta: String?, deltaColor: Color,
    pb: Boolean, flag: RecordFlag?, grade: PFTGrade?, partner: String?, onClick: (() -> Unit)?, pbLabel: String? = null,
) {
    val nick = partner?.trim().orEmpty()
    val subText = if (nick.isEmpty()) sub else sub + " · " + L10n.t("with @%@", nick)
    Row(
        modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.001f))
            .let { if (onClick != null) it.tap(onClick = onClick) else it }.padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                T(title, F.t(17, W500), Modifier.weight(1f, fill = false), maxLines = 1, translate = false)
                if (grade != null) PFTBadge(grade)
                if (pb) PBPill(pbLabel)
                if (flag != null) FlagPill(flag)
            }
            T(subText, F.num(13, W400, subColor), maxLines = 1, translate = false)
        }
        Column(horizontalAlignment = Alignment.End) {
            T(time, F.num(20, tracking = -0.4f), maxLines = 1, translate = false)
            if (delta != null) T(delta, F.num(13, color = deltaColor), maxLines = 1, translate = false)
        }
    }
}

// MARK: 테두리 빛

enum class LightMode { Off, Once, Loop }

/**
 * 카드 테두리를 따라 밝은 빛이 도는 효과 (아이폰 BorderLight).
 * once = 나타날 때마다 한 바퀴 돌고 멈춤 / loop = 계속 (밝기 · 한 바퀴 시간 · 두 줄기) / off = 테두리만.
 * border = 고정 테두리 (null 이면 안 그림)
 */
fun Modifier.borderLight(
    light: Color, mode: LightMode, radius: Dp = 20.dp, border: Brush? = null, delayMs: Long = 0,
    lineWidth: Dp = 1.5.dp, intensity: Float = 1f, lapSec: Float = 6f, double: Boolean = false,
): Modifier = composed {
    val frozen = Store.demo
    var angle = -90f
    var shine = 0f
    if (mode == LightMode.Loop) {
        val inf = rememberInfiniteTransition(label = "light")
        val a by inf.animateFloat(-90f, 270f, infiniteRepeatable(tween((maxOf(1f, lapSec) * 1000).toInt(), easing = LinearEasing), RepeatMode.Restart), label = "a")
        val fade = remember { Animatable(0f) }
        LaunchedEffect(intensity, frozen) {
            if (frozen) { fade.snapTo(intensity); return@LaunchedEffect }
            delay(delayMs + 50); fade.animateTo(intensity, tween(400))
        }
        angle = if (frozen) 20f else a
        shine = fade.value
    } else if (mode == LightMode.Once) {
        val ang = remember { Animatable(-90f) }
        val fade = remember { Animatable(0f) }
        LaunchedEffect(Unit) {
            if (frozen) return@LaunchedEffect
            delay(delayMs + 50)
            coroutineScope {
                launch { fade.animateTo(1f, tween(250)) }
                launch { ang.animateTo(270f, tween(2600, easing = FastOutSlowInEasing)) }
                launch { delay(2200); fade.animateTo(0f, tween(500)) }
            }
        }
        angle = ang.value
        shine = fade.value
    }
    val stops = remember(light, double) { beamStops(light, double) }
    this.drawWithContent {
        drawContent()
        val s = lineWidth.toPx()
        val r = CornerRadius(radius.toPx() - s / 2)
        val tl = Offset(s / 2, s / 2)
        val sz = Size(size.width - s, size.height - s)
        if (border != null) drawRoundRect(border, tl, sz, r, style = Stroke(s))
        if (mode != LightMode.Off && shine > 0f) {
            val cx = size.width / 2
            val cy = size.height / 2
            val sh = android.graphics.SweepGradient(cx, cy, stops.second, stops.first)
            sh.setLocalMatrix(android.graphics.Matrix().apply { postRotate(angle, cx, cy) })
            drawRoundRect(ShaderBrush(sh), tl, sz, r, alpha = shine, style = Stroke(s))
        }
    }
}

/** 빛 한 줄기 = 원의 뒤쪽 30% (꼬리가 길고 머리가 흼). 두 줄기면 반대편에 하나 더 */
private fun beamStops(light: Color, double: Boolean): Pair<FloatArray, IntArray> {
    val pos = ArrayList<Float>()
    val col = ArrayList<Int>()
    fun add(p: Float, c: Color) { pos.add(p); col.add(c.toArgb()) }
    fun beam(at: Float) {
        add(at, light.copy(alpha = 0f))
        add(at + 0.16f, light.copy(alpha = 0.55f))
        add(at + 0.255f, light)
        add(at + 0.285f, Color.White)
        add(at + 0.30f, light.copy(alpha = 0f))
    }
    add(0f, light.copy(alpha = 0f))
    if (double) beam(0.20f)
    beam(0.70f)
    return pos.toFloatArray() to col.toIntArray()
}

/** 등급 색 테두리 (왼쪽 위가 진하고 오른쪽 아래로 옅어짐) */
fun PFTGrade.borderBrush(): Brush = Brush.linearGradient(
    0f to hex(hex1, 0.9f), 0.45f to hex(hex2, 0.25f), 1f to Color.White.copy(alpha = 0.08f),
)

/** 홈 프로필 카드: PFT 등급 색 테두리. 골드는 들어올 때마다 빛이 한 바퀴 */
fun Modifier.gradeBorder(g: PFTGrade?): Modifier =
    if (g == null) this else borderLight(hex(g.hex1), if (g == PFTGrade.Gold) LightMode.Once else LightMode.Off, border = g.borderBrush())
