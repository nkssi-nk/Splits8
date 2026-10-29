package com.nkssi.splits8.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Bonus
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Kinds
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import kotlin.math.roundToInt

// 18번: 기록 화면 — 타바타 · EMOM 라운드 표, AMRAP 점수(+ 추가 동작 수 입력) · 라운드 표, 인터벌 러닝 단계 표(빠른 단계 노랑),
// 기능성 운동 종목별 세트 표 · 총 볼륨 · 지난번 대비. Detail.kt 의 구간 표(SPLITS) 자리에 들어감

/** 타일 두 번째 칸 (TOTAL 옆) */
internal fun bonusTileValue(rec: Record): Triple<String, String, String>? = when (rec.kind) {
    Kinds.TABATA -> Triple("ROUNDS", "${Bonus.tabataDone(rec)}/${rec.segs.count { it.icon == "hiit" }}", "")
    Kinds.EMOM -> Triple("ROUNDS", "${rec.segs.size}", "")
    Kinds.AMRAP -> Triple("ROUNDS", "${rec.rounds ?: 0}" + ((rec.extra ?: 0).takeIf { it > 0 }?.let { " +$it" } ?: ""), "")
    Kinds.LIFT -> Triple("VOLUME", grouped(Bonus.volume(rec).roundToInt()), "KG")
    else -> null
}

@Composable
internal fun BonusDetail(rec: Record) {
    when (rec.kind) {
        Kinds.TABATA, Kinds.EMOM -> RoundsTable(rec)
        Kinds.AMRAP -> { AmrapScore(rec); RoundsTable(rec) }
        Kinds.IVRUN -> StepsTable(rec)
        Kinds.LIFT -> LiftTables(rec)
    }
}

/** 한 줄: 왼쪽 이름 · 오른쪽 칸들 */
@Composable
private fun TableRow(name: String, nameColor: Color, cells: List<String>, last: Boolean, header: Boolean = false, tag: String? = null) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = if (header) 34.dp else 44.dp).rowLine(!last).padding(horizontal = 16.dp)
            .let { if (tag != null) it.testTag(tag) else it },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        T(name, if (header) F.t(11, W600, C.text3, tracking = 0.6f) else F.t(15, W600, nameColor), Modifier.weight(1.4f), maxLines = 1, translate = false)
        for (c in cells) {
            T(c, if (header) F.t(11, W600, C.text3, tracking = 0.6f) else F.num(15, W500, Color.White), Modifier.weight(1f),
                maxLines = 1, align = androidx.compose.ui.text.style.TextAlign.End, translate = false)
        }
    }
}

/** 타바타 · EMOM · AMRAP: 라운드 · 시간 (EMOM 은 끝낸 때) · 평균 심박 */
@Composable
private fun RoundsTable(rec: Record) {
    val rows = rec.segs.filter { it.kind != SegKind.Rox }
    SectionLabel("ROUNDS", top = 20.dp)
    Column(Modifier.fillMaxWidth().card8(18.dp)) {
        val emom = rec.kind == Kinds.EMOM
        TableRow("", C.text3, listOf((if (emom) "DONE IN" else "TIME").l10n, "AVG HR".l10n), false, header = true)
        rows.forEachIndexed { i, s ->
            val partial = rec.kind == Kinds.AMRAP && i == rows.size - 1
            val full = rec.kind != Kinds.TABATA || s.time >= s.target
            val name = if (partial) "Extra".l10n else s.name.l10n
            val time = if (emom) (s.work?.let { Fm.t(it) } ?: "–") else Fm.t(s.time)
            TableRow(name, if (partial || !full) C.text2 else Color.White, listOf(time, s.hr?.toString() ?: "–"), i == rows.size - 1,
                tag = "detail.round.$i")
        }
    }
    if (rec.kind == Kinds.EMOM) Note8("Done in: when you tapped Done in that round. The rest of the minute was your break.")
}

/** AMRAP 점수 + 남은 반 라운드에서 더 한 동작 수 (고칠 수 있음) */
@Composable
private fun AmrapScore(rec: Record) {
    SectionLabel("SCORE", top = 20.dp)
    Column(Modifier.fillMaxWidth().card8(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        T(Bonus.amrapScore(rec), F.num(28), Modifier.testTag("detail.amrapScore"), maxLines = 1, translate = false)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Label8("EXTRA REPS", Modifier.weight(1f))
            Stepper8("${rec.extra ?: 0}", minWidth = 44.dp, fontSize = 20, button = 32.dp, gap = 10.dp,
                down = { Store.updateRecord(rec.copy(extra = ((rec.extra ?: 0) - 1).takeIf { it > 0 })) },
                up = { Store.updateRecord(rec.copy(extra = ((rec.extra ?: 0) + 1).coerceAtMost(999))) })
        }
        T("Reps you did in the last unfinished round.", F.t(F.foot, color = C.text2))
    }
}

/** 인터벌 러닝: 단계 · 거리 · 시간 · 페이스 · 심박 (빠른 단계는 노랑) + 빠른 단계 평균 페이스 */
@Composable
private fun StepsTable(rec: Record) {
    val imp = Store.settings.imperial
    SectionLabel("STEPS", top = 20.dp)
    Bonus.fastPace(rec)?.let { fp ->
        Row(Modifier.fillMaxWidth().card8(18.dp).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Label8("FAST STEPS AVG PACE", Modifier.weight(1f))
            T(Fm.t(Units.pace(fp, imp)) + " " + Units.paceUnit(imp), F.num(20, color = C.accent), maxLines = 1, translate = false)
        }
    }
    Column(Modifier.fillMaxWidth().card8(18.dp)) {
        TableRow("", C.text3, listOf("DISTANCE".l10n, "TIME".l10n, "PACE".l10n), false, header = true)
        rec.segs.forEachIndexed { i, s ->
            val fast = s.name == "Fast"
            val d = s.dist
            val pace = if (d != null && d >= 50 && s.kind == SegKind.Run) Fm.t(Units.pace((s.time / d * 1000).roundToInt(), imp)) else "–"
            val dist = if (d != null && d > 0) Units.dist(d, imp) + " " + Units.distUnit(imp) else "–"
            val label = s.name.l10n + (s.rep?.let { " $it" } ?: "")
            TableRow(label, if (fast) C.accent else if (s.kind == SegKind.Rox) C.text2 else Color.White,
                listOf(dist, Fm.t(s.time), pace), i == rec.segs.size - 1, tag = "detail.step.$i")
        }
    }
}

/** 기능성 운동: 총 볼륨 · 지난번 대비 + 종목별 세트 표 (횟수 · 무게를 고칠 수 있음 — 워치로 한 세트는 계획 값) */
@Composable
private fun LiftTables(rec: Record) {
    val vol = Bonus.volume(rec)
    val prev = remember(rec, Store.records) { Bonus.prevVolume(Store.records, rec) }
    var edit by remember(rec.id) { mutableStateOf(false) }
    SectionLabel("VOLUME", top = 20.dp)
    Column(Modifier.fillMaxWidth().card8(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        T(Bonus.kgText(vol), F.num(28), Modifier.testTag("detail.volume"), maxLines = 1, translate = false)
        if (prev != null && prev > 0) {
            val d = vol - prev
            val txt = if (d >= 0) L10n.t("+%@ vs last time", Bonus.kgText(d)) else L10n.t("−%@ vs last time", Bonus.kgText(-d))
            T(txt, F.t(F.foot, W600, if (d >= 0) C.good else C.bad), maxLines = 1, translate = false)
        }
    }
    Row(Modifier.fillMaxWidth().padding(top = 20.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        T("SETS", F.t(F.sub, W600), Modifier.weight(1f), maxLines = 1)
        T(if (edit) "Done" else "Edit", F.t(F.sub, W600, C.accent), Modifier.tap { edit = !edit }.testTag("detail.liftEdit"), maxLines = 1)
    }
    for ((name, sets) in Bonus.liftTable(rec)) {
        Column(Modifier.fillMaxWidth().padding(top = 8.dp).card8(18.dp)) {
            TableRow(name.l10n, Color.White, listOf("REPS".l10n, "KG", "TIME".l10n), false, header = false)
            sets.forEachIndexed { i, s ->
                if (edit) LiftEditRow(rec, s, i == sets.size - 1)
                else TableRow(L10n.t("Set %lld", s.rep ?: (i + 1)), C.text2,
                    listOf("${s.reps ?: "–"}", s.kg?.let { if (it > 0) Bonus.kgText(it).removeSuffix(" kg") else "–" } ?: "–", Fm.t(s.time)),
                    i == sets.size - 1)
            }
        }
    }
}

/** 세트 한 줄 고치기 (횟수 ±1 · 무게 ±2.5) */
@Composable
private fun LiftEditRow(rec: Record, s: SegResult, last: Boolean) {
    fun put(n: SegResult) {
        val i = rec.segs.indexOfFirst { it === s }.takeIf { it >= 0 } ?: rec.segs.indexOf(s)
        if (i < 0) return
        Store.updateRecord(rec.copy(segs = rec.segs.toMutableList().also { it[i] = n }))
    }
    Column(Modifier.fillMaxWidth().rowLine(!last).padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        T(L10n.t("Set %lld", s.rep ?: 1), F.t(13, W600, C.text2), maxLines = 1, translate = false)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Stepper8("${s.reps ?: 0}", minWidth = 32.dp, fontSize = 17, button = 30.dp, gap = 8.dp,
                down = { put(s.copy(reps = ((s.reps ?: 0) - 1).coerceAtLeast(0))) }, up = { put(s.copy(reps = ((s.reps ?: 0) + 1).coerceAtMost(999))) })
            Spacer(Modifier.weight(1f))
            Stepper8(Bonus.kgText(s.kg ?: 0.0).removeSuffix(" kg"), minWidth = 44.dp, fontSize = 17, button = 30.dp, gap = 8.dp,
                down = { put(s.copy(kg = ((s.kg ?: 0.0) - 2.5).coerceAtLeast(0.0))) }, up = { put(s.copy(kg = ((s.kg ?: 0.0) + 2.5).coerceAtMost(999.0))) })
        }
    }
}
