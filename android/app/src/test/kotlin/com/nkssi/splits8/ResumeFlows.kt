package com.nkssi.splits8

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/** 폰으로 기록하던 중 앱이 완전히 꺼졌다가 다시 열림 → 이어서 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ResumeFlows {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private var t = 1_790_000_000_000L
    private val file get() = File(app.filesDir, "phone_run.json")

    @Before fun setUp() {
        Store.resetForTest(app)
        Store.update { it.copy(hasOnboarded = true) }
        Store.now = { java.time.Instant.ofEpochMilli(t) }
        Router.phoneClock = { t }
        Router.scr = Scr.Sim
    }

    @After fun tearDown() {
        Router.phoneClock = { System.currentTimeMillis() }
        Store.now = { java.time.Instant.now() }
        Router.finish = null; Router.phoneRun = null
    }

    /** 앱이 꺼졌다가 다시 열림 (화면 · 기록 엔진이 새로 만들어짐) */
    private fun relaunch() {
        Router.phoneEngine = PhoneRunEngine(); Router.phoneRun = null; Router.scr = Scr.Splash
        Router.start()
    }

    @Test fun killedMidWorkoutResumesWhereItWas() {
        Router.startOnPhone(Mode.Sim, null)
        val e = Router.phoneEngine
        e.start(Router.phoneRun!!)
        t += 250_000; e.advance()                 // Run 1 끝 (4:10)
        t += 20_000; e.advance()                  // Roxzone 끝
        t += 30_000                               // SkiErg 30초째에 앱이 꺼짐
        assertTrue(file.exists())
        t += 60_000                               // 꺼져 있던 1분도 운동 시간
        relaunch()
        assertEquals(Scr.PhoneLive, Router.scr)
        val r = Router.phoneEngine
        assertTrue(r.active)
        assertEquals(2, r.idx)
        assertEquals("SkiErg", r.cur.name)
        assertEquals(90, r.segEl(t))
        assertEquals(360, r.total(t))
        assertEquals(Mode.Sim, Router.phoneRun!!.mode)
        // 이어서 끝까지 → 기록 저장 · 파일 지움
        while (r.active && !r.finished) { t += 200_000; r.advance()?.let { Store.addPhoneRecord(it) } }
        assertFalse(file.exists())
        val rec = Store.records.single()
        assertEquals(250, rec.segs[0].time)
        assertEquals(290, rec.segs[2].time)       // 꺼지기 전 30초 + 꺼져 있던 60초 + 이어서 200초
    }

    @Test fun pausedStaysPaused() {
        Router.startOnPhone(Mode.Training, Program.hiit())
        val e = Router.phoneEngine
        e.start(Router.phoneRun!!)
        t += 40_000; e.togglePause()
        t += 600_000                              // 쉬는 동안 꺼짐
        relaunch()
        val r = Router.phoneEngine
        assertFalse(r.running)
        assertEquals(40, r.total(t))
        t += 5_000; r.togglePause(); t += 5_000
        assertEquals(45, r.total(t))
    }

    @Test fun discardOrOldRunIsNotResumed() {
        Router.startOnPhone(Mode.Sim, null)
        Router.phoneEngine.start(Router.phoneRun!!)
        Router.phoneEngine.discard()
        assertFalse(file.exists())
        relaunch()
        assertEquals(Scr.Home, Router.scr)
        // 12시간이 넘은 것은 버림
        Router.startOnPhone(Mode.Sim, null)
        Router.phoneEngine.start(Router.phoneRun!!)
        assertTrue(file.exists())
        t += 13 * 3600_000L
        relaunch()
        assertEquals(Scr.Home, Router.scr)
        assertNull(Store.loadPhoneRun())
    }

    @Test fun stepsContinueAfterRelaunch() {
        Router.startOnPhone(Mode.Training, Program.run(3, indoor = true))
        val e = Router.phoneEngine
        e.start(Router.phoneRun!!)
        e.gotSteps(500.0); t += 180_000; e.advance()
        relaunch()
        val r = Router.phoneEngine
        r.gotSteps(10.0)                          // 센서는 0 부터 다시 셈 → 이어서 510
        assertNotNull(r.snapshot())
        assertEquals(510.0, r.snapshot()!!.rawSteps, 0.01)
    }
}
