package com.nkssi.splits8.wear

import androidx.activity.ComponentActivity
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.captureRoboImage
import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.WatchContext
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * 워치 화면 사진 (에뮬레이터 없이). 결과: wear/build/shots 폴더의 png
 * 크기: 갤럭시 워치 44mm (450 × 450 px, 225 dp, 동그란 화면). 작은 워치(40mm, 198 dp)도 몇 장.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w225dp-h225dp-round-watch-xhdpi")
class WShots {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private val out = System.getProperty("shots.dir") ?: "build/shots"
    private val t0 = 1_790_000_000_000L

    private fun ctx(): WatchContext {
        val now = Instant.ofEpochMilli(t0)
        val s = Settings(hasOnboarded = true, event = RaceEvent("Seoul", "KINTEX", now.plus(12, ChronoUnit.DAYS)), goalTime = 4320)
        return WatchContext(s, listOf(Program.run(5, indoor = false, id = "run5"), Program.hiit()) + Program.presets(),
            pftBest = listOf(150, 95, 120, 210, 260, 180), pftBestTotal = 1015, simBestTotal = 4565)
    }

    @Before fun setUp() {
        WatchStore.useDemo(ctx())
        WatchStore.engine = WorkoutEngine { t0 }.also { it.settings = WatchStore.settings }
        WNav.open(null); WNav.quick = emptyList(); WNav.program = null
    }

    @After fun tearDown() { WNav.open(null) }

    private fun shot(name: String, lang: String = "en", aod: Boolean = false) {
        L10n.lang = lang
        rule.setContent { CompositionLocalProvider(LocalAod provides aod) { WearApp(buzz = {}, exit = {}) } }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/$name.png")
    }

    // 운동 전

    @Test fun w01Home() = shot("w01_home")
    @Test fun w01HomeKo() = shot("w01_home_ko", "ko")
    @Config(sdk = [35], qualifiers = "w198dp-h198dp-round-watch-xhdpi")
    @Test fun w01HomeSmall() = shot("w01_home_40mm")
    @Test fun w02Programs() { WNav.mode = Mode.Training; WNav.open(WScreen.Programs); shot("w02_programs") }
    @Test fun w03Quick() {
        WNav.mode = Mode.Training; WNav.open(WScreen.Quick)
        WNav.quick = listOf(ProgItem("run", "1KM"), ProgItem("sledPush"), ProgItem("run", "1KM"), ProgItem("wallBalls"))
        shot("w03_quick")
    }
    @Test fun w03QuickKo() { WNav.mode = Mode.Training; WNav.open(WScreen.Quick); shot("w03_quick_ko", "ko") }
    @Test fun w04ConfirmSim() { WNav.mode = Mode.Sim; WNav.open(WScreen.Confirm); shot("w04_confirm_sim") }
    @Test fun w04ConfirmRaceKo() { WNav.mode = Mode.Race; WNav.open(WScreen.Confirm); shot("w04_confirm_race_ko", "ko") }
    @Test fun w04ConfirmPft() { WNav.mode = Mode.Pft; WNav.open(WScreen.Confirm); shot("w04_confirm_pft") }
    @Test fun w04ConfirmTraining() {
        WNav.mode = Mode.Training; WNav.program = Program.presets()[0]; WNav.open(WScreen.Confirm); shot("w04_confirm_training")
    }
    @Test fun w04ConfirmNoRace() {
        WatchStore.useDemo(ctx().copy(settings = ctx().settings.copy(event = RaceEvent())))
        WNav.mode = Mode.Race; WNav.open(WScreen.Confirm); shot("w04_confirm_norace")
    }
    @Test fun w05Countdown() {
        WatchStore.engine.startAfterCountdown(Mode.Sim, "Full Simulation", seq = sim())
        shot("w05_countdown")
    }

    // 운동 중

    private val div = Division.of("openM")
    private fun sim() = SeqBuilder.full(div, true, Defaults.goals)

    private fun live(name: String, lang: String = "en", idx: Int, el: Int, mode: Mode = Mode.Sim, hr: Double = 158.0, aod: Boolean = false, segDist: Double = 0.0) {
        WatchStore.engine.demoRun(mode, if (mode == Mode.Race) "Seoul" else "Full Simulation", sim(), idx, el, hr, done = false, dist = 900.0, segDist = segDist)
        shot(name, lang, aod)
    }

    @Test fun w06LiveStation() = live("w06_live_station", idx = 2, el = 132)          // SkiErg · GOAL (빌드 24)
    @Test fun w06LiveOverKo() = live("w06_live_over_ko", "ko", idx = 6, el = 255)    // Sled Push 목표 넘김 → SPLIT 빨강
    @Test fun w06LiveRun() = live("w06_live_run", idx = 4, el = 168, segDist = 560.0)  // 러닝 PACE
    @Test fun w06LiveRox() = live("w06_live_rox", idx = 1, el = 18, mode = Mode.Race) // Roxzone · GOAL
    @Config(sdk = [35], qualifiers = "w198dp-h198dp-round-watch-xhdpi")
    @Test fun w06LiveSmall() = live("w06_live_station_40mm", idx = 2, el = 132)
    @Test fun w06LiveAod() = live("w06_live_aod", idx = 2, el = 132, aod = true)
    @Test fun w07RunCard() {
        val p = Program.run(5, indoor = false)
        WatchStore.engine.demoRun(Mode.Training, p.name, SeqBuilder.training(p, div, emptyMap()) + SeqBuilder.runKm(2) + SeqBuilder.runKm(3),
            1, 230, 162.0, done = false, kind = "run", dist = 1620.0, segDist = 620.0)
        shot("w07_live_runcard")
    }

    @Test fun w08Controls() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 3, 80, 150.0, done = false)
        L10n.lang = "en"
        rule.setContent { WWorkoutPager({}, startPage = 1) }
        rule.waitForIdle(); rule.onRoot().captureRoboImage("$out/w08_controls.png")
    }
    @Test fun w09Segments() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 6, 40, 150.0, done = false)
        L10n.lang = "ko"
        rule.setContent { WWorkoutPager({}, startPage = 2) }
        rule.waitForIdle(); rule.onRoot().captureRoboImage("$out/w09_segments_ko.png")
    }
    @Test fun w10EndSheet() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 6, 40, 150.0, done = false)
        L10n.lang = "en"
        rule.setContent { WWorkoutPager({}, startPage = 1, startEnd = true) }
        rule.waitForIdle(); rule.onRoot().captureRoboImage("$out/w10_end.png")
        rule.onNodeWithTag("w.discard").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/w10_end_discard.png")
    }
    @Test fun w11Summary() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 0, 0, 150.0, done = true)
        shot("w11_summary")
    }
    @Test fun w11SummaryPftKo() {
        WatchStore.engine.demoRun(Mode.Pft, PFT.title, PFT.seq(div, listOf(150, 95, 120, 210, 260, 180)), 0, 0, 150.0, done = true, vsBest = true)
        shot("w11_summary_pft_ko", "ko")
    }

    // 빌드 27 · 28

    @Test fun w12LiveLast() = live("w12_live_last", idx = 30, el = 300)                     // 마지막 구간 → ✓ FINISH
    @Test fun w12LiveRoxKo() = live("w12_live_rox_ko", "ko", idx = 1, el = 18, mode = Mode.Race)
    @Test fun w12LiveRunSpeed() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 4, 168, 158.0, done = false, dist = 900.0, segDist = 560.0, speed = 3.4)
        shot("w12_live_run_speed")
    }
    @Test fun w12LiveRunMeasuringKo() {
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 4, 8, 158.0, done = false, dist = 900.0, segDist = 20.0)
        shot("w12_live_run_measuring_ko", "ko")
    }
    @Config(sdk = [35], qualifiers = "w198dp-h198dp-round-watch-xhdpi")
    @Test fun w12LiveRunCardSmall() {
        val p = Program.run(5, indoor = false)
        WatchStore.engine.demoRun(Mode.Training, p.name, SeqBuilder.training(p, div, emptyMap()) + SeqBuilder.runKm(2) + SeqBuilder.runKm(3),
            1, 230, 162.0, done = false, kind = "run", dist = 1620.0, segDist = 620.0, speed = 3.1)
        shot("w12_live_runcard_40mm")
    }
    @Test fun w12LiveImperial() {
        WatchStore.useDemo(ctx().copy(settings = ctx().settings.copy(units = "imperial")))
        WatchStore.engine.settings = WatchStore.settings
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", sim(), 6, 100, 158.0, done = false)
        shot("w12_live_imperial")
    }
    @Test fun w12LiveDoubles() {
        val d = Division.of("dblX")
        WatchStore.useDemo(ctx().copy(settings = ctx().settings.copy(division = "dblX"), doublesPlan = DoublesPlan(partnerName = "Jihoon")))
        WatchStore.engine.settings = WatchStore.settings
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", SeqBuilder.full(d, true, Defaults.goals), 2, 100, 158.0, done = false)
        shot("w12_live_doubles")
    }
    @Test fun w12LiveDoublesKo() {
        val d = Division.of("dblX")
        WatchStore.useDemo(ctx().copy(settings = ctx().settings.copy(division = "dblX"), doublesPlan = DoublesPlan(partnerName = "지훈이형님")))
        WatchStore.engine.settings = WatchStore.settings
        WatchStore.engine.demoRun(Mode.Sim, "Full Simulation", SeqBuilder.full(d, true, Defaults.goals), 14, 100, 158.0, done = false)
        shot("w12_live_doubles_ko", "ko")
    }

    @Test fun w13ConfirmSimGoal() {
        WatchStore.pickWatchGoal(5400)
        WNav.mode = Mode.Sim; WNav.open(WScreen.Confirm); shot("w13_confirm_sim_goal")
    }
    @Test fun w13GoalPicker() { WNav.mode = Mode.Sim; WNav.open(WScreen.Goal); shot("w13_goal_picker") }
    @Test fun w13GoalPickerKo() { WatchStore.pickWatchGoal(5400); WNav.mode = Mode.Sim; WNav.open(WScreen.Goal); shot("w13_goal_picker_ko", "ko") }
    @Test fun w14RunStart() {
        WNav.mode = Mode.Training; WNav.program = Program.run(5, indoor = false, id = "run5"); WNav.open(WScreen.Confirm); shot("w14_run_start")
    }
    @Test fun w14RunStartIndoorKo() {
        WNav.mode = Mode.Training; WNav.program = Program.run(5, indoor = true, id = "run5i"); WNav.open(WScreen.Confirm); shot("w14_run_start_indoor_ko", "ko")
    }

    private fun calib(name: String, phase: Calib.Phase, lang: String = "en", icon: String = "wallBalls", live: Int = 0,
                      saved: com.nkssi.splits8.shared.RepTune? = null) {
        Calib.demo(icon, phase, live, saved)
        try { shot(name, lang) } finally { Calib.close() }
    }
    @Test fun w15CalibReady() = calib("w15_calib_ready", Calib.Phase.Ready)
    @Test fun w15CalibReadyKo() = calib("w15_calib_ready_ko", Calib.Phase.Ready, "ko", icon = "skiErg")
    @Test fun w15CalibCounting() = calib("w15_calib_counting", Calib.Phase.Counting, live = 14)
    @Test fun w15CalibConfirm() = calib("w15_calib_confirm", Calib.Phase.Confirm)
    @Test fun w15CalibSavedKo() = calib("w15_calib_saved_ko", Calib.Phase.Saved, "ko", saved = com.nkssi.splits8.shared.RepTune.defaults["row"])
    @Test fun w15CalibFailed() = calib("w15_calib_failed", Calib.Phase.Saved, icon = "row")
    @Config(sdk = [35], qualifiers = "w198dp-h198dp-round-watch-xhdpi")
    @Test fun w15CalibConfirmSmall() = calib("w15_calib_confirm_40mm", Calib.Phase.Confirm)
}
