package com.nkssi.splits8

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.asImageBitmap
import com.nkssi.splits8.shared.BlockedUser
import kotlinx.coroutines.launch
import com.nkssi.splits8.shared.EventItem
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RecordBook
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.SplitsJson
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import java.io.File

/**
 * 폰 저장소 (아이폰 Store.swift): 설정 · 트레이닝 · 기록 · 친구 · 예약.
 * 아이폰과 같은 파일 이름 · 같은 JSON 모양으로 앱 폴더에 저장.
 * 서버(Supabase)와 맞추는 일은 Cloud 가 함. 워치로 보내는 일은 WatchSync (바뀔 때마다 묶음을 다시 보냄).
 */
object Store {
    private var dir: File? = null
    /** 화면 확인용 예시 데이터 (저장 안 함) */
    var demo = false
        private set

    var settings by mutableStateOf(Settings())
        private set
    var programs by mutableStateOf(Program.presets())
        private set
    var records by mutableStateOf<List<Record>>(emptyList())
        private set
    var friends by mutableStateOf<List<Friend>>(emptyList())
        private set
    var plans by mutableStateOf<List<PlannedWorkout>>(emptyList())
        private set
    var events by mutableStateOf(EventItem.bundled)

    /** 서버에서 받은 순위표 · 친구 요청 (빌드 22: 받은 요청은 수락해야 친구) */
    var leaderboard by mutableStateOf<List<LBRow>>(emptyList())
    var requests by mutableStateOf<List<FriendReq>>(emptyList())
    val incoming: List<FriendReq> get() = requests.filter { it.incoming }
    val outgoing: List<FriendReq> get() = requests.filterNot { it.incoming }
    /** 내 계정 id (순위표에서 "나" 줄 찾기). 화면 확인용 예시에서는 "demo.me" */
    var myId by mutableStateOf<String?>(null)

    /** 서버에 올린 내 사진 주소 (없으면 null) */
    var avatarUrl: String?
        get() = pref("avatar.url", "").ifEmpty { null }
        set(v) = setPref("avatar.url", v ?: "")

    /** 내 프로필 사진 (앱 폴더 avatar.jpg, 720×720 정사각). 로그인했으면 서버에도 올림 */
    var photo by mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null)
        private set

    /** 지금 시각 (화면 사진에서는 고정해서 늘 같은 화면이 나오게) */
    var now: () -> java.time.Instant = { java.time.Instant.now() }
    fun today(): java.time.LocalDate = now().atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate()

    /** 화면에서만 쓰는 작은 기억 (홈 요약 주/월 등) — 아이폰 UserDefaults */
    private var prefs: android.content.SharedPreferences? = null
    private val memPrefs = HashMap<String, String>()
    fun pref(key: String, def: String): String = if (demo) memPrefs[key] ?: def else prefs?.getString(key, def) ?: def
    fun setPref(key: String, v: String) {
        if (demo) memPrefs[key] = v else prefs?.edit()?.putString(key, v)?.apply()
    }

    /** 기록 계산 (PB · 최고 · 비교 …). 기록 · 설정이 바뀌면 새로 만듦 */
    var book by mutableStateOf(RecordBook(emptyList(), Settings()))
        private set

    val friend: Friend? get() = friends.firstOrNull { it.id == settings.friendId }
    /** 로그인함 = 닉네임이 있고 서버 로그인 정보도 있음 (예시 화면은 닉네임만) */
    val signedIn: Boolean get() = settings.signedIn && (demo || Supabase.session != null)


    /**
     * 빌드 24: 켤 때 설정 바로잡기 (아이폰 Store.init 과 같음)
     * - 태어난 해가 있으면 나이는 늘 그 해로 계산 (프로필의 나이와 태어난 해가 따로 놀지 않게)
     * - 예전 '대회 경험 디비전'(raceDivision)은 Division 하나로 합침
     */
    fun fixSettings(s0: Settings, thisYear: Int = java.time.Year.now().value): Settings {
        var s = s0
        s.birthYear?.let { y -> val a = thisYear - y; if (a in 10..100 && s.age != a) s = s.copy(age = a) }
        val k = s.raceDivision
        if (s.divPicked != true && k != null && com.nkssi.splits8.shared.Division.all.any { it.key == k }) s = s.copy(division = k, divPicked = true)
        return s
    }

    fun init(context: Context) {
        if (dir != null) return
        dir = context.filesDir
        Reminders.context = context.applicationContext
        prefs = context.getSharedPreferences("splits8", Context.MODE_PRIVATE)
        settings = fixSettings(load("settings.json", Settings.serializer()) ?: Settings())
        programs = load("programs.json", ListSerializer(Program.serializer())) ?: Program.presets()
        records = load("records.json", ListSerializer(Record.serializer())) ?: emptyList()
        friends = load("friends.json", ListSerializer(Friend.serializer())) ?: emptyList()
        plans = load("plans.json", ListSerializer(PlannedWorkout.serializer())) ?: emptyList()
        photo = runCatching { android.graphics.BitmapFactory.decodeFile(File(dir, "avatar.jpg").path)?.asImageBitmap() }.getOrNull()
        // 서버 로그인 정보 (이 폰에만)
        Supabase.session = runCatching { SplitsJson.decodeFromString(SbSession.serializer(), pref("sb.session", "")) }.getOrNull()
        Supabase.onSession = { s -> setPref("sb.session", s?.let { SplitsJson.encodeToString(SbSession.serializer(), it) } ?: "") }
        // 로그인 정보가 없으면 로그아웃 상태
        if (Supabase.session == null && settings.nickname != null) settings = settings.copy(nickname = null)
        applyLang()
        rebuild()
        // 88번: Test 탭은 처음엔 Full Sim (예전에 PFT 를 골라 둔 사람은 그대로)
        Router.testTab = if (pref("test.tab", "") == "pft") "pft" else "sim"
    }

    /** Test 탭에서 고른 쪽 기억 */
    fun saveTestTab(t: String) = setPref("test.tab", t)

    /** 시험용: 예시 모드를 끄고 빈 저장소로 다시 시작 (시험 기기의 임시 폴더) */
    fun resetForTest(context: Context) {
        context.getSharedPreferences("splits8", Context.MODE_PRIVATE).edit().clear().commit()
        context.filesDir.listFiles()?.forEach { it.delete() }
        dir = null; demo = false
        friends = emptyList(); requests = emptyList(); leaderboard = emptyList(); requested = emptySet(); myId = null
        init(context)
    }

    /** 화면 확인용: 예시 데이터로 채움 (파일에 안 씀) */
    fun useDemo(
        s: Settings, p: List<Program>, r: List<Record>, f: List<Friend> = emptyList(),
        lb: List<LBRow> = emptyList(), req: List<FriendReq> = emptyList(), me: String? = null,
        pl: List<PlannedWorkout> = emptyList(),
    ) {
        demo = true
        settings = s; programs = p; records = r; friends = f; plans = pl
        leaderboard = lb; requests = req; myId = me; memPrefs.clear(); cheers = emptyList()
        applyLang()
        rebuild()
    }

    fun plans(on: java.time.LocalDate): List<PlannedWorkout> =
        plans.filter { it.date.atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate() == on }

    fun records(on: java.time.LocalDate): List<Record> =
        records.filter { it.date.atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate() == on }.sortedByDescending { it.date }

    fun update(f: (Settings) -> Settings) {
        val old = settings
        settings = f(settings)
        applyLang()
        rebuild()
        save("settings.json", Settings.serializer(), settings)
        if (!demo) Cloud.settingsChanged(old, settings)
        // 대회를 바꾸면 대회 알림 (일주일 전 · 전날) 다시
        if (!demo && old.event != settings.event) Reminders.scheduleRace(settings.event)
        if (!demo && (old.event != settings.event || old.goalTime != settings.goalTime || old.division != settings.division ||
                old.lang != settings.lang)) widgets()
    }

    /** 트레이닝 저장 (같은 id 면 바꿈, 새것은 맨 위 — 아이폰과 같음) */
    fun saveProgram(p: Program) {
        programs = if (programs.any { it.id == p.id }) programs.map { if (it.id == p.id) p else it } else listOf(p) + programs
        save("programs.json", ListSerializer(Program.serializer()), programs)
        WatchSync.dirty()
    }

    fun deleteProgram(id: String) {
        programs = programs.filterNot { it.id == id }
        save("programs.json", ListSerializer(Program.serializer()), programs)
        WatchSync.dirty()
    }

    /** 운동 예약 추가 · 수정 (같은 id 면 바꿈) + 알림 */
    fun savePlan(p: PlannedWorkout) {
        plans = (if (plans.any { it.id == p.id }) plans.map { if (it.id == p.id) p else it } else plans + p).sortedBy { it.date }
        save("plans.json", ListSerializer(PlannedWorkout.serializer()), plans)
        if (!demo) Reminders.schedule(p)
    }

    fun deletePlan(id: String) {
        plans = plans.filterNot { it.id == id }
        save("plans.json", ListSerializer(PlannedWorkout.serializer()), plans)
        if (!demo) Reminders.cancel(id)
    }

    /** 앞으로 남은 예약 (오늘 이후) */
    val upcomingPlans: List<PlannedWorkout>
        get() {
            val start = today().atStartOfDay(com.nkssi.splits8.shared.Fm.zone).toInstant()
            return plans.filter { !it.date.isBefore(start) }.sortedBy { it.date }
        }

    /** 친구 목표 (트레이닝 탭 "Mine | 친구") */
    fun setTgtSrc(v: String) = update { it.copy(tgtSrc = v) }

    /** 사진 바꾸기 (null = 지우기). 가운데를 정사각으로 잘라 720×720 JPEG 로 저장 */
    fun setPhoto(src: android.graphics.Bitmap?, upload: Boolean = true) {
        val f = dir?.let { File(it, "avatar.jpg") }
        if (src == null) {
            photo = null
            if (!demo) f?.delete()
            if (upload && Cloud.on) { avatarUrl = null; Cloud.launch { Cloud.syncProfile(clearAvatar = true) } }
            return
        }
        val side = minOf(src.width, src.height)
        val sq = android.graphics.Bitmap.createBitmap(src, (src.width - side) / 2, (src.height - side) / 2, side, side)
        val out = android.graphics.Bitmap.createScaledBitmap(sq, 720, 720, true)
        photo = out.asImageBitmap()
        if (!demo && f != null) runCatching { f.outputStream().use { out.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, it) } }
        if (upload && Cloud.on) photoJpeg()?.let { j -> Cloud.launch { Cloud.syncAvatar(j) } }
    }

    /** 저장된 내 사진 (JPEG) */
    fun photoJpeg(): ByteArray? = dir?.let { File(it, "avatar.jpg") }?.takeIf { it.exists() }?.let { runCatching { it.readBytes() }.getOrNull() }

    /** 로그아웃: 서버 로그아웃 + 이 기기에서 계정 정보만 지움. 기록 · 트레이닝 · 설정(프로필 포함)은 그대로 */
    fun signOut() {
        Cloud.signOut()
        clearAccount()
    }

    /** 이 기기에서 계정 정보만 지움 */
    fun clearAccount() {
        update { it.copy(nickname = null, email = null, signMethod = null) }
        friends = emptyList(); leaderboard = emptyList(); requests = emptyList(); myId = null; requested = emptySet()
        save("friends.json", ListSerializer(Friend.serializer()), friends)
    }

    /** 서버에서 받은 친구 · 요청 (고른 친구가 없어졌으면 풂) */
    fun setSocial(fs: List<Friend>, rq: List<FriendReq>) {
        friends = fs
        requests = rq
        requested = requested.filter { r -> fs.none { it.id == r } }.toSet()
        val sel = settings.friendId
        if (sel != null && fs.none { it.id == sel }) update { it.copy(friendId = null) } else rebuild()
        save("friends.json", ListSerializer(Friend.serializer()), friends)
    }

    // MARK: 친구 (아이폰 Store 와 같은 규칙)

    /** 친구 최대 인원 (빌드 24 — 트레이닝 5개처럼. 이미 넘은 사람은 지우지 않고 추가만 막음) */
    const val FRIEND_LIMIT = 10

    /** 이번에 요청을 보낸 사람 (서버 목록이 다시 오기 전까지 "Requested" 로 보이게) */
    var requested by mutableStateOf<Set<String>>(emptySet())

    /** 친구 수 (수락된 친구 + 보낸 요청) — 10명 제한에 씀 (아이폰 · 서버 friend_limit 과 같은 셈) */
    val friendCount: Int get() = friends.size + outgoing.size
    val friendsFull: Boolean get() = friendCount >= FRIEND_LIMIT

    /** 빌드 24: 받은 응원 (서버에 표가 아직 없으면 빈 목록) */
    var cheers by mutableStateOf<List<CheerRow>>(emptyList())
    val unseenCheers: Int get() = cheers.count { !it.seen }

    /** 받은 응원을 읽음으로 (친구 화면을 열면) */
    fun markCheersSeen() {
        if (cheers.none { !it.seen }) return
        cheers = cheers.map { it.copy(seen = true) }
        if (!demo) socialCall { Supabase.markCheersSeen() }
    }

    /** 응원 보내기. 실패하면 이유 (null = 보냄) */
    suspend fun sendCheer(k: CheerKind, to: Friend): String? {
        if (demo) return null
        return try {
            Supabase.sendCheer(to.id, k.raw); null
        } catch (e: ServerError) {
            val m = e.message ?: ""
            when {
                "daily limit" in m -> L10n.t("You've sent a lot of cheers today. Try again tomorrow.")
                "too fast" in m -> L10n.t("Give it a minute before cheering the same friend again.")
                "send_cheer" in m || "function" in m -> L10n.t("Cheers aren't available yet.")
                else -> L10n.t("Couldn't send. Check your connection and try again.")
            }
        } catch (e: Exception) {
            L10n.t("Couldn't send. Check your connection and try again.")
        }
    }

    /** 친구를 고르면 Full Sim 비교 · 트레이닝 목표에 씀. 다시 누르면 풂 */
    fun toggleFriend(f: Friend) {
        val on = settings.friendId == f.id
        update {
            var n = it.copy(friendId = if (on) null else f.id)
            if (on && n.simCmp == "friend") n = n.copy(simCmp = "goal")
            if (on) n = n.copy(tgtSrc = "mine")
            n
        }
    }

    fun isBlocked(id: String): Boolean = settings.blocked.any { it.id == id }

    /** 차단: 이 폰의 차단 목록에 넣고, 친구 목록 · 순위표 · 요청에서 바로 빼고, 서버의 친구 관계도 끊음 */
    fun block(id: String, name: String) {
        update {
            var n = if (it.blocked.any { b -> b.id == id }) it else it.withBlocked(it.blocked + BlockedUser(id, name))
            if (n.friendId == id) n = n.copy(friendId = null, simCmp = if (n.simCmp == "friend") "goal" else n.simCmp, tgtSrc = "mine")
            n
        }
        friends = friends.filterNot { it.id == id }
        leaderboard = leaderboard.filterNot { it.user_id == id }
        requested = requested - id
        requests = requests.filterNot { it.id == id }
        save("friends.json", ListSerializer(Friend.serializer()), friends)
        if (signedIn && !demo) socialCall { Accounts.api.removeFriend(id) }
    }

    fun unblock(id: String) = update { it.withBlocked(it.blocked.filterNot { b -> b.id == id }) }

    /** 받은 요청 수락 / 거절. 수락은 친구 10명 한도 안에서만 (넘으면 false) */
    fun respond(q: FriendReq, accept: Boolean): Boolean {
        if (accept && friendsFull && friends.none { it.id == q.id }) return false
        requests = requests.filterNot { it.id == q.id }
        if (accept && friends.none { it.id == q.id }) {
            friends = friends + Friend(q.id, q.name, q.div, "", emptyList(), q.avatarUrl)
            save("friends.json", ListSerializer(Friend.serializer()), friends)
        }
        if (!demo) socialCall { Accounts.api.respondFriend(q.id, accept) }
        return true
    }

    /** 보낸 요청 취소 */
    fun cancelRequest(q: FriendReq) {
        requests = requests.filterNot { it.id == q.id }
        requested = requested - q.id
        if (!demo) socialCall { Accounts.api.removeFriend(q.id) }
    }

    /** 친구 요청 보내기. 10명이면 false */
    fun addFriend(id: String): Boolean {
        if (friendsFull) return false
        requested = requested + id
        if (!demo) socialCall { Accounts.api.addFriend(id) }
        return true
    }

    /** 서버 일은 화면을 막지 않고 뒤에서 (실패해도 앱은 그대로 — 다음 새로고침 때 맞춰짐) */
    private fun socialCall(f: suspend () -> Unit) {
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main.immediate).launch {
            runCatching { f() }
            runCatching { Cloud.refreshSocial() }
        }
    }

    /** 백업 파일 글자 (아이폰과 같은 모양) */
    fun backupJson(): String = com.nkssi.splits8.shared.BackupFile(exportedAt = now(), records = records, programs = programs).json()

    /** 백업 가져오기: 없는 기록 · 트레이닝만 더함. 파일이 SPLITS8 백업이 아니면 null, 아니면 (기록 수, 트레이닝 수) */
    fun importBackup(text: String): Pair<Int, Int>? {
        val b = com.nkssi.splits8.shared.BackupFile.read(text) ?: return null
        val (r, nr) = com.nkssi.splits8.shared.BackupFile.mergeRecords(b.records, records)
        val (p, np) = com.nkssi.splits8.shared.BackupFile.mergePrograms(b.programs, programs, Program.freeLimit)
        if (nr > 0) {
            val fresh = r.filter { x -> records.none { it.id.equals(x.id, ignoreCase = true) } }
            records = r; rebuild(); save("records.json", ListSerializer(Record.serializer()), records)
            fresh.forEach { Cloud.upload(it) }
            widgets()
        }
        if (np > 0) { programs = p; save("programs.json", ListSerializer(Program.serializer()), programs); WatchSync.dirty() }
        return nr to np
    }

    // MARK: 진행 중인 폰 기록 (앱이 꺼져도 이어서)

    /** 저장 (null = 지움). 기록이 끝나거나 버리면 지움 */
    fun savePhoneRun(x: PhoneRunSnapshot?) {
        if (demo) return
        val f = dir?.let { File(it, "phone_run.json") } ?: return
        if (x == null) { f.delete(); return }
        save("phone_run.json", PhoneRunSnapshot.serializer(), x)
    }

    /** 이어서 할 기록 (12시간이 넘은 것은 버림) */
    fun loadPhoneRun(): PhoneRunSnapshot? {
        val x = load("phone_run.json", PhoneRunSnapshot.serializer()) ?: return null
        if (now().toEpochMilli() - x.startMs > 12 * 3600_000L) { savePhoneRun(null); return null }
        return x
    }

    /** 폰으로 끝낸 기록 (source = "phone") — Health Connect 에도 저장 (워치 기록은 WatchSync 가 같은 방식으로) */
    fun addPhoneRecord(r: Record) {
        val x = r.copy(source = "phone")
        if (records.any { it.id.equals(x.id, ignoreCase = true) }) return
        add(x)
        Health.save(x)
    }

    fun add(r: Record) {
        if (records.any { it.id.equals(r.id, ignoreCase = true) }) return
        records = records + r
        rebuild()
        save("records.json", ListSerializer(Record.serializer()), records)
        Cloud.upload(r)
        widgets()
    }

    /** 더블 파트너 닉네임 바꾸기 (null = 빼기). 기기에만 저장 */
    fun updatePartner(id: String, nick: String?) {
        val i = records.indexOfFirst { it.id == id }
        if (i < 0) return
        records = records.toMutableList().also { it[i] = it[i].copy(partner = nick) }
        rebuild()
        save("records.json", ListSerializer(Record.serializer()), records)
    }

    fun delete(r: Record) {
        records = records.filterNot { it.id == r.id }
        rebuild()
        save("records.json", ListSerializer(Record.serializer()), records)
        Cloud.deleteRecord(r.id)
        widgets()
    }

    /** 홈 화면 위젯 새로 그리기 */
    private fun widgets() { if (!demo) Reminders.context?.let { Widgets.refresh(it) } }

    /** 기록 계산을 새로 하고, 워치에도 새 묶음 (설정 · 친구 · 최고 기록이 바뀌었을 수 있음) */
    private fun rebuild() {
        book = RecordBook(records, settings, friend)
        WatchSync.dirty()
    }

    /** 앱 언어: 설정에서 고른 것 → 없으면 기기 언어 */
    private fun applyLang() {
        L10n.lang = settings.lang ?: java.util.Locale.getDefault().language
    }

    private fun <T> load(name: String, ser: KSerializer<T>): T? {
        val f = File(dir ?: return null, name)
        if (!f.exists()) return null
        return runCatching { SplitsJson.decodeFromString(ser, f.readText()) }.getOrNull()
    }

    private fun <T> save(name: String, ser: KSerializer<T>, v: T) {
        if (demo) return
        val d = dir ?: return
        // 다 쓴 다음 바꿔 끼움 (쓰다가 꺼져도 예전 파일이 남게)
        val tmp = File(d, "$name.tmp")
        tmp.writeText(SplitsJson.encodeToString(ser, v))
        tmp.renameTo(File(d, name))
    }
}
