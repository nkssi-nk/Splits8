package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.screens.placeLabel
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Settings
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

/** 폰으로 기록 (넘기기 · 되돌리기 · 일시정지 · 끝내기 · GPS 러닝) + 끝 카드 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h915dp-xxhdpi")
class PhoneFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private var t = 1_790_000_000_000L

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.now = { java.time.Instant.ofEpochMilli(t) }
        val o = Demo.Opts()
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o))
        Router.phoneClock = { t }
        Router.phoneNoCount = true
        Router.scr = Scr.Sim
    }

    @After fun tearDown() {
        Router.phoneClock = { System.currentTimeMillis() }
        Router.phoneNoCount = false
        Router.ask = null; Router.finish = null; Router.phoneRun = null
    }

    private fun start(mode: Mode, program: Program? = null) {
        Router.startOnPhone(mode, program)
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }
    private fun wait(sec: Int) { t += sec * 1000L }
    private val eng get() = Router.phoneEngine

    @Test fun fullSimToFinishCard() {
        val before = Store.records.size
        start(Mode.Sim)
        assertTrue(eng.active)
        val n = eng.seq.size
        repeat(n) { wait(if (eng.cur.kind == SegKind.Rox) 20 else 260); tap("phone.next") }
        assertEquals(before + 1, Store.records.size)
        val rec = Store.records.first { it.source == "phone" }
        assertEquals("phone", rec.source)
        assertEquals(Mode.Sim, rec.mode)
        assertTrue(rec.isComplete)
        assertEquals(16, rec.splits16!!.size)
        assertEquals(Scr.Detail, Router.scr)
        assertNotNull(Router.finish)
        rule.onNodeWithTag("finish.line").assertExists()
        tap("finish.primary")                               // Share
        assertEquals(Scr.Share, Router.scr)
    }

    @Test fun undoJoinsTheTime() {
        start(Mode.Sim)
        wait(100); tap("phone.next")
        wait(5); tap("phone.undo")                           // 잘못 넘김 → 되돌리기
        assertEquals(0, eng.idx)
        assertEquals(105, eng.segEl(t))                      // 앞 구간 시간이 이어짐
        assertFalse(eng.canUndo)
    }

    @Test fun pauseIsNotCounted() {
        start(Mode.Sim)
        wait(30); tap("phone.pause")
        wait(60); tap("phone.pause")                         // Resume
        wait(10)
        assertEquals(40, eng.total(t))
    }

    @Test fun endSaveKeepsWhatWasDone() {
        start(Mode.Sim)
        wait(250); tap("phone.next")
        wait(40)
        tap("phone.end"); tap("ask.ok")                      // Save
        val rec = Router.detail!!
        assertEquals(2, rec.segs.size)
        assertFalse(rec.isComplete)
        assertEquals(Scr.Detail, Router.scr)
    }

    @Test fun endDiscardGoesBack() {
        val before = Store.records.size
        start(Mode.Sim)
        wait(30)
        tap("phone.end"); tap("ask.alt")                     // Discard
        assertEquals(before, Store.records.size)
        assertEquals(Scr.Sim, Router.scr)
    }

    @Test fun countdownTapCancels() {
        Router.phoneNoCount = false
        start(Mode.Sim)
        rule.onNodeWithTag("phone.count", useUnmergedTree = true).assertTextEquals("3")
        tap("phone.countdown")
        assertEquals(Scr.Sim, Router.scr)
        assertFalse(eng.active)
    }

    @Test fun hiitGrowsUntilEnd() {
        start(Mode.Training, Program.hiit())
        repeat(3) { wait(45); tap("phone.next") }
        assertEquals(4, eng.seq.size)                       // 라운드가 계속 붙음
        tap("phone.end"); tap("ask.ok")
        assertEquals(4, Router.detail!!.segs.size)
    }

    @Test fun gpsRunSplitsEveryKmAndFinishes() {
        // 야외 2 km 러닝: 위치를 넣으면 1 km 마다 저절로 넘어가고 2 km 에서 끝남
        val run = Program.run(2, indoor = false)
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, run, Scr.Training))
        assertTrue(e.useGPS)
        var lat = 37.5444
        repeat(230) {                                        // 10 m 씩 2.3 km
            t += 3000; lat += 10 / 111_320.0
            e.gotLocation(lat, 127.0374, 5f, 24.0, 3f, t)
        }
        val rec = e.autoDone
        assertNotNull(rec)
        assertEquals(2, rec!!.runs.size)
        assertTrue(rec.route!!.size > 100)
        assertTrue(rec.runs.all { (it.dist ?: 0.0) >= 1000 })
    }

    @Test fun inaccurateFixIsIgnored() {
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, Program.run(1, indoor = false), Scr.Training))
        e.gotLocation(37.0, 127.0, 5f, null, null, t)
        e.gotLocation(37.001, 127.0, 50f, null, null, t)     // 정확도 50 m → 버림
        assertEquals(0.0, e.segDist, 0.01)
    }

    @Test fun placeLabels() {
        assertEquals("성수동, 서울", placeLabel("성수동", "서울특별시"))
        assertEquals("Seongsu-dong, Seoul", placeLabel("Seongsu-dong", "Seoul"))
        assertEquals("부산", placeLabel(null, "부산광역시"))
        assertNull(placeLabel(null, null))
    }
}
