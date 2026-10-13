package com.nkssi.splits8.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.Wordmark
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.navBottom
import com.nkssi.splits8.ui.tap
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.testTag

/** 사진 초점 (CSS background-position center 30%) */
private val splashFocus = BiasAlignment(0f, -0.4f)

@Composable
private fun SplashPhoto() {
    Image(painterResource(R.drawable.splash), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop, alignment = splashFocus)
}

/** 처음 화면 (아이폰 SplashView): 사진 + 8 RUNS · 8 STATIONS + 로고 + 설명 + Get started + Sign in */
@Composable
fun SplashView() {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        SplashPhoto()
        Box(
            Modifier.fillMaxSize()
                .background(Brush.verticalGradient(0f to Color.Black.copy(alpha = 0.55f), 0.3f to Color.Transparent,
                    0.45f to Color.Transparent, 0.78f to Color.Black.copy(alpha = 0.92f)))
                .tap { Router.go(Scr.Ob1) },
        )
        Column(
            Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(horizontal = 28.dp).padding(bottom = 30.dp + navBottom()),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            T("8 RUNS · 8 STATIONS", F.te(11, W600, C.accent, em = 0.28f), maxLines = 1)
            Wordmark(72f)
            T("Every run. Every station. Every second on your wrist.",
                F.t(15, color = Color.White.copy(alpha = 0.78f)).copy(lineHeight = 21.75.sp), Modifier.widthIn(max = 300.dp))
            YellowButton("Get started", Modifier.padding(top = 10.dp), tag = "splash.start") { Router.go(Scr.Ob1) }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                T("Have an account? ", F.t(15, color = Color.White.copy(alpha = 0.7f)))
                T("Sign in", F.t(15, W600), Modifier.tap { Router.toAuth(Scr.Splash, "signin") }.testTag("splash.signin"))
            }
        }
    }
}

/** 앱 켤 때 로고 (사진 + 가운데 SPLITS8, 1.3초) */
@Composable
fun LaunchLogo(modifier: Modifier = Modifier) {
    var appear by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appear = true }
    val a by animateFloatAsState(if (appear) 1f else 0f, tween(350), label = "logo")
    Box(modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
        SplashPhoto()
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color.Black.copy(alpha = 0.4f), 0.35f to Color.Transparent,
            0.6f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.85f))))
        Wordmark(56f, Modifier.scale(0.94f + 0.06f * a).alpha(a))
    }
}
