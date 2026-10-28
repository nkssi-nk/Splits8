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
import androidx.compose.foundation.layout.size
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.navBottom
import com.nkssi.splits8.ui.statusTop
import com.nkssi.splits8.ui.tap
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await

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

// MARK: 4번 · 앱 안 업데이트 안내 (Play In-App Updates)
// 앱을 켤 때 하루 한 번 플레이에 새 버전이 있는지 물어봄 → 있으면 홈 위에 띠 "새 버전이 나왔어요" [업데이트] [×].
// [업데이트] = 유연한 업데이트(받는 동안 앱 계속 사용) → 다 받으면 "다시 시작해서 적용" 띠 → completeUpdate().
// [×] = 그 versionCode 는 다시 안 띄움. 운동 중 · 처음 안내 중 · 예시 화면에서는 안 함.
// 플레이에서 설치한 앱에서만 됨 (디버그 · Firebase 배포본은 실패 → 조용히 넘어감)

object AppUpdate {
    private const val LAST = "update.lastCheck"
    private const val DISMISSED = "update.dismissedCode"
    private const val DAY_MS = 24L * 3600 * 1000
    private const val REQ = 4801

    /** 띠: null = 안 보임 · "available" = 새 버전 있음 · "ready" = 다 받음 (다시 시작) */
    var band by mutableStateOf<String?>(null)
    /** 새 버전 번호 (versionCode) — [×] 로 닫으면 이 번호를 기억 */
    var availableCode = 0
        private set
    /** 시험용: 가짜 관리자 (FakeAppUpdateManager). 실제로는 처음 확인할 때 만듦 */
    var manager: AppUpdateManager? = null
    private var info: AppUpdateInfo? = null
    private var listening: AppUpdateManager? = null

    /** 오늘 확인할 차례인지 (마지막 확인 뒤 하루가 지났거나, 시계가 뒤로 갔으면) */
    fun due(nowMs: Long): Boolean {
        val last = Store.pref(LAST, "").toLongOrNull() ?: return true
        return nowMs - last >= DAY_MS || nowMs < last
    }

    /** [×] 로 닫은 버전인지 */
    fun dismissed(code: Int): Boolean = Store.pref(DISMISSED, "").toIntOrNull() == code

    /** 띄우면 안 되는 때: 예시 화면 · 처음 안내 중 · 운동 중 (폰 기록 · 워치 같이 보기) */
    fun quiet(): Boolean = Store.demo || !Store.settings.hasOnboarded || Router.phoneRun != null || WatchMirror.on ||
        Router.scr == Scr.PhoneLive || Router.scr == Scr.WatchLive

    private fun mgr(ctx: android.content.Context): AppUpdateManager? =
        manager ?: runCatching { AppUpdateManagerFactory.create(ctx.applicationContext) }.getOrNull()?.also { manager = it }

    /** 앱이 앞으로 올 때마다 부름 (하루 한 번만 실제로 물어봄). 실패하면 조용히 */
    suspend fun check(ctx: android.content.Context, nowMs: Long = System.currentTimeMillis()) {
        if (Store.demo && manager == null) return
        if (quiet()) return
        val m = mgr(ctx) ?: return
        listen(m)
        val i = runCatching { m.appUpdateInfo.await() }.getOrNull() ?: return
        // 전에 다 받아 놓고 다시 시작을 안 했으면 하루 제한 없이 "다시 시작" 띠
        if (i.installStatus() == InstallStatus.DOWNLOADED) { band = "ready"; return }
        if (!due(nowMs)) return
        Store.setPref(LAST, nowMs.toString())
        if (i.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE || !i.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) return
        if (dismissed(i.availableVersionCode())) return
        info = i
        availableCode = i.availableVersionCode()
        band = "available"
    }

    /** 다 받았다는 소식 → "다시 시작" 띠 (관리자마다 한 번만 등록) */
    private fun listen(m: AppUpdateManager) {
        if (listening === m) return
        listening = m
        runCatching {
            m.registerListener(InstallStateUpdatedListener { st ->
                if (st.installStatus() == InstallStatus.DOWNLOADED) band = "ready"
            })
        }
    }

    /** [업데이트]: 플레이의 확인 창 → 뒤에서 받기. 띠는 닫음 (다 받으면 "다시 시작" 띠가 뜸) */
    fun start(activity: Activity?) {
        val m = manager ?: return
        val i = info ?: return
        band = null
        info = null           // 같은 정보로는 한 번만 시작할 수 있음
        val a = activity ?: return
        runCatching { m.startUpdateFlowForResult(i, a, AppUpdateOptions.defaultOptions(AppUpdateType.FLEXIBLE), REQ) }
    }

    /** [다시 시작]: 받은 새 버전 설치 (앱이 다시 켜짐) */
    fun restart() {
        band = null
        runCatching { manager?.completeUpdate() }
    }

    /** [×]: 새 버전 띠면 그 버전은 다시 안 띄움. 다시 시작 띠는 이번만 닫음 (다음에 켤 때 다시) */
    fun dismiss() {
        if (band == "available" && availableCode > 0) Store.setPref(DISMISSED, availableCode.toString())
        band = null
    }

    /** 시험용 */
    fun resetForTest() {
        band = null; availableCode = 0; manager = null; info = null; listening = null
    }
}

/** 홈 맨 위 업데이트 띠 (노란 알약 — 위 알림 띠와 같은 모양) */
@Composable
fun UpdateBand() {
    val b = AppUpdate.band ?: return
    if (AppUpdate.quiet()) return
    val ctx = LocalContext.current
    val ready = b == "ready"
    val shape = RoundedCornerShape(50)
    Row(
        Modifier.fillMaxWidth().height(48.dp).clip(shape).background(C.accent).padding(start = 18.dp, end = 6.dp).testTag("update.band"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        T(if (ready) "Restart to update" else "A new version is available", F.t(15, W600, Color.Black), Modifier.weight(1f), maxLines = 1)
        Box(Modifier.height(32.dp).clip(CircleShape).background(Color.Black)
            .press(0.96f, tag = "update.go") { if (ready) AppUpdate.restart() else AppUpdate.start(ctx as? Activity) }
            .padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
            T(if (ready) "Restart" else "Update", F.t(13, W600, C.accent), maxLines = 1)
        }
        Box(Modifier.size(36.dp).tap { AppUpdate.dismiss() }.testTag("update.close"), contentAlignment = Alignment.Center) {
            Glyph("i_x", 13.dp, Color.Black)
        }
    }
}

/** 16번: 아래 "숨겼어요 · 되돌리기" 띠 (탭 바 위, 회색 알약 #2C2C2E · 되돌리기 노랑). 4초 뒤 저절로 사라짐 */
@Composable
fun UndoBand(modifier: Modifier = Modifier) {
    val note = Router.undo
    var last by remember { mutableStateOf<UndoNote?>(null) }
    if (note != null) last = note
    LaunchedEffect(note?.key) {
        if (note != null) {
            delay(4000)
            if (Router.undo?.key == note.key) Router.undo = null
        }
    }
    AnimatedVisibility(note != null, modifier.fillMaxWidth().padding(horizontal = 16.dp)
        .padding(bottom = maxOf(26.dp, navBottom() + 10.dp) + 76.dp),
        enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut()) {
        val shape = RoundedCornerShape(50)
        Row(
            Modifier.fillMaxWidth().height(48.dp).shadow(10.dp, shape, ambientColor = Color.Black, spotColor = Color.Black)
                .clip(shape).background(C.segOn).padding(start = 18.dp, end = 4.dp).testTag("undo.band"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            T(last?.text ?: "", F.t(15, W600), Modifier.weight(1f), maxLines = 1)
            Box(Modifier.height(48.dp).tap {
                val n = Router.undo ?: return@tap
                Router.undo = null
                n.undo()
            }.testTag("undo.go").padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
                T("Undo", F.t(15, W600, C.accent), maxLines = 1)
            }
        }
    }
}
