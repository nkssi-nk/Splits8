package com.nkssi.splits8

import android.app.Application
import android.content.Context
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContract
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.test.core.app.ApplicationProvider
import com.nkssi.splits8.screens.ScreenFor
import com.nkssi.splits8.shared.HRPoint
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RoutePt
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/** 가짜 Health Connect */
class FakeHealth(var st: Int = Health.READY, var perms: Set<String> = Health.perms, var b: HealthBody = HealthBody()) : HealthApi {
    val written = mutableListOf<HealthWorkout>()
    override fun status(ctx: Context) = st
    override suspend fun granted(ctx: Context) = perms
    override suspend fun body(ctx: Context) = b
    override suspend fun write(ctx: Context, w: HealthWorkout) { written += w }
    override fun contract() = object : ActivityResultContract<Set<String>, Set<String>>() {
        override fun createIntent(context: Context, input: Set<String>) = Intent("test.health")
        override fun parseResult(resultCode: Int, intent: Intent?) = perms
    }
}

/** Health Connect: 기록 → 저장할 값 · 폰 기록 저장 · 시작 화면 줄 · 가입 프로필 키/몸무게 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h1400dp-xxhdpi")
class HealthFlows {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()
    private val app: Application = ApplicationProvider.getApplicationContext()
    private lateinit var fake: FakeHealth
    private val t0 = Instant.parse("2026-10-10T00:00:00Z")

    @Before fun setUp() {
        GlowDrift.fixed = true
        L10n.lang = "en"
        Store.resetForTest(app)
        fake = FakeHealth()
        Health.api = fake
        Router.profileEdit = false; Router.signupFlow = false
    }

    @After fun tearDown() { Health.api = RealHealth; Router.profileEdit = false }

    private fun idle() { shadowOf(app.mainLooper).idle(); rule.waitForIdle() }

    private fun show(s: Scr) {
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
    }

    private fun rec(kind: String? = "run", id: String = "R1") = Record(
        id = id, mode = Mode.Training, title = "5K Run", date = t0, total = 600,
        segs = listOf(
            SegResult("run", "Run", "1KM", SegKind.Run, 300, 300, dist = 1010.0),
            SegResult("run", "Run", "1KM", SegKind.Run, 300, 300),            // 거리 못 잼 → 안 더함
        ),
        hr = listOf(HRPoint(30, 140), HRPoint(10, 120), HRPoint(900, 170), HRPoint(40, 0)),
        kcal = 88, avgHR = 140, maxHR = 170, division = "openMen", vsWord = "VS GOAL", kind = kind,
        route = listOf(RoutePt(37.5, 127.0, 20.0, 5), RoutePt(37.51, 127.01, null, 2), RoutePt(37.52, 127.02)),
    )

    @Test fun workoutValues() {
        val w = HealthWorkout.of(rec())
        assertEquals(ExerciseSessionRecord.EXERCISE_TYPE_RUNNING, w.type)
        assertEquals(t0, w.start)
        assertEquals(t0.plusSeconds(600), w.end)
        assertEquals(1010.0, w.meters!!, 0.01)
        assertEquals(88.0, w.kcal!!, 0.01)
        // 심박: 0 빼고, 시간 순서, 끝 시각 넘으면 끝 시각으로
        assertEquals(listOf(t0.plusSeconds(10), t0.plusSeconds(30), t0.plusSeconds(600)), w.hr.map { it.first })
        // 경로: 시각 있는 점만, 시간 순서
        assertEquals(listOf(2L, 5L), w.route.map { it.time.epochSecond - t0.epochSecond })
        assertEquals(ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING, HealthWorkout.of(rec("hiit")).type)
        assertEquals(ExerciseSessionRecord.EXERCISE_TYPE_RUNNING, HealthWorkout.of(rec(null)).type)   // HYROX 도 러닝 (아이폰과 같음)
        val noData = HealthWorkout.of(rec().copy(kcal = 0, segs = emptyList(), hr = emptyList()))
        assertNull(noData.meters); assertNull(noData.kcal); assertTrue(noData.hr.isEmpty())
    }

    @Test fun phoneRecordIsSavedOnce() {
        Store.addPhoneRecord(rec())
        idle()
        assertEquals(listOf("R1"), fake.written.map { it.id })
        Store.addPhoneRecord(rec())               // 같은 기록 다시 → 저장 안 함
        idle()
        assertEquals(1, fake.written.size)
        assertEquals("phone", Store.records.single().source)
    }

    @Test fun notSavedWithoutPermission() {
        fake.perms = Health.readPerms
        Store.addPhoneRecord(rec())
        idle()
        assertTrue(fake.written.isEmpty())
        fake.perms = Health.perms; fake.st = Health.NONE
        Store.addPhoneRecord(rec(id = "R2"))
        idle()
        assertTrue(fake.written.isEmpty())
        assertEquals(2, Store.records.size)       // 앱 기록은 그대로 저장
    }

    @Test fun onboardingRow() {
        show(Scr.Ob3)
        idle()
        rule.onNode(hasText("Allowed · heart rate, workouts")).assertIsDisplayed()

        fake.st = Health.NEEDS_INSTALL
        fake.perms = emptySet()
        Router.go(Scr.Ob2); idle(); Router.go(Scr.Ob3); idle()
        rule.onNode(hasText("Install Health Connect")).assertIsDisplayed()
        rule.onNodeWithTag("ob.health").performClick(); idle()
        val next = shadowOf(app).nextStartedActivity
        assertTrue(next.data.toString().contains(Health.PACKAGE))
    }

    @Test fun profileFilledFromHealth() {
        fake.b = HealthBody(181, 77.0)
        Router.startProfile(Scr.Home)
        Router.profileStep = 4
        show(Scr.ProfileSetup)
        idle()
        rule.onNodeWithTag("profile.fromHealth").assertIsDisplayed()
        rule.onNodeWithTag("profile.next").performClick(); idle()
        assertEquals(181, Store.settings.heightCm)
        assertEquals(77.0, Store.settings.weightKg!!, 0.01)
    }

    @Test fun profileNotFilledWithoutReadPermission() = runBlocking {
        fake.b = HealthBody(181, 77.0)
        fake.perms = Health.writePerms
        assertEquals(HealthBody(), Health.body(app))
    }
}
