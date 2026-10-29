package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 — 구간 순서 · 시간 규칙 · 저장 모양 · 음성 */
class BonusTest {
    private fun rec(kind: String?, segs: List<SegResult>, title: String = "T", date: Instant = Instant.parse("2026-10-20T08:00:00Z"),
                    mode: Mode = Mode.Training) =
        Record(mode = mode, title = title, date = date, total = segs.sumOf { it.time }, segs = segs, hr = emptyList(),
            kcal = 0, avgHR = 0, maxHR = 0, division = "openM", vsWord = "VS BEST", kind = kind)

    // MARK: 구간 순서

    @Test fun tabataSeqDefault() {
        val p = Bonus.tabata()
        assertEquals("Tabata", p.name)
        assertEquals(Kinds.TABATA, p.kind)
        assertTrue(p.isOpen)
        val s = SeqBuilder.training(p, Division.all[0], emptyMap())
        // 운동 8 + 휴식 7 (마지막 운동 뒤 휴식 없음)
        assertEquals(15, s.size)
        assertEquals(8, s.count { it.icon == "hiit" })
        assertEquals(7, s.count { it.icon == "rest" && it.kind == SegKind.Rox })
        assertEquals(listOf(20, 10, 20), s.take(3).map { it.target })
        assertEquals(8 * 20 + 7 * 10, Bonus.plannedTime(p))
        assertEquals(8, s.last().rep)
    }

    @Test fun tabataCustomName() {
        assertEquals("Interval timer 40/20", Bonus.tabata(40, 20, 10).name)
        assertEquals(10, Bonus.tabata(40, 20, 10).rounds)
        // 휴식 0초면 휴식 구간 없음
        assertEquals(5, Bonus.tabataSeq(30, 0, 5).size)
    }

    @Test fun emomSeqAndNames() {
        val p = Bonus.emom(every = 120, rounds = 6, tasks = listOf(" Burpees 10 ", "", "Wall balls 15"))
        assertEquals("E2MOM", p.name)
        assertEquals(listOf("Burpees 10", "Wall balls 15"), p.tasks)
        val s = Bonus.seq(p)
        assertEquals(6, s.size)
        assertTrue(s.all { it.target == 120 && it.kind == SegKind.St })
        assertEquals("EMOM", Bonus.emomName(60))
        assertEquals("EMOM 0:30", Bonus.emomName(30))
        assertEquals(720, Bonus.plannedTime(p))
        // 간격은 30초 ~ 5분
        assertEquals(300, Bonus.emom(every = 900).every)
        assertEquals(30, Bonus.emom(every = 5).every)
    }

    @Test fun amrapSeq() {
        val p = Bonus.amrap(cap = 600, tasks = listOf("Push-ups 10"))
        assertEquals(listOf(Bonus.amrapRound(1)), Bonus.seq(p))
        assertTrue(Bonus.grows(Kinds.AMRAP))
        assertEquals(600, Bonus.plannedTime(p))
    }

    @Test fun ivrunSeqWithWarmCool() {
        val p = Bonus.ivrun(
            listOf(IvStep(IvStep.FAST, m = 500, pace = 240), IvStep(IvStep.EASY, m = 300)), rounds = 3, indoor = false,
            warm = IvStep(IvStep.EASY, s = 600), cool = IvStep(IvStep.WALK, s = 300),
        )
        val s = Bonus.seq(p)
        assertEquals(1 + 6 + 1, s.size)
        assertEquals("Warm-up", s.first().name)
        assertEquals("600S", s.first().detail)
        assertEquals(600, s.first().target)
        assertNull(s.first().rep)
        assertEquals("Fast", s[1].name)
        assertEquals("500M", s[1].detail)
        assertEquals(120, s[1].target)                     // 4:00/km × 0.5 km
        assertEquals(240, s[1].pace)
        assertEquals(500.0, runMeters(s[1].detail), 0.01)
        assertEquals(3, s[6].rep)
        assertEquals("Cool-down", s.last().name)
        // 시간 · 거리 단계 구분
        assertEquals(600, Bonus.timedLen(Kinds.IVRUN, s.first()))
        assertNull(Bonus.timedLen(Kinds.IVRUN, s[1]))
        assertEquals(500.0, Bonus.distLen(Kinds.IVRUN, s[1])!!, 0.01)
        assertNull(Bonus.distLen(Kinds.IVRUN, s.first()))
    }

    @Test fun ivrunRestIsTimeAndRox() {
        val p = Bonus.ivrun(Bonus.ivPresets[2], indoor = true)
        assertEquals("1 km × 5", p.name)
        val s = Bonus.seq(p)
        assertEquals(10, s.size)
        assertEquals("1KM", s[0].detail)
        val rest = s[1]
        assertEquals("rest", rest.icon)
        assertEquals(SegKind.Rox, rest.kind)
        assertEquals(120, Bonus.timedLen(Kinds.IVRUN, rest))
        // 거리로 쓴 휴식도 시간 단계로 봄
        assertTrue(IvStep(IvStep.REST, m = 200).isTime)
        assertEquals("1.5KM", Bonus.distLabel(1500))
        assertEquals("1.5 km", Bonus.distText(1500))
        assertEquals("400 m", Bonus.distText(400))
    }

    @Test fun liftSeq() {
        val p = Bonus.lift(listOf(Lift("Squat", 3, 5, 100.0), Lift("Push-up", 2, 20)), rest = 90)
        assertEquals("Strength", p.name)
        val s = Bonus.seq(p)
        // 세트 5개 + 사이 휴식 4개
        assertEquals(9, s.size)
        assertEquals(listOf("lift", "rest", "lift", "rest", "lift", "rest", "lift", "rest", "lift"), s.map { it.icon })
        assertEquals("SET 2/3", s[2].detail)
        assertEquals(5, s[0].reps)
        assertEquals(100.0, s[0].kg!!, 0.0)
        assertNull(Bonus.timedLen(Kinds.LIFT, s[0]))
        assertEquals(90, Bonus.timedLen(Kinds.LIFT, s[1]))
    }

    // MARK: 시간 규칙

    @Test fun timedCutExactBoundary() {
        val work = Seg("hiit", "Round 1", "WORK", SegKind.St, 20, rep = 1)
        assertNull(Bonus.timedCut(Kinds.TABATA, work, 19_999))
        assertEquals(TimedCut(20, 0), Bonus.timedCut(Kinds.TABATA, work, 20_000))
        // 늦게 확인해도 기록은 정확히 20초, 넘친 시간은 다음 구간으로
        assertEquals(TimedCut(20, 750), Bonus.timedCut(Kinds.TABATA, work, 20_750))
        // HIIT · 하이록스 구간은 시간으로 안 넘어감
        assertNull(Bonus.timedCut(Kinds.HIIT, work, 99_000))
        assertNull(Bonus.timedCut(null, work, 99_000))
        // AMRAP 라운드는 목표가 없어서 안 넘어감
        assertNull(Bonus.timedCut(Kinds.AMRAP, Bonus.amrapRound(1), 99_000))
    }

    @Test fun capCut() {
        assertNull(Bonus.capCut(600, 500, 99_000))
        assertEquals(TimedCut(100, 0), Bonus.capCut(600, 500, 100_000))
        assertEquals(TimedCut(100, 400), Bonus.capCut(600, 500, 100_400))
        assertNull(Bonus.capCut(null, 500, 900_000))
        assertEquals(40, Bonus.capLeft(600, 560))
        assertEquals(0, Bonus.capLeft(600, 700))
    }

    @Test fun warnThreeTwoOne() {
        val work = Seg("hiit", "Round 1", "WORK", SegKind.St, 20, rep = 1)
        assertNull(Bonus.warnSec(Kinds.TABATA, work, 16_900))
        assertEquals(3, Bonus.warnSec(Kinds.TABATA, work, 17_000))
        assertEquals(2, Bonus.warnSec(Kinds.TABATA, work, 18_000))
        assertEquals(1, Bonus.warnSec(Kinds.TABATA, work, 19_500))
        assertNull(Bonus.warnSec(Kinds.TABATA, work, 20_000))
        assertTrue(Bonus.tapMarksDone(Kinds.EMOM))
        assertFalse(Bonus.tapMarksDone(Kinds.TABATA))
    }

    // MARK: 기능성 운동

    @Test fun liftPrefillAndVolume() {
        val seq = Bonus.liftSeq(listOf(Lift("Squat", 3, 5, 100.0)), 90)
        val old = rec(Kinds.LIFT, listOf(
            SegResult("lift", "Squat", "SET 1/3", SegKind.St, 40, 0, reps = 5, kg = 90.0, rep = 1),
            SegResult("lift", "Squat", "SET 2/3", SegKind.St, 40, 0, reps = 4, kg = 95.0, rep = 2),
        ), date = Instant.parse("2026-10-01T08:00:00Z"))
        val last = Bonus.lastSets(listOf(old), "Squat")
        assertEquals(listOf(5 to 90.0, 4 to 95.0), last)
        // 첫 세트: 지난번 1세트
        assertEquals(5 to 90.0, Bonus.prefill(seq, 0, emptyMap(), last))
        // 둘째 세트: 이번에 바로 앞 세트 값
        assertEquals(6 to 92.5, Bonus.prefill(seq, 2, mapOf(0 to (6 to 92.5)), last))
        // 지난번에 없던 셋째 세트: 지난번 마지막 세트
        assertEquals(4 to 95.0, Bonus.prefill(seq, 4, emptyMap(), last))
        // 지난번 기록이 없으면 계획
        assertEquals(5 to 100.0, Bonus.prefill(seq, 0, emptyMap(), emptyList()))
        assertEquals(5 * 90.0 + 4 * 95.0, Bonus.volume(old), 0.001)
        val now = rec(Kinds.LIFT, old.segs, date = Instant.parse("2026-10-10T08:00:00Z"))
        assertEquals(Bonus.volume(old), Bonus.prevVolume(listOf(old, now), now)!!, 0.001)
        assertNull(Bonus.prevVolume(listOf(old), old))
        assertEquals(listOf("Squat"), Bonus.liftTable(old).map { it.first })
    }

    // MARK: 기록

    @Test fun fastPaceAndAmrapScore() {
        val r = rec(Kinds.IVRUN, listOf(
            SegResult("run", "Fast", "500M", SegKind.Run, 100, 0, dist = 500.0),
            SegResult("run", "Easy", "300M", SegKind.Run, 100, 0, dist = 300.0),
            SegResult("run", "Fast", "500M", SegKind.Run, 110, 0, dist = 500.0),
        ))
        assertEquals(210, Bonus.fastPace(r))
        val a = rec(Kinds.AMRAP, (1..8).map { SegResult("hiit", "Round $it", "AMRAP", SegKind.St, 100, 0) }).copy(rounds = 7, extra = 5)
        assertEquals("7 rounds + 5", Bonus.amrapScore(a))
        assertEquals("7 rounds", Bonus.amrapScore(a.copy(extra = null)))
    }

    /** 인터벌 러닝 시간 단계에 거리가 없어도 1 km 로 세지 않음 */
    @Test fun runLegsSkipTimeSteps() {
        val r = rec(Kinds.IVRUN, listOf(
            SegResult("run", "Fast", "60S", SegKind.Run, 60, 60),
            SegResult("run", "Fast", "400M", SegKind.Run, 90, 0, dist = 410.0),
        ))
        assertEquals(410.0, r.runDistance, 0.01)
    }

    /** 새 종류는 하이록스 구간 최고 · PB · 분석에 안 들어감 */
    @Test fun newKindsStayOutOfHyroxStats() {
        val lift = rec(Kinds.LIFT, listOf(SegResult("lift", "Squat", "SET 1/3", SegKind.St, 200, 0, reps = 5, kg = 60.0)))
        val iv = rec(Kinds.IVRUN, listOf(SegResult("run", "Fast", "1KM", SegKind.Run, 230, 0, dist = 1000.0)))
        val tab = rec(Kinds.TABATA, listOf(SegResult("hiit", "Round 1", "WORK", SegKind.St, 20, 20)))
        val book = RecordBook(listOf(lift, iv, tab), Settings())
        assertTrue(book.segBests.isEmpty())
        assertFalse(book.isPB(iv))
        assertFalse(book.isPB(tab))
        assertTrue(Insights.make(iv, book).isEmpty())
        assertTrue(SegKey.plausible("run", "1KM", 230))
        assertFalse(SegKey.plausible("lift", "SET 1/3", 200))
        assertFalse(SegKey.plausible("rest", "REST", 200))
    }

    // MARK: 저장 모양 (예전 파일 · 예전 앱)

    @Test fun programJsonCompatible() {
        // 예전 HIIT 카드 파일: 새 칸 없음 → 그대로 읽힘, 다시 쓸 때도 새 칸 안 생김
        val oldJson = """{"id":"hiit.ab","name":"HIIT","sets":1,"seq":[{"icon":"hiit"}],"kind":"hiit"}"""
        val old = SplitsJson.decodeFromString(Program.serializer(), oldJson)
        assertNull(old.work); assertNull(old.steps); assertNull(old.lifts)
        val again = SplitsJson.encodeToString(Program.serializer(), old)
        for (k in listOf("work", "rest", "rounds", "every", "cap", "tasks", "steps", "warm", "cool", "lifts")) assertFalse(k, again.contains("\"$k\""))
        // 새 카드는 주고받아도 그대로
        val all = listOf(
            Bonus.tabata(40, 20, 10), Bonus.emom(90, 10, listOf("Burpees")), Bonus.amrap(900, listOf("Row 250 m")),
            Bonus.ivrun(Bonus.ivPresets[1], indoor = false).copy(warm = IvStep(IvStep.EASY, s = 300)),
            Bonus.lift(listOf(Lift("Deadlift", 5, 5, 120.5))),
        )
        for (p in all) assertEquals(p, SplitsJson.decodeFromString(Program.serializer(), SplitsJson.encodeToString(Program.serializer(), p)))
    }

    @Test fun recordJsonCompatible() {
        val r = rec(Kinds.LIFT, listOf(SegResult("lift", "Squat", "SET 1/3", SegKind.St, 40, 0, reps = 5, kg = 80.0, rep = 1, work = null)))
            .copy(rounds = 7, extra = 3, cap = 900)
        val j = SplitsJson.encodeToString(Record.serializer(), r)
        assertEquals(r, SplitsJson.decodeFromString(Record.serializer(), j))
        val plain = SplitsJson.encodeToString(Record.serializer(), rec(null, listOf(SegResult("run", "Run", "1KM", SegKind.Run, 300, 270))))
        for (k in listOf("rounds", "extra", "cap", "kg", "work", "rep")) assertFalse(k, plain.contains("\"$k\""))
        // 운동 중 구간(Seg)도 새 칸이 없으면 안 씀 (폰 ↔ 워치 같이 보기 · 이어 받기 파일)
        val seg = SplitsJson.encodeToString(Seg.serializer(), Seg("run", "Run 1", "1KM", SegKind.Run, 270))
        assertEquals("""{"icon":"run","name":"Run 1","detail":"1KM","kind":"run","target":270}""", seg)
    }

    // MARK: 이름 · 글자

    @Test fun koreanNames() {
        assertEquals("라운드 3", Bonus.koName("Round 3"))
        assertEquals("인터벌 타이머 40/20", Bonus.koName("Interval timer 40/20"))
        assertNull(Bonus.koName("Rounds"))
        val was = L10n.lang
        try {
            L10n.lang = "ko"
            assertEquals("라운드 12", L10n.t("Round 12"))
            assertEquals("타바타", L10n.t("Tabata"))
            assertEquals("기능성 운동", L10n.t("Strength"))
            assertEquals("인터벌 러닝", L10n.t("Interval run"))
            assertEquals("하이록스 트레이닝", L10n.t("HYROX training"))
            assertEquals("20초", Bonus.dur(20))
            assertEquals("2분", Bonus.dur(120))
            assertEquals("1:30", Bonus.dur(90))
            for (k in Kinds.menu) {
                assertTrue(k, L10nKo.get(Kinds.title(k)) != null || Kinds.title(k) == "HIIT")
                assertTrue(k, L10nKo.get(Kinds.sub(k)) != null)
            }
            for (n in Bonus.liftNames) assertTrue(n, L10nKo.get(n) != null)
            for (t in IvStep.types) assertTrue(t, L10nKo.get(IvStep.typeName(t)) != null)
        } finally {
            L10n.lang = was
        }
        assertEquals("20 sec", Bonus.dur(20))
        assertEquals("EMOM · 12 min", Bonus.kindLine(rec(Kinds.EMOM, (1..12).map { SegResult("hiit", "Round $it", "EMOM", SegKind.St, 60, 60) })))
        assertEquals("Interval timer 40/20 × 10",
            Bonus.kindLine(rec(Kinds.TABATA, (1..10).map { SegResult("hiit", "Round $it", "WORK", SegKind.St, 40, 40) }, title = "Interval timer 40/20")))
    }
}
