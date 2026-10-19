package com.nkssi.splits8.screens

import android.view.HapticFeedbackConstants
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
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
fun watchFrame(st: LiveState, nowMs: Long, receivedMs: Long): LiveFrame {
    val next = st.nextSeg ?: if (st.open) {
        val n = st.seq.size + 1
        if (st.cur?.icon == "hiit") SeqBuilder.hiitRound(n) else SeqBuilder.runKm(n)
    } else null
    return LiveFrame(
        mode = st.mode, title = st.title, seq = st.seq, idx = st.idx,
        segEl = st.segEl(nowMs, receivedMs), total = st.total(nowMs, receivedMs), running = st.running, open = st.open,
        segDist = st.segDist, totalDist = st.dist, runKind = st.cur?.icon == "run" && st.mode == com.nkssi.splits8.shared.Mode.Training,
        next = next,
        speed = if (st.running) st.spd else null,
        imperial = com.nkssi.splits8.Store.settings.imperial,
    )
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

    // 위쪽 빛 = 지금 심박 구간 색 (심박이 없으면 테마 색)
    val z = st?.zone ?: 0
    val glow by animateColorAsState(if (z in 1..5) C.zone(z) else hex(Store.settings.glow.hex), tween(800), label = "zone")
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val m = LiveMetrics(maxHeight.value)
        Canvas(Modifier.fillMaxWidth().height(maxHeight * 0.5f)) {
            drawRect(Brush.radialGradient(listOf(glow.copy(alpha = 0.30f), glow.copy(alpha = 0f)), Offset(size.width / 2, 0f), 420.dp.toPx()))
        }
        if (st == null) {
            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                T("Connecting to your watch…", F.t(15, color = C.text2), maxLines = 1)
            }
            return@BoxWithConstraints
        }
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            val f = watchFrame(st, now, WatchMirror.received)
            LiveHeader(f, if (WatchMirror.reconnecting) "Watch · Reconnecting…" else "Watch · Live", !WatchMirror.reconnecting, "watchLive")
            when {
                // 워치에서 버림: 기록이 안 오니 잠시 뒤 홈으로
                WatchMirror.discarded -> Spacer(Modifier.weight(1f))
                st.finished || WatchMirror.ended -> Saving(Modifier.weight(1f))
                else -> {
                    LiveBody(f, m.totalFont, m.segFont, m.icon, m.nameFont, m.detailFont, m.segTop, m.nameTop, "watchLive",
                        Modifier.padding(top = (m.top * 0.6f).dp))
                    Chips(st, Modifier.padding(top = (14 * m.k).dp))
                    LiveNextRow(f.next, m.nextLabel, m.nextFont, m.nextIcon, m.dividerTop * 0.7f, m.k, "watchLive")
                    Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
                    Buttons(st, m) { strong -> view.performHapticFeedback(if (strong) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.VIRTUAL_KEY) }
                }
            }
        }
    }
}

/** ♥ 165 BPM [Z4] · 286 KCAL */
@Composable
private fun Chips(st: LiveState, modifier: Modifier) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
        Row(Modifier.height(32.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Sym(R.drawable.sym_heart, 12.dp, C.hr)
            T(if (st.hr > 0) "${st.hr}" else "--", F.num(15), Modifier.testTag("watchLive.hr"), maxLines = 1, translate = false)
            T("BPM", F.t(10, W600, C.text2), maxLines = 1, translate = false)
            if (st.zone > 0) {
                Box(Modifier.height(16.dp).clip(RoundedCornerShape(4.dp)).background(C.zone(st.zone)).padding(horizontal = 5.dp),
                    contentAlignment = Alignment.Center) { T("Z${st.zone}", F.t(10, W700, Color.Black), maxLines = 1, translate = false) }
            }
        }
        Row(Modifier.height(32.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            T("${st.kcal}", F.num(15), maxLines = 1, translate = false)
            T("KCAL", F.t(10, W600, C.text2), maxLines = 1, translate = false)
        }
    }
}

/** 아래 단추 (누르면 워치로 보냄). 끊겼으면 흐리게 · 못 누름 */
@Composable
private fun Buttons(st: LiveState, m: LiveMetrics, buzz: (Boolean) -> Unit) {
    val on = !WatchMirror.reconnecting
    val nextOn = on && st.running && !st.autoSplit
    Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().height(m.buttonH.dp).yellowFill(RoundedCornerShape(50), on = nextOn)
                .press(enabled = nextOn, tag = "watchLive.next") { buzz(true); WatchMirror.send(LiveCommand.Next) },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
        ) {
            val label = if (st.autoSplit) "Auto split every 1 km" else if (st.nextSeg != null || st.open) "Next" else "Finish"
            T(label.l10n + "  ›", F.t(m.buttonFont, W600, if (nextOn) Color.Black else C.text3), maxLines = 1, translate = false)
        }
        Row(Modifier.padding(top = m.pillGap.dp, bottom = m.bottom.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Pill(R.drawable.sym_stop, "End", C.bad, hex(0xFF453A, 0.22f), m.pillH, "watchLive.end", on) {
                Router.ask = Ask("End workout?", "The workout ends on your watch and is saved there.", ok = "End", cancel = "Cancel", destructive = true,
                    onOk = { WatchMirror.send(LiveCommand.End) })
            }
            Pill(R.drawable.sym_undo, "Undo", if (st.canUndo) Color.White else C.text3,
                Color.White.copy(alpha = if (st.canUndo) 0.12f else 0.05f), m.pillH, "watchLive.undo", on && st.canUndo) {
                buzz(false); WatchMirror.send(LiveCommand.Undo)
            }
            Pill(if (st.running) R.drawable.sym_pause else R.drawable.sym_play, if (st.running) "Pause" else "Resume",
                if (st.running) Color.White else C.accent, Color.White.copy(alpha = 0.12f), m.pillH, "watchLive.pause", on) {
                WatchMirror.send(if (st.running) LiveCommand.Pause else LiveCommand.Resume)
            }
        }
    }
}

/** 워치가 끝냄: 기록이 도착하면 기록 화면 + 카드 */
@Composable
private fun Saving(modifier: Modifier) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Spacer(Modifier.weight(1f))
        Icon8("deviceWatch", 44.dp, C.accent)
        T("Saving on your watch…", F.t(17, W600), Modifier.testTag("watchLive.saving"), maxLines = 1)
        T("Your record will appear here in a moment.", F.t(14, color = C.text2))
        Spacer(Modifier.weight(1f))
        GrayPill("Home", Modifier.padding(bottom = 60.dp)) { Router.go(Scr.Home) }
    }
}
