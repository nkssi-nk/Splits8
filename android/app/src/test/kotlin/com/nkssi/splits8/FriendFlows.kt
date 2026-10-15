package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.screens.friendQuery
import com.nkssi.splits8.screens.friendSearchable
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 친구 화면 (가짜 서버로) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h1800dp-xxhdpi")
class FriendFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private val api = FakeApi()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(), req = Demo.requests(), me = "demo.me")
        Store.requested = emptySet()
        Accounts.api = api
    }

    @After fun tearDown() {
        Accounts.api = NotConnected
        Router.ask = null; Router.userMenu = null
    }

    private fun show() {
        Router.scr = Scr.Friends
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }

    private fun search(t: String) {
        rule.onNode(hasSetTextAction() and hasAnyAncestor(hasTestTag("friends.search"))).performTextInput(t)
        rule.mainClock.advanceTimeBy(700); rule.waitForIdle()
    }

    @Test fun searchAndAdd() {
        show()
        search("@MinJi")                                   // @ · 대문자도 찾아짐
        rule.onNodeWithTag("friends.hit").assertExists()
        tap("friends.add")
        assertTrue("u.minji" in Store.requested)
    }

    @Test fun searchNoneAndError() {
        show()
        search("nobody_here")
        rule.onNodeWithTag("friends.none").assertExists()
    }

    @Test fun searchMyselfIsHidden() {
        show()
        search("me_myself")
        rule.onNodeWithTag("friends.none").assertExists()
    }

    @Test fun acceptAndDecline() {
        show()
        val before = Store.friends.size
        tap("friends.accept")                              // hana 수락
        assertEquals(before + 1, Store.friends.size)
        assertTrue(Store.incoming.isEmpty())
        tap("friends.cancelRequest")                       // woojin 에게 보낸 요청 취소
        assertTrue(Store.outgoing.isEmpty())
    }

    @Test fun tenFriendLimit() {
        val many = (1..10).map { Friend("f$it", "friend$it", "Open Men", "", emptyList()) }
        Store.useDemo(Store.settings, Store.programs, Store.records, many, req = Demo.requests(), me = "demo.me")
        show()
        // 빌드 24: 수락된 친구 10 + 보낸 요청 1 (woojin) = 11 — 아이폰 · 서버와 같은 셈
        rule.onNodeWithTag("friends.count").assertTextEquals("11 / 10")
        tap("friends.accept")
        assertEquals("You can add up to 10 friends", Router.ask?.title)
        assertEquals("Remove a friend or cancel a request to add someone new.", Router.ask?.message)
        assertEquals(10, Store.friends.size)
        assertTrue(Store.incoming.isNotEmpty())            // 거절된 게 아니라 그대로 남음
    }

    @Test fun selectFriendThenBlock() {
        show()
        val f = Store.friends.first { it.hasSplits }
        tap("friend." + f.name)
        assertEquals(f.id, Store.settings.friendId)
        tap("friend." + f.name)                            // 다시 누르면 풂
        assertNull(Store.settings.friendId)
        tap("friend." + f.name)
        Router.userMenu = com.nkssi.splits8.shared.BlockedUser(f.id, f.name); rule.waitForIdle()
        tap("menu.block")
        tap("ask.ok")
        assertTrue(Store.friends.none { it.id == f.id })
        assertNull(Store.settings.friendId)               // 고른 친구였으면 풀림
        assertTrue(Store.isBlocked(f.id))
        tap("friends.unblock")
        assertTrue(!Store.isBlocked(f.id))
    }

    @Test fun guestSeesSignUp() {
        Store.signOut()
        show()
        tap("friends.signup")
        assertEquals(Scr.Auth, Router.scr)
        assertEquals(Scr.Friends, Router.authReturn)
    }

    @Test fun queryHelpers() {
        assertEquals("jiho", friendQuery("  @JiHo "))
        assertEquals("a@b.co", friendQuery("A@B.co"))
        assertTrue(friendSearchable("a@b.co"))
        assertTrue(friendSearchable("abc"))
        assertTrue(!friendSearchable("ab"))
        assertTrue(!friendSearchable("abc@"))
    }
}
