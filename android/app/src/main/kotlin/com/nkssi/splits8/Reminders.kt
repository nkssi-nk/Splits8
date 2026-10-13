package com.nkssi.splits8

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.PlanReminder
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.RaceEvent
import java.time.Instant
import java.time.LocalTime

/**
 * 운동 예약 알림 · 대회 알림 (아이폰 Store.schedule · scheduleRaceReminders 와 같은 시각).
 * 안드로이드는 폰을 다시 켜면 알람이 지워져서, 켜질 때 다시 잡음 (BootReceiver)
 */
object Reminders {
    const val CHANNEL = "reminders"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    var context: Context? = null

    /** 알림 시각: 1시간 전 / 전날 오후 8시 / 일주일 전 같은 시각 */
    fun reminderDate(date: Instant, r: PlanReminder): Instant? = when (r) {
        PlanReminder.None -> null
        PlanReminder.HourBefore -> date.minusSeconds(3600)
        PlanReminder.DayBefore -> date.atZone(Fm.zone).toLocalDate().minusDays(1).atTime(LocalTime.of(20, 0)).atZone(Fm.zone).toInstant()
        PlanReminder.WeekBefore -> date.atZone(Fm.zone).minusDays(7).toInstant()
    }

    /** "Thu 15 Oct 7:00 AM" / "10월 15일 (목) 오전 7:00" */
    fun body(p: PlannedWorkout): String = Fm.wdm(p.date) + " " + Fm.time12(p.date)

    private fun alarms(c: Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pending(c: Context, id: String, title: String? = null, body: String? = null): PendingIntent {
        val i = Intent(c, ReminderReceiver::class.java).setAction("splits8.reminder.$id")
            .putExtra(EXTRA_ID, id).putExtra(EXTRA_TITLE, title).putExtra(EXTRA_BODY, body)
        return PendingIntent.getBroadcast(c, id.hashCode(), i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun set(c: Context, id: String, at: Instant, title: String, body: String) {
        if (!at.isAfter(Store.now())) return
        // 정확한 알람 권한 없이도 되는 방식 (몇 분 늦을 수 있음 — 운동 알림에는 충분)
        runCatching { alarms(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.toEpochMilli(), pending(c, id, title, body)) }
    }

    private fun clear(c: Context, id: String) = runCatching { alarms(c).cancel(pending(c, id)) }

    /** 예약 하나 알림 잡기 (이미 잡혀 있으면 바꿈) */
    fun schedule(p: PlannedWorkout) {
        val c = context ?: return
        clear(c, p.id)
        val fire = reminderDate(p.date, p.reminder) ?: return
        set(c, p.id, fire, p.title.l10nTitle(), body(p))
    }

    fun cancel(id: String) { context?.let { clear(it, id) } }

    /** 등록한 대회 알림 (일주일 전 · 전날 오후 8시). 대회를 바꾸면 다시 잡음 */
    fun scheduleRace(ev: RaceEvent) {
        val c = context ?: return
        clear(c, "race.week"); clear(c, "race.day")
        if (!ev.isSet) return
        reminderDate(ev.date, PlanReminder.WeekBefore)?.let { set(c, "race.week", it, ev.name, "D-7") }
        reminderDate(ev.date, PlanReminder.DayBefore)?.let { set(c, "race.day", it, ev.name, "D-1") }
    }

    /** 앞으로 남은 예약 · 대회 알림을 모두 다시 잡음 (폰을 다시 켰을 때) */
    fun rescheduleAll() {
        Store.plans.forEach { schedule(it) }
        scheduleRace(Store.settings.event)
    }

    private fun String.l10nTitle(): String = L10n.t(this)

    fun channel(c: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, L10n.t("Workout reminders"), NotificationManager.IMPORTANCE_HIGH))
    }

    /** 알림 허락 (Android 13 이상만 물어봄) */
    fun allowed(c: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
}

/** 알림을 켤 때 처음 한 번 허락을 물어보는 함수 (아이폰처럼 알림을 처음 켤 때) */
@Composable
fun rememberAskNotifications(): () -> Unit {
    val ctx = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    return {
        if (Build.VERSION.SDK_INT >= 33 && !Reminders.allowed(ctx)) runCatching { launcher.launch(Manifest.permission.POST_NOTIFICATIONS) }
    }
}

/** 알림 시각이 되면 알림을 띄움 (누르면 앱이 열림) */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (!Reminders.allowed(c)) return
        Reminders.channel(c)
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(c, Reminders.CHANNEL)
            .setSmallIcon(R.drawable.sym_stopwatch)
            .setContentTitle(i.getStringExtra(Reminders.EXTRA_TITLE) ?: "SPLITS8")
            .setContentText(i.getStringExtra(Reminders.EXTRA_BODY) ?: "")
            .setContentIntent(open).setAutoCancel(true).build()
        runCatching { c.getSystemService(NotificationManager::class.java).notify((i.getStringExtra(Reminders.EXTRA_ID) ?: "").hashCode(), n) }
    }
}

/** 폰을 다시 켜면 알림을 다시 잡음 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action != Intent.ACTION_BOOT_COMPLETED) return
        Store.init(c.applicationContext)
        Reminders.rescheduleAll()
    }
}

/**
 * 폰으로 기록하는 동안 (야외 GPS): 화면을 끄거나 다른 앱으로 가도 위치를 계속 받게 하는 서비스.
 * 알림 줄에 "운동 기록 중"이 떠 있음. 기록이 끝나면 멈춤
 */
class RunService : Service() {
    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(i: Intent?, flags: Int, id: Int): Int {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(NotificationChannel(CHANNEL, L10n.t("Workout in progress"), NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.sym_stopwatch)
            .setContentTitle(i?.getStringExtra("title") ?: "SPLITS8")
            .setContentText(L10n.t("Recording on your phone"))
            .setOngoing(true).setContentIntent(open).build()
        val ok = runCatching {
            if (Build.VERSION.SDK_INT >= 29) startForeground(7, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) else startForeground(7, n)
        }.isSuccess
        if (!ok) stopSelf()
        return START_NOT_STICKY
    }

    companion object {
        const val CHANNEL = "run"

        fun start(c: Context, title: String) {
            runCatching { ContextCompat.startForegroundService(c, Intent(c, RunService::class.java).putExtra("title", title)) }
        }

        fun stop(c: Context) {
            runCatching { c.stopService(Intent(c, RunService::class.java)) }
        }
    }
}
