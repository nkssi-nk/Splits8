package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.captureToImage
import com.nkssi.splits8.screens.PosterLayout
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.screens.ShareData
import com.nkssi.splits8.screens.ShareDebug
import com.nkssi.splits8.screens.movedLayout
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 공유 화면 (그림 크기 · 옵션 · 글자 덩어리 옮기기 · 카드 값) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
class ShareFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        val now = java.time.Instant.parse("2026-10-05T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(), me = "demo.me")
        ShareDebug.dryRun = true
        ShareDebug.last = null
    }

    @After fun tearDown() {
        ShareDebug.dryRun = false; ShareDebug.last = null
        Router.detail = null; Router.ask = null
    }

    private val race: Record get() = Store.records.first { it.title == "Incheon" }

    private fun open(r: Record) {
        Router.detail = r
        Router.scr = Scr.Share
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    /** 시험 화면은 그려야 할 때만 그려서, 저장 버튼 전에 한 번 그리게 함 (폰에서는 늘 그려져 있음) */
    private fun tap(tag: String) {
        rule.onRoot().captureToImage()
        rule.onNodeWithTag(tag).performClick(); rule.waitForIdle()
    }

    @Test fun storeImageIs1080x1920() {
        open(race)
        tap("share.save")
        val b = ShareDebug.last
        assertNotNull(b)
        assertEquals(1080, b!!.width)
        assertEquals(1920, b.height)
        rule.onNodeWithText("Saved").assertExists()
    }

    @Test fun postImageIs1080x1350() {
        open(race)
        rule.onNodeWithText("Post 4:5").performClick(); rule.waitForIdle()
        tap("Block")
        tap("share.instagram")
        assertEquals(1350, ShareDebug.last!!.height)
    }

    @Test fun closeGoesBackToDetail() {
        open(race)
        tap("nav.left")
        assertEquals(Scr.Detail, Router.scr)
    }

    @Test fun routeMapOnlyForOutdoorRun() {
        open(race)
        rule.onNodeWithTag("share.map").assertDoesNotExist()
    }

    @Test fun routeMapToggle() {
        open(Store.records.first { it.isRunKind })
        tap("share.map")
        tap("share.save")
        assertNotNull(ShareDebug.last)
    }

    @Test fun movingBlocksSnapsToNearestSpot() {
        val l = PosterLayout()
        val time = Rect(22f, 300f, 338f, 420f)                       // 가운데 y 360
        // 위로 끌어 올리면 맨 위, 오른쪽으로 많이 밀면 오른쪽 정렬
        val up = movedLayout(l, "time", time, Offset(150f, -300f), 640f)
        assertEquals(0, up.time); assertEquals(2, up.timeAlign)
        // 조금만 움직이면 가운데
        assertEquals(1, movedLayout(l, "table", Rect(22f, 400f, 338f, 600f), Offset(0f, -150f), 640f).table)
        // 로고는 위 · 아래 둘 중 하나
        assertEquals(2, movedLayout(l, "head", Rect(22f, 22f, 338f, 60f), Offset(0f, 500f), 640f).head)
    }

    @Test fun cardValues() {
        val d = ShareData.of(race)
        assertEquals("13 Sep 2026", d.date)
        assertEquals("Race · Open Men", d.badge)
        assertEquals(8, d.pairs.size)
        assertEquals("Farmers", d.pairs[5].sn)
        assertEquals("50M · 152KG", d.pairs[1].spec)
        assertEquals("1,042", d.kcal)
        assertEquals("--", ShareData.kcalText(0))
        assertEquals("100 REPS · 6KG", ShareData.spec("100 REPS · 6KG · shared"))
    }
}
