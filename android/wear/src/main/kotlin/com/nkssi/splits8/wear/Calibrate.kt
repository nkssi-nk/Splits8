package com.nkssi.splits8.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Picker
import androidx.wear.compose.material3.rememberPickerState
import com.nkssi.splits8.shared.RepTune
import java.time.Instant
import kotlin.math.sqrt

// 98번(빌드 28): 횟수 보정 (스키 · 로잉 · 월볼) — 아이폰 WatchApp/Calibrate.swift.
// 폰 설정 › 운동 · 측정 › 종목 › "워치에서 시작" → 워치 앱이 켜지며 이 화면 (splits8://calib?icon=… 또는 /calib 메시지).
// 평소처럼 20회 → 끝 → 실제 개수 확인 → 그 사람 동작에 맞는 기준값(RepTune.fit)을 찾아 저장 · 폰으로 보냄.
// 화면이 꺼져도 센서를 계속 받으려고 세는 동안 화면 켜 둠 + 부분 깨우기(wake lock). 기록 · 건강 앱 저장 없음.

/** 보정용 움직임 센서 (실제: 선형 가속도). 시험 · 화면 사진에서는 없음 */
interface CalibSensor {
    /** mag = 움직임 세기(g), t = 초 */
    fun start(onSample: (mag: Double, t: Double) -> Unit)
    fun stop()
}

object NoCalibSensor : CalibSensor {
    override fun start(onSample: (Double, Double) -> Unit) {}
    override fun stop() {}
}

/** 실제 워치: 선형 가속도 50번/초 (m/s² → g, 아이폰 userAcceleration 과 같은 단위) + 세는 동안 부분 깨우기 */
class AccelCalibSensor(context: Context) : CalibSensor {
    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val sensor: Sensor? = sm?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val wake: PowerManager.WakeLock? = (context.getSystemService(Context.POWER_SERVICE) as? PowerManager)
        ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "splits8:calib")?.apply { setReferenceCounted(false) }
    private var listener: SensorEventListener? = null

    override fun start(onSample: (Double, Double) -> Unit) {
        stop()
        val l = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                val v = e.values
                onSample(sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble()) / RepCounter.G, e.timestamp / 1e9)
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        listener = l
        if (sensor != null) sm?.registerListener(l, sensor, 20_000)
        runCatching { wake?.acquire(10 * 60 * 1000L) }        // 10분까지
    }

    override fun stop() {
        listener?.let { sm?.unregisterListener(it) }
        listener = null
        runCatching { if (wake?.isHeld == true) wake.release() }
    }
}

object Calib {
    enum class Phase { Ready, Counting, Confirm, Saved }

    /** 보정할 종목 아이콘 (null = 보정 화면 아님) */
    var icon by mutableStateOf<String?>(null); private set
    var phase by mutableStateOf(Phase.Ready); private set
    /** 지금 기준으로 센 횟수 (참고용으로 화면에 보여 줌) */
    var live by mutableIntStateOf(0); private set
    /** 실제로 한 개수 (끝난 뒤 크라운으로 맞춤) */
    var actual by mutableIntStateOf(20)
    /** 저장된 새 기준 (끝 화면에 보여 줌) */
    var saved by mutableStateOf<RepTune?>(null); private set

    var sensor: CalibSensor = NoCalibSensor
    var buzz: (BuzzKind) -> Unit = {}

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val mags = ArrayList<Double>()
    private val times = ArrayList<Double>()
    private var level = 0.0
    private var armed = true
    private var lastHit = -1000.0
    private var tune: RepTune? = null

    const val HOST = "calib"

    /** 폰이 워치 앱을 켤 때 쓰는 주소: splits8://calib?icon=wallBalls */
    fun uri(icon: String): Uri = Uri.parse("splits8://$HOST?icon=$icon")

    /** 주소에서 종목을 알아냄 (보정 주소가 아니면 null) */
    fun iconFrom(u: Uri?): String? {
        if (u == null || u.scheme != "splits8" || u.host != HOST) return null
        return u.getQueryParameter("icon")?.takeIf { RepTune.defaults.containsKey(it) }
    }

    fun name(icon: String): String = mapOf("skiErg" to "SkiErg", "row" to "Row", "wallBalls" to "Wall Balls")[icon] ?: icon

    /** 폰이 보낸 요청: 보정 화면을 띄움 (운동 중이면 무시). 띄웠으면(또는 이미 떠 있으면) true */
    fun request(icon: String): Boolean {
        if (!RepTune.defaults.containsKey(icon) || WatchStore.engine.active) return false
        if (this.icon == icon && phase != Phase.Saved) return true
        this.icon = icon
        phase = Phase.Ready; live = 0; actual = 20; saved = null
        return true
    }

    // MARK: 세기

    fun begin() {
        val ic = icon ?: return
        val t = RepCounter.tuning(ic) ?: return
        synchronized(lock) { mags.clear(); times.clear(); level = 0.0; armed = true; lastHit = -1000.0; tune = t }
        live = 0
        phase = Phase.Counting
        sensor.start { m, s -> feed(m, s) }
    }

    /** 움직임 하나 (시험용으로도 부름) */
    fun feed(mag: Double, t: Double) {
        var hit = false
        synchronized(lock) {
            val tn = tune ?: return
            if (mags.size < 50 * 60 * 8) { mags.add(mag); times.add(t) }     // 8분까지만 (메모리 보호)
            // 화면용: 지금 기준으로 센 숫자
            level = tn.smooth * level + (1 - tn.smooth) * mag
            if (armed) {
                if (level >= tn.threshold && t - lastHit >= tn.minGap) { lastHit = t; armed = false; hit = true }
            } else if (level <= tn.release) {
                armed = true
            }
        }
        if (hit) { if (Looper.myLooper() == Looper.getMainLooper()) live++ else main.post { live++ } }
    }

    /** 끝: 실제 개수 확인 화면으로 (기본값 = 20) */
    fun stop() {
        sensor.stop()
        synchronized(lock) { tune = null }
        actual = 20
        phase = Phase.Confirm
        buzz(BuzzKind.Click)
    }

    /** 실제 개수로 기준을 찾아 저장하고 폰으로 보냄 */
    fun save(now: Instant = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.SECONDS)) {
        val ic = icon ?: return
        val (m, t) = synchronized(lock) { mags.toList() to times.toList() }
        sensor.stop()
        val tn = RepTune.fit(ic, m, t, actual, now)
        saved = tn
        phase = Phase.Saved
        if (tn == null) return
        WatchStore.applyCalibration(ic, tn)
        buzz(BuzzKind.Success)
    }

    /** 닫기 (언제든). 센서 정리, 저장 안 함 */
    fun close() {
        sensor.stop()
        synchronized(lock) { tune = null }
        icon = null; phase = Phase.Ready; live = 0; saved = null
    }

    /** 화면 사진용: 이 단계 그대로 */
    fun demo(icon: String, phase: Phase, live: Int = 0, saved: RepTune? = null) {
        this.icon = icon; this.phase = phase; this.live = live; this.saved = saved; actual = 20
    }
}

// MARK: - 보정 화면

@Composable
fun WCalibView() {
    val c = Calib
    val icon = c.icon ?: "wallBalls"
    val unit = if (icon == "wallBalls") wt("reps") else wt("pulls")
    val k = wk()
    Box(Modifier.fillMaxSize().background(Color.Black).testTag("w.calib")) {
        AmbientLayer(Ambient.y(0.18f, 1.0f, 0.5f, 0.5f, -0.1f, WatchStore.settings.glow))
        Column(Modifier.fillMaxSize().padding(start = (24 * k).dp, end = (24 * k).dp, top = (22 * k).dp, bottom = (24 * k).dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            // 제목 + 닫기 (언제든 — 세는 중이어도 센서 정리, 저장 안 함)
            // 2026-10-21: 맨 위 줄은 동그란 화면에서 좁음 → 원 안 폭으로 (제목 앞 글자가 잘렸음)
            Row(Modifier.width(roundWidth(22 * k, 4f)), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                T(wt("Calibrate") + " · " + Calib.name(icon), F.t(13, W600, C.accent), Modifier.weight(1f, fill = false), minScale = 0.6f, translate = false)
                Box(Modifier.size(24.dp).clip(CircleShape).background(hex(0x262626)).press { c.close() }.testTag("w.calib.close"),
                    contentAlignment = Alignment.Center) {
                    Icon8("i_x", 10.dp, C.text2)
                }
            }
            when (c.phase) {
                Calib.Phase.Ready -> {
                    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        T(wt("Do 20 %@ as usual, then tap Done.", unit), F.t(14, color = C.text2), Modifier.fillMaxWidth(), maxLines = 4,
                            align = TextAlign.Center, translate = false)
                    }
                    BigButton("Start", C.accent, Color.Black, "w.calib.start") { c.begin() }
                }
                Calib.Phase.Counting -> {
                    T(wt("Do 20 %@, then tap Done", unit), F.t(12, color = C.text2), Modifier.fillMaxWidth().padding(top = 4.dp), translate = false)
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        T("${c.live}", F.num(56 * k, tracking = -2f), Modifier.testTag("w.calib.live"), translate = false)
                        T("/ 20", F.num(20, color = C.text2), Modifier.padding(top = 18.dp), translate = false)
                    }
                    BigButton("Done", C.accent, Color.Black, "w.calib.done") { c.stop() }
                }
                Calib.Phase.Confirm -> {
                    T("How many did you do?", F.t(13, color = C.text2), Modifier.fillMaxWidth().padding(top = 2.dp))
                    CountPicker(Modifier.weight(1f).fillMaxWidth())
                    BigButton("Save", C.good, Color.Black, "w.calib.save") { c.save() }
                }
                Calib.Phase.Saved -> {
                    Column(Modifier.weight(1f).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically)) {
                        if (c.saved != null) {
                            T("Saved", F.t(22, W600, C.good))
                            T("Counting now fits your movement. You can redo it anytime from your phone.", F.t(13, color = C.text2),
                                Modifier.fillMaxWidth(), maxLines = 4, align = TextAlign.Center)
                        } else {
                            T("Not enough movement", F.t(18, W600))
                            T("Try again from your phone and keep the watch on the hand that moves.", F.t(13, color = C.text2),
                                Modifier.fillMaxWidth(), maxLines = 4, align = TextAlign.Center)
                        }
                    }
                    BigButton("Close", hex(0x262626), Color.White, "w.calib.finish") { c.close() }
                }
            }
        }
    }
}

/** 실제 개수 1~60 (크라운 · 위아래로 밀기) */
@Composable
private fun CountPicker(modifier: Modifier) {
    val state = rememberPickerState(60, Calib.actual.coerceIn(1, 60) - 1, false)
    LaunchedEffect(state) { snapshotFlow { state.selectedOptionIndex }.collect { Calib.actual = it + 1 } }
    Picker(state, { "${Calib.actual}" }, modifier.testTag("w.calib.picker"), verticalSpacing = 0.dp) { i ->
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            T("${i + 1}", F.num(28, color = if (i == state.selectedOptionIndex) Color.White else C.text3), translate = false)
        }
    }
}

@Composable
private fun BigButton(t: String, bg: Color, fg: Color, tag: String, onClick: () -> Unit) {
    // 2026-10-21: 화면 아래 끝 단추 — 동그란 화면 안에 들어오는 폭으로 (양 끝이 잘렸음)
    Box(Modifier.width(roundWidth(24 * wk())).height(40.dp).clip(RoundedCornerShape(20.dp)).background(bg).press(onClick = onClick).testTag(tag),
        contentAlignment = Alignment.Center) {
        T(t, F.t(15, W600, fg))
    }
}
