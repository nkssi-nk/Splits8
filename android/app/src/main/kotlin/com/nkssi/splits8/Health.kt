package com.nkssi.splits8

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Health Connect (아이폰 "건강 앱" 자리).
 * - 운동 기록 저장: 운동 · 거리 · 활동 칼로리 · 심박 · 야외 러닝 경로
 *   (아이폰은 워치가 저장. 안드로이드 워치는 Health Connect 에 직접 못 넣어서 폰이 저장 — 폰 기록도 같이)
 * - 키 · 몸무게 읽기: 가입 프로필 4단계를 미리 채움 (아이폰 HealthProfile 과 같은 쓰임. 성별 · 태어난 해는 Health Connect 에 없음)
 */

/** Health Connect 에 넣을 운동 하나 — 기록에서 계산 (시험에서 확인) */
data class HealthWorkout(
    val id: String,
    val title: String,
    /** ExerciseSessionRecord.EXERCISE_TYPE_… */
    val type: Int,
    val start: Instant,
    val end: Instant,
    val kcal: Double?,
    /** 실제로 잰 러닝 거리(m) — GPS · 워치. 계획 거리(1KM 등)는 안 넣음 */
    val meters: Double?,
    /** (시각, bpm) */
    val hr: List<Pair<Instant, Long>>,
    /** (시각, 위도, 경도, 높이) */
    val route: List<HealthPt>,
) {
    companion object {
        fun of(r: Record): HealthWorkout {
            val start = r.date
            val end = r.end.takeIf { it.isAfter(start) } ?: start.plusSeconds(1)
            fun clamp(t: Int): Instant = start.plusSeconds(t.toLong()).let { if (it.isAfter(end)) end else it }
            val type = if (r.kind == "hiit") ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING
                else ExerciseSessionRecord.EXERCISE_TYPE_RUNNING          // 아이폰과 같음: HIIT 말고는 모두 러닝
            val m = r.segs.filter { it.kind == SegKind.Run }.mapNotNull { it.dist }.sum()
            val hr = r.hr.filter { it.b in 1..300 }.map { clamp(it.t) to it.b.toLong() }.distinctBy { it.first }.sortedBy { it.first }
            val route = r.route.orEmpty().filter { it.t != null }.map { HealthPt(clamp(it.t!!), it.a, it.o, it.h) }
                .distinctBy { it.time }.sortedBy { it.time }
            return HealthWorkout(r.id, r.title, type, start, end, r.kcal.takeIf { it > 0 }?.toDouble(), m.takeIf { it > 0 }, hr, route)
        }
    }
}

data class HealthPt(val time: Instant, val lat: Double, val lon: Double, val alt: Double?)

/** 키(cm) · 몸무게(kg) — 없으면 null */
data class HealthBody(val heightCm: Int? = null, val weightKg: Double? = null)

/** 실제 Health Connect ↔ 시험용 가짜를 바꿔 끼움 */
interface HealthApi {
    /** Health.NONE / NEEDS_INSTALL / READY */
    fun status(ctx: Context): Int
    suspend fun granted(ctx: Context): Set<String>
    suspend fun body(ctx: Context): HealthBody
    suspend fun write(ctx: Context, w: HealthWorkout)
    /** 허락 받기 화면 */
    fun contract(): ActivityResultContract<Set<String>, Set<String>>
}

object Health {
    const val NONE = 0
    const val NEEDS_INSTALL = 1
    const val READY = 2
    const val PACKAGE = "com.google.android.apps.healthdata"

    /** 저장에 꼭 필요한 것 */
    val writePerms: Set<String> = setOf(
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(DistanceRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE,
    )
    val readPerms: Set<String> = setOf(
        HealthPermission.getReadPermission(HeightRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
    )
    val perms: Set<String> = writePerms + readPerms

    var api: HealthApi = RealHealth
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    fun status(ctx: Context): Int = runCatching { api.status(ctx) }.getOrDefault(NONE)

    /** 운동 저장 허락을 받았는지 */
    suspend fun connected(ctx: Context): Boolean =
        status(ctx) == READY && runCatching { api.granted(ctx).containsAll(writePerms) }.getOrDefault(false)

    /** 폰 · 워치로 끝낸 기록을 Health Connect 에 저장 (허락 없거나 실패하면 조용히 넘어감) */
    fun save(r: Record) {
        val ctx = Reminders.context ?: return
        if (Store.demo) return
        scope.launch {
            if (!connected(ctx)) return@launch
            runCatching { api.write(ctx, HealthWorkout.of(r)) }
        }
    }

    /** 키 · 몸무게 (읽기 허락이 있을 때만 — 가입 중에 허락 창을 새로 띄우지 않음) */
    suspend fun body(ctx: Context): HealthBody {
        if (status(ctx) != READY) return HealthBody()
        val g = runCatching { api.granted(ctx) }.getOrDefault(emptySet())
        if (readPerms.none { it in g }) return HealthBody()
        return runCatching { api.body(ctx) }.getOrDefault(HealthBody())
    }

    /** Health Connect 설치 · 업데이트 (안드로이드 13 이하) — Play 스토어 */
    fun install(ctx: Context) {
        val uri = Uri.parse("market://details?id=$PACKAGE&url=healthconnect%3A%2F%2Fonboarding")
        runCatching {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage("com.android.vending").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.onFailure {
            runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$PACKAGE")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        }
    }
}

/** 진짜 Health Connect */
object RealHealth : HealthApi {
    override fun status(ctx: Context): Int = when (HealthConnectClient.getSdkStatus(ctx, Health.PACKAGE)) {
        HealthConnectClient.SDK_AVAILABLE -> Health.READY
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> Health.NEEDS_INSTALL
        else -> Health.NONE
    }

    private fun client(ctx: Context) = HealthConnectClient.getOrCreate(ctx)

    override suspend fun granted(ctx: Context): Set<String> = client(ctx).permissionController.getGrantedPermissions()

    override suspend fun body(ctx: Context): HealthBody {
        val c = client(ctx)
        val g = c.permissionController.getGrantedPermissions()
        val range = TimeRangeFilter.before(Instant.now())
        val h = if (HealthPermission.getReadPermission(HeightRecord::class) in g)
            c.readRecords(ReadRecordsRequest(HeightRecord::class, range, ascendingOrder = false, pageSize = 1)).records.firstOrNull()?.height?.inMeters
            else null
        val w = if (HealthPermission.getReadPermission(WeightRecord::class) in g)
            c.readRecords(ReadRecordsRequest(WeightRecord::class, range, ascendingOrder = false, pageSize = 1)).records.firstOrNull()?.weight?.inKilograms
            else null
        return HealthBody(h?.let { Math.round(it * 100).toInt() }, w?.let { Math.round(it).toDouble() })
    }

    override suspend fun write(ctx: Context, w: HealthWorkout) {
        val c = client(ctx)
        val g = c.permissionController.getGrantedPermissions()
        fun off(t: Instant): ZoneOffset = ZoneId.systemDefault().rules.getOffset(t)
        fun meta(part: String) = Metadata.activelyRecorded(Device(type = Device.TYPE_PHONE), clientRecordId = "splits8-${w.id}-$part")
        val so = off(w.start); val eo = off(w.end)
        val route = if (w.route.size >= 2 && HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE in g)
            ExerciseRoute(w.route.map { ExerciseRoute.Location(time = it.time, latitude = it.lat, longitude = it.lon, altitude = it.alt?.let { a -> Length.meters(a) }) })
            else null
        val list = buildList {
            add(ExerciseSessionRecord(startTime = w.start, startZoneOffset = so, endTime = w.end, endZoneOffset = eo, metadata = meta("session"),
                exerciseType = w.type, title = w.title, exerciseRoute = route))
            w.meters?.let { add(DistanceRecord(startTime = w.start, startZoneOffset = so, endTime = w.end, endZoneOffset = eo,
                distance = Length.meters(it), metadata = meta("distance"))) }
            w.kcal?.let { add(ActiveCaloriesBurnedRecord(startTime = w.start, startZoneOffset = so, endTime = w.end, endZoneOffset = eo,
                energy = Energy.kilocalories(it), metadata = meta("kcal"))) }
            if (w.hr.isNotEmpty()) add(HeartRateRecord(startTime = w.start, startZoneOffset = so, endTime = w.end, endZoneOffset = eo,
                samples = w.hr.map { HeartRateRecord.Sample(it.first, it.second) }, metadata = meta("hr")))
        }
        c.insertRecords(list)
    }

    override fun contract(): ActivityResultContract<Set<String>, Set<String>> = PermissionController.createRequestPermissionResultContract()
}

/**
 * Health Connect 의 "왜 이 데이터를 쓰나요" 버튼 → 개인정보 처리방침 웹페이지.
 * (Health Connect 가 이 화면이 있는 앱만 허락 창을 보여 줌)
 */
class HealthPrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://nkssi-nk.github.io/splits8/privacy.html"))) }
        finish()
    }
}
