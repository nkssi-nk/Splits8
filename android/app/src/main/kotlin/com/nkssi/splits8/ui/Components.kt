package com.nkssi.splits8.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.R
import com.nkssi.splits8.shared.PFTGrade
import com.nkssi.splits8.shared.l10n

// 아이폰 iOSApp/Views/Components.swift 의 공통 부품.
// 글자 크기는 11 · 13 · 15 · 17 · 20 · 28 · 44 만 씀 (예외: 큰 제목 34, 레이스 52). 굵기 400/500/600, 워드마크만 800.

// MARK: 카드

/** 카드: rgba 255 0.06 + 테두리 1px 0.08, 모서리 20 */
fun Modifier.card8(radius: Dp = 20.dp, fill: Color = C.card): Modifier {
    val shape = RoundedCornerShape(radius)
    return this.clip(shape).background(fill, shape).border(1.dp, C.cardBorder, shape)
}

/** 목록 줄 아래 1px 선 */
fun Modifier.rowLine(show: Boolean, start: Dp = 0.dp): Modifier = if (!show) this else drawBehind {
    val y = size.height - 1.dp.toPx() / 2
    drawLine(C.line, Offset(start.toPx(), y), Offset(size.width, y), strokeWidth = 1.dp.toPx())
}

/** 누르면 살짝 작아지는 버튼 (아이폰 Press). 물결 효과 없음 */
@Composable
fun Modifier.press(scale: Float = 0.98f, enabled: Boolean = true, tag: String? = null, onClick: () -> Unit): Modifier {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) scale else 1f, tween(80), label = "press")
    return this
        .let { if (tag != null) it.testTag(tag) else it }
        .scale(s)
        .clickable(interactionSource = src, indication = null, enabled = enabled, onClick = onClick)
}

/** 물결 없이 누르기 */
@Composable
fun Modifier.tap(enabled: Boolean = true, onClick: () -> Unit): Modifier =
    clickable(remember { MutableInteractionSource() }, indication = null, enabled = enabled, onClick = onClick)

// MARK: 글자

/** 번역해서 보여 주는 글자 (아이폰 Text("…") 와 같음 — 열쇠는 영어 원문) */
@Composable
fun T(
    text: String, style: androidx.compose.ui.text.TextStyle, modifier: Modifier = Modifier,
    maxLines: Int = Int.MAX_VALUE, align: TextAlign? = null, translate: Boolean = true,
) {
    BasicText(
        if (translate) text.l10n else text,
        modifier = modifier,
        style = if (align != null) style.copy(textAlign = align) else style,
        maxLines = maxLines,
        overflow = if (maxLines == Int.MAX_VALUE) TextOverflow.Clip else TextOverflow.Ellipsis,
    )
}

/** 대문자 라벨 (13 semibold, 자간 0.06em, 회색) */
@Composable
fun Label8(text: String, modifier: Modifier = Modifier, size: Int = F.foot, color: Color = C.text2, spacing: Float = 0.06f) {
    T(text, F.te(size, W600, color, spacing), modifier, maxLines = 1)
}

/** 큰 제목 34 / 600, 자간 −0.03em */
@Composable
fun LargeTitle(text: String, modifier: Modifier = Modifier, top: Dp = 10.dp) {
    T(text, F.te(34, W600, em = -0.03f).copy(lineHeight = 38.sp), modifier.fillMaxWidth().padding(top = top))
}

object SectionText {
    /** 그대로 대문자로 두는 낱말 */
    private val keep = setOf("PFT", "HIIT", "HR", "PB", "KM", "ID", "VS")

    fun shown(key: String): String {
        val loc = key.l10n
        if (loc != key) return loc
        return titleCase(key)
    }

    /** "PERSONAL BESTS" → "Personal Bests" (이미 소문자가 섞여 있으면 그대로) */
    fun titleCase(s: String): String {
        if (s != s.uppercase()) return s
        return s.split(" ").joinToString(" ") { w ->
            when {
                w in keep || w.length <= 1 -> w
                w.none { it.isLetter() } -> w
                else -> w.take(1) + w.drop(1).lowercase()
            }
        }
    }
}

/** 구역 소제목 줄 (15 / 600 흰색). 코드에는 대문자 키로 적고 보여 줄 때 첫 글자만 대문자 */
@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier, top: Dp = 14.dp) {
    T(SectionText.shown(text), F.t(F.sub, W600), modifier.fillMaxWidth().padding(top = top, start = 4.dp, end = 4.dp),
        maxLines = 1, translate = false)
}

/** 설명 문구 (13, #6E6E73, 줄간 1.5, 좌우 4) */
@Composable
fun Note8(text: String, modifier: Modifier = Modifier, color: Color = C.text3) {
    T(text, F.t(13, color = color).copy(lineHeight = 19.5.sp), modifier.fillMaxWidth().padding(horizontal = 4.dp))
}

// MARK: 아이콘 · 로고

/** 아이폰 그림 이름으로 색칠한 아이콘 (스테이션 · 모드 · i_* 모두) */
@Composable
fun Icon8(name: String, size: Dp, color: Color = Color.White, modifier: Modifier = Modifier) {
    val id = IconRes.of(name)
    if (id == null) {
        Spacer(modifier.size(size))
        return
    }
    Image(painterResource(id), contentDescription = null, modifier = modifier.size(size),
        colorFilter = ColorFilter.tint(color), contentScale = ContentScale.Fit)
}

/** 작은 아이콘 (i_*) — Icon8 과 같음, 아이폰 이름 맞춤 */
@Composable
fun Glyph(name: String, size: Dp, color: Color = Color.White, modifier: Modifier = Modifier) = Icon8(name, size, color, modifier)

/** › (14, #48484C) */
@Composable
fun Chevron8(size: Dp = 14.dp, color: Color = C.chev) = Glyph("i_chevR", size, color)

/** 체크 (노랑) */
@Composable
fun Check8(color: Color = C.accent, size: Dp = 20.dp) = Glyph("i_check", size, color)

/**
 * SPLITS8 로고 그림. 높이 = 예전 글자 크기 × 0.83, 원본 비율 1677 × 331.
 * black=true 면 검은 글자 (+ 노란 8)
 */
@Composable
fun Wordmark(size: Float, modifier: Modifier = Modifier, black: Boolean = false, whiteEight: Boolean = false) {
    val h = (size * 0.83f).dp
    val w = h * 1677f / 331f
    if (black && !whiteEight) {
        // 검은 SPLITS + 노란 8: 두 그림을 8 앞(1361/1677)에서 잘라 이어 붙임
        val cut = 1361f / 1677f
        Box(modifier.size(w, h)) {
            Image(painterResource(R.drawable.wordmark_black), "SPLITS8", Modifier.size(w, h).clipLeft(cut), contentScale = ContentScale.Fit)
            Image(painterResource(R.drawable.wordmark_yellow), null, Modifier.size(w, h).clipRight(cut), contentScale = ContentScale.Fit)
        }
    } else {
        val id = when {
            black -> R.drawable.wordmark_black
            whiteEight -> R.drawable.wordmark_white
            else -> R.drawable.wordmark_yellow
        }
        Image(painterResource(id), "SPLITS8", modifier.size(w, h), contentScale = ContentScale.Fit)
    }
}

private fun Modifier.clipLeft(f: Float) = drawWithContent {
    clipRect(0f, 0f, size.width * f, size.height) { this@drawWithContent.drawContent() }
}
private fun Modifier.clipRight(f: Float) = drawWithContent {
    clipRect(size.width * f, 0f, size.width, size.height) { this@drawWithContent.drawContent() }
}

// MARK: 노란 유리 버튼 (Liquid Glass 대신 — 노란 그라데이션 + 위 하이라이트 + 노란 빛 그림자)

/** 노란 유리 바탕. on=false 면 회색 비활성 바탕 */
fun Modifier.yellowFill(shape: Shape, on: Boolean = true, glow: Boolean = true): Modifier {
    if (!on) return this.clip(shape).background(Color.White.copy(alpha = 0.12f), shape)
    return this
        .then(if (glow) Modifier.shadow(9.dp, shape, ambientColor = Color(0x33FFD600), spotColor = Color(0x55FFD600)) else Modifier)
        .clip(shape)
        .background(Brush.verticalGradient(listOf(Color(0xF5FFEE46), Color(0xCCFFD600))), shape)
        .border(
            1.dp,
            Brush.verticalGradient(
                0f to Color.White.copy(alpha = 0.6f), 0.12f to Color.White.copy(alpha = 0f),
                0.88f to Color.Black.copy(alpha = 0f), 1f to Color.Black.copy(alpha = 0.10f),
            ),
            shape,
        )
}

/** 큰 노란 버튼 (54 높이, 모서리 16, 17/600). 비활성이면 회색 */
@Composable
fun YellowButton(
    title: String, modifier: Modifier = Modifier, height: Dp = 54.dp, radius: Dp = 16.dp, enabled: Boolean = true,
    tag: String? = null, onClick: () -> Unit,
) {
    Box(
        modifier.fillMaxWidth().height(height).yellowFill(RoundedCornerShape(radius), on = enabled)
            .press(enabled = enabled, tag = tag, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        T(title, F.t(17, W600, if (enabled) Color.Black else C.text3), maxLines = 1)
    }
}

/** 작은 노란 알약 (34 높이, 좌우 14, 13/600) */
@Composable
fun YellowPill(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier.height(34.dp).yellowFill(CircleShape).press(0.96f, onClick = onClick).padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center) {
        T(title, F.t(13, W600, Color.Black), maxLines = 1)
    }
}

/** 회색 알약 (34 높이, 흰색 0.10) */
@Composable
fun GrayPill(title: String, modifier: Modifier = Modifier, icon: String? = null, onClick: () -> Unit) {
    Row(
        modifier.height(34.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f))
            .press(0.96f, onClick = onClick).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Glyph(icon, 13.dp)
        T(title, F.t(13, W600), maxLines = 1)
    }
}

// MARK: 세그먼트 · 토글 · 스테퍼

/** 세그먼트 (By age | Manual): 트랙 흰 0.08 모서리 10, 고른 칸 #2C2C2E, 32 높이, 13/600 */
@Composable
fun Seg8(
    items: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier,
    height: Dp = 32.dp, radius: Dp = 10.dp, fontSize: Int = 13, track: Color = C.segTrack, minWidth: Dp = 0.dp,
    onSelect: (String) -> Unit,
) {
    Row(modifier.clip(RoundedCornerShape(radius)).background(track).padding(2.dp)) {
        for ((k, l) in items) {
            val on = selected == k
            val m = if (minWidth > 0.dp) Modifier.widthIn(min = minWidth).padding(horizontal = 0.dp) else Modifier.weight(1f)
            Box(
                m.height(height).clip(RoundedCornerShape(radius - 2.dp)).background(if (on) C.segOn else Color.Transparent)
                    .tap { onSelect(k) }.then(if (minWidth > 0.dp) Modifier.padding(horizontal = 12.dp) else Modifier),
                contentAlignment = Alignment.Center,
            ) { T(l, F.t(fontSize, W600, if (on) Color.White else C.text2), maxLines = 1) }
        }
    }
}

/** 작은 알약 세그먼트 (Mine | Jiho): 24 높이, 11/600 */
@Composable
fun Pills8(items: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    Row(modifier.clip(RoundedCornerShape(8.dp)).background(C.segTrack).padding(2.dp)) {
        for ((k, l) in items) {
            val on = selected == k
            Box(
                Modifier.height(24.dp).clip(RoundedCornerShape(6.dp)).background(if (on) C.segOn else Color.Transparent)
                    .tap { onSelect(k) }.padding(horizontal = 9.dp),
                contentAlignment = Alignment.Center,
            ) { T(l, F.t(11, W600, if (on) Color.White else C.text2), maxLines = 1) }
        }
    }
}

/** 토글 51×31, 켜짐 노랑 + 검정 손잡이 */
@Composable
fun Toggle8(on: Boolean, modifier: Modifier = Modifier, w: Dp = 51.dp, h: Dp = 31.dp, onChange: (Boolean) -> Unit) {
    val k = h - 4.dp
    val x by animateDpAsState(if (on) w - k - 2.dp else 2.dp, tween(200), label = "toggle")
    Box(modifier.size(w, h).clip(CircleShape).background(if (on) C.accent else C.control).tap { onChange(!on) }) {
        Box(
            Modifier.offset(x = x).align(Alignment.CenterStart).size(k)
                .shadow(2.dp, CircleShape).background(if (on) Color.Black else Color.White, CircleShape),
        )
    }
}

/** − 값 + (34 정사각 #1A1A1A 모서리 10, 값 20/600) */
@Composable
fun Stepper8(
    value: String, modifier: Modifier = Modifier, minWidth: Dp = 24.dp, fontSize: Int = 20, button: Dp = 34.dp,
    radius: Dp = 10.dp, gap: Dp = 16.dp, down: () -> Unit, up: () -> Unit,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(gap)) {
        StepBtn("−", button, radius, down)
        T(value, F.num(fontSize), Modifier.widthIn(min = minWidth), maxLines = 1, align = TextAlign.Center, translate = false)
        StepBtn("+", button, radius, up)
    }
}

@Composable
private fun StepBtn(t: String, size: Dp, radius: Dp, onClick: () -> Unit) {
    Box(Modifier.size(size).clip(RoundedCornerShape(radius)).background(C.btn1A).press(0.94f, onClick = onClick),
        contentAlignment = Alignment.Center) { T(t, F.t(17), translate = false) }
}

// MARK: 목록 줄

/** 확인할 개수 (노란 동그라미). 0 이면 안 보임 */
@Composable
fun CountBadge(n: Int) {
    if (n <= 0) return
    Box(Modifier.heightIn(min = 20.dp).widthIn(min = 20.dp).clip(CircleShape).background(C.accent).padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center) {
        T(if (n > 99) "99+" else "$n", F.num(12, W600, Color.Black), translate = false)
    }
}

/** 설정 목록 줄: 제목 17 · 값 15 회색 · › (14×18, 선 1px) */
@Composable
fun SettingRow(
    title: String, value: String, modifier: Modifier = Modifier, numeric: Boolean = false, last: Boolean = false,
    badge: Int = 0, onClick: () -> Unit,
) {
    Row(
        modifier.fillMaxWidth().rowLine(!last).tap(onClick = onClick).padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        T(title, F.t(17), Modifier.weight(1f), maxLines = 1)
        CountBadge(badge)
        T(value, if (numeric) F.num(15, W400, C.text2) else F.t(15, color = C.text2), maxLines = 1)
        Chevron8()
    }
}

/** 원형 사진/이니셜 */
@Composable
fun Avatar8(size: Dp, initial: String, modifier: Modifier = Modifier, photo: androidx.compose.ui.graphics.ImageBitmap? = null,
            bg: Color = C.control, fg: Color = Color.White) {
    Box(modifier.size(size).clip(CircleShape).background(bg), contentAlignment = Alignment.Center) {
        if (photo != null) {
            Image(photo, null, Modifier.size(size), contentScale = ContentScale.Crop)
        } else {
            T(initial, F.t(size.value * 0.38f, W600, fg), translate = false)
        }
    }
}

// MARK: 입력칸

/** 입력칸 (카드 모양, 모서리 14, 17pt, 14×16) */
@Composable
fun Field8(placeholder: String, text: String, modifier: Modifier = Modifier, size: Int = 17, vPad: Dp = 14.dp, onChange: (String) -> Unit) {
    Box(modifier.fillMaxWidth().card8(14.dp).padding(vertical = vPad, horizontal = 16.dp)) {
        if (text.isEmpty()) T(placeholder, F.t(size, color = C.text3), maxLines = 1)
        BasicTextField(text, onChange, Modifier.fillMaxWidth(), textStyle = F.t(size), singleLine = true, cursorBrush = SolidColor(C.accent))
    }
}

/** 검색칸 (흰 0.08, 모서리 12, 돋보기 16 회색, 17pt) */
@Composable
fun SearchField8(placeholder: String, text: String, modifier: Modifier = Modifier, prefix: String? = null, onChange: (String) -> Unit) {
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (prefix != null) T(prefix, F.t(17, color = C.text2), translate = false) else Glyph("i_search", 16.dp, C.text2)
        Box(Modifier.weight(1f).padding(vertical = 11.dp)) {
            if (text.isEmpty()) T(placeholder, F.t(17, color = C.text3), maxLines = 1)
            BasicTextField(text, onChange, Modifier.fillMaxWidth(), textStyle = F.t(17), singleLine = true, cursorBrush = SolidColor(C.accent))
        }
    }
}

// MARK: PFT 등급 뱃지

/** GOLD / SILVER / BRONZE / IRON / UNRANKED (기본 78 × 22). 점은 왼쪽 같은 자리, 글자는 남은 칸 가운데 */
@Composable
fun PFTBadge(grade: PFTGrade, modifier: Modifier = Modifier, width: Dp = 78.dp, height: Dp = 22.dp, fontSize: Float = 12f) {
    val shape = RoundedCornerShape(height * 0.32f)
    val dot = (fontSize * 0.92f).dp
    val lead = (height - dot) / 2 + 1.dp
    Row(
        modifier.size(width, height).clip(shape)
            // Unranked = 회색 테두리만 (바탕 없음) — 아이폰 빌드 26
            .then(if (grade == PFTGrade.Unranked) Modifier.border(1.2.dp, hex(grade.hex1), shape)
                  else Modifier.background(Brush.linearGradient(listOf(hex(grade.hex1), hex(grade.hex2))))),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.padding(start = lead).size(dot).clip(CircleShape).background(Color.Black.copy(alpha = 0.28f))
                .border(maxOf(1.5f, fontSize / 6).dp, Color.White.copy(alpha = 0.55f), CircleShape),
        )
        T(grade.label, F.te(fontSize, W800, hex(grade.inkHex), 0.04f),
            Modifier.weight(1f).padding(start = 2.dp, end = lead * 0.7f), maxLines = 1, align = TextAlign.Center, translate = false)
    }
}

// MARK: 겹꺾쇠 (︾ ︽)

/** 아래(︾) 또는 위(︽) 겹꺾쇠 선 */
fun Modifier.doubleChevron(up: Boolean, color: Color = C.aeb, width: Dp = 10.dp, height: Dp = 11.dp): Modifier = drawBehind {
    val w = width.toPx()
    val h = height.toPx()
    val x0 = (size.width - w) / 2
    val y0 = (size.height - h) / 2
    val stroke = Stroke(1.7.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round)
    for (k in 0..1) {
        val off = y0 + k * h * 0.45f
        val p = androidx.compose.ui.graphics.Path().apply {
            if (up) {
                moveTo(x0, off + h * 0.45f); lineTo(x0 + w / 2, off); lineTo(x0 + w, off + h * 0.45f)
            } else {
                moveTo(x0, off); lineTo(x0 + w / 2, off + h * 0.45f); lineTo(x0 + w, off)
            }
        }
        drawPath(p, color, style = stroke)
    }
}

/** 둥근 사각 테두리만 */
fun Modifier.strokeBorder(color: Color, radius: Dp, width: Dp = 1.dp): Modifier = drawBehind {
    val s = width.toPx()
    drawRoundRect(color, Offset(s / 2, s / 2), Size(size.width - s, size.height - s), CornerRadius(radius.toPx()), style = Stroke(s))
}

/**
 * 카드 바깥으로만 번지는 빛 (아이폰 .shadow(color:) 처럼). 안드로이드 그림자는 반투명 카드 안까지 어둡게 비쳐서 직접 그림.
 * radius = 번지는 거리, y = 아래로 내림
 */
fun Modifier.outerGlow(color: Color, corner: Dp, radius: Dp, y: Dp = 0.dp): Modifier = drawBehind {
    val r = radius.toPx()
    val dy = y.toPx()
    val c = corner.toPx()
    val card = androidx.compose.ui.graphics.Path().apply {
        addRoundRect(androidx.compose.ui.geometry.RoundRect(0f, 0f, size.width, size.height, CornerRadius(c)))
    }
    clipPath(card, androidx.compose.ui.graphics.ClipOp.Difference) {
        val steps = 10
        for (k in steps downTo 1) {
            val g = r * k / steps
            drawRoundRect(color.copy(alpha = color.alpha * (1f - k.toFloat() / (steps + 1)) / steps * 2.2f),
                Offset(-g, -g + dy), Size(size.width + g * 2, size.height + g * 2), CornerRadius(c + g))
        }
    }
}
