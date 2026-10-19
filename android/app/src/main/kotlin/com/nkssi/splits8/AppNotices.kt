package com.nkssi.splits8

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.statusTop
import kotlinx.coroutines.delay

// 아이폰 AppNotices.swift (빌드 27)
// ① 앱 평가 요청: 운동 끝 카드를 닫았을 때, 좋은 순간(기록 3개 이상 · PB · PFT 등급 상승 · 새 배지)에만.
//    같은 버전에서는 한 번만, 그리고 60일에 한 번 이하. 운동 중 · 처음 켰을 때는 묻지 않음. 안드로이드는 Play In-App Review.
// ② 앱을 열 때 받은 응원 · 친구 요청 알림 띠 (위쪽, 4초 뒤 사라짐, 누르면 친구 화면)

object ReviewAsk {
    private const val LAST = "review.lastAsk"
    private const val VERSION = "review.lastVersion"
    private const val MIN_GAP_MS = 60L * 24 * 3600 * 1000

    /** 시험용: 실제 평가 창 대신 */
    var testSink: (() -> Unit)? = null

    fun appVersion(): String = runCatching { BuildConfig.VERSION_NAME }.getOrDefault("")

    /** 지금 물어봐도 되는지 (버전 · 간격) */
    fun allowed(nowMs: Long = System.currentTimeMillis()): Boolean {
        if (Store.demo && testSink == null) return false
        val v = Store.pref(VERSION, "")
        if (v.isNotEmpty() && v == appVersion()) return false
        val last = Store.pref(LAST, "").toLongOrNull()
        if (last != null && nowMs - last < MIN_GAP_MS) return false
        return true
    }

    fun markAsked(nowMs: Long = System.currentTimeMillis()) {
        Store.setPref(LAST, nowMs.toString())
        Store.setPref(VERSION, appVersion())
    }

    /** Play 평가 창 (구글이 띄울지 최종 결정 — 아이폰과 같음) */
    fun launch(activity: Activity?) {
        testSink?.let { it(); return }
        val a = activity ?: return
        runCatching {
            val m = com.google.android.play.core.review.ReviewManagerFactory.create(a)
            m.requestReviewFlow().addOnCompleteListener { t ->
                if (t.isSuccessful) runCatching { m.launchReviewFlow(a, t.result) }
            }
        }
    }
}

/**
 * 운동 끝 카드를 닫은 뒤, 좋은 순간이면 0.6초 뒤 평가 요청 (App() 안에 한 번 둠).
 * 운동 중 · 공유 화면으로 넘어갔거나 다른 카드가 떠 있으면 다음 기회에
 */
@Composable
fun ReviewAfterFinish() {
    var shown by remember { mutableStateOf<Record?>(null) }
    val ctx = LocalContext.current
    val f = Router.finish
    LaunchedEffect(f) {
        if (f != null) { shown = f; return@LaunchedEffect }
        val rec = shown ?: return@LaunchedEffect
        shown = null
        if (!ReviewAsk.allowed() || !Store.book.reviewMoment(rec)) return@LaunchedEffect
        delay(600)
        if (Router.finish != null || WatchMirror.on || !(Router.scr.showsTabs || Router.scr == Scr.Detail)) return@LaunchedEffect
        ReviewAsk.markAsked()
        ReviewAsk.launch(ctx as? Activity)
    }
}

/** 위쪽 작은 알림 띠 (노란 알약 44, 글자 15/600 검정 + ›). 4초 뒤 저절로 사라짐 */
@Composable
fun NoticeBanner() {
    val text = Router.notice
    var last by remember { mutableStateOf("") }
    if (text != null) last = text
    LaunchedEffect(text) {
        if (text != null) {
            delay(4000)
            if (Router.notice == text) Router.notice = null
        }
    }
    AnimatedVisibility(text != null, Modifier.fillMaxWidth().padding(top = statusTop() + 50.dp).padding(horizontal = 16.dp),
        enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
        val shape = RoundedCornerShape(50)
        Row(
            Modifier.fillMaxWidth().height(44.dp).shadow(10.dp, shape, ambientColor = Color.Black, spotColor = Color.Black)
                .clip(shape).background(C.accent).press(0.97f, tag = "notice.banner") { Router.openNotice() }
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            T(last, F.t(15, W600, Color.Black), Modifier.weight(1f), maxLines = 1, translate = false)
            Chevron8(color = Color.Black)
        }
    }
}
