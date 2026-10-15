package com.nkssi.splits8

import android.app.Application
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.LivePacket
import com.nkssi.splits8.shared.LiveState
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.SeqBuilder
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
import org.robolectric.shadows.ShadowLooper
import java.time.Duration
import java.time.Instant

/** 갤럭시 워치 ↔ 폰: 워치가 보낸 기록 받기 · 워치로 보내는 묶음 · 워치 운동 같이 보기(단추 → 워치) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h915dp-xxhdpi")
class WatchFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private val app: Application = ApplicationProvider.getApplicationContext()
    private var t = 1_790_000_000_000L
    private val sentCmds = ArrayList<LiveCommand>()
    private val pushed = ArrayList<String>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        WatchMirror.reset()
        WatchMirror.clock = { t }
        WatchMirror.testSink = { sentCmds.add(it) }
        WatchSync.testSink = { pushed.add(it) }
        Health.api = FakeHealth()
    }

    @After fun tearDown() {
        WatchMirror.reset()
        WatchMirror.clock = { System.currentTimeMillis() }
        WatchMirror.testSink = null
        WatchSync.testSink = null
        Health.api = RealHealth
        Router.ask = null; Router.finish = null
    }

    private fun idle(ms: Long = 0) {
        if (ms > 0) ShadowLooper.idleMainLooper(ms, java.util.concurrent.TimeUnit.MILLISECONDS) else ShadowLooper.idleMainLooper()
        rule.waitForIdle()
    }

    private fun watchRecord(endedAgo: Duration = Duration.ofMinutes(1)): Record {
        val end = Instant.ofEpochMilli(System.currentTimeMillis()).minus(endedAgo)
        val segs = SeqBuilder.full(Division.of("openM"), false, Defaults.goals).map { SegResult(it.icon, it.name, it.detail, it.kind, it.target, it.target, hr = 150) }
        val total = segs.sumOf { it.time }
        return Record(mode = Mode.Sim, title = "Full Simulation", date = end.minusSeconds(total.toLong()), total = total, segs = segs,
            hr = emptyList(), kcal = 600, avgHR = 150, maxHR = 175, division = "Open Men", vsWord = "VS GOAL", vsTarget = total,
            complete = true, endDate = end)
    }

    // MARK: 기록 받기

    @Test fun recordFromWatchIsSavedOnceWithCard() {
        Store.resetForTest(app)
        Router.scr = Scr.Home
        val r = watchRecord()
        assertTrue(WatchSync.receiveRecord(WatchWire.recordJson(r)))
        idle()
        assertEquals(1, Store.records.size)
        assertNull(Store.records[0].source)                  // 워치 기록
        assertNotNull(Router.finish)                          // 방금 끝난 운동 → 끝 카드
        assertEquals(Scr.Detail, Router.scr)
        // 같은 기록이 또 와도 하나만 (그래도 true → 워치 보관함에서 빠지게 확인은 보냄)
        Router.finish = null
        assertTrue(WatchSync.receiveRecord(WatchWire.recordJson(r)))
        idle()
        assertEquals(1, Store.records.size)
        assertNull(Router.finish)
        // 깨진 글자
        assertFalse(WatchSync.receiveRecord("{oops"))
    }

    @Test fun oldRecordArrivesQuietly() {
        Store.resetForTest(app)
        Router.scr = Scr.Home
        WatchSync.receiveRecord(WatchWire.recordJson(watchRecord(Duration.ofHours(3))))
        idle()
        assertEquals(1, Store.records.size)
        assertNull(Router.finish)                             // 오래 전 기록은 카드 없이 저장만
        assertEquals(Scr.Home, Router.scr)
    }

    // MARK: 워치로 보내는 묶음

    @Test fun contextGoesToWatchWhenThingsChange() {
        Store.resetForTest(app)
        idle(500)
        pushed.clear()
        Store.update { it.copy(goalTime = 4000, event = it.event.copy(name = "Incheon")) }
        Store.saveProgram(Program.hiit())
        idle(500)                                             // 0.4초 모아서 한 번
        assertEquals(1, pushed.size)
        val c = WatchWire.ctx(pushed.last())!!
        assertEquals(4000, c.settings.goalTime)
        assertEquals("Incheon", c.settings.event.name)
        assertTrue(c.programs.any { it.isHIIT })
        // 같은 내용이면 다시 안 보냄
        WatchSync.push()
        assertEquals(1, pushed.size)
    }

    @Test fun watchRecordUpdatesBestsSentToWatch() {
        Store.resetForTest(app)
        WatchSync.receiveRecord(WatchWire.recordJson(watchRecord()))
        idle(500)
        val c = WatchWire.ctx(pushed.last())!!
        assertEquals(16, c.simBest!!.size)                    // 새 최고 기록이 워치 Full Sim 비교 기준으로
        assertEquals(16, c.simLast!!.size)
    }

    // MARK: 워치 운동 같이 보기

    private fun liveState(idx: Int = 4, el: Int = 80, running: Boolean = true, canUndo: Boolean = true, finished: Boolean = false): LiveState {
        val seq = SeqBuilder.full(Division.of("openM"), true, Defaults.goals)
        return LiveState(Mode.Sim, "Full Simulation", seq, idx, seq.take(idx).map { it.target }, el, running, 158, 286, 4, canUndo, finished,
            "VS GOAL", delta = 12)
    }

    private fun showMirror(st: LiveState) {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.scr = Scr.Home
        WatchMirror.received(LivePacket(state = st).bytes(), "node1")
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    @Test fun mirrorOpensAndButtonsGoToWatch() {
        showMirror(liveState())
        assertEquals(Scr.WatchLive, Router.scr)
        rule.onNodeWithTag("watchLive.of", useUnmergedTree = true).assertTextEquals("3 / 16")   // Run 1 · Ski · Run 2 → 3번째 (Roxzone 뺌)
        rule.onNodeWithTag("watchLive.hr", useUnmergedTree = true).assertTextEquals("158")
        tap("watchLive.next")
        tap("watchLive.undo")
        tap("watchLive.pause")
        tap("watchLive.end"); tap("ask.ok")
        assertEquals(listOf(LiveCommand.Next, LiveCommand.Undo, LiveCommand.Pause, LiveCommand.End), sentCmds)
    }

    @Test fun mirrorTimeKeepsRunningBetweenMessages() {
        showMirror(liveState(el = 80))
        t += 7_000
        rule.mainClock.advanceTimeBy(300)
        rule.onNodeWithTag("watchLive.seg", useUnmergedTree = true).assertExists()
        assertEquals(87, WatchMirror.state!!.segEl(t, WatchMirror.received))
    }

    @Test fun mirrorReconnectingAfterSilence() {
        showMirror(liveState())
        t += 13_000
        idle(2_100)
        assertTrue(WatchMirror.reconnecting)
        rule.onNodeWithTag("watchLive.status", useUnmergedTree = true).assertTextEquals("Watch · Reconnecting…")
        tap("watchLive.next")                                 // 끊긴 동안은 못 누름
        assertTrue(sentCmds.isEmpty())
        WatchMirror.apply(liveState())                        // 다시 소식이 옴
        assertFalse(WatchMirror.reconnecting)
    }

    @Test fun mirrorSavingThenRecordCard() {
        showMirror(liveState())
        WatchMirror.apply(liveState(finished = true))
        rule.waitForIdle()
        rule.onNodeWithTag("watchLive.saving").assertExists()
        Router.showFinish(watchRecord(), Scr.Home)
        WatchMirror.recordArrived(watchRecord())
        rule.waitForIdle()
        assertFalse(WatchMirror.on)
        assertNotNull(Router.finish)
    }

    @Test fun mirrorDiscardGoesHome() {
        showMirror(liveState())
        WatchMirror.apply(liveState().copy(discarded = true))
        idle(1_600)
        assertTrue(WatchMirror.discarded)
        assertEquals(Scr.Home, Router.scr)
    }

    @Test fun mirrorOffInSettingsShowsNothing() {
        Store.useDemo(Settings(hasOnboarded = true).withMirror(false), Program.presets(), emptyList())
        Router.scr = Scr.Home
        WatchMirror.received(LivePacket(state = liveState()).bytes(), "node1")
        assertFalse(WatchMirror.on)
        assertEquals(Scr.Home, Router.scr)
    }

    @Test fun phoneRecordingIsNotInterrupted() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.scr = Scr.PhoneLive
        WatchMirror.received(LivePacket(state = liveState()).bytes(), "node1")
        assertEquals(Scr.PhoneLive, Router.scr)                // 폰으로 직접 기록 중이면 화면을 안 바꿈
        Router.scr = Scr.Home
    }
}
