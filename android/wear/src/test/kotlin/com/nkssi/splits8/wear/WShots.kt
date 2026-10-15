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
}
