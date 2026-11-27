package com.nkssi.splits8.screens

import android.view.HapticFeedbackConstants
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.WatchMirror
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.LiveState
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.FD
import com.nkssi.splits8.ui.GrayPill
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.delay

// 워치 운동을 폰에서 같이 보기 (아이폰 WatchLiveView.swift, 빌드 24 머리 · SPLIT | GOAL).
// 폰에서 누른 Next · Undo · Pause · End 는 워치로 보냄. 기록의 기준은 워치.

/** 워치에서 받은 상태 → 화면 한 장면 */
fun watchFrame(st: LiveState, nowMs: Long, receivedMs: Long): LiveFrame8 = LiveFrame8(
    mode = st.mode, title = st.title, seq = st.seq, idx = st.idx,
    segEl = st.segEl(nowMs, receivedMs), total = st.total(nowMs, receivedMs), running = st.running, open = st.open,
    segDist = st.segDist, totalDist = st.dist,
    speed = if (st.running) st.spd else null,
    imperial = com.nkssi.splits8.Store.settings.imperial,
    runCard = isRunCard(st), runGoalKm = if (isRunCard(st) && !st.open) st.seq.size else 0,
    splits = st.splits, hr = st.hr, zone = st.zone, kcal = st.kcal,
)

/** 1.2.2: 워치의 러닝 카드인지 (구간이 모두 "KM n" 러닝) */
private fun isRunCard(st: com.nkssi.splits8.shared.LiveState): Boolean =
    st.mode == com.nkssi.splits8.shared.Mode.Training && st.seq.isNotEmpty() && st.seq.all { it.icon == "run" && it.name.startsWith("KM ") }

/** 받은 심박으로 세는 최고 · 평균 (워치가 보내는 상태에는 없음) */
private object WatchHR {
    var max by androidx.compose.runtime.mutableIntStateOf(0)
    var sum = 0L
    var n = 0
    var lastAt = 0L
}

@Composable
fun WatchLiveView() {
    val st = WatchMirror.state
    val view = LocalView.current
    var now by remember { mutableLongStateOf(WatchMirror.clock()) }
    LaunchedEffect(Unit) { while (true) { now = WatchMirror.clock(); delay(250) } }
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
    BackAction { Router.go(Scr.Home) }
    // 최고 · 평균 심박 (1초에 한 번 셈)
    LaunchedEffect(st?.hr, now / 1000) {
        val hr = st?.hr ?: 0
        if (hr > 0 && now / 1000 != WatchHR.lastAt) { WatchHR.lastAt = now / 1000; WatchHR.max = maxOf(WatchHR.max, hr); WatchHR.sum += hr; WatchHR.n++ }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val L = PL(maxWidth.value, maxHeight.value)
        if (st == null) {
            Box(Modifier.fillMaxSize().background(Color.Black))
            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                T("Connecting to your watch…", FD.t(15, color = C.dText2), maxLines = 1)
            }
            return@BoxWithConstraints
        }
        val f = watchFrame(st, now, WatchMirror.received)
        val status = if (WatchMirror.reconnecting) "Watch · Reconnecting…"
            else if (st.hr > 0) "Watch".l10n + " · ${st.hr} " + "BPM".l10n else "Watch · Live"
        LiveBackground8(f.tone, if (isRunCard(st)) 1 else st.idx, f.zone)
        when {
            // 워치에서 버림: 기록이 안 오니 잠시 뒤 홈으로
            WatchMirror.discarded -> {}
            st.finished || WatchMirror.ended -> {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)))
                Saving(Modifier.fillMaxSize().padding(top = L.dy(150f)))
            }
            else -> {
                val count = if (isRunCard(st)) 2 else 3
                val pager = rememberPagerState(pageCount = { count })
                HorizontalPager(pager, Modifier.fillMaxSize().testTag("watchLive.pages")) { page ->
                    when (page) {
                        0 -> LiveMain8(f, L, "watchLive")
                        1 -> LiveGoalPage8(f, L, WatchHR.max, if (WatchHR.n > 0) (WatchHR.sum / WatchHR.n).toInt() else null)
                        else -> LiveSegmentList8(L, f.tone, st.seq, st.idx, st.splits, emptySet(), f.segEl, st.vsWord)
                    }
                }
                LivePageDots8(L, count, pager.currentPage, f.tone)
                Buttons(st, f, L) { strong -> view.performHapticFeedback(if (strong) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.VIRTUAL_KEY) }
            }
        }
        LiveTop8(f, L, status, !WatchMirror.reconnecting, "watchLive")
    }
}

/** ♥ 165 BPM [Z4] · 286 KCAL */
@Composable
private fun Chips(st: LiveState, modifier: Modifier) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
        Row(Modifier.height(32.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Sym(R.drawable.sym_heart, 12.dp, C.hr)
            T(if (st.hr > 0) "${st.hr}" else "--", FD.num(15), Modifier.testTag("watchLive.hr"), maxLines = 1, translate = false)
            T("BPM", FD.t(10, W600, C.dText2), maxLines = 1, translate = false)
            if (st.zone > 0) {
                Box(Modifier.height(16.dp).clip(RoundedCornerShape(4.dp)).background(C.zone(st.zone)).padding(horizontal = 5.dp),
                    contentAlignment = Alignment.Center) { T("Z${st.zone}", FD.t(10, W700, Color.Black), maxLines = 1, translate = false) }
            }
        }
        Row(Modifier.height(32.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            T("${st.kcal}", FD.num(15), maxLines = 1, translate = false)
            T("KCAL", FD.t(10, W600, C.dText2), maxLines = 1, translate = false)
        }
    }
}

/** 아래 단추 (누르면 워치로 보냄). 끊겼으면 흐리게 · 못 누름 */
@Composable
private fun Buttons(st: LiveState, f: LiveFrame8, L: PL, buzz: (Boolean) -> Unit) {
    val on = !WatchMirror.reconnecting
    LiveButtons8(L, f.tone, "watchLive",
        nextTitle = if (st.autoSplit) null else (if (st.nextSeg != null || st.open) "Next" else "Finish"),
        nextOn = on && st.running,
        showUndo = !isRunCard(st), undoOn = st.canUndo,
        showSkip = false, running = st.running, enabled = on,
        onNext = { buzz(true); WatchMirror.send(LiveCommand.Next) },
        onEnd = {
            Router.ask = Ask("End workout?", "The workout ends on your watch and is saved there.", ok = "End", cancel = "Cancel", destructive = true,
                onOk = { WatchMirror.send(LiveCommand.End) })
        },
        onUndo = { buzz(false); WatchMirror.send(LiveCommand.Undo) },
        onPause = { WatchMirror.send(if (st.running) LiveCommand.Pause else LiveCommand.Resume) })
}

/** 워치가 끝냄: 기록이 도착하면 기록 화면 + 카드 */
@Composable
private fun Saving(modifier: Modifier) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Spacer(Modifier.weight(1f))
        Icon8("deviceWatch", 44.dp, C.yellow)
        T("Saving on your watch…", FD.t(17, W600), Modifier.testTag("watchLive.saving"), maxLines = 1)
        T("Your record will appear here in a moment.", FD.t(14, color = C.dText2))
        Spacer(Modifier.weight(1f))
        GrayPill("Home", Modifier.padding(bottom = 60.dp)) { Router.go(Scr.Home) }
    }
}
