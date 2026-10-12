package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import kotlin.math.cos

class RecordBookTest {
    private fun at(s: String) = Instant.parse(s)

    private fun sim(date: String, runs: List<Int>, sts: List<Int>, rox: Int = 0, mode: Mode = Mode.Sim, goal: Int? = null): Record {
        val segs = ArrayList<SegResult>()
        for (i in 0 until 8) {
            segs.add(SegResult("run", "Run ${i + 1}", "1KM", SegKind.Run, runs[i], 270))
            if (rox > 0) segs.add(SegResult("roxzone", "Roxzone", "TRANSITION", SegKind.Rox, rox, 30))
            val s = Station.all[i]
            segs.add(SegResult(s.key, s.name, "", SegKind.St, sts[i], 240))
            if (rox > 0 && i < 7) segs.add(SegResult("roxzone", "Roxzone", "TRANSITION", SegKind.Rox, rox, 30))
        }
        return Record(mode = mode, title = "Full Simulation", date = at(date), total = segs.sumOf { it.time }, segs = segs,
            hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = "Open Men", vsWord = "VS GOAL", goal = goal)
    }

    private val r8 = List(8) { 300 }
    private val s8 = List(8) { 240 }

    @Test fun pbAndVs() {
        val a = sim("2026-09-01T09:00:00Z", r8, s8)                       // 4320
        val b = sim("2026-09-08T09:00:00Z", r8.map { it - 10 }, s8)       // 4240
        val c = sim("2026-09-15T09:00:00Z", r8.map { it + 5 }, s8)        // 4360
        val book = RecordBook(listOf(a, b, c), Settings())
        assertTrue(book.isPB(b))
        assertFalse(book.isPB(a))
        assertEquals(b.id, book.simBest!!.id)
        assertEquals(c.id, book.simLast!!.id)
        assertEquals("VS LAST" to 120, book.vs(c))
        assertEquals("VS LAST" to null, book.vs(a))
        // 하나뿐이면 PB 아님
        assertFalse(RecordBook(listOf(a), Settings()).isPB(a))
    }

    @Test fun segBestsSkipImplausible() {
        val t1 = Record(mode = Mode.Training, title = "x", date = at("2026-09-01T09:00:00Z"), total = 400,
            segs = listOf(
                SegResult("sledPush", "Sled Push", "50M · 152KG", SegKind.St, 150, 0),
                SegResult("sledPull", "Sled Pull", "50M · 103KG", SegKind.St, 10, 0),   // 너무 빠름 → 뺌
                SegResult("run", "Run", "400M", SegKind.Run, 80, 0),
            ), hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = "Open Men", vsWord = "VS BEST")
        val b = RecordBook(listOf(t1), Settings()).segBests
        assertEquals(150, b["sledPush|50M · 152KG"])
        assertNull(b["sledPull|50M · 103KG"])
        assertEquals(80, b["run|400M"])
    }

    @Test fun fatigue() {
        // 스키 다음 러닝(Run 2)만 30초 느림
        val runs = listOf(300, 330, 300, 300, 300, 300, 300, 300)
        val f = Fatigue.analyze(listOf(sim("2026-09-01T09:00:00Z", runs, s8)))!!
        assertEquals(304, f.avgRun)                     // 2430/8 = 303.75 → 304
        assertEquals(26, f.deltas[0])                    // 330 − 303.75 = 26.25 → 26
        assertEquals(-4, f.deltas[1])
        assertNull(f.deltas[7])
        assertEquals(0, f.worst)
    }

    @Test fun predict() {
        val now = at("2026-10-12T00:00:00Z")
        val s = sim("2026-10-01T09:00:00Z", r8, s8)
        val p = RecordBook(listOf(s), Settings()).predictFinish(now)!!
        // 풀 시뮬 최고(4320)보다 길게 나오지 않음
        assertTrue(p <= 4320)
        // 90일 넘은 기록만 있으면 없음
        assertNull(RecordBook(listOf(s), Settings()).predictFinish(at("2027-03-01T00:00:00Z")))
    }

    private fun run(kms: List<Int>, dist: List<Double?> = kms.map { null }): Record {
        val segs = kms.mapIndexed { i, t -> SegResult("run", "KM ${i + 1}", "1KM", SegKind.Run, t, 0, dist = dist[i]) }
        return Record(mode = Mode.Training, title = "Run 5K", date = at("2026-10-01T09:00:00Z"), total = kms.sum(),
            segs = segs, hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = "Open Men", vsWord = "VS BEST", kind = "run")
    }

    @Test fun runBests() {
        val r = run(listOf(300, 290, 280, 270, 260, 250))
        assertEquals(250, r.bestEffort(1000.0))
        assertEquals(270 + 260 + 250 + 280 + 290, r.bestEffort(5000.0))  // 2번째부터 6번째
        assertNull(r.bestEffort(10000.0))
        assertEquals(275, r.avgKmPace)
        // 마지막 짧은 구간은 계획 거리로 세지 않음
        assertEquals(5000.0, run(listOf(300, 300, 300, 300, 300, 60)).runDistance, 0.0)
        // 너무 빠른 1 km 는 뺌
        assertNull(run(listOf(120)).bestEffort(1000.0))
    }

    @Test fun runPBs() {
        val a = run(listOf(300, 300, 300, 300, 300))
        val b = run(listOf(290, 290, 290, 290, 290)).copy(id = newId(), date = at("2026-10-02T09:00:00Z"))
        val book = RecordBook(listOf(a, b), Settings())
        assertTrue(book.isPB(b))
        assertFalse(book.isPB(a))
        assertEquals(listOf(1000.0, 5000.0), book.runPBs(b))
    }

    @Test fun laps() {
        // 반지름 70 m 원을 4바퀴, 1바퀴 100초, 5초마다 점
        val r = 70.0
        val lat0 = 37.5
        val pts = (0..400 step 5).map { t ->
            val ang = 2 * Math.PI * t / 100.0
            val x = r * kotlin.math.sin(ang)
            val y = r - r * cos(ang)
            RoutePt(lat0 + y / 111_320.0, 127.0 + x / (111_320.0 * cos(lat0 * Math.PI / 180)), t = t)
        }
        val l = RunLaps.laps(pts)
        assertNotNull(l)
        assertEquals(4, l!!.size)
        assertTrue(l.all { it in 95..105 })
        assertNull(RunLaps.laps(pts.take(15)))
    }

    @Test fun cheerInput() {
        val a = sim("2026-09-01T09:00:00Z", r8, s8)
        val b = sim("2026-09-02T09:00:00Z", r8.map { it - 10 }, s8)
        val book = RecordBook(listOf(a, b), Settings())
        val x = book.cheerInput(b)
        assertEquals(-80, x.pbDelta)
        assertEquals(-80, x.lastDelta)
        assertEquals(2, x.streak)
        assertFalse(x.firstEver)
        assertTrue(book.cheerInput(a).firstEver)
        assertEquals("★ PB", book.cheer(b).tag)
    }

    @Test fun insights() {
        L10n.lang = "en"
        val a = sim("2026-09-01T09:00:00Z", r8, s8, rox = 45)
        val runs = listOf(300, 340, 300, 300, 300, 300, 300, 300)
        val b = sim("2026-09-08T09:00:00Z", runs, s8.mapIndexed { i, v -> if (i == 4) v - 40 else v }, rox = 45)
        val book = RecordBook(listOf(a, b), Settings())
        val ins = Insights.make(b, book)
        assertTrue(ins.size in 2..4)
        // 같은 묶음은 하나만, 조언은 하나만
        assertEquals(ins.size, ins.map { it.group }.toSet().size)
        assertTrue(ins.count { it.tip != null } <= 1)
        // 새 최고(로잉 −40초)가 맨 위
        assertEquals(7, ins[0].id)
        assertEquals("New best: [y]Row 3:20[/y].", ins[0].text)
        assertTrue(ins.any { it.text.contains("Run") || it.group == "rox" })
        // 같은 기록은 늘 같은 결과
        assertEquals(ins, Insights.make(b, book))
    }

    @Test fun insightPieces() {
        val p = Insights.pieces("Your runs slowed most after [y]Row[/y] — [r]+20s[/r] on your average run.")
        assertEquals(listOf("Your runs slowed most after " to null, "Row" to "y", " — " to null, "+20s" to "r",
            " on your average run." to null), p)
        assertEquals(listOf("[y]open" to null), Insights.pieces("[y]open"))
    }
}
