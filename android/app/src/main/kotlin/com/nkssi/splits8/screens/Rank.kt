package com.nkssi.splits8.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.OfficialParse
import com.nkssi.splits8.shared.OfficialResult
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlin.math.abs

// 1.2.4 · 공식 기록 카드 · 공식 결과 넣기 (아이폰 RankViews.swift 와 같은 화면). 대략 상위 % 는 Detail.kt RankCard (80번) 그대로

/** 공식 기록: OFFICIAL · 대회 · 디비전 · Rank (M/W) · Rank (AG) · 참가 인원 넣으면 상위 % */
@Composable
fun OfficialCard(o: OfficialResult) {
    Column(Modifier.fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp).testTag("detail.official"),
        verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            T("OFFICIAL", F.t(10, W700, Color.Black), Modifier.clip(RoundedCornerShape(6.dp)).background(C.accent).padding(vertical = 2.dp, horizontal = 7.dp), translate = false)
            T("${o.event} · ${o.division.l10n}", F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            o.rank?.let { Stat("#$it", "Rank (M/W)") }
            o.ageRank?.let { Stat("#$it", "Rank (AG)") }
            o.topPct?.let { Stat(String.format(java.util.Locale.US, "%.1f%%", it), "Top") }
        }
        T("Official ranks are from the race results: Rank (M/W) is within your division and gender, Rank (AG) within your age group.",
            F.t(11, color = C.text3), Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun Stat(v: String, label: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        T(v, F.num(24, color = C.accent), translate = false)
        T(label, F.t(11, W600, C.text3))
    }
}

// MARK: 대회 화면 맨 아래: 공식 결과 넣기

const val RESULTS_URL = "https://results.hyrox.com"

/** 대회 화면(SetEventView) 맨 아래: 설명 + Add official result + Official results ↗ */
@Composable
fun OfficialEntrySection(ev: RaceEvent) {
    val ctx = LocalContext.current
    SectionLabel("OFFICIAL RESULT", top = 14.dp)
    T("After the race, take a screenshot of your result on the official results page and add it here. The photo is read only on this device. Your recorded workout stays as it is, and the official result is saved as one more record.",
        F.t(13, color = C.text2), Modifier.padding(horizontal = 4.dp))
    Box(Modifier.fillMaxWidth().height(48.dp).yellowFill(RoundedCornerShape(50), on = ev.isSet)
        .press(enabled = ev.isSet, tag = "ev.addOfficial") { Router.officialFor = ev }, contentAlignment = Alignment.Center) {
        T("Add official result", F.t(16, W600, if (ev.isSet) Color.Black else C.text3), maxLines = 1)
    }
    T("Official results ↗", F.t(14, W600, C.accent), Modifier.fillMaxWidth().padding(vertical = 6.dp)
        .tap { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(RESULTS_URL))) } }.testTag("ev.officialResults"),
        align = TextAlign.Center)
}

/** 공식 결과 넣기 시트: 캡처 고르기 → 이 기기 안에서 글자 읽기 → 표에서 확인 · 고치기 → Save → 공식 기록 하나 더 */
@Composable
fun OfficialImportSheet(ev: RaceEvent) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var reading by remember { mutableStateOf(false) }
    var readOnce by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf("") }
    var event by remember { mutableStateOf(ev.name) }
    var division by remember { mutableStateOf(Store.settings.div.name) }
    var total by remember { mutableStateOf("") }
    var rank by remember { mutableStateOf("") }
    var ageRank by remember { mutableStateOf("") }
    var field by remember { mutableStateOf("") }
    val runs = remember { mutableStateListOf(*Array(8) { "" }) }
    val st = remember { mutableStateListOf(*Array(8) { "" }) }
    var rox by remember { mutableStateOf("") }
    var divOpen by remember { mutableStateOf(false) }

    fun secs(s: String): Int? {
        val t = s.trim()
        if (t.isEmpty()) return null
        val parts = t.split(":")
        val p = parts.mapNotNull { it.toIntOrNull() }
        if (p.size != parts.size) return null
        return when (p.size) { 3 -> p[0] * 3600 + p[1] * 60 + p[2]; 2 -> p[0] * 60 + p[1]; else -> null }
    }
    val runSecs = runs.map { secs(it) }
    val stSecs = st.map { secs(it) }
    val canSave = (secs(total) ?: 0) > 0 && event.isNotBlank() && runSecs.all { it != null } && stSecs.all { it != null }
    val sumWarn: String? = run {
        val t = secs(total) ?: return@run null
        if (!runSecs.all { it != null } || !stSecs.all { it != null }) return@run null
        val sum = runSecs.sumOf { it!! } + stSecs.sumOf { it!! } + (secs(rox) ?: 0)
        if (abs(sum - t) <= 3) null else L10n.t("⚠ The splits add up to %@, %@ off the overall time. Please check the boxes.", Fm.t(sum), Fm.t(abs(sum - t)))
    }

    fun save() {
        val t = secs(total) ?: return
        if (!canSave) return
        val o = OfficialResult(rank = rank.trim().toIntOrNull(), ageRank = ageRank.trim().toIntOrNull(), field = field.trim().toIntOrNull(),
            time = t, event = event.trim(), division = division)
        val rec = OfficialParse.record(runSecs.map { it!! }, stSecs.map { it!! }, secs(rox) ?: 0, o, ev.date)
        Store.add(rec)
        Router.officialFor = null
        Router.open(rec, Scr.Race)
    }

    // 사진 고르기 (권한 필요 없는 사진 선택기) → ML Kit 기기 안 글자 읽기. 사진은 저장 · 전송 안 함
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        reading = true
        scope.launch {
            val text = runCatching {
                val img = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { InputImage.fromFilePath(ctx, uri) }
                val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(img).await()
                joinLines(r.textBlocks.flatMap { b -> b.lines.map { (it.boundingBox ?: android.graphics.Rect()) to it.text } })
            }.getOrDefault("")
            val d = OfficialParse.parse(text)
            d.total?.let { total = Fm.t(it) }
            d.rank?.let { rank = "$it" }
            d.ageRank?.let { ageRank = "$it" }
            for (i in 0 until 8) {
                d.runs[i]?.let { runs[i] = Fm.t(it) }
                d.st[i]?.let { st[i] = Fm.t(it) }
            }
            d.rox?.let { rox = Fm.t(it) }
            note = if (d.found == 0) "Could not find a result in this image. Try a sharper screenshot, or type the times in.".l10n
                   else L10n.t("Filled %d boxes from the screenshot. Please check them.", d.found)
            reading = false
            readOnce = true
        }
    }

    @Composable
    fun Row8(label: String, value: String, placeholder: String = "", numeric: Boolean = true, digits: Boolean = false,
             optional: Boolean = false, tag: String = "", onChange: (String) -> Unit) {
        val missing = readOnce && !optional && value.isBlank()
        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp, horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            T(label, F.t(15), Modifier.weight(1f), maxLines = 1)
            Box(Modifier.width(if (numeric) 96.dp else 180.dp).clip(RoundedCornerShape(8.dp)).background(C.control)
                .border(2.dp, if (missing) C.accent else Color.Transparent, RoundedCornerShape(8.dp))
                .padding(vertical = 5.dp, horizontal = 8.dp)) {
                if (value.isEmpty()) T(placeholder, F.t(15, color = C.text3), Modifier.fillMaxWidth(), align = TextAlign.End, translate = false)
                BasicTextField(value, onChange, Modifier.fillMaxWidth().testTag(tag), singleLine = true,
                    textStyle = (if (numeric) F.num(15) else F.t(15)).copy(textAlign = TextAlign.End),
                    keyboardOptions = KeyboardOptions(keyboardType = if (digits) KeyboardType.Number else if (numeric) KeyboardType.Text else KeyboardType.Text),
                    cursorBrush = SolidColor(C.accent))
            }
        }
    }

    NavBar3("Cancel", "Official result", right = "Save", rightColor = if (canSave) C.accent else C.g3A, edgeBack = false,
        onLeft = { Router.officialFor = null }, onRight = { save() })
    Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 10.dp, bottom = 30.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.fillMaxWidth().height(48.dp).yellowFill(RoundedCornerShape(50))
            .press(tag = "official.pick") { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
            contentAlignment = Alignment.Center) {
            T(if (readOnce) "Choose another screenshot" else "Choose screenshot", F.t(16, W600, Color.Black), maxLines = 1)
        }
        T(if (reading) "Reading the screenshot…".l10n else "🔒 " + "The photo is read only on this device.".l10n,
            F.t(12, color = C.text2), Modifier.fillMaxWidth(), align = TextAlign.Center, translate = false)
        if (note.isNotEmpty()) T(note, F.t(12, color = Color(0xFFFF9F0A)), translate = false)

        SectionLabel("RESULT", top = 6.dp)
        Column(Modifier.fillMaxWidth().card8()) {
            Row8("Event", event, numeric = false, tag = "official.event") { event = it }
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                T("Division", F.t(15), Modifier.weight(1f))
                T(division, F.t(15, color = C.accent), Modifier.tap { divOpen = !divOpen }, translate = false)
            }
            if (divOpen) Division.all.forEach { d ->
                T(d.name, F.t(15, color = if (d.name == division) C.accent else Color.White),
                    Modifier.fillMaxWidth().tap { division = d.name; divOpen = false }.padding(vertical = 8.dp, horizontal = 28.dp), translate = false)
            }
            Row8("Overall time", total, "1:21:30", tag = "official.total") { total = it }
            Row8("Rank (M/W)", rank, "123", digits = true) { rank = it.filter { c -> c.isDigit() } }
            Row8("Rank (AG)", ageRank, "15", digits = true) { ageRank = it.filter { c -> c.isDigit() } }
            Row8("Finishers (optional)", field, "—", digits = true, optional = true) { field = it.filter { c -> c.isDigit() } }
        }
        SectionLabel("SPLITS", top = 6.dp)
        Column(Modifier.fillMaxWidth().card8()) {
            for (i in 0 until 8) {
                Row8(L10n.t("Running %d", i + 1), runs[i], "4:30") { runs[i] = it }
                Row8(Station.all[i].name, st[i], "4:00") { st[i] = it }
            }
            Row8("Roxzone", rox, "7:00", optional = true) { rox = it }
        }
        sumWarn?.let { T(it, F.t(12, color = Color(0xFFFF9F0A)), Modifier.padding(horizontal = 4.dp), translate = false) }
        T("Only your own result is kept. Names in the screenshot are not saved.", F.t(11, color = C.text3), Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(20.dp))
    }
}

/** 글자 조각을 줄로 (같은 높이를 왼쪽부터) — 결과 표는 이름 · 시간 · 순위가 따로 읽힘 */
internal fun joinLines(items: List<Pair<android.graphics.Rect, String>>): String {
    val sorted = items.sortedBy { it.first.centerY() }
    val lines = ArrayList<ArrayList<Pair<android.graphics.Rect, String>>>()
    for (it in sorted) {
        val last = lines.lastOrNull()
        val ref = last?.firstOrNull()
        if (ref != null && abs(ref.first.centerY() - it.first.centerY()) < maxOf(ref.first.height(), it.first.height()) * 0.6) last.add(it)
        else lines.add(arrayListOf(it))
    }
    return lines.joinToString("\n") { l -> l.sortedBy { it.first.left }.joinToString("  ") { it.second } }
}
