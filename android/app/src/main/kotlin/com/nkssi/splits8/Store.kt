package com.nkssi.splits8

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.asImageBitmap
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
 * 서버 · 워치 · 알림은 다음 단계에서 붙임.
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

    /** 내 프로필 사진 (앱 폴더 avatar.jpg, 720×720 정사각). 서버 올리기는 5단계 */
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
    val signedIn: Boolean get() = settings.signedIn

    fun init(context: Context) {
        if (dir != null) return
        dir = context.filesDir
        prefs = context.getSharedPreferences("splits8", Context.MODE_PRIVATE)
        settings = load("settings.json", Settings.serializer()) ?: Settings()
        programs = load("programs.json", ListSerializer(Program.serializer())) ?: Program.presets()
        records = load("records.json", ListSerializer(Record.serializer())) ?: emptyList()
        friends = load("friends.json", ListSerializer(Friend.serializer())) ?: emptyList()
        plans = load("plans.json", ListSerializer(PlannedWorkout.serializer())) ?: emptyList()
        photo = runCatching { android.graphics.BitmapFactory.decodeFile(File(dir, "avatar.jpg").path)?.asImageBitmap() }.getOrNull()
        applyLang()
        rebuild()
    }

    /** 화면 확인용: 예시 데이터로 채움 (파일에 안 씀) */
    fun useDemo(
        s: Settings, p: List<Program>, r: List<Record>, f: List<Friend> = emptyList(),
        lb: List<LBRow> = emptyList(), req: List<FriendReq> = emptyList(), me: String? = null,
        pl: List<PlannedWorkout> = emptyList(),
    ) {
        demo = true
        settings = s; programs = p; records = r; friends = f; plans = pl
        leaderboard = lb; requests = req; myId = me; memPrefs.clear()
        applyLang()
        rebuild()
    }

    fun plans(on: java.time.LocalDate): List<PlannedWorkout> =
        plans.filter { it.date.atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate() == on }

    fun records(on: java.time.LocalDate): List<Record> =
        records.filter { it.date.atZone(com.nkssi.splits8.shared.Fm.zone).toLocalDate() == on }.sortedByDescending { it.date }

    fun update(f: (Settings) -> Settings) {
        settings = f(settings)
        applyLang()
        rebuild()
        save("settings.json", Settings.serializer(), settings)
    }

    /** 트레이닝 저장 (같은 id 면 바꿈, 새것은 맨 위 — 아이폰과 같음) */
    fun saveProgram(p: Program) {
        programs = if (programs.any { it.id == p.id }) programs.map { if (it.id == p.id) p else it } else listOf(p) + programs
        save("programs.json", ListSerializer(Program.serializer()), programs)
    }

    fun deleteProgram(id: String) {
        programs = programs.filterNot { it.id == id }
        save("programs.json", ListSerializer(Program.serializer()), programs)
    }

    /** 운동 예약 추가 · 수정 (같은 id 면 바꿈). 알림은 6단계에서 붙임 */
    fun savePlan(p: PlannedWorkout) {
        plans = (if (plans.any { it.id == p.id }) plans.map { if (it.id == p.id) p else it } else plans + p).sortedBy { it.date }
        save("plans.json", ListSerializer(PlannedWorkout.serializer()), plans)
    }

    fun deletePlan(id: String) {
        plans = plans.filterNot { it.id == id }
        save("plans.json", ListSerializer(PlannedWorkout.serializer()), plans)
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
    fun setPhoto(src: android.graphics.Bitmap?) {
        val f = dir?.let { File(it, "avatar.jpg") }
        if (src == null) {
            photo = null
            if (!demo) f?.delete()
            return
        }
        val side = minOf(src.width, src.height)
        val sq = android.graphics.Bitmap.createBitmap(src, (src.width - side) / 2, (src.height - side) / 2, side, side)
        val out = android.graphics.Bitmap.createScaledBitmap(sq, 720, 720, true)
        photo = out.asImageBitmap()
        if (!demo && f != null) runCatching { f.outputStream().use { out.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, it) } }
    }

    /** 로그아웃: 이 기기에서 계정 정보만 지움. 기록 · 트레이닝 · 설정(프로필 포함)은 그대로 (서버 로그아웃은 5단계) */
    fun signOut() {
        update { it.copy(nickname = null, email = null, signMethod = null) }
        friends = emptyList(); leaderboard = emptyList(); requests = emptyList(); myId = null
        save("friends.json", ListSerializer(Friend.serializer()), friends)
    }

    /** 백업 파일 글자 (아이폰과 같은 모양) */
    fun backupJson(): String = com.nkssi.splits8.shared.BackupFile(exportedAt = now(), records = records, programs = programs).json()

    /** 백업 가져오기: 없는 기록 · 트레이닝만 더함. 파일이 SPLITS8 백업이 아니면 null, 아니면 (기록 수, 트레이닝 수) */
    fun importBackup(text: String): Pair<Int, Int>? {
        val b = com.nkssi.splits8.shared.BackupFile.read(text) ?: return null
        val (r, nr) = com.nkssi.splits8.shared.BackupFile.mergeRecords(b.records, records)
        val (p, np) = com.nkssi.splits8.shared.BackupFile.mergePrograms(b.programs, programs, Program.freeLimit)
        if (nr > 0) { records = r; rebuild(); save("records.json", ListSerializer(Record.serializer()), records) }
        if (np > 0) { programs = p; save("programs.json", ListSerializer(Program.serializer()), programs) }
        return nr to np
    }

    fun add(r: Record) {
        if (records.any { it.id.equals(r.id, ignoreCase = true) }) return
        records = records + r
        rebuild()
        save("records.json", ListSerializer(Record.serializer()), records)
    }

    fun delete(r: Record) {
        records = records.filterNot { it.id == r.id }
        rebuild()
        save("records.json", ListSerializer(Record.serializer()), records)
    }

    private fun rebuild() {
        book = RecordBook(records, settings, friend)
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
