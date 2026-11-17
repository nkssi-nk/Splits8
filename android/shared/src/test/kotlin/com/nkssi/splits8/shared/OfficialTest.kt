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
    // 1.2.5 · TrainRox 한국어 화면 (서울 2026 더블 남자 — 대표님 캡처를 기기가 읽었을 모양)
    private val koSheet = """
이재성  김내균
HYROX Seoul 2026
HYROX DOUBLES MEN • AG 40-44
1:12:46
전체 #1141  AG #82
달리기  스테이션  ROXZONE  페이스
38:38  24:56  9:20  5:30/km
35.01점  만렙형
TRAINROX LEAGUE · 실버 #=77,518
요약  레이스 분석  타임라인  비교
비교  전체  AG 40-44
스플릿  전체  러닝  스테이션
시간  순위
평균 페이스 /km  5:30
러닝 1  2:52  #1496
SkiErg  4:13  #1034
러닝 2  4:48  #1442
Sled Push  1:42  #380
러닝 3  4:54  #1148
Sled Pull  3:25  #936
러닝 4  4:49  #1049
BBJ  3:02  #1860
러닝 5  5:11  #1301
Row  4:34  #1042
러닝 6  4:56  #1096
Farmers C.  2:05  #2126
러닝 7  4:47  #795
S. Lunges  1:54  #178
러닝 8  6:21  #1358
Wall Balls  4:01  #1235
    """.trimIndent()

    @Test fun parseKoreanSheet() {
        val d = OfficialParse.parse(koSheet)
        assertEquals(72 * 60 + 46, d.total)
        assertEquals(1141, d.rank)
        assertEquals(82, d.ageRank)                       // "AG 40-44" 는 나이대라 순위가 아님
        assertEquals(listOf(172, 288, 294, 289, 311, 296, 287, 381), d.runs)
        assertEquals(listOf(253, 102, 205, 182, 274, 125, 114, 241), d.st)
        assertEquals(560, d.rox)                          // 요약 줄의 ROXZONE 9:20
        assertEquals("Doubles Men", d.division)
    }

    @Test fun parseByOrderWhenNamesMissing() {
        // 막대 위 이름을 못 읽은 경우: 시간만 위에서부터 16개 → 러닝 · 스테이션 번갈아
        val names = listOf("러닝 ", "SkiErg", "Sled", "BBJ", "Row ", "Farmers", "S. L", "Wall")
        val noName = koSheet.lines().joinToString("\n") { l -> if (names.any { l.startsWith(it) }) l.split("  ").drop(1).joinToString("  ") else l }
        val d = OfficialParse.parse(noName)
        assertEquals(listOf(172, 288, 294, 289, 311, 296, 287, 381), d.runs)
        assertEquals(listOf(253, 102, 205, 182, 274, 125, 114, 241), d.st)
    }

    @Test fun officialSkipsSegmentChecks() {
        // 서울처럼 러닝 1 이 짧아도 공식 기록은 "확인 필요" 아님. 앱 레이스 기록도 러닝 1:30 까지는 정상
        val d = OfficialParse.parse(koSheet)
        val runs = d.runs.map { it!! }.toMutableList().also { it[0] = 135 }
        val o = OfficialResult(rank = 1141, ageRank = 82, time = d.total!!, event = "Seoul 2026", division = "Doubles Men")
        val r = OfficialParse.record(runs, d.st.map { it!! }, d.rox!!, o, Instant.parse("2026-11-15T00:00:00Z"))
        assertNull(r.flag)
        assertTrue(r.counts)
        assertNull(r.copy(official = null).flag)              // 레이스: 2:15 ≥ 1:30
        assertEquals(RecordFlag.Check, r.copy(official = null, segs = r.segs.mapIndexed { i, s -> if (i == 0) s.copy(time = 80) else s }).flag)
    }

    @Test fun robustMaxHr() {
        assertEquals(172, HRStat.robustMax(listOf(165, 168, 170, 172, 171, 190, 170, 169)))   // 한 번 튄 190 빼기
        assertEquals(180, HRStat.robustMax(listOf(170, 174, 177, 180, 179, 176)))             // 꾸준히 오른 180 은 그대로
        assertEquals(150, HRStat.robustMax(listOf(150)))
    }

    @Test fun zonesWithRestingHr() {
        val s = Settings(hrMode = "manual", manualHr = 175, restHr = 62)
        assertEquals(listOf(130, 141, 152, 164), listOf(60, 70, 80, 90).map { s.zoneBpm(it) })   // 애플워치 화면 경계와 같음
        assertEquals(5, s.zone(165.0))
        assertEquals(4, s.zone(160.0))
        val old = Settings(hrMode = "manual", manualHr = 175)
        assertEquals(5, old.zone(160.0))                       // 안정 심박 없으면 예전처럼 최대 심박의 %
    }
}
