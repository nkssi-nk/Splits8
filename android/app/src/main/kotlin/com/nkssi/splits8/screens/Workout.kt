package com.nkssi.splits8.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.WatchSync
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.RepTune
import com.nkssi.splits8.shared.RunModes
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.SettingRow
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.Toggle8
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

// 아이폰 WorkoutSettingsViews.swift (98번 · 빌드 28): 설정 › 운동 · 측정
// 러닝(장소) · 횟수 보정(스키 · 로잉 · 월볼) · 심박 · 진동을 한 곳에. 예전엔 설정 첫 화면에 '러닝' 한 줄과 '진동' 칸이 따로 있었음

@Composable
fun SetWorkoutView() {
    val s = Store.settings
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionLabel("RUNNING", top = 4.dp)
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Running place", RunModes.name(s.runMode).l10n, Modifier.testTag("workout.running"), last = true) {
                    Router.sub(Scr.SetRun, Scr.SetWorkout)
                }
            }
            Note8("Run cards ask Outdoor or Indoor when you start on the watch. Indoors there is no GPS, so distance is estimated from arm motion. A few outdoor runs with GPS make indoor distance more accurate.")

            SectionLabel("REP COUNT CALIBRATION")
            Column(Modifier.fillMaxWidth().card8()) {
                RepTune.icons.forEachIndexed { i, icon -> CalRow(icon, i == RepTune.icons.size - 1) }
            }
            Note8("Do 20 reps with your watch and counting fits your own movement.")

            SectionLabel("HEART RATE")
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Max heart rate", "${s.maxHR} BPM", Modifier.testTag("workout.hr"), numeric = true, last = true) {
                    Router.sub(Scr.SetHr, Scr.SetWorkout)
                }
            }

            SectionLabel("VIBRATION")
            Column(Modifier.fillMaxWidth().card8()) {
                WToggleRow("Heart rate zone change", null, s.hapticZone, false, "settings.hapticZone") { v -> Store.update { it.withHapticZone(v) } }
                WToggleRow("Behind target pace", "Race · Full Sim", s.hapticPace, true, "settings.hapticPace") { v -> Store.update { it.withHapticPace(v) } }
            }
            Note8("Your watch alerts you with a vibration during workouts.")

            VoiceSection(s)
        }
    }
}

/**
 * 19번: 음성 안내 — 켜기/끄기(기본 끔) · 러닝 알림 간격 · 러닝 알림에 넣을 것.
 * 워치 운동은 워치가, 폰 운동은 폰이 말함 (설정은 워치로 같이 감). 지금은 한국어 조각만 있어서 다른 언어면 회색으로 못 켬
 */
@Composable
private fun VoiceSection(s: Settings) {
    val ko = L10n.isKorean
    val on = s.voice && ko
    SectionLabel("VOICE GUIDANCE")
    Column(Modifier.fillMaxWidth().card8().alpha(if (ko) 1f else 0.45f)) {
        WToggleRow("Voice guidance", null, on, !on, "settings.voice") { v -> if (ko) Store.update { it.withVoice(v) } }
        if (on) {
            Row(Modifier.fillMaxWidth().rowLine(true).padding(vertical = 10.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                T("Running alerts", F.t(17), Modifier.weight(1f), maxLines = 1)
                Seg8(listOf("500" to "0.5 km", "1000" to "1 km", "0" to "Off"), "${s.voiceEvery}", Modifier.width(196.dp).testTag("settings.voiceEvery"),
                    height = 30.dp, radius = 9.dp, fontSize = 13) { k -> Store.update { it.withVoiceEvery(k.toIntOrNull() ?: 1000) } }
            }
            WToggleRow("Distance", null, s.voiceDist, false, "settings.voiceDist") { v -> Store.update { it.withVoiceDist(v) } }
            WToggleRow("Total time", null, s.voiceTime, false, "settings.voiceTime") { v -> Store.update { it.withVoiceTime(v) } }
            WToggleRow("Average pace", null, s.voicePace, false, "settings.voicePace") { v -> Store.update { it.withVoicePace(v) } }
            WToggleRow("Average heart rate", "Watch workouts only", s.voiceHr, true, "settings.voiceHr") { v -> Store.update { it.withVoiceHr(v) } }
        }
    }
    Note8(if (ko) "Speaks on the device you work out with: the watch for watch workouts, this phone for phone workouts. Other sound gets quieter while it speaks. Running alerts are for Run cards."
        else "Voice guidance is available in Korean for now.")
}

/** 종목 이름 · 오른쪽 상태 (기본값 / 보정됨 · 날짜) */
@Composable
private fun CalRow(icon: String, last: Boolean) {
    val tune = Store.settings.repCal?.get(icon)
    val value = tune?.date?.let { L10n.t("Calibrated · %@", Fm.dm(it)) } ?: "Default".l10n
    Row(Modifier.fillMaxWidth().rowLine(!last).tap { Router.calibIcon = icon; Router.go(Scr.SetCalib) }.testTag("workout.cal.$icon")
        .padding(vertical = 14.dp, horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        T(CalibText.name(icon), F.t(17), Modifier.weight(1f), maxLines = 1)
        T(value, F.t(15, color = if (tune == null) C.text2 else C.good), maxLines = 1, translate = false)
        Chevron8()
    }
}

/** 제목 17 · 설명 13 회색 · 토글 */
@Composable
private fun WToggleRow(title: String, sub: String?, on: Boolean, last: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().rowLine(!last).padding(vertical = if (sub == null) 10.dp else 11.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, F.t(17), maxLines = 1)
            if (sub != null) T(sub, F.t(13, color = C.text2), maxLines = 1)
        }
        Toggle8(on, Modifier.testTag(tag), onChange = onChange)
    }
}

/** 종목 이름 · 안내 글 */
object CalibText {
    fun name(icon: String): String = mapOf("skiErg" to "SkiErg", "row" to "Row", "wallBalls" to "Wall Balls")[icon] ?: icon

    /** "월볼 20개를 평소처럼 해 주세요" */
    fun task(icon: String): String = when (icon) {
        "wallBalls" -> "Do 20 wall balls as usual"
        "row" -> "Do 20 row strokes as usual"
        else -> "Do 20 SkiErg pulls as usual"
    }
}

// MARK: - 종목 보정 (안내 + 워치에서 시작)

@Composable
fun SetCalibView() {
    val icon = Router.calibIcon
    val tune = Store.settings.repCal?.get(icon)
    var sent by remember(icon) { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.fillMaxWidth().card8().padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T(L10n.t("CALIBRATE · %@", CalibText.name(icon).uppercase()), F.t(12, W600, C.accent, tracking = 0.9f), maxLines = 1, translate = false)
                T(CalibText.task(icon), F.t(26, W700, tracking = -0.5f))
                T("We measure how hard your arm moves on each rep and set counting to match you.", F.t(15, color = C.text2))
                tune?.date?.let {
                    T(L10n.t("Calibrated · %@", Fm.dm(it)), F.t(13, W600, C.good), Modifier.padding(top = 2.dp), maxLines = 1, translate = false)
                }
            }

            SectionLabel("HOW")
            Column(Modifier.fillMaxWidth().card8()) {
                CalStep(1, "Tap the button below. The calibration screen opens on your watch.")
                CalStep(2, "Start on the watch, then do exactly 20.")
                CalStep(3, "Tap Done and confirm how many you did. That's it.", last = true)
            }
            Note8("Wear the watch on the wrist that moves. You can redo it or go back to default anytime.")

            Box(Modifier.padding(top = 10.dp).fillMaxWidth().height(52.dp).clip(RoundedCornerShape(14.dp)).background(C.accent)
                .press(tag = "calib.start") {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    sent = true
                    WatchSync.startCalibration(icon)
                }, contentAlignment = Alignment.Center) {
                T(if (sent) "Sent to watch" else "Start on watch", F.t(17, W600, Color.Black), maxLines = 1)
            }
            if (sent) Note8("If nothing shows on the watch, open SPLITS8 on the watch.", color = C.text2)

            if (tune != null) {
                Box(Modifier.padding(top = 6.dp).fillMaxWidth().height(50.dp).card8(14.dp).press(tag = "calib.reset") {
                    Router.ask = Ask("Reset to default?", ok = "Reset", destructive = true) {
                        Store.update { st ->
                            val m = (st.repCal ?: emptyMap()) - icon
                            st.copy(repCal = m.ifEmpty { null })
                        }
                    }
                }, contentAlignment = Alignment.Center) {
                    T("Reset to default", F.t(17, W600, C.bad), maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun CalStep(n: Int, t: String, last: Boolean = false) {
    Row(Modifier.fillMaxWidth().rowLine(!last).padding(vertical = 12.dp, horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(24.dp).clip(CircleShape).background(C.accent), contentAlignment = Alignment.Center) {
            T("$n", F.t(13, W700, Color.Black), maxLines = 1, translate = false)
        }
        T(t, F.t(15), Modifier.weight(1f))
    }
}
