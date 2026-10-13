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

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        Store.init(applicationContext)
        if (savedInstanceState == null) Router.start()
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
    val overlay = Router.ask != null || Router.bonus != null || Router.planRequest != null || Router.testInfo != null || Router.raceSheet != null
    BackHandler(enabled = overlay || (Router.scr != Scr.Home && Router.scr != Scr.Splash)) { Router.back() }
    Box(Modifier.fillMaxSize()) {
        PhoneRoot { s -> ScreenFor(s) }
        AnimatedVisibility(logo, exit = fadeOut(tween(400))) { LaunchLogo() }
    }
}
