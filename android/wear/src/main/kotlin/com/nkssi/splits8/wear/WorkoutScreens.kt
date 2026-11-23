package com.nkssi.splits8.wear

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.foundation.pager.VerticalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.CheerInput
import com.nkssi.splits8.shared.CheerPicker
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.IvStep
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RecordFlag
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.runMeters
import kotlinx.coroutines.delay
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

// 운동 중 (1.2.7 새 디자인 — 애플워치와 같은 규칙, 동그란 화면 자리는 splits8-1.2.7-갤럭시워치-화면.md).
// 위아래 페이지(베젤 · 크라운) = 실시간 · 목표 대비 · 심박/칼로리. 실시간에서 왼쪽으로 밀기 · 가운데 버튼 = 다음 구간,
// 오른쪽으로 밀기 = 조작 화면 (위에 덮임). 조작 화면에서 왼쪽으로 밀기 = 돌아감.

/** 베젤 아래 칸에서 크게 볼 것 (누르면 바뀜, 앱을 끄기 전까지 기억) */
private object WBig {
    var goal by mutableStateOf("vs")
    var stat by mutableStateOf("max")
}

@Composable
fun WWorkoutPager(buzz: (BuzzKind) -> Unit, startPage: Int = 0, startEnd: Boolean = false, startControls: Boolean = false) {
    val e = WatchStore.engine
    // 페이지: 실시간 · (목표 대비) · 심박/칼로리. 목표가 없는 운동은 목표 칸 없음
    val pages: List<String> = buildList { add("live"); if (e.hasGoalTotal) add("goal"); add("stats") }
    val pager = rememberPagerState(initialPage = startPage.coerceIn(0, pages.size - 1)) { pages.size }
    var endSheet by remember { mutableStateOf(startEnd) }
    var controls by remember { mutableStateOf(startControls) }
    val aod = LocalAod.current
    val flash = remember { Animatable(0f) }
    LaunchedEffect(e.advanceCount) {
        if (e.advanceCount == 0 || aod || e.isRunKind) return@LaunchedEffect      // 러닝 카드는 1 km 마다 번쩍이지 않음
        // 1.2.7: 구간 넘어갈 때 흰 번쩍임 (약하게)
        flash.snapTo(0f)
        flash.animateTo(1f, tween(60, easing = LinearEasing))
        delay(30)
        flash.animateTo(0f, tween(300))
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        VerticalPager(pager, Modifier.fillMaxSize()) { page ->
            when (pages.getOrNull(page)) {
                "goal" -> WGoalPage(page, pages.size)
                "stats" -> WStatsPage(page, pages.size)
                else -> WLive(onControls = { controls = true })
            }
        }
        AnimatedVisibility(controls && !aod, enter = slideInHorizontally(tween(220)) { -it } + fadeIn(tween(160)),
            exit = slideOutHorizontally(tween(220)) { -it } + fadeOut(tween(160))) {
            WControls(onBack = { controls = false }, onEnd = { controls = false; endSheet = true },
                onNext = { e.advance(); controls = false })
        }
        if (endSheet) {
            WEndSheet(
                onEnd = { endSheet = false; e.endNow() },
                onDiscard = { endSheet = false; e.discardNow(); WNav.open(null) },
                onResume = { endSheet = false },
                buzz = buzz,
            )
        }
        if (!aod && flash.value > 0f) Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.32f * flash.value)))
    }
}

// MARK: 실시간

/** 구간 색 (타이머 운동: 인터벌 빠르게 = 파랑, 천천히 · 걷기 · 휴식 = 회색, 그 밖 운동 = 노랑 / 휴식 = 회색) */
private fun toneNow(): WTone {
    val e = WatchStore.engine
    val cur = e.cur
    if (e.isRunKind) return WTone.Run
    if (Kinds.isNew(e.kind)) {
        if (cur.kind == SegKind.Rox) return WTone.Gray
        if (e.kind == Kinds.IVRUN) return if (cur.name == IvStep.typeName(IvStep.FAST)) WTone.Run else WTone.Gray
        if (e.kind == Kinds.EMOM && e.segWork.getOrNull(e.idx) != null) return WTone.Gray
        return WTone.Station
    }
    return WTone.of(cur)
}

@Composable
fun WLive(onControls: () -> Unit) {
    val e = WatchStore.engine
    val aod = LocalAod.current
    var now by remember { mutableLongStateOf(e.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(250) } }
    val swipePx = with(LocalDensity.current) { 40.dp.toPx() }
    val tone = toneNow()

    WCanvas(Modifier.testTag("w.live").pointerInput(Unit) {
        var dx = 0f
        detectHorizontalDragGestures(onDragStart = { dx = 0f }, onDragEnd = {
            if (abs(dx) >= swipePx) { if (dx < 0) mainAction() else onControls() }
        }) { _, d -> dx += d }
    }) { L ->
        WBackground(tone, if (e.isRunKind) 0 else e.idx, aod)
        val ink = if (aod) WAod.text else tone.ink
        WClock(L, if (aod) WAod.text else if (tone.dark) Color.Black else Color.White.copy(alpha = 0.86f))
        WTotalRow(L, if (e.isRunKind) "TIME" else "TOTAL", if (aod) Fm.t(e.total(now)).dropLast(2) + "––" else Fm.t(e.total(now)), tone, aod)
        when {
            e.isRunKind -> RunCard(L, now, tone, aod)
            Kinds.isNew(e.kind) -> TimerCard(L, now, tone, aod)
            else -> SegCard(L, now, tone, aod)
        }
        Buttons(L, tone, aod)
    }
}

/** 맨 위 "TOTAL 23:41" (높이 29, 이름표 8 + 값 13) */
@Composable
private fun WTotalRow(L: WScale, label: String, value: String, tone: WTone, aod: Boolean) {
    Row(Modifier.at(L.dx(WScale.D / 2), L.dy(29f)).testTag("w.total"), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(L.dv(4f))) {
        T(label, wf(L, 8f, W700, if (aod) WAod.text else tone.label, tracking = 0.6f), translate = false)
        T(value, wf(L, 13f, W600, if (aod) WAod.text else tone.ink, num = true).wShadow(tone, L, aod), translate = false)
    }
}

/** 레이스 · 풀시뮬 · PFT · 하이록스 트레이닝 · HIIT: [이름 · 무게/거리] · SPLIT GOAL ♥ BPM · 점 · Next */
@Composable
private fun SegCard(L: WScale, now: Long, tone: WTone, aod: Boolean) {
    val e = WatchStore.engine
    val cur = e.cur
    val el = e.segEl(now)
    val ink = if (aod) WAod.text else tone.ink
    val sub = if (aod) WAod.text else tone.sub
    val lab = if (aod) WAod.text else tone.label
    // 귀퉁이 표시 40 ~ 92 안: 이름 24 Bold (폭 136 안에 맞게 14 까지) + 9 + 무게/거리 13
    val y0 = 40f
    val y1 = 92f
    val info = detailLine(now)
    val ct = wCap(24f)
    val ci = wCap(13f)
    val tot = if (info.isEmpty()) ct else ct + 9f + ci
    val yy = (y0 + y1) / 2 - tot / 2
    WBrackets(L, y0, y1, if (aod) WAod.mark else tone.mark)
    WText(cur.name, wf(L, 24f, W700, ink).wShadow(tone, L, aod), L, WScale.D / 2, yy + ct / 2, 140f, minScale = 14f / 24f, tag = "w.segName")
    if (info.isNotEmpty()) WText(info, wf(L, 13f, W600, sub).wShadow(tone, L, aod), L, WScale.D / 2, yy + ct + 9f + ci / 2, 150f,
        minScale = 0.6f, tag = "w.detailLine")
    // 칸
    val isRun = cur.icon == "run"
    val over = cur.target > 0 && el > cur.target && cur.kind != SegKind.Rox
    val imp = e.settings.imperial
    val cols = ArrayList<Triple<String, String, String>>()
    cols.add(Triple(if (over) wt("OVER") + " " + Fm.d(el - cur.target) else "SPLIT", if (aod) Fm.t(el).dropLast(2) + "––" else Fm.t(el), "w.split"))
    when {
        isRun -> cols.add(Triple(if (curvedRun()) "PACE ≈" else "PACE", e.paceText(el, e.segDist, imp) ?: "--", "w.pace"))
        cur.target > 0 -> cols.add(Triple(if (e.mode == Mode.Training) "BEST" else "GOAL", Fm.t(cur.target), "w.goal"))
    }
    cols.add(Triple("♥ BPM", if (e.hr > 0) e.hr.roundToInt().toString() else "--", "w.bpm"))
    Cols(L, cols, 103f, 120f, 20f, ink, lab, tone, aod, overFirst = over)
    // 점 · HIIT 는 "3 rounds done"
    if (e.growsOpen) {
        WText(wt("%lld rounds done", e.idx), wf(L, 11f, W600, sub).wShadow(tone, L, aod), L, WScale.D / 2, 141f, 150f, translate = false)
    } else {
        val (n, c) = liveDots()
        if (n in 2..30) Dots(L, n, c, 141f, tone, aod)
    }
    NextLine(L, if (e.isLast) wt("Finish") else wt(e.nextSeg.name), tone, aod)
}

/** 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성: [단계 · 큰 숫자 · 단위나 할 일] · 횟수 ♥ BPM · 점 · Next */
@Composable
private fun TimerCard(L: WScale, now: Long, tone: WTone, aod: Boolean) {
    val e = WatchStore.engine
    val cur = e.cur
    val rest = cur.kind == SegKind.Rox
    val ink = if (aod) WAod.text else tone.ink
    val sub = if (aod) WAod.text else tone.sub
    val lab = if (aod) WAod.text else tone.label
    val imp = e.settings.imperial
    val el = e.segEl(now)
    var label: String
    var value: String
    var unit = ""
    var count = ""
    var countLabel = "ROUND"
    when (e.kind) {
        Kinds.AMRAP -> {
            label = wt("TIME LEFT")
            value = Fm.t(e.capLeft(now) ?: 0)
            unit = (wt("Round %lld", e.idx + 1) + " · " + Fm.t(el) + if (e.tasks.isEmpty()) "" else " · " + e.tasks.joinToString(" · "))
            count = "${e.idx}"
            countLabel = "ROUNDS"
        }
        Kinds.EMOM -> {
            val w = e.segWork.getOrNull(e.idx)
            label = if (w != null) wt("REST") else wt("ROUND")
            value = Fm.t(e.segLeft(now) ?: 0)
            unit = if (w != null) wt("Done in %@", Fm.t(w)) else e.tasks.joinToString(" · ")
            count = "${cur.rep ?: (e.idx + 1)}/${e.seq.size}"
        }
        Kinds.TABATA -> {
            label = if (rest) wt("REST") else wt("WORK")
            value = Fm.t(e.segLeft(now) ?: 0)
            count = "${cur.rep ?: 1}/${e.seq.count { it.icon == "hiit" }}"
        }
        Kinds.LIFT -> {
            label = if (rest) wt("REST") else wt(cur.name).uppercase(Locale.getDefault())
            value = if (rest) Fm.t(e.segLeft(now) ?: 0) else Fm.t(el)
            unit = if (rest) "" else liftLine(cur.reps, cur.kg)
            count = if (rest) "" else cur.detail.removePrefix("SET ")
            countLabel = "SET"
        }
        else -> {                                                       // 인터벌 러닝
            val distLen = Bonus.distLen(e.kind, cur)
            val nm = wt(cur.name).uppercase(Locale.getDefault())
            if (distLen != null) {
                label = nm + " · " + distLen.roundToInt() + " m"
                value = "${max(0.0, distLen - e.segDist).roundToInt()}"
                unit = "M"
            } else {
                label = nm + (Bonus.timedLen(e.kind, cur)?.let { " · $it s" } ?: "")
                value = Fm.t(e.segLeft(now) ?: 0)
            }
            count = cur.rep?.let { r -> "$r/${e.seq.mapNotNull { it.rep }.maxOrNull() ?: r}" } ?: ""
            countLabel = "REP"
        }
    }
    // 귀퉁이 표시 40 ~ 96 안: 단계 11 · 큰 숫자 32 · 단위나 할 일 10
    val y0 = 40f
    val y1 = 96f
    val ca = wCap(11f)
    val cb = wCap(32f)
    val cw = wCap(10f)
    val tot = ca + 7f + cb + if (unit.isEmpty()) 0f else 6f + cw
    val yy = (y0 + y1) / 2 - tot / 2
    WBrackets(L, y0, y1, if (aod) WAod.mark else tone.mark)
    WText(label, wf(L, 11f, W700, sub, tracking = 0.6f).wShadow(tone, L, aod), L, WScale.D / 2, yy + ca / 2, 140f)
    WText(if (aod && value.contains(':')) value.dropLast(2) + "––" else value, wf(L, 32f, W700, ink, num = true).wShadow(tone, L, aod), L,
        WScale.D / 2, yy + ca + 7f + cb / 2, 140f, minScale = 0.55f, tag = "w.bonusBig")
    if (unit.isNotEmpty()) WText(unit, wf(L, 10f, W700, sub, tracking = 0.4f).wShadow(tone, L, aod), L, WScale.D / 2,
        yy + ca + 7f + cb + 6f + cw / 2, 150f, tag = "w.detailLine")
    val cols = ArrayList<Triple<String, String, String>>()
    if (count.isNotEmpty()) cols.add(Triple(countLabel, count, "w.count"))
    cols.add(Triple("♥ BPM", if (e.hr > 0) e.hr.roundToInt().toString() else "--", "w.bpm"))
    Cols(L, cols, 106f, 122f, 18f, ink, lab, tone, aod)
    // 점 ("3/8")
    val p = count.split("/")
    val a = p.getOrNull(0)?.toIntOrNull()
    val b = p.getOrNull(1)?.toIntOrNull()
    if (p.size == 2 && a != null && b != null && b in 2..30) Dots(L, b, max(0, a - 1), 141f, tone, aod)
    if (e.kind != Kinds.AMRAP) NextLine(L, timerNext() ?: wt("Finish"), tone, aod)
}

/** 러닝 카드: [카드 이름 · 거리 · KM] · PACE ♥ BPM · 진행 막대 · "Goal 5 km · Avg 5:14" */
@Composable
private fun RunCard(L: WScale, now: Long, tone: WTone, aod: Boolean) {
    val e = WatchStore.engine
    val imp = e.settings.imperial
    val ink = if (aod) WAod.text else tone.ink
    val sub = if (aod) WAod.text else tone.sub
    val lab = if (aod) WAod.text else tone.label
    val d = e.runDistance
    val total = e.total(now)
    val y0 = 40f
    val y1 = 96f
    val ca = wCap(11f)
    val cb = wCap(32f)
    val cw = wCap(10f)
    val tot = ca + 7f + cb + 6f + cw
    val yy = (y0 + y1) / 2 - tot / 2
    WBrackets(L, y0, y1, if (aod) WAod.mark else tone.mark)
    WText(e.title.ifEmpty { "Run" }, wf(L, 11f, W700, sub, tracking = 0.4f).wShadow(tone, L, aod), L, WScale.D / 2, yy + ca / 2, 140f, translate = false)
    WText(Units.dist(d, imp), wf(L, 32f, W700, ink, num = true).wShadow(tone, L, aod), L, WScale.D / 2, yy + ca + 7f + cb / 2, 140f, tag = "w.dist")
    WText(if (imp) "MI" else "KM", wf(L, 10f, W700, sub, tracking = 0.6f).wShadow(tone, L, aod), L, WScale.D / 2, yy + ca + 7f + cb + 6f + cw / 2, 60f)
    Cols(L, listOf(
        Triple(if (curvedRun()) "PACE ≈" else "PACE", e.paceText(total, d, imp) ?: "--", "w.pace"),
        Triple("♥ BPM", if (e.hr > 0) e.hr.roundToInt().toString() else "--", "w.bpm"),
    ), 106f, 122f, 18f, ink, lab, tone, aod)
    // 진행 막대 (목표 거리가 있을 때). 자유 러닝은 왔다 갔다
    val goal = e.runGoalKm * 1000.0
    val frac = if (goal > 0) (d / goal).coerceIn(0.0, 1.0).toFloat() else -1f
    val swing = ((total % 4) / 4f).let { if (it < 0.5f) it * 2 else 2 - it * 2 }
    Canvas(Modifier.fillMaxSize()) {
        val x0 = L.x(60f).dp.toPx()
        val x1 = L.x(167f).dp.toPx()
        val y = L.y(141f).dp.toPx()
        val th = L.v(4f).dp.toPx()
        drawRoundRect(if (aod) WAod.dotOff else tone.dotOff, Offset(x0, y - th / 2), Size(x1 - x0, th), CornerRadius(th / 2))
        val c = if (aod) WAod.text else ink
        if (frac >= 0f) drawRoundRect(c, Offset(x0, y - th / 2), Size((x1 - x0) * frac, th), CornerRadius(th / 2))
        else {
            val seg = (x1 - x0) * 0.3f
            drawRoundRect(c, Offset(x0 + (x1 - x0 - seg) * swing, y - th / 2), Size(seg, th), CornerRadius(th / 2))
        }
    }
    WText(runSummary(now), wf(L, 12f, W600, sub, num = true).wShadow(tone, L, aod), L, WScale.D / 2, 158f, 160f, tag = "w.runSummary")
}

/** 칸 (이름표 9 Bold · 값). 칸 사이 구분선 없음. overFirst = 첫 칸 이름표를 검정 굵게 (목표 넘김) */
@Composable
private fun Cols(L: WScale, cols: List<Triple<String, String, String>>, labelY: Float, valueY: Float, valueSize: Float,
                 ink: Color, lab: Color, tone: WTone, aod: Boolean, overFirst: Boolean = false) {
    val n = cols.size
    val x0 = if (n == 2) 50f else 30f
    val x1 = WScale.D - x0
    cols.forEachIndexed { i, (l, v, tag) ->
        val cx = x0 + (x1 - x0) * (i + 0.5f) / n
        val cw = (x1 - x0) / n - 4f
        WText(l, wf(L, 9f, W700, if (i == 0 && overFirst) ink else lab, tracking = 0.6f).wShadow(tone, L, aod), L, cx, labelY, cw + 8f)
        WText(v, wf(L, valueSize, W600, ink, num = true).wShadow(tone, L, aod), L, cx, valueY, cw, minScale = 0.55f, tag = tag)
    }
}

/** 진행 점: 지난 것 · 지금 막대(11) · 남은 것 (간격 6.5, 10개 이하면 9) */
@Composable
private fun Dots(L: WScale, n: Int, cur: Int, y: Float, tone: WTone, aod: Boolean) {
    Canvas(Modifier.fillMaxSize().testTag("w.dots")) {
        val k = L.v(1f).dp.toPx()
        val g = (if (n > 10) 6.5f else 9f) * k
        val wc = 11f * k
        val r = 1.7f * k
        val totW = g * (n - 1) + wc - 2 * r
        var x = L.x(WScale.D / 2).dp.toPx() - totW / 2
        val yy = L.y(y).dp.toPx()
        val ink = if (aod) WAod.text else tone.ink
        for (i in 0 until n) {
            if (i == cur) {
                drawRoundRect(ink, Offset(x - r, yy - r), Size(wc, 2 * r), CornerRadius(r))
                x += wc - 2 * r + g
            } else {
                drawCircle(if (i < cur) ink.copy(alpha = 0.59f) else if (aod) WAod.dotOff else tone.dotOff, r, Offset(x, yy))
                x += g
            }
        }
    }
}

/** "Next" 14 (반투명) + 다음 이름 Bold 14 (높이 158, 폭 172 안) */
@Composable
private fun NextLine(L: WScale, name: String, tone: WTone, aod: Boolean) {
    Row(Modifier.at(L.dx(WScale.D / 2), L.dy(158f)).widthIn(max = L.dv(172f)).testTag("w.nextName"), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(L.dv(6f))) {
        T("Next", wf(L, 14f, W600, if (aod) WAod.text else tone.sub).wShadow(tone, L, aod))
        T(name, wf(L, 14f, W700, if (aod) WAod.text else tone.ink).wShadow(tone, L, aod), Modifier.widthIn(max = L.dv(130f)), minScale = 10f / 14f, translate = false)
    }
}

/** 버튼 3개: 되돌리기 · 다음(→) · 일시정지 (가운데 r22 · 높이 194, 옆 r16 · ±50 · 높이 187). 러닝 카드는 가운데 일시정지 하나 */
@Composable
private fun Buttons(L: WScale, tone: WTone, aod: Boolean) {
    val e = WatchStore.engine
    val c = WScale.D / 2
    if (e.isRunKind) {
        WCircleButton(L, c, 194f, 22f, tone, aod, tag = "w.pauseLive", onClick = { e.togglePause() }) { p, col ->
            wPause(p, L.v(16f).dp.toPx(), col, !e.running)
        }
        return
    }
    WCircleButton(L, c - 50f, 187f, 16f, tone, aod, on = e.canUndo, tag = "w.undoLive", onClick = { e.undo() }) { p, col ->
        wUndo(p, L.v(16f).dp.toPx(), col)
    }
    val emomDone = Bonus.tapMarksDone(e.kind) && e.segWork.getOrNull(e.idx) != null
    WCircleButton(L, c, 194f, 22f, tone, aod, on = e.running && !emomDone, tag = "w.next", onClick = { mainAction() }) { p, col ->
        if (e.isLast || Bonus.tapMarksDone(e.kind)) wCheck(p, L.v(18f).dp.toPx(), col)
        else wArrow(p, L.v(20f).dp.toPx(), L.v(17f).dp.toPx(), col)
    }
    WCircleButton(L, c + 50f, 187f, 16f, tone, aod, tag = "w.pauseLive", onClick = { e.togglePause() }) { p, col ->
        wPause(p, L.v(13f).dp.toPx(), col, !e.running)
    }
}

/** 가운데 버튼 · 왼쪽으로 밀기: 다음 구간 (EMOM 은 이 라운드 할 일 끝냄, 러닝 카드는 아무것도 안 함) */
private fun mainAction() {
    val e = WatchStore.engine
    if (e.isRunKind || !e.running) return
    if (Bonus.tapMarksDone(e.kind) && e.segWork.getOrNull(e.idx) != null) return
    e.advance()
}

/** 진행 점 (Roxzone · 휴식은 빼고 셈): (모두, 지금 몇 번째 0부터) */
private fun liveDots(): Pair<Int, Int> {
    val e = WatchStore.engine
    val all = e.seq.count { it.kind != SegKind.Rox }
    val before = e.seq.take(e.idx).count { it.kind != SegKind.Rox }
    return all to before.coerceAtMost(all - 1)
}

/** 타이머 운동 다음 단계 이름 ("Rest 10 s" · "Easy 0:40" · "Round 5" · "Squat · set 2"). 마지막이면 null */
private fun timerNext(): String? {
    val e = WatchStore.engine
    val n: Seg = e.seq.getOrNull(e.idx + 1) ?: return null
    return when (e.kind) {
        Kinds.IVRUN -> {
            val dl = Bonus.distLen(e.kind, n)
            wt(n.name) + " " + (if (dl != null) "${dl.roundToInt()} m" else Fm.t(Bonus.timedLen(e.kind, n) ?: n.target))
        }
        Kinds.LIFT -> if (n.kind == SegKind.Rox) wt("Rest") + " " + Fm.t(n.target) else wt(n.name) + " · " + wt("set %lld", n.rep ?: 1)
        Kinds.TABATA -> if (n.kind == SegKind.Rox) wt("Rest") + " ${n.target} s" else wt("Work") + " ${n.target} s"
        else -> wt("Round %lld", n.rep ?: (e.idx + 2))
    }
}

/** 러닝 카드 아래 줄: "Goal 5 km · Avg 5:12" (자유 러닝은 평균만) */
private fun runSummary(now: Long): String {
    val e = WatchStore.engine
    val imp = e.settings.imperial
    val parts = ArrayList<String>()
    if (e.runGoalKm > 0) parts.add(if (imp) wt("Goal %@ mi", Units.dist(e.runGoalKm * 1000.0, true)) else wt("Goal %@ km", "${e.runGoalKm}"))
    val d = e.runDistance
    if (d >= 200) {
        val avg = Units.pace((e.total(now) / d * 1000).roundToInt(), imp)
        if (avg in 1 until 3600) parts.add(wt("Avg %@", Fm.t(avg)))
    }
    return parts.joinToString(" · ")
}

/** 기능성 운동 세트 줄: "5 × 80 kg" */
private fun liftLine(reps: Int?, kg: Double?): String {
    val r = reps ?: return ""
    return if ((kg ?: 0.0) > 0) "$r × " + Bonus.kgText(kg ?: 0.0) else wt("%lld reps", r)
}

/** 아래 줄: 러닝 = "0.38 / 1.00 km", 스테이션 = 무게 · 거리 (더블 계획이 있으면 교대 줄), Roxzone = Transition, 휴식 = 없음 */
private fun detailLine(now: Long): String {
    val e = WatchStore.engine
    val cur = e.cur
    if (cur.icon == "run") return runLine()
    if (cur.icon == "rest") return ""
    if (cur.kind == SegKind.Rox) return wt("Transition")
    if (e.isHIIT) return ""
    // 1.2.1: 교대 줄은 시뮬 · 레이스에서만
    if (e.mode != Mode.Training) doublesLine(cur, WatchStore.ctx.doublesPlan, e.settings.division)?.let { return it }
    return Units.detail(cur.detail, e.settings.imperial)
}

/** 러닝 아래 줄: "0.62 / 1.00 km" */
private fun runLine(): String {
    val e = WatchStore.engine
    val imp = e.settings.imperial
    val segM = runMeters(e.cur.detail)
    val unit = if (imp) "mi" else "km"
    return Units.dist(minOf(segM, e.segDist), imp) + " / " + Units.dist(segM, imp) + " " + unit
}

private fun curvedRun(): Boolean = WatchStore.engine.settings.runMode == "curved" && WatchStore.engine.mode != Mode.Race

// MARK: 베젤 ↓ 1칸 · 2칸 (목표 대비 · 심박/칼로리)

private data class InfoItem(val key: String, val label: String, val value: String, val word: String)

@Composable
fun WGoalPage(page: Int, pages: Int) {
    val e = WatchStore.engine
    var now by remember { mutableLongStateOf(e.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(1000) } }
    val d = e.delta(now)
    val vsBest = e.mode == Mode.Training || e.mode == Mode.Pft
    val items = listOf(
        InfoItem("vs", if (vsBest) "VS BEST" else "VS GOAL", Fm.d(d), if (d < 0) "AHEAD" else if (d > 0) "BEHIND" else "ON PACE"),
        InfoItem("finish", "FINISH", Fm.t(e.projectedFinish(now)), "EST"),
        InfoItem("goal", if (vsBest) "BEST" else "GOAL", Fm.t(e.targetTotal), ""),
    )
    InfoFrame(items, WBig.goal, { WBig.goal = it }, "vs", page, pages, now, "w.goalPage")
}

@Composable
fun WStatsPage(page: Int, pages: Int) {
    val e = WatchStore.engine
    var now by remember { mutableLongStateOf(e.now()) }
    LaunchedEffect(Unit) { while (true) { now = WatchStore.engine.now(); delay(1000) } }
    val mx = e.maxHRNow
    val items = ArrayList<InfoItem>()
    items.add(InfoItem("max", "MAX HR", if (mx > 0) "$mx" else "--", "BPM"))
    items.add(InfoItem("kcal", "ENERGY", "${e.kcal.roundToInt()}", "KCAL"))
    val runs = e.isRunKind || Kinds.runLike(e.kind) || e.cur.icon == "run"
    if (runs) items.add(InfoItem("third", "CADENCE", e.cadenceNow(now)?.toString() ?: "--", "SPM"))
    else {
        val a = e.avgHRLive
        items.add(InfoItem("third", "AVG BPM", if (a > 0) "$a" else "--", "BPM"))
    }
    InfoFrame(items, WBig.stat, { WBig.stat = it }, "max", page, pages, now, "w.statsPage")
}

/** [이름표 11 · 큰 숫자 42 · 작은 말 10] + 두 칸 (± 42). 칸을 누르면 큰 자리와 바뀜, 큰 숫자를 누르면 처음대로 */
@Composable
private fun InfoFrame(items: List<InfoItem>, bigKey: String, setBig: (String) -> Unit, def: String, page: Int, pages: Int, now: Long, tag: String) {
    val e = WatchStore.engine
    val aod = LocalAod.current
    val tone = toneNow()
    val big = items.firstOrNull { it.key == bigKey } ?: items[0]
    val rest = items.filter { it.key != big.key }
    WCanvas(Modifier.testTag(tag)) { L ->
        WBackground(tone, if (e.isRunKind) 0 else e.idx, aod)
        val ink = if (aod) WAod.text else tone.ink
        val sub = if (aod) WAod.text else tone.sub
        val lab = if (aod) WAod.text else tone.label
        WClock(L, if (aod) WAod.text else if (tone.dark) Color.Black else Color.White.copy(alpha = 0.86f))
        WTotalRow(L, if (e.isRunKind) "TIME" else "TOTAL", Fm.t(e.total(now)), tone, aod)
        val p = 10f
        val ca = wCap(11f)
        val cb = wCap(42f)
        val cw = wCap(10f)
        val blk = p + ca + 8f + cb + 8f + cw + p
        val colh = wCap(9f) + 7f + wCap(18f)
        val tot = blk + 12f + colh
        val y = (38f + (WScale.D - 22f)) / 2 - tot / 2
        WBrackets(L, y, y + blk, if (aod) WAod.mark else tone.mark)
        WText(big.label, wf(L, 11f, W700, sub, tracking = 0.6f).wShadow(tone, L, aod), L, WScale.D / 2, y + p + ca / 2, 140f)
        WText(big.value, wf(L, 42f, W700, ink, num = true).wShadow(tone, L, aod), L, WScale.D / 2, y + p + ca + 8f + cb / 2, 130f, minScale = 0.55f, tag = "$tag.big")
        if (big.word.isNotEmpty()) WText(big.word, wf(L, 10f, W700, lab, tracking = 0.6f).wShadow(tone, L, aod), L, WScale.D / 2,
            y + p + ca + 8f + cb + 8f + cw / 2, 140f)
        // 큰 숫자 누르면 처음대로
        Box(Modifier.at(L.dx(WScale.D / 2), L.dy(y + blk / 2)).size(L.dv(140f), L.dv(blk))
            .clickable(remember { MutableInteractionSource() }, indication = null) { if (bigKey != def) setBig(def) })
        val yc = y + blk + 12f
        rest.take(2).forEachIndexed { i, item ->
            val cx = WScale.D / 2 + (if (i == 0) -42f else 42f)
            WText(item.label, wf(L, 9f, W700, lab, tracking = 0.6f).wShadow(tone, L, aod), L, cx, yc + wCap(9f) / 2, 80f)
            WText(item.value, wf(L, 18f, W600, ink, num = true).wShadow(tone, L, aod), L, cx, yc + wCap(9f) + 7f + wCap(18f) / 2, 76f, minScale = 0.6f)
            Box(Modifier.at(L.dx(cx), L.dy(yc + colh / 2)).size(L.dv(78f), L.dv(colh + 14f)).testTag("$tag.${item.key}")
                .clickable(remember(item.key) { MutableInteractionSource() }, indication = null) { setBig(item.key) })
        }
        PageDots(L, page, pages, ink)
    }
}

/** 몇 번째 칸인지 = 오른쪽 가장자리 점 (베젤 따라) */
@Composable
private fun PageDots(L: WScale, page: Int, pages: Int, ink: Color) {
    Canvas(Modifier.fillMaxSize()) {
        val c = Offset(L.x(WScale.D / 2).dp.toPx(), L.y(WScale.D / 2).dp.toPx())
        val rr = L.v(WScale.D / 2 - 7f).dp.toPx()
        for (i in 0 until pages) {
            val ang = Math.toRadians((-8.0 * (pages - 1) / 2) + i * 8.0)
            val p = Offset(c.x + rr * cos(ang).toFloat(), c.y + rr * sin(ang).toFloat())
            drawCircle(ink.copy(alpha = if (i == page) 1f else 0.43f), L.v(if (i == page) 2.6f else 1.6f).dp.toPx(), p)
        }
    }
}

// MARK: 조작 (오른쪽으로 밀기)

/** End · Pause · Undo | Skip · Next 4줄 (높이 32 · 간격 6). 줄마다 그 높이의 동그라미 폭 − 좌우 10 (최대 152) */
@Composable
fun WControls(onBack: () -> Unit, onEnd: () -> Unit, onNext: () -> Unit) {
    val e = WatchStore.engine
    val swipePx = with(LocalDensity.current) { 40.dp.toPx() }
    val tone = toneNow()
    WCanvas(Modifier.testTag("w.controls").pointerInput(Unit) {
        var dx = 0f
        detectHorizontalDragGestures(onDragStart = { dx = 0f }, onDragEnd = { if (dx <= -swipePx) onBack() }) { _, d -> dx += d }
    }.clickable(remember { MutableInteractionSource() }, indication = null) { }) { L ->
        WBackground(tone, if (e.isRunKind) 0 else e.idx, false, darker = 0.12f)
        WClock(L, if (tone.dark) Color.Black else Color.White)
        val hgt = 32f
        val g = 6f
        val tot = 4 * hgt + 3 * g
        val y0 = (24f + (WScale.D - 14f)) / 2 - tot / 2
        val ys = List(4) { y0 + it * (hgt + g) }
        fun rw(i: Int): Float = L.rowW(ys[i], ys[i] + hgt, 10f)
        val c = WScale.D / 2
        val glass = Color.White.copy(alpha = tone.glass)
        // End
        val w0 = rw(0)
        WPill(L, c - w0 / 2, ys[0], w0, hgt, hex(0xFF3B30, 0.59f), 0.22f, "w.end", onClick = onEnd) {
            PillLabel(L, "End", Color.White) { p, col -> wEndMark(p, L.v(13f).dp.toPx(), col) }
        }
        // Pause / Resume
        val w1 = rw(1)
        WPill(L, c - w1 / 2, ys[1], w1, hgt, glass, 0.55f, "w.pause", onClick = { e.togglePause() }) {
            PillLabel(L, if (e.running) "Pause" else "Resume", tone.ink) { p, col -> wPause(p, L.v(11f).dp.toPx(), col, !e.running) }
        }
        // Undo | Skip
        val w2 = rw(2)
        val hf = (w2 - g) / 2
        val un = e.canUndo
        WPill(L, c - w2 / 2, ys[2], hf, hgt, glass.copy(alpha = if (un) tone.glass else tone.glass * 0.45f), 0.55f, "w.undo", enabled = un,
            onClick = { e.undo(); onBack() }) {
            PillLabel(L, "Undo", tone.ink.copy(alpha = if (un) 1f else 0.4f)) { p, col -> wUndo(p, L.v(13f).dp.toPx(), col) }
        }
        val sk = e.canSkip
        WPill(L, c + w2 / 2 - hf, ys[2], hf, hgt, glass.copy(alpha = if (sk) tone.glass else tone.glass * 0.45f), 0.55f, "w.skip", enabled = sk,
            onClick = { e.skip(); onBack() }) {
            PillLabel(L, "Skip", tone.ink.copy(alpha = if (sk) 1f else 0.4f)) { p, col -> wSkip(p, L.v(11f).dp.toPx(), col) }
        }
        // Next
        val w3 = rw(3)
        val nOn = e.running && !e.isRunKind
        WPill(L, c - w3 / 2, ys[3], w3, hgt, tone.nextBg, 0.22f, "w.controlsNext", enabled = nOn, onClick = onNext) {
            PillLabel(L, "Next", tone.nextFg.copy(alpha = if (nOn) 1f else 0.4f)) { p, col -> wArrow(p, L.v(12f).dp.toPx(), L.v(12f).dp.toPx(), col) }
        }
    }
}

@Composable
private fun PillLabel(L: WScale, text: String, color: Color, icon: androidx.compose.ui.graphics.drawscope.DrawScope.(Offset, Color) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(L.dv(5f))) {
        Canvas(Modifier.size(L.dv(13f))) { icon(center, color) }
        T(text, wf(L, 14f, W600, color))
    }
}

// MARK: 끝내기 확인

/** 제목 "End workout?" → [SEGMENTS DONE · 9 / 16 · REST WON'T BE SAVED] → Discard | Resume → ✓ Save & end (아래 끝 버튼) */
@Composable
fun WEndSheet(onEnd: () -> Unit, onDiscard: () -> Unit, onResume: () -> Unit, buzz: (BuzzKind) -> Unit) {
    val e = WatchStore.engine
    var ask by remember { mutableStateOf(false) }
    WCanvas(Modifier.background(Color.Black).clickable(remember { MutableInteractionSource() }, indication = null) { }.testTag("w.endSheet")) { L ->
        WMenuBackground(61)
        WClock(L, Color.White)
        WMenuTitle(L, if (ask) "Discard this workout?" else "End workout?")
        val hb = 32f
        val g = 6f
        val eb = 172f
        val yb1 = eb - 8f - hb
        val done = e.seq.take(e.idx).count { it.kind != SegKind.Rox }
        val all = e.seq.count { it.kind != SegKind.Rox }
        val (label, value, word, col) = when {
            ask -> Quad("TOTAL", Fm.t(e.total()), "NOTHING WILL BE SAVED", hex(0xFF6B60))
            e.growsOpen || Kinds.isNew(e.kind) -> Quad("TOTAL", Fm.t(e.total()), "EVERYTHING WILL BE SAVED", Color.White)
            else -> Quad("SEGMENTS DONE", "$done / $all", if (done < all) "REST WON'T BE SAVED" else "", Color.White)
        }
        WBlock(L, 45f, yb1 - 4f, label, value, word, col, 32f, 9f, 7f, 40f)
        val w = L.rowW(yb1, yb1 + hb, 10f)
        val hf = (w - g) / 2
        val c = WScale.D / 2
        if (ask) {
            WPill(L, c - w / 2, yb1, w, hb, Color.White.copy(alpha = 0.13f), 0.55f, "w.discardCancel", onClick = { ask = false }) {
                T("Cancel", wf(L, 13f, W600, Color.White))
            }
            WEdgeButton(L, "Discard", null, "w.discardConfirm", red = true, onClick = onDiscard)
        } else {
            WPill(L, c - w / 2, yb1, hf, hb, hex(0xFF3B30, 0.59f), 0.22f, "w.discard", onClick = { buzz(BuzzKind.Click); ask = true }) {
                T("Discard", wf(L, 13f, W600, Color.White))
            }
            WPill(L, c + w / 2 - hf, yb1, hf, hb, Color.White.copy(alpha = 0.13f), 0.55f, "w.resume", onClick = onResume) {
                T("Resume", wf(L, 13f, W600, Color.White))
            }
            WEdgeButton(L, "Save & end", "check", "w.endConfirm", onClick = onEnd)
        }
    }
}

private data class Quad(val a: String, val b: String, val c: String, val d: Color)

/** 귀퉁이 표시 안 블록 [이름표 10 · 큰 숫자 · 작은 말 9]: top ~ bottom 의 세로 가운데. 반환 = (위, 아래) */
@Composable
fun WBlock(L: WScale, top: Float, bottom: Float, label: String, value: String, word: String, color: Color = Color.White,
           valueSize: Float = 34f, pad: Float = 10f, inner: Float = 7f, bm: Float = 40f, center: Float? = null): Pair<Float, Float> {
    val ca = wCap(10f)
    val cb = wCap(valueSize)
    val cw = wCap(9f)
    val blk = pad + ca + inner + cb + (if (word.isEmpty()) 0f else inner + cw) + pad
    val y = (center ?: ((top + bottom) / 2)) - blk / 2
    WBrackets(L, y, y + blk, Color.White.copy(alpha = 0.47f))
    WText(label, wf(L, 10f, W700, Color.White.copy(alpha = 0.65f), tracking = 0.6f), L, WScale.D / 2, y + pad + ca / 2, 140f)
    WText(value, wf(L, valueSize, W700, color, num = true), L, WScale.D / 2, y + pad + ca + inner + cb / 2, 140f, minScale = 0.6f, tag = "w.blockValue")
    if (word.isNotEmpty()) WText(word, wf(L, 9f, W700, Color.White.copy(alpha = 0.55f), tracking = 0.5f), L, WScale.D / 2,
        y + pad + ca + inner + cb + inner + cw / 2, 150f)
    return y to y + blk
}

// MARK: 요약

/** 제목 → 응원 한 줄 → [TOTAL 1:18:42 · −1:18 VS GOAL] → About top 12% → ✓ Done. 아래로 돌리면 AVG · MAX · KCAL · 구간 기록 */
@Composable
fun WSummary() {
    val e = WatchStore.engine
    val r = e.lastRecord ?: return
    val state = rememberScalingLazyListState(initialCenterItemIndex = 0, initialCenterItemScrollOffset = 0)
    Box(Modifier.fillMaxSize().testTag("w.summary")) {
        WMenuBackground(62)
        ScalingLazyColumn(Modifier.fillMaxSize(), state = state,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            anchorType = androidx.wear.compose.foundation.lazy.ScalingLazyListAnchorType.ItemStart,
            autoCentering = null,
            scalingParams = androidx.wear.compose.foundation.lazy.ScalingLazyColumnDefaults.scalingParams(edgeScale = 1f, edgeAlpha = 1f)) {
            item { SummaryFirst(r) }
            item { Stats(r) }
            item {
                Column(Modifier.fillMaxWidth(0.82f).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.08f)).padding(vertical = 4.dp)) {
                    for (s in r.segs.filter { it.kind != SegKind.Rox }) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 3.dp, horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon8(s.icon, 12.dp, Tint.Yellow)
                            T(s.name, F.t(12), Modifier.weight(1f), align = TextAlign.Start, minScale = 0.85f, translate = false)
                            T(Fm.t(s.time), F.num(12, W500), translate = false)
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(40.dp)) }
        }
    }
}

@Composable
private fun SummaryFirst(r: Record) {
    val e = WatchStore.engine
    val cfg = androidx.compose.ui.platform.LocalConfiguration.current
    val side = min(cfg.screenWidthDp, cfg.screenHeightDp).dp
    Box(Modifier.size(side)) {
        WCanvas { L ->
            WClock(L, Color.White)
            WMenuTitle(L, if (r.mode == Mode.Training) r.title else r.mode.title, translate = r.mode != Mode.Training)
            val tg = r.vsTarget ?: r.total
            val rank: String? = if ((r.mode == Mode.Race || r.mode == Mode.Sim) && r.splits16 != null)
                com.nkssi.splits8.shared.HyroxRank.of(r.division, r.total)?.let { rk ->
                    rk.pct?.let { com.nkssi.splits8.shared.L10n.t("About top %d%%", it) } ?: com.nkssi.splits8.shared.L10n.t(rk.level)
                } else null
            val extra: String? = bonusSummary(r)
            // 응원 · 블록 · (등급/종류/등수) 를 45 ~ 168 사이 가운데
            val c0 = wCap(12f)
            val p = 9f
            val blk = p + wCap(10f) + 7f + wCap(34f) + (if (r.vsTarget != null) 7f + wCap(9f) else 0f) + p
            val tail = listOfNotNull(rank, extra).size * (wCap(12f) + 10f) + (if (r.pftGrade != null) 32f else 0f)
            val tot = c0 + 10f + blk + tail
            var y = (45f + 168f) / 2 - tot / 2
            WText(cheer(r), wf(L, 12f, W600, C.accent), L, WScale.D / 2, y + c0 / 2, 170f, minScale = 0.7f, tag = "w.cheer")
            y += c0 + 10f
            val word = if (r.vsTarget != null) Fm.d(r.total - tg) + " " + wt(r.vsWord) else ""
            val (_, yb) = WBlock(L, y, y + blk, "TOTAL", Fm.t(r.total), word, Color.White, 34f, 9f, 7f, 36f, center = y + blk / 2)
            y = yb + 10f
            r.pftGrade?.let { g ->
                Box(Modifier.at(L.dx(WScale.D / 2), L.dy(y + 11f))) { PFTBadge(g, L.dv(78f), L.dv(22f), 12f * L.s) }
                y += 32f
            }
            for (line in listOfNotNull(extra, rank)) {
                WText(line, wf(L, 12f, W600, C.accent), L, WScale.D / 2, y + wCap(12f) / 2, 170f, minScale = 0.7f, tag = if (line == rank) "w.rank" else null)
                y += wCap(12f) + 10f
            }
            WEdgeButton(L, "Done", "check", "w.done", onClick = { e.reset(); WNav.open(null) })
        }
    }
}

@Composable
private fun Stats(r: Record) {
    Row(Modifier.fillMaxWidth(0.82f).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.08f)).padding(vertical = 7.dp, horizontal = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for ((l, v, c) in listOf(
            Triple("AVG", if (r.avgHR > 0) "${r.avgHR}" else "--", C.hr),
            Triple("MAX", if (r.maxHR > 0) "${r.maxHR}" else "--", C.hr),
            Triple("KCAL", String.format(Locale.US, "%,d", r.kcal), Color.White),
        )) {
            Column(Modifier.weight(1f)) {
                T(l, F.t(11, W600, C.text2, tracking = 0.64f), Modifier.fillMaxWidth(), align = TextAlign.Start)
                T(v, F.num(14, color = c), Modifier.fillMaxWidth(), align = TextAlign.Start, translate = false)
            }
        }
    }
}

/** 18번 요약 한 줄 (번역됨). AMRAP 은 라운드 수 + "남은 동작은 폰에서", 기능성 운동은 총 볼륨 */
private fun bonusSummary(r: Record): String? = when (r.kind) {
    Kinds.AMRAP -> Bonus.amrapScore(r) + " · " + wt("Add extra reps on your phone")
    Kinds.LIFT -> wt("Volume %@", Bonus.kgText(Bonus.volume(r)))
    else -> Bonus.kindLine(r)
}

/** 워치가 아는 것: 내 최고 Full Sim · 최고 PFT · 레이스 목표 · 대회 날짜 · 심박 */
fun cheer(r: Record): String {
    val ctx = WatchStore.ctx
    var x = CheerInput(r.mode, r.title, r.total, r.isComplete, r.flag == RecordFlag.Check, r.date, r.end, CheerPicker.seed(r.id),
        isHIIT = r.isHIIT, isRun = r.isRunKind, hiitRounds = if (r.isHIIT) r.segs.size else 0,
        runKm = r.runs.sumOf { it.dist ?: runMeters(it.detail) } / 1000, hiShare = CheerPicker.hiShare(r.hr, ctx.settings))
    if (r.mode == Mode.Race) (r.goal ?: r.vsTarget)?.let { g -> x = x.copy(goalDelta = r.total - g) }
    val sb = ctx.simBestTotal
    if (r.mode == Mode.Sim && sb != null && r.total < sb && r.counts) x = x.copy(pbDelta = r.total - sb)
    if (r.mode == Mode.Sim && sb == null && r.splits16 != null) x = x.copy(firstFullSim = true)
    if (r.mode == Mode.Pft) {
        val prev = ctx.pftBestTotal ?: ctx.pftBest?.sum()
        x = x.copy(pftPrevBest = prev, pftEverGold = (prev ?: Int.MAX_VALUE) < PFT.goldLimit)
    }
    val ev = ctx.settings.event
    if (ev.isSet) {
        val d = ChronoUnit.DAYS.between(r.date.atZone(Fm.zone).toLocalDate(), ev.date.atZone(Fm.zone).toLocalDate()).toInt()
        if (d >= 0) x = x.copy(daysToRace = d)
    }
    return CheerPicker.pick(x).line
}
