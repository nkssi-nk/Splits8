package com.nkssi.splits8

import android.app.Application
import android.appwidget.AppWidgetManager
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.WidgetSnap
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.io.FileOutputStream
import java.time.LocalDateTime

/** 홈 화면 위젯 (그림 · 숫자 · 새로 그리기 · 누르면 열리는 곳) */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "xxhdpi")
class WidgetFlows {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val out = System.getProperty("shots.dir") ?: "build/shots"
    private fun at(y: Int, mo: Int, d: Int, h: Int = 9) = LocalDateTime.of(y, mo, d, h, 0).atZone(Fm.zone).toInstant()
    private val now = at(2026, 10, 15)          // 목요일

    @Before fun setUp() {
        L10n.lang = "en"
        Store.resetForTest(app)
        Store.now = { now }
    }

    @After fun tearDown() { Store.now = { java.time.Instant.now() } }

    private fun save(name: String, b: Bitmap) {
        File(out).mkdirs()
        FileOutputStream("$out/$name.png").use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test fun pictures() {
        val k = 3f
        save("80_widget_dday_small", WidgetArt.dday(app, WidgetSnap.demo(now, 45), now, 170f, 170f, k))
        save("80_widget_dday_small_10", WidgetArt.dday(app, WidgetSnap.demo(now, 10), now, 170f, 170f, k))
        save("80_widget_dday_small_day", WidgetArt.dday(app, WidgetSnap.demo(now, 0), now, 170f, 170f, k))
        save("81_widget_dday_medium", WidgetArt.dday(app, WidgetSnap.demo(now, 10), now, 360f, 170f, k))
        save("82_widget_norace", WidgetArt.dday(app, WidgetSnap(), now, 170f, 170f, k))
        save("83_widget_week_small", WidgetArt.week(app, WidgetSnap.demo(now), now, 170f, 170f, k))
        save("84_widget_week_medium", WidgetArt.week(app, WidgetSnap.demo(now), now, 360f, 170f, k))
        L10n.lang = "ko"
        save("85_widget_dday_medium_ko", WidgetArt.dday(app, WidgetSnap.demo(now, 3), now, 360f, 170f, k))
        save("86_widget_week_medium_ko", WidgetArt.week(app, WidgetSnap.demo(now), now, 360f, 170f, k))
        save("87_widget_week_small_empty_ko", WidgetArt.week(app, WidgetSnap(), now, 170f, 170f, k))
        // 위젯 고르는 화면의 미리보기 그림 (영어 · 2.5배)
        L10n.lang = "en"
        save("widget_dday_preview", WidgetArt.dday(app, WidgetSnap.demo(now, 10), now, 170f, 170f, 2.5f))
        save("widget_week_preview", WidgetArt.week(app, WidgetSnap.demo(now), now, 170f, 170f, 2.5f))
    }

    @Test fun weekNumbers() {
        val recs = Demo.records()
        // 이번 주 (12~18일): 13일 · 15일 기록 / 지난주 기록은 안 셈 / 미완료는 앱이 빼고 넘김
        val a = recs.first { it.mode == Mode.Sim }.copy(id = "a", date = at(2026, 10, 13))
        val b = recs.first { it.mode == Mode.Training }.copy(id = "b", date = at(2026, 10, 15, 7))
        val old = a.copy(id = "c", date = at(2026, 10, 10))
        val s = WidgetSnap.make(listOf(a, b, old), Store.settings, 4565, now)
        assertEquals(2, s.weekCount)
        assertEquals(a.total + b.total, s.weekSec)
        assertEquals("sim", s.dayMode[1]); assertEquals("training", s.dayMode[3]); assertEquals("", s.dayMode[0])
        assertEquals(a.total / 60, s.dayMin[1])
        assertEquals(java.time.LocalDate.of(2026, 10, 12), s.weekStart)
        // 다음 주가 되면 이번 주 숫자는 0
        val next = s.fresh(at(2026, 10, 20))
        assertEquals(0, next.weekCount)
    }

    @Test fun raceDaysAndStage() {
        Store.update { it.copy(event = RaceEvent("HYROX Seoul", "COEX", at(2026, 10, 25, 0))) }
        val s = Widgets.snap()
        assertEquals(10, s.daysLeft(now))
        assertEquals(2, WidgetSnap.stage(10)); assertEquals(3, WidgetSnap.stage(0)); assertEquals(1, WidgetSnap.stage(30)); assertEquals(0, WidgetSnap.stage(31))
        // 지난 대회는 안 보임
        Store.update { it.copy(event = RaceEvent("Old", "", at(2026, 10, 1, 0))) }
        assertNull(Widgets.snap().raceName)
    }

    @Test fun providerPutsPictureAndOpensRace() {
        val m = AppWidgetManager.getInstance(app)
        val sm = shadowOf(m)
        val id = sm.createWidget(DdayWidget::class.java, R.layout.widget_image)
        DdayWidget().onUpdate(app, m, intArrayOf(id))
        val v = sm.getViewFor(id)
        assertNotNull(v)
        val img = v.findViewById<android.widget.ImageView>(R.id.widget_image)
        assertNotNull(img.drawable)
        val week = sm.createWidget(WeekWidget::class.java, R.layout.widget_image)
        WeekWidget().onUpdate(app, m, intArrayOf(week))
        assertNotNull(sm.getViewFor(week).findViewById<android.widget.ImageView>(R.id.widget_image).drawable)
    }
}
