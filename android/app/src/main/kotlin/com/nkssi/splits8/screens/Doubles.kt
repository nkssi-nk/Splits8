package com.nkssi.splits8.screens

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Router
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.DoublesLink
import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.Wordmark
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import kotlinx.coroutines.launch

// 아이폰 DoublesPlanViews.swift (빌드 27) — 더블 계획 시트.
// 스테이션마다 "몇 m(개)씩 번갈아 · 누가 먼저"를 정함. 저장하면 워치로도 감 (WatchContext.doublesPlan).
// 공유: 계획 그림 + 링크 (받은 사람은 먼저 하는 사람이 바뀐 채로 저장됨 — Router.acceptIncomingDoubles)
// 아이폰은 스테이션을 누르면 시트 위에 시트를 하나 더 띄우지만, 안드로이드는 같은 시트 안에서 화면을 바꿈

/** 막대 색: 나 = 노랑, 파트너 = 회색 */
object DblColor {
    val me = C.accent
    val partner = hex(0x48484A)
}

/** 글자 모음 (아이폰 DblText) */
object DblText {
    /** "150 m씩 · 나 먼저" / "한 바퀴(12.5 m)씩 · 가테부 먼저" */
    fun summary(p: DoublesPlan, i: Int): String = chunkLabel(p.chunk(i), i) + " · " + firstLabel(p, p.meFirst(i))

    /** "150 m씩" / "1 length (12.5 m)" */
    fun chunkLabel(v: Double, i: Int): String =
        if (DoublesPlan.isFixed(i)) "1 length (12.5 m)".l10n else L10n.t("%@ each", DoublesPlan.amountText(i, v))

    /** "나 먼저" / "가테부 먼저" */
    fun firstLabel(p: DoublesPlan, me: Boolean): String = if (me) "Me first".l10n else L10n.t("%@ first", p.partnerShown)

    /** "나 550 m · 파트너 450 m" */
    fun totals(p: DoublesPlan, i: Int): String =
        "Me".l10n + " " + DoublesPlan.amountText(i, p.mine(i)) + " · " + p.partnerShown + " " + DoublesPlan.amountText(i, p.partners(i))

    /** 공유 그림 한 줄: "나 150 → 파 150 → 나 150 → …" */
    fun flow(p: DoublesPlan, i: Int, max: Int = 4): String {
        val me = "Me".l10n
        val yu = p.partnerShown.take(1)
        val seq = p.sequence(i)
        var s = seq.take(max).joinToString(" → ") { (if (it.me) me else yu) + " " + DoublesPlan.num(it.amount) }
        if (seq.size > max) s += " → …"
        return s
    }

    fun turns(n: Int): String = L10n.t("%lld turns", n)
}

/** 막대 (나 노랑 · 파트너 회색, 차례마다 한 칸, 사이 2) */
@Composable
fun DoublesBar(plan: DoublesPlan, index: Int, height: Dp = 8.dp, modifier: Modifier = Modifier) {
    val seq = plan.sequence(index)
    val total = maxOf(1.0, DoublesPlan.total(index))
    Box(modifier.fillMaxWidth().height(height).drawBehind {
        val gap = 2.dp.toPx()
        val free = maxOf(0f, size.width - gap * maxOf(0, seq.size - 1))
        var x = 0f
        val r = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx())
        for (t in seq) {
            val w = maxOf(1f, free * (t.amount / total).toFloat())
            drawRoundRect(if (t.me) DblColor.me else DblColor.partner, Offset(x, 0f), androidx.compose.ui.geometry.Size(w, size.height), r)
            x += w + gap
        }
    })
}

/** 더블 계획 시트 (Race · Full Sim 의 "Doubles plan" 줄) */
@Composable
fun DoublesPlanSheet() {
    var plan by remember { mutableStateOf(Store.settings.doublesPlan ?: DoublesPlan()) }
    var editing by remember { mutableStateOf<Int?>(null) }
    val e = editing
    if (e != null) {
        DoublesStationPage(plan, e, onCancel = { editing = null }) { plan = it; editing = null }
        return
    }
    val ctx = LocalContext.current
    val layer = rememberGraphicsLayer()
    val scope = rememberCoroutineScope()
    // 공유 그림 (화면에 안 보이게 3배로 그려 둠)
    CaptureCard(layer) { DoublesShareCard(plan, Store.settings.div.name) }

    fun save() {
        val n = DoublesPlan.cleanName(plan.partnerName)
        val p = plan.copy(partnerName = n, partnerId = if (n == null) null else plan.partnerId)
        Store.update { it.copy(doublesPlan = p) }
        Router.raceSheet = null
    }

    fun share() {
        scope.launch {
            val bmp = runCatching { layer.toImageBitmap().asAndroidBitmap() }.getOrNull()
            var text = "SPLITS8 Doubles plan".l10n
            text += "\n" + DoublesLink.webUrl(plan, Store.settings.nickname)
            if (bmp != null) shareImage(ctx, bmp, text)
            else runCatching { ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), null)) }
        }
    }

    Column(Modifier.padding(horizontal = 16.dp)) {
        NavBar3("Cancel", "Doubles plan", right = "Save", edgeBack = false, onLeft = { Router.raceSheet = null }, onRight = { save() })
        Column(Modifier.verticalScroll(rememberScrollState()).padding(top = 4.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PartnerCard(plan) { plan = it }
            Note8("Choose how much each of you does per turn and who goes first. Tap a station to change it.")
            Column(Modifier.fillMaxWidth().card8()) {
                for (i in 0 until 8) {
                    val st = Station.all[i]
                    Column(Modifier.fillMaxWidth().rowLine(i < 7).tap { editing = i }.testTag("dbl." + st.key).padding(vertical = 12.dp, horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Icon8(st.key, 20.dp, C.accent)
                            T(st.name, F.t(15, W600), Modifier.weight(1f), maxLines = 1)
                            T(DblText.summary(plan, i), F.t(13, color = C.text2), maxLines = 1, translate = false)
                            Chevron8()
                        }
                        DoublesBar(plan, i, 8.dp)
                        T(DblText.totals(plan, i), F.t(13, color = C.text2), maxLines = 1, translate = false)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.08f))
                    .press(tag = "dbl.reset") { plan = DoublesPlan().copy(partnerName = plan.partnerName, partnerId = plan.partnerId) },
                    contentAlignment = Alignment.Center) {
                    T("Reset", F.t(15, W600), maxLines = 1)
                }
                Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(14.dp)).background(C.accent)
                    .press(tag = "dbl.share") { share() }, contentAlignment = Alignment.Center) {
                    T("Share", F.t(15, W600, Color.Black), maxLines = 1)
                }
            }
            Note8("In Doubles, you run all 8 runs together. Only stations are split.")
        }
    }
}

/** 파트너 이름 칸 + 친구 고르기 칩 */
@Composable
private fun PartnerCard(plan: DoublesPlan, onChange: (DoublesPlan) -> Unit) {
    val friends = Store.friends
    Column(Modifier.fillMaxWidth().card8().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Label8("PARTNER")
        val name = plan.partnerName ?: ""
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.06f))
            .padding(vertical = 12.dp, horizontal = 14.dp)) {
            if (name.isEmpty()) T("Partner", F.t(17, color = C.text3), maxLines = 1)
            BasicTextField(name, { v ->
                val t = v.take(20)
                var p = plan.copy(partnerName = t.ifEmpty { null })
                // 친구를 고른 뒤 이름을 고치면 친구 연결을 끊음
                val id = plan.partnerId
                if (id != null && friends.firstOrNull { it.id == id }?.name != t) p = p.copy(partnerId = null)
                onChange(p)
            }, Modifier.fillMaxWidth().testTag("dbl.partner"), textStyle = F.t(17), singleLine = true, cursorBrush = SolidColor(C.accent))
        }
        if (friends.isNotEmpty()) {
            T("Or pick a friend", F.t(13, color = C.text2), maxLines = 1)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (f in friends) {
                    val on = plan.partnerId == f.id
                    Box(Modifier.height(34.dp).clip(CircleShape).background(if (on) C.accent else Color.White.copy(alpha = 0.10f))
                        .press(0.96f, tag = "dbl.friend." + f.id) {
                            onChange(if (on) plan.copy(partnerId = null, partnerName = null)
                            else plan.copy(partnerId = f.id, partnerName = DoublesPlan.cleanName(f.name)))
                        }.padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
                        T(f.name, F.t(13, W600, if (on) Color.Black else Color.White), maxLines = 1, translate = false)
                    }
                }
            }
        }
    }
}

/** 스테이션 하나 고치기 (Cancel · 이름 · Done): 한 번 양 · 누가 먼저 · 막대 · 차례 목록 */
@Composable
private fun DoublesStationPage(plan: DoublesPlan, index: Int, onCancel: () -> Unit, onDone: (DoublesPlan) -> Unit) {
    var draft by remember(index) { mutableStateOf(plan) }
    val st = Station.all[index]
    val i = index
    Column(Modifier.padding(horizontal = 16.dp)) {
        NavBar3("Cancel", st.name, right = "Done", edgeBack = false, onLeft = onCancel, onRight = { onDone(draft) })
        Column(Modifier.verticalScroll(rememberScrollState()).padding(top = 4.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.fillMaxWidth().card8().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Label8("EACH TURN")
                if (DoublesPlan.isFixed(i)) {
                    T("1 length (12.5 m)", F.t(15, W600), maxLines = 1)
                } else {
                    val opts = DoublesPlan.options[i]
                    Seg8(opts.map { DoublesPlan.num(it) to DoublesPlan.amountText(i, it) }, DoublesPlan.num(draft.chunk(i)),
                        Modifier.fillMaxWidth().testTag("dbl.chunk")) { k ->
                        opts.firstOrNull { DoublesPlan.num(it) == k }?.let { draft = draft.setChunk(i, it) }
                    }
                }
                Label8("WHO GOES FIRST", Modifier.padding(top = 4.dp))
                Seg8(listOf("me" to "Me", "partner" to draft.partnerShown), if (draft.meFirst(i)) "me" else "partner",
                    Modifier.fillMaxWidth().testTag("dbl.first")) { k -> draft = draft.setMeFirst(i, k == "me") }
                DoublesBar(draft, i, 10.dp, Modifier.padding(top = 4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(DblText.totals(draft, i), F.t(13, color = C.text2), Modifier.weight(1f), maxLines = 1, translate = false)
                    T(DblText.turns(draft.turns(i)), F.t(13, color = C.text3), maxLines = 1, translate = false)
                }
            }
            // "1  나  150 m   0 → 150 m"
            val seq = draft.sequence(i)
            val unit = if (DoublesPlan.isReps(i)) "" else " m"
            Column(Modifier.fillMaxWidth().card8()) {
                var acc = 0.0
                seq.forEachIndexed { n, t ->
                    val start = acc
                    acc += t.amount
                    Row(Modifier.fillMaxWidth().rowLine(n < seq.size - 1).padding(vertical = 11.dp, horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        T("${n + 1}", F.num(13, color = C.text3), Modifier.width(22.dp), maxLines = 1, translate = false)
                        Box(Modifier.size(8.dp).clip(CircleShape).background(if (t.me) DblColor.me else DblColor.partner))
                        T(if (t.me) "Me".l10n else draft.partnerShown, F.t(15, W600), Modifier.weight(1f), maxLines = 1, translate = false)
                        T(DoublesPlan.amountText(i, t.amount), F.num(15), maxLines = 1, translate = false)
                        T(DoublesPlan.num(start) + " → " + DoublesPlan.num(start + t.amount) + unit, F.num(13, androidx.compose.ui.text.font.FontWeight.Normal, C.text2),
                            Modifier.widthIn(min = 96.dp), maxLines = 1, align = TextAlign.End, translate = false)
                    }
                }
            }
        }
    }
}

/** 공유용 카드 (360 너비 → 3배로 그림) */
@Composable
fun DoublesShareCard(plan: DoublesPlan, division: String) {
    Column(Modifier.width(360.dp).background(Color.Black).padding(22.dp)) {
        Wordmark(22f)
        T("Our doubles plan", F.t(28, W600), Modifier.padding(top = 18.dp), maxLines = 1)
        T(division.l10n + " · " + "Me".l10n + " & " + plan.partnerShown, F.t(13, color = C.text2), Modifier.padding(top = 4.dp),
            maxLines = 1, translate = false)
        Column(Modifier.padding(top = 16.dp)) {
            for (i in 0 until 8) {
                val st = Station.all[i]
                Column(Modifier.fillMaxWidth().drawBehind {
                    if (i < 7) drawLine(C.line, Offset(0f, size.height), Offset(size.width, size.height), 1.dp.toPx())
                }.padding(vertical = 9.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon8(st.key, 16.dp, C.accent)
                        T(st.name, F.t(13, W600), Modifier.weight(1f), maxLines = 1)
                        T(DblText.chunkLabel(plan.chunk(i), i), F.t(11, color = C.text2), maxLines = 1, translate = false)
                    }
                    T(DblText.flow(plan, i), F.num(13, androidx.compose.ui.text.font.FontWeight.Normal, C.d1), maxLines = 1, translate = false)
                    DoublesBar(plan, i, 5.dp)
                }
            }
        }
        Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            for ((c, t) in listOf(DblColor.me to "Me".l10n, DblColor.partner to plan.partnerShown)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(12.dp, 6.dp).clip(RoundedCornerShape(2.dp)).background(c))
                    T(t, F.t(11, color = C.text2), maxLines = 1, translate = false)
                }
            }
        }
    }
}

/** 더블 계획 줄의 값: 안 정했으면 Not set, 파트너가 있으면 그 이름, 아니면 Custom */
fun doublesValue(): String {
    val p = Store.settings.doublesPlan ?: return "Not set".l10n + " ›"
    val n = p.partnerName
    if (!n.isNullOrEmpty()) return "$n ›"
    return "Custom".l10n + " ›"
}
