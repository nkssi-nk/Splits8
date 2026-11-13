package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class OfficialTest {
    @Test fun doublesLevels() {
        // 1.2.4 더블: Rox Lyfe 단계 (% 없음)
        assertEquals("Top-end level", HyroxRank.of("dblM", 50 * 60)!!.level)
        assertNull(HyroxRank.of("dblM", 50 * 60)!!.next)
        assertEquals("Competitive level", HyroxRank.of("Doubles Men", 60 * 60)!!.level)
        assertEquals("Faster than Doubles average", HyroxRank.of("dblX", 70 * 60)!!.level)
        assertEquals("Slower than Doubles average", HyroxRank.of("dblW", 95 * 60)!!.level)
        assertEquals("Faster than Doubles average" to 89 * 60 + 24, HyroxRank.of("dblW", 95 * 60)!!.next)
        assertNull(HyroxRank.of("dblW", 95 * 60)!!.pct)
        assertEquals("Faster than Doubles average", HyroxRank.of("dblMP", 60 * 60)!!.level)  // Pro 더블은 평균만
        assertNull(HyroxRank.of("dblMP", 60 * 60)!!.next)
        assertNull(HyroxRank.of("relay", 60 * 60))
    }

    private val sample = """
        Overall Time
        Rank (M/W)  90
        Rank (AG)  18
        Overall Time  01:06:47
        Split  Time  Place
        Running 1  00:03:09  –
        1000m SkiErg  00:04:07  45
        Running 2  00:04:12  –
        50m Sled Push  00:03:12  21
        Running 3  00:04:20  –
        50m Sled Pull  00:04:33  28
        Running 4  00:04:30  –
        80m Burpee Broad Jump  00:02:37  7
        Running 5  00:04:32  –
        1000m Row  00:04:23  45
        Running 6  00:04:23  –
        200m Farmers Carry  00:02:03  42
        Running 7  00:04:38  –
        100m Sandbag Lunges  00:03:46  12
        Running 8  00:03:41  –
        Wall Balls  00:04:31  8
        Roxzone Time  00:04:19  –
        Run Total  00:33:21  24
        Best Run Lap  00:03:41  23
    """.trimIndent()

    @Test fun parseOfficialSheet() {
        val d = OfficialParse.parse(sample)
        assertEquals(66 * 60 + 47, d.total)
        assertEquals(90, d.rank)
        assertEquals(18, d.ageRank)
        assertEquals(listOf(189, 252, 260, 270, 272, 263, 278, 221), d.runs)
        assertEquals(listOf(247, 192, 273, 157, 263, 123, 226, 271), d.st)
        assertEquals(259, d.rox)
        assertEquals(20, d.found)
        // 시간 글자 고치기: O→0
        assertEquals(listOf(247), OfficialParse.times("SkiErg 0O:04:O7"))
    }

    @Test fun officialRecord() {
        val d = OfficialParse.parse(sample)
        val o = OfficialResult(rank = 90, ageRank = 18, field = 900, time = d.total!!, event = "Seoul 2026", division = "Pro Men")
        val r = OfficialParse.record(d.runs.map { it!! }, d.st.map { it!! }, d.rox!!, o, Instant.parse("2026-11-15T00:00:00Z"))
        assertEquals(17, r.segs.size)
        assertTrue(r.counts)
        assertTrue(r.isOfficial)
        assertEquals("Faster than Pro average", HyroxRank.of(r.division, r.total)!!.level)
        assertEquals(10.0, o.topPct!!, 0.001)
        assertEquals(16, r.splits16!!.size)
        // 저장 · 읽기 (예전 앱이 모르는 칸이어도 됨)
        val back = SplitsJson.decodeFromString(Record.serializer(), SplitsJson.encodeToString(Record.serializer(), r))
        assertEquals(o, back.official)
    }
}
