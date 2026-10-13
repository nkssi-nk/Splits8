package com.nkssi.splits8.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Scr
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.card8

/** 아직 옮기지 않은 화면 자리 (다음 단계에서 아이폰 화면으로 채움) */
@Composable
fun ComingScreen(title: String) {
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide)) {
            SectionLabel(title.uppercase(), top = 4.dp)
            Column(Modifier.fillMaxWidth().padding(top = 10.dp).card8().padding(18.dp)) {
                T(title, F.t(17))
                Note8("Android · coming next", Modifier.padding(top = 6.dp))
            }
            Column(Modifier.height(900.dp)) {}
        }
    }
}

/** 화면 고르기 (아이폰 PhoneRoot.screen) */
@Composable
fun ScreenFor(s: Scr) {
    when (s) {
        Scr.Splash -> SplashView()
        Scr.Home -> HomeView()
        Scr.Training -> TrainingView()
        Scr.Builder -> BuilderView()
        Scr.Sim -> TestView()
        Scr.Race -> RaceView()
        Scr.SetEvent -> SetEventView()
        Scr.FindEvent -> FindEventView()
        Scr.SetGoals -> SetGoalsView()
        Scr.Settings -> SettingsView()
        Scr.SetDiv -> SetDivView()
        Scr.SetRun -> SetRunView()
        Scr.SetHr -> SetHrView()
        Scr.Account -> AccountView()
        Scr.Friends -> FriendsView()
        Scr.Detail -> DetailView()
        Scr.Share -> ShareView()
        Scr.PhoneLive -> PhoneLiveView()
        Scr.Ob1 -> Onboarding1()
        Scr.Ob2 -> Onboarding2()
        Scr.Ob3 -> Onboarding3()
        Scr.Auth -> AuthView()
        Scr.Code -> CodeView()
        Scr.Nick -> NickView()
        Scr.ProfileSetup -> ProfileSetupView()
        else -> ComingScreen(s.name)
    }
}

