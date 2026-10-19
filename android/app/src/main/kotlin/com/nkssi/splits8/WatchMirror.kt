package com.nkssi.splits8

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.Wearable
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LiveCommand
import com.nkssi.splits8.shared.LivePacket
import com.nkssi.splits8.shared.LiveState
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SyncKey
import com.nkssi.splits8.shared.l10n

/**
 * 워치 운동을 폰에서 같이 보기 (아이폰 Mirror.swift, 빌드 22 의 52번).
 * 워치가 "/live" 메시지로 LiveState 를 보내면(구간이 바뀔 때 + 5초마다) 여기서 받아
 * 화면(WatchLive) · 진행 중 알림(잠금 화면)에 보여 주고, 폰에서 누른 Next · Undo · Pause · End 를 워치로 보냄.
 * 기록은 워치가 끝낸 뒤 평소처럼 /record 로 도착함.
 */
object WatchMirror {
    /** 워치에서 받은 마지막 상태 */
    var state by mutableStateOf<LiveState?>(null)
        private set
    /** 그 상태를 받은 시각 (폰 시계, ms) */
    var received by mutableLongStateOf(0L)
        private set
    /** 같이 보는 중 */
    var on by mutableStateOf(false)
        private set
    /** 워치가 운동을 끝냄 → 기록을 기다리는 중 */
    var ended by mutableStateOf(false)
        private set
    /** 한동안 소식이 없음 (워치와 끊김) */
    var reconnecting by mutableStateOf(false)
        private set
    /** 워치에서 버림 → 기록이 안 오니 바로 홈으로 */
    var discarded by mutableStateOf(false)
        private set

    /** 보낼 곳 (워치 노드). 시험에서는 sink 로 */
    private var node: String? = null
    var testSink: ((LiveCommand) -> Unit)? = null
    var clock: () -> Long = { System.currentTimeMillis() }

    private val main = Handler(Looper.getMainLooper())
    private const val STALE_MS = 12_000L
    private const val CHANNEL = "watch_live"
    private const val NOTE_ID = 7001
    private var gen = 0
    private var lastNoteIdx = -1
    private var lastNoteRunning = true
    private var lastNoteAt = 0L
    private var lastNoteReconnecting = false

    private val watchdog = object : Runnable {
        override fun run() {
            if (!on || ended) return
            val stale = clock() - received > STALE_MS
            if (stale != reconnecting) { reconnecting = stale; note(force = true) }
            main.postDelayed(this, 2000)
        }
    }

    /** 워치에서 온 메시지 */
    fun received(bytes: ByteArray, from: String?) {
        val p = LivePacket.read(bytes) ?: return
        val st = p.state ?: return
        // 설정 › Device › Show on phone 을 끄면 화면 · 알림 없음 (워치도 안 보내지만 한 번 더 막음)
        if (!Store.settings.mirror) return
        node = from ?: node
        apply(st)
    }

    fun apply(st: LiveState) {
        if (st.discarded) { discardedOnWatch(); return }
        val first = !on || state == null
        if (first) attach()
        state = st
        received = clock()
        reconnecting = false
        if (st.finished && !ended) {
            ended = true
            // 저장 중… → 15초 안에 기록이 안 오면 홈으로
            val g = gen
            main.postDelayed({ if (g == gen && Router.scr == Scr.WatchLive && Router.finish == null) Router.go(Scr.Home) }, 15_000)
        }
        note(force = first || st.finished)
    }

    private fun attach() {
        gen++
        on = true; ended = false; reconnecting = false; discarded = false
        main.removeCallbacks(watchdog)
        main.postDelayed(watchdog, 2000)
        // 폰으로 직접 기록 중이면 화면을 바꾸지 않음
        if (Router.scr != Scr.PhoneLive && Router.finish == null) Router.go(Scr.WatchLive)
    }

    /** 워치에서 버림 (LiveState.discarded) */
    fun discardedOnWatch() {
        if (!on) return
        discarded = true; on = false; ended = true
        main.removeCallbacks(watchdog)
        cancelNote()
        val g = gen
        main.postDelayed({ if (g == gen && Router.scr == Scr.WatchLive && Router.finish == null) Router.go(Scr.Home) }, 1500)
    }

    /** 기록이 도착함 → 같이 보기 끝. 빌드 27: 방금 끝난 운동 알림은 5초 타이머가 지움, 그 밖에 남은 알림은 바로 지움 */
    fun recordArrived(r: Record) {
        if (!on && !ended) { cleanLeftover(); return }
        val finishedNow = state?.finished == true
        on = false; ended = true
        main.removeCallbacks(watchdog)
        if (!finishedNow) cancelNote()
    }

    /** 빌드 27: 앱을 켤 때 — 지난번에 끝내지 못하고 남은 진행 중 알림 정리 (앱이 꺼졌거나 끝 소식을 못 받은 경우) */
    fun cleanLeftover() {
        if (on && !ended) return
        if (Store.demo) return
        cancelNote()
    }

    /** 폰에서 누른 단추를 워치로 */
    fun send(c: LiveCommand) {
        if (!on || ended) return
        testSink?.let { it(c); return }
        val ctx = Reminders.context ?: return
        val bytes = LivePacket(command = c).bytes()
        val to = node
        if (to != null) {
            Wearable.getMessageClient(ctx).sendMessage(to, SyncKey.live, bytes)
        } else {
            Wearable.getNodeClient(ctx).connectedNodes.addOnSuccessListener { ns ->
                ns.forEach { Wearable.getMessageClient(ctx).sendMessage(it.id, SyncKey.live, bytes) }
            }
        }
    }

    /** 시험 · 화면 사진용 */
    fun reset() {
        gen++
        state = null; on = false; ended = false; reconnecting = false; discarded = false; node = null
        main.removeCallbacks(watchdog)
    }

    fun demo(st: LiveState, reconnect: Boolean = false) {
        state = st; received = clock(); on = true; ended = st.finished; reconnecting = reconnect; discarded = false
    }

    // MARK: 진행 중 알림 (잠금 화면) — 구간 · 멈춤이 바뀌면 바로, 그 밖에는 15초에 한 번

    private fun note(force: Boolean) {
        val ctx = Reminders.context ?: return
        if (Store.demo) return
        val st = state ?: return
        val now = clock()
        val changed = st.idx != lastNoteIdx || st.running != lastNoteRunning || reconnecting != lastNoteReconnecting
        if (!force && !changed && now - lastNoteAt < 15_000) return
        lastNoteIdx = st.idx; lastNoteRunning = st.running; lastNoteAt = now; lastNoteReconnecting = reconnecting
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, L10n.t("Watch workout"), NotificationManager.IMPORTANCE_LOW))
        }
        if (st.finished) {
            // 빌드 27: 운동이 끝나면 "끝" 알림으로 바꾸고 5초 뒤 사라짐 (아이폰 잠금 화면 카드와 같음)
            nm.notify(NOTE_ID, buildFinished(ctx, st))
            val g = gen
            main.postDelayed({ if (g == gen || !on) cancelNote() }, 5_000)
            return
        }
        nm.notify(NOTE_ID, build(ctx, st, now))
    }

    private fun build(ctx: Context, st: LiveState, now: Long): Notification {
        val open = PendingIntent.getActivity(ctx, 0,
            Intent(ctx, MainActivity::class.java).putExtra("open", "watchLive").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val cur = st.cur
        val title = (if (st.mode == Mode.Training) st.title else st.mode.title.l10n)
        val seg = st.segEl(now, received)
        val tot = st.total(now, received)
        val line = buildString {
            if (cur != null) append(cur.name)
            if (st.hr > 0) append(" · ♥ ${st.hr}")
            if (reconnecting) append(" · " + L10n.t("Reconnecting…"))
        }
        val b = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.sym_stopwatch)
            .setContentTitle(title + " · " + Fm.t(tot))
            .setContentText(line)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open)
        // 지금 구간 시간을 시계처럼 저절로 흐르게 (멈춤이면 고정)
        if (st.running) b.setUsesChronometer(true).setWhen(now - seg * 1000L).setShowWhen(true)
        else b.setShowWhen(false).setSubText(L10n.t("Paused"))
        return b.build()
    }

    /** 끝난 운동: 총 시간 고정 · 스와이프로 지울 수 있음 · 5초 뒤 저절로 사라짐 */
    private fun buildFinished(ctx: Context, st: LiveState): Notification {
        val open = PendingIntent.getActivity(ctx, 0,
            Intent(ctx, MainActivity::class.java).putExtra("open", "watchLive").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val title = (if (st.mode == Mode.Training) st.title else st.mode.title.l10n)
        return NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.sym_stopwatch)
            .setContentTitle(title + " · " + Fm.t(st.splits.sum()))
            .setContentText(L10n.t("Done"))
            .setOngoing(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setTimeoutAfter(5_000)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .build()
    }

    private fun cancelNote() {
        val ctx = Reminders.context ?: return
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)?.cancel(NOTE_ID)
        lastNoteIdx = -1
    }
}
