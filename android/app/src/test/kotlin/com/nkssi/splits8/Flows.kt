package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PlanReminder
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
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

/** 트레이닝 탭 동작 (누르기 → 저장 결과). 화면 사진 없이 결과만 확인 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
class Flows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
    }

    @After fun tearDown() {
        Router.ask = null; Router.bonus = null; Router.planRequest = null; Router.editId = null
    }

    private fun show(s: Scr) {
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    @Test fun newTrainingStartsFullAndSavesOnTop() {
        show(Scr.Training)
        tap("training.new")
        assertEquals(Scr.Builder, Router.scr)
        assertEquals(16, Router.draftSeq.size)
        tap("builder.st.skiErg")                          // 꽉 차서 안 들어감
        assertEquals(16, Router.draftSeq.size)
        tap("builder.clear")
        tap("builder.run.400M"); tap("builder.st.wallBalls"); tap("builder.st.wallBalls")
        assertEquals(listOf("run", "wallBalls", "wallBalls"), Router.draftSeq.map { it.icon })
        tap("builder.remove.1")
        assertEquals(listOf("run", "wallBalls"), Router.draftSeq.map { it.icon })
        tap("nav.right")                                   // Save
        assertEquals(Scr.Training, Router.scr)
        val p = Store.programs.first()                     // 새것은 맨 위
        assertEquals("Training 3", p.name)
        assertEquals("400M", p.seq[0].run)
    }

    @Test fun cancelKeepsList() {
        show(Scr.Training)
        tap("training.new"); tap("builder.clear"); tap("nav.left")
        assertEquals(Scr.Training, Router.scr)
        assertEquals(2, Store.programs.size)
    }

    @Test fun limitShowsAlert() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets() + Program.presets().map { it.copy(id = it.id + "a") } +
            Program.hiit(), emptyList())
        show(Scr.Training)
        tap("training.new")
        assertEquals(Scr.Training, Router.scr)
        assertNotNull(Router.ask)
        tap("ask.ok")
        assertNull(Router.ask)
    }

    @Test fun runSheetSavesAndReopens() {
        show(Scr.Training)
        tap("training.new"); tap("builder.bonus.run")
        tap("bonus.km.10"); tap("bonus.save")
        assertEquals(Scr.Training, Router.scr)
        val p = Store.programs.first()
        assertTrue(p.isRun); assertEquals(10, p.runKm); assertEquals(false, p.indoor)
        rule.onAllNodesWithTag("training.card")[0].performClick(); rule.waitForIdle()   // 저장된 러닝 카드 → 시트
        assertEquals(p.id, Router.bonus?.existing?.id)
        tap("bonus.delete")
        assertTrue(Store.programs.none { it.id == p.id })
    }

    @Test fun editTraining() {
        show(Scr.Training)
        rule.onAllNodesWithTag("training.card")[0].performClick(); rule.waitForIdle()
        assertEquals(Scr.Builder, Router.scr)
        assertEquals("p1", Router.editId)
        tap("builder.delete")
        assertEquals(listOf("p2"), Store.programs.map { it.id })
    }

    @Test fun planFromCalendar() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        Router.openPlan(java.time.LocalDate.of(2026, 9, 27).atStartOfDay(com.nkssi.splits8.shared.Fm.zone).toInstant())
        show(Scr.Home)
        tap("plan.reminder.HourBefore")
        tap("nav.right")
        assertNull(Router.planRequest)
        val p = Store.plans.single()
        assertEquals(Mode.Training, p.mode)
        assertEquals("p1", p.programId)
        assertEquals("Sled Intervals", p.title)
        assertEquals(PlanReminder.HourBefore, p.reminder)
        val z = p.date.atZone(com.nkssi.splits8.shared.Fm.zone)
        assertEquals(27, z.dayOfMonth); assertEquals(7, z.hour)       // 날짜만 고르면 오전 7시
        // 다시 열어 지우기
        Router.openPlan(p.date, p.mode, p); rule.waitForIdle()
        tap("plan.delete")
        assertTrue(Store.plans.isEmpty())
    }

    @Test fun backClosesSheetFirst() {
        Router.bonus = BonusRequest("hiit")
        show(Scr.Training)
        assertTrue(Router.back())
        assertNull(Router.bonus)
        assertEquals(Scr.Training, Router.scr)
    }
}
