package com.nkssi.splits8.wear

import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.IvStep
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.Lift
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.VoiceCoach
import com.nkssi.splits8.shared.WatchWire
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** 18번: 워치 엔진 — 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 (시계 · 측정 · 진동은 가짜) */
class BonusEngineTest {
    private var t = 1_790_000_000_000L
    private lateinit var e: WorkoutEngine
    private val buzzes = ArrayList<BuzzKind>()
    private val sent = ArrayList<Record>()
    private val said = ArrayList<List<String>>()
    private var cfg: ExerciseCfg? = null

    private val fake = object : WorkoutSensors {
        override fun start(cfg: ExerciseCfg, sink: SensorSink) { this@BonusEngineTest.cfg = cfg }
        override fun pause() {}
        override fun resume() {}
        override fun end(save: Boolean) {}
    }

    @Before fun setUp() {
        e = WorkoutEngine { t }
        e.sensors = fake
        e.buzz = { buzzes.add(it) }
        e.onRecord = { sent.add(it) }
        e.settings = Settings()
    }

    private val div = Division.of("openM")

    private fun start(p: Program) = e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)

    /** ms 만큼 0.25초씩 흘려 보냄 (운동 서비스처럼) */
    private fun run(ms: Long) {
        var left = ms
        while (left > 0) {
            val d = minOf(250L, left)
            t += d; left -= d
            e.timerTick()
        }
    }

    @Test fun tabataRunsByItself() {
        val p = Bonus.tabata(20, 10, 3)
        start(p)
        assertEquals(true, cfg?.hiit)
        assertEquals(false, cfg?.gps)
        assertEquals(20, e.segLeft())
        run(17_000)
        assertEquals(BuzzKind.Tick, buzzes.last())             // 3초 전 진동
        run(3_000)
        assertEquals(1, e.idx)                                   // 휴식
        assertEquals(SegKind.Rox, e.cur.kind)
        assertEquals(listOf(20), e.splits)
        run(10_000 + 20_000 + 10_000 + 20_000)
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(Kinds.TABATA, r.kind)
        assertEquals(listOf(20, 10, 20, 10, 20), r.segs.map { it.time })
        assertEquals(80, r.total)
        assertTrue(r.isComplete)
        assertEquals(20, r.cap)
        assertNull(r.vsTarget)
        assertEquals(3, Bonus.tabataDone(r))
        assertEquals(r, WatchWire.record(WatchWire.recordJson(r)))
    }

    /** 화면이 꺼져서 한참 뒤에 확인해도 구간 시간은 정확 */
    @Test fun tabataCatchesUpAfterSleep() {
        start(Bonus.tabata(20, 10, 4))
        t += 65_500
        e.timerTick()
        // 20 + 10 + 20 + 10 = 60 → 셋째 운동 5.5초째
        assertEquals(4, e.idx)
        assertEquals(listOf(20, 10, 20, 10), e.splits)
        assertEquals(5, e.segEl())
    }

    @Test fun pauseStopsTimer() {
        start(Bonus.tabata(20, 10, 2))
        run(5_000)
        e.togglePause()
        t += 60_000; e.timerTick()
        assertEquals(0, e.idx)
        e.togglePause()
        run(15_000)
        assertEquals(1, e.idx)
        assertEquals(listOf(20), e.splits)
    }

    @Test fun emomDoneMarksRoundTime() {
        val p = Bonus.emom(60, 3, listOf("Burpees 10"))
        start(p)
        assertEquals(listOf("Burpees 10"), e.tasks)
        run(42_000)
        e.advance()                                              // "끝" — 넘기지 않음
        assertEquals(0, e.idx)
        assertEquals(42, e.segWork[0])
        e.gotCommand(LiveCommand.Next)                           // 두 번 눌러도 처음 값
        assertEquals(42, e.segWork[0])
        run(18_000)
        assertEquals(1, e.idx)
        assertFalse(e.canUndo)
        run(120_000)
        val r = sent.single()
        assertEquals(listOf(60, 60, 60), r.segs.map { it.time })
        assertEquals(listOf(42, null, null), r.segs.map { it.work })
        assertEquals(60, r.cap)
    }

    @Test fun amrapCountsRoundsAndEndsAtCap() {
        val p = Bonus.amrap(300)
        start(p)
        assertTrue(e.growsOpen)
        assertEquals(300, e.capLeft())
        run(70_000); e.advance()
        run(80_000); e.advance()
        assertTrue(e.canUndo)
        assertEquals(2, e.idx)
        assertEquals("Round 3", e.cur.name)
        run(149_000)
        assertFalse(e.finished)
        run(1_000)
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(listOf(70, 80, 150), r.segs.map { it.time })
        assertEquals(300, r.total)
        assertEquals(2, r.rounds)
        assertEquals(300, r.cap)
        assertTrue(r.isComplete)
    }

    @Test fun amrapEndedEarlyIsIncomplete() {
        start(Bonus.amrap(600))
        run(100_000); e.advance(); run(20_000)
        e.endNow()
        val r = sent.single()
        assertFalse(r.isComplete)
        assertEquals(1, r.rounds)
    }

    @Test fun ivrunDistanceAndTimeSteps() {
        val p = Bonus.ivrun(listOf(IvStep(IvStep.FAST, m = 400), IvStep(IvStep.EASY, s = 60)), 2, indoor = false)
        start(p)
        assertEquals(false, cfg?.hiit)
        assertEquals(true, cfg?.gps)
        assertTrue(e.outdoorRun)
        t += 80_000; e.gotDistance(390.0)
        assertEquals(0, e.idx)
        t += 2_000; e.gotDistance(402.0)
        assertEquals(1, e.idx)                                   // 400 m → 천천히 1분
        run(60_000)
        assertEquals(2, e.idx)
        e.gotDistance(560.0)
        t += 70_000; e.gotDistance(1000.0)
        assertEquals(3, e.idx)
        e.advance()                                               // 밀어서 강제로 넘기기 (마지막 → 끝)
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(Kinds.IVRUN, r.kind)
        assertEquals(listOf(82, 60, 70, 0), r.segs.map { it.time })
        assertEquals(402.0, r.segs[0].dist!!, 0.01)
        assertEquals("Fast", r.segs[0].name)
        assertNull(r.indoor)
    }

    @Test fun liftSetRestNext() {
        val p = Bonus.lift(listOf(Lift("Squat", 2, 5, 80.0)), rest = 60)
        start(p)
        assertEquals(true, cfg?.hiit)
        run(40_000); e.advance()                                  // 세트 끝 → 휴식
        assertEquals(1, e.idx)
        assertEquals(60, e.segLeft())
        run(60_000)
        assertEquals(2, e.idx)                                     // 휴식 끝 → 다음 세트
        run(35_000); e.advance()
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(listOf(40, 60, 35), r.segs.map { it.time })
        assertEquals(5, r.segs[0].reps)
        assertEquals(80.0, r.segs[0].kg!!, 0.0)
        assertEquals(2 * 5 * 80.0, Bonus.volume(r), 0.01)
    }

    @Test fun countdownVoiceForTimers() {
        e.settings = Settings().copy(voiceOpt = true)
        e.voice = { said.add(it.clips) }
        val p = Bonus.tabata()
        val was = com.nkssi.splits8.shared.L10n.lang
        com.nkssi.splits8.shared.L10n.lang = "ko"
        try {
            e.startAfterCountdown(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
            e.countTick(); e.countTick(); e.countTick()
            assertTrue(e.active)
            assertEquals(listOf(listOf("cd_3"), listOf("cd_2"), listOf("cd_1"), listOf("cd_go"), listOf("iv_work")), said)
            run(20_000)
            assertEquals(listOf("iv_rest"), said.last())
        } finally {
            com.nkssi.splits8.shared.L10n.lang = was
        }
    }

    @Test fun hyroxCountdownHasNoVoice() {
        e.settings = Settings().copy(voiceOpt = true)
        e.voice = { line: VoiceCoach.Line -> said.add(line.clips) }
        val p = Program.hiit()
        e.startAfterCountdown(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        e.countTick(); e.countTick(); e.countTick()
        assertTrue(said.none { it.any { c -> c.startsWith("cd_") } })
    }
}
