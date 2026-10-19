package com.nkssi.splits8.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.shared.newId
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.ProgItem
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import com.nkssi.splits8.R
import com.nkssi.splits8.Config
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fatigue
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.HyroxBench
import com.nkssi.splits8.shared.Insight
import com.nkssi.splits8.shared.Insights
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFTGrade
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.RecordFlag
import com.nkssi.splits8.shared.RoutePt
import com.nkssi.splits8.shared.RunLaps
import com.nkssi.splits8.shared.RunMetrics
import com.nkssi.splits8.shared.RunPB
import com.nkssi.splits8.shared.SegKey
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.avgKmPace
import com.nkssi.splits8.shared.bestEffort
import com.nkssi.splits8.shared.HyroxRank
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.isPartialRun
import com.nkssi.splits8.shared.isTinyRun
import com.nkssi.splits8.shared.runMeters
import com.nkssi.splits8.ui.PBPill
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.mainSegs
import com.nkssi.splits8.shared.pace
import com.nkssi.splits8.shared.runDistance
import com.nkssi.splits8.shared.zoneSeconds
import com.nkssi.splits8.ui.Ambient
import com.nkssi.splits8.ui.AmbientLayer
import com.nkssi.splits8.ui.Avatar8
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.LightMode
import com.nkssi.splits8.ui.borderLight
import com.nkssi.splits8.ui.outerGlow
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.FlagPill
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.LargeTitle
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PFTBadge
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.SectionText
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import java.util.Locale
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// 기록 상세 (아이폰 DetailView.swift · Insights.swift 카드 · RunRouteViews.swift · BenchViews.swift)
// 아이폰 지도(MapKit) 자리는 구글 지도 (RouteMap.kt). 키가 없으면 지도 없이 경로만 그림

/** 빠르면 초록, 느리면 빨강, 같거나 없으면 회색 */
fun deltaColor(v: Int?): Color = when {
    v == null -> C.text2
    v < 0 -> C.good
    v > 0 -> C.bad
    else -> C.text2
}

/** 1,042 */
fun grouped(n: Int): String = String.format(Locale.US, "%,d", n)

/** 타일 한 칸 (라벨 · 값 · 단위). sub = 제목 줄 오른쪽의 작은 두 번째 값 */
private data class DetailTile(
    val label: String, val value: String, val unit: String = "",
    val color: Color = Color.White, val unitColor: Color = Color.Transparent, val sub: String = "",
)

private fun backLabel(from: Scr): String = when (from) {
    Scr.Training -> "Training"
    Scr.Sim -> "Test"
    Scr.Home -> "Home"
    else -> "Race"
}

// MARK: 화면

@Composable
fun DetailView() {
    val rec = Router.detail
    val from = Router.detailFrom
    val goBack = remember(from) { { Router.go(from) } }
    BackAction(goBack)
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            BackLink(backLabel(from).l10n, goBack)
            // 기록이 지워졌으면 뒤로만
            val r = rec?.let { d -> Store.records.firstOrNull { it.id == d.id } ?: d } ?: return@Column
            DetailContent(r)
        }
    }
}

@Composable
private fun DetailContent(rec: Record) {
    val book = Store.book
    Header(rec)
    val route = rec.route
    if (route != null && route.size >= 2) {
        RouteCard(route)
        // 러닝 카드 — 높이 그래프 (높이를 잰 경로만) · 같은 코스 바퀴 (3바퀴 이상)
        if (rec.mode == Mode.Training && rec.isRunKind) {
            if (route.count { it.h != null } >= 2) ElevationCard(route, rec.ascent)
            RunLaps.laps(route)?.let { LapsCard(it) }
        }
    }
    if (rec.mode == Mode.Pft) PftCard(rec)
    TilesGrid(rec)
    // 94번(빌드 28): 실내 러닝 — 거리는 손목 움직임 짐작값이라 빠르게 나올 수 있음 · 러닝 PB 에서 뺌
    if (rec.mode == Mode.Training && rec.isRunKind && rec.indoor == true) {
        Note8("Indoor run: distance is estimated from arm motion without GPS, so pace can look faster than it was. Indoor runs don't count toward running PBs.")
    }
    // 이 기록의 숫자로 고른 분석 2~4줄
    val ins = remember(rec, book) { Insights.make(rec, book) }
    if (ins.isNotEmpty()) InsightsCard(ins)
    if (showsPartner(rec)) {
        SectionLabel("PARTNER", top = 20.dp)
        PartnerRow(rec)
    }
    ShareButton()
    val f = Store.friend
    val me = rec.splits16
    if (f != null && me != null && f.splits.size == 16) FriendCard(rec, me, f)
    if (rec.hr.isNotEmpty()) {
        HrCard(rec)
        ZonesCard(rec)
    }
    if (rec.runs.isNotEmpty() && rec.mode != Mode.Pft) PaceCard(rec)
    if (rec.mode == Mode.Sim) {
        Fatigue.analyze(listOf(rec), limit = 1)?.let {
            SectionLabel("RUN FATIGUE", top = 20.dp)
            RunFatigueCard(it, "Based on this Full Sim".l10n)
        }
    }
    // SPLITS 라벨: margin 20 4 0
    Row(Modifier.fillMaxWidth().padding(top = 20.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.Bottom) {
        T(SectionText.shown("SPLITS"), F.t(F.sub, W600), Modifier.weight(1f), maxLines = 1, translate = false)
        if (rec.mode == Mode.Training) T("VS YOUR BEST", F.t(11, W600, C.text3, tracking = 0.6f), maxLines = 1)
    }
    Splits(rec)
    BenchSection(rec)
    // 빌드 25 (66번): 워치 Quick 은 한 번 쓰는 운동 → 마음에 들면 여기서 정식 트레이닝으로
    if (rec.mode == Mode.Training && rec.kind == null && rec.title.startsWith("Quick") && rec.segs.isNotEmpty())
        SaveQuickCard(rec, Modifier.padding(top = 10.dp))
    DeleteCard(rec, Modifier.padding(top = 10.dp))
}

// MARK: Quick → 내 트레이닝으로 저장 (빌드 25 · 66번)

object QuickSave {
    /** 이 기록의 구간 순서로 만든 트레이닝 (Roxzone 은 뺌) */
    fun program(rec: Record): Program {
        val items = rec.segs.filter { it.kind != SegKind.Rox }.map { s -> if (s.icon == "run") ProgItem("run", s.detail) else ProgItem(s.icon) }
        return Program(id = "t" + newId().take(8), name = rec.title, sets = 1, seq = items)
    }

    /** 같은 구간 순서의 트레이닝이 이미 목록에 있는지 */
    fun saved(rec: Record, programs: List<Program>): Boolean {
        val seq = program(rec).seq
        return programs.any { it.kind == null && it.sets == 1 && it.seq == seq }
    }
}

@Composable
private fun SaveQuickCard(rec: Record, modifier: Modifier) {
    var justSaved by remember(rec.id) { mutableStateOf(false) }
    val done = justSaved || QuickSave.saved(rec, Store.programs)
    val haptic = LocalHapticFeedback.current
    Row(
        modifier.fillMaxWidth().height(50.dp).card8(14.dp).press(enabled = !done) {
            if (Store.programs.size >= Program.freeLimit) {
                Router.ask = Ask(L10n.t("You can save up to %lld trainings", Program.freeLimit), "", cancel = null)
                return@press
            }
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            Store.saveProgram(QuickSave.program(rec))
            justSaved = true
        }.testTag("detail.saveQuick"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) {
        if (done) Check8(C.good, 18.dp)
        T(if (done) "Saved to My Trainings" else "Save to My Trainings", F.t(17, W600, if (done) C.good else C.accent), maxLines = 1)
    }
}

// MARK: 머리 (배지 · 날짜 · 큰 제목), padding 0 4 8

@Composable
private fun Header(rec: Record) {
    val pb = Store.book.isPB(rec)
    Box(Modifier.fillMaxWidth()) {
        if (pb) PBGlow(Modifier.matchParentSize())
        Column(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, bottom = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.clip(RoundedCornerShape(6.dp)).background(C.accent).padding(vertical = 3.dp, horizontal = 8.dp)) {
                    T(rec.mode.title, F.t(11, W600, Color.Black), maxLines = 1)
                }
                Label8(Fm.wdmy(rec.date))
                // 빌드 27: 러닝 PB 는 머리에 거리까지 ("★ 5K PB")
                Store.book.runPBLabel(rec)?.let { PBPill(it) }
                rec.flag?.let { FlagPill(it) }
            }
            // PFT 는 제목이 위 알약과 같아서 큰 제목을 뺌
            if (rec.mode != Mode.Pft) LargeTitle(rec.title, top = 10.dp)
            T(timePlace(rec), F.t(F.sub, color = C.text2),
                Modifier.padding(top = if (rec.mode == Mode.Pft) 10.dp else 6.dp).testTag("detail.timePlace"), maxLines = 1, translate = false)
            rec.flag?.let { fl ->
                T(if (fl == RecordFlag.Incomplete) "Ended early, so it isn't counted as a complete result."
                  else "This looks too fast to be a valid result. A tap may have been missed.",
                    F.t(13, color = C.text2), Modifier.padding(top = 6.dp))
            }
            partnerNick(rec)?.let { PartnerChip(rec, it) }
        }
    }
}

/** "오전 7:02 – 8:21 · 성수동, 서울" (동네 이름은 있을 때만) */
private fun timePlace(rec: Record): String {
    var s = Fm.time12(rec.date) + " – " + Fm.time12(rec.end)
    if (!rec.place.isNullOrEmpty()) s += " · " + rec.place
    return s
}

/** ★ PB 기록을 열면 머리 뒤에 큰 노란 빛 (0 → 1 (0.43초) → 0.45 (2.4초까지)) */
@Composable
private fun PBGlow(modifier: Modifier) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        a.animateTo(1f, tween(430))
        a.animateTo(0.45f, tween(1970))
    }
    AmbientLayer(
        Ambient(0xFFE600, 0.55f, 0.6f, 0.65f, 0.5f, 0.3f),
        modifier.layout { m, c ->
            // 머리보다 크게 (높이 300, 좌우 40 더, 위로 110)
            val side = 40.dp.roundToPx()
            val p = m.measure(Constraints.fixed(c.maxWidth + side * 2, 300.dp.roundToPx()))
            layout(c.maxWidth, c.maxHeight) { p.place(-side, -110.dp.roundToPx()) }
        }.graphicsLayer { alpha = a.value },
    )
}

// MARK: 더블 파트너

private fun isDoubles(rec: Record): Boolean = Division.all.firstOrNull { it.key == rec.division || it.name == rec.division }
    ?.key?.startsWith("dbl") ?: false

private fun partnerNick(rec: Record): String? = rec.partner?.trim()?.takeIf { it.isNotEmpty() }

private fun showsPartner(rec: Record): Boolean {
    if (rec.mode == Mode.Pft) return partnerNick(rec) != null     // PFT 는 혼자 하는 테스트
    return isDoubles(rec) || partnerNick(rec) != null
}

private val partnerPalette = listOf(0x30D158L, 0x0A84FFL, 0xFF9F0AL, 0xBF5AF2L, 0x64D2FFL, 0xFF375FL)

/** 닉네임마다 늘 같은 색 (아이폰과 같은 계산) */
fun partnerColor(nick: String): Color {
    var h = 0
    for (u in nick.lowercase().codePoints().toArray()) h = (h * 31 + u) and 0x7FFFFFFF
    return hex(partnerPalette[h % partnerPalette.size])
}

/** 제목 아래 알약: (M) with @minji · Doubles Mixed */
@Composable
private fun PartnerChip(rec: Record, nick: String) {
    val divName = if (isDoubles(rec)) Division.of(rec.division).name else ""
    Row(
        Modifier.padding(top = 8.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.10f))
            .padding(top = 5.dp, bottom = 5.dp, start = 5.dp, end = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Avatar8(22.dp, nick.take(1).uppercase(), bg = partnerColor(nick), fg = Color.Black)
        T(L10n.t("with @%@", nick), F.t(15, W600), maxLines = 1, translate = false)
        if (divName.isNotEmpty()) T("· " + divName.l10n, F.t(13, color = C.text2), maxLines = 1, translate = false)
    }
}

@Composable
private fun PartnerRow(rec: Record) {
    val nick = partnerNick(rec)
    Row(
        Modifier.fillMaxWidth().card8().tap { Router.partnerFor = rec.id }.testTag("detail.partner")
            .padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        T(if (nick == null) "Add partner" else "Partner", F.t(15, color = if (nick == null) C.accent else Color.White),
            Modifier.weight(1f), maxLines = 1)
        T((nick?.let { "@$it" } ?: "") + " ›", F.t(15, color = C.text2), maxLines = 1, translate = false)
    }
}

/** 파트너 고르기 시트 (친구 목록 · 직접 입력 · 빼기) */
@Composable
fun PartnerSheet(recordId: String) {
    val rec = Store.records.firstOrNull { it.id == recordId } ?: return
    val current = rec.partner
    val currentLower = (current ?: "").lowercase()
    var typing by remember(recordId) { mutableStateOf(false) }
    var typed by remember(recordId) { mutableStateOf("") }
    fun save(nick: String?) {
        var clean: String? = null
        if (nick != null) {
            val t = nick.trim().trimStart('@')
            clean = t.ifEmpty { null }
        }
        Store.updatePartner(rec.id, clean)
        Router.detail?.let { if (it.id == rec.id) Router.detail = it.copy(partner = clean) }
        Router.partnerFor = null
    }
    fun saveTyped() {
        if (typing && typed.isNotBlank()) save(typed)
    }
    Column(Modifier.padding(horizontal = 16.dp).padding(top = 0.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        NavBar3("Cancel", "Partner", right = if (typing) "Save" else null,
            rightColor = if (typed.isBlank()) C.g3A else C.accent, edgeBack = false,
            onLeft = { Router.partnerFor = null }, onRight = { saveTyped() })
        SectionLabel("CHOOSE PARTNER", top = 10.dp)
        Column(Modifier.fillMaxWidth().card8()) {
            for (f in Store.friends) {
                Row(
                    Modifier.fillMaxWidth().rowLine(true).tap { save(f.name) }.padding(vertical = 12.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Avatar8(30.dp, f.ini, bg = partnerColor(f.name), fg = Color.Black)
                    T("@" + f.name, F.t(15), Modifier.weight(1f), maxLines = 1, translate = false)
                    if (f.name.lowercase() == currentLower) Check8(size = 18.dp)
                }
            }
            if (typing) {
                val focus = remember { FocusRequester() }
                LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
                Row(Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 18.dp), horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    T("@", F.t(15, color = C.text2), translate = false)
                    Box(Modifier.weight(1f)) {
                        if (typed.isEmpty()) T("nickname", F.t(15, color = C.text3), maxLines = 1)
                        BasicTextField(typed, { typed = it }, Modifier.fillMaxWidth().focusRequester(focus).testTag("partner.field"),
                            textStyle = F.t(15), singleLine = true, cursorBrush = SolidColor(C.accent),
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false,
                                imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(onDone = { saveTyped() }))
                    }
                }
            } else {
                Box(Modifier.fillMaxWidth().tap {
                    val isFriend = Store.friends.any { it.name.lowercase() == currentLower }
                    typed = if (isFriend) "" else (current ?: "")
                    typing = true
                }.testTag("partner.type").padding(vertical = 14.dp, horizontal = 18.dp)) {
                    T("＋ Type a name", F.t(15, color = C.accent), maxLines = 1)
                }
            }
        }
        if (current != null) {
            Box(Modifier.padding(top = 10.dp).fillMaxWidth().height(50.dp).card8(14.dp).press { save(null) }.testTag("partner.remove"),
                contentAlignment = Alignment.Center) {
                T("Remove partner", F.t(17, W600, C.bad), maxLines = 1)
            }
        }
    }
}

// MARK: 타일 2열 (gap 10, radius 18, padding 14×16)

private fun tiles(rec: Record): List<DetailTile> {
    val book = Store.book
    val (word, value) = book.vs(rec)
    val imp = Store.settings.imperial
    val pace = rec.runPace?.let { Fm.t(Units.pace(it, imp)) } ?: "--:--"
    // PFT 는 총 시간·최고 기록 대비를 위의 큰 카드가 보여 줌
    val head: List<DetailTile> = when (rec.mode) {
        Mode.Pft -> emptyList()
        Mode.Training -> {
            // VS BEST 는 풀 시뮬 · 레이스에서만. 러닝은 거리, 그 외 트레이닝은 구간 수
            val second = if (rec.isRunKind) DetailTile("DISTANCE", Units.dist(rec.runDistance, imp), Units.distUnit(imp), unitColor = C.text2,
                sub = if (rec.indoor == true) "Indoor · est.".l10n else "")
            else DetailTile("SEGMENTS", "${rec.mainSegs.size}")
            listOf(DetailTile("TOTAL", Fm.t(rec.total)), second)
        }
        else -> listOf(
            DetailTile("TOTAL", Fm.t(rec.total)),
            DetailTile(word, value?.let { Fm.d(it) } ?: "--:--", color = deltaColor(value)),
        )
    }
    return head + listOf(
        DetailTile("AVG HR", if (rec.avgHR > 0) "${rec.avgHR}" else "--", "BPM", unitColor = C.bad),
        DetailTile("MAX HR", if (rec.maxHR > 0) "${rec.maxHR}" else "--", "BPM", unitColor = C.bad),
        DetailTile("CALORIES", grouped(rec.kcal), "KCAL", unitColor = C.text2),
        DetailTile("RUN PACE", pace, Units.paceUnit(imp), unitColor = C.text2),
    ) + runTiles(rec) + repTiles(rec) + bestTiles(rec)
}

/** 러닝 기록 — 평균 케이던스 · 보폭 · 오른 높이 (잰 값이 있을 때만) */
private fun runTiles(rec: Record): List<DetailTile> {
    if (rec.mode != Mode.Training || !rec.isRunKind) return emptyList()
    val out = ArrayList<DetailTile>()
    rec.cadence?.let { out.add(DetailTile("AVG CADENCE", "$it", "SPM", unitColor = C.text2)) }
    rec.stride?.let { out.add(DetailTile("STRIDE", String.format(Locale.US, "%.2f", it), "M", unitColor = C.text2)) }
    rec.ascent?.let { out.add(DetailTile("ASCENT", "${it.roundToInt()}", "M", unitColor = C.text2)) }
    return out
}

/** 러닝 기록 — 이번에 뛴 정해진 거리의 가장 빠른 시간. 최고 기록이면 ★ PB */
private fun bestTiles(rec: Record): List<DetailTile> {
    if (rec.mode != Mode.Training || !rec.isRunKind) return emptyList()
    val pbs = Store.book.runPBs(rec).toSet()
    return RunPB.distances.mapNotNull { (m, label) ->
        val t = rec.bestEffort(m) ?: return@mapNotNull null
        val pb = m in pbs
        DetailTile(label, Fm.t(t), if (pb) "★ PB" else "", unitColor = if (pb) C.accent else Color.Transparent)
    }
}

/** 스키 · 로잉: 큰 숫자 = 분당 횟수, 작은 숫자 = 총 횟수 / 월볼: 큰 숫자 = 개수, 작은 숫자 = 분당 */
private fun repTiles(rec: Record): List<DetailTile> = rec.repSummaries.map { s ->
    if (s.icon == "wallBalls") DetailTile("WALL BALLS", "${s.count}", "REPS".l10n, unitColor = C.text2, sub = "${s.perMin} " + "/MIN".l10n)
    else DetailTile(if (s.icon == "skiErg") "SKIERG" else "ROW", "${s.perMin}", "SPM".l10n, unitColor = C.text2,
        sub = "${s.count} " + "STROKES".l10n)
}

@Composable
private fun TilesGrid(rec: Record) {
    val items = tiles(rec)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (pair in items.chunked(2)) {
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    for (t in pair) TileView(t)
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
        // 횟수 카드가 있으면 짐작한 값이라는 안내 한 줄
        if (rec.repSummaries.isNotEmpty()) Note8("Counts are estimated from wrist motion.", Modifier.testTag("detail.repNote"))
    }
}

@Composable
private fun RowScope.TileView(t: DetailTile) {
    Column(Modifier.weight(1f).fillMaxHeight().card8(18.dp).padding(vertical = 14.dp, horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Label8(t.label, Modifier.weight(1f))
            if (t.sub.isNotEmpty()) T(t.sub, F.num(11, W600, C.aeb, tracking = 0.66f), maxLines = 1, translate = false)
        }
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            T(t.value, F.num(28, tracking = -0.84f, color = t.color), Modifier.weight(1f, fill = false), maxLines = 1, translate = false)
            if (t.unit.isNotEmpty()) T(t.unit, F.t(11, W600, t.unitColor, tracking = 0.66f), Modifier.padding(bottom = 4.dp), maxLines = 1, translate = false)
        }
    }
}

// MARK: PFT 총 시간 카드 (등급 뱃지 + 등급 색 얇은 테두리)

private fun pftRule(g: PFTGrade): String = when (g) {
    PFTGrade.Gold -> "Gold is under 22:00"
    PFTGrade.Silver -> "Silver is within 26:00"
    PFTGrade.Bronze -> "Bronze is within 30:00"
    PFTGrade.Iron -> "Iron is within 35:00"
    PFTGrade.Unranked -> "Finish within 35:00 for Iron"
}

@Composable
private fun PftCard(rec: Record) {
    val g = rec.pftGrade
    val v = Store.book.vs(rec).second
    val (line, color) = when {
        v == null -> "First record".l10n to C.text2
        v < 0 -> L10n.t("New best · %@", Fm.d(v)) to C.good
        else -> Fm.d(v) + " " + "vs best".l10n to (if (v == 0) C.text2 else C.bad)
    }
    val shape = RoundedCornerShape(20.dp)
    val border: Brush = if (g == null) SolidColor(C.cardBorder) else Brush.linearGradient(
        0f to hex(g.hex1, 0.9f), 0.45f to hex(g.hex2, 0.25f), 1f to Color.White.copy(alpha = 0.08f),
    )
    Column(
        Modifier.fillMaxWidth()
            // 빌드 26: 등급 색으로 은은하게 빛남 + 테두리 빛 한 바퀴 (Unranked · 등급 없음은 없음)
            .then(if (g != null && g != PFTGrade.Unranked) Modifier.outerGlow(hex(g.hex1, 0.28f), 20.dp, 18.dp) else Modifier)
            .borderLight(hex((g ?: PFTGrade.Unranked).hex1), if (g == null || g == PFTGrade.Unranked) LightMode.Off else LightMode.Once, 20.dp)
            .clip(shape).background(Color(0xFF121210))
            .border(1.dp, border, shape).testTag("detail.pft")
            .padding(top = 20.dp, start = 18.dp, end = 18.dp, bottom = 18.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Label8("TOTAL TIME", Modifier.weight(1f))
            if (g != null) PFTBadge(g)
        }
        T(Fm.t(rec.total), F.num(56, W700, tracking = -1.68f), Modifier.padding(top = 12.dp), maxLines = 1, translate = false)
        Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.Bottom) {
            T(line, F.t(F.foot, W600, color), Modifier.weight(1f), maxLines = 1, translate = false)
            if (g != null) T(pftRule(g), F.t(F.foot, color = C.text2), maxLines = 1)
        }
    }
}

// MARK: Insights (숫자 타일 바로 아래)

/** [y]…[/y] 노랑, [r]…[/r] 빨강, [g]…[/g] 초록 */
fun insightStyled(s: String): AnnotatedString = buildAnnotatedString {
    val re = Regex("\\[(y|r|g)\\](.*?)\\[/\\1\\]")
    var i = 0
    for (m in re.findAll(s)) {
        append(s.substring(i, m.range.first))
        val c = when (m.groupValues[1]) { "y" -> C.accent; "r" -> C.bad; else -> C.good }
        withStyle(SpanStyle(color = c, fontWeight = W600)) { append(m.groupValues[2]) }
        i = m.range.last + 1
    }
    append(s.substring(i))
}

@Composable
private fun InsightsCard(items: List<Insight>) {
    Column(Modifier.fillMaxWidth().card8().testTag("detail.insights").padding(top = 16.dp, bottom = 6.dp, start = 18.dp, end = 18.dp)) {
        Row(Modifier.padding(bottom = 10.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            T("Insights", F.t(F.sub, W600), maxLines = 1)
            T("From this record", F.t(F.foot, color = C.text3), maxLines = 1)
        }
        items.forEachIndexed { i, x ->
            Row(
                Modifier.fillMaxWidth().then(if (i > 0) Modifier.topLine(40.dp) else Modifier).padding(vertical = 10.dp).testTag("insight.${x.id}"),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                InsightBadge(x.mark)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    BasicText(insightStyled(x.text), style = F.t(15))
                    x.tip?.let { T(it, F.t(13, color = C.text2), translate = false) }
                }
            }
        }
    }
}

/** 위쪽 1px 선 (왼쪽 start 만큼 띄움) */
private fun Modifier.topLine(start: Dp): Modifier = drawBehind {
    drawLine(C.line, Offset(start.toPx(), 0f), Offset(size.width, 0f), 1.dp.toPx())
}

/** 28 정사각 기호 칸: ↓ 빨강 · ↑ 초록 · 그 밖 노랑 */
@Composable
private fun InsightBadge(m: Insight.Mark) {
    val (id, color) = when (m) {
        Insight.Mark.Down -> R.drawable.sym_arrow_down to C.bad
        Insight.Mark.Up -> R.drawable.sym_arrow_up to C.good
        Insight.Mark.Star -> R.drawable.sym_star to C.accent
        Insight.Mark.Time -> R.drawable.sym_stopwatch to C.accent
        Insight.Mark.Pct -> R.drawable.sym_percent to C.accent
        Insight.Mark.Heart -> R.drawable.sym_heart to C.hr
        Insight.Mark.Even -> R.drawable.sym_equal to C.accent
        Insight.Mark.Info -> R.drawable.sym_sparkles to C.accent
    }
    Box(Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(color.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
        Sym(id, 15.dp, color)
    }
}

// MARK: Share with photo (노랑, 52 높이, radius 14, 15/600)

@Composable
private fun ShareButton() {
    Row(
        Modifier.fillMaxWidth().height(52.dp).yellowFill(RoundedCornerShape(14.dp))
            .press(0.97f, tag = "Share with photo") { Router.go(Scr.Share) },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
    ) {
        Glyph("i_share", 18.dp, Color.Black)
        Spacer(Modifier.width(8.dp))
        T("Share with photo", F.t(15, W600, Color.Black), maxLines = 1)
    }
}

// MARK: VS 친구

private val friendFr = listOf(1.2f, 1f, 1f, 1f)

@Composable
private fun Cols(fr: List<Float>, cells: List<@Composable (Modifier) -> Unit>) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        cells.forEachIndexed { i, c -> c(Modifier.weight(fr[min(i, fr.size - 1)])) }
    }
}

@Composable
private fun FriendCard(rec: Record, me: List<Int>, f: Friend) {
    val name = f.first.split(" ").first()
    val up = name.uppercase()
    val frRuns = (0 until 16 step 2).sumOf { f.splits[it] }
    val frSt = (1 until 16 step 2).sumOf { f.splits[it] }
    val rows = listOf(
        Triple("Total", rec.total, f.total), Triple("Runs", rec.runTotal, frRuns),
        Triple("Stations", rec.stationTotal, frSt), Triple("Roxzone", rec.roxTotal, 8 * Store.settings.roxTarget),
    )
    Column(Modifier.fillMaxWidth().card8().testTag("detail.friend").padding(18.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Label8("VS $up", Modifier.weight(1f))
            T("${f.div.l10n} · ${f.date}", F.t(F.foot, color = C.text3), maxLines = 1, translate = false)
        }
        Column(Modifier.padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Cols(friendFr, listOf(
                { m -> Spacer(m) },
                { m -> Box(m, contentAlignment = Alignment.CenterEnd) { Label8("ME", spacing = 0.08f) } },
                { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(up, F.te(F.foot, W600, C.text2, em = 0.08f), maxLines = 1, translate = false) } },
                { m -> Box(m, contentAlignment = Alignment.CenterEnd) { Label8("DIFF", spacing = 0.08f) } },
            ))
            for ((label, mine, theirs) in rows) {
                val d = mine - theirs
                Cols(friendFr, listOf(
                    { m -> T(label, F.t(15), m, maxLines = 1) },
                    { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.t(mine), F.num(15), maxLines = 1, translate = false) } },
                    { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.t(theirs), F.num(15, color = C.text2), maxLines = 1, translate = false) } },
                    { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.d(d), F.num(15, color = deltaColor(d)), maxLines = 1, translate = false) } },
                ))
            }
        }
        // 16쌍 막대 (44 높이, gap 2, 쌍 안 gap 1, 340초 = 100%)
        Canvas(Modifier.fillMaxWidth().padding(top = 14.dp).height(44.dp)) {
            val gap = 2.dp.toPx()
            val pw = (size.width - gap * 15) / 16
            val bw = (pw - 1.dp.toPx()) / 2
            for (i in 0 until 16) {
                val x = i * (pw + gap)
                val hm = size.height * min(1f, me[i] / 340f)
                val hf = size.height * min(1f, f.splits[i] / 340f)
                drawRect(Color.White, Offset(x, size.height - hm), androidx.compose.ui.geometry.Size(bw, hm))
                drawRect(C.g3A, Offset(x + bw + 1.dp.toPx(), size.height - hf), androidx.compose.ui.geometry.Size(bw, hf))
            }
        }
        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LegendDot(Color.White, "Me".l10n)
            LegendDot(C.g3A, name)
            Spacer(Modifier.weight(1f))
            T("Run 1 → Wall Balls", F.t(F.foot, color = C.text3), maxLines = 1, translate = false)   // 아이폰도 영어 그대로
        }
    }
}

@Composable
private fun LegendDot(c: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(8.dp).background(c))
        T(label, F.t(F.foot, color = C.text3), maxLines = 1, translate = false)
    }
}

// MARK: 심박 그래프 (140 높이, 존 띠 5개, 점선 구간 경계, 빨간 1.6 선)

private val hrBands = listOf(
    hex(0xFF453A, 0.12f), hex(0xFF9F0A, 0.10f), hex(0x30D158, 0.08f), hex(0x0A84FF, 0.08f), hex(0x8E8E93, 0.08f),
)

@Composable
private fun HrCard(rec: Record) {
    val total = max(1, rec.total)
    val m3 = (total / 3) / 60 * 60
    val m6 = (total * 2 / 3) / 60 * 60
    // 구간 경계 (Roxzone 아닌 구간 끝마다, 마지막 빼고)
    val bounds = remember(rec) {
        val out = ArrayList<Float>()
        var acc = 0
        rec.segs.forEachIndexed { i, s ->
            acc += s.time
            if (s.kind != SegKind.Rox && i < rec.segs.size - 1) out.add(acc.toFloat() / total)
        }
        out.take(max(0, rec.mainSegs.size - 1))
    }
    val sample = remember(rec) {
        val pts = rec.hr.sortedBy { it.t }
        val step = max(1, pts.size / 240)
        (pts.indices step step).map { pts[it] }
    }
    Column(Modifier.fillMaxWidth().card8().testTag("detail.hr").padding(18.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Label8("HEART RATE", Modifier.weight(1f))
            T("Dotted lines = split boundaries", F.t(F.cap1, color = C.text3), maxLines = 1)
        }
        Canvas(Modifier.padding(top = 14.dp).fillMaxWidth().height(140.dp).clip(RoundedCornerShape(8.dp))) {
            val w = size.width
            val h = size.height
            val bh = h / 5
            for (i in 0 until 5) drawRect(hrBands[i], Offset(0f, i * bh), androidx.compose.ui.geometry.Size(w, bh))
            val dash = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 3.dp.toPx()))
            for (b in bounds) {
                val x = b * w
                drawLine(Color.White.copy(alpha = 0.14f), Offset(x, 0f), Offset(x, h), 1.dp.toPx(), pathEffect = dash)
            }
            val line = Path()
            sample.forEachIndexed { i, q ->
                val x = min(1f, q.t.toFloat() / total) * w
                val y = (h - (q.b - 90f) / 100f * h).coerceIn(0f, h)
                if (i == 0) line.moveTo(x, y) else line.lineTo(x, y)
            }
            drawPath(line, C.hr, style = Stroke(1.6.dp.toPx(), join = StrokeJoin.Round))
        }
        Row(Modifier.padding(top = 8.dp).fillMaxWidth()) {
            val st = F.num(11, androidx.compose.ui.text.font.FontWeight.Normal, C.text3)
            T("0:00", st, maxLines = 1, translate = false); Spacer(Modifier.weight(1f))
            T(Fm.t(m3), st, maxLines = 1, translate = false); Spacer(Modifier.weight(1f))
            T(Fm.t(m6), st, maxLines = 1, translate = false); Spacer(Modifier.weight(1f))
            T(Fm.t(rec.total), st, maxLines = 1, translate = false)
        }
    }
}

// MARK: 존별 시간 (gap 12)

@Composable
private fun ZonesCard(rec: Record) {
    val z = rec.zoneSeconds(Store.settings)
    val mx = max(1, z.maxOrNull() ?: 1)
    Column(Modifier.fillMaxWidth().card8().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Label8("TIME IN ZONES")
        for (i in 0 until 5) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                T("Z${i + 1}", F.t(13, W600, C.d1), Modifier.width(22.dp), maxLines = 1, translate = false)
                Canvas(Modifier.weight(1f).height(6.dp)) {
                    drawRect(C.btn1A)
                    drawRect(C.zones[i], size = size.copy(width = size.width * z[i] / mx))
                }
                Box(Modifier.width(44.dp), contentAlignment = Alignment.CenterEnd) {
                    T(Fm.t(z[i]), F.num(15, W500), maxLines = 1, translate = false)
                }
            }
        }
    }
}

// MARK: 러닝 페이스 (막대, 가장 빠른 것 노랑)

@Composable
private fun PaceCard(rec: Record) {
    val imp = Store.settings.imperial
    // 95번: 마지막 덜 뛴 조각은 막대에서 뺌
    val paces = rec.runs.filter { !rec.isPartialRun(it) }.map { Units.pace(rec.pace(it), imp) }
    val avg = rec.runPace?.let { Fm.t(Units.pace(it, imp)) } ?: "--:--"
    val mn = paces.minOrNull() ?: 0
    val mx = paces.maxOrNull() ?: 0
    Column(Modifier.fillMaxWidth().card8().testTag("detail.pace").padding(18.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Label8("RUN PACE", Modifier.weight(1f))
            T(if (imp) L10n.t("AVG %@ /MI", avg) else L10n.t("AVG %@ /KM", avg), F.num(15), maxLines = 1, translate = false)
        }
        Row(Modifier.padding(top = 16.dp).fillMaxWidth().height(110.dp), horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom) {
            paces.forEachIndexed { i, p ->
                // 높이 = 40% + (p − min + 6)/(max − min + 6) × 55% of 110, 위아래 글자 때문에 72에서 멈춤
                val pct = 0.40f + (p - mn + 6f) / (mx - mn + 6f) * 0.55f
                val barH = min(110f * pct, 72f).dp
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    T(Fm.t(p), F.num(11, W500, C.aeb), maxLines = 1, translate = false)
                    Box(Modifier.fillMaxWidth().height(barH).background(if (p == mn) C.accent else C.control))
                    T("R${i + 1}", F.t(11, W600, C.text3), maxLines = 1, translate = false)
                }
            }
        }
    }
}

// MARK: 구간 기록 (padding 11×18)

@Composable
private fun Splits(rec: Record) {
    val segs = rec.mainSegs.filter { !rec.isTinyRun(it) }
    // 빌드 27: 트레이닝은 저장된 목표(s.target) 대신 이 기록 전까지의 구간별 최고와 비교 (한 번만 계산)
    val prior = remember(rec, Store.book) { if (rec.mode == Mode.Training) Store.book.segBestsBefore(rec) else emptyMap() }
    Column(Modifier.fillMaxWidth().card8().testTag("detail.splits")) {
        segs.forEachIndexed { i, s -> SplitRow(rec, s, i == segs.size - 1, prior) }
    }
}

@Composable
private fun SplitRow(rec: Record, s: SegResult, last: Boolean, prior: Map<String, Int>) {
    // 트레이닝: 이 기록 전까지 같은 구간(SegKey)의 최고 기록과 비교 (빌드 27: 저장된 s.target 은 안 씀).
    //  이전 최고가 없으면 "–". Full Sim · Race · PFT 는 예전처럼 s.target 과 비교
    // 러닝 기록은 목표가 없어서 내 평균 페이스 대비 (빠르면 초록, 느리면 빨강)
    val runAvg = if (rec.mode == Mode.Training && rec.isRunKind && s.kind == SegKind.Run) rec.avgKmPace else null
    val priorBest = if (rec.mode == Mode.Training && s.kind != SegKind.Rox) prior[SegKey.of(s.icon, s.detail)] else null
    val partial = rec.isPartialRun(s)
    val showDelta = !partial && (runAvg != null || rec.mode != Mode.Training || priorBest != null)
    val imp = Store.settings.imperial
    // 러닝 평균 대비 차이도 보이는 페이스 단위(/KM · /MI)로
    val base = if (rec.mode == Mode.Training) (priorBest ?: s.time) else s.target
    val d = runAvg?.let { Units.pace(rec.pace(s), imp) - Units.pace(it, imp) } ?: (s.time - base)
    var first = if (s.kind == SegKind.Run) "${Fm.t(Units.pace(rec.pace(s), imp))} ${Units.paceUnit(imp)}" else Units.detail(s.detail, imp)
    // 93번: 스테이션 섞인 트레이닝의 러닝 구간 — 워치가 잰 거리가 계획(1 km 등)과 3% 넘게 다르면 실제 거리를 앞에 붙임
    val plan = runMeters(s.detail)
    val m = s.dist
    if (s.kind == SegKind.Run && !rec.isRunKind && m != null && plan > 0 && abs(m - plan) > plan * 0.03) {
        first = "${Units.dist(m, imp)} ${Units.distUnit(imp)} · " + first
    }
    val bpm = s.hr?.toString() ?: "--"
    // 스키 · 로잉 · 월볼: 워치가 팔 움직임으로 센 횟수 ("~" = 짐작값)
    val reps = s.reps?.let { n -> " · " + (if (s.icon == "wallBalls") L10n.t("~%lld reps", n) else L10n.t("~%lld strokes", n)) } ?: ""
    var runExtra = ""
    if (rec.mode == Mode.Training && rec.isRunKind && s.kind == SegKind.Run) {
        s.cad?.let { runExtra += " · $it SPM" }
        s.up?.let { if (it >= 1) runExtra += " · +${it.roundToInt()} m" }
    }
    // 93번: 무엇과 비교했는지 보이게 — 트레이닝은 이전 최고 시간을 같이 ("BEST 4:15")
    val bestNote = if (priorBest != null && runAvg == null && !partial) " · " + L10n.t("BEST %@", Fm.t(priorBest)) else ""
    val sub = "$first · $bpm BPM$reps$runExtra$bestNote"
    // 95번: 마지막 덜 뛴 구간은 "KM 7" 대신 실제 거리로 ("마지막 0.42 km")
    val title = if (partial) L10n.t("Last %@ %@", Units.dist(s.dist ?: 0.0, imp), Units.distUnit(imp).lowercase()) else s.name
    Row(
        Modifier.fillMaxWidth().rowLine(!last).padding(vertical = 11.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon8(s.icon, 24.dp, if (s.kind == SegKind.Run) Color.White else C.accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(title, F.t(15, W500), maxLines = 1, translate = !partial)
            T(sub, F.num(11, W500, C.text2, tracking = 0.22f), maxLines = 1, translate = false)
        }
        Column(horizontalAlignment = Alignment.End) {
            T(Fm.t(s.time), F.num(17, tracking = -0.17f), maxLines = 1, translate = false)
            T(if (showDelta) Fm.d(d) else "–", F.num(11, color = if (showDelta) deltaColor(d) else C.text3), maxLines = 1, translate = false)
        }
    }
}

// MARK: 같은 기록대 선수들과 비교 (Full Sim · Race, 16구간이 다 있을 때)

private val benchFr = listOf(1.25f, 1f, 1f, 1f)

@Composable
private fun BenchSection(rec: Record) {
    val me = rec.splits16 ?: return
    if (rec.mode != Mode.Sim && rec.mode != Mode.Race) return
    // 80번(빌드 28): 전 세계 출전자 중 대략 위치 (홈페이지 '내 기록 분석'과 같은 기준 · 같은 계산)
    HyroxRank.of(rec.division, rec.total)?.let { rk ->
        SectionLabel("WHERE YOU STAND", top = 20.dp)
        RankCard(rk)
    }
    SectionLabel("VS ATHLETES AT YOUR TIME", top = 20.dp)
    val (run, st) = HyroxBench.bench(rec.division, rec.total)
    Column(Modifier.fillMaxWidth().card8().testTag("detail.bench").padding(18.dp)) {
        Cols(benchFr, listOf(
            { m -> Spacer(m) },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { Label8("ME", spacing = 0.08f) } },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { Label8("MEDIAN", spacing = 0.08f) } },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { Label8("DIFF", spacing = 0.08f) } },
        ))
        Column(Modifier.padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            rec.runPace?.let { BenchRow("Run pace".l10n, it, run, pace = true) }
            for (i in 0 until 8) BenchRow(Station.all[i].name.l10n, me[i * 2 + 1], st[i])
        }
        T("Worldwide medians (2025/26 season) at this finish time — not an official ranking.",
            F.t(F.foot, color = C.text3), Modifier.padding(top = 14.dp))
    }
}

/** 80번: 상위 몇 % 카드 — 단계 이름 30 노랑 · "Open Men 완주자 중 상위 약 33%" · 눈금 막대 · 다음 단계까지 */
@Composable
private fun RankCard(rank: HyroxRank) {
    Column(Modifier.fillMaxWidth().card8().testTag("detail.rank").padding(18.dp)) {
        T(rank.level, F.t(30, W700, C.accent, tracking = -0.6f), maxLines = 1)
        rank.pct?.let { p ->
            T(L10n.t("Top ~%lld%% of %@ finishers", p, rank.group.l10n), F.t(16), Modifier.padding(top = 4.dp), translate = false)
            RankBar(p, Modifier.padding(top = 16.dp))
        }
        rank.next?.let { (name, time) ->
            val gap = rank.total - time + 1
            T(L10n.t("%@ to %@ (%@) — about %lld sec per split", Fm.t(gap), name.l10n, Fm.t(time), ceil(gap / 16.0).toInt()),
                F.t(14, color = C.text2), Modifier.padding(top = 14.dp), translate = false)
        }
        T("Rough position from published worldwide race results (2025/26) — not an official ranking.",
            F.t(F.foot, color = C.text3).copy(lineHeight = 17.sp), Modifier.padding(top = 14.dp))
    }
}

/** 상위 10 · 25 · 50 · 75% 눈금 + 내 위치 (흰 막대 5×18) */
@Composable
private fun RankBar(p: Int, modifier: Modifier = Modifier) {
    val tm = rememberTextMeasurer()
    val style = F.t(11, color = C.text3)
    val labels = listOf(10, 25, 50, 75).map { m -> m to (if (m == 10) L10n.t("Top %lld%%", m) else "$m%") }
    Canvas(modifier.fillMaxWidth().height(34.dp)) {
        val w = size.width
        val barH = 10.dp.toPx()
        val top = 4.dp.toPx()
        drawRoundRect(Brush.horizontalGradient(listOf(C.accent, Color(0xFF6E6A3A), Color(0xFF2A2924))), Offset(0f, top),
            androidx.compose.ui.geometry.Size(w, barH), androidx.compose.ui.geometry.CornerRadius(barH / 2))
        val x = w * p.coerceIn(0, 100) / 100f
        drawRoundRect(Color.White, Offset(x - 2.5.dp.toPx(), top + barH / 2 - 9.dp.toPx()), androidx.compose.ui.geometry.Size(5.dp.toPx(), 18.dp.toPx()),
            androidx.compose.ui.geometry.CornerRadius(3.dp.toPx()))
        for ((m, t) in labels) {
            val lay = tm.measure(t, style)
            val cx = w * m / 100f
            drawText(lay, topLeft = Offset((cx - lay.size.width / 2f).coerceIn(0f, w - lay.size.width), top + barH + 6.dp.toPx()))
        }
    }
}

/** 줄: 이름 · 내 시간 · 중간값 · 차이 + 차이 크기만큼 3dp 막대 (90초에 꽉 참) */
@Composable
private fun BenchRow(name: String, mine: Int, bench: Int, pace: Boolean = false) {
    val d = mine - bench
    val color = if (d <= 0) C.good else C.bad
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Cols(benchFr, listOf(
            { m -> T(name, F.t(15), m, maxLines = 1, translate = false) },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.t(mine) + if (pace) " /KM" else "", F.num(15), maxLines = 1, translate = false) } },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.t(bench), F.num(15, color = C.text2), maxLines = 1, translate = false) } },
            { m -> Box(m, contentAlignment = Alignment.CenterEnd) { T(Fm.d(d), F.num(15, color = color), maxLines = 1, translate = false) } },
        ))
        Canvas(Modifier.fillMaxWidth().height(3.dp)) {
            val r = androidx.compose.ui.geometry.CornerRadius(size.height / 2)
            drawRoundRect(Color.White.copy(alpha = 0.06f), cornerRadius = r)
            val f = min(1f, abs(d) / 90f)
            drawRoundRect(color, size = size.copy(width = max(2.dp.toPx(), size.width * f)), cornerRadius = r)
        }
    }
}

// MARK: 기록 지우기 (50 높이, radius 14 카드, 빨강 17/600)

@Composable
private fun DeleteCard(rec: Record, modifier: Modifier) {
    Box(
        modifier.fillMaxWidth().height(50.dp).card8(14.dp).press {
            Router.ask = Ask("Delete this record?", "This can't be undone.", ok = "Delete", destructive = true) {
                Router.go(Router.detailFrom)
                Store.delete(rec)
            }
        }.testTag("detail.delete"),
        contentAlignment = Alignment.Center,
    ) { T("Delete record", F.t(17, W600, C.bad), maxLines = 1) }
}

// MARK: 실외 러닝 경로 (지도 없이 경로만 — 구글 지도는 6단계)

/** 느릴 때 (어두운 노랑) → 빠를 때 (밝은 노랑) */
object RouteSpeed {
    fun color(f: Double): Color {
        val k = f.coerceIn(0.0, 1.0).toFloat()
        return Color(0.36f + (1f - 0.36f) * k, 0.32f + (0.902f - 0.32f) * k, 0f)
    }

    /** 경로를 최대 약 150 토막으로 나눠 토막마다 페이스로 색 (시작 점 번호, 끝 점 번호, 0~1). 시간 없는 점이 있으면 null */
    fun chunks(route: List<RoutePt>, maxChunks: Int = 150): List<Triple<Int, Int, Double>>? {
        if (route.size < 3 || route.any { it.t == null }) return null
        val n = max(2, route.size / maxChunks)
        val ranges = ArrayList<Triple<Int, Int, Double?>>()
        var i = 0
        while (i < route.size - 1) {
            val j = min(i + n, route.size - 1)
            var m = 0.0
            for (k in i until j) m += RunMetrics.meters(route[k], route[k + 1])
            val dt = ((route[j].t ?: 0) - (route[i].t ?: 0)).toDouble()
            ranges.add(Triple(i, j, if (m >= 5 && dt > 0) dt / m else null))
            i = j
        }
        val ps = ranges.mapNotNull { it.third }.sorted()
        if (ps.size < 2) return null
        // 튀는 값에 끌려가지 않게 10% · 90% 지점을 가장 빠름 · 가장 느림으로
        val fast = ps[ps.size / 10]
        val slow = ps[min(ps.size - 1, ps.size * 9 / 10)]
        val span = max(0.0001, slow - fast)
        var lastF = 0.5
        return ranges.map { (a, b, p) ->
            if (p != null) lastF = 1 - (p - fast) / span
            Triple(a, b, lastF)
        }
    }
}

@Composable
private fun RouteCard(route: List<RoutePt>) {
    val chunks = remember(route) { RouteSpeed.chunks(route) }
    Box(Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(20.dp)).background(Color(0xFF1B1C1E)).testTag("detail.route")) {
        // 구글 지도 (키가 있을 때). 지도가 뜨기 전 · 키가 없을 때는 지도 없이 그린 경로
        if (Config.hasMaps) GoogleRouteMap(route, chunks, Modifier.matchParentSize()) { RouteDrawing(route, chunks) }
        else RouteDrawing(route, chunks)
        if (chunks != null) RouteSpeedLegend(Modifier.align(Alignment.BottomStart))
    }
}

/** 지도 없이 그린 경로 (옅은 격자 + 속도별 노란 선) */
@Composable
private fun BoxScope.RouteDrawing(route: List<RoutePt>, chunks: List<Triple<Int, Int, Double>>?) {
        Canvas(Modifier.matchParentSize()) {
            // 옅은 격자 (지도 느낌)
            val g = 28.dp.toPx()
            var x = 0f
            while (x < size.width) { drawLine(Color.White.copy(alpha = 0.035f), Offset(x, 0f), Offset(x, size.height), 1f); x += g }
            var y = 0f
            while (y < size.height) { drawLine(Color.White.copy(alpha = 0.035f), Offset(0f, y), Offset(size.width, y), 1f); y += g }
            // 경로가 다 보이게 (가장자리 여유 20%, 가로세로 비율 유지)
            val lat0 = route.first().a
            val kx = cos(Math.toRadians(lat0))
            val xs = route.map { it.o * kx }
            val ys = route.map { it.a }
            val minX = xs.min(); val maxX = xs.max(); val minY = ys.min(); val maxY = ys.max()
            val spanX = max(1e-6, maxX - minX)
            val spanY = max(1e-6, maxY - minY)
            val pad = 0.2f
            val scale = min(size.width * (1 - 2 * pad) / spanX, size.height * (1 - 2 * pad) / spanY)
            val cx = (minX + maxX) / 2
            val cy = (minY + maxY) / 2
            fun pt(i: Int) = Offset((size.width / 2 + (xs[i] - cx) * scale).toFloat(), (size.height / 2 - (ys[i] - cy) * scale).toFloat())
            val w = 4.dp.toPx()
            if (chunks != null) {
                for ((a, b, f) in chunks) {
                    val p = Path()
                    p.moveTo(pt(a).x, pt(a).y)
                    for (k in a + 1..b) p.lineTo(pt(k).x, pt(k).y)
                    drawPath(p, RouteSpeed.color(f), style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
                }
            } else {
                val p = Path()
                route.indices.forEach { if (it == 0) p.moveTo(pt(it).x, pt(it).y) else p.lineTo(pt(it).x, pt(it).y) }
                drawPath(p, C.accent, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
            drawCircle(Color.White, 5.dp.toPx(), pt(0))
            drawCircle(C.accent, 6.dp.toPx(), pt(route.size - 1))
        }
}

/** 왼쪽 아래 작은 안내: SLOW ▬▬ FAST */
@Composable
private fun RouteSpeedLegend(modifier: Modifier) {
            Row(
                modifier.padding(10.dp).clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.55f))
                    .padding(vertical = 5.dp, horizontal = 9.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                T("SLOW", F.t(10, W600, C.text2), maxLines = 1)
                Box(Modifier.width(44.dp).height(5.dp).clip(RoundedCornerShape(50))
                    .background(Brush.horizontalGradient(listOf(RouteSpeed.color(0.0), RouteSpeed.color(1.0)))))
                T("FAST", F.t(10, W600, C.accent), maxLines = 1)
            }
}

// MARK: 높이 그래프 (경로 아래, 가로 = km)

@Composable
private fun ElevationCard(route: List<RoutePt>, ascent: Double?) {
    val pts = remember(route) { RunMetrics.profile(route) }
    if (pts.size < 2) return
    val lo = pts.minOf { it.second }
    val hi = pts.maxOf { it.second }
    // 평지에서도 선이 바닥에 붙지 않게 높이 범위를 최소 20 m 로
    val pad = max(4.0, (20 - (hi - lo)) / 2)
    val y0 = floor(lo - pad)
    val y1 = ceil(hi + pad)
    val kmMax = max(0.1, pts.last().first)
    val measurer = rememberTextMeasurer()
    val labelStyle = F.num(10, androidx.compose.ui.text.font.FontWeight.Normal, C.text3)
    Column(Modifier.fillMaxWidth().card8().testTag("detail.elevation").padding(18.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Label8("ELEVATION", Modifier.weight(1f))
            ascent?.let { T("+${it.roundToInt()} m", F.num(15), maxLines = 1, translate = false) }
        }
        Canvas(Modifier.padding(top = 14.dp).fillMaxWidth().height(110.dp)) {
            val left = 34.dp.toPx()
            val bottom = 16.dp.toPx()
            val w = size.width - left
            val h = size.height - bottom
            fun px(km: Double) = (left + km / kmMax * w).toFloat()
            fun py(m: Double) = ((1 - (m - y0) / (y1 - y0)) * h).toFloat()
            // 가로 칸 (높이 3줄)
            for (k in 0..2) {
                val v = y0 + (y1 - y0) * k / 2
                val yy = py(v)
                drawLine(C.line, Offset(left, yy), Offset(size.width, yy), 1f)
                val tl = measurer.measure("${v.roundToInt()} m", labelStyle)
                drawText(tl, topLeft = Offset(0f, (yy - tl.size.height / 2f).coerceIn(0f, h - tl.size.height)))
            }
            // 세로 칸 (km, 4~5개)
            val step = listOf(0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0).firstOrNull { kmMax / it <= 5 } ?: 10.0
            var km = 0.0
            while (km <= kmMax + 1e-6) {
                val xx = px(km)
                drawLine(C.line, Offset(xx, 0f), Offset(xx, h), 1f)
                val s = (if (km == floor(km)) km.toInt().toString() else String.format(Locale.US, "%.1f", km)) + " km"
                val tl = measurer.measure(s, labelStyle)
                drawText(tl, topLeft = Offset(min(xx, size.width - tl.size.width), h + 3.dp.toPx()))
                km += step
            }
            val line = Path()
            val area = Path()
            pts.forEachIndexed { i, (k, m) ->
                val p = Offset(px(k), py(m))
                if (i == 0) { line.moveTo(p.x, p.y); area.moveTo(p.x, h); area.lineTo(p.x, p.y) } else { line.lineTo(p.x, p.y); area.lineTo(p.x, p.y) }
            }
            area.lineTo(px(pts.last().first), h)
            area.close()
            drawPath(area, Brush.verticalGradient(listOf(C.accent.copy(alpha = 0.32f), C.accent.copy(alpha = 0.02f)), 0f, h))
            drawPath(line, C.accent, style = Stroke(1.6.dp.toPx(), join = StrokeJoin.Round))
        }
    }
}

// MARK: 같은 코스 바퀴 (12 laps · avg 1:52 · fastest #7 1:46)

@Composable
private fun LapsCard(laps: List<Int>) {
    val avg = laps.sum() / max(1, laps.size)
    val fi = laps.indices.minByOrNull { laps[it] } ?: 0
    val mn = laps.minOrNull() ?: 0
    val mx = laps.maxOrNull() ?: 0
    Column(Modifier.fillMaxWidth().card8().testTag("detail.laps").padding(18.dp)) {
        Label8("LAPS")
        T(L10n.t("%lld laps · avg %@ · fastest #%lld %@", laps.size, Fm.t(avg), fi + 1, Fm.t(laps[fi])), F.num(15),
            Modifier.padding(top = 10.dp), maxLines = 1, translate = false)
        // 바퀴마다 막대 (빠를수록 높게, 가장 빠른 바퀴 노랑) — 너무 많으면 막대는 뺌
        if (laps.size <= 40) {
            Row(Modifier.padding(top = 14.dp).fillMaxWidth().height(42.dp), verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(if (laps.size > 20) 2.dp else 4.dp)) {
                laps.forEachIndexed { i, t ->
                    val f = if (mx > mn) (mx - t).toFloat() / (mx - mn) else 1f
                    Box(Modifier.weight(1f).height((12 + 30 * f).dp).background(if (i == fi) C.accent else C.control))
                }
            }
        }
    }
}
