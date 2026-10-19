package com.nkssi.splits8

import android.app.Activity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.Station
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.lang.ref.WeakReference

/**
 * 서버와 이 폰을 맞추는 일 (아이폰 Store.swift 의 "계정 (Supabase)" 부분과 같은 규칙).
 * 화면을 막지 않고 뒤에서. 실패해도 앱은 그대로 — 다음 새로고침 때 맞춰짐. 화면 확인용 예시(demo)에서는 서버에 가지 않음
 */
object Cloud {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** 다른 기기에서 로그인해서 이 기기가 로그아웃됨 → 안내 한 번 */
    var signedOutElsewhere by mutableStateOf(false)
    private var claiming = false

    /** 서버에 가도 되는지 (예시 데이터 · 서버 설정 없음이면 안 감) */
    val live: Boolean get() = !Store.demo && Supabase.isConfigured
    val on: Boolean get() = live && Store.signedIn && Supabase.session != null

    fun launch(f: suspend () -> Unit) {
        if (!live) return
        scope.launch { runCatching { f() } }
    }

    // MARK: 로그인 뒤 프로필

    /**
     * 로그인 끝난 뒤: 이 기기를 "지금 기기"로 적고 프로필 읽기. 실패하면 한 번 더 해 보고, 그래도 안 되면 Failed
     * ("읽기 실패"를 "프로필 없음"으로 보면 이미 닉네임이 있는 계정에 닉네임을 다시 만들라고 하게 됨)
     */
    suspend fun loadProfile(): ProfileLoad {
        claimThisDevice(fresh = true)
        repeat(2) { attempt ->
            try {
                val p = Supabase.myProfile()
                loadPrivate()
                val n = p?.nickname
                if (p == null || n.isNullOrEmpty()) return ProfileLoad.None
                applyRemote(p, n)
                return ProfileLoad.Found
            } catch (e: Exception) {
                if (attempt == 0) Supabase.pause(700)
            }
        }
        return ProfileLoad.Failed
    }

    /** 서버 프로필을 이 폰에 적용 (같은 계정으로 다른 기기에 로그인했을 때 같은 모습이 되게) */
    private suspend fun applyRemote(p: RemoteProfile, n: String) {
        Store.avatarUrl = p.avatarUrl
        Store.update { s ->
            var x = s.copy(nickname = n, email = Supabase.session?.email ?: s.email, visibility = p.visibility ?: s.visibility)
            Division.all.firstOrNull { it.name == p.division }?.let { x = x.copy(division = it.key) }
            x
        }
        if (Store.photo == null) p.avatarUrl?.let { downloadAvatar(it) }
        refreshSocial()
    }

    private suspend fun downloadAvatar(url: String) {
        val d = Supabase.download(url) ?: return
        val bmp = android.graphics.BitmapFactory.decodeByteArray(d, 0, d.size) ?: return
        Store.setPhoto(bmp, upload = false)
    }

    /** 닉네임 저장 (가입 마무리 · 변경). 이미 있는 닉네임이면 NicknameTaken */
    suspend fun saveNickname(n: String) {
        try {
            Supabase.upsertProfile(n, Store.settings.div.name, Store.settings.visibility, Store.avatarUrl)
        } catch (e: ServerError) {
            if (e.code == 409 || (e.message ?: "").contains("duplicate", ignoreCase = true)) throw NicknameTaken()
            throw e
        }
        Store.update { it.copy(nickname = n, email = Supabase.session?.email ?: it.email) }
        if (Store.avatarUrl == null) Store.photoJpeg()?.let { syncAvatar(it) }
        for (r in Store.records) runCatching { Supabase.upload(r) }
        refreshSocial()
    }

    suspend fun syncProfile(clearAvatar: Boolean = false) {
        if (!on) return
        Supabase.upsertProfile(null, Store.settings.div.name, Store.settings.visibility, Store.avatarUrl, clearAvatar)
    }

    suspend fun syncAvatar(jpeg: ByteArray) {
        if (Supabase.session == null) return
        val u = runCatching { Supabase.uploadAvatar(jpeg) }.getOrNull() ?: return
        Store.avatarUrl = u
        runCatching { syncProfile() }
    }

    // MARK: 친구 · 순위표 · 대회

    /** 친구 목록 · 요청 · 순위표 새로 받기 */
    suspend fun refreshSocial() {
        if (!on) return
        val rows = runCatching { Supabase.friends() }.getOrNull()
        if (rows != null) {
            val links = runCatching { Supabase.friendLinks() }.getOrNull()
            val me = Supabase.userId ?: ""
            val (fs, rq) = mergeFriends(rows, links, me) { Store.isBlocked(it) }
            Store.setSocial(fs, rq)
        }
        runCatching { Supabase.cheers() }.getOrNull()?.let { cs -> Store.cheers = cs.filter { !Store.isBlocked(it.sender) } }
        refreshLeaderboard()
    }

    /**
     * 서버 줄 → 친구 · 요청. 같은 사람이 두 줄로 올 수 있음 (서로 추가) → 한 사람당 하나, 수락된 쪽 우선.
     * 요청 방향: 친구 줄(friendships)에서 판단 → 서버가 알려 준 값 → 모르면 보낸 요청으로 봄
     */
    fun mergeFriends(rows: List<FriendRow>, links: List<FriendLink>?, me: String, blocked: (String) -> Boolean): Pair<List<Friend>, List<FriendReq>> {
        val seen = LinkedHashMap<String, FriendRow>()
        for (x in rows) {
            if (blocked(x.userId)) continue
            val old = seen[x.userId]
            if (old == null) seen[x.userId] = x
            else if (old.status != "accepted" && x.status == "accepted") seen[x.userId] = x
            else if (old.splits == null && x.splits != null && x.status == old.status) seen[x.userId] = x
        }
        val fs = ArrayList<Friend>()
        val rq = ArrayList<FriendReq>()
        for ((id, x) in seen) {
            val accepted = x.status == "accepted" || (links?.any {
                it.status == "accepted" && ((it.requester == id && it.addressee == me) || (it.requester == me && it.addressee == id))
            } ?: false)
            if (accepted) {
                fs.add(Friend(id, x.nickname, x.division, x.bestDate ?: "", x.splits ?: emptyList(), x.avatarUrl))
                continue
            }
            val incoming = if (links != null) {
                val sent = links.any { it.requester == me && it.addressee == id }
                val got = links.any { it.requester == id && it.addressee == me }
                got && !sent
            } else x.direction == "incoming"
            rq.add(FriendReq(id, x.nickname, x.division, x.avatarUrl, incoming))
        }
        return fs to rq
    }

    suspend fun refreshLeaderboard() {
        if (!on) return
        val s = Store.settings
        val kind = if (s.lbTab == "stations") "station" else s.lbTab
        val st = Station.all.indexOfFirst { it.key == s.lbStation }.coerceAtLeast(0)
        val rows = runCatching { Supabase.leaderboard(kind, st, if (s.lbAllDivisions) null else s.div.name) }.getOrNull() ?: return
        Store.leaderboard = rows.filterNot { Store.isBlocked(it.user_id) }
    }

    suspend fun refreshEvents() {
        if (!live) return
        val e = runCatching { Supabase.events() }.getOrNull()
        if (!e.isNullOrEmpty()) Store.events = e
    }

    // MARK: 기록

    fun upload(r: com.nkssi.splits8.shared.Record) { if (on) launch { Supabase.upload(r) } }
    fun deleteRecord(id: String) { if (on) launch { Supabase.deleteRecord(id) } }

    // MARK: 로그아웃 · 계정 삭제

    fun signOut() {
        if (live) launch { Supabase.signOut() }
        clearDevice()
    }

    suspend fun deleteAccount() {
        Supabase.deleteAccount()
        clearDevice()
    }

    // MARK: 한 기기만 로그인 (나중에 로그인한 기기가 이김)

    private const val deviceKey = "session.device.v1"
    private const val claimedKey = "session.device.claimed.v1"

    private fun clearDevice() {
        Store.setPref(deviceKey, ""); Store.setPref(claimedKey, "")
    }

    /** 이 기기를 서버에 "지금 로그인한 기기"로 적음. fresh = 방금 로그인함 → 새 기기 id */
    suspend fun claimThisDevice(fresh: Boolean) {
        if (!live || Supabase.session == null) return
        var dev = Store.pref(deviceKey, "")
        if (fresh || dev.isEmpty()) {
            dev = java.util.UUID.randomUUID().toString()
            Store.setPref(deviceKey, dev); Store.setPref(claimedKey, "")
        }
        claiming = true
        try {
            Supabase.claimDevice(dev)
            Store.setPref(claimedKey, "1")
        } catch (_: Exception) {
        } finally { claiming = false }
    }

    /** 앱이 앞에 올 때 · 켜져 있는 동안 3분마다: 서버의 "지금 기기"가 이 기기와 다르면 이 기기만 로그아웃 */
    suspend fun checkDevice() {
        if (!on || claiming) return
        val local = Store.pref(deviceKey, "").ifEmpty { null }
        val server = try { Supabase.activeDevice() } catch (_: Exception) { return }
        if (local == null) {
            if (server == null) claimThisDevice(false) else kickOut()
            return
        }
        if (Store.pref(claimedKey, "") != "1") {
            if (server != null && server != local) kickOut() else claimThisDevice(false)
            return
        }
        if (server == null) { claimThisDevice(false); return }
        if (server != local) kickOut()
    }

    /** 다른 기기 로그인으로 이 기기만 로그아웃 (기록은 이 폰에 그대로) */
    private fun kickOut() {
        if (!Store.signedIn) return
        Supabase.dropSession()
        Store.clearAccount()
        clearDevice()
        signedOutElsewhere = true
    }

    // MARK: 본인만 보는 프로필

    /** 서버의 본인 프로필을 이 폰에 가져옴 (서버에 값이 있을 때만 바꿈) */
    suspend fun loadPrivate() {
        if (!live || Supabase.session == null) return
        val p = runCatching { Supabase.myPrivate() }.getOrNull() ?: return
        if (p.sex == null && p.birthYear == null && p.raced == null && p.heightCm == null && p.weightKg == null) return
        Store.update {
            it.copy(sex = p.sex ?: it.sex, heightCm = p.heightCm ?: it.heightCm, weightKg = p.weightKg ?: it.weightKg,
                birthYear = p.birthYear ?: it.birthYear, raced = p.raced ?: it.raced, raceDivision = p.raceDivision ?: it.raceDivision,
                profileDone = true)          // 다른 기기에서 이미 답함 → 다시 묻지 않음
                // 빌드 27: 태어난 해로 심박 계산용 나이도 맞춤 (나이로 계산할 때만)
                .let { s -> Store.fixSettings(s) }
        }
    }

    suspend fun syncPrivate() {
        if (!live || Supabase.session == null) return
        val s = Store.settings
        Supabase.upsertPrivate(PrivateProfile(s.sex, s.heightCm, s.weightKg, s.birthYear, s.raced, s.raceDivision))
    }

    /** 설정이 바뀐 뒤 서버에 알릴 것 (디비전 · 본인 프로필 · 순위표 탭) */
    fun settingsChanged(old: Settings, new: Settings) {
        if (!on) return
        if (old.division != new.division || old.visibility != new.visibility) launch { syncProfile() }
        if (old.sex != new.sex || old.heightCm != new.heightCm || old.weightKg != new.weightKg || old.birthYear != new.birthYear ||
            old.raced != new.raced || old.raceDivision != new.raceDivision) launch { syncPrivate() }
        if (old.lbTab != new.lbTab || old.lbStation != new.lbStation || old.lbAllDivisions != new.lbAllDivisions ||
            old.division != new.division) launch { refreshLeaderboard() }
    }
}

/** 서버 사진 (친구 · 순위표 얼굴). 한 번 받으면 앱이 켜져 있는 동안 기억 */
object RemoteImages {
    private val cache = mutableStateMapOf<String, ImageBitmap>()
    private val asked = HashSet<String>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    fun get(url: String?): ImageBitmap? {
        if (url.isNullOrEmpty() || Store.demo) return null
        cache[url]?.let { return it }
        if (asked.add(url)) scope.launch {
            val d = Supabase.download(url) ?: return@launch
            val b = runCatching { android.graphics.BitmapFactory.decodeByteArray(d, 0, d.size) }.getOrNull() ?: return@launch
            cache[url] = b.asImageBitmap()
        }
        return null
    }
}

/** 구글 로그인 (안드로이드 Credential Manager → 구글 ID 토큰 → Supabase) */
object GoogleSignIn {
    /** 지금 앞에 있는 화면 (로그인 창을 띄울 곳) */
    var activity: WeakReference<Activity>? = null

    /** 구글 ID 토큰. 사용자가 취소하면 null */
    suspend fun idToken(): String? {
        if (Config.googleWebClientId.isEmpty()) throw Exception(com.nkssi.splits8.shared.L10n.t("Google sign-in isn't set up yet. Please use email for now."))
        val act = activity?.get() ?: throw Exception("No screen")
        val cm = androidx.credentials.CredentialManager.create(act)
        val opt = com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption.Builder(Config.googleWebClientId).build()
        val req = androidx.credentials.GetCredentialRequest.Builder().addCredentialOption(opt).build()
        val res = try {
            cm.getCredential(act, req)
        } catch (e: androidx.credentials.exceptions.GetCredentialCancellationException) {
            return null
        }
        val c = res.credential
        if (c is androidx.credentials.CustomCredential &&
            c.type == com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            return com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.createFrom(c.data).idToken
        }
        throw Exception("Google sign-in failed")
    }
}

/** 실제 서버 (Supabase) 로 하는 계정 일 */
object SupabaseAccounts : AccountApi {
    override val ready: Boolean get() = Supabase.isConfigured
    override suspend fun sendCode(email: String) = Supabase.sendCode(email)
    override suspend fun verify(email: String, code: String) = Supabase.verify(email, code)
    override suspend fun signInGoogle(): String? {
        val t = GoogleSignIn.idToken() ?: return null
        Supabase.signInWithGoogle(t)
        return Supabase.session?.email ?: ""
    }
    override suspend fun nicknameAvailable(nick: String): Boolean = Supabase.nicknameAvailable(nick)
    override suspend fun saveNickname(nick: String) = Cloud.saveNickname(nick)
    override suspend fun loadProfile(): ProfileLoad = Cloud.loadProfile()
    override suspend fun findUser(q: String): RemoteProfile? = Supabase.findUser(q)
    override suspend fun addFriend(id: String) = Supabase.addFriend(id)
    override suspend fun respondFriend(id: String, accept: Boolean) = Supabase.respondFriend(id, accept)
    override suspend fun removeFriend(id: String) = Supabase.removeFriend(id)
    override val userId: String? get() = Supabase.userId
}
