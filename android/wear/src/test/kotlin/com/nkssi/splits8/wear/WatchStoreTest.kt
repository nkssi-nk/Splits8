package com.nkssi.splits8.wear

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.CalibResult
import com.nkssi.splits8.shared.SplitsJson
import com.nkssi.splits8.shared.SyncKey
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.WatchContext
import com.nkssi.splits8.shared.WatchWire
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

/** 워치 저장소: 폰 묶음 받기 · 기록 보관함(폰 확인 전까지) · 빠른 트레이닝 하나만 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w225dp-h225dp-round-watch-xhdpi")
class WatchStoreTest {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val sent = ArrayList<Record>()

    @Before fun setUp() {
        WatchStore.resetForTest(app)
        WatchStore.testRecordSink = { sent.add(it) }
    }

    @After fun tearDown() { WatchStore.testRecordSink = null; L10n.lang = "en" }

    private fun rec(i: Int) = Record(mode = Mode.Training, title = "T$i", date = Instant.ofEpochSecond(1_790_000_000L + i), total = 60,
        segs = emptyList(), hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = "Open Men", vsWord = "VS BEST")

    @Test fun outboxKeepsUntilPhoneConfirms() {
        val r = rec(1)
        WatchStore.send(r)
        assertEquals(listOf(r), sent)
        assertEquals(1, WatchStore.pending.size)
        // 앱을 껐다 켜도 남아 있음
        WatchStore.reloadForTest(app)
        assertEquals(listOf(r.id), WatchStore.pending.map { it.id })
        WatchStore.send(rec(2))
        WatchStore.delivered(r.id)                          // 폰이 받았다고 확인
        assertEquals(listOf("T2"), WatchStore.pending.map { it.title })
    }

    @Test fun outboxKeepsLast20() {
        repeat(25) { WatchStore.send(rec(it)) }
        assertEquals(20, WatchStore.pending.size)
        assertEquals("T5", WatchStore.pending.first().title)
    }

    @Test fun phoneContextAppliesButNotDuringWorkout() {
        val c = WatchContext(Settings(goalTime = 3900, lang = "ko"), listOf(Program.hiit()))
        WatchStore.apply(WatchWire.ctxJson(c))
        assertEquals(3900, WatchStore.settings.goalTime)
        assertEquals("ko", L10n.lang)                       // 언어가 바로 바뀜
        assertEquals(3900, WatchStore.engine.settings.goalTime)
        assertTrue(WatchStore.programs.single().isHIIT)
        // 운동 중에는 엔진 설정을 덮지 않음
        WatchStore.engine.start(Mode.Sim, "Full Simulation", seq = WatchStore.seq(Mode.Sim, null))
        WatchStore.apply(WatchWire.ctxJson(c.copy(settings = c.settings.copy(goalTime = 3600))))
        assertEquals(3600, WatchStore.settings.goalTime)
        assertEquals(3900, WatchStore.engine.settings.goalTime)
    }

    @Test fun quickNotKept() {
        // 빌드 25 (66번): Quick 은 워치 목록에 남지 않음 (이번 운동에만 씀)
        val p = WatchStore.saveQuick(listOf(ProgItem("run", "1KM"), ProgItem("sledPush")))
        assertTrue(p.quick)
        assertTrue(WatchStore.quickSaved.isEmpty())
        assertTrue(WatchStore.programs.none { it.id == p.id })
        WatchStore.reloadForTest(app)
        assertTrue(WatchStore.quickSaved.isEmpty())
    }

    // MARK: 빌드 27 · 28

    @Test fun watchGoalSavedOnWatchAndSplits() {
        // 68-① · 86번: 워치에서 고른 목표는 워치에만 저장, 다시 켜도 그대로, 16구간을 그 목표로 나눔
        assertNull(WatchStore.watchGoal)
        WatchStore.pickWatchGoal(5400)
        WatchStore.reloadForTest(app)
        assertEquals(5400, WatchStore.watchGoal)
        val (t, w) = WatchStore.simPick
        assertEquals("GOAL", w)
        assertEquals(16, t.size)
        assertEquals(5400 - 8 * WatchStore.settings.roxTarget, t.sum())
        assertEquals(t.sum() + 15 * WatchStore.settings.roxTarget, WatchStore.seq(Mode.Sim, null).sumOf { it.target })
        WatchStore.pickWatchGoal(null)
        WatchStore.reloadForTest(app)
        assertNull(WatchStore.watchGoal)
        assertEquals("VS GOAL", WatchStore.simPick.second)
    }

    @Test fun calibrationResultSentAndKept() {
        // 98번: 결과는 /calib-done/<id> 에 CalibResult JSON, 워치에도 바로 씀
        val got = ArrayList<Pair<String, String>>()
        WatchStore.testCalibSink = { p, j -> got.add(p to j) }
        try {
            val tune = RepTune(0.38, 0.17, 1.0, 0.7, Instant.now().truncatedTo(java.time.temporal.ChronoUnit.SECONDS))
            WatchStore.applyCalibration("wallBalls", tune)
            val (path, json) = got.single()
            assertTrue(path.startsWith(SyncKey.calibDone + "/"))
            assertTrue(path.length > SyncKey.calibDone.length + 1)
            assertEquals(CalibResult("wallBalls", tune), SplitsJson.decodeFromString(CalibResult.serializer(), json))
            assertEquals(tune, WatchStore.settings.repCal!!["wallBalls"])
            assertEquals(tune, WatchStore.engine.settings.repCal!!["wallBalls"])
            assertEquals(tune, RepCounter.tuning("wallBalls"))
            // 폰 설정이 아직 이 값을 모른 채 내려와도 (10분 안) 지우지 않음
            WatchStore.apply(WatchWire.ctxJson(WatchContext(Settings(), emptyList())))
            assertEquals(tune, WatchStore.settings.repCal!!["wallBalls"])
            // 10분이 지나면 폰 설정을 따름
            WatchStore.apply(WatchWire.ctxJson(WatchContext(Settings(), emptyList())), Instant.now().plusSeconds(700))
            assertNull(WatchStore.settings.repCal)
        } finally { WatchStore.testCalibSink = null }
    }

    @Test fun calibrationFlow() {
        // 98번: 시작 → 세기 → 끝 → 실제 개수 → 저장 (화면 없이)
        val got = ArrayList<String>()
        WatchStore.testCalibSink = { _, j -> got.add(j) }
        try {
            assertEquals("wallBalls", Calib.iconFrom(Calib.uri("wallBalls")))
            assertNull(Calib.iconFrom(android.net.Uri.parse("splits8://calib?icon=sledPush")))
            assertNull(Calib.iconFrom(android.net.Uri.parse("splits8://other?icon=row")))
            assertFalse(Calib.request("sledPush"))
            assertTrue(Calib.request("row"))
            assertEquals(Calib.Phase.Ready, Calib.phase)
            Calib.begin()
            assertEquals(Calib.Phase.Counting, Calib.phase)
            var s = 0.0
            repeat(18) {
                repeat(10) { s += 0.02; Calib.feed(0.9, s) }
                repeat(70) { s += 0.02; Calib.feed(0.05, s) }
            }
            org.robolectric.shadows.ShadowLooper.idleMainLooper()
            assertEquals(18, Calib.live)
            Calib.stop()
            assertEquals(Calib.Phase.Confirm, Calib.phase)
            assertEquals(20, Calib.actual)
            Calib.actual = 18
            Calib.save()
            assertEquals(Calib.Phase.Saved, Calib.phase)
            val tune = Calib.saved!!
            assertEquals(CalibResult("row", tune), SplitsJson.decodeFromString(CalibResult.serializer(), got.single()))
            Calib.close()
            assertNull(Calib.icon)
            // 운동 중에는 보정 화면을 띄우지 않음
            WatchStore.engine.start(Mode.Sim, "Full Simulation", seq = WatchStore.seq(Mode.Sim, null))
            assertFalse(Calib.request("row"))
        } finally { WatchStore.testCalibSink = null; Calib.close() }
    }
}
