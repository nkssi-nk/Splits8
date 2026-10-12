package com.nkssi.splits8

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
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

    /** 기록 계산 (PB · 최고 · 비교 …). 기록 · 설정이 바뀌면 새로 만듦 */
    var book by mutableStateOf(RecordBook(emptyList(), Settings()))
        private set

    val friend: Friend? get() = friends.firstOrNull { it.id == settings.friendId }
    val signedIn: Boolean get() = settings.signedIn

    fun init(context: Context) {
        if (dir != null) return
        dir = context.filesDir
        settings = load("settings.json", Settings.serializer()) ?: Settings()
        programs = load("programs.json", ListSerializer(Program.serializer())) ?: Program.presets()
        records = load("records.json", ListSerializer(Record.serializer())) ?: emptyList()
        friends = load("friends.json", ListSerializer(Friend.serializer())) ?: emptyList()
        plans = load("plans.json", ListSerializer(PlannedWorkout.serializer())) ?: emptyList()
        applyLang()
        rebuild()
    }

    /** 화면 확인용: 예시 데이터로 채움 (파일에 안 씀) */
    fun useDemo(s: Settings, p: List<Program>, r: List<Record>, f: List<Friend> = emptyList()) {
        demo = true
        settings = s; programs = p; records = r; friends = f; plans = emptyList()
        applyLang()
        rebuild()
    }

    fun update(f: (Settings) -> Settings) {
        settings = f(settings)
        applyLang()
        rebuild()
        save("settings.json", Settings.serializer(), settings)
    }

    fun saveProgram(p: Program) {
        programs = if (programs.any { it.id == p.id }) programs.map { if (it.id == p.id) p else it } else programs + p
        save("programs.json", ListSerializer(Program.serializer()), programs)
    }

    fun deleteProgram(id: String) {
        programs = programs.filterNot { it.id == id }
        save("programs.json", ListSerializer(Program.serializer()), programs)
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
