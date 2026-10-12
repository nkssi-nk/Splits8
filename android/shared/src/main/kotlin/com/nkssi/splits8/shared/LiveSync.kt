package com.nkssi.splits8.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// 워치 운동을 폰에 실시간으로 (아이폰 Shared/LiveSync.swift 와 같은 내용).
// 워치 → 폰: LiveState (구간이 바뀔 때마다 + 5초마다 심박 · 칼로리)
// 폰 → 워치: LiveCommand (Next · Undo · Pause · Resume · End)
// 기록의 기준은 워치. 폰은 받은 상태를 그대로 보여 주기만 함. 안드로이드는 Data Layer 메시지(SyncKey.live)로 주고받음.

@Serializable
data class LiveState(
    val mode: Mode,
    val title: String,
    val seq: List<Seg>,
    val idx: Int,
    val splits: List<Int>,
    /** 보낸 순간의 지금 구간 시간(초). 폰은 받은 시각부터 이어서 셈 */
    val segElapsed: Int,
    val running: Boolean,
    val hr: Int,
    val kcal: Int,
    val zone: Int,
    val canUndo: Boolean,
    val finished: Boolean,
    val vsWord: String,
    /** 목표 (보낸 순간 지금 구간의 목표). 없으면 null */
    val delta: Int? = null,
    /** HIIT · 자유 러닝처럼 끝없이 늘어나는 운동 */
    val open: Boolean = false,
    /** 러닝 1km 자동 넘김 */
    val autoSplit: Boolean = false,
    /** 지금 구간에서 달린 거리(m) · 운동 전체 거리(m) */
    val segDist: Double? = null,
    val dist: Double? = null,
) {
    val cur: Seg? get() = seq.getOrNull(idx) ?: seq.lastOrNull()
    val nextSeg: Seg? get() = seq.getOrNull(idx + 1)
    val doneT: Int get() = splits.take(idx).sum()

    /** nowMs · receivedMs = 기기 시계(ms). 받은 시각부터 이어서 셈 */
    fun segEl(nowMs: Long, receivedMs: Long): Int =
        if (running) segElapsed + maxOf(0, ((nowMs - receivedMs) / 1000).toInt()) else segElapsed

    fun total(nowMs: Long, receivedMs: Long): Int = doneT + segEl(nowMs, receivedMs)
}

@Serializable
enum class LiveCommand {
    @SerialName("next") Next,
    @SerialName("undo") Undo,
    @SerialName("pause") Pause,
    @SerialName("resume") Resume,
    @SerialName("end") End,
}

@Serializable
data class LivePacket(val state: LiveState? = null, val command: LiveCommand? = null) {
    fun bytes(): ByteArray = SplitsJson.encodeToString(serializer(), this).toByteArray(Charsets.UTF_8)

    companion object {
        fun read(b: ByteArray): LivePacket? =
            runCatching { SplitsJson.decodeFromString(serializer(), String(b, Charsets.UTF_8)) }.getOrNull()
    }
}

/** "5:12" 처럼 1 km 페이스 글자 (거리가 10 m 미만이면 "–:––") */
object LivePace {
    fun text(el: Int, dist: Double?): String {
        if (dist == null || dist < 10 || el <= 0) return "–:––"
        val p = (el / (dist / 1000)).r()
        if (p >= 3600) return "–:––"
        return "${p / 60}:" + "%02d".format(p % 60)
    }
}
