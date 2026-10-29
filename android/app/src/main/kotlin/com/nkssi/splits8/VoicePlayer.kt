package com.nkssi.splits8

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.HandlerThread
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.VoiceCoach
import com.nkssi.splits8.shared.VoicePrefs
import java.io.File

// 19번: 음성 안내 재생 (폰). 무엇을 말할지는 shared VoiceCoach, 여기는 조각(assets/voice/ko/<id>.m4a)을 이어서 재생만.
// 워치 앱에도 같은 모양의 VoicePlayer 가 있음 (wear/VoicePlayer.kt)

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

/**
 * 폰으로 기록하는 운동(PhoneLiveView)의 음성 안내. 화면이 0.25초마다 엔진 상태를 넣어 줌.
 * 워치 운동을 폰에 같이 보여 줄 때(WatchLive)는 워치가 말하므로 여기를 부르지 않음
 */
object PhoneVoice {
    private var coach: VoiceCoach? = null
    private var key = 0L
    private var player: VoicePlayer? = null
    /** 18번: 시작 전 3 · 2 · 1 을 말한 coach (시작하면 이걸 그대로 씀 → "운동 시작" 을 다시 안 함) */
    private var counting: VoiceCoach? = null

    /** 18번: 타이머 운동(타바타 · EMOM · AMRAP) 시작 전 세기 음성. n = 3 · 2 · 1, 0 = 시작 */
    fun countdown(ctx: Context, n: Int, kind: String?) {
        if (n == 3 || counting == null) counting = VoiceCoach(VoicePrefs.of(Store.settings, L10n.isKorean))
        val line = counting?.countdown(n, kind) ?: return
        (player ?: VoicePlayer(ctx).also { player = it }).play(line)
    }

    fun observe(ctx: Context, eng: PhoneRunEngine, now: Long) {
        if (eng.startMs == 0L) return
        val c = coach?.takeIf { key == eng.startMs }
            ?: (counting ?: VoiceCoach(VoicePrefs.of(Store.settings, L10n.isKorean))).also { coach = it; key = eng.startMs; counting = null }
        val dist = when {
            eng.useGPS -> eng.totalDist
            eng.isRunKind -> eng.splits.size * 1000.0          // 실내: 1 km 마다 Next
            else -> null
        }
        // 끝났으면 기록의 총 시간 (AMRAP 이 정한 시간에 딱 끝났는지)
        val tot = if (eng.finished) eng.splits.sum() else eng.total(now)
        val o = VoiceCoach.Obs(eng.active, eng.finished, eng.running, eng.mode, eng.kind, eng.seq, eng.idx,
            eng.segEl(now), tot, dist, null, eng.cap, eng.segMs(now))
        val line = c.update(o, now) ?: return
        (player ?: VoicePlayer(ctx).also { player = it }).play(line)
    }
}
