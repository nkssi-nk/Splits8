package com.nkssi.splits8.wear

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.health.services.client.data.LocationAccuracy
import androidx.health.services.client.endExercise
import androidx.health.services.client.getCapabilities
import androidx.health.services.client.getCurrentExerciseInfo
import androidx.health.services.client.pauseExercise
import androidx.health.services.client.resumeExercise
import androidx.health.services.client.startExercise
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.l10n
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

// 워치 운동 측정 (아이폰 HKWorkoutSession · HKLiveWorkoutBuilder 자리) — Health Services ExerciseClient.
// 워치 전체에서 운동 기록은 한 번에 앱 하나만 → 삼성 헬스 운동이 켜져 있으면 시작 전에 알려 줌(otherAppRecording).
// 기록은 폰 앱이 Health Connect 에 저장함 (워치는 직접 못 넣음).

class HealthSensors(private val context: Context) : WorkoutSensors {
    private val client = HealthServices.getClient(context).exerciseClient
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var sink: SensorSink? = null
    private val main = Handler(Looper.getMainLooper())
    private var placeAsked = false

    private val callback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val s = sink ?: return
            val m = update.latestMetrics
            // 측정 시각 = 지금 시계 − (켜진 뒤 지난 시간 − 측정한 때의 켜진 뒤 시간)
            fun wall(fromBootMs: Long) = System.currentTimeMillis() - (android.os.SystemClock.elapsedRealtime() - fromBootMs)
            m.getData(DataType.HEART_RATE_BPM).lastOrNull()?.let { p ->
                val at = wall(p.timeDurationFromBoot.toMillis())
                if (p.value > 0) main.post { s.gotHR(p.value, at) }
            }
            m.getData(DataType.CALORIES_TOTAL)?.total?.let { v -> main.post { s.gotEnergy(v) } }
            m.getData(DataType.DISTANCE_TOTAL)?.total?.let { v -> main.post { s.gotDistance(v) } }
            m.getData(DataType.STEPS_TOTAL)?.total?.let { v -> main.post { s.gotSteps(v.toDouble()) } }
            for (p in m.getData(DataType.LOCATION)) {
                val loc = p.value
                val acc = (p.accuracy as? LocationAccuracy)?.horizontalPositionErrorMeters?.toFloat() ?: 10f
                val vAcc = (p.accuracy as? LocationAccuracy)?.verticalPositionErrorMeters?.toFloat()
                val at = wall(p.timeDurationFromBoot.toMillis())
                main.post { s.gotLocation(loc.latitude, loc.longitude, acc, loc.altitude.takeIf { !it.isNaN() }, vAcc, at) }
                if (!placeAsked) { placeAsked = true; lookupPlace(loc.latitude, loc.longitude) }
            }
        }
        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
        override fun onRegistered() {}
        override fun onRegistrationFailed(throwable: Throwable) {}
        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
    }

    override fun start(cfg: ExerciseCfg, sink: SensorSink) {
        this.sink = sink
        placeAsked = false
        client.setUpdateCallback(callback)
        scope.launch {
            runCatching {
                val type = when {
                    cfg.hiit -> ExerciseType.HIGH_INTENSITY_INTERVAL_TRAINING
                    cfg.gps -> ExerciseType.RUNNING
                    else -> ExerciseType.RUNNING_TREADMILL
                }
                // 기기마다 되는 항목이 다름 → 되는 것만 고름
                val caps = client.getCapabilities()
                val supported = caps.getExerciseTypeCapabilities(type).supportedDataTypes
                val want = buildSet<DataType<*, *>> {
                    add(DataType.HEART_RATE_BPM); add(DataType.CALORIES_TOTAL); add(DataType.DISTANCE_TOTAL)
                    if (cfg.steps) add(DataType.STEPS_TOTAL)
                    if (cfg.gps) add(DataType.LOCATION)
                }.filter { it in supported }.toSet()
                val config = ExerciseConfig.builder(type)
                    .setDataTypes(want)
                    .setIsAutoPauseAndResumeEnabled(false)
                    .setIsGpsEnabled(cfg.gps && DataType.LOCATION in want)
                    .build()
                client.startExercise(config)
            }
            // 실내: 동네 이름은 마지막으로 알던 위치로
            if (!cfg.gps) lastKnownPlace()
        }
    }

    override fun pause() { scope.launch { runCatching { client.pauseExercise() } } }
    override fun resume() { scope.launch { runCatching { client.resumeExercise() } } }

    override fun end(save: Boolean) {
        sink = null
        scope.launch {
            runCatching { client.endExercise() }
            runCatching { client.clearUpdateCallbackAsync(callback) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun lastKnownPlace() {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? android.location.LocationManager ?: return
        val last = listOf(android.location.LocationManager.GPS_PROVIDER, android.location.LocationManager.NETWORK_PROVIDER, android.location.LocationManager.PASSIVE_PROVIDER)
            .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }.maxByOrNull { it.time } ?: return
        lookupPlace(last.latitude, last.longitude)
    }

    /** 동 + 시 (폰과 같은 모양 "역삼동, 서울"). 워치에 Geocoder 가 없으면 빈칸 — 폰이 기록을 받을 때 채우지 않음 */
    @Suppress("DEPRECATION")
    private fun lookupPlace(lat: Double, lon: Double) {
        if (!Geocoder.isPresent()) return
        scope.launch {
            val name = withContext(Dispatchers.IO) {
                runCatching {
                    val a = Geocoder(context, Locale.getDefault()).getFromLocation(lat, lon, 1)?.firstOrNull() ?: return@runCatching null
                    placeLabel(a.subLocality, a.locality ?: a.adminArea)
                }.getOrNull()
            }
            name?.let { n -> sink?.gotPlace(n) }
        }
    }

    companion object {
        /** 다른 앱(삼성 헬스 등)이 지금 운동을 기록 중인지 */
        suspend fun otherAppRecording(context: Context): Boolean = runCatching {
            HealthServices.getClient(context).exerciseClient.getCurrentExerciseInfo().exerciseTrackedStatus == ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS
        }.getOrDefault(false)
    }
}

/** "서울특별시" → "서울" (폰 placeLabel 과 같음) */
fun placeLabel(sub: String?, city: String?): String? {
    var c = city
    if (c != null) for (suf in listOf("특별자치시", "특별자치도", "특별시", "광역시")) if (c!!.endsWith(suf)) { c = c.dropLast(suf.length); break }
    val parts = listOfNotNull(sub, c).filter { it.isNotEmpty() }.distinct()
    return if (parts.isEmpty()) null else parts.joinToString(", ")
}

/**
 * 운동 중 계속 돌아가는 서비스: 화면이 꺼지거나 다른 화면으로 가도 측정 · 시간이 이어짐.
 * 시계 화면 아래에 "운동 중" 표시(Ongoing Activity)가 떠서 누르면 앱으로 돌아옴. 1초마다 엔진의 tick().
 */
class WorkoutService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var ticker: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val e = WatchStore.engine
        val note = notification(e)
        val gps = e.outdoorRun || (e.mode != Mode.Race && WatchStore.settings.runMode == "outdoor" && !e.isHIIT)
        var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        if (gps && hasLocation()) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        runCatching { startForeground(NOTE_ID, note, type) }.onFailure {
            runCatching { startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH) }
        }
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                delay(1000)
                val en = WatchStore.engine
                if (!en.active || en.finished) break
                en.tick()
            }
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun hasLocation() = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED

    override fun onDestroy() {
        ticker?.cancel()
        super.onDestroy()
    }

    private fun notification(e: WorkoutEngine): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, L10n.t("Recording a workout"), NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, WearActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val title = if (e.mode == Mode.Training) e.title else e.mode.title.l10n
        val b = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.mode_race)
            .setContentTitle(title)
            .setContentText(L10n.t("Recording a workout"))
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setContentIntent(open)
            .setSilent(true)
        // 시계 화면 아래 "운동 중" 아이콘 (누르면 앱으로)
        val status = Status.Builder().addTemplate("#title#").addPart("title", Status.TextPart(title)).build()
        OngoingActivity.Builder(this, NOTE_ID, b)
            .setStaticIcon(R.drawable.mode_race)
            .setTouchIntent(open)
            .setStatus(status)
            .build()
            .apply(this)
        return b.build()
    }

    companion object {
        private const val CHANNEL = "workout"
        private const val NOTE_ID = 8001

        fun start(context: Context) {
            runCatching { context.startForegroundService(Intent(context, WorkoutService::class.java)) }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WorkoutService::class.java))
        }
    }
}
