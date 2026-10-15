package com.nkssi.splits8

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.net.HttpURLConnection
import java.net.URL

/** 서버 설정 (아이폰 Config.swift 와 같은 서버 — 아이폰 ↔ 안드로이드 친구 · 순위표가 이어짐) */
object Config {
    const val supabaseURL = "https://hzkixqmtpillcaqsouwr.supabase.co"
    const val supabaseAnonKey = "sb_publishable_U2rt8t0plmtMDsE-KLb4Pw_Ku0JLOno"
    /**
     * 구글 로그인용 "웹 클라이언트 ID" (Google Cloud → API 및 서비스 → 사용자 인증 정보, Supabase 의 Google 공급자에 넣은 것과 같은 값).
     * 비어 있으면 구글 로그인 단추가 "아직 준비 중" 안내를 띄움
     */
    const val googleWebClientId = ""
    const val supportEmail = "nkssi1981@gmail.com"
    val hasSupabase: Boolean get() = supabaseURL.isNotEmpty() && supabaseAnonKey.isNotEmpty()
    /** 구글 지도를 쓸지 (키가 있고, 컴퓨터 시험(Robolectric)이 아닐 때). 아니면 지도 없이 경로만 그림 */
    val hasMaps: Boolean get() = BuildConfig.MAPS_KEY.isNotEmpty() && android.os.Build.FINGERPRINT != "robolectric"
}

@Serializable
data class SbSession(val accessToken: String, val refreshToken: String, val userId: String, val email: String? = null, val expiresAt: Long)

/** 서버 응답 (code = HTTP 번호, 0 = 연결 실패) */
class ServerError(val code: Int, message: String) : Exception(
    if (code == 0) com.nkssi.splits8.shared.L10n.t("Couldn't reach the server. Check your connection.")
    else com.nkssi.splits8.shared.L10n.t("Server error %lld: %@", code, message),
)

/** 인터넷 요청 하나 (시험에서는 가짜로 바꿔 끼움) */
data class HttpReq(val method: String, val url: String, val headers: Map<String, String>, val body: ByteArray?)
data class HttpResp(val code: Int, val body: ByteArray)

/** 본인만 보는 프로필 (profile_private 표) */
data class PrivateProfile(
    val sex: String? = null, val heightCm: Int? = null, val weightKg: Double? = null, val birthYear: Int? = null,
    val raced: Boolean? = null, val raceDivision: String? = null,
)

/** friends_with_best 한 줄 */
data class FriendRow(
    val userId: String, val nickname: String, val division: String, val avatarUrl: String?, val bestDate: String?,
    val splits: List<Int>?, val status: String, val direction: String?,
)

data class FriendLink(val requester: String, val addressee: String, val status: String)

/**
 * Supabase (REST · 별도 라이브러리 없이). 아이폰 Supabase.swift 와 같은 주소 · 같은 함수.
 * 로그인 정보(session)는 이 폰에만 저장 (saveSession 으로 Store 가 파일에 씀)
 */
object Supabase {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    var base: String = Config.supabaseURL
    var key: String = Config.supabaseAnonKey
    val isConfigured: Boolean get() = base.isNotEmpty() && key.isNotEmpty()

    /** 실제 인터넷 요청 (시험에서는 바꿔 끼움) */
    var http: suspend (HttpReq) -> HttpResp = { r -> withContext(Dispatchers.IO) { send(r) } }
    var now: () -> Long = { System.currentTimeMillis() }

    /** 로그인 정보가 바뀔 때 (파일에 저장) */
    var onSession: (SbSession?) -> Unit = {}
    var session: SbSession? = null
        set(v) { field = v; onSession(v) }
    val userId: String? get() = session?.userId

    // MARK: 요청

    private fun send(r: HttpReq): HttpResp {
        val c = URL(r.url).openConnection() as HttpURLConnection
        return try {
            c.requestMethod = r.method
            c.connectTimeout = 15_000; c.readTimeout = 30_000
            r.headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
            if (r.body != null) { c.doOutput = true; c.outputStream.use { it.write(r.body) } }
            val code = c.responseCode
            val stream = if (code in 200..299) c.inputStream else c.errorStream
            HttpResp(code, stream?.use { it.readBytes() } ?: ByteArray(0))
        } catch (e: java.io.IOException) {
            HttpResp(0, (e.message ?: "").toByteArray())
        } finally { c.disconnect() }
    }

    suspend fun request(
        path: String, method: String = "GET", body: JsonElement? = null, auth: Boolean = true,
        headers: Map<String, String> = emptyMap(), raw: ByteArray? = null,
    ): ByteArray {
        if (!isConfigured) throw ServerError(-1, "The server isn't set up yet")
        if (auth) refreshIfNeeded()
        val h = LinkedHashMap<String, String>()
        h["apikey"] = key
        session?.takeIf { auth }?.let { h["Authorization"] = "Bearer " + it.accessToken }
        h["Content-Type"] = "application/json"
        h.putAll(headers)
        val bytes = raw ?: body?.toString()?.toByteArray()
        val resp = http(HttpReq(method, base + path, h, bytes))
        if (resp.code !in 200..299) {
            val text = String(resp.body)
            val msg = runCatching {
                val o = json.parseToJsonElement(text).jsonObject
                listOf("msg", "message", "error_description", "error").firstNotNullOfOrNull { o[it]?.jsonPrimitive?.contentOrNull }
            }.getOrNull() ?: text
            throw ServerError(resp.code, msg)
        }
        return resp.body
    }

    private suspend fun refreshIfNeeded() {
        val s = session ?: return
        if (s.expiresAt - now() > 60_000) return
        val d = request("/auth/v1/token?grant_type=refresh_token", "POST", buildJsonObject { put("refresh_token", s.refreshToken) }, auth = false)
        session = parseSession(d)
    }

    private fun parseSession(d: ByteArray): SbSession {
        val j = json.parseToJsonElement(String(d)).jsonObject
        val at = j["access_token"]?.jsonPrimitive?.contentOrNull
        val rt = j["refresh_token"]?.jsonPrimitive?.contentOrNull
        val u = j["user"] as? JsonObject
        val id = u?.get("id")?.jsonPrimitive?.contentOrNull
        if (at == null || rt == null || id == null) throw ServerError(-2, "Couldn't read the server response")
        val exp = j["expires_in"]?.jsonPrimitive?.doubleOrNull ?: 3600.0
        return SbSession(at, rt, id, u["email"]?.jsonPrimitive?.contentOrNull, now() + (exp * 1000).toLong())
    }

    private fun arr(d: ByteArray): List<JsonObject> =
        (json.parseToJsonElement(String(d)) as? JsonArray)?.mapNotNull { it as? JsonObject } ?: emptyList()

    private fun JsonObject.str(k: String): String? = (this[k] as? JsonPrimitive)?.contentOrNull
    private fun JsonObject.int(k: String): Int? = (this[k] as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull()?.toInt()

    // MARK: 로그인

    /** 이메일로 6자리 코드 보내기 */
    suspend fun sendCode(email: String) {
        request("/auth/v1/otp", "POST", buildJsonObject { put("email", email); put("create_user", true) }, auth = false)
    }

    /** 코드 확인 → 로그인 */
    suspend fun verify(email: String, code: String) {
        val d = request("/auth/v1/verify", "POST", buildJsonObject { put("type", "email"); put("email", email); put("token", code) }, auth = false)
        session = parseSession(d)
    }

    /** 구글 로그인 (구글이 준 ID 토큰으로) */
    suspend fun signInWithGoogle(idToken: String) {
        val d = request("/auth/v1/token?grant_type=id_token", "POST",
            buildJsonObject { put("provider", "google"); put("id_token", idToken) }, auth = false)
        session = parseSession(d)
    }

    suspend fun signOut() {
        runCatching { request("/auth/v1/logout", "POST", JsonObject(emptyMap())) }
        session = null
    }

    /** 다른 기기에서 로그인해서 이 기기만 로그아웃 (서버에 logout 을 보내지 않음 — 새 기기 로그인까지 끊길 수 있어서) */
    fun dropSession() { session = null }

    /** 계정 삭제 (SQL 함수 delete_account) — 서버의 프로필 · 친구 · 기록이 지워짐 */
    suspend fun deleteAccount() {
        request("/rest/v1/rpc/delete_account", "POST", JsonObject(emptyMap()))
        session = null
    }

    // MARK: 프로필

    suspend fun myProfile(): RemoteProfile? {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        val o = arr(request("/rest/v1/profiles?id=eq.$id&select=*")).firstOrNull() ?: return null
        return RemoteProfile(o.str("id") ?: id, o.str("nickname"), o.str("division"), o.str("avatar_url"), o.str("visibility"))
    }

    suspend fun nicknameAvailable(n: String): Boolean =
        String(request("/rest/v1/rpc/nickname_available", "POST", buildJsonObject { put("n", n) })).trim() == "true"

    /** avatarUrl 이 null 이면 서버의 사진 주소는 건드리지 않음. 사진을 지울 때만 clearAvatar */
    suspend fun upsertProfile(nickname: String?, division: String, visibility: String, avatarUrl: String?, clearAvatar: Boolean = false) {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        val b = buildJsonObject {
            put("id", id); put("division", division); put("visibility", visibility)
            if (nickname != null) put("nickname", nickname)
            if (avatarUrl != null) put("avatar_url", avatarUrl) else if (clearAvatar) put("avatar_url", JsonNull)
        }
        request("/rest/v1/profiles", "POST", b, headers = mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"))
    }

    /** 서버에 아직 표가 없으면(404) null */
    suspend fun myPrivate(): PrivateProfile? {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        val d = try {
            request("/rest/v1/profile_private?id=eq.$id&select=sex,height_cm,weight_kg,birth_year,raced,race_division")
        } catch (e: ServerError) { if (e.code == 404) return null else throw e }
        val o = arr(d).firstOrNull() ?: return null
        return PrivateProfile(o.str("sex"), o.int("height_cm"), o.str("weight_kg")?.toDoubleOrNull(), o.int("birth_year"),
            o.str("raced")?.toBooleanStrictOrNull(), o.str("race_division"))
    }

    /** 값이 null 이면 서버에서도 비움 */
    suspend fun upsertPrivate(p: PrivateProfile) {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        val b = buildJsonObject {
            put("id", id)
            put("sex", p.sex); put("height_cm", p.heightCm); put("weight_kg", p.weightKg)
            put("birth_year", p.birthYear); put("raced", p.raced); put("race_division", p.raceDivision)
        }
        request("/rest/v1/profile_private", "POST", b, headers = mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"))
    }

    // MARK: 한 기기만 로그인

    suspend fun claimDevice(dev: String) { request("/rest/v1/rpc/claim_device", "POST", buildJsonObject { put("dev", dev) }) }

    suspend fun activeDevice(): String? {
        val t = String(request("/rest/v1/rpc/active_device", "POST", JsonObject(emptyMap()))).trim()
        val e = runCatching { json.parseToJsonElement(t) }.getOrNull()
        return (e as? JsonPrimitive)?.takeIf { it.isString }?.content
    }

    /** 아바타 올리기 → 공개 주소 */
    suspend fun uploadAvatar(jpeg: ByteArray): String {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        val path = "avatars/$id.jpg"
        request("/storage/v1/object/$path", "POST", headers = mapOf("Content-Type" to "image/jpeg", "x-upsert" to "true"), raw = jpeg)
        return base + "/storage/v1/object/public/$path?v=" + (now() / 1000)
    }

    // MARK: 친구

    /** 이메일 전체 또는 닉네임 전체가 정확히 맞는 한 사람만. 서버에 find_user 가 없으면(404) 닉네임만 */
    suspend fun findUser(query: String): RemoteProfile? {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return null
        val rows = try {
            arr(request("/rest/v1/rpc/find_user", "POST", buildJsonObject { put("q", q) }))
        } catch (e: ServerError) {
            if (e.code != 404) throw e
            if (!Regex("^[a-z0-9_]{3,16}$").matches(q)) return null
            arr(request("/rest/v1/profiles?nickname=eq.$q&select=id,nickname,division,avatar_url&limit=1"))
        }
        val o = rows.firstOrNull() ?: return null
        return RemoteProfile(o.str("id") ?: return null, o.str("nickname"), o.str("division"), o.str("avatar_url"))
    }

    suspend fun addFriend(other: String) { request("/rest/v1/rpc/add_friend", "POST", buildJsonObject { put("other", other) }) }

    /** 받은 요청에 답하기. 서버에 respond_friend 가 없으면(404) 수락 = add_friend, 거절 = 줄 지우기 */
    suspend fun respondFriend(other: String, accept: Boolean) {
        try {
            request("/rest/v1/rpc/respond_friend", "POST", buildJsonObject { put("other", other); put("accept", accept) })
        } catch (e: ServerError) {
            if (e.code != 404) throw e
            if (accept) addFriend(other) else removeFriend(other)
        }
    }

    suspend fun friendLinks(): List<FriendLink> =
        arr(request("/rest/v1/friendships?select=requester,addressee,status")).mapNotNull {
            FriendLink(it.str("requester") ?: return@mapNotNull null, it.str("addressee") ?: return@mapNotNull null, it.str("status") ?: "")
        }

    /** 두 사람 사이의 친구 · 요청 줄을 양쪽 방향 모두 지움 */
    suspend fun removeFriend(other: String) {
        val me = userId ?: throw ServerError(-3, "Please sign in first")
        request("/rest/v1/friendships?requester=eq.$me&addressee=eq.$other", "DELETE", headers = mapOf("Prefer" to "return=minimal"))
        request("/rest/v1/friendships?requester=eq.$other&addressee=eq.$me", "DELETE", headers = mapOf("Prefer" to "return=minimal"))
    }

    /** 친구 + 각자의 최고 Full Simulation */
    suspend fun friends(): List<FriendRow> =
        arr(request("/rest/v1/rpc/friends_with_best", "POST", JsonObject(emptyMap()))).mapNotNull { o ->
            FriendRow(
                o.str("user_id") ?: return@mapNotNull null, o.str("nickname") ?: "", o.str("division") ?: "", o.str("avatar_url"),
                o.str("best_date"), (o["splits"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull()?.toInt() },
                o.str("status") ?: "", o.str("direction"),
            )
        }

    /** 순위표: kind = sim / race / station, station 0…7 */
    suspend fun leaderboard(kind: String, station: Int, division: String?): List<LBRow> =
        arr(request("/rest/v1/rpc/leaderboard", "POST", buildJsonObject {
            put("kind", kind); put("station", station); put("div", division)
        })).mapNotNull { o ->
            LBRow(o.str("user_id") ?: return@mapNotNull null, o.str("nickname") ?: "", o.str("division") ?: "", o.str("avatar_url"), o.int("t") ?: 0)
        }

    // MARK: 기록 (요약만 올림 — 심박 원본은 기기에만)

    /** 미완료 · 확인 필요 · PFT 기록은 서버에 안 올림 (아이폰과 같음) */
    suspend fun upload(r: com.nkssi.splits8.shared.Record) {
        val id = userId ?: throw ServerError(-3, "Please sign in first")
        if (!r.counts || r.mode == com.nkssi.splits8.shared.Mode.Pft) return
        val b = buildJsonObject {
            put("id", r.id.lowercase()); put("user_id", id); put("mode", r.mode.raw)
            put("date", com.nkssi.splits8.shared.Fm.ymd(r.date)); put("total_s", r.total); put("rox_s", r.roxTotal)
            put("division", r.division)
            put("splits", r.splits16?.let { s -> JsonArray(s.map { JsonPrimitive(it) }) } ?: JsonNull)
        }
        request("/rest/v1/records", "POST", b, headers = mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"))
    }

    suspend fun deleteRecord(id: String) {
        request("/rest/v1/records?id=eq." + id.lowercase(), "DELETE", headers = mapOf("Prefer" to "return=minimal"))
    }

    // MARK: 대회

    suspend fun events(): List<com.nkssi.splits8.shared.EventItem> =
        arr(request("/rest/v1/events?select=city,venue,region,start_date,end_date&order=start_date", auth = false)).mapNotNull { o ->
            com.nkssi.splits8.shared.EventItem(o.str("city") ?: return@mapNotNull null, o.str("venue") ?: "", o.str("region") ?: "",
                o.str("start_date") ?: return@mapNotNull null, o.str("end_date") ?: o.str("start_date")!!)
        }

    /** 공개 사진 받기 (5 MB 까지, 이 서버 주소만) */
    suspend fun download(url: String): ByteArray? {
        if (!url.startsWith(base)) return null
        val r = runCatching { http(HttpReq("GET", url, emptyMap(), null)) }.getOrNull() ?: return null
        return if (r.code == 200 && r.body.size <= 5_000_000) r.body else null
    }

    /** 잠깐 쉬었다 다시 (프로필 읽기 재시도용) */
    suspend fun pause(ms: Long) = delay(ms)
}
