package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.CalibResult
import com.nkssi.splits8.shared.DoublesLink
import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.ProgramLink
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.WatchWire
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 아이폰 빌드 27 · 28 에서 들어온 것 (링크 · 보정 · 단위 · 알림 띠 · 평가 요청 · 상위 % · 가입 단계) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
class Build28Flows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
    }

    @After fun tearDown() {
        Router.ask = null; Router.notice = null; Router.finish = null; Router.raceSheet = null
        ReviewAsk.testSink = null
        Store.now = { java.time.Instant.now() }
    }

    private fun show(s: Scr, extra: @androidx.compose.runtime.Composable () -> Unit = {}) {
        Router.scr = s
        rule.setContent { extra(); PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    private fun useDemo() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(), me = "demo.me")
    }

    @Test fun doublesLinkAsksAndSwaps() {
        show(Scr.Home)
        val sent = DoublesPlan().setChunk(0, 150.0).setMeFirst(1, false)
        Router.handleUrl("splits8://d?d=" + DoublesLink.token(sent, "gatebu"))
        rule.waitForIdle()
        assertEquals("Get gatebu's doubles plan?", Router.ask?.title)
        tap("ask.ok")
        val p = Store.settings.doublesPlan!!
        assertEquals(150.0, p.chunk(0), 0.001)
        assertFalse(p.meFirst(0))                 // 보낸 사람이 먼저였으니 나는 나중
        assertTrue(p.meFirst(1))
        assertEquals("gatebu", p.partnerName)
        assertEquals(Scr.Race, Router.scr)
    }

    @Test fun badLinksSayCantRead() {
        show(Scr.Home)
        Router.handleUrl("splits8://d?d=d1.@@@")
        assertEquals("This doubles plan link can't be read", Router.ask?.title)
        Router.ask = null
        Router.handleUrl("https://splits8.com/splits8/t.html#1.xxxx")
        assertEquals("This training link can't be read", Router.ask?.title)
        Router.ask = null
        Router.handleUrl("https://example.com/")          // 우리 링크가 아니면 아무것도 안 함
        assertNull(Router.ask)
    }

    @Test fun trainingLinkAdds() {
        Store.useDemo(Settings(hasOnboarded = true), emptyList(), emptyList())
        show(Scr.Home)
        val p = Program("x", "Leg day", 2, listOf(ProgItem("run", "1KM"), ProgItem("sledPush")))
        Router.handleUrl("splits8://t?d=" + ProgramLink.token(p))
        rule.waitForIdle()
        assertEquals("Add this training?", Router.ask?.title)
        tap("ask.ok")
        assertEquals("Leg day", Store.programs.first().name)
        assertEquals(Scr.Training, Router.scr)
    }

    @Test fun calibrationResultSaves() {
        val t = RepTune(0.52, 0.23, 1.0, 0.7, java.time.Instant.parse("2026-10-19T01:00:00Z"))
        assertTrue(WatchSync.receiveCalib(WatchWire.calibJson(CalibResult("wallBalls", t))))
        assertEquals(0.52, Store.settings.repCal!!["wallBalls"]!!.threshold, 0.0001)
        // 모르는 종목 · 깨진 글자는 무시 (그래도 DataItem 은 지움)
        assertTrue(WatchSync.receiveCalib("{"))
        assertTrue(WatchSync.receiveCalib(WatchWire.calibJson(CalibResult("burpee", t))))
        assertEquals(setOf("wallBalls"), Store.settings.repCal!!.keys)
    }

    @Test fun workoutAndCalibrateScreens() {
        show(Scr.Settings)
        tap("settings.workout")
        assertEquals(Scr.SetWorkout, Router.scr)
        tap("workout.cal.row")
        assertEquals(Scr.SetCalib, Router.scr)
        assertEquals("row", Router.calibIcon)
        tap("calib.start")
        rule.onAllNodesWithText("Sent to watch")[0].assertExists()
        tap("back")
        assertEquals(Scr.SetWorkout, Router.scr)
        tap("workout.running")
        assertEquals(Scr.SetRun, Router.scr)
        tap("back")
        assertEquals(Scr.SetWorkout, Router.scr)
    }

    @Test fun calibrateResetGoesBackToDefault() {
        Store.update { it.copy(repCal = mapOf("skiErg" to RepTune(0.5, 0.2, 0.8, 0.8, java.time.Instant.parse("2026-10-19T01:00:00Z")))) }
        Router.calibIcon = "skiErg"
        show(Scr.SetCalib)
        tap("calib.reset")
        tap("ask.ok")
        assertNull(Store.settings.repCal)
    }

    @Test fun unitsSwitch() {
        show(Scr.Settings)
        rule.onAllNodesWithText("lb · mi")[0].performClick(); rule.waitForIdle()
        assertTrue(Store.settings.imperial)
        rule.onAllNodesWithText("kg · km")[0].performClick(); rule.waitForIdle()
        assertNull(Store.settings.units)
    }

    @Test fun noticeBannerOpensFriends() {
        Store.useDemo(Settings(hasOnboarded = true, nickname = "kim"), Program.presets(), emptyList(),
            req = listOf(FriendReq("u2", "hana", "Open Women", null, incoming = true)))
        show(Scr.Home)
        Router.showNoticeIfAny()
        rule.waitForIdle()
        assertEquals("👋 1 friend request", Router.notice)
        tap("notice.banner")
        assertEquals(Scr.Friends, Router.scr)
        assertEquals(Scr.Home, Router.friendsFrom)
        assertNull(Router.notice)
    }

    @Test fun reviewAskedAfterGoodFinish() {
        useDemo()
        var asked = 0
        ReviewAsk.testSink = { asked++ }
        val rec = Store.records.first { it.mode == Mode.Sim && it.counts }
        show(Scr.Detail) { ReviewAfterFinish() }
        rule.runOnUiThread { Router.finish = rec }
        rule.waitForIdle()
        rule.runOnUiThread { Router.finish = null }
        rule.waitForIdle()
        rule.waitUntil(5000) { asked == 1 }
        assertEquals(1, asked)
        // 같은 버전에서는 다시 안 물음
        rule.runOnUiThread { Router.finish = rec }; rule.waitForIdle(); rule.runOnUiThread { Router.finish = null }
        rule.waitForIdle(); rule.mainClock.advanceTimeBy(1000); rule.waitForIdle()
        assertEquals(1, asked)
    }

    @Test fun rankCardOnFullSim() {
        useDemo()
        val rec = Store.records.first { it.mode == Mode.Sim && it.splits16 != null }
        Router.open(rec, Scr.Sim)
        show(Scr.Detail)
        rule.onNodeWithTag("detail.rank").assertExists()
    }

    @Test fun profileSkipsDivisionWhenPicked() {
        Store.useDemo(Settings(hasOnboarded = true, division = "proW", divPicked = true), Program.presets(), emptyList())
        Router.signupFlow = false
        Router.startProfile(Scr.Home)
        show(Scr.ProfileSetup)
        rule.onNodeWithTag("dots").assertTextEquals("1 / 3")
        tap("profile.raced.no")
        tap("profile.next")
        rule.onNodeWithTag("dots").assertTextEquals("2 / 3")    // 디비전 건너뜀 → 태어난 해
        assertNotNull(rule.onAllNodesWithText("Birth year").fetchSemanticsNodes().firstOrNull())
    }

    @Test fun fullSimHasGoalRows() {
        useDemo()
        Router.testTab = "sim"
        show(Scr.Sim)
        tap("sim.Goal time")
        assertEquals("goal", Router.raceSheet)
        Router.raceSheet = null; rule.waitForIdle()
        tap("sim.splitTargets")
        assertEquals(Scr.SetGoals, Router.scr)
        tap("back")
        assertEquals(Scr.Sim, Router.scr)
        assertEquals("sim", Router.testTab)
    }
}
