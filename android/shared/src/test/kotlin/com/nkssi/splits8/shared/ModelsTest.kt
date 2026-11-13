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

    @Test fun skippedFlags() {
        // 1.2.2: 건너뛴 구간(0초)이 있으면 "확인 필요" 대신 Skipped, 3개부터 Partial. 둘 다 counts = false
        val one = sim16(270, 230).mapIndexed { i, s -> if (i == 3) s.copy(time = 0, skipped = true) else s }
        val r1 = rec(Mode.Sim, 3770, one)
        assertEquals(RecordFlag.Skipped, r1.flag)
        assertEquals(1, r1.skippedCount)
        assertFalse(r1.counts)
        val three = sim16(270, 230).mapIndexed { i, s -> if (i in listOf(3, 5, 7)) s.copy(time = 0, skipped = true) else s }
        assertEquals(RecordFlag.Partial, rec(Mode.Sim, 3310, three).flag)
        // 예전 기록(skipped 없음)은 그대로 — 0초 스테이션은 여전히 확인 필요
        val old = sim16(270, 230).mapIndexed { i, s -> if (i == 3) s.copy(time = 0) else s }
        assertEquals(RecordFlag.Check, rec(Mode.Sim, 3770, old).flag)
        // JSON 으로 갔다 와도 유지
        val back = SplitsJson.decodeFromString(Record.serializer(), SplitsJson.encodeToString(Record.serializer(), r1))
        assertTrue(back.segs[3].isSkipped)
        assertEquals(RecordFlag.Skipped, back.flag)
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
        // 스키 1000 m 를 150 m 씩, 내가 먼저 → 6번 교대 (1.2.1: 남는 100 m 는 마지막 두 차례에 반씩 → 150×4 + 200 + 200)
        p = p.setChunk(0, 150.0)
        assertEquals(6, p.turns(0))
        assertEquals(3, p.myTurns(0))
        assertEquals(500.0, p.mine(0), 0.001)
        assertEquals(500.0, p.partners(0), 0.001)
        assertEquals(200.0, p.sequence(0).last().amount, 0.001)
        assertFalse(p.isEdited(0))                     // 빠르게 채운 모양은 "고친 것" 아님
        // 1.2.1: 슬레드 반 바퀴 · 숫자 둘째 자리
        assertEquals(8, p.setChunk(1, 6.25).turns(1))
        assertEquals("6.25", DoublesPlan.num(6.25))
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

    /** 1.2.1: 차례마다 양 고치기 — 마지막 줄은 늘 나머지, 넘침 · 모자람 없음 (시험 페이지와 같은 예) */
    @Test fun doublesTurnsEdit() {
        // 혼성 예 1: Sled Push 50 · 12.5 씩 → 2번 · 4번 줄을 6.25 로 → 나 37.5 / 파 12.5, 5번 교대
        var p = DoublesPlan()
        assertEquals(4, p.turns(1))
        assertFalse(p.canPlus(1, 0))                    // 이미 꽉 참
        p = p.minus(1, 1)                                // 2번 줄 12.5 → 6.25, 나머지 6.25 (나)
        assertEquals(5, p.turns(1))
        assertTrue(p.lastIsRemainder(1))
        assertEquals(6.25, p.remainder(1), 0.001)
        p = p.minus(1, 3)                                // 4번 줄 → 6.25, 나머지 12.5
        val s1 = p.sequence(1)
        assertEquals(listOf(12.5, 6.25, 12.5, 6.25, 12.5), s1.map { it.amount })
        assertEquals(listOf(true, false, true, false, true), s1.map { it.me })
        assertEquals(37.5, p.mine(1), 0.001)
        assertEquals(12.5, p.partners(1), 0.001)
        assertEquals(50.0, s1.sumOf { it.amount }, 0.001)
        assertTrue(p.isEdited(1))
        // 혼성 예 2: BBJ 80 · 20 씩 → 1 · 3번 줄 10 → 나머지 20 → 나머지 줄 − → 파 10 생김 = 나 30 / 파 50
        p = p.setChunk(3, 20.0).minus(3, 0).minus(3, 2)
        assertEquals(listOf(10.0, 20.0, 10.0, 20.0, 20.0), p.sequence(3).map { it.amount })
        assertTrue(p.canSplitRemainder(3))
        p = p.splitRemainder(3)
        assertEquals(listOf(10.0, 20.0, 10.0, 20.0, 10.0, 10.0), p.sequence(3).map { it.amount })
        assertEquals(30.0, p.mine(3), 0.001)
        assertEquals(50.0, p.partners(3), 0.001)
        assertFalse(p.canSplitRemainder(3))              // 나머지 10 = 1칸 → 더 못 나눔
        // 최소 1칸 · 나머지가 있으면 + 가능(나머지를 먹음) · 꽉 차면 + 잠금 · 합은 늘 총량
        assertFalse(p.canMinus(3, 0))
        assertTrue(p.canPlus(3, 4))
        val q = p.plus(3, 4)
        assertEquals(listOf(10.0, 20.0, 10.0, 20.0, 20.0), q.sequence(3).map { it.amount })
        assertFalse(q.canPlus(3, 4))
        assertFalse(q.lastIsRemainder(3))
        for (i in 0 until 8) assertEquals(DoublesPlan.total(i), p.sequence(i).sumOf { it.amount }, 0.001)
        // 한 번 양을 다시 고르면(초기화) 고친 차례 사라짐
        assertFalse(p.resetTurns(1).isEdited(1))
        // 받은 계획 뒤집기: 양 그대로 · 사람만 뒤집힘
        val sw = p.swapped("yuna")
        assertEquals(p.sequence(1).map { it.amount }, sw.sequence(1).map { it.amount })
        assertEquals(p.sequence(1).map { !it.me }, sw.sequence(1).map { it.me })
        // 저장 · 링크에 차례가 들어가고, 옛 모양(차례 없음)도 그대로 읽힘
        val j = SplitsJson.encodeToString(DoublesPlan.serializer(), p)
        assertTrue(j.contains("\"turns\""))
        assertEquals(p.sequence(1).map { it.amount }, SplitsJson.decodeFromString(DoublesPlan.serializer(), j).sequence(1).map { it.amount })
        val tok = DoublesLink.token(p, "kim")
        val got = DoublesLink.read(tok)!!.first
        assertEquals(p.sequence(3).map { it.amount }, got.sequence(3).map { it.amount })
        // 이상한 차례(단위 안 맞음 · 총량 넘음)는 버리고 한 번 양 방식으로
        val bad = SplitsJson.decodeFromString(DoublesPlan.serializer(), """{"chunks":[250,12.5,12.5,20,250,50,25,20],"firsts":[true,true,true,true,true,true,true,true],"turns":[[333],null,null,null,null,null,null,[60,60]]}""")
        assertFalse(bad.isEdited(0))
        assertFalse(bad.isEdited(7))
        assertTrue(bad.isDefault)
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
        assertEquals("Slower than Doubles average", HyroxRank.of("dblM", 90 * 60)!!.level)   // 1.2.4: 더블도 단계
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

    /** 17번: 친구 순서 — 정한 순서대로, 새 친구는 맨 아래, 숨긴 친구는 제자리 */
    @Test fun listOrderApplyAndMove() {
        val ids = listOf("a", "b", "c", "d")
        assertEquals(ids, ListOrder.ordered(ids, emptyList()) { it })
        // 저장된 순서 c, a + 목록에 없는 b · d 는 원래 순서로 아래 (지워진 x 는 무시)
        assertEquals(listOf("c", "a", "b", "d"), ListOrder.ordered(ids, listOf("c", "x", "a")) { it })
        // 맨 위 ↔ 맨 아래
        assertEquals(listOf("b", "c", "d", "a"), ListOrder.moved(ids, ids, 0, 3))
        assertEquals(listOf("d", "a", "b", "c"), ListOrder.moved(ids, ids, 3, 0))
        // b 를 숨김: 보이는 a c d 에서 d 를 맨 위로 → b 는 둘째 자리 그대로
        assertEquals(listOf("d", "b", "a", "c"), ListOrder.moved(ids, listOf("a", "c", "d"), 2, 0))
        assertEquals(ids, ListOrder.moved(ids, ids, 1, 9))
    }

    /** 16 · 17번: 숨긴 친구 · 친구 순서 — 예전 설정 파일도 읽히고, 비어 있으면 파일에 안 씀 */
    @Test fun hiddenAndOrderSettingsCompatible() {
        val old = SplitsJson.decodeFromString(Settings.serializer(), """{"division":"openW","blockedOpt":[{"id":"x","name":"xx"}]}""")
        assertTrue(old.hidden.isEmpty())
        assertTrue(old.friendOrder.isEmpty())
        assertEquals("x", old.blocked.single().id)
        val plain = SplitsJson.encodeToString(Settings.serializer(), Settings().withHidden(emptyList()).withFriendOrder(emptyList()))
        assertFalse(plain.contains("hiddenOpt"))
        assertFalse(plain.contains("friendOrderOpt"))
        val s = Settings().withHidden(listOf(BlockedUser("u1", "jiho"))).withFriendOrder(listOf("u2", "u1"))
        val back = SplitsJson.decodeFromString(Settings.serializer(), SplitsJson.encodeToString(Settings.serializer(), s))
        assertEquals("jiho", back.hidden.single().name)
        assertEquals(listOf("u2", "u1"), back.friendOrder)
    }
}
