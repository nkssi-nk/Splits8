package com.nkssi.splits8

import android.content.Context
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.test.core.app.ApplicationProvider
import com.google.android.play.core.appupdate.testing.FakeAppUpdateManager
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** 4번: 앱 안 업데이트 안내 — Play 의 가짜 관리자(FakeAppUpdateManager)로 띠 표시 · 닫기 · 다시 시작 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class UpdateFlows {
    private val day = 24L * 3600 * 1000
    private lateinit var ctx: Context
    private lateinit var fake: FakeAppUpdateManager

    @Before fun setUp() {
        ctx = ApplicationProvider.getApplicationContext()
        Store.resetForTest(ctx)
        Store.update { it.copy(hasOnboarded = true) }
        Router.scr = Scr.Home
        Router.phoneRun = null
        AppUpdate.resetForTest()
        fake = FakeAppUpdateManager(ctx)
        AppUpdate.manager = fake
    }

    @After fun tearDown() {
        AppUpdate.resetForTest()
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    @Test fun showsAndDismissRemembersVersion() = runBlocking {
        fake.setUpdateAvailable(321)
        AppUpdate.check(ctx, 1_000L)
        assertEquals("available", AppUpdate.band)
        assertEquals(321, AppUpdate.availableCode)
        AppUpdate.dismiss()
        assertNull(AppUpdate.band)
        // 다음 날: 닫은 버전은 다시 안 띄움
        AppUpdate.check(ctx, 1_000L + day)
        assertNull(AppUpdate.band)
        // 더 새 버전은 띄움
        fake.setUpdateAvailable(331)
        AppUpdate.check(ctx, 1_000L + 2 * day)
        assertEquals("available", AppUpdate.band)
    }

    @Test fun checksOnlyOncePerDay() = runBlocking {
        fake.setUpdateNotAvailable()
        AppUpdate.check(ctx, 1_000L)
        assertNull(AppUpdate.band)
        fake.setUpdateAvailable(321)
        AppUpdate.check(ctx, 1_000L + 3600_000L)          // 같은 날 다시 켬 → 안 물어봄
        assertNull(AppUpdate.band)
        AppUpdate.check(ctx, 1_000L + day)
        assertEquals("available", AppUpdate.band)
    }

    @Test fun quietDuringOnboardingAndWorkout() = runBlocking {
        fake.setUpdateAvailable(321)
        Store.update { it.copy(hasOnboarded = false) }
        AppUpdate.check(ctx, 1_000L)
        assertNull(AppUpdate.band)
        Store.update { it.copy(hasOnboarded = true) }
        Router.scr = Scr.PhoneLive
        AppUpdate.check(ctx, 1_000L)
        assertNull(AppUpdate.band)
        // 안 물어봤으니 하루를 기다리지 않고 다음에 바로 확인
        Router.scr = Scr.Home
        AppUpdate.check(ctx, 1_000L)
        assertEquals("available", AppUpdate.band)
    }

    @Test fun flexibleUpdateThenRestart() = runBlocking {
        fake.setUpdateAvailable(321)
        AppUpdate.check(ctx, 1_000L)
        val act = Robolectric.buildActivity(ComponentActivity::class.java).setup().get()
        AppUpdate.start(act)
        assertNull(AppUpdate.band)
        assertTrue(fake.isConfirmationDialogVisible)
        fake.userAcceptsUpdate()
        fake.downloadStarts()
        fake.downloadCompletes()
        idle()
        assertEquals("ready", AppUpdate.band)
        AppUpdate.restart()
        assertNull(AppUpdate.band)
        assertTrue(fake.isInstallSplashScreenVisible)
    }
}
