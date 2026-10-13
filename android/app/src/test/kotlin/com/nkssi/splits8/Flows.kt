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
import com.nkssi.splits8.Demo
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
        Router.ask = null; Router.bonus = null; Router.planRequest = null; Router.editId = null; Router.testInfo = null
        Router.testTab = "pft"; Router.raceSheet = null; Router.evDraft = null
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

    @Test fun testTabSwitchAndSettings() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(), me = "demo.me")
        Router.testTab = "pft"
        show(Scr.Sim)
        rule.onNodeWithTag("pft.best").assertExists()
        tap("test.seg.sim")
        assertEquals("sim", Router.testTab)
        rule.onNodeWithTag("predict.card").assertExists()
        rule.onNodeWithTag("sim.fatigue").assertExists()
        val before = Store.settings.roxAuto
        tap("sim.rox")
        assertEquals(!before, Store.settings.roxAuto)
        tap("sim.metric.run")                              // 칩 바꾸기 (오류 없이)
        tap("sim.info")
        assertEquals("sim", Router.testInfo)
        assertTrue(Router.back())
        assertNull(Router.testInfo)
        tap("sim.division")
        assertEquals(Scr.SetDiv, Router.scr)
        assertEquals(Scr.Sim, Router.subFrom)
    }

    @Test fun pftEmptyStartAsks() {
        Router.testTab = "pft"
        show(Scr.Sim)
        rule.onNodeWithTag("pft.about").assertExists()
        tap("startOnPhone.pft")
        assertEquals("Start on phone?", Router.ask?.title)
    }

    @Test fun pftScalePositions() {
        assertEquals(0f, com.nkssi.splits8.screens.pftPos(12 * 60), 0.001f)
        assertEquals(0.44f, com.nkssi.splits8.screens.pftPos(22 * 60), 0.001f)
        assertEquals(0.70f, com.nkssi.splits8.screens.pftPos(26 * 60), 0.001f)
        assertEquals(1f, com.nkssi.splits8.screens.pftPos(40 * 60), 0.001f)
    }

    private fun useRaceDemo() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(), me = "demo.me")
    }

    @Test fun findEventFillsDraftAndSaves() {
        useRaceDemo()
        show(Scr.Race)
        tap("race.Event")
        assertEquals(Scr.SetEvent, Router.scr)
        tap("ev.find")
        assertEquals(Scr.FindEvent, Router.scr)
        tap("ev.region.korea")
        tap("ev.item.Seoul")
        assertEquals(Scr.SetEvent, Router.scr)
        assertEquals("Seoul", Router.evDraft?.name)
        tap("ev.Start time"); tap("ev.h.9"); tap("ev.m.30")
        assertEquals("09:30", Router.evDraft?.time)
        tap("nav.right")
        assertEquals(Scr.Race, Router.scr)
        assertEquals("Seoul", Store.settings.event.name)
        assertEquals("09:30", Store.settings.event.time)
        assertEquals(java.time.LocalDate.of(2026, 11, 13), Store.settings.event.date.atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate())
        assertNull(Router.evDraft)
    }

    @Test fun cancelEventKeepsOld() {
        useRaceDemo()
        val old = Store.settings.event
        Router.evDraft = null
        show(Scr.SetEvent)
        tap("ev.find"); tap("ev.item.Shanghai")
        tap("nav.left")
        assertEquals(Scr.Race, Router.scr)
        assertEquals(old, Store.settings.event)
    }

    @Test fun goalTimeSplitsGoals() {
        useRaceDemo()
        show(Scr.Race)
        tap("race.Goal time")
        assertEquals("goal", Router.raceSheet)
        tap("nav.right")                                    // 같은 시간 · "Current" 방식으로 저장
        assertNull(Router.raceSheet)
        val s = Store.settings
        assertEquals(4320, s.goalTime)
        assertEquals(16, s.goals.size)
        assertTrue(kotlin.math.abs(s.goals.sum() - (s.goalTime - 8 * s.roxTarget)) <= 5)   // 5초 단위로 반올림
        assertTrue(s.goals.all { it % 5 == 0 && it >= 30 })
    }

    @Test fun splitGoalsStep() {
        useRaceDemo()
        show(Scr.Race)
        tap("race.splitTargets")
        assertEquals(Scr.SetGoals, Router.scr)
        val before = Store.settings.goals[0]
        changeGoalViaUi()
        assertEquals(before + 5, Store.settings.goals[0])
        assertEquals(Store.settings.goals.sum() + 8 * Store.settings.roxTarget, Store.settings.goalTime)
        assertTrue(Router.back())                           // ‹ Race
        assertEquals(Scr.Race, Router.scr)
    }

    private fun changeGoalViaUi() {
        com.nkssi.splits8.screens.changeGoal(0, 5); rule.waitForIdle()
    }

    @Test fun doublesPlanOnlyForDoubles() {
        useRaceDemo()
        show(Scr.Race)
        rule.onAllNodesWithTag("race.Doubles plan").fetchSemanticsNodes().let { assertTrue(it.isEmpty()) }
        Store.update { it.copy(division = "dblM") }
        rule.waitForIdle()
        tap("race.Doubles plan")
        assertEquals("doubles", Router.raceSheet)
        tap("nav.right")                                    // 반반 그대로 저장 → 비워 둠
        assertNull(Store.settings.doublesPlan)
    }

    @Test fun settingsToggles() {
        show(Scr.Settings)
        tap("settings.hapticZone")
        assertEquals(false, Store.settings.hapticZone)
        tap("settings.mirror")
        assertEquals(false, Store.settings.mirror)
        tap("settings.theme.blue")
        assertEquals(com.nkssi.splits8.shared.GlowTheme.Blue, Store.settings.glow)
        tap("settings.theme.yellow")
        assertNull(Store.settings.themeOpt)                // 노랑이면 비워 둠 (아이폰 파일과 같게)
    }

    @Test fun languageAppliesRightAway() {
        show(Scr.Settings)
        Store.update { it.copy(lang = "ko") }
        rule.waitForIdle()
        assertTrue(L10n.isKorean)
        Store.update { it.copy(lang = "en") }
        rule.waitForIdle()
        assertTrue(!L10n.isKorean)
    }

    @Test fun divisionHrRunScreens() {
        show(Scr.Settings)
        tap("settings.profile")
        assertEquals(Scr.Account, Router.scr)
        tap("profile.division")                             // 프로필의 Division = 가입 프로필 "내 디비전" (빌드 24)
        assertEquals(Scr.ProfileSetup, Router.scr)
        tap("profile.div.proW"); tap("profile.next")
        assertEquals("proW", Store.settings.division)
        assertEquals(Scr.Account, Router.scr)
        Router.sub(Scr.SetDiv, Scr.Account); rule.waitForIdle()   // 레이스 · 풀 시뮬에서 여는 Division 목록
        tap("div.openW")
        assertEquals("openW", Store.settings.division)
        assertTrue(Router.back())                           // ‹ Profile
        assertEquals(Scr.Account, Router.scr)
        tap("profile.hr")
        assertEquals(Scr.SetHr, Router.scr)
        val age = Store.settings.age
        rule.onNodeWithTag("hr.stepper").assertExists()
        Store.update { it.copy(hrMode = "manual", manualHr = 190) }; rule.waitForIdle()
        assertEquals(190, Store.settings.maxHR)
        Store.update { it.copy(hrMode = "age", age = age) }
        Router.go(Scr.SetRun); rule.waitForIdle()
        tap("run.outdoor")
        assertEquals("outdoor", Store.settings.runMode)
    }

    @Test fun backupRoundTrip() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        val recs = Demo.records(o)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), recs, Demo.friends(), me = "demo.me")
        val json = Store.backupJson()
        assertTrue(json.contains("\"app\":\"SPLITS8\""))
        // 기록이 없는 폰에 가져오기 → 전부 들어옴, 다시 가져오면 0
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        assertEquals(L10n.t("Restored %lld records and %lld trainings.", recs.size, 1), com.nkssi.splits8.screens.restoreMessage(json))
        assertEquals(recs.size, Store.records.size)
        assertEquals("Nothing new to restore. Everything in this file is already here.", com.nkssi.splits8.screens.restoreMessage(json))
        assertEquals("This file isn't a SPLITS8 backup.", com.nkssi.splits8.screens.restoreMessage("{\"app\":\"OTHER\"}"))
    }

    @Test fun signOutKeepsRecords() {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(), me = "demo.me")
        val n = Store.records.size
        show(Scr.Settings)
        tap("settings.signout")
        tap("ask.ok")
        assertTrue(!Store.signedIn)
        assertEquals(n, Store.records.size)
        assertTrue(Store.friends.isEmpty())
    }

    @Test fun backClosesSheetFirst() {
        Router.bonus = BonusRequest("hiit")
        show(Scr.Training)
        assertTrue(Router.back())
        assertNull(Router.bonus)
        assertEquals(Scr.Training, Router.scr)
    }
}
