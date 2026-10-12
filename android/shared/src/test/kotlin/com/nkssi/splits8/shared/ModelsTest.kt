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
        p = p.set(0, 60)
        assertEquals(600, p.mine(0))
        assertEquals(400, p.partners(0))
        assertEquals(50, DoublesPlan(listOf(70)).share(5))
        assertEquals(100, p.set(1, 150).share(1))
    }

    @Test fun livePace() {
        assertEquals("–:––", LivePace.text(30, 5.0))
        assertEquals("5:00", LivePace.text(150, 500.0))
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
