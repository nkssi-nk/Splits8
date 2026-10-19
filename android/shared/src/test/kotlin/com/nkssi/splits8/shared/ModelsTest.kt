package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** 아이폰과 같은 값이 나오는지 확인 */
class ModelsTest {
    @Test fun divisionByKeyOrName() {
        assertEquals("Open Women", Division.of("openW").name)
        assertEquals("openW", Division.of("Open Women").key)
        assertEquals("openM", Division.of("unknown").key)
        assertEquals(9, Division.all.size)
    }

    @Test fun stationDetail() {
        val d = Division.of("dblX")
        assertEquals("50M · 152KG", Station.of("sledPush")!!.detail(d))
        assertEquals("100 REPS · 6KG · shared", Station.of("wallBalls")!!.detail(d))
        assertEquals("Push 152 · Pull 103 · FC 2×24 · SB 20 · WB 6KG", d.spec)
    }

    @Test fun defaults() {
        assertEquals(16, Defaults.goals.size)
        assertEquals(4100, Defaults.goals.sum())  // 270×8 + 1940
        assertEquals(1000.0, runMeters("1KM"), 0.0)
        assertEquals(400.0, runMeters("400M"), 0.0)
        assertEquals(1000.0, runMeters("INTERVAL"), 0.0)
        assertEquals(108, defaultTarget("run", "400M"))
        assertEquals(120, defaultTarget("hiit", ""))
    }

    @Test fun swiftRounding() {
        assertEquals(3, 2.5.r())
        assertEquals(-3, (-2.5).r())
        assertEquals(2, 2.49.r())
    }

    @Test fun seqFull() {
        val d = Division.of("openM")
        assertEquals(16, SeqBuilder.full(d, false, Defaults.goals).size)
        val withRox = SeqBuilder.full(d, true, Defaults.goals, 35)
        assertEquals(31, withRox.size)
        assertEquals(15, withRox.count { it.kind == SegKind.Rox })
        assertEquals(35, withRox[1].target)
        assertEquals("Run 1", withRox[0].name)
        assertEquals("skiErg", withRox[2].icon)
        assertEquals("wallBalls", withRox.last().icon)
    }

    @Test fun seqTraining() {
        val d = Division.of("openM")
        val p = Program.presets()[0].copy(sets = 2)
        val s = SeqBuilder.training(p, d, mapOf("sledPush|50M · 152KG" to 111))
        assertEquals(8, s.size)
        assertEquals(111, s[1].target)
        assertEquals(0, s[0].target)
        assertEquals(1, SeqBuilder.training(Program.hiit(), d, emptyMap()).size)
        assertEquals(5, SeqBuilder.training(Program.run(5, true), d, emptyMap()).size)
        assertEquals(1, SeqBuilder.training(Program.run(0, false), d, emptyMap()).size)
    }

    @Test fun pft() {
        assertEquals(PFTGrade.Gold, PFT.grade(1319))
        assertEquals(PFTGrade.Silver, PFT.grade(1320))
        assertEquals(PFTGrade.Silver, PFT.grade(1560))
        assertEquals(PFTGrade.Bronze, PFT.grade(1561))
        assertEquals(1320, PFT.items.sumOf { it.target })
        assertEquals("100 REPS · 4KG", PFT.detail(5, Division.of("proW")))
        assertEquals(6, PFT.seq(Division.of("openM"), listOf(1, 2, 3)).first().let { PFT.seq(Division.of("openM")).size })
        assertEquals(285, PFT.seq(Division.of("openM"), listOf(1, 2, 3))[0].target)
    }

    private fun rec(mode: Mode, total: Int, segs: List<SegResult>, division: String = "Open Men", complete: Boolean? = null) =
        Record(mode = mode, title = "t", date = Instant.parse("2026-10-01T07:00:00Z"), total = total, segs = segs,
            hr = emptyList(), kcal = 0, avgHR = 0, maxHR = 0, division = division, vsWord = "VS GOAL", complete = complete)

    private fun sim16(run: Int, st: Int) = (0 until 16).map {
        if (it % 2 == 0) SegResult("run", "Run", "1KM", SegKind.Run, run, 0)
        else SegResult("skiErg", "SkiErg", "1K", SegKind.St, st, 0)
    }

    @Test fun recordFlags() {
        assertNull(rec(Mode.Sim, 4000, sim16(270, 230)).flag)
        assertEquals(RecordFlag.Check, rec(Mode.Sim, 2900, sim16(270, 230)).flag)
        assertNull(rec(Mode.Sim, 2900, sim16(270, 230), division = "Doubles Mixed").flag)
        assertEquals(RecordFlag.Check, rec(Mode.Sim, 4000, sim16(140, 230)).flag)
        assertEquals(RecordFlag.Incomplete, rec(Mode.Sim, 4000, sim16(270, 230).take(10)).flag)
        assertEquals(RecordFlag.Incomplete, rec(Mode.Training, 100, emptyList(), complete = false).flag)
        assertNull(rec(Mode.Training, 5, emptyList()).flag)
        val r = rec(Mode.Sim, 4000, sim16(300, 200))
        assertEquals(2400, r.runTotal)
        assertEquals(300, r.runPace)
        assertEquals(16, r.splits16!!.size)
    }

    @Test fun simTarget() {
        assertEquals("VS GOAL", SimTarget.pick("goal", Defaults.goals, null, null, null, null).second)
        val f = List(16) { 200 }
        assertEquals("VS JIHO", SimTarget.pick("friend", Defaults.goals, null, f, "jiho", null).second)
        assertEquals("VS BEST", SimTarget.pick("last", Defaults.goals, null, null, null, null).second)
        assertEquals("VS LAST", SimTarget.pick("friend", Defaults.goals, f, null, "x", null).second)
    }

    @Test fun nickFilter() {
        assertTrue(NickFilter.allowed("hyrox_kim"))
        assertFalse(NickFilter.allowed("adm1n"))
        assertFalse(NickFilter.allowed("sp_lits8"))
        assertTrue(NickFilter.pattern.matches("abc_12"))
        assertFalse(NickFilter.pattern.matches("Ab"))
    }

    @Test fun settingsDefaults() {
        val s = Settings()
        assertEquals(188, s.maxHR)
        assertEquals(5, s.zone(180.0))
        assertEquals(1, s.zone(100.0))
        assertEquals(30, s.roxTarget)
        assertTrue(s.mirror)
        assertNull(s.withGlow(GlowTheme.Yellow).themeOpt)
        assertEquals("blue", s.withGlow(GlowTheme.Blue).themeOpt)
    }

    @Test fun formatTimes() {
        assertEquals("4:21", Fm.t(261))
        assertEquals("1:15:03", Fm.t(4503))
        assertEquals("±0:00", Fm.d(0))
        assertEquals("−0:27", Fm.d(-27))
        assertEquals("+2:46", Fm.d(166))
    }

    @Test fun doublesPlan() {
        var p = DoublesPlan()
        assertTrue(p.isDefault)
        // 스키 1000 m 를 150 m 씩, 내가 먼저 → 7번 교대 (나 4번 · 파트너 3번, 마지막 100 m)
        p = p.setChunk(0, 150.0)
        assertEquals(7, p.turns(0))
        assertEquals(4, p.myTurns(0))
        assertEquals(550.0, p.mine(0), 0.001)
        assertEquals(450.0, p.partners(0), 0.001)
        assertEquals(100.0, p.sequence(0).last().amount, 0.001)
        // 고를 수 없는 값은 무시
        assertEquals(150.0, p.setChunk(0, 333.0).chunk(0), 0.001)
        assertEquals(12.5, p.chunk(1), 0.001)
        assertEquals("12.5", DoublesPlan.num(12.5))
        assertEquals("250", DoublesPlan.num(250.0))
        // 받은 계획: 먼저 하는 사람이 바뀌고 파트너 = 보낸 사람
        val sw = p.setMeFirst(2, false).swapped("gatebu")
        assertFalse(sw.meFirst(0))
        assertTrue(sw.meFirst(2))
        assertEquals("gatebu", sw.partnerShown)
        assertEquals(150.0, sw.chunk(0), 0.001)
        // 이름 정리
        assertEquals("ab", DoublesPlan.cleanName("  a\nb "))
        assertNull(DoublesPlan.cleanName("   "))
        assertEquals(20, DoublesPlan.cleanName("x".repeat(30))!!.length)
    }

    @Test fun doublesOldFileAndJson() {
        // 예전(빌드 23) 저장 파일 {"shares": [...]} → 기본값
        val old = SplitsJson.decodeFromString(DoublesPlan.serializer(), """{"shares":[60,50,50,50,50,50,50,50]}""")
        assertTrue(old.isDefault)
        // 아이폰 모양 그대로 읽고 씀
        val p = DoublesPlan().setChunk(7, 10.0).copy(partnerName = "kim")
        val j = SplitsJson.encodeToString(DoublesPlan.serializer(), p)
        assertTrue(j.contains("\"chunks\":[250.0,12.5,12.5,20.0,250.0,50.0,25.0,10.0]"))
        assertEquals(p.chunk(7), SplitsJson.decodeFromString(DoublesPlan.serializer(), j).chunk(7), 0.001)
        // 이상한 값은 기본값으로
        val bad = SplitsJson.decodeFromString(DoublesPlan.serializer(), """{"chunks":[999,1],"firsts":[false]}""")
        assertEquals(250.0, bad.chunk(0), 0.001)
        assertFalse(bad.meFirst(0))
    }

    @Test fun doublesLink() {
        val p = DoublesPlan().setChunk(0, 150.0).setMeFirst(1, false)
        val tok = DoublesLink.token(p, "ji/ho")
        assertTrue(tok.startsWith("d1."))
        val json = String(java.util.Base64.getDecoder().decode(
            tok.drop(3).replace('-', '+').replace('_', '/').let { it + "=".repeat((4 - it.length % 4) % 4) }))
        // 아이폰 JSONEncoder(sortedKeys) 와 같은 글자
        assertEquals("""{"c":[150,12.5,12.5,20,250,50,25,20],"f":[1,0,1,1,1,1,1,1],"n":"ji\/ho"}""", json)
        val (got, sender) = DoublesLink.read(tok)!!
        assertEquals("ji/ho", sender)
        assertEquals(150.0, got.chunk(0), 0.001)
        assertFalse(got.meFirst(1))
        // 주소에서 글자 꺼내기
        assertEquals(tok, DoublesLink.token("splits8://d?d=$tok"))
        assertEquals(tok, DoublesLink.token("https://splits8.com/splits8/t.html#$tok"))
        assertNull(DoublesLink.token("splits8://t?d=$tok"))
        assertTrue(DoublesLink.isDoubles("splits8://d?d=x"))
        assertFalse(DoublesLink.isDoubles("splits8://t?d=1.abc"))
        // 이상한 글자는 못 읽음
        assertNull(DoublesLink.read("d1.@@@"))
        assertNull(DoublesLink.read("1.abc"))
    }

    @Test fun units() {
        assertEquals("50M · 335LB", Units.detail("50M · 152KG", true))
        assertEquals("2×53LB", Units.detail("2×24KG", true))
        assertEquals("0.62MI", Units.detail("1KM", true))
        assertEquals("1000M", Units.detail("1000M", true))
        assertEquals("50M · 152KG", Units.detail("50M · 152KG", false))
        assertEquals(483, Units.pace(300, true))
        assertEquals("3.11", Units.dist(5000.0, true))
        assertEquals("/MI", Units.paceUnit(true))
    }

    @Test fun repTuneFit() {
        // 2초마다 한 번 크게 흔듦 (20번) → 기준을 찾으면 20번을 셈
        val mags = ArrayList<Double>()
        val times = ArrayList<Double>()
        for (i in 0 until 50 * 42) {
            val t = i / 50.0
            val ph = t % 2.0
            mags.add(if (ph < 0.25 && t < 40) 0.9 else 0.05)
            times.add(t)
        }
        val fit = RepTune.fit("wallBalls", mags, times, 20)!!
        assertEquals(20, RepTune.count(mags, times, fit))
        assertNotNull(fit.date)
        assertNull(RepTune.fit("burpee", mags, times, 20))
        assertNull(RepTune.fit("row", mags.take(10), times.take(10), 20))
    }

    @Test fun hyroxRank() {
        val r = HyroxRank.of("openM", 90 * 60)!!
        assertEquals("Intermediate", r.level)
        assertEquals(33, r.pct)
        assertEquals("Advanced" to 85 * 60, r.next)
        assertEquals(1, HyroxRank.of("Open Women", 60 * 60)!!.pct)
        assertNull(HyroxRank.of("openM", 60 * 60)!!.next)
        assertEquals("Elite", HyroxRank.of("openM", 60 * 60)!!.level)
        assertNull(HyroxRank.of("dblM", 90 * 60))
        assertNull(HyroxRank.of("relay", 90 * 60))
        assertEquals("World level", HyroxRank.of("proW", 60 * 60)!!.level)
    }

    @Test fun livePace() {
        assertEquals("Measuring", LivePace.text(30, 5.0))
        assertEquals("–:––", LivePace.text(30, null))
        assertEquals("5:00", LivePace.text(150, 500.0))
        // 지금 속도가 있으면 그걸로 (4 m/s = 4:10 /km)
        assertEquals("4:10", LivePace.text(150, 500.0, speed = 4.0))
        assertEquals("6:42", LivePace.text(150, 500.0, imperial = true, speed = 4.0))
    }

    @Test fun cheerSeedStable() {
        val id = "6F1C2A3B-0000-4000-8000-0000000000AA"
        assertEquals(CheerPicker.seed(id), CheerPicker.seed(id.lowercase()))
        assertTrue(CheerPicker.seed(id) >= 0)
    }

    @Test fun cheerPick() {
        L10n.lang = "en"
        val base = CheerInput(Mode.Race, "Seoul", 4000, true, false,
            Instant.parse("2026-10-01T03:00:00Z"), Instant.parse("2026-10-01T04:10:00Z"), 2)
        assertEquals("Goal beaten by 1:05. Great race.", CheerPicker.pick(base.copy(goalDelta = -65)).line)
        assertEquals(Cheer.Tone.Check, CheerPicker.pick(base.copy(check = true)).tone)
        val pft = base.copy(mode = Mode.Pft, total = 1330, pftPrevBest = 1400)
        assertEquals("Silver — just 11s from Gold.", CheerPicker.pick(pft).line)
        L10n.lang = "ko"
        assertNotNull(CheerPicker.pick(pft).line)
        assertFalse(CheerPicker.pick(base.copy(goalDelta = -65)).line.startsWith("Goal"))
        L10n.lang = "en"
    }
}
