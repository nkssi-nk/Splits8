package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** 19번: 음성 안내 — 어떤 조각을 어떤 순서로 말하는지 */
class VoiceTest {
    @Test fun durationClips() {
        assertEquals(listOf("min_5", "sec_12"), VoiceClips.duration(312))
        assertEquals(listOf("min_5"), VoiceClips.duration(300))
        assertEquals(listOf("sec_42"), VoiceClips.duration(42))
        assertEquals(listOf("min_59", "sec_59"), VoiceClips.duration(3599))
        // 1시간 넘으면 시간 + 분 (초는 뺌)
        assertEquals(listOf("hour_1"), VoiceClips.duration(3600))
        assertEquals(listOf("hour_1", "min_5"), VoiceClips.duration(3600 + 312))
        assertEquals(listOf("hour_3", "min_59"), VoiceClips.duration(4 * 3600 + 59 * 60))
        assertTrue(VoiceClips.duration(0).isEmpty())
    }

    @Test fun paceClips() {
        assertEquals(listOf("pre_pace", "min_5", "sec_12"), VoiceClips.pace(312))
        assertEquals(listOf("pre_avg", "min_6"), VoiceClips.pace(360, "pre_avg"))
        assertTrue(VoiceClips.pace(0).isEmpty())
        assertTrue(VoiceClips.pace(3600).isEmpty())
    }

    @Test fun heartRateClips() {
        assertEquals("hr_155", VoiceClips.heartRate(154))
        assertEquals("hr_150", VoiceClips.heartRate(152))
        assertEquals("hr_155", VoiceClips.heartRate(153))
        assertEquals("hr_60", VoiceClips.heartRate(48))
        assertEquals("hr_200", VoiceClips.heartRate(214))
        assertNull(VoiceClips.heartRate(0))
    }

    @Test fun distanceClips() {
        assertEquals("km_1", VoiceClips.distance(1000.0))
        assertEquals("km_1", VoiceClips.distance(1020.0))
        assertEquals("m_500", VoiceClips.distance(500.0))
        assertEquals("km_2_5", VoiceClips.distance(2500.0))
        assertEquals("km_10", VoiceClips.distance(10000.0))
        assertEquals("km_15", VoiceClips.distance(15000.0))
        assertEquals("km_21", VoiceClips.distance(21000.0))
        assertEquals("half", VoiceClips.distance(21097.0))
        assertEquals("full", VoiceClips.distance(42195.0))
        assertEquals("m_800", VoiceClips.distance(790.0))
        assertNull(VoiceClips.distance(30000.0))
        assertNull(VoiceClips.distance(10.0))
    }

    @Test fun stationAndRunNames() {
        assertEquals("st_ski", VoiceClips.station("skiErg"))
        assertEquals("st_rox", VoiceClips.station("roxzone"))
        assertEquals("st_wb", VoiceClips.station("wallBalls"))
        assertNull(VoiceClips.station("pushUp"))
        assertEquals("run_8", VoiceClips.runNo(8))
        assertNull(VoiceClips.runNo(9))
        assertEquals(25, VoiceClips.cheers.size)
        assertEquals("cheer_01", VoiceClips.cheers.first())
    }

    private val sim = SeqBuilder.full(Division.of("openM"), true, SeqBuilder.defaultTargets16)
    private val simNoRox = SeqBuilder.full(Division.of("openM"), false, SeqBuilder.defaultTargets16)

    @Test fun segmentIntros() {
        // 시작: 첫 번째 러닝
        assertEquals(listOf("run_1"), VoiceCoach.segIntro(sim, 0))
        // 록스존 다음은 스키에르그
        assertEquals(listOf("st_rox", "pre_next", "st_ski"), VoiceCoach.segIntro(sim, 1))
        assertEquals(listOf("st_ski"), VoiceCoach.segIntro(sim, 2))
        assertEquals(listOf("st_rox", "pre_next", "run_2"), VoiceCoach.segIntro(sim, 3))
        // 마지막 러닝 · 마지막 월볼
        val lastRun = sim.indexOfLast { it.kind == SegKind.Run }
        assertEquals(listOf("sim_lastrun"), VoiceCoach.segIntro(sim, lastRun))
        assertEquals(listOf("sim_wb"), VoiceCoach.segIntro(sim, sim.size - 1))
        assertEquals(listOf("sim_wb"), VoiceCoach.segIntro(simNoRox, simNoRox.size - 1))
        // 트레이닝 마지막이 월볼이 아니면 종목 + 라스트
        val tr = listOf(Seg("run", "Run", "1KM", SegKind.Run, 270), Seg("skiErg", "SkiErg", "1000M", SegKind.St, 255))
        assertEquals(listOf("st_ski", "sim_last"), VoiceCoach.segIntro(tr, 1))
    }

    @Test fun halfway() {
        // 16구간 중 8개 끝 → 록스존이 있으면 그 록스존에서, 없으면 5번째 러닝에서 한 번
        val withRox = sim.indices.filter { VoiceCoach.isHalfway(sim, it) }
        assertEquals(1, withRox.size)
        assertEquals(SegKind.Rox, sim[withRox[0]].kind)
        val noRox = simNoRox.indices.filter { VoiceCoach.isHalfway(simNoRox, it) }
        assertEquals(listOf(8), noRox)
    }

    private fun obs(seq: List<Seg>, idx: Int, segEl: Int = 0, total: Int = 0, running: Boolean = true, finished: Boolean = false,
                    active: Boolean = true, kind: String? = null, dist: Double? = null, hr: Int? = null, mode: Mode = Mode.Training) =
        VoiceCoach.Obs(active, finished, running, mode, kind, seq, idx, segEl, total, dist, hr)

    @Test fun offSaysNothing() {
        val c = VoiceCoach(VoicePrefs(on = false))
        assertNull(c.update(obs(sim, 0), 0))
        assertFalse(VoicePrefs.of(Settings().withVoice(true), korean = false).on)
        assertTrue(VoicePrefs.of(Settings().withVoice(true), korean = true).on)
    }

    @Test fun simFlow() {
        val c = VoiceCoach(VoicePrefs(on = true), Random(1))
        assertEquals(listOf("go_start", "run_1"), c.update(obs(sim, 0), 0)!!.clips)
        assertNull(c.update(obs(sim, 0, segEl = 1, total = 1), 1000))
        // 일시정지 · 다시 시작
        assertEquals(listOf("go_pause"), c.update(obs(sim, 0, 5, 5, running = false), 5000)!!.clips)
        assertNull(c.update(obs(sim, 0, 5, 5, running = false), 6000))
        assertEquals(listOf("go_resume"), c.update(obs(sim, 0, 5, 5), 9000)!!.clips)
        // 구간 바뀜
        val l = c.update(obs(sim, 1, 0, 270), 270_000)!!
        assertEquals(listOf("st_rox", "pre_next", "st_ski"), l.clips)
        assertEquals(VoiceCoach.Pri.Event, l.pri)
        assertEquals(listOf("st_ski"), c.update(obs(sim, 2, 0, 300), 300_000)!!.clips)
        // 스키(목표 255초) 절반쯤 응원 한 번
        assertNull(c.update(obs(sim, 2, 100, 400), 400_000))
        val ch = c.update(obs(sim, 2, 130, 430), 430_000)!!
        assertEquals(VoiceCoach.Pri.Cheer, ch.pri)
        assertTrue(ch.clips.single() in VoiceClips.cheers)
        assertNull(c.update(obs(sim, 2, 200, 500), 500_000))
        // 되돌리기(뒤로)는 말 안 함
        assertNull(c.update(obs(sim, 1, 30, 330), 501_000))
        // 끝
        assertEquals(listOf("go_end"), c.update(obs(sim, 2, 0, 600, finished = true), 600_000)!!.clips)
        assertNull(c.update(obs(sim, 2, 0, 600, finished = true), 601_000))
    }

    @Test fun cheerWaitsAfterLine() {
        val c = VoiceCoach(VoicePrefs(on = true), Random(2))
        c.update(obs(sim, 0), 0)
        c.update(obs(sim, 2, 0, 300), 300_000)
        // 구간 안내 바로 뒤(15초 안)는 응원 안 함
        assertNull(c.update(obs(sim, 2, 130, 430), 305_000))
        assertNotEquals(null, c.update(obs(sim, 2, 140, 440), 330_000))
    }

    @Test fun cheersDontRepeat() {
        val tr = List(10) { Seg("skiErg", "SkiErg", "1000M", SegKind.St, 200) }
        val c = VoiceCoach(VoicePrefs(on = true), Random(3))
        c.update(obs(tr, 0, mode = Mode.Training), 0)
        var t = 0L
        var prev: String? = null
        for (i in 1 until tr.size - 1) {
            t += 200_000
            c.update(obs(tr, i, 0, 0, mode = Mode.Training), t)
            val ch = c.update(obs(tr, i, 110, 0, mode = Mode.Training), t + 110_000)!!.clips.single()
            assertNotEquals(prev, ch)
            prev = ch
        }
    }

    @Test fun discardIsSilent() {
        val c = VoiceCoach(VoicePrefs(on = true))
        c.update(obs(sim, 0), 0)
        assertNull(c.update(obs(sim, 0, 9, 9, active = false, finished = true), 9000))
        assertNull(c.update(obs(sim, 0, 9, 9, finished = true), 9500))
    }

    @Test fun resumedWorkoutSkipsStart() {
        val c = VoiceCoach(VoicePrefs(on = true))
        assertNull(c.update(obs(sim, 4, 30, 900), 0))
        assertEquals(listOf("st_rox", "pre_next", "st_push"), c.update(obs(sim, 5, 0, 930), 30_000)!!.clips)
    }

    @Test fun runningAlerts() {
        val run = List(5) { SeqBuilder.runKm(it + 1) }
        val c = VoiceCoach(VoicePrefs(on = true, everyM = 1000), Random(4))
        assertEquals(listOf("go_start"), c.update(obs(run, 0, kind = "run", dist = 0.0, mode = Mode.Training), 0)!!.clips)
        assertNull(c.update(obs(run, 0, 200, 200, kind = "run", dist = 900.0, hr = 150, mode = Mode.Training), 200_000))
        // 1 km: 거리 · 지금까지 5분 12초 · 평균 페이스 5분 12초 · 심박 155 (구간 바뀜은 따로 말하지 않음)
        val l = c.update(obs(run, 1, 0, 312, kind = "run", dist = 1000.0, hr = 154, mode = Mode.Training), 312_000)!!
        assertEquals(listOf("km_1", "pre_time", "min_5", "sec_12", "pre_avg", "min_5", "sec_12", "hr_155"), l.clips)
        assertNull(c.update(obs(run, 1, 10, 322, kind = "run", dist = 1040.0, hr = 154, mode = Mode.Training), 322_000))
        // 끝: 운동 끝 + 거리 + 시간
        assertEquals(listOf("go_end", "km_2", "min_10", "sec_30"),
            c.update(obs(run, 1, 0, 630, finished = true, kind = "run", dist = 2000.0, mode = Mode.Training), 630_000)!!.clips)
    }

    @Test fun runningAlertToggles() {
        val run = List(5) { SeqBuilder.runKm(it + 1) }
        val c = VoiceCoach(VoicePrefs(on = true, everyM = 500, time = false, hr = false), Random(5))
        c.update(obs(run, 0, kind = "run", dist = 0.0, mode = Mode.Training), 0)
        assertEquals(listOf("m_500", "pre_avg", "min_5"), c.update(obs(run, 0, 150, 150, kind = "run", dist = 500.0, hr = 150, mode = Mode.Training), 150_000)!!.clips)
        // 간격 끔
        val off = VoiceCoach(VoicePrefs(on = true, everyM = 0))
        off.update(obs(run, 0, kind = "run", dist = 0.0, mode = Mode.Training), 0)
        assertNull(off.update(obs(run, 1, 0, 300, kind = "run", dist = 1000.0, mode = Mode.Training), 300_000))
    }

    /** 예전 설정 파일도 읽히고, 기본값이면 파일에 안 씀 */
    @Test fun voiceSettingsCompatible() {
        val old = SplitsJson.decodeFromString(Settings.serializer(), """{"division":"openW"}""")
        assertFalse(old.voice)
        assertEquals(1000, old.voiceEvery)
        assertTrue(old.voiceDist && old.voiceTime && old.voicePace && old.voiceHr)
        val plain = SplitsJson.encodeToString(Settings.serializer(), Settings().withVoice(false).withVoiceEvery(1000).withVoiceHr(true))
        assertFalse(plain.contains("voice"))
        val s = Settings().withVoice(true).withVoiceEvery(500).withVoicePace(false)
        val back = SplitsJson.decodeFromString(Settings.serializer(), SplitsJson.encodeToString(Settings.serializer(), s))
        assertTrue(back.voice)
        assertEquals(500, back.voiceEvery)
        assertFalse(back.voicePace)
        assertTrue(back.voiceDist)
        assertEquals(0, Settings().withVoiceEvery(0).voiceEvery)
    }

    // MARK: 1.2.2 · 레이스 · 풀 시뮬 코치 (코치 음성 v8)

    private fun race(idx: Int, segEl: Int = 0, total: Int = 0, splits: List<Int> = emptyList(), segDist: Double? = null,
                     finished: Boolean = false, running: Boolean = true, seq: List<Seg> = sim) =
        VoiceCoach.Obs(true, finished, running, Mode.Sim, null, seq, idx, segEl, total, null, null, null, null, splits, segDist)

    @Test fun raceIsOnlyHyroxOrder() {
        assertTrue(RaceVoice.isRace(sim))
        assertTrue(RaceVoice.isRace(simNoRox))
        assertFalse(RaceVoice.isRace(sim.take(10)))
        val tr = listOf(Seg("run", "Run", "1KM", SegKind.Run, 270), Seg("skiErg", "SkiErg", "1K", SegKind.St, 255))
        assertFalse(RaceVoice.isRace(tr))
    }

    @Test fun raceTransitions() {
        // sim: 러닝1 · 록스존 · 스키 · 록스존 · 러닝2 …
        assertEquals(listOf("rr_1"), RaceVoice.transition(sim, 0, "low"))
        assertEquals(listOf("ri_1"), RaceVoice.transition(sim, 1, "low"))
        assertEquals(listOf("rs_1"), RaceVoice.transition(sim, 2, "low"))
        assertEquals(listOf("rs_1", "tip_1"), RaceVoice.transition(sim, 2, "mid"))
        assertEquals(listOf("ro_1"), RaceVoice.transition(sim, 3, "low"))
        assertEquals(listOf("rr_2"), RaceVoice.transition(sim, 4, "low"))
        assertEquals(listOf("ri_8"), RaceVoice.transition(sim, sim.size - 2, "low"))
        assertEquals(listOf("rs_8"), RaceVoice.transition(sim, sim.size - 1, "low"))
        // 록스존 없이도 통문장
        assertEquals(listOf("rs_1"), RaceVoice.transition(simNoRox, 1, "low"))
        assertEquals(listOf("rr_2"), RaceVoice.transition(simNoRox, 2, "low"))
        // 쓰는 조각이 모두 clips.json 에 있는 이름 (rr 1~8 · ri 1~8 · rs 1~8 · tip 1~8 · ro 1~7)
        val all = sim.indices.flatMap { RaceVoice.transition(sim, it, "high") }.toSet()
        assertEquals((1..8).map { "rr_$it" }.toSet(), all.filter { it.startsWith("rr_") }.toSet())
        assertEquals((1..7).map { "ro_$it" }.toSet(), all.filter { it.startsWith("ro_") }.toSet())
        assertEquals(8, all.count { it.startsWith("tip_") })
    }

    @Test fun raceGoalCompare() {
        assertEquals(listOf("goal_on"), RaceVoice.compare(2))
        assertEquals(listOf("goal_pre", "sec_12", "goal_fast"), RaceVoice.compare(-12))
        assertEquals(listOf("goal_pre", "min_1", "sec_5", "goal_slow"), RaceVoice.compare(65))
        assertEquals(listOf("goal_behind"), RaceVoice.compare(4000))
        // 스키(목표 255) 끝 → 록스존(3)에 들어올 때 누적 비교. 러닝1 270 · 록스존 30 · 스키 255 = 555, 내 기록 540 → 15초 빠름
        val sp = listOf(260, 25, 255)
        assertEquals(listOf("goal_pre", "sec_15", "goal_fast"), RaceVoice.goalLine(sim, 3, sp, "low"))
        // 적게: 러닝 끝(록스존 IN)에는 안 함, 보통이면 함
        assertTrue(RaceVoice.goalLine(sim, 1, listOf(260), "low").isEmpty())
        assertEquals(listOf("goal_pre", "sec_10", "goal_fast"), RaceVoice.goalLine(sim, 1, listOf(260), "mid"))
        // 록스존이 끝난 자리 · 건너뛴 구간(0초)은 안 함
        assertTrue(RaceVoice.goalLine(sim, 2, listOf(260, 25), "mid").isEmpty())
        assertTrue(RaceVoice.goalLine(sim, 3, listOf(260, 25, 0), "mid").isEmpty())
    }

    @Test fun raceFlowLow() {
        val c = VoiceCoach(VoicePrefs(on = true), Random(7))
        // 출발: 통문장 하나 (go_start 없음)
        assertEquals(listOf("rr_1"), c.update(race(0), 0)!!.clips)
        // 러닝1(목표 270) 85 % = 229초 → 거의 끝
        val near = c.update(race(0, 230, 230), 230_000)!!
        assertTrue(near.clips.single() in listOf("near_run", "near_run_rox"))
        // 록스존 IN
        assertEquals(listOf("ri_1"), c.update(race(1, 0, 260, listOf(260)), 260_000)!!.clips)
        // 스키 시작 (적게 → 요령 없음)
        assertEquals(listOf("rs_1"), c.update(race(2, 0, 290, listOf(260, 30)), 290_000)!!.clips)
        // 스키 끝 → 록스존 OUT + 목표 비교 (270+30+255 = 555, 내 260+30+250 = 540)
        assertEquals(listOf("ro_1", "goal_pre", "sec_15", "goal_fast"), c.update(race(3, 0, 540, listOf(260, 30, 250)), 540_000)!!.clips)
        // 일시정지 · 다시
        assertEquals(listOf("go_pause"), c.update(race(3, 5, 545, listOf(260, 30, 250), running = false), 545_000)!!.clips)
        assertEquals(listOf("go_resume"), c.update(race(3, 5, 545, listOf(260, 30, 250)), 550_000)!!.clips)
        // 끝까지 → 완주
        val all = List(sim.size) { 100 }
        assertEquals(listOf("rf_1"), c.update(race(sim.size - 1, 0, 3000, all, finished = true), 3_000_000)!!.clips)
    }

    @Test fun raceEndEarlySaysGoEnd() {
        val c = VoiceCoach(VoicePrefs(on = true))
        c.update(race(0), 0)
        assertEquals(listOf("go_end"), c.update(race(2, 10, 300, listOf(260, 30), finished = true), 300_000)!!.clips)
    }

    @Test fun raceCheersPerLevel() {
        for ((level, max) in listOf("low" to 1, "mid" to 2, "high" to 3)) {
            val c = VoiceCoach(VoicePrefs(on = true, cheer = level), Random(11))
            c.update(race(0), 0)
            c.update(race(1, 0, 270, listOf(270)), 270_000)
            c.update(race(2, 0, 300, listOf(270, 30)), 300_000)      // 스키 시작 (목표 255)
            val said = ArrayList<VoiceCoach.Line>()
            for (t in 1..255) c.update(race(2, t, 300 + t, listOf(270, 30)), 300_000L + t * 1000L)?.let { said.add(it) }
            val cheers = said.filter { it.pri == VoiceCoach.Pri.Cheer }
            assertTrue("$level ${cheers.size}", cheers.size in 1..max)
            // 스키 응원은 일반 응원 + 스키 요령만, 안 겹침
            val ids = cheers.map { it.clips.single() }
            assertTrue(ids.all { it.startsWith("cheer_") || it.startsWith("cs_ski_") })
            assertEquals(ids.size, ids.toSet().size)
        }
    }

    @Test fun racePhaseLineMidOnly() {
        // 러닝2 첫 응원 자리는 보통 · 많이면 ph_q1, 적게면 일반 응원
        val i2 = sim.indexOfFirst { it.kind == SegKind.Run && RaceVoice.runNo(sim, sim.indexOf(it)) == 2 }
        assertEquals(listOf("ph_q1"), RaceVoice.cheerOptions(sim, i2, 0, "mid"))
        assertFalse(RaceVoice.cheerOptions(sim, i2, 0, "low").contains("ph_q1"))
        assertTrue(RaceVoice.cheerOptions(sim, i2, 1, "mid").containsAll(listOf("cr_01", "cheer_25")))
        assertEquals(listOf("ph_wb"), RaceVoice.cheerOptions(sim, sim.size - 1, 0, "high"))
    }

    @Test fun racePaceWarnOnce() {
        val c = VoiceCoach(VoicePrefs(on = true), Random(5))
        c.update(race(0), 0)
        // 60 % (162초)에 700 m → 있어야 할 600 m 보다 10 % 넘게 앞섬
        assertEquals(VoiceCoach.Pri.Event, c.update(race(0, 162, 162, segDist = 700.0), 162_000)!!.pri)
        // 거리를 모르면 경고 없음
        val d = VoiceCoach(VoicePrefs(on = true), Random(5))
        d.update(race(0), 0)
        val l = d.update(race(0, 162, 162), 162_000)
        assertTrue(l == null || l.pri == VoiceCoach.Pri.Cheer)
        assertFalse(RaceVoice.tooFast(sim[0], 162, 640.0))
        assertTrue(RaceVoice.tooFast(sim[0], 162, 700.0))
    }

    @Test fun trainingStaysOldWay() {
        val c = VoiceCoach(VoicePrefs(on = true), Random(1))
        assertEquals(listOf("go_start", "run_1"), c.update(obs(sim, 0, mode = Mode.Training), 0)!!.clips)
    }
}
