package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import com.nkssi.splits8.screens.LaunchLogo
import com.nkssi.splits8.screens.ScreenFor
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 화면 사진 (에뮬레이터 없이). 결과: app/build/shots 폴더의 png
 * 크기: 갤럭시 S 시리즈와 비슷한 412 × 915 dp, 화면 밀도 2.625 (xxhdpi)
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h915dp-xxhdpi")
class Shots {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    private val out = System.getProperty("shots.dir") ?: "build/shots"

    @Before fun setUp() {
        GlowDrift.fixed = true
        Store.useDemo(Settings(hasOnboarded = true), com.nkssi.splits8.shared.Program.presets(), emptyList())
    }

    private fun shot(name: String, lang: String = "en", s: Scr) {
        L10n.lang = lang
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/$name.png")
    }

    @Test fun splash() = shot("01_splash", s = Scr.Splash)
    @Test fun splashKo() = shot("01_splash_ko", "ko", Scr.Splash)
    @Test fun home() = shot("02_home", s = Scr.Home)

    /** 예시 기록이 있는 홈 (아이폰 --demo --friends --racenear 와 같은 데이터). 화면 전체를 보려고 아주 긴 화면으로 */
    private fun demoHome(name: String, lang: String, raceDays: Int?) {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true, raceDays = raceDays)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(),
            Demo.leaderboard(), Demo.requests(), "demo.me")
        shot(name, lang, Scr.Home)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun homeDemoLong() = demoHome("05_home_demo_long", "en", 3)

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun homeDemoLongKo() = demoHome("05_home_demo_long_ko", "ko", 3)

    @Test fun homeDemo() = demoHome("06_home_demo", "en", 3)
    @Test fun trainingKo() = shot("03_training_ko", "ko", Scr.Training)
    @Test fun settings() = shot("04_settings", s = Scr.Settings)

    @Test fun launch() {
        rule.setContent { LaunchLogo() }
        rule.mainClock.advanceTimeBy(600)
        rule.onRoot().captureRoboImage("$out/00_launch.png")
    }
}
