package com.nkssi.splits8.screens

import android.media.AudioManager
import android.media.ToneGenerator
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.PhoneRunEngine
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.tap
import kotlin.math.roundToInt

// 18번: 폰으로 기록하는 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동의 가운데 화면 (PhoneLiveView 가 씀).
// 운동 = 노랑, 휴식 = 회색으로 남은 시간을 크게. 바뀌기 3 · 2 · 1초 전 삑 소리 (BonusBeeper).

/** 가운데: TOTAL · [아이콘 이름 n/N] · 큰 숫자 (남은 시간 / 남은 거리 / 세트 시간) · 아래 줄 */
@Composable
internal fun BonusLiveBody(eng: PhoneRunEngine, now: Long, m: LiveMetrics, modifier: Modifier = Modifier) {
    val cur = eng.cur
    val rest = cur.kind == SegKind.Rox
    val imp = Store.settings.imperial
    val el = eng.segEl(now)
    val bigColor = if (!eng.running) C.text2 else if (rest) C.d1 else C.accent
    val label: String
    val big: String
    var head = ""
    var line = ""
    when (eng.kind) {
        Kinds.AMRAP -> {
            label = "TIME LEFT"
            big = Fm.t(eng.capLeft(now) ?: 0)
            head = L10n.t("%lld rounds", eng.idx)
            line = eng.tasks.joinToString(" · ")
        }
        Kinds.EMOM -> {
            label = "TIME LEFT"
            big = Fm.t(eng.segLeft(now) ?: 0)
            head = "${cur.rep ?: (eng.idx + 1)}/${eng.seq.size}"
            val w = eng.segWork.getOrNull(eng.idx)
            line = if (w != null) L10n.t("Done in %@", Fm.t(w)) else eng.tasks.joinToString(" · ")
        }
        Kinds.TABATA -> {
            label = if (rest) "REST" else "WORK"
            big = Fm.t(eng.segLeft(now) ?: 0)
            head = "${cur.rep ?: 1}/${eng.seq.count { it.icon == "hiit" }}"
        }
        Kinds.LIFT -> {
            label = if (rest) "REST" else "SET TIME"
            big = Fm.t(if (rest) (eng.segLeft(now) ?: 0) else el)
            head = if (rest) "" else cur.detail.removePrefix("SET ")
            line = if (rest) L10n.t("Next: %@", (eng.next?.name ?: "").l10n)
                else liftText(cur.reps, cur.kg)
        }
        else -> {                                                        // 인터벌 러닝
            val len = Bonus.distLen(eng.kind, cur)
            val maxRep = eng.seq.mapNotNull { it.rep }.maxOrNull()
            head = cur.rep?.let { "$it/${maxRep ?: it}" } ?: ""
            if (len != null && eng.useGPS) {
                label = "DISTANCE LEFT"
                big = Units.dist(maxOf(0.0, len - eng.segDist), imp) + " " + Units.distUnit(imp)
            } else if (len != null) {
                label = "DISTANCE"
                big = Bonus.distText(len.roundToInt())
            } else {
                label = "TIME LEFT"
                big = Fm.t(eng.segLeft(now) ?: 0)
            }
            line = ivPaceLine(eng, el, imp, now)
        }
    }
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        T("TOTAL", F.t(12, W600, C.text2, tracking = 1.44f), maxLines = 1)
        FitText(Fm.t(eng.total(now)), F.num(m.totalFont * 0.62f, color = if (eng.running) Color.White else C.text2),
            Modifier.testTag("phone.total"), minScale = 0.6f)
        Row(Modifier.padding(top = (m.segTop * 0.5f).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon8(if (rest) "hiit" else Kinds.icon(eng.kind), (m.icon * 0.6f).dp, if (rest) C.text2 else C.accent)
            FitText(cur.name.l10n, F.t(m.nameFont, W600, if (rest) C.text2 else Color.White), minScale = 0.7f)
            if (head.isNotEmpty()) T(head, F.num(m.nameFont * 0.8f, color = C.text2), maxLines = 1, translate = false)
        }
        Label8(label, Modifier.padding(top = (m.nameTop * 1.4f).dp))
        FitText(big, F.num(m.totalFont * 1.25f, color = bigColor, tracking = -0.02f * m.totalFont),
            Modifier.testTag("phone.bonusBig"), minScale = 0.5f)
        FitText(line, F.t(m.detailFont, color = C.aeb), Modifier.padding(top = 4.dp).height((m.detailFont * 1.4f).dp), minScale = 0.7f)
    }
}

/** "5 × 80 kg" / "12 reps" */
internal fun liftText(reps: Int?, kg: Double?): String {
    val r = reps ?: return ""
    return if ((kg ?: 0.0) > 0) "$r × " + Bonus.kgText(kg ?: 0.0) else L10n.t("%lld reps", r)
}

/** 인터벌 러닝 아래 줄: "페이스 4:32 · 목표 4:30 (+0:02)" — 목표보다 빠르면 −, 느리면 + */
private fun ivPaceLine(eng: PhoneRunEngine, el: Int, imp: Boolean, now: Long): String {
    if (eng.cur.kind == SegKind.Rox) return ""
    if (!eng.useGPS) return eng.cur.pace?.let { L10n.t("Target pace %@", Fm.t(Units.pace(it, imp))) } ?: ""
    val p = LivePace.text(el, eng.segDist, imp, eng.speedNow(now))
    var s = L10n.t("Pace %@", p)
    val goal = eng.cur.pace
    if (goal != null && eng.segDist >= 100 && el > 0) {
        val avg = (el / eng.segDist * 1000).roundToInt()
        s += " · " + L10n.t("Target %@", Fm.t(Units.pace(goal, imp))) + " (" + Fm.d(Units.pace(avg, imp) - Units.pace(goal, imp)) + ")"
    }
    return s
}

/** 큰 노란 단추 글자 (번역 키) */
internal fun bonusNextLabel(eng: PhoneRunEngine): String = when (eng.kind) {
    Kinds.EMOM -> if (eng.segWork.getOrNull(eng.idx) != null) "Done ✓" else "Done"
    Kinds.AMRAP -> "Round done"
    Kinds.TABATA -> "Skip"
    Kinds.LIFT -> if (eng.isLiftSet) "Set done" else "Skip rest"
    else -> if (eng.hasNext) "Next step" else "Finish"
}

/** 바뀌기 3 · 2 · 1초 전 · 바뀔 때 삑 소리 (폰 — 워치는 진동) */
@Composable
internal fun rememberBeeper(): (Boolean) -> Unit {
    val tg = remember { runCatching { ToneGenerator(AudioManager.STREAM_MUSIC, 80) }.getOrNull() }
    DisposableEffect(tg) { onDispose { runCatching { tg?.release() } } }
    return { long -> runCatching { tg?.startTone(ToneGenerator.TONE_PROP_BEEP, if (long) 400 else 120) } }
}

/** 기능성 운동 세트 끝: 실제 횟수 · 무게 확인 (지난번 값으로 미리 채움) → 휴식 */
@Composable
internal fun LiftSetSheet(name: String, setLabel: String, reps: Int, kg: Double,
                          onReps: (Int) -> Unit, onKg: (Double) -> Unit, onSave: () -> Unit, onCancel: () -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.75f)).tap(onClick = onCancel).testTag("phone.liftSheet"),
        contentAlignment = Alignment.BottomCenter) {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp)).background(C.sheet).tap { }
                .padding(start = 22.dp, end = 22.dp, top = 20.dp, bottom = 34.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(name, F.t(F.title3, W600), maxLines = 1)
                T(setLabel, F.t(F.foot, color = C.text2), maxLines = 1, translate = false)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Label8("REPS", Modifier.weight(1f))
                Stepper8("$reps", minWidth = 44.dp, fontSize = 24, down = { onReps((reps - 1).coerceAtLeast(0)) }, up = { onReps((reps + 1).coerceAtMost(999)) })
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Label8("WEIGHT (KG)", Modifier.weight(1f))
                Stepper8(Bonus.kgText(kg).removeSuffix(" kg"), minWidth = 56.dp, fontSize = 24,
                    down = { onKg((kg - 2.5).coerceAtLeast(0.0)) }, up = { onKg((kg + 2.5).coerceAtMost(999.0)) })
            }
            YellowButton("Save set", tag = "phone.liftSave", onClick = onSave)
            Spacer(Modifier.height(2.dp))
        }
    }
}
