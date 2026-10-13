package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performImeAction
import androidx.compose.ui.test.performTextInput
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.screens.insightStyled
import com.nkssi.splits8.screens.partnerColor
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 기록 상세 화면 (지우기 · 파트너 · 카드가 기록 종류에 맞게 나오는지) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h4200dp-xxhdpi")
class DetailFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        val now = java.time.Instant.parse("2026-10-05T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(),
            req = Demo.requests(), me = "demo.me")
    }

    @After fun tearDown() {
        Router.ask = null; Router.partnerFor = null; Router.detail = null; Router.toast = null
    }

    private fun open(r: Record, from: Scr = Scr.Race) {
        Router.open(r, from)
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    private val race: Record get() = Store.records.first { it.title == "Incheon" }

    @Test fun deleteAsksThenGoesBack() {
        open(race)
        tap("detail.delete")
        tap("ask.cancel")
        assertNotNull(Store.records.firstOrNull { it.title == "Incheon" })
        tap("detail.delete")
        tap("ask.ok")
        assertNull(Store.records.firstOrNull { it.title == "Incheon" })
        assertEquals(Scr.Race, Router.scr)
    }

    @Test fun backLinkGoesWhereItCameFrom() {
        open(Store.records.first { it.mode == Mode.Sim }, Scr.Sim)
        tap("back")
        assertEquals(Scr.Sim, Router.scr)
    }

    @Test fun raceShowsBenchAndInsights() {
        open(race)
        rule.onNodeWithTag("detail.insights").assertExists()
        rule.onNodeWithTag("detail.bench").assertExists()
        rule.onNodeWithTag("detail.hr").assertExists()
        rule.onNodeWithTag("detail.route").assertDoesNotExist()
    }

    @Test fun runShowsRouteElevationLaps() {
        open(Store.records.first { it.isRunKind }, Scr.Training)
        rule.onNodeWithTag("detail.route").assertExists()
        rule.onNodeWithTag("detail.elevation").assertExists()
        rule.onNodeWithTag("detail.laps").assertExists()
        rule.onNodeWithTag("detail.bench").assertDoesNotExist()
    }

    @Test fun pftShowsGradeCard() {
        open(Store.records.first { it.mode == Mode.Pft }, Scr.Sim)
        rule.onNodeWithTag("detail.pft").assertExists()
        rule.onNodeWithTag("detail.pace").assertDoesNotExist()
    }

    @Test fun typePartnerThenRemove() {
        // 개인 기록에 파트너 줄은 없음 → 기록을 더블로 바꿔서 확인
        val r = race.copy(division = "dblX")
        Store.useDemo(Store.settings, Store.programs, Store.records.map { if (it.id == r.id) r else it }, Store.friends, me = "demo.me")
        open(r)
        tap("detail.partner")
        tap("partner.type")
        rule.onNodeWithTag("partner.field").performTextInput("@yuna ")
        rule.onNodeWithTag("partner.field").performImeAction()
        rule.waitForIdle()
        assertEquals("yuna", Store.records.first { it.id == r.id }.partner)
        assertNull(Router.partnerFor)
        tap("detail.partner")
        tap("partner.remove")
        assertNull(Store.records.first { it.id == r.id }.partner)
    }

    @Test fun shareOpensShareScreen() {
        open(race)
        tap("Share with photo")
        assertEquals(Scr.Share, Router.scr)
    }

    @Test fun styledAndColors() {
        val s = insightStyled("Ahead until [y]SkiErg[/y], then [r]+2:13[/r].")
        assertEquals("Ahead until SkiErg, then +2:13.", s.text)
        assertEquals(2, s.spanStyles.size)
        assertFalse(s.text.contains("["))
        assertEquals(partnerColor("Minji"), partnerColor("minji"))
    }
}
