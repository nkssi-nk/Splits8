package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.captureRoboImage
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 아이폰 빌드 27 · 28 로 새로 생긴 화면 사진. 결과: app/build/shots/b28_*.png */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h915dp-xxhdpi")
class Shots28 {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private val out = System.getProperty("shots.dir") ?: "build/shots"

    @Before fun setUp() {
        GlowDrift.fixed = true
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(),
            Demo.leaderboard(), Demo.requests(), "demo.me")
    }

    @After fun tearDown() {
        Router.raceSheet = null; Router.notice = null; Router.detail = null; Router.testTab = "pft"; Router.ask = null
        Store.now = { java.time.Instant.now() }
    }

    private fun shot(name: String, lang: String = "en", s: Scr, before: () -> Unit = {}) {
        L10n.lang = lang
        Router.scr = s
        before()
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/b28_$name.png")
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    @Test fun settings() = shot("settings", s = Scr.Settings)
    @Test fun settingsKo() = shot("settings_ko", "ko", Scr.Settings)

    @Config(sdk = [35], qualifiers = "w412dp-h1300dp-xxhdpi")
    @Test fun workout() {
        Store.update { it.copy(repCal = mapOf("wallBalls" to RepTune(0.5, 0.22, 1.0, 0.7, java.time.Instant.parse("2026-09-24T03:00:00Z")))) }
        shot("workout", s = Scr.SetWorkout)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1300dp-xxhdpi")
    @Test fun workoutKo() = shot("workout_ko", "ko", Scr.SetWorkout)

    @Test fun calib() { Router.calibIcon = "wallBalls"; shot("calib", s = Scr.SetCalib) }
    @Test fun calibKo() { Router.calibIcon = "skiErg"; shot("calib_ko", "ko", Scr.SetCalib) }

    private fun dbl() {
        Store.update {
            it.copy(division = "dblM", doublesPlan = DoublesPlan().setChunk(0, 150.0).setMeFirst(4, false).copy(partnerName = "gatebu"))
        }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun doublesSheet() { dbl(); shot("doubles", s = Scr.Race) { Router.raceSheet = "doubles" } }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun doublesSheetKo() { dbl(); shot("doubles_ko", "ko", Scr.Race) { Router.raceSheet = "doubles" } }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun doublesStation() {
        dbl(); shot("doubles_station", s = Scr.Race) { Router.raceSheet = "doubles" }
        tap("dbl.skiErg")
        rule.onRoot().captureRoboImage("$out/b28_doubles_station.png")
    }

    @Config(sdk = [35], qualifiers = "w412dp-h900dp-xxhdpi")
    @Test fun doublesShareCard() {
        dbl()
        L10n.lang = "ko"
        rule.setContent { com.nkssi.splits8.screens.DoublesShareCard(Store.settings.doublesPlan!!, "Doubles Men") }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/b28_doubles_card_ko.png")
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2200dp-xxhdpi")
    @Test fun fullSim() { dbl(); shot("fullsim", s = Scr.Sim) { Router.testTab = "sim" } }

    @Config(sdk = [35], qualifiers = "w412dp-h1600dp-xxhdpi")
    @Test fun race() = shot("race", s = Scr.Race)

    @Config(sdk = [35], qualifiers = "w412dp-h4400dp-xxhdpi")
    @Test fun detailSimRank() {
        val rec = Store.records.first { it.mode == Mode.Sim && it.splits16 != null }
        shot("detail_sim", s = Scr.Detail) { Router.open(rec, Scr.Sim); Router.scr = Scr.Detail }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h3200dp-xxhdpi")
    @Test fun detailSimRankKo() {
        val rec = Store.records.first { it.mode == Mode.Sim && it.splits16 != null }
        shot("detail_sim_ko", "ko", Scr.Detail) { Router.open(rec, Scr.Sim); Router.scr = Scr.Detail }
    }

    /** 실내 러닝 + 마지막 덜 뛴 구간 (0.42 km) */
    @Config(sdk = [35], qualifiers = "w412dp-h2600dp-xxhdpi")
    @Test fun detailIndoorRun() {
        val base = Demo.runRecord()
        val segs = base.segs + SegResult("run", "KM 7", "1KM", SegKind.Run, 128, 0, hr = 170, dist = 420.0)
        val rec = base.copy(id = "run.indoor", indoor = true, route = null, segs = segs, total = base.total + 128)
        Store.add(rec)
        shot("detail_indoor_run_ko", "ko", Scr.Detail) { Router.open(rec, Scr.Training); Router.scr = Scr.Detail }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun detailTrainingBest() {
        val rec = Store.records.filter { it.mode == Mode.Training && !it.isRunKind && it.segs.isNotEmpty() }.maxByOrNull { it.date }!!
        shot("detail_training", s = Scr.Detail) { Router.open(rec, Scr.Training); Router.scr = Scr.Detail }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun detailImperial() {
        Store.update { it.copy(units = "imperial") }
        val rec = Store.records.first { it.mode == Mode.Sim && it.splits16 != null }
        shot("detail_imperial", s = Scr.Detail) { Router.open(rec, Scr.Sim); Router.scr = Scr.Detail }
    }

    @Test fun profile() { Store.update { it.copy(homeShow = "run") }; shot("profile", s = Scr.Account) }

    @Test fun profilePicker() {
        shot("profile_picker", s = Scr.Account)
        tap("profile.homeShow")
        rule.onRoot().captureRoboImage("$out/b28_profile_picker.png")
    }

    @Test fun homeRunPB() { Store.update { it.copy(homeShow = "run") }; shot("home_runpb", s = Scr.Home) }

    @Test fun notice() {
        shot("notice", s = Scr.Home) { Router.notice = "🔥 2 new cheers · 1 friend request" }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun leaderboardNoRecord() {
        // 순위표에 없는 친구 (기록 없음) 한 명 더
        val f = Demo.friends() + com.nkssi.splits8.shared.Friend("u.new", "minji", Store.settings.div.name, "", emptyList())
        Store.useDemo(Store.settings, Store.programs, Store.records, f, Demo.leaderboard(), emptyList(), "demo.me")
        shot("home_lb", s = Scr.Home)
    }

    @Test fun onboarding() = shot("ob_watch", s = Scr.Ob3)

    @Test fun bonusName() {
        shot("bonus_run", s = Scr.Training) { Router.bonus = BonusRequest("run", Program.run(5, false, "run.x").copy(name = "Morning loop")) }
        Router.bonus = null
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1200dp-xxhdpi")
    @Test fun builderUnits() {
        Store.update { it.copy(units = "imperial") }
        Router.edit(Store.programs.first())
        shot("builder_imperial", s = Scr.Builder)
    }
}
