package com.nkssi.splits8.wear

import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.LiveState
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SeqBuilder
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.WatchWire
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** 워치 운동 엔진 (아이폰 WorkoutEngine 과 같은 규칙인지) — 시계 · 측정 · 진동은 가짜 */
class EngineTest {
    private var t = 1_790_000_000_000L
    private lateinit var e: WorkoutEngine
    private val buzzes = ArrayList<BuzzKind>()
    private val sent = ArrayList<Record>()
    private val lives = ArrayList<LiveState>()
    private var cfg: ExerciseCfg? = null
    private var ended: Boolean? = null
    private var activeCalls = ArrayList<Boolean>()

    private val fake = object : WorkoutSensors {
        override fun start(cfg: ExerciseCfg, sink: SensorSink) { this@EngineTest.cfg = cfg }
        override fun pause() {}
        override fun resume() {}
        override fun end(save: Boolean) { ended = save }
    }

    private fun sec(n: Int) { t += n * 1000L }

    @Before fun setUp() {
        e = WorkoutEngine { t }
        e.sensors = fake
        e.buzz = { buzzes.add(it) }
        e.onRecord = { sent.add(it) }
        e.onLive = { lives.add(it) }
        e.onActive = { activeCalls.add(it) }
        e.settings = Settings()
    }

    private val div = Division.of("openM")
    private fun simSeq() = SeqBuilder.full(div, true, Defaults.goals)

    @Test fun fullSimToEnd() {
        val seq = simSeq()
        assertEquals(31, seq.size)                         // 러닝 8 + 스테이션 8 + Roxzone 15
        e.start(Mode.Sim, "Full Simulation", seq = seq, simWord = "VS GOAL")
        assertTrue(e.active)
        assertEquals(listOf(true), activeCalls)
        repeat(30) { sec(100); e.advance() }
        assertEquals(30, e.idx)
        sec(100); e.advance()                               // 마지막 → 끝
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(Mode.Sim, r.mode)
        assertEquals(31 * 100, r.total)
        assertEquals(16, r.splits16!!.size)
        assertEquals("VS GOAL", r.vsWord)
        assertEquals(seq.sumOf { it.target }, r.vsTarget)
        assertTrue(r.isComplete)
        assertEquals(true, ended)
        assertEquals(listOf(true, false), activeCalls)
        assertEquals(BuzzKind.Success, buzzes.last())
        // 폰으로 가는 글자가 그대로 다시 읽힘
        assertEquals(r, WatchWire.record(WatchWire.recordJson(r)))
    }

    @Test fun undoJoinsTime() {
        e.start(Mode.Race, "Seoul", seq = simSeq())
        sec(250); e.advance()
        assertEquals(1, e.idx)
        assertTrue(e.canUndo)
        sec(15); e.undo()                                   // 잘못 넘김 → 앞 구간으로, 시간은 이어짐
        assertEquals(0, e.idx)
        assertEquals(265, e.segEl())
        assertFalse(e.canUndo)
        assertEquals(BuzzKind.Undo, buzzes.last())
        sec(5); e.advance()
        assertEquals(listOf(270), e.splits)
    }

    @Test fun pauseNotCounted() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        sec(60); e.togglePause()
        assertFalse(e.running)
        sec(300)
        assertEquals(60, e.total())
        e.advance()                                         // 멈춘 동안은 못 넘김
        assertEquals(0, e.idx)
        e.togglePause(); sec(10)
        assertEquals(70, e.segEl())
    }

    @Test fun endEarlyIsIncomplete() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        sec(200); e.advance(); sec(30)
        e.endNow()
        val r = sent.single()
        assertEquals(2, r.segs.size)
        assertFalse(r.isComplete)
    }

    @Test fun hiitGrowsAndEndCompletes() {
        val p = Program.hiit()
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        assertEquals(true, cfg?.hiit)
        assertTrue(e.growsOpen)
        repeat(4) { sec(40); e.advance() }
        assertEquals(5, e.seq.size)                         // 라운드가 계속 붙음
        assertEquals("Round 6", e.nextSeg.name)
        sec(40); e.endNow()
        val r = sent.single()
        assertEquals(5, r.segs.size)
        assertTrue(r.isComplete)
        assertNull(r.vsTarget)
        assertEquals("hiit", r.kind)
    }

    @Test fun runCardAutoSplitsEveryKm() {
        val p = Program.run(3, indoor = false)
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        assertEquals(ExerciseCfg(hiit = false, gps = true, steps = true), cfg)
        e.gotDistance(500.0); sec(150)
        e.advance()                                         // 러닝은 손으로 못 넘김
        assertEquals(0, e.idx)
        sec(150); e.gotDistance(1001.0)
        assertEquals(1, e.idx)
        assertEquals(BuzzKind.Next, buzzes.last())
        sec(290); e.gotDistance(2003.0)
        sec(310); e.gotDistance(3004.0)
        assertTrue(e.finished)
        val r = sent.single()
        assertEquals(3, r.segs.size)
        assertEquals(listOf(300, 290, 310), r.segs.map { it.time })
        assertEquals(1001.0, r.segs[0].dist!!, 0.01)
    }

    @Test fun indoorRunWithoutDistanceIsManual() {
        val p = Program.run(0, indoor = true)
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        assertFalse(e.autoSplit)
        sec(300); e.advance()
        assertEquals(1, e.idx)
        assertEquals(2, e.seq.size)                         // 자유 러닝: km 가 계속 붙음
    }

    @Test fun discardSendsNothing() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        sec(100); e.advance()
        e.discardNow()
        assertFalse(e.active)
        assertTrue(sent.isEmpty())
        assertEquals(false, ended)                          // 측정도 저장 안 함
        assertTrue(lives.last().discarded)                  // 폰 화면도 닫힘
        assertEquals(listOf(true, false), activeCalls)
    }

    @Test fun overTargetBuzzesOncePerSegment() {
        e.start(Mode.Race, "Seoul", seq = simSeq())
        val target = e.cur.target
        repeat(target) { sec(1); e.tick() }
        assertFalse(BuzzKind.Over in buzzes)
        sec(1); e.tick()
        assertEquals(1, buzzes.count { it == BuzzKind.Over })
        repeat(30) { sec(1); e.tick() }
        assertEquals(1, buzzes.count { it == BuzzKind.Over })
    }

    @Test fun noOverBuzzForTrainingOrRox() {
        val p = Program.presets()[0]
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        repeat(600) { sec(1); e.tick() }
        assertFalse(BuzzKind.Over in buzzes)
    }

    @Test fun zoneBuzzThrottled() {
        e.settings = Settings(hrMode = "manual", manualHr = 190)
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        e.gotHR(100.0, t)                                   // 첫 값: 진동 없음
        assertFalse(buzzes.any { it == BuzzKind.ZoneUp || it == BuzzKind.ZoneDown })
        sec(1); e.gotHR(180.0, t)
        assertEquals(BuzzKind.ZoneUp, buzzes.last())
        sec(3); e.gotHR(100.0, t)                           // 10초 안: 진동 없음
        assertEquals(1, buzzes.count { it == BuzzKind.ZoneUp || it == BuzzKind.ZoneDown })
        sec(11); e.gotHR(180.0, t)
        assertEquals(2, buzzes.count { it == BuzzKind.ZoneUp || it == BuzzKind.ZoneDown })
    }

    @Test fun hrSamplesEvery5s() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        repeat(20) { sec(1); e.gotHR(150.0 + it, t) }
        assertEquals(listOf(1, 6, 11, 16), e.liveState(t).let { e.endNow(); sent.single().hr.map { it.t } })
        assertEquals(160, sent.single().segs[0].hr)         // 구간 평균 심박
    }

    @Test fun countdownThenStart() {
        e.startAfterCountdown(Mode.Sim, "Full Simulation", seq = simSeq())
        assertEquals(3, e.countdown)
        assertFalse(e.active)
        e.countTick(); e.countTick()
        assertEquals(1, e.countdown)
        e.countTick()
        assertNull(e.countdown)
        assertTrue(e.active)
        assertEquals(listOf(BuzzKind.Tick, BuzzKind.Tick, BuzzKind.Tick, BuzzKind.Go), buzzes)
    }

    @Test fun countdownCancel() {
        e.startAfterCountdown(Mode.Sim, "Full Simulation", seq = simSeq())
        e.cancelCountdown()
        e.countTick()
        assertFalse(e.active)
        assertNull(e.countdown)
    }

    @Test fun phoneButtons() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        sec(90); e.gotCommand(LiveCommand.Next)
        assertEquals(1, e.idx)
        e.gotCommand(LiveCommand.Undo)
        assertEquals(0, e.idx)
        e.gotCommand(LiveCommand.Pause)
        assertFalse(e.running)
        e.gotCommand(LiveCommand.Pause)                     // 두 번 눌러도 그대로
        assertFalse(e.running)
        e.gotCommand(LiveCommand.Resume)
        assertTrue(e.running)
        e.gotCommand(LiveCommand.End)
        assertTrue(e.finished)
        assertEquals(1, sent.size)
    }

    @Test fun liveStateAndMirrorSwitch() {
        e.start(Mode.Race, "Seoul", seq = simSeq())
        sec(30); e.gotHR(150.0, t); e.gotEnergy(42.4)
        repeat(5) { sec(1); e.tick() }
        val st = lives.last()
        assertEquals(35, st.segElapsed)
        assertEquals(150, st.hr)
        assertEquals(42, st.kcal)
        assertEquals("VS GOAL", st.vsWord)
        assertFalse(st.open)
        // 설정 › Show on phone 끔 → 보내지 않음
        lives.clear()
        e.settings = e.settings.withMirror(false)
        repeat(10) { sec(1); e.tick() }
        e.advance()
        assertTrue(lives.isEmpty())
    }

    @Test fun pftRecordVsBestOnlyWithBest() {
        e.pftBestCount = 0
        e.start(Mode.Pft, PFT.title, seq = PFT.seq(div, null))
        repeat(PFT.items.size) { sec(120); e.advance() }
        assertNull(sent.single().vsTarget)                 // 최고 기록이 없으면 비교 없음
        sent.clear()
        e.pftBestCount = PFT.items.size
        e.reset()
        e.start(Mode.Pft, PFT.title, seq = PFT.seq(div, List(PFT.items.size) { 100 }))
        repeat(PFT.items.size) { sec(120); e.advance() }
        assertEquals(PFT.items.size * 100, sent.single().vsTarget)
    }

    @Test fun outdoorRoutePointsKept() {
        val p = Program.run(1, indoor = false)
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        var lat = 37.5
        repeat(10) { sec(5); lat += 0.0002; e.gotLocation(lat, 127.0, 5f, 30.0, 3f, t) }
        e.gotLocation(lat + 0.0001, 127.0, 80f, null, null, t)  // 너무 부정확 → 버림
        e.gotDistance(1001.0)
        val r = sent.single()
        assertEquals(10, r.route!!.size)
        assertNotNull(r.route!!.first().h)
    }

    @Test fun repCounterCountsStrokes() {
        val c = RepCounter(null)
        c.start("row")
        var s = 0.0
        // 1.6초마다 한 번 크게 당김 (0.9g), 사이에는 거의 가만히 (0.05g)
        repeat(10) {
            repeat(10) { s += 0.02; c.feed(0.9, s) }
            repeat(70) { s += 0.02; c.feed(0.05, s) }
        }
        assertEquals(10, c.stop())
        c.start("sledPush")
        assertNull(c.stop())                                // 세지 않는 종목
    }

    @Test fun roxzoneCountedInSeqButNotInSplits16() {
        e.start(Mode.Sim, "Full Simulation", seq = simSeq())
        assertEquals(SegKind.Run, e.cur.kind)
        sec(10); e.advance()
        assertEquals(SegKind.Rox, e.cur.kind)
    }

    // MARK: 빌드 27 · 28

    @Test fun indoorRunRecordFlag() {
        // 94번: 실내로 뛴 러닝 카드 기록은 indoor = true, 실외는 null
        val p = Program.run(1, indoor = false)
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p.copy(indoor = true))
        assertFalse(e.outdoorRun)
        assertEquals(false, cfg!!.gps)
        e.gotDistance(1000.0)
        assertEquals(true, sent.single().indoor)
        sent.clear()
        e.reset()
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        assertTrue(e.outdoorRun)
        e.gotDistance(1000.0)
        assertNull(sent.single().indoor)
    }

    @Test fun liveSpeedPaceAndSpd() {
        // 74-11: 지금 속도(부드럽게) → PACE, 폰에도 spd 로
        val p = Program.run(3, indoor = false)
        e.start(Mode.Training, p.name, seq = SeqBuilder.training(p, div, emptyMap()), program = p)
        assertNull(e.paceText(5, 20.0))                     // 속도 모르고 50 m 미만 → 측정 중
        assertEquals("–:––", e.paceText(0, 100.0))
        e.gotSpeed(3.2)
        assertEquals(3.2, e.curSpeed, 1e-9)                 // 처음 값은 그대로
        e.gotSpeed(4.2)
        assertEquals(3.5, e.curSpeed, 1e-9)                 // 0.3 × 새 값 + 0.7 × 예전
        assertEquals("4:46", e.paceText(10, 20.0))          // 1000 / 3.5 = 285.7초
        assertEquals("7:40", e.paceText(10, 20.0, imperial = true))
        repeat(5) { sec(1); e.tick() }
        assertEquals(3.5, lives.last().spd!!, 1e-9)
        // 10초 넘게 새 값이 없으면 모름 → spd 안 보냄, 구간 평균으로
        repeat(10) { sec(1); e.tick() }
        assertEquals(0.0, e.curSpeed, 0.0)
        assertNull(lives.last().spd)
        assertEquals("5:00", e.paceText(300, 1000.0))
        // 일시정지하면 속도 모름, 그동안 받은 값은 버림
        e.gotSpeed(3.0); e.togglePause()
        assertEquals(0.0, e.curSpeed, 0.0)
        e.gotSpeed(3.0)
        assertEquals(0.0, e.curSpeed, 0.0)
    }

    @Test fun repTuneFromSettings() {
        // 97번: 기본값, 98번: 폰에서 받은 보정값이 있으면 그것
        val s = Settings()
        assertEquals(RepTune.defaults["wallBalls"], RepCounter.tuning("wallBalls", s))
        assertEquals(0.45, RepCounter.tuning("wallBalls", s)!!.threshold, 0.0)
        val mine = RepTune(0.33, 0.15, 1.0, 0.7)
        val s2 = s.copy(repCal = mapOf("wallBalls" to mine))
        assertEquals(mine, RepCounter.tuning("wallBalls", s2))
        assertEquals(RepTune.defaults["row"], RepCounter.tuning("row", s2))
        assertNull(RepCounter.tuning("sledPush", s2))
        assertTrue(RepCounter.counts("skiErg"))
        assertFalse(RepCounter.counts("sledPush"))
    }

    @Test fun watchGoalSplit() {
        // 68-①: 워치에서 고른 목표 → 16구간 (폰과 같은 balanced), 합 = 목표 − Roxzone 8번
        val s = Settings()
        for (min in listOf(45, 60, 75, 90, 105, 120, 180)) {
            val t = WatchGoal.split(min * 60, s, null)
            assertEquals(16, t.size)
            assertEquals(min * 60 - 8 * s.roxTarget, t.sum())
            assertTrue(t.all { it >= 30 && it % 5 == 0 })
        }
        assertEquals(WatchGoal.split(5400, s, null), com.nkssi.splits8.shared.GoalSplit.split(5400, "balanced", s.goals, null, s.division, s.roxTarget))
        // 고르기 화면 처음 자리 · 확인 화면 숫자 (86번)
        assertEquals(90, WatchGoal.initialMinutes(5400, emptyList(), 30))
        assertEquals(45, WatchGoal.initialMinutes(null, listOf(100), 30))
        assertEquals("1:30:00", WatchGoal.shown(5400, simSeq(), 30))
        val noRox = SeqBuilder.full(div, false, Defaults.goals)
        assertEquals(com.nkssi.splits8.shared.Fm.t(Defaults.goals.sum() + 240), WatchGoal.shown(null, noRox, 30))
    }

    @Test fun doublesLineRules() {
        // 75번: 더블 디비전 · 스테이션 · 계획 있을 때만
        com.nkssi.splits8.shared.L10n.lang = "en"
        val plan = com.nkssi.splits8.shared.DoublesPlan(partnerName = "Jihoonie")
        val dbl = Division.of("dblM")
        val ski = SeqBuilder.full(dbl, true, Defaults.goals).first { it.icon == "skiErg" }
        assertEquals("Me 250 → Jihoon 250 · 4 turns", doublesLine(ski, plan, "dblM"))
        assertNull(doublesLine(ski, plan, "openM"))
        assertNull(doublesLine(ski, null, "dblM"))
        val run = SeqBuilder.full(dbl, true, Defaults.goals).first { it.kind == SegKind.Run }
        assertNull(doublesLine(run, plan, "dblM"))
    }
}
