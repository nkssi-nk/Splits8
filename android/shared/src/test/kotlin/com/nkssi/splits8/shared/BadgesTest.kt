package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

/** 배지 (아이폰 Badges.swift) · PFT 등급 (빌드 26 Iron · Unranked) */
class BadgesTest {
    private val zone = ZoneId.of("Asia/Seoul")
    private fun day(s: String) = Instant.parse("${s}T03:00:00Z")

    private fun sim(date: String, total: Int): Record {
        val segs = ArrayList<SegResult>()
        for (i in 0 until 8) {
            segs.add(SegResult("run", "Run ${i + 1}", "1KM", SegKind.Run, total / 16, 270))
            val st = Station.all[i]
            segs.add(SegResult(st.key, st.name, "", SegKind.St, total / 16, 200))
        }
        return Record(mode = Mode.Sim, title = "Full Simulation", date = day(date), total = total, segs = segs, hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = "Open Men", vsWord = "vs best")
    }

    @Test fun firstSimAllStationsAndPbs() {
        val rs = listOf(sim("2026-09-01", 5500), sim("2026-09-08", 5300), sim("2026-09-15", 4700), sim("2026-09-22", 4800))
        val got = Badges.earned(rs, zone)
        assertEquals(day("2026-09-01"), got["firstSim"])
        assertEquals(day("2026-09-01"), got["allStations"])
        assertEquals(day("2026-09-08"), got["sub130"])            // 5300 < 5400
        assertEquals(day("2026-09-15"), got["sub120"])            // 4700 < 4800
        assertEquals(day("2026-09-08"), got["pb1"])               // 첫 PB
        assertTrue("pb5" !in got)
        assertEquals(day("2026-09-22"), got["weeks4"])            // 4주 연속
        assertEquals(32.0, 8 * 4.0, 0.0)
        assertTrue("run100" !in got)                              // 32 km
    }

    @Test fun newBadgesForRecord() {
        val old = listOf(sim("2026-09-01", 5500))
        val r = sim("2026-09-08", 5300)
        assertEquals(listOf("sub130", "pb1"), Badges.new(r, old, zone).map { it.id })
        assertTrue(Badges.new(old.first(), old, zone).map { it.id }.contains("firstSim"))
    }

    @Test fun pftGrades() {
        assertEquals(PFTGrade.Gold, PFT.grade(21 * 60 + 59))
        assertEquals(PFTGrade.Silver, PFT.grade(26 * 60))
        assertEquals(PFTGrade.Bronze, PFT.grade(30 * 60))
        assertEquals(PFTGrade.Iron, PFT.grade(30 * 60 + 1))
        assertEquals(PFTGrade.Iron, PFT.grade(35 * 60))
        assertEquals(PFTGrade.Unranked, PFT.grade(35 * 60 + 1))
        assertEquals(PFTGrade.Bronze, PFTGrade.Iron.next)
        assertEquals(PFT.bronzeLimit, PFT.limit(PFTGrade.Bronze))
    }
}
