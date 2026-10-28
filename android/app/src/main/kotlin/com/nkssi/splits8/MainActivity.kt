package com.nkssi.splits8

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.nkssi.splits8.screens.LaunchLogo
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.ui.PhoneRoot
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.lifecycle.repeatOnLifecycle

class MainActivity : ComponentActivity() {
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        openFrom(intent)
    }

    /** 위젯을 눌러서 열었을 때 (다음 대회 → Race 탭, 이번 주 → 홈). 폰으로 기록 중이면 그 화면 그대로 */
    private fun openFrom(i: android.content.Intent?) {
        // 트레이닝 · 더블 계획 링크 (splits8://t?d=… · splits8://d?d=…)
        i?.data?.toString()?.let { u ->
            if (u.lowercase().startsWith("splits8://") || u.contains("#")) { Router.handleUrl(u); return }
        }
        val to = when (i?.getStringExtra("open")) {
            "race" -> Scr.Race; "home" -> Scr.Home
            // 진행 중 알림(워치 운동)을 눌렀을 때
            "watchLive" -> if (WatchMirror.on || WatchMirror.ended) Scr.WatchLive else return
            else -> return
        }
        if (Router.scr == Scr.PhoneLive || !Store.settings.hasOnboarded) return
        Router.go(to)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        Store.init(applicationContext)
        // 실제 서버 (Supabase). 시험에서는 가짜 서버를 넣음
        if (Supabase.isConfigured) Accounts.api = SupabaseAccounts
        GoogleSignIn.activity = java.lang.ref.WeakReference(this)
        if (savedInstanceState == null) Router.start()
        // 워치: 상태 확인 · 묶음 보내기 · 앱이 꺼져 있던 동안 도착한 기록 받기
        WatchSync.start()
        WatchMirror.cleanLeftover()               // 빌드 27: 남은 진행 중 알림 정리
        openFrom(intent)
        setContent { App(showLogo = savedInstanceState == null) }
    }
}

/** 앱 전체: 화면 틀 + 켤 때 로고 1.3초 + 뒤로 가기 */
@Composable
fun App(showLogo: Boolean = true) {
    var logo by rememberSaveable { mutableStateOf(showLogo) }
    LaunchedEffect(Unit) {
        if (logo) { delay(1300); logo = false }
    }
    val overlay = Router.ask != null || Router.bonus != null || Router.planRequest != null || Router.testInfo != null || Router.raceSheet != null || Router.userMenu != null || Router.partnerFor != null || Router.finish != null
    // 앱이 앞에 있는 동안: 다른 기기 로그인 확인 (3분마다) · 친구 목록 새로 받기
    val life = androidx.lifecycle.compose.LocalLifecycleOwner.current
    val ctx = androidx.compose.ui.platform.LocalContext.current
    LaunchedEffect(life) {
        life.repeatOnLifecycle(androidx.lifecycle.Lifecycle.State.RESUMED) {
            WatchSync.refreshState()
            launch { AppUpdate.check(ctx) }   // 4번: 하루 한 번 새 버전 확인 (서버 로그인과 상관없이, 실패하면 조용히)
            if (!Cloud.live) return@repeatOnLifecycle
            Cloud.checkDevice()
            Cloud.retryAvatarIfNeeded()       // 15번
            Cloud.refreshSocial()
            Router.showNoticeIfAny()          // 빌드 27: 받은 응원 · 친구 요청 알림 띠
            while (true) {
                delay(180_000)
                Cloud.checkDevice()
            }
        }
    }
    LaunchedEffect(Cloud.signedOutElsewhere) {
        if (Cloud.signedOutElsewhere) {
            Cloud.signedOutElsewhere = false
            Router.ask = Ask("Signed out because this account signed in on another device.",
                "Your records stay on this phone. Sign in again to use friends and leaderboards here.", cancel = null)
        }
    }
    // 15번: 사진 올리기 실패 안내
    LaunchedEffect(Cloud.avatarUploadFailed) {
        if (Cloud.avatarUploadFailed) {
            Cloud.avatarUploadFailed = false
            Router.ask = Ask("Couldn't upload your photo",
                "Friends still see your old photo. We'll try again next time you open the app.",
                ok = "Try again", cancel = "Later") {
                Store.photoJpeg()?.let { j -> Cloud.launch { Cloud.syncAvatar(j) } }
            }
        }
    }
    ReviewAfterFinish()                       // 빌드 27: 운동 끝 카드를 닫은 뒤 앱 평가 요청 (좋은 순간에만)
    BackHandler(enabled = overlay || (Router.scr != Scr.Home && Router.scr != Scr.Splash)) { Router.back() }
    Box(Modifier.fillMaxSize()) {
        PhoneRoot { s -> ScreenFor(s) }
        AnimatedVisibility(logo, exit = fadeOut(tween(400))) { LaunchLogo() }
    }
}
