package com.nkssi.splits8

import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** 서버 (Supabase) 와 맞추기 — 가짜 인터넷으로 (실제 서버에 가지 않음) */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ServerFlows {
    /** 주소(앞부분) → (HTTP 번호, 응답) */
    private val routes = LinkedHashMap<String, (HttpReq) -> HttpResp>()
    private val log = ArrayList<HttpReq>()
    private var t = 1_790_000_000_000L

    private fun on(path: String, code: Int = 200, body: String = "") { routes[path] = { HttpResp(code, body.toByteArray()) } }
    private fun sent(path: String): List<HttpReq> = log.filter { it.url.removePrefix(Supabase.base).startsWith(path) }
    private fun bodyOf(r: HttpReq) = Json.parseToJsonElement(String(r.body!!)).jsonObject

    private val sessionJson = """{"access_token":"AT","refresh_token":"RT","expires_in":3600,"user":{"id":"u.me","email":"me@example.com"}}"""

    @Before fun setUp() {
        Store.resetForTest(ApplicationProvider.getApplicationContext())
        Supabase.now = { t }
        Supabase.http = { r ->
            log += r
            val path = r.url.removePrefix(Supabase.base)
            val h = routes.entries.lastOrNull { path.startsWith(it.key) }?.value
            h?.invoke(r) ?: HttpResp(200, "[]".toByteArray())
        }
        Store.setPref("session.device.v1", ""); Cloud.signedOutElsewhere = false
    }

    @After fun tearDown() {
        Supabase.session = null
        Supabase.now = { System.currentTimeMillis() }
    }

    private fun signIn() = runBlocking {
        on("/auth/v1/verify", body = sessionJson)
        Supabase.verify("me@example.com", "123456")
    }

    @Test fun codeLoginKeepsSessionAndSendsKey() = runBlocking {
        Supabase.sendCode("me@example.com")
        val r = sent("/auth/v1/otp").single()
        assertEquals("me@example.com", bodyOf(r)["email"]!!.jsonPrimitive.content)
        assertEquals(com.nkssi.splits8.Config.supabaseAnonKey, r.headers["apikey"])
        signIn()
        assertEquals("u.me", Supabase.userId)
        // 앱을 다시 켜도 로그인 유지 (파일에 저장됨)
        assertTrue(Store.pref("sb.session", "").contains("\"RT\""))
    }

    @Test fun wrongCodeIsAnError() = runBlocking {
        on("/auth/v1/verify", 403, """{"msg":"Token has expired or is invalid"}""")
        val e = runCatching { Supabase.verify("me@example.com", "000000") }.exceptionOrNull() as ServerError
        assertEquals(403, e.code)
        assertNull(Supabase.session)
    }

    @Test fun refreshesTokenBeforeItExpires() = runBlocking {
        signIn()
        on("/auth/v1/token?grant_type=refresh_token", body = sessionJson.replace("\"AT\"", "\"AT2\""))
        t += 3_570_000                                   // 59.5분 뒤 (남은 시간 1분 미만)
        Supabase.friends()
        assertEquals(1, sent("/auth/v1/token").size)
        assertEquals("Bearer AT2", sent("/rest/v1/rpc/friends_with_best").last().headers["Authorization"])
    }

    @Test fun profileFoundIsApplied() = runBlocking {
        signIn()
        on("/rest/v1/profiles?id=eq.u.me", body = """[{"id":"u.me","nickname":"nkssi","division":"Pro Men","visibility":"friends"}]""")
        assertEquals(ProfileLoad.Found, Cloud.loadProfile())
        assertEquals("nkssi", Store.settings.nickname)
        assertEquals("proM", Store.settings.division)
        assertTrue(Store.signedIn)
        assertEquals(1, sent("/rest/v1/rpc/claim_device").size)      // 이 기기를 "지금 기기"로
    }

    @Test fun noNicknameMeansNewAccount() = runBlocking {
        signIn()
        on("/rest/v1/profiles?id=eq.u.me", body = "[]")
        assertEquals(ProfileLoad.None, Cloud.loadProfile())
    }

    @Test fun readFailureIsNotNewAccount() = runBlocking {
        signIn()
        on("/rest/v1/profiles?id=eq.u.me", 0, "offline")
        assertEquals(ProfileLoad.Failed, Cloud.loadProfile())
        assertEquals(2, sent("/rest/v1/profiles?id=eq.u.me").size)   // 한 번 더 해 봄
    }

    @Test fun takenNicknameIsReported() = runBlocking {
        signIn()
        on("/rest/v1/profiles", 409, """{"code":"23505","message":"duplicate key value violates unique constraint"}""")
        assertTrue(runCatching { Cloud.saveNickname("taken") }.exceptionOrNull() is NicknameTaken)
    }

    @Test fun friendsAndRequestsAreSorted() {
        val rows = listOf(
            FriendRow("a", "jiho", "Open Men", null, "2026-09-20", List(16) { 250 }, "accepted", null),
            FriendRow("b", "hana", "Open Women", null, null, null, "pending", null),
            FriendRow("c", "woojin", "Pro Men", null, null, null, "pending", null),
            FriendRow("a", "jiho", "Open Men", null, null, null, "pending", null),       // 같은 사람 두 줄
            FriendRow("x", "blocked", "Open Men", null, null, null, "accepted", null),
        )
        val links = listOf(FriendLink("b", "me", "pending"), FriendLink("me", "c", "pending"))
        val (fs, rq) = Cloud.mergeFriends(rows, links, "me") { it == "x" }
        assertEquals(listOf("jiho"), fs.map { it.name })
        assertEquals(16, fs[0].splits.size)
        assertTrue(rq.first { it.id == "b" }.incoming)       // 받은 요청
        assertFalse(rq.first { it.id == "c" }.incoming)      // 보낸 요청
    }

    @Test fun recordsUploadOnlyFinishedNonPft() = runBlocking {
        signIn()
        Store.update { it.copy(nickname = "nkssi") }
        val sim = Demo.records().first { it.mode == Mode.Sim }
        Store.add(sim)
        val up = sent("/rest/v1/records").single()
        val b = bodyOf(up)
        assertEquals(sim.id.lowercase(), b["id"]!!.jsonPrimitive.content)
        assertEquals("sim", b["mode"]!!.jsonPrimitive.content)
        assertEquals(16, b["splits"]!!.jsonArray.size)
        Store.add(Demo.records().first { it.mode == Mode.Pft })               // PFT 는 올리지 않음
        Store.add(sim.copy(id = "x1", complete = false))                      // 미완료도 안 올림
        assertEquals(1, sent("/rest/v1/records").size)
        Store.delete(sim)
        assertEquals("DELETE", sent("/rest/v1/records?id=eq.").last().method)
    }

    @Test fun otherDeviceSignInLogsThisOneOut() = runBlocking {
        signIn()
        on("/rest/v1/profiles?id=eq.u.me", body = """[{"id":"u.me","nickname":"nkssi","division":"Open Men"}]""")
        Cloud.loadProfile()
        assertTrue(Store.signedIn)
        on("/rest/v1/rpc/active_device", body = "\"" + Store.pref("session.device.v1", "") + "\"")
        Cloud.checkDevice()
        assertTrue(Store.signedIn)                            // 같은 기기 → 그대로
        on("/rest/v1/rpc/active_device", body = "\"other-phone\"")
        Cloud.checkDevice()
        assertFalse(Store.signedIn)
        assertNull(Supabase.session)
        assertTrue(Cloud.signedOutElsewhere)
        assertTrue(sent("/auth/v1/logout").isEmpty())          // 서버 로그아웃은 보내지 않음 (새 기기까지 끊기지 않게)
    }

    @Test fun findUserFallsBackToNickname() = runBlocking {
        signIn()
        on("/rest/v1/rpc/find_user", 404, """{"message":"not found"}""")
        on("/rest/v1/profiles?nickname=eq.minji", body = """[{"id":"u.minji","nickname":"minji","division":"Open Women"}]""")
        assertEquals("u.minji", Supabase.findUser("MinJi ")?.id)
        assertNull(Supabase.findUser("minji@example.com"))     // 이메일은 서버 함수가 있어야 찾음
    }

    @Test fun signOutClearsAccountButKeepsRecords() = runBlocking {
        signIn()
        Store.update { it.copy(nickname = "nkssi") }
        Store.add(Demo.records().first())
        Store.signOut()
        assertFalse(Store.signedIn)
        assertNull(Supabase.session)
        assertEquals(1, Store.records.size)
        assertNotNull(sent("/auth/v1/logout").singleOrNull())
    }
}
