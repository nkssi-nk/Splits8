package com.nkssi.splits8.wear

import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * 워치 진동을 한곳에 (아이폰 WBuzz + WKHapticType 자리).
 * 숫자는 [쉼, 울림, 쉼, 울림 …] (ms). 실제 갤럭시 워치로 느껴 보고 여기만 고치면 됨.
 * 운동 중에는 약한 진동이 안 느껴짐 → 구간 넘김 · 목표 초과는 두 번 길게.
 */
object Buzz {
    val patterns: Map<BuzzKind, LongArray> = mapOf(
        BuzzKind.Tick to longArrayOf(0, 70),                       // 3 · 2 · 1 숫자마다
        BuzzKind.Go to longArrayOf(0, 420, 110, 420),              // 시작 순간 (합쳐서 약 1초)
        BuzzKind.Start to longArrayOf(0, 160),
        BuzzKind.Next to longArrayOf(0, 200, 90, 200),             // 다음 구간
        BuzzKind.Undo to longArrayOf(0, 60, 70, 60),
        BuzzKind.ZoneUp to longArrayOf(0, 70, 60, 70, 60, 70),     // 심박 존 올라감
        BuzzKind.ZoneDown to longArrayOf(0, 260),                  // 심박 존 내려감
        BuzzKind.Over to longArrayOf(0, 320, 140, 320),            // 목표 시간 넘김
        BuzzKind.Success to longArrayOf(0, 120, 90, 260),          // 운동 끝
        BuzzKind.Click to longArrayOf(0, 35),
        BuzzKind.Failure to longArrayOf(0, 60, 50, 60, 50, 60),
    )

    fun play(context: Context, k: BuzzKind) {
        val v: Vibrator = (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator ?: return
        val p = patterns[k] ?: return
        runCatching { v.vibrate(VibrationEffect.createWaveform(p, -1)) }
    }
}
