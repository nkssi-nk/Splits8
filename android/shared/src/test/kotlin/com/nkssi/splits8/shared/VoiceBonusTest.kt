package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 18번 + 19번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동의 음성 안내 */
class VoiceBonusTest {
    private val on = VoicePrefs(on = true)

    private fun obs(kind: String, seq: List<Seg>, idx: Int, segEl: Int, total: Int, running: Boolean = true,
                    finished: Boolean = false, cap: Int? = null, dist: Double? = null, segMs: Long? = null) =
        VoiceCoach.Obs(true, finished, running, Mode.Training, kind, seq, idx, segEl, total, dist, null, cap, segMs)

    /** 한 번 부를 때마다 나온 조각 (없으면 null) */
    private fun VoiceCoach.say(o: VoiceCoach.Obs, now: Long = o.total * 1000L): List<String>? = update(o, now)?.clips

    @Test fun countdownThenNoStartLine() {
        val seq = Bonus.tabataSeq(20, 10, 8)
        val c = VoiceCoach(on)
        assertEquals(listOf("cd_3"), c.countdown(3, Kinds.TABATA)?.clips)
        assertEquals(listOf("cd_2"), c.countdown(2, Kinds.TABATA)?.clips)
        assertEquals(listOf("cd_1"), c.countdown(1, Kinds.TABATA)?.clips)
        assertEquals(listOf("cd_go"), c.countdown(0, Kinds.TABATA)?.clips)
        // "시작" 을 말했으니 운동 시작 때 "운동 시작" 은 안 함 (첫 운동 안내만)
        assertEquals(listOf("iv_work"), c.say(obs(Kinds.TABATA, seq, 0, 0, 0)))
        // 하이록스 · 러닝은 세기 음성 없음
        assertNull(VoiceCoach(on).countdown(3, null))
        assertNull(VoiceCoach(on).countdown(3, Kinds.RUN))
        assertNull(VoiceCoach(VoicePrefs(on = false)).countdown(3, Kinds.EMOM))
    }

    @Test fun tabataWorkRestLast() {
        val seq = Bonus.tabataSeq(20, 10, 3)        // W R W R W
        val c = VoiceCoach(on)
        c.countdown(0, Kinds.TABATA)
        c.say(obs(Kinds.TABATA, seq, 0, 0, 0))
        assertEquals(listOf("iv_rest"), c.say(obs(Kinds.TABATA, seq, 1, 0, 20)))
        assertEquals(listOf("iv_work"), c.say(obs(Kinds.TABATA, seq, 2, 0, 30)))
        assertEquals(listOf("iv_rest"), c.say(obs(Kinds.TABATA, seq, 3, 0, 50)))
        assertEquals(listOf("iv_last_set"), c.say(obs(Kinds.TABATA, seq, 4, 0, 60)))
        assertEquals(listOf("go_end"), c.say(obs(Kinds.TABATA, seq, 4, 20, 80, finished = true)))
    }

    @Test fun tenSecondsOnlyForLongPhases() {
        val short = Bonus.tabataSeq(20, 10, 2)
        val c = VoiceCoach(on)
        c.say(obs(Kinds.TABATA, short, 0, 0, 0))
        assertNull(c.say(obs(Kinds.TABATA, short, 0, 10, 10, segMs = 10_000)))   // 20초 운동 → "10초" 없음
        val long = Bonus.tabataSeq(40, 20, 2)
        val d = VoiceCoach(on)
        d.say(obs(Kinds.TABATA, long, 0, 0, 0))
        assertNull(d.say(obs(Kinds.TABATA, long, 0, 29, 29, segMs = 29_900)))
        assertEquals(listOf("t_10s"), d.say(obs(Kinds.TABATA, long, 0, 30, 30, segMs = 30_000)))
        assertNull(d.say(obs(Kinds.TABATA, long, 0, 31, 31, segMs = 31_000)))      // 한 번만
    }

    @Test fun emomEveryInterval() {
        val seq = Bonus.seq(Bonus.emom(60, 3))
        val c = VoiceCoach(on)
        c.countdown(0, Kinds.EMOM)
        assertNull(c.say(obs(Kinds.EMOM, seq, 0, 0, 0)))
        assertNull(c.say(obs(Kinds.EMOM, seq, 0, 50, 50)))                           // EMOM 은 "10초" 없음
        assertEquals(listOf("emom_next"), c.say(obs(Kinds.EMOM, seq, 1, 0, 60)))
        assertEquals(listOf("emom_next"), c.say(obs(Kinds.EMOM, seq, 2, 0, 120)))
    }

    @Test fun amrapTimeLeftAndEnd() {
        val seq = listOf(Bonus.amrapRound(1))
        val c = VoiceCoach(on)
        c.countdown(0, Kinds.AMRAP)
        assertNull(c.say(obs(Kinds.AMRAP, seq, 0, 0, 0, cap = 600)))
        assertNull(c.say(obs(Kinds.AMRAP, seq, 0, 500, 500, cap = 600)))
        assertEquals(listOf("t_1m"), c.say(obs(Kinds.AMRAP, seq, 0, 540, 540, cap = 600)))
        assertNull(c.say(obs(Kinds.AMRAP, seq, 0, 541, 541, cap = 600)))
        assertEquals(listOf("t_30s"), c.say(obs(Kinds.AMRAP, seq, 0, 570, 570, cap = 600)))
        assertEquals(listOf("t_10s"), c.say(obs(Kinds.AMRAP, seq, 0, 590, 590, cap = 600)))
        assertEquals(listOf("amrap_end"), c.say(obs(Kinds.AMRAP, seq, 0, 600, 600, cap = 600, finished = true)))
        // 중간에 End → 그냥 "운동 끝"
        val d = VoiceCoach(on)
        d.say(obs(Kinds.AMRAP, seq, 0, 0, 0, cap = 600))
        assertEquals(listOf("go_end"), d.say(obs(Kinds.AMRAP, seq, 0, 300, 300, cap = 600, finished = true)))
    }

    @Test fun amrapLateJoinSkipsOldMarks() {
        // 앱을 늦게 다시 열어 15초 남았을 때 처음 봄 → 1분 · 30초는 안 함, 10초는 함
        val seq = listOf(Bonus.amrapRound(1))
        val c = VoiceCoach(on)
        c.say(obs(Kinds.AMRAP, seq, 0, 0, 0, cap = 600))
        assertNull(c.say(obs(Kinds.AMRAP, seq, 0, 585, 585, cap = 600)))
        assertEquals(listOf("t_10s"), c.say(obs(Kinds.AMRAP, seq, 0, 590, 590, cap = 600)))
    }

    @Test fun ivrunSteps() {
        val p = Bonus.ivrun(listOf(IvStep(IvStep.FAST, m = 400), IvStep(IvStep.WALK, s = 60)), 2, indoor = false,
            warm = IvStep(IvStep.EASY, s = 300))
        val seq = Bonus.seq(p)                      // warm F W F W
        val c = VoiceCoach(on.copy(everyM = 0))
        assertEquals(listOf("go_start", "iv_easy"), c.say(obs(Kinds.IVRUN, seq, 0, 0, 0)))
        assertEquals(listOf("iv_fast"), c.say(obs(Kinds.IVRUN, seq, 1, 0, 300)))
        assertEquals(listOf("iv_rest"), c.say(obs(Kinds.IVRUN, seq, 2, 0, 400)))
        // 마지막 반복의 첫 단계 → "마지막 세트" + "빠르게"
        assertEquals(listOf("iv_last_set", "iv_fast"), c.say(obs(Kinds.IVRUN, seq, 3, 0, 460)))
        // 끝: 러닝처럼 거리 · 시간
        assertEquals(listOf("go_end", "km_2", "min_10"), c.say(obs(Kinds.IVRUN, seq, 4, 40, 600, finished = true, dist = 2000.0)))
    }

    @Test fun ivrunDistanceAlertsLikeRun() {
        val seq = Bonus.seq(Bonus.ivrun(Bonus.ivPresets[0], indoor = false))
        val c = VoiceCoach(on.copy(everyM = 1000, time = false, pace = false, hr = false))
        c.say(obs(Kinds.IVRUN, seq, 0, 0, 0, dist = 0.0))
        assertNull(c.say(obs(Kinds.IVRUN, seq, 0, 60, 60, dist = 300.0)))
        assertEquals(listOf("km_1"), c.say(obs(Kinds.IVRUN, seq, 0, 300, 300, dist = 1005.0)))
    }

    @Test fun liftRestEndSaysNextSet() {
        val seq = Bonus.liftSeq(listOf(Lift("Squat", 2, 5, 60.0)), 90)    // set rest set
        val c = VoiceCoach(on)
        assertEquals(listOf("go_start"), c.say(obs(Kinds.LIFT, seq, 0, 0, 0)))
        assertNull(c.say(obs(Kinds.LIFT, seq, 1, 0, 40)))                  // 세트 끝 → 휴식 (내가 누른 것)
        assertEquals(listOf("t_10s"), c.say(obs(Kinds.LIFT, seq, 1, 80, 120, segMs = 80_000)))
        assertEquals(listOf("tabata_set"), c.say(obs(Kinds.LIFT, seq, 2, 0, 130)))
    }
}
