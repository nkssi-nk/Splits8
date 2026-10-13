package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.screens.ageGroup
import com.nkssi.splits8.screens.nickFiltered
import com.nkssi.splits8.shared.L10n
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

/** 가짜 서버: 코드 123456, 닉네임 "taken" 은 이미 있음 */
class FakeApi(private val existing: Boolean = false) : AccountApi {
    override val ready = true
    var sent = 0
    override suspend fun sendCode(email: String) { sent++ }
    override suspend fun verify(email: String, code: String) { if (code != "123456") throw Exception("bad") }
    override suspend fun signInGoogle(): String = "g@example.com"
    override suspend fun nicknameAvailable(nick: String) = nick != "taken"
    override suspend fun saveNickname(nick: String) { if (nick == "taken") throw NicknameTaken() }
    override suspend fun loadProfile() = if (existing) ProfileLoad.Found else ProfileLoad.None
}

/** 시작 · 가입 흐름 (가짜 서버로) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h1400dp-xxhdpi")
class SignupFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.useDemo(Settings(hasOnboarded = false), Program.presets(), emptyList())
        Router.email = ""; Router.code = ""; Router.nickDraft = ""; Router.signupFlow = false; Router.profileEdit = false
    }

    @After fun tearDown() {
        Accounts.api = NotConnected
        Router.ask = null; Router.toast = null; Router.signupFlow = false; Router.profileEdit = false
        Router.email = ""; Router.code = ""; Router.nickDraft = ""
    }

    private fun show(s: Scr) {
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun tap(tag: String) { rule.onNodeWithTag(tag).performClick(); rule.waitForIdle() }
    private fun type(tag: String, t: String) { rule.onNodeWithTag(tag).performTextInput(t); rule.waitForIdle() }

    @Test fun onboardingThreeSteps() {
        show(Scr.Splash)
        tap("splash.start")
        assertEquals(Scr.Ob1, Router.scr)
        tap("div.openW")
        assertEquals("openW", Store.settings.division)
        tap("ob.next")
        assertEquals(Scr.Ob2, Router.scr)
        val age = Store.settings.age
        tap("hr.up")
        assertEquals(age + 1, Store.settings.age)
        tap("ob.next")
        assertEquals(Scr.Ob3, Router.scr)
        // 위치를 이미 허락했다고 치면 "Start training" → 홈
        org.robolectric.Shadows.shadowOf(rule.activity.application).grantPermissions(android.Manifest.permission.ACCESS_FINE_LOCATION)
        Router.go(Scr.Ob2); rule.waitForIdle(); Router.go(Scr.Ob3); rule.waitForIdle()
        tap("ob.next")
        assertEquals(Scr.Home, Router.scr)
        assertTrue(Store.settings.hasOnboarded)
    }

    @Test fun notConnectedShowsMessage() {
        Router.toAuth(Scr.Account)
        show(Scr.Auth)
        type("auth.field", "me@example.com")
        tap("auth.email")
        rule.onNodeWithTag("error").assertTextEquals("Sign-in comes in a later Android build.")
        assertEquals(Scr.Auth, Router.scr)
    }

    @Test fun newAccountFullSignup() {
        val api = FakeApi(); Accounts.api = api
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.toAuth(Scr.Account)
        show(Scr.Auth)
        type("auth.field", "me@example.com")
        assertEquals("typed", "me@example.com", Router.email)
        tap("auth.email")
        assertEquals("after send", "me@example.com", Router.email)
        assertEquals(1, api.sent)
        assertEquals(Scr.Code, Router.scr)
        type("code.field", "123456")                         // 6자리가 차면 바로 확인
        assertEquals("after code", "me@example.com", Router.email)
        assertEquals(Scr.Nick, Router.scr)
        assertEquals("me@example.com", Store.settings.email)
        rule.onNodeWithTag("dots").assertTextEquals("1 / 5")
        type("nick.field", "Kim Nae_1!")                     // 대문자 · 띄어쓰기 · 특수문자는 걸러짐
        assertEquals("kimnae_1", Router.nickDraft)
        rule.mainClock.advanceTimeBy(400); rule.waitForIdle()
        rule.onNodeWithTag("nick.msg").assertTextEquals("@kimnae_1 is available")
        tap("nick.save")
        assertEquals("kimnae_1", Store.settings.nickname)
        assertEquals(Scr.ProfileSetup, Router.scr)
        rule.onNodeWithTag("dots").assertTextEquals("2 / 5")
        // ① 대회 경험: 나가 봤어요 + 시간 그대로 (1:20:00) → 목표 시간 기본값
        tap("profile.raced.yes")
        tap("profile.next")
        assertEquals(true, Store.settings.raced)
        assertEquals(4800, Store.settings.bestFinish)
        assertEquals(4800, Store.settings.goalTime)
        // ② 내 디비전: Doubles Mixed → 본인 성별
        rule.onNodeWithTag("dots").assertTextEquals("3 / 5")
        tap("profile.div.dblX"); tap("profile.mixedSex")
        tap("profile.next")
        assertEquals("dblX", Store.settings.division)
        // ③ 태어난 해 (기본 1990) → 나이도 맞춤
        tap("profile.next")
        assertEquals(1990, Store.settings.birthYear)
        assertEquals(java.time.Year.now().value - 1990, Store.settings.age)
        // ④ 키 · 몸무게
        rule.onNodeWithTag("dots").assertTextEquals("5 / 5")
        tap("profile.next")
        assertEquals(true, Store.settings.profileDone)
        assertEquals(Scr.Account, Router.scr)
        assertTrue(!Router.signupFlow)
    }

    @Test fun takenNickname() {
        Accounts.api = FakeApi()
        Router.signupFlow = true
        show(Scr.Nick)
        type("nick.field", "taken")
        rule.mainClock.advanceTimeBy(400); rule.waitForIdle()
        rule.onNodeWithTag("nick.msg").assertTextEquals("@taken is taken")
    }

    @Test fun notRacedRecommendsAndSkipToasts() {
        Router.startProfile(Scr.Home)
        show(Scr.ProfileSetup)
        rule.onNodeWithTag("dots").assertTextEquals("1 / 4")      // 닉네임 없는 흐름
        tap("profile.raced.no")
        tap("profile.next")
        rule.onNodeWithTag("profile.recommend").assertExists()
        tap("profile.skip")                                       // 디비전 건너뛰기
        assertNotNull(Router.toast)
        rule.onNodeWithTag("dots").assertTextEquals("3 / 4")
        tap("profile.skip"); tap("profile.skip")
        assertEquals(Scr.Home, Router.scr)
        assertEquals(true, Store.settings.profileDone)
        assertNull(Store.settings.bestFinish)
    }

    @Test fun existingAccountSkipsNick() {
        Accounts.api = FakeApi(existing = true)
        Store.useDemo(Settings(hasOnboarded = true, profileDone = true), Program.presets(), emptyList())
        Router.toAuth(Scr.Settings, "signin")
        show(Scr.Auth)
        tap("auth.google")
        assertEquals(Scr.Settings, Router.scr)
        assertEquals("Google", Store.settings.signMethod)
    }

    @Test fun editFromProfile() {
        show(Scr.Account)
        tap("profile.about.race")
        assertEquals(Scr.ProfileSetup, Router.scr)
        tap("profile.raced.no")
        tap("profile.next")                                       // 고치는 중: 저장하고 프로필로
        assertEquals(Scr.Account, Router.scr)
        assertEquals(false, Store.settings.raced)
    }

    @Test fun emailTypingOnce() {
        Router.email = ""
        Router.toAuth(Scr.Account)
        show(Scr.Auth)
        assertEquals("", Router.email)
        type("auth.field", "ab@cd.ef")
        assertEquals("ab@cd.ef", Router.email)
    }

    @Test fun helpers() {
        assertEquals("abc_12", nickFiltered("AbC _1-2"))
        assertEquals(16, nickFiltered("a".repeat(30)).length)
        assertEquals("35–39", ageGroup(1990, 2026))
        assertEquals("16–24", ageGroup(2005, 2026))
        assertEquals("70+", ageGroup(1950, 2026))
    }
}
