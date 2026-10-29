package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.IvStep
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Lift
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.SplitsJson
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/** 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 — 만들기 시트 · 폰 기록 엔진 · 기록 화면 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
class BonusFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private var t = 1_790_000_000_000L

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
    }

    @After fun tearDown() {
        Router.ask = null; Router.bonus = null; Router.editId = null; Router.detail = null
    }

    private fun show(s: Scr) {
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performScrollTo().performClick(); rule.waitForIdle() }

    /** 0.25초씩 흘려 보냄 (폰 화면처럼) */
    private fun PhoneRunEngine.run(ms: Long) {
        var left = ms
        while (left > 0) { val d = minOf(250L, left); t += d; left -= d; timerTick() }
    }

    // MARK: 만들기 시트

    @Test fun tabataSheetSavesDefault() {
        show(Scr.Training)
        Router.bonus = BonusRequest(Kinds.TABATA); rule.waitForIdle()
        tap("bonus.save")
        val p = Store.programs.first { it.kind == Kinds.TABATA }
        assertEquals("Tabata", p.name)
        assertEquals(20, p.work); assertEquals(10, p.rest); assertEquals(8, p.rounds)
        assertTrue(p.isOpen)
    }

    @Test fun emomAmrapLiftIvrunSheetsSave() {
        show(Scr.Training)
        for (k in listOf(Kinds.EMOM, Kinds.AMRAP, Kinds.LIFT, Kinds.IVRUN)) {
            Router.bonus = BonusRequest(k); rule.waitForIdle()
            tap("bonus.save")
            assertNull(Router.bonus)
        }
        assertNotNull(Store.programs.firstOrNull { it.kind == Kinds.EMOM && it.every == 60 && it.rounds == 12 })
        assertNotNull(Store.programs.firstOrNull { it.kind == Kinds.AMRAP && it.cap == 15 * 60 })
        assertNotNull(Store.programs.firstOrNull { it.kind == Kinds.LIFT && it.lifts?.firstOrNull()?.name == "Squat" })
        val iv = Store.programs.first { it.kind == Kinds.IVRUN }
        assertEquals("400 m × 8", iv.name)
        assertEquals(false, iv.indoor)
    }

    @Test fun savedCardReopensSheet() {
        Store.saveProgram(Bonus.emom(120, 6))
        show(Scr.Training)
        rule.onAllNodesWithTag("training.card")[0].performClick(); rule.waitForIdle()   // 새 카드는 맨 위
        assertEquals(Kinds.EMOM, Router.bonus?.kind)
        tap("bonus.delete")
        assertTrue(Store.programs.none { it.kind == Kinds.EMOM })
    }

    // MARK: 폰 기록 엔진

    @Test fun phoneTabataRunsByItself() {
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, Bonus.tabata(20, 10, 2), Scr.Training))
        assertFalse(e.useGPS)
        e.run(17_000)
        assertEquals(3, e.warnSec())
        e.run(3_000)
        assertEquals(1, e.idx)
        e.run(30_000)
        val r = e.autoDone!!
        assertEquals(listOf(20, 10, 20), r.segs.map { it.time })
        assertEquals(Kinds.TABATA, r.kind)
    }

    @Test fun phoneEmomDoneAndResume() {
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, Bonus.emom(60, 2), Scr.Training))
        e.run(30_000)
        assertNull(e.advance())                            // "끝" — 넘기지 않음
        assertEquals(30, e.segWork[0])
        val snap = SplitsJson.decodeFromString(PhoneRunSnapshot.serializer(), SplitsJson.encodeToString(PhoneRunSnapshot.serializer(), e.snapshot()!!))
        val e2 = PhoneRunEngine { t }
        e2.restore(snap)
        t += 90_000; e2.timerTick()
        val r = e2.autoDone!!
        assertEquals(listOf(30, null), r.segs.map { it.work })
    }

    @Test fun phoneAmrapEndsAtCap() {
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, Bonus.amrap(120), Scr.Training))
        e.run(50_000); e.advance()
        e.run(70_000)
        val r = e.autoDone!!
        assertEquals(1, r.rounds)
        assertEquals(120, r.total)
        assertTrue(r.isComplete)
    }

    @Test fun phoneLiftConfirmsSets() {
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, Bonus.lift(listOf(Lift("Squat", 2, 5, 80.0)), rest = 30), Scr.Training))
        assertTrue(e.isLiftSet)
        assertEquals(5 to 80.0, e.liftPrefill())
        e.run(40_000); assertNull(e.finishSet(6, 82.5))
        e.run(30_000)
        assertEquals(6 to 82.5, e.liftPrefill())
        e.run(20_000)
        val r = e.finishSet(5, 82.5)!!
        assertEquals(listOf(6, null, 5), r.segs.map { it.reps })
        assertEquals(11 * 82.5, Bonus.volume(r), 0.01)
    }

    @Test fun phoneIvrunIndoorManualDistance() {
        val p = Bonus.ivrun(listOf(IvStep(IvStep.FAST, m = 400), IvStep(IvStep.EASY, s = 60)), 1, indoor = true)
        val e = PhoneRunEngine { t }
        e.start(PhoneRunRequest(Mode.Training, p, Scr.Training))
        assertFalse(e.useGPS)
        t += 100_000; e.advance()
        e.run(60_000)
        val r = e.autoDone!!
        assertEquals(400.0, r.segs[0].dist!!, 0.01)
        assertNull(r.segs[1].dist)
        assertEquals(true, r.indoor)
    }

    // MARK: 기록 화면

    private fun rec(kind: String, segs: List<SegResult>, extra: (Record) -> Record = { it }) = extra(Record(
        mode = Mode.Training, title = Kinds.title(kind), date = Instant.parse("2026-10-20T08:00:00Z"), total = segs.sumOf { it.time },
        segs = segs, hr = emptyList(), kcal = 120, avgHR = 0, maxHR = 0, division = "openM", vsWord = "VS BEST", kind = kind, source = "phone",
    ))

    @Test fun detailShowsEachKind() {
        val all = listOf(
            rec(Kinds.TABATA, Bonus.tabataSeq(20, 10, 2).map { SegResult(it.icon, it.name, it.detail, it.kind, it.target, it.target, rep = it.rep) }),
            rec(Kinds.EMOM, (1..3).map { SegResult("hiit", "Round $it", "EMOM", SegKind.St, 60, 60, work = 40, rep = it) }),
            rec(Kinds.AMRAP, (1..3).map { SegResult("hiit", "Round $it", "AMRAP", SegKind.St, 100, 0, rep = it) }) { it.copy(rounds = 2, cap = 300) },
            rec(Kinds.IVRUN, listOf(SegResult("run", "Fast", "400M", SegKind.Run, 90, 0, dist = 405.0, rep = 1),
                SegResult("rest", "Rest", "60S", SegKind.Rox, 60, 60, rep = 1))),
            rec(Kinds.LIFT, listOf(SegResult("lift", "Squat", "SET 1/1", SegKind.St, 40, 0, reps = 5, kg = 80.0, rep = 1))),
        )
        for (r in all) Store.add(r)
        for (r in all) {
            Router.detail = r
            show(Scr.Detail)
            rule.onNodeWithTag("detail.timePlace").assertExists()
        }
        Router.detail = all[2]; show(Scr.Detail)
        rule.onNodeWithTag("detail.amrapScore").assertExists()
        Router.detail = all[4]; show(Scr.Detail)
        rule.onNodeWithTag("detail.volume").assertExists()
    }

    @Test fun amrapExtraRepsSave() {
        val r = rec(Kinds.AMRAP, (1..3).map { SegResult("hiit", "Round $it", "AMRAP", SegKind.St, 100, 0, rep = it) }) { it.copy(rounds = 2, cap = 300) }
        Store.add(r)
        Store.updateRecord(r.copy(extra = 7))
        assertEquals(7, Store.records.first { it.id == r.id }.extra)
        assertEquals("2 rounds + 7", Bonus.amrapScore(Store.records.first { it.id == r.id }))
    }
}
