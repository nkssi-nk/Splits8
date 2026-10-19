package com.nkssi.splits8.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.Settings
import kotlin.math.sqrt

/**
 * 스키 · 로잉 · 월볼 횟수 세기 (참고용 짐작값, 아이폰 RepCounter.swift 와 같은 규칙).
 * 팔이 한 번 크게 움직일 때마다 하나로 셈. 운동 중 화면에는 안 보이고, 끝난 뒤 폰 기록 화면에 "≈ 98" 처럼 참고 숫자로만.
 * 시간 · 순위 · 최고 기록 · 등급에는 쓰지 않음.
 * 기준값 = RepTune (shared). 98번(빌드 28): 폰 설정 › 운동 · 측정에서 워치로 20회 보정하면 그 사람 값(settings.repCal),
 * 없으면 기본값(RepTune.defaults)
 */
class RepCounter(context: Context?) : RepSource {
    companion object {
        /** 이 종목 기준값 (보정값 → 기본값). settings 를 안 넘기면 워치 저장소의 설정 */
        fun tuning(icon: String, settings: Settings = WatchStore.settings): RepTune? =
            settings.repCal?.get(icon) ?: RepTune.defaults[icon]

        /** 이 종목은 횟수를 세는지 */
        fun counts(icon: String) = RepTune.defaults.containsKey(icon)
        const val G = 9.80665
    }

    private val sm = context?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val sensor: Sensor? = sm?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

    private var tune: RepTune? = null
    private var count = 0
    private var level = 0.0
    private var armed = true
    private var lastHit = 0.0
    private var paused = false

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) {
            val v = e.values
            // m/s² → g (아이폰 userAcceleration 과 같은 단위)
            val mag = sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble()) / G
            feed(mag, e.timestamp / 1e9)
        }
        override fun onAccuracyChanged(s: Sensor?, a: Int) {}
    }

    @Synchronized
    override fun start(icon: String, base: Int) {
        sm?.unregisterListener(listener)
        val t = tuning(icon)
        tune = t; count = maxOf(0, base); level = 0.0; armed = true; lastHit = 0.0; paused = false
        if (t != null && sensor != null) sm?.registerListener(listener, sensor, 20_000)   // 50번/초
    }

    @Synchronized
    override fun setPaused(p: Boolean) {
        paused = p
        if (p) { level = 0.0; armed = true }
    }

    @Synchronized
    override fun stop(): Int? {
        sm?.unregisterListener(listener)
        val out = if (tune == null) null else count
        tune = null
        return out
    }

    /** 시험용으로도 부름: mag = 움직임 세기(g), t = 초 */
    @Synchronized
    fun feed(mag: Double, t: Double) {
        val tn = tune ?: return
        if (paused) return
        level = tn.smooth * level + (1 - tn.smooth) * mag
        if (armed) {
            if (level >= tn.threshold && (lastHit == 0.0 || t - lastHit >= tn.minGap)) {
                count++
                lastHit = t
                armed = false
            }
        } else if (level <= tn.release) {
            armed = true
        }
    }
}
