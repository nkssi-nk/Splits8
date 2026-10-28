package com.nkssi.splits8.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.TabBarScroll
import kotlinx.coroutines.launch
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource

// 아이폰 PhoneApp.swift 의 화면 틀: 루트 · 위 고정 바 · 떠 있는 탭 바 · 세로 스크롤

/** 상태 줄 높이 (화면 사진에서는 0) */
@Composable
fun statusTop(): Dp = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()

@Composable
fun navBottom(): Dp = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

/** 화면 틀: 배경 빛 + 화면 + 상태 줄 그늘 + 고정 바 + 탭 바 */
/** 위 고정 바 뒤 흐림 (안드로이드 74-2): 화면 내용을 담아 두는 곳 */
val LocalHaze = androidx.compose.runtime.staticCompositionLocalOf<dev.chrisbanes.haze.HazeState?> { null }

@Composable
fun PhoneRoot(screen: @Composable (Scr) -> Unit) {
    val scr = Router.scr
    val theme = Store.settings.glow
    val haze = remember { dev.chrisbanes.haze.HazeState() }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        // 배경 빛 + 화면 = 위 고정 바가 뒤로 비춰 흐리게 보여 줄 내용
        Box(Modifier.fillMaxSize().hazeSource(haze)) {
            Crossfade(scr to theme, animationSpec = tween(500), label = "ambient") { (s, t) ->
                AmbientLayer(s.ambient(t))
            }
            // 들어오는 화면만 부드럽게 (아이폰과 같음)
            Crossfade(scr, animationSpec = tween(250), label = "screen") { s -> Box(Modifier.fillMaxSize()) { screen(s) } }
        }

        // 상태 줄 뒤 검은 그라데이션
        if (scr != Scr.Splash) {
            val top = statusTop()
            if (top > 0.dp) {
                Box(Modifier.fillMaxWidth().height(top).background(Brush.verticalGradient(0.6f to Color.Black, 1f to Color.Transparent)))
            }
        }
        if (scr.showsBar) androidx.compose.runtime.CompositionLocalProvider(LocalHaze provides haze) { TopBar8() }
        if (scr.showsTabs) {
            TabFade(Modifier.align(Alignment.BottomCenter))
            TabBar8(Modifier.align(Alignment.BottomCenter).padding(horizontal = 20.dp).padding(bottom = maxOf(26.dp, navBottom() + 10.dp)))
        }
        // 빌드 27: 받은 응원 · 친구 요청 알림 띠 (누르면 친구 화면)
        com.nkssi.splits8.NoticeBanner()
        // 16번: "숨겼어요 · 되돌리기" 띠 (탭 바 바로 위)
        com.nkssi.splits8.UndoBand(Modifier.align(Alignment.BottomCenter))
        // 시트 · 확인 창 (탭 바보다 위)
        com.nkssi.splits8.screens.Overlays()
    }
}

/** 17번: 끌어서 순서 바꿀 때 화면 끝 자동 스크롤에 씀 — Scroll8 의 스크롤 + 내용이 보이는 영역(창 기준 y, 위 바 · 탭 바 자리 뺌) */
class ScrollArea(val state: androidx.compose.foundation.ScrollState) {
    var top = 0f
    var bottom = 0f
}

val LocalScrollArea = androidx.compose.runtime.staticCompositionLocalOf<ScrollArea?> { null }

/** 세로 스크롤. 위: 고정 바가 있으면 52 (상태 줄 아래) / 없으면 4, 아래 120 (탭 바 자리) */
@Composable
fun Scroll8(bottom: Dp = 120.dp, content: @Composable ColumnScope.() -> Unit) {
    val state = rememberScrollState()
    val density = LocalDensity.current
    val conn = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                TabBarScroll.dragging(source == NestedScrollSource.UserInput)
                return Offset.Zero
            }
        }
    }
    LaunchedEffect(state) {
        snapshotFlow { state.value }.collect { TabBarScroll.update(with(density) { it.toDp().value }) }
    }
    LaunchedEffect(state.isScrollInProgress) { if (!state.isScrollInProgress) TabBarScroll.dragging(false) }
    val s = Router.scr
    val top = statusTop() + if (s.showsBar || s.pinsNav) 52.dp else 4.dp
    val area = remember(state) { ScrollArea(state) }
    val topPx = with(density) { top.toPx() }
    val bottomPx = with(density) { (bottom + navBottom()).toPx() }
    androidx.compose.runtime.CompositionLocalProvider(LocalScrollArea provides area) {
        Column(
            Modifier.fillMaxSize()
                .onGloballyPositioned { c ->
                    val b = c.boundsInWindow()
                    area.top = b.top + topPx; area.bottom = b.bottom - bottomPx
                }
                .nestedScroll(conn).verticalScroll(state, enabled = !MapTouch.down)
                .padding(top = top, bottom = bottom + navBottom()),
            content = content,
        )
    }
}

/** 지도를 손가락으로 누르고 있는 동안은 화면 스크롤을 멈춤 (지도를 위아래로 끌어도 화면이 안 따라가게) */
object MapTouch { var down by mutableStateOf(false) }

// MARK: 위 고정 바

/**
 * 44 높이, 아래 1px 흰 0.06. 왼쪽 SPLITS8 또는 노랑 ‹ 뒤로, 오른쪽 제목 17/600.
 * 74-2(안드로이드): 아이폰처럼 뒤 내용을 흐리게 (얇은 유리 + 검정 0.55). 흐림이 안 되는 폰(안드로이드 11 이하)은 더 진한 검정
 */
@OptIn(dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi::class)
@Composable
fun TopBar8() {
    val top = statusTop()
    val haze = LocalHaze.current
    val blur = haze != null && android.os.Build.VERSION.SDK_INT >= 31
    Column(Modifier.fillMaxWidth()) {
        Box(
            Modifier.fillMaxWidth().height(top + 44.dp)
                .let { if (blur) it.hazeEffect(haze, dev.chrisbanes.haze.materials.HazeMaterials.ultraThin(Color.Black)) else it }
                .background(Color.Black.copy(alpha = if (blur) 0.55f else 0.82f))
                .drawBehind {
                    val y = size.height - 0.5.dp.toPx()
                    drawLine(Color.White.copy(alpha = 0.06f), Offset(0f, y), Offset(size.width, y), 1.dp.toPx())
                }
                .padding(top = top).padding(horizontal = 20.dp),
        ) {
            Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                val back = Router.barBack
                if (back != null) {
                    Row(
                        Modifier.offset(x = (-6).dp).height(44.dp).tap(onClick = back.second).testTag("back"),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Glyph("i_chevL", 22.dp, C.accent)
                        T(back.first, F.t(17, color = C.accent), maxLines = 1)
                    }
                } else {
                    // 빌드 26: 로고를 누르면 홈으로
                    Box(Modifier.height(44.dp).tap { if (Router.scr != Scr.Home) Router.go(Scr.Home) }.testTag("bar.logo"), contentAlignment = Alignment.CenterStart) {
                        Wordmark(17f)
                    }
                }
                Spacer(Modifier.weight(1f).width(12.dp))
                T(Router.barTitle, F.t(17, W600, tracking = -0.17f), maxLines = 1)
            }
        }
    }
}

// MARK: 떠 있는 탭 바

private data class Tab(val scr: Scr, val label: String, val icon: String)

private val tabs = listOf(
    Tab(Scr.Home, "Home", "i_home"), Tab(Scr.Training, "Training", "modeTraining"),
    Tab(Scr.Sim, "Test", "i_sim"), Tab(Scr.Race, "Race", "i_race"),
    Tab(Scr.Settings, "Settings", "i_gear"),
)

/**
 * 캡슐 (펼침 64 / 접힘 50), 좌우 20 · 아래 26. 아이폰 Liquid Glass 대신 반투명 진회색 + 얇은 테두리 + 그림자.
 * 고른 탭: 노랑 아이콘 + 아래 짧은 노란 선 (옮길 때 가는 쪽 끝이 먼저 뻗고 뒤쪽 끝이 늦게 따라붙음)
 */
@Composable
fun TabBar8(modifier: Modifier = Modifier) {
    val compact = TabBarScroll.compact
    val selScr = Router.scr.tab(Router.friendsFrom)
    val selected = tabs.indexOfFirst { it.scr == selScr }.takeIf { it >= 0 }
    // 74-1(안드로이드): 접기/펴기를 숫자 하나(p: 0 접힘 → 1 펼침)로 — 바 높이 · 글자 높이 · 투명도가 같은 움직임으로 함께 바뀜.
    //  예전엔 바 높이(스프링)와 글자(나타나기 효과)가 따로 움직이고, 글자가 생길 때 아이콘이 한 번에 튀어 올라 뚝뚝 끊겨 보였음
    val p by animateFloatAsState(if (compact) 0f else 1f, spring(dampingRatio = 1f, stiffness = 380f), label = "barP")
    val barH = 50.dp + 14.dp * p
    val edgeL = remember { Animatable((selected ?: 0).toFloat()) }
    val edgeR = remember { Animatable((selected ?: 0).toFloat()) }
    var prev by remember { mutableStateOf(selected) }
    var pop by remember { mutableStateOf<Int?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(selected) {
        val new = selected ?: return@LaunchedEffect
        val old = prev
        prev = new
        val to = new.toFloat()
        if (old == null || old == new) { edgeL.snapTo(to); edgeR.snapTo(to); return@LaunchedEffect }
        val fast = tween<Float>(240, easing = CubicBezierEasing(0.3f, 0.9f, 0.3f, 1f))
        val slow = spring<Float>(dampingRatio = 0.62f, stiffness = 220f)
        val lead = if (new > old) edgeR else edgeL
        val tail = if (new > old) edgeL else edgeR
        scope.launch { lead.animateTo(to, fast) }
        scope.launch { kotlinx.coroutines.delay(50); tail.animateTo(to, slow) }
        pop = new
        kotlinx.coroutines.delay(170)
        if (pop == new) pop = null
    }
    val shape = CircleShape
    BoxWithConstraints(
        modifier.fillMaxWidth().height(barH)
            .shadow(16.dp, shape, ambientColor = Color.Black, spotColor = Color.Black)
            .clip(shape)
            .background(Color(0xE6161616))
            .border(0.5.dp, Color.White.copy(alpha = 0.1f), shape),
    ) {
        val side = 6.dp
        val cell = (maxWidth - side * 2) / tabs.size
        Row(Modifier.fillMaxSize().padding(horizontal = side)) {
            tabs.forEachIndexed { i, t ->
                val on = selected == i
                val c = if (on) C.accent else C.text2
                val s by animateFloatAsState(if (pop == i) 1.14f else 1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium), label = "pop")
                Column(
                    Modifier.weight(1f).fillMaxSize().tap { Router.go(t.scr) }.testTag("tab." + t.label)
                        .padding(bottom = 7.dp + 2.dp * p),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(Modifier.size(25.dp, 24.dp).scale(s).offset(y = if (pop == i) (-2).dp else 0.dp), contentAlignment = Alignment.Center) {
                        if (t.icon == "modeTraining") Icon8(t.icon, 25.dp, c) else Glyph(t.icon, 24.dp, c)
                        // 빌드 27: 받은 응원 · 친구 요청이 있으면 설정 탭에 빨간 점 (친구 화면이 설정 안에 있음)
                        if (t.scr == Scr.Settings && Store.signedIn && (Store.unseenCheers > 0 || Store.incoming.isNotEmpty())) {
                            Box(Modifier.align(Alignment.TopEnd).offset(x = 3.dp, y = (-1).dp).size(8.dp).clip(CircleShape).background(C.bad))
                        }
                    }
                    // 글자: 높이 · 간격 · 투명도가 p 를 따라 조금씩 (아래로 내려가며 사라짐)
                    if (p > 0.01f) {
                        Box(Modifier.padding(top = 3.dp * p).height(13.dp * p).graphicsLayer {
                            alpha = p; translationY = (1f - p) * 6.dp.toPx()
                        }.clipToBounds(), contentAlignment = Alignment.TopCenter) {
                            T(t.label, F.t(11, W600, c), Modifier.requiredHeight(13.dp), maxLines = 1)
                        }
                    }
                }
            }
        }
        // 노란 선 (18 × 3, 둥근 끝, 옅은 노란 빛). 바 아래와 7(접힘 6) 떨어짐
        if (selected != null) {
            val lineW = 18.dp
            val lineH = 3.dp
            val bottomGap = 6.dp + 1.dp * p
            Box(
                Modifier.fillMaxSize().drawBehind {
                    val c = cell.toPx()
                    val x0 = side.toPx() + (edgeL.value + 0.5f) * c - lineW.toPx() / 2
                    val x1 = side.toPx() + (edgeR.value + 0.5f) * c + lineW.toPx() / 2
                    val left = minOf(x0, x1)
                    val w = maxOf(lineH.toPx(), x1 - x0)
                    val y = size.height - lineH.toPx() - bottomGap.toPx()
                    val r = androidx.compose.ui.geometry.CornerRadius(lineH.toPx() / 2)
                    // 빛 (반지름 4 그림자 흉내)
                    for (k in 1..3) {
                        val g = k * 1.5.dp.toPx()
                        drawRoundRect(C.accent.copy(alpha = 0.12f), Offset(left - g, y - g), Size(w + g * 2, lineH.toPx() + g * 2),
                            androidx.compose.ui.geometry.CornerRadius(lineH.toPx() / 2 + g))
                    }
                    drawRoundRect(C.accent, Offset(left, y), Size(w, lineH.toPx()), r)
                },
            )
        }
    }
}

/** 화면 맨 아래 띠: 아래로 갈수록 살짝 어두워짐 (탭 바와 겹친 글자가 읽히게) */
@Composable
fun TabFade(modifier: Modifier = Modifier) {
    Box(
        modifier.fillMaxWidth().height(96.dp + navBottom())
            .background(Brush.verticalGradient(0f to Color.Transparent, 0.5f to Color.Black.copy(alpha = 0.16f), 1f to Color.Black.copy(alpha = 0.32f))),
    )
}

/** 카드 안쪽 기본 여백 (좌우 16) — 탭 화면 공통 */
val PageSide = 16.dp

