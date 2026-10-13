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
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.nkssi.splits8.shared.Program
import org.junit.After
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

    @After fun tearDown() {
        Router.ask = null; Router.bonus = null; Router.planRequest = null; Router.editId = null; Router.testInfo = null
        Router.testTab = "pft"; Router.raceSheet = null; Router.evDraft = null
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

    // MARK: 트레이닝 탭 (4-2)

    private fun demoTraining(lang: String = "en") {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        val progs = listOf(Program.run(5, false, "run.demo1"), Program.hiit().copy(id = "hiit.demo1")) + Demo.programs()
        Store.useDemo(Demo.settings(o, Store.today()), progs, Demo.records(o), Demo.friends(), me = "demo.me")
        L10n.lang = lang
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun trainingDemo() { demoTraining(); shot("10_training", s = Scr.Training) }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun trainingDemoKo() { demoTraining("ko"); shot("10_training_ko", "ko", Scr.Training) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun builderNew() { demoTraining(); Router.newTraining(); shot("11_builder_new", s = Scr.Builder) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun builderEditKo() {
        demoTraining("ko"); Router.edit(Store.programs.first { it.id == "p1" }); shot("12_builder_edit_ko", "ko", Scr.Builder)
    }

    @Test fun bonusRun() {
        demoTraining(); Router.bonus = BonusRequest("run"); shot("13_bonus_run", s = Scr.Training); Router.bonus = null
    }

    @Test fun bonusHiitKo() {
        demoTraining("ko"); Router.bonus = BonusRequest("hiit"); shot("14_bonus_hiit_ko", "ko", Scr.Training); Router.bonus = null
    }

    @Test fun planSheet() {
        demoTraining()
        Router.openPlan(java.time.LocalDate.of(2026, 9, 27).atTime(7, 0).atZone(com.nkssi.splits8.shared.Fm.zone).toInstant())
        shot("15_plan", s = Scr.Home)
        rule.onNodeWithTag("plan.date").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/15_plan_date.png")
        rule.onNodeWithTag("plan.time").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/15_plan_time.png")
        Router.planRequest = null
    }

    // MARK: Test 탭 (4-3)

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun pftDemo() { demoTraining(); Router.testTab = "pft"; shot("20_pft", s = Scr.Sim) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun pftEmptyKo() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.testTab = "pft"; shot("21_pft_empty_ko", "ko", Scr.Sim)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2800dp-xxhdpi")
    @Test fun simDemo() { demoTraining(); Router.testTab = "sim"; shot("22_sim", s = Scr.Sim) }

    @Config(sdk = [35], qualifiers = "w412dp-h2800dp-xxhdpi")
    @Test fun simDemoKo() { demoTraining("ko"); Router.testTab = "sim"; shot("22_sim_ko", "ko", Scr.Sim) }

    @Test fun simEmpty() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.testTab = "sim"; shot("23_sim_empty", s = Scr.Sim)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1600dp-xxhdpi")
    @Test fun pftInfoKo() { demoTraining("ko"); Router.testTab = "pft"; Router.testInfo = "pft"; shot("24_pft_info_ko", "ko", Scr.Sim) }

    @Test fun simInfo() { demoTraining(); Router.testTab = "sim"; Router.testInfo = "sim"; shot("25_sim_info", s = Scr.Sim) }

    // MARK: 레이스 탭 (4-4)

    private fun demoRace(lang: String = "en", dbl: Boolean = false) {
        demoTraining(lang)
        Store.update { it.copy(event = com.nkssi.splits8.shared.RaceEvent("Seoul", "KINTEX, Goyang",
            java.time.LocalDate.of(2026, 11, 13).atStartOfDay(com.nkssi.splits8.shared.Fm.zone).toInstant(), "09:30"),
            division = if (dbl) "dblM" else it.division) }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun raceDemo() { demoRace(); shot("30_race", s = Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun raceDemoKoDbl() { demoRace("ko", dbl = true); shot("30_race_ko_dbl", "ko", Scr.Race) }

    @Test fun raceEmpty() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        shot("31_race_empty", s = Scr.Race)
    }

    @Test fun goalSheet() { demoRace(); Router.raceSheet = "goal"; shot("32_goal_sheet", s = Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1100dp-xxhdpi")
    @Test fun doublesSheetKo() { demoRace("ko", dbl = true); Router.raceSheet = "doubles"; shot("33_doubles_ko", "ko", Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1400dp-xxhdpi")
    @Test fun setEvent() {
        demoRace(); Router.evDraft = null; shot("34_event", s = Scr.SetEvent)
        rule.onNodeWithTag("ev.Date").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/34_event_date.png")
        rule.onNodeWithTag("ev.Date").performClick(); rule.onNodeWithTag("ev.Start time").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/34_event_time.png")
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun findEventKo() { demoRace("ko"); shot("35_find_ko", "ko", Scr.FindEvent) }

    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun setGoals() { demoRace(); shot("36_goals", s = Scr.SetGoals) }

    // MARK: 설정 탭 (4-5)

    @Config(sdk = [35], qualifiers = "w412dp-h2300dp-xxhdpi")
    @Test fun settingsDemo() { demoTraining(); shot("40_settings", s = Scr.Settings) }

    @Config(sdk = [35], qualifiers = "w412dp-h2300dp-xxhdpi")
    @Test fun settingsKoGuest() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Store.update { it.withGlow(com.nkssi.splits8.shared.GlowTheme.Blue) }
        shot("41_settings_ko_guest", "ko", Scr.Settings)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun accountSigned() { demoTraining(); shot("42_account", s = Scr.Account) }

    @Config(sdk = [35], qualifiers = "w412dp-h1300dp-xxhdpi")
    @Test fun accountGuestKo() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        shot("43_account_guest_ko", "ko", Scr.Account)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun setDiv() { demoTraining(); Router.subFrom = Scr.Account; shot("44_division", s = Scr.SetDiv) }

    @Test fun setHrKo() { demoTraining("ko"); Router.subFrom = Scr.Account; shot("45_hr_ko", "ko", Scr.SetHr) }

    @Test fun setRun() { demoTraining(); shot("46_running", s = Scr.SetRun) }

    @Test fun limitAlertKo() {
        demoTraining("ko")
        Store.useDemo(Store.settings, Store.programs + Program.presets().map { it.copy(id = it.id + "x") }, Store.records)
        shot("16_limit_ko", "ko", Scr.Training)
        rule.onNodeWithTag("training.new").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/16_limit_ko.png")
        Router.ask = null
    }
    @Test fun settings() = shot("04_settings", s = Scr.Settings)

    @Test fun launch() {
        rule.setContent { LaunchLogo() }
        rule.mainClock.advanceTimeBy(600)
        rule.onRoot().captureRoboImage("$out/00_launch.png")
    }
}
