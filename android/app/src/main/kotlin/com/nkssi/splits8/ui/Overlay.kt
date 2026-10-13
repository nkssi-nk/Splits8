package com.nkssi.splits8.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.Router
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// 아이폰 Components.swift 의 NavBar3 · SwipeDelete · PagedCard, 그리고 .alert · .sheet 를 대신하는 부품

// MARK: 머리줄 (Cancel · 제목 · Save)

/** 44 높이: 가운데 제목 17/600, 왼쪽 회색 글자 단추, 오른쪽 노란 글자 단추. edgeBack = 뒤로 가기가 왼쪽 단추를 누름 */
@Composable
fun NavBar3(
    left: String, title: String, modifier: Modifier = Modifier, right: String? = null,
    rightColor: Color = C.accent, leftColor: Color = C.text2, edgeBack: Boolean = true,
    onLeft: () -> Unit, onRight: () -> Unit = {},
) {
    if (edgeBack) {
        DisposableEffect(Unit) {
            Router.backAction = onLeft
            onDispose { if (Router.backAction === onLeft) Router.backAction = null }
        }
    }
    Box(modifier.fillMaxWidth().height(44.dp).padding(horizontal = 4.dp)) {
        T(title, F.t(17, W600), Modifier.align(Alignment.Center).padding(horizontal = 80.dp), maxLines = 1)
        Box(Modifier.align(Alignment.CenterStart).heightIn(min = 44.dp).widthIn(min = 44.dp).tap(onClick = onLeft).testTag("nav.left"),
            contentAlignment = Alignment.CenterStart) {
            T(left, F.t(17, color = leftColor), maxLines = 1)
        }
        if (right != null) {
            Box(Modifier.align(Alignment.CenterEnd).heightIn(min = 44.dp).widthIn(min = 44.dp).tap(onClick = onRight).testTag("nav.right"),
                contentAlignment = Alignment.CenterEnd) {
                T(right, F.t(17, W600, rightColor), maxLines = 1)
            }
        }
    }
}

// MARK: 확인 창

/** Router.ask 가 있으면 화면 가운데 확인 창 (아이폰 alert 모양: 270 폭, 모서리 14, 단추 두 칸) */
@Composable
fun AskHost() {
    val a = Router.ask
    var shown by remember { mutableStateOf<Ask?>(null) }
    if (a != null) shown = a
    AnimatedVisibility(a != null, enter = fadeIn(tween(150)), exit = fadeOut(tween(150))) {
        val x = shown ?: return@AnimatedVisibility
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)).tap { }, contentAlignment = Alignment.Center) {
            Column(
                Modifier.width(280.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFF2C2C2E)).testTag("ask"),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.padding(start = 18.dp, end = 18.dp, top = 20.dp, bottom = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    T(x.title, F.t(17, W600), align = TextAlign.Center)
                    if (x.message != null) T(x.message, F.t(13, color = C.d1).copy(lineHeight = androidx.compose.ui.unit.TextUnit(18f, androidx.compose.ui.unit.TextUnitType.Sp)), align = TextAlign.Center)
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.12f)))
                Row(Modifier.fillMaxWidth().height(46.dp)) {
                    if (x.cancel != null) {
                        Box(Modifier.weight(1f).fillMaxHeight().tap { Router.ask = null }.testTag("ask.cancel"), contentAlignment = Alignment.Center) {
                            T(x.cancel, F.t(17, color = C.accent), maxLines = 1)
                        }
                        Box(Modifier.width(1.dp).fillMaxHeight().background(Color.White.copy(alpha = 0.12f)))
                    }
                    Box(
                        Modifier.weight(1f).fillMaxHeight().tap { Router.ask = null; x.onOk() }.testTag("ask.ok"),
                        contentAlignment = Alignment.Center,
                    ) { T(x.ok, F.t(17, W600, if (x.destructive) C.bad else C.accent), maxLines = 1) }
                }
            }
        }
    }
}

// MARK: 아래에서 올라오는 시트

/**
 * 시트 (아이폰 .sheet): 어두운 바탕 + 아래에서 올라오는 #1C1C1E 판, 위 모서리 20, 손잡이.
 * 바깥을 누르거나 손잡이를 아래로 끌면 닫힘. large = 화면 위쪽 거의 끝까지
 */
@Composable
fun <T : Any> Sheet8(item: T?, onClose: () -> Unit, large: Boolean = false, bg: Color = C.sheet, content: @Composable ColumnScope.(T) -> Unit) {
    var last by remember { mutableStateOf<T?>(null) }
    if (item != null) last = item
    val density = LocalDensity.current
    Box(Modifier.fillMaxSize()) {
        AnimatedVisibility(item != null, enter = fadeIn(tween(200)), exit = fadeOut(tween(200))) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)).pointerInput(Unit) { detectTapGestures { onClose() } })
        }
        AnimatedVisibility(
            item != null, Modifier.align(Alignment.BottomCenter),
            enter = slideInVertically(tween(280)) { it }, exit = slideOutVertically(tween(220)) { it },
        ) {
            val it = last ?: return@AnimatedVisibility
            val drag = remember { Animatable(0f) }
            val scope = rememberCoroutineScope()
            Column(
                Modifier.fillMaxWidth()
                    .then(if (large) Modifier.fillMaxHeight(0.94f) else Modifier.heightIn(max = 760.dp))
                    .offset { IntOffset(0, drag.value.roundToInt()) }
                    .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                    .background(bg)
                    .pointerInput(Unit) { detectTapGestures { } }   // 판 안을 눌러도 닫히지 않게
                    .padding(bottom = navBottom()),
            ) {
                // 손잡이 (36 × 5) — 아래로 끌면 닫힘
                Box(
                    Modifier.fillMaxWidth().height(20.dp).pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onDragEnd = {
                                scope.launch {
                                    if (drag.value > with(density) { 90.dp.toPx() }) { onClose(); drag.snapTo(0f) } else drag.animateTo(0f, tween(180))
                                }
                            },
                        ) { _, dy -> scope.launch { drag.snapTo((drag.value + dy).coerceAtLeast(0f)) } }
                    },
                    contentAlignment = Alignment.Center,
                ) { Box(Modifier.size(36.dp, 5.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.25f))) }
                content(it)
            }
        }
    }
}

// MARK: 밀어서 삭제

/**
 * 왼쪽으로 밀면 오른쪽에 빨간 Delete (84 폭). 절반 넘게 밀고 놓으면 열린 채로, Delete 를 누르면 확인 창.
 * 길게 누르기도 확인 창 (아이폰의 길게 눌러 나오는 삭제 메뉴 대신). 열린 상태에서 누르면 닫힘
 */
@Composable
fun SwipeDelete(
    alertTitle: String, modifier: Modifier = Modifier, corner: Dp = 0.dp, alertMessage: String = "This can't be undone.",
    onTap: () -> Unit, onDelete: () -> Unit, content: @Composable BoxScope.() -> Unit,
) {
    val density = LocalDensity.current
    val reveal = with(density) { 84.dp.toPx() }
    val off = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    fun close() = scope.launch { off.animateTo(0f, tween(220)) }
    fun ask() {
        Router.ask = Ask(alertTitle, alertMessage, ok = "Delete", destructive = true) { close(); onDelete() }
    }
    Box(modifier.clip(RoundedCornerShape(corner))) {
        if (off.value < 0f) {
            Box(
                Modifier.matchParentSize().background(Color.Transparent),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Column(
                    Modifier.fillMaxHeight().width(with(density) { maxOf(reveal, -off.value).toDp() }).background(C.bad)
                        .tap { ask() }.testTag("swipe.delete"),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                ) {
                    Sym(com.nkssi.splits8.R.drawable.sym_trash, 19.dp)
                    T("Delete", F.t(12, W600), Modifier.padding(top = 3.dp), maxLines = 1)
                }
            }
        }
        Box(
            Modifier.offset { IntOffset(off.value.roundToInt(), 0) }
                .pointerInput(Unit) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            scope.launch { off.animateTo(if (off.value < -reveal / 2) -reveal else 0f, tween(220)) }
                        },
                    ) { ch, dx ->
                        ch.consume()
                        scope.launch { off.snapTo((off.value + dx).coerceAtMost(0f)) }
                    }
                }
                .pointerInput(Unit) {
                    detectTapGestures(onLongPress = { ask() }) { if (off.value != 0f) close() else onTap() }
                },
            content = content,
        )
    }
}

// MARK: 5줄씩 넘기는 카드

/** 기록 목록 카드: 5줄씩, 아래 ‹ 1 / 3 › (쪽이 여러 개일 때만). 마지막 쪽이 짧아도 카드 높이는 그대로 */
@Composable
fun PagedCard(count: Int, modifier: Modifier = Modifier, row: @Composable (index: Int, last: Boolean) -> Unit) {
    val size = 5
    val pages = maxOf(1, (count + size - 1) / size)
    var page by remember { mutableIntStateOf(0) }
    var fullH by remember { mutableIntStateOf(0) }
    val p = page.coerceIn(0, pages - 1)
    val lo = p * size
    val hi = minOf(count, lo + size)
    Column(modifier.fillMaxWidth().card8()) {
        val minH = if (pages > 1 && fullH > 0) with(LocalDensity.current) { fullH.toDp() } else 0.dp
        Column(Modifier.heightIn(min = minH).onSizeChanged { if (hi - lo == size && it.height > fullH) fullH = it.height }) {
            for (i in lo until hi) row(i, pages == 1 && i == hi - 1)
        }
        if (pages > 1) {
            Row(Modifier.fillMaxWidth().height(52.dp), horizontalArrangement = Arrangement.spacedBy(22.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically) {
                PagerArrow("i_chevL", p > 0, "pager.prev") { page = p - 1 }
                Row(Modifier.widthIn(min = 52.dp), horizontalArrangement = Arrangement.Center) {
                    T("${p + 1}", F.num(14, W600), translate = false)
                    T(" / $pages", F.num(14, W400, C.text2), translate = false)
                }
                PagerArrow("i_chevR", p < pages - 1, "pager.next") { page = p + 1 }
            }
        }
    }
}

@Composable
private fun PagerArrow(icon: String, on: Boolean, tag: String, onClick: () -> Unit) {
    Box(Modifier.size(44.dp).press(0.92f, enabled = on, tag = tag, onClick = onClick), contentAlignment = Alignment.Center) {
        Box(Modifier.size(34.dp).clip(CircleShape).background(Color.White.copy(alpha = if (on) 0.08f else 0.04f)), contentAlignment = Alignment.Center) {
            Glyph(icon, 13.dp, if (on) C.accent else Color(0xFF4A4A4A))
        }
    }
}

// MARK: 기록 머리줄 · 빈 기록

/** "History" 소제목 (위 20) */
@Composable
fun HistoryHeader() = SectionLabel("HISTORY", top = 20.dp)

/** 기록이 하나도 없을 때 */
@Composable
fun EmptyHistory() {
    Column(Modifier.fillMaxWidth().card8().padding(vertical = 22.dp, horizontal = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        T("No records yet", F.t(15, W600))
        T("Start a workout on your watch and your records will show up here.", F.t(13, color = C.text2), align = TextAlign.Center)
    }
}

/** 안드로이드에 따로 그린 작은 기호 (휴지통 · 링크 · 폰) */
@Composable
fun Sym(id: Int, size: Dp, color: Color = Color.White, modifier: Modifier = Modifier) {
    androidx.compose.foundation.Image(
        androidx.compose.ui.res.painterResource(id), null, modifier.size(size),
        colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(color),
    )
}
