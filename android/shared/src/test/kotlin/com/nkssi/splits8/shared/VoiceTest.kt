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
        assertEquals(15, VoiceClips.cheers.size)
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
                    active: Boolean = true, kind: String? = null, dist: Double? = null, hr: Int? = null, mode: Mode = Mode.Sim) =
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
}
