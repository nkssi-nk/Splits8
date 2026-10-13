package com.nkssi.splits8

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PlanReminder
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.RaceEvent
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.LocalDateTime

/** 운동 예약 · 대회 알림 (시각 · 알림 띄우기 · 지우기 · 폰을 다시 켰을 때) */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ReminderFlows {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val alarms get() = shadowOf(app.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
    private fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int) = LocalDateTime.of(y, mo, d, h, mi).atZone(Fm.zone).toInstant()

    @Before fun setUp() {
        L10n.lang = "en"
        Store.resetForTest(app)
        Store.now = { at(2026, 10, 13, 9, 0) }
        shadowOf(app).grantPermissions(android.Manifest.permission.POST_NOTIFICATIONS)
    }

    @After fun tearDown() { Store.now = { java.time.Instant.now() } }

    @Test fun reminderTimesMatchIphone() {
        val w = at(2026, 10, 20, 7, 0)
        assertEquals(at(2026, 10, 20, 6, 0), Reminders.reminderDate(w, PlanReminder.HourBefore))
        assertEquals(at(2026, 10, 19, 20, 0), Reminders.reminderDate(w, PlanReminder.DayBefore))
        assertEquals(at(2026, 10, 13, 7, 0), Reminders.reminderDate(w, PlanReminder.WeekBefore))
        assertNull(Reminders.reminderDate(w, PlanReminder.None))
    }

    @Test fun savingAPlanSetsTheAlarmAndDeletingClearsIt() {
        val p = PlannedWorkout(id = "p1", mode = Mode.Training, title = "Sled Intervals", date = at(2026, 10, 20, 7, 0), reminder = PlanReminder.DayBefore)
        Store.savePlan(p)
        assertEquals(1, alarms.scheduledAlarms.size)
        assertEquals(at(2026, 10, 19, 20, 0).toEpochMilli(), alarms.scheduledAlarms[0].triggerAtTime)
        Store.savePlan(p.copy(reminder = PlanReminder.HourBefore))          // 바꾸면 하나만 (새 시각)
        assertEquals(1, alarms.scheduledAlarms.size)
        assertEquals(at(2026, 10, 20, 6, 0).toEpochMilli(), alarms.scheduledAlarms[0].triggerAtTime)
        Store.deletePlan("p1")
        assertEquals(0, alarms.scheduledAlarms.size)
    }

    @Test fun pastReminderIsSkipped() {
        // 내일 아침 운동의 "일주일 전" 알림은 이미 지남 → 안 잡음
        Store.savePlan(PlannedWorkout(id = "p2", mode = Mode.Sim, title = "Full Simulation", date = at(2026, 10, 14, 7, 0), reminder = PlanReminder.WeekBefore))
        assertEquals(0, alarms.scheduledAlarms.size)
    }

    @Test fun raceGetsWeekAndDayBefore() {
        Store.update { it.copy(event = RaceEvent(name = "HYROX Seoul", loc = "COEX", date = at(2026, 11, 13, 0, 0))) }
        val times = alarms.scheduledAlarms.map { it.triggerAtTime }.sorted()
        assertEquals(listOf(at(2026, 11, 6, 0, 0).toEpochMilli(), at(2026, 11, 12, 20, 0).toEpochMilli()), times)
    }

    @Test fun alarmShowsNotification() {
        val i = Intent(app, ReminderReceiver::class.java).putExtra(Reminders.EXTRA_ID, "p1")
            .putExtra(Reminders.EXTRA_TITLE, "Sled Intervals").putExtra(Reminders.EXTRA_BODY, "Tue 20 Oct 7:00 AM")
        ReminderReceiver().onReceive(app, i)
        val n = shadowOf(app.getSystemService(NotificationManager::class.java)).allNotifications.single()
        assertEquals("Sled Intervals", shadowOf(n).contentTitle)
        assertEquals("Tue 20 Oct 7:00 AM", shadowOf(n).contentText)
    }

    @Test fun rebootRearmsEverything() {
        Store.savePlan(PlannedWorkout(id = "p3", mode = Mode.Training, title = "Run", date = at(2026, 10, 20, 7, 0)))
        Store.update { it.copy(event = RaceEvent(name = "HYROX Seoul", loc = "COEX", date = at(2026, 11, 13, 0, 0))) }
        alarms.scheduledAlarms.toList().forEach { (app.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(it.operation!!) }
        assertEquals(0, alarms.scheduledAlarms.size)
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(3, alarms.scheduledAlarms.size)
    }

    @Test fun runServiceShowsOngoingNotification() {
        val c = org.robolectric.Robolectric.buildService(RunService::class.java, Intent(app, RunService::class.java).putExtra("title", "Easy 5K"))
            .create().startCommand(0, 1).get()
        val n = shadowOf(c).lastForegroundNotification
        assertEquals("Easy 5K", shadowOf(n).contentTitle)
        assertEquals("Recording on your phone", shadowOf(n).contentText)
    }
}
