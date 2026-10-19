package com.nkssi.splits8.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fatigue
import com.nkssi.splits8.shared.FatigueResult
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.PFTGrade
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.EmptyHistory
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.FoldChips
import com.nkssi.splits8.ui.HistoryHeader
import com.nkssi.splits8.ui.HistoryRow
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PFTBadge
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.PagedCard
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.Toggle8
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

// 아이폰 PFTViews.swift (Test 탭 · PFT) + SimRaceViews.swift 의 SimView · TrendChart · RunFatigueCard, Predict.swift 의 PredictCard

// MARK: - Test 탭 (세 번째 탭): 위에서 PFT / Full Sim 을 고름

@Composable
fun TestView() {
    Scroll8 {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            TestSeg(Router.testTab, Modifier.padding(horizontal = PageSide)) { Router.setTest(it) }
            Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (Router.testTab == "sim") SimView() else PFTView()
            }
        }
    }
}

/** Full Sim | PFT — 88번(빌드 28): Full Sim 이 메인 → 왼쪽 (40 높이, 고른 쪽은 노랑 바탕 + 검정 글자) */
@Composable
private fun TestSeg(selected: String, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    Row(modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.segTrack).padding(3.dp)) {
        for ((k, l) in listOf("sim" to "Full Sim", "pft" to "PFT")) {
            val on = selected == k
            Box(
                Modifier.weight(1f).height(34.dp).clip(RoundedCornerShape(9.dp)).background(if (on) C.accent else Color.Transparent)
                    .tap { onSelect(k) }.testTag("test.seg.$k"),
                contentAlignment = Alignment.Center,
            ) { T(l, F.t(15, W600, if (on) Color.Black else C.text2), maxLines = 1) }
        }
    }
}

/** 한 줄 설명 + ⓘ (누르면 설명 시트) */
@Composable
private fun TestIntro(text: String, tag: String, onInfo: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = 4.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        T(text, F.t(F.foot, color = C.text2).copy(lineHeight = 18.sp), Modifier.weight(1f))
        InfoButton(tag, onInfo)
    }
}

/** ⓘ 단추 (회색, 누르는 자리 36) */
@Composable
private fun InfoButton(tag: String, onClick: () -> Unit) {
    Box(Modifier.size(36.dp).tap(onClick = onClick).testTag(tag), contentAlignment = Alignment.Center) {
        Sym(R.drawable.sym_info, 21.dp, C.text2)
    }
}

// MARK: - PFT 문구

private object PFTText {
    /** Gold 기준까지 얼마나 남았는지 / 얼마나 여유 있는지 */
    fun gap(total: Int): String = when (PFT.grade(total)) {
        PFTGrade.Gold -> L10n.t("%@ inside Gold", Fm.t(PFT.goldLimit - total))
        PFTGrade.Silver -> L10n.t("%@ to Gold", Fm.t(total - PFT.goldLimit + 1))
        PFTGrade.Bronze -> L10n.t("%@ to Silver", Fm.t(total - PFT.silverLimit))
        PFTGrade.Iron -> L10n.t("%@ to Bronze", Fm.t(total - PFT.bronzeLimit))
        PFTGrade.Unranked -> L10n.t("%@ to Iron", Fm.t(total - PFT.ironLimit))
    }

    /** 설명 카드의 등급 기준 */
    fun range(g: PFTGrade): String = when (g) {
        PFTGrade.Gold -> "Under 22:00".l10n
        PFTGrade.Silver -> "Within 26:00".l10n
        PFTGrade.Bronze -> "Within 30:00".l10n
        PFTGrade.Iron -> "Within 35:00".l10n
        PFTGrade.Unranked -> "Over 35:00".l10n
    }
}

// MARK: - PFT 화면

@Composable
private fun PFTView() {
    val recs = Store.book.records(Mode.Pft)
    if (recs.isEmpty()) {
        // 처음: 무엇인지 + 등급 기준 + 종목 + 시작
        PFTAboutCard(onInfo = { Router.testInfo = "pft" })
        PFTMovesCard(Store.settings.div)
        YellowButton("Start on phone", height = 50.dp, tag = "startOnPhone.pft") { askStartOnPhone(Mode.Pft) }
        T("or start PFT on your watch", F.t(F.foot, color = C.text3), Modifier.fillMaxWidth(),
            align = androidx.compose.ui.text.style.TextAlign.Center)
    } else {
        TestIntro("Physical Fitness Test · six movements back to back, for time.", "pft.info") { Router.testInfo = "pft" }
        PFTBestCard()
        PFTMovesCard(Store.settings.div)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { StartOnPhoneButton(Mode.Pft, null) }
        HistoryHeader()
        PagedCard(recs.size) { i, last -> PFTHistoryRow(recs, i, last) }
    }
}

/** 최고 기록 카드 (등급 뱃지 + 큰 시간 + Gold 까지 남은 시간 + 등급 막대) */
@Composable
private fun PFTBestCard() {
    val best = Store.book.pftBest
    val grade = best?.pftGrade
    val line = best?.let { "Best".l10n + " · " + Fm.ddmy(it.date) } ?: "None yet".l10n
    Column(Modifier.fillMaxWidth().card8().padding(18.dp).testTag("pft.best")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(line, F.t(F.foot, color = C.text2), Modifier.weight(1f), maxLines = 1, translate = false)
            if (grade != null) PFTBadge(grade)
        }
        Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.Bottom) {
            T(best?.let { Fm.t(it.total) } ?: "--:--", F.num(44, tracking = -1.76f), Modifier.weight(1f), maxLines = 1, translate = false)
            if (best != null) {
                T(PFTText.gap(best.total), F.t(F.foot, W600, if (grade == PFTGrade.Gold) C.good else C.text2),
                    Modifier.padding(bottom = 9.dp), maxLines = 1, translate = false)
            }
        }
        PFTScale(best?.total, Modifier.padding(top = 14.dp))
    }
}

@Composable
private fun PFTHistoryRow(recs: List<Record>, i: Int, last: Boolean) {
    val rec = recs[i]
    val older = recs.drop(i + 1).firstOrNull { it.counts }
    val isBest = rec.id == Store.book.pftBest?.id
    val d: Int? = if (rec.counts) older?.let { rec.total - it.total } else null
    val pb = isBest && recs.count { it.counts } >= 2
    val sub = when {
        pb -> "Personal best".l10n
        d != null -> (if (d <= 0) "↓ " else "↑ ") + Fm.t(kotlin.math.abs(d)) + " " + "vs last".l10n
        else -> Fm.time12(rec.date)
    }
    val color = when {
        pb -> C.accent
        d == null -> C.text2
        d <= 0 -> C.good
        else -> C.bad
    }
    HistoryRow(Fm.wdm(rec.date), sub, Fm.t(rec.total), subColor = color, last = last, flag = rec.flag, grade = rec.pftGrade,
        onDelete = { Store.delete(rec) }) { Router.open(rec, Scr.Sim) }
}

/** 설명 카드 (무엇인지 + 등급 기준). onInfo 가 있으면 제목 오른쪽에 ⓘ */
@Composable
private fun PFTAboutCard(onInfo: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().card8().padding(18.dp).testTag("pft.about")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T("Physical Fitness Test", F.t(F.title3, W600, tracking = -0.4f), Modifier.weight(1f), maxLines = 1)
            if (onInfo != null) Box(Modifier.offset(x = 8.dp).heightIn(max = 24.dp), contentAlignment = Alignment.Center) { InfoButton("pft.info", onInfo) }
        }
        T("Six movements back to back, no rest. Your total time shows your level.", F.t(F.sub, color = C.text2).copy(lineHeight = 21.sp),
            Modifier.padding(top = 6.dp))
        Column(Modifier.padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (g in PFTGrade.entries) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PFTBadge(g)
                    T(PFTText.range(g), F.num(F.sub, W400), maxLines = 1, translate = false)
                }
            }
        }
    }
}

/** 종목 6개 (아이콘 · 이름 · 양) */
@Composable
private fun PFTMovesCard(div: Division) {
    Column(Modifier.fillMaxWidth().card8()) {
        PFT.items.forEachIndexed { i, it ->
            Row(Modifier.fillMaxWidth().rowLine(i < PFT.items.size - 1).padding(vertical = 12.dp, horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon8(it.icon, 24.dp, C.accent)
                T(it.long, F.t(F.body), Modifier.weight(1f), maxLines = 1)
                T(PFT.amount(i, div), F.num(F.foot, color = C.text2, tracking = 0.39f), maxLines = 1, translate = false)
            }
        }
    }
}

// MARK: 등급 막대 (Gold | Silver | Bronze | Iron | Unranked + 내 기록 위치) — 아이폰 빌드 26

/** 칸 끝 위치 */
private val PFT_ENDS = listOf(0.30f, 0.50f, 0.68f, 0.86f, 1.0f)
/** 칸 경계 시간(초): 12:00 · 22:00 · 26:00 · 30:00 · 35:00 · 40:00 */
private val PFT_MARKS = listOf(12 * 60f, PFT.goldLimit.toFloat(), PFT.silverLimit.toFloat(), PFT.bronzeLimit.toFloat(), PFT.ironLimit.toFloat(), 40 * 60f)

/** 기록 위치 0…1 */
internal fun pftPos(t: Int): Float {
    val x = t.toFloat()
    var start = 0f
    for (i in PFT_ENDS.indices) {
        val a = PFT_MARKS[i]
        val b = PFT_MARKS[i + 1]
        if (x <= b || i == PFT_ENDS.size - 1) {
            val f = ((x - a) / (b - a)).coerceIn(0f, 1f)
            return start + (PFT_ENDS[i] - start) * f
        }
        start = PFT_ENDS[i]
    }
    return 1f
}

@Composable
private fun PFTScale(total: Int?, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val w = maxWidth
        val widths = PFT_ENDS.indices.map { w * (PFT_ENDS[it] - (if (it == 0) 0f else PFT_ENDS[it - 1])) }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.fillMaxWidth().height(18.dp), contentAlignment = Alignment.CenterStart) {
                Row(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    PFTGrade.entries.forEachIndexed { i, g ->
                        Box(Modifier.width(widths[i] - 2.dp).height(10.dp).background(Brush.horizontalGradient(listOf(hex(g.hex2), hex(g.hex1)))))
                    }
                }
                if (total != null) {
                    val x = (w * pftPos(total) - 2.dp).coerceIn(0.dp, w - 4.dp)
                    Box(
                        Modifier.offset(x = x).size(4.dp, 18.dp).testTag("pft.marker")
                            .background(Color.Black, RoundedCornerShape(3.dp)).padding(1.dp)
                            .background(Color.White, RoundedCornerShape(2.dp)),
                    )
                }
            }
            Row {
                listOf("Gold", "22:00", "26:00", "30:00", "35:00").forEachIndexed { i, s ->
                    T(s, F.num(F.cap2, color = C.text2), Modifier.width(widths[i]), maxLines = 1, translate = false)
                }
            }
        }
    }
}

// MARK: - Full Simulation

private data class Metric(val key: String, val label: String, val caption: String, val st: Int?)

private val simMetrics: List<Metric> = listOf(
    Metric("total", "TOTAL", "Total time · latest", null),
    Metric("run", "RUN AVG", "Avg 1KM run · latest", null),
    Metric("rox", "ROXZONE", "Roxzone total · latest", null),
) + listOf(
    Triple("skiErg", "SKIERG", "SkiErg"), Triple("sledPush", "SLED PUSH", "Sled Push"), Triple("sledPull", "SLED PULL", "Sled Pull"),
    Triple("burpeeBroadJump", "BBJ", "BBJ"), Triple("row", "ROW", "Row"), Triple("farmersCarry", "FARMERS", "Farmers Carry"),
    Triple("sandbagLunges", "LUNGES", "Lunges"), Triple("wallBalls", "WALL BALLS", "Wall Balls"),
).mapIndexed { i, (k, l, c) -> Metric(k, l, "$c · latest", i) }

private fun simValue(rec: Record, m: String): Int? = when (m) {
    "total" -> rec.total
    "run" -> rec.runs.map { it.time }.takeIf { it.isNotEmpty() }?.let { kotlin.math.round(it.sum().toDouble() / it.size).toInt() }
    "rox" -> rec.roxTotal
    else -> rec.segs.lastOrNull { it.icon == m }?.time
}

private fun runAvg(a: List<Int>): Int {
    if (a.size < 16) return 0
    return kotlin.math.round((0 until 16 step 2).sumOf { a[it] } / 8.0).toInt()
}

/** 비교 기준 (Goal / Last / 친구) */
private fun simRef(m: Metric, prev: Int?): Int? {
    val s = Store.settings
    val g = s.goals
    val goalOf = when (m.key) {
        "total" -> g.sum() + 8 * s.roxTarget
        "run" -> runAvg(g)
        "rox" -> 8 * s.roxTarget
        else -> g.getOrElse((m.st ?: 7) * 2 + 1) { 0 }
    }
    return when (s.simCmp) {
        "goal" -> goalOf
        "friend" -> {
            val f = Store.friend ?: return prev
            when (m.key) {
                "total" -> f.total
                "run" -> if (f.hasSplits) runAvg(f.splits) else null
                "rox" -> 8 * s.roxTarget
                else -> if (f.hasSplits) f.splits[(m.st ?: 7) * 2 + 1] else null
            }
        }
        else -> prev
    }
}

private fun cmpLabel(): String = when (Store.settings.simCmp) {
    "goal" -> "VS GOAL".l10n
    "friend" -> Store.friend?.let { "VS " + it.first.uppercase() } ?: "VS LAST".l10n
    else -> "VS LAST".l10n
}

@Composable
private fun SimView() {
    var metric by remember { mutableStateOf("total") }
    var chipsOpen by remember { mutableStateOf(false) }
    val cur = simMetrics.firstOrNull { it.key == metric } ?: simMetrics[0]
    val sims = Store.book.records(Mode.Sim)
    val pts = sims.filter { it.counts }.take(6).reversed().mapNotNull { r -> simValue(r, metric)?.let { r.date to it } }

    TestIntro("Full Simulation · the full race order, 8 runs + 8 stations, for time.", "sim.info") { Router.testInfo = "sim" }

    // 그래프 카드
    Column(Modifier.fillMaxWidth().card8().padding(18.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        FoldChips(chipsOpen, { chipsOpen = !chipsOpen }, spacing = 6.dp, height = 30.dp, radius = 8.dp,
            pinned = simMetrics.indexOfFirst { it.key == metric }, tag = "sim.chips.more") {
            for (c in simMetrics) {
                val on = metric == c.key
                Box(Modifier.height(30.dp).clip(RoundedCornerShape(8.dp)).background(if (on) C.accent else C.btn1A)
                    .tap { metric = c.key }.testTag("sim.metric." + c.key).padding(horizontal = 12.dp),
                    contentAlignment = Alignment.Center) {
                    T(c.label, F.t(11, W600, if (on) Color.Black else C.aeb, tracking = 0.88f), maxLines = 1)
                }
            }
        }
        val last = pts.lastOrNull()?.second
        val prev = if (pts.size >= 2) pts[pts.size - 2].second else null
        val rf = simRef(cur, prev)
        Row(verticalAlignment = Alignment.Bottom) {
            // 빌드 26: 큰 시간을 누르면 목표 시간 시트
            Column(Modifier.weight(1f).tap { Router.raceSheet = "goal" }.testTag("sim.bigTime"), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                // 종목 칸은 "SkiErg · 최근" (이름은 영어 그대로 — 아이폰과 같음)
                val cap = if (cur.st == null) cur.caption.l10n else cur.caption.substringBefore(" · ") + " · " + "latest".l10n
                T(cap, F.t(13, color = C.text2), maxLines = 1, translate = false)
                T(last?.let { Fm.t(it) } ?: "--:--", F.num(44, tracking = -1.76f), maxLines = 1, translate = false)
            }
            if (last != null && rf != null) {
                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T((if (last <= rf) "−" else "+") + Fm.t(kotlin.math.abs(last - rf)), F.num(20, color = if (last <= rf) C.good else C.bad),
                        maxLines = 1, translate = false)
                    T(cmpLabel(), F.t(11, W600, C.text2, tracking = 0.88f), maxLines = 1, translate = false)
                }
            }
        }
        if (pts.size >= 2) {
            TrendChart(pts.map { it.second }, Modifier.padding(horizontal = 8.dp).padding(top = 6.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                for ((d, _) in pts) T(Fm.axis(d), F.num(11, W400, C.text3), maxLines = 1, translate = false)
            }
        }
    }

    // BEST
    val best = Store.book.simBest
    Row(Modifier.fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Label8("BEST")
            T(best?.let { Fm.ddmy(it.date) } ?: "None yet".l10n, F.t(13, color = C.text3), maxLines = 1, translate = false)
        }
        T(best?.let { Fm.t(it.total) } ?: "--:--", F.num(28, color = C.accent, tracking = -0.84f), maxLines = 1, translate = false)
    }

    PredictCard()
    SimSettingsCard()
    // 87번: 목표 시간 · 구간 목표는 Race 와 같은 값 (한쪽에서 바꾸면 둘 다)
    Note8("Goal time and split targets are shared with Race. Compare with sets what you race against during a Full Simulation: Goal, your latest Full Sim, or a friend.")
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { StartOnPhoneButton(Mode.Sim, null) }

    Fatigue.analyze(sims.filter { it.counts })?.let { f ->
        SectionLabel("RUN FATIGUE", top = 20.dp)
        RunFatigueCard(f, L10n.t("Average of your last %lld Full Sims", f.count))
    }

    HistoryHeader()
    if (sims.isEmpty()) {
        EmptyHistory()
    } else {
        PagedCard(sims.size) { i, last ->
            val rec = sims[i]
            val older = sims.getOrNull(i + 1)
            val isBest = rec.id == best?.id
            val d = older?.let { rec.total - it.total }
            val sub = when {
                isBest -> "Personal best".l10n
                d != null -> (if (d <= 0) "↓ " else "↑ ") + Fm.t(kotlin.math.abs(d)) + " " + "vs last".l10n
                else -> " "
            }
            val color = if (isBest) C.accent else if ((d ?: 0) <= 0) C.good else C.bad
            HistoryRow(Fm.wdm(rec.date), sub, Fm.t(rec.total), subColor = color, last = last, pb = Store.book.isPB(rec),
                flag = rec.flag, partner = rec.partner, onDelete = { Store.delete(rec) }) { Router.open(rec, Scr.Sim) }
        }
    }
}

/** 설정 카드 (줄 높이 52): Division › · Compare with (Goal | Last | 친구) · Add Roxzone */
@Composable
private fun SimSettingsCard() {
    val s = Store.settings
    val items = listOf("goal" to "Goal", "last" to "Last") + (Store.friend?.let { listOf("friend" to it.first) } ?: emptyList())
    Column(Modifier.fillMaxWidth().card8()) {
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).rowLine(true).tap { Router.sub(Scr.SetDiv, Scr.Sim) }.testTag("sim.division")
            .padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            T("Division", F.t(17), Modifier.weight(1f), maxLines = 1)
            T(s.div.name, F.t(15, color = C.text2), maxLines = 1, translate = false)
            Chevron8()
        }
        // 87번(빌드 28): Race 와 같은 줄 — 더블 계획(더블일 때) · 목표 시간 · 구간 목표. 목표는 Race 와 같은 값을 씀
        if (s.division.startsWith("dbl")) {
            SimRow("Doubles plan", doublesValue()) { Router.raceSheet = "doubles" }
        }
        SimRow("Goal time", Fm.t(s.goalTime) + " ›", numeric = true) { Router.raceSheet = "goal" }
        Column(Modifier.fillMaxWidth().rowLine(true).tap { Router.sub(Scr.SetGoals, Scr.Sim) }.testTag("sim.splitTargets")
            .padding(top = 14.dp, start = 18.dp, end = 18.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row {
                T("Split targets", F.t(17), Modifier.weight(1f), maxLines = 1)
                T("Edit".l10n + " ›", F.t(17, color = C.text2), maxLines = 1, translate = false)
            }
            SplitBars(s.goals, 40) { minOf(1f, maxOf(0f, it / 335f)) }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).rowLine(true).padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            T("Compare with", F.t(17), Modifier.weight(1f), maxLines = 1)
            Seg8(items, s.simCmp, Modifier.testTag("sim.cmp"), height = 28.dp, radius = 9.dp, minWidth = 56.dp) { k ->
                Store.update { it.copy(simCmp = k) }
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            T("Add Roxzone", F.t(17), Modifier.weight(1f), maxLines = 1)
            Toggle8(s.roxAuto, Modifier.testTag("sim.rox")) { on -> Store.update { it.copy(roxAuto = on) } }
        }
    }
}

/** Full Sim 설정 줄 (52 높이): 제목 17 · 값 17 회색 */
@Composable
private fun SimRow(t: String, value: String, numeric: Boolean = false, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).rowLine(true).tap(onClick = onClick).testTag("sim.$t").padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        T(t, F.t(17), Modifier.weight(1f), maxLines = 1)
        T(value, if (numeric) F.num(17, W400, C.text2) else F.t(17, color = C.text2), maxLines = 1, translate = false)
    }
}

/**
 * 변화 그래프 (높이 150): 격자 y 30/75/120 #1C1C1C · 노란 2 선 · 점 6(검정 + 노란 테) · 마지막 10 노랑 · 값 라벨
 */
@Composable
fun TrendChart(values: List<Int>, modifier: Modifier = Modifier) {
    val tm = rememberTextMeasurer()
    val small = F.num(10, color = C.text3)
    val big = F.num(13, color = Color.White)
    Canvas(modifier.fillMaxWidth().height(150.dp)) {
        val n = values.size
        val w = size.width
        val u = 1.dp.toPx()
        val mn = values.minOrNull() ?: 0
        val mx = values.maxOrNull() ?: 1
        val span = maxOf(1, mx - mn).toFloat()
        val xs = (0 until n).map { w * (0.04f + it * 0.92f / maxOf(1, n - 1)) }
        val ys = values.map { (30f + (it - mn) / span * 90f) * u }
        for (gy in listOf(30f, 75f, 120f)) drawLine(Color(0xFF1C1C1C), Offset(0f, gy * u), Offset(w, gy * u), u)
        val p = Path()
        for (i in 0 until n) if (i == 0) p.moveTo(xs[i], ys[i]) else p.lineTo(xs[i], ys[i])
        drawPath(p, C.accent, style = Stroke(2 * u, cap = StrokeCap.Round, join = StrokeJoin.Round))
        for (i in 0 until n) {
            val last = i == n - 1
            val r = (if (last) 10f else 6f) / 2 * u
            val c = Offset(xs[i], ys[i])
            drawCircle(if (last) C.accent else Color.Black, r, c)
            drawCircle(C.accent, r + u, c, style = Stroke(2 * u))
            val lay = tm.measure(Fm.t(values[i]), if (last) big else small)
            // 라벨 아래 끝이 점 위 12
            val top = c.y - 12 * u - lay.size.height + (if (last) 2 * u else 1 * u)
            val left = (c.x - lay.size.width / 2f).coerceIn(0f, w - lay.size.width)
            drawText(lay, topLeft = Offset(left, top))
        }
    }
}

// MARK: 예상 완주 · 러닝 피로도

/** Full Sim · Race 탭의 예상 완주 시간 카드. 자료가 모자라면 안 보임 */
@Composable
fun PredictCard() {
    val p = Store.book.predictFinish(Store.now()) ?: return
    Column(Modifier.fillMaxWidth().card8().padding(vertical = 14.dp, horizontal = 18.dp).testTag("predict.card"),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Label8("PREDICTED FINISH", Modifier.weight(1f))
            T(Fm.t(p), F.num(28, color = C.accent, tracking = -0.84f), maxLines = 1, translate = false)
        }
        T("Estimated from your best segments in the last 90 days — not a guarantee.", F.t(F.foot, color = C.text3).copy(lineHeight = 18.sp))
    }
}

/** 스테이션 다음 1KM 가 내 평균 러닝보다 얼마나 느려지는지. 가장 큰 것 노랑 */
@Composable
fun RunFatigueCard(result: FatigueResult, footnote: String) {
    val worst = result.worst
    Column(Modifier.fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp).testTag("sim.fatigue")) {
        T(L10n.t("How much slower the 1 km after each station is, against your average run of %@ /km", Fm.t(result.avgRun)),
            F.t(F.sub, color = C.text2), translate = false)
        Column(Modifier.padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
            result.names.forEachIndexed { i, name ->
                val d = result.deltas[i]
                val top = worst == i
                val frac = if (d == null || d <= 0) 0.03f else (d.toFloat() / result.maxDelta).coerceIn(0.03f, 1f)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    T(name, F.t(F.sub), Modifier.width(104.dp), maxLines = 1)
                    Box(Modifier.weight(1f).height(10.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.08f))) {
                        Box(Modifier.fillMaxWidth(frac).height(10.dp).clip(CircleShape).background(if (top) C.accent else C.text2))
                    }
                    T(d?.let { Fm.d(it) } ?: "—", F.num(F.sub, color = if (top) C.accent else Color.White), Modifier.width(56.dp),
                        maxLines = 1, align = androidx.compose.ui.text.style.TextAlign.End, translate = false)
                }
            }
        }
        val wd = worst?.let { result.deltas[it] }
        if (worst != null && wd != null) {
            val name = result.names[worst]
            val head = L10n.t("The run after %@", name.l10n)
            val rest = L10n.t(" is your slowest (%@). Practice compromised running straight off %@.", Fm.d(wd), name.l10n)
            androidx.compose.foundation.text.BasicText(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = C.accent, fontWeight = W600)) { append(head) }
                    append(rest)
                },
                Modifier.padding(top = 14.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color(0x1AFFE600))
                    .padding(vertical = 10.dp, horizontal = 12.dp),
                style = F.t(F.sub).copy(lineHeight = 21.sp),
            )
        } else {
            T("You're holding your average pace on the runs after stations too.", F.t(F.sub),
                Modifier.padding(top = 14.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.06f))
                    .padding(vertical = 10.dp, horizontal = 12.dp))
        }
        T(footnote, F.t(F.foot, color = C.text2), Modifier.padding(top = 10.dp), translate = false)
    }
}

// MARK: - 설명 시트 (ⓘ)

@Composable
fun TestInfoSheet(kind: String) {
    val close = { Router.testInfo = null }
    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 2.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (kind == "pft") {
            NavBar3("Close", "PFT", edgeBack = false, onLeft = close)
            PFTAboutCard()
            SectionLabel("HOW IT WORKS", top = 10.dp)
            val rows = listOf(
                Triple("run", "Run", "1000 m. Outdoors, or on a treadmill at 2% incline."),
                Triple("burpeeBroadJump", "Burpee Broad Jumps", "50 reps."),
                Triple("sandbagLunges", "Stationary Lunges", "100 reps, no weight."),
                Triple("row", "Row", "1000 m."),
                Triple("pushUp", "Hand-Release Push-Ups", "30 reps. Lift your hands off the floor at the bottom."),
                Triple("wallBalls", "Wall Balls", "100 reps. 6 kg ball for men, 4 kg for women."),
            )
            Column(Modifier.fillMaxWidth().card8()) {
                rows.forEachIndexed { i, (icon, title, sub) ->
                    Row(Modifier.fillMaxWidth().rowLine(i < rows.size - 1).padding(vertical = 12.dp, horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon8(icon, 24.dp, C.accent, Modifier.padding(top = 1.dp))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            T(title, F.t(F.body, W500))
                            T(sub, F.t(F.foot, color = C.text2).copy(lineHeight = 18.sp))
                        }
                    }
                }
            }
            Note8("The clock keeps running between movements. Tap Next (or swipe left on your watch) when you finish each one.",
                Modifier.padding(top = 4.dp))
            Note8("Grades are SPLITS8's own guide, not an official HYROX result.")
        } else {
            val div = Store.settings.div
            NavBar3("Close", "Full Simulation", edgeBack = false, onLeft = close)
            Column(Modifier.fillMaxWidth().card8().padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                T("Full Simulation", F.t(F.title3, W600, tracking = -0.4f))
                T("The full race order for time: a 1 km run before each of the 8 stations.", F.t(F.sub, color = C.text2).copy(lineHeight = 21.sp))
            }
            SectionLabel("STATIONS", top = 10.dp)
            Column(Modifier.fillMaxWidth().card8()) {
                Station.all.forEachIndexed { i, s ->
                    Row(Modifier.fillMaxWidth().rowLine(i < Station.all.size - 1).padding(vertical = 12.dp, horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon8(s.key, 24.dp, C.accent)
                        T("${i + 1}. " + s.name.l10n, F.t(F.body), Modifier.weight(1f), maxLines = 1, translate = false)
                        T(com.nkssi.splits8.shared.Units.detail(s.detail(div), Store.settings.imperial), F.num(F.foot, color = C.text2), maxLines = 1, translate = false)
                    }
                }
            }
            Note8("Weights follow your division. Turn on Add Roxzone to time the transitions separately.", Modifier.padding(top = 4.dp))
        }
    }
}
