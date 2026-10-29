package com.nkssi.splits8.wear

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.HandlerThread
import com.nkssi.splits8.shared.VoiceCoach
import java.io.File

// 19번: 음성 안내 재생 (워치 — 스피커 또는 연결된 이어폰). 폰 앱 VoicePlayer.kt 와 같은 것.
// 무엇을 말할지는 shared VoiceCoach (WorkoutEngine 이 부름). 조각은 폰 앱 assets 폴더를 빌드할 때 같이 넣음 (build.gradle.kts)

/**
 * 조각 여러 개를 사이 0.12초로 이어서 재생. 말하는 동안만 소리 초점을 잠깐 받아서(다른 음악은 작아짐) 끝나면 돌려줌.
 * 구간 안내(Event)가 오면 기다리던 · 말하던 응원은 버림. 응원은 다른 말이 있으면 기다리지 않고 버림.
 * 모든 일은 "voice" 스레드 하나에서 (준비하느라 화면이 끊기지 않게)
 */
class VoicePlayer(context: Context) {
    private val app = context.applicationContext
    private val thread = HandlerThread("voice").apply { start() }
    private val h = Handler(thread.looper)
    private val am = app.getSystemService(AudioManager::class.java)
    private val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(attrs)
        .setOnAudioFocusChangeListener({ }, h)
        .build()

    private val queue = ArrayDeque<VoiceCoach.Line>()
    private var cur: VoiceCoach.Line? = null
    private var players: List<MediaPlayer> = emptyList()
    /** 줄이 바뀔 때마다 +1 (멈춘 줄의 늦은 콜백 무시) */
    private var gen = 0
    private var hasFocus = false

    fun play(line: VoiceCoach.Line) {
        if (line.clips.isEmpty()) return
        h.post { enqueue(line) }
    }

    private fun enqueue(line: VoiceCoach.Line) {
        if (line.pri == VoiceCoach.Pri.Event) {
            queue.removeAll { it.pri == VoiceCoach.Pri.Cheer }
            if (cur?.pri == VoiceCoach.Pri.Cheer) stopCurrent()
        } else if (cur != null || queue.isNotEmpty()) {
            return
        }
        queue.addLast(line)
        if (cur == null) next()
    }

    private fun next() {
        val line = queue.removeFirstOrNull()
        if (line == null) { dropFocus(); return }
        val ps = line.clips.mapNotNull { open(it) }
        if (ps.isEmpty()) { next(); return }
        if (!hasFocus) hasFocus = runCatching { am?.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED }.getOrDefault(false)
        if (!hasFocus) {                       // 전화 중 등: 이번 줄은 버림
            ps.forEach { runCatching { it.release() } }
            queue.clear()
            return
        }
        cur = line
        players = ps
        startAt(++gen, 0)
    }

    private fun startAt(g: Int, i: Int) {
        if (g != gen) return
        val p = players.getOrNull(i) ?: run { lineDone(g); return }
        p.setOnCompletionListener { if (g == gen) h.postDelayed({ startAt(g, i + 1) }, GAP_MS) }
        p.setOnErrorListener { _, _, _ -> if (g == gen) h.post { startAt(g, i + 1) }; true }
        runCatching { p.start() }.onFailure { h.post { startAt(g, i + 1) } }
    }

    private fun lineDone(g: Int) {
        if (g != gen) return
        releasePlayers()
        cur = null
        next()
    }

    private fun stopCurrent() {
        gen++
        players.forEach { runCatching { it.stop() } }
        releasePlayers()
        cur = null
    }

    private fun releasePlayers() {
        players.forEach { runCatching { it.release() } }
        players = emptyList()
    }

    private fun dropFocus() {
        if (!hasFocus) return
        hasFocus = false
        runCatching { am?.abandonAudioFocusRequest(focus) }
    }

    /** 조각 하나 준비 (없으면 null). m4a 는 압축 안 하고 넣어져서 바로 열림, 안 되면 임시 파일로 */
    private fun open(id: String): MediaPlayer? {
        val path = "voice/ko/$id.m4a"
        val mp = MediaPlayer()
        return runCatching {
            mp.setAudioAttributes(attrs)
            val fromFd = runCatching {
                app.assets.openFd(path).use { fd -> mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            }.isSuccess
            if (!fromFd) {
                mp.reset()
                mp.setAudioAttributes(attrs)
                val f = File(app.cacheDir, "voice_$id.m4a")
                if (!f.exists()) app.assets.open(path).use { inp -> f.outputStream().use { inp.copyTo(it) } }
                mp.setDataSource(f.absolutePath)
            }
            mp.prepare()
            mp
        }.getOrElse { runCatching { mp.release() }; null }
    }

    companion object {
        /** 조각 사이 틈 (ms) */
        const val GAP_MS = 120L
    }
}

/** 워치 앱 하나에 재생기 하나 */
object WearVoice {
    @Volatile private var p: VoicePlayer? = null
    fun get(c: Context): VoicePlayer = p ?: synchronized(this) { p ?: VoicePlayer(c).also { p = it } }
}
