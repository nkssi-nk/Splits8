package com.nkssi.splits8.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Accounts
import com.nkssi.splits8.Ask
import com.nkssi.splits8.RemoteProfile
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.BlockedUser
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.Avatar8
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.CountBadge
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SearchField8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.SectionText
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowPill
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap
import kotlinx.coroutines.delay

// 아이폰 FriendsViews.swift (빌드 22 친구 요청 · 빌드 23) + 빌드 24 친구 최대 10명

private const val SUPPORT_EMAIL = "nkssi1981@gmail.com"

/** 찾을 글자: 앞뒤 빈칸을 빼고 소문자로. 닉네임 앞의 @ 는 뺌 (이메일 안의 @ 는 그대로) */
fun friendQuery(v: String): String {
    val t = v.trim().lowercase()
    return if (t.startsWith("@")) t.drop(1) else t
}

/** 이메일 모양이거나 닉네임 모양(3–16자)일 때만 서버에 물어봄 (앞 글자만으로는 모르는 사람을 훑어볼 수 없게) */
fun friendSearchable(q: String): Boolean =
    Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").matches(q) || Regex("^[a-z0-9_]{3,16}$").matches(q)

/** "최대 10명까지 추가할 수 있어요" (유료 · Pro 말은 안 씀) */
private fun limitAsk() {
    Router.ask = Ask(L10n.t("You can add up to %lld friends.", Store.FRIEND_LIMIT), null, cancel = null)
}

@Composable
fun FriendsView() {
    var query by remember { mutableStateOf("") }
    var hit by remember { mutableStateOf<RemoteProfile?>(null) }
    /** "" 없음 / searching / none / error */
    var searchState by remember { mutableStateOf("") }

    // 입력이 멈추고 0.5초 뒤 서버에 물어봄
    LaunchedEffect(query) {
        val q = friendQuery(query)
        hit = null
        if (!friendSearchable(q)) { searchState = ""; return@LaunchedEffect }
        searchState = "searching"
        delay(500)
        val found = try { Accounts.api.findUser(q) } catch (e: Exception) { searchState = "error"; return@LaunchedEffect }
        if (found != null && found.id != Accounts.api.userId && !Store.isBlocked(found.id)) { hit = found; searchState = "" }
        else searchState = "none"
    }

    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (Store.signedIn) {
                SearchField8("Email or nickname", query, Modifier.padding(top = 4.dp).testTag("friends.search")) { query = it }
                val h = hit
                if (h?.nickname != null) HitCard(h, h.nickname)
                else if (searchState == "none") Note8("No one found. Enter the full email or the full nickname.", Modifier.testTag("friends.none"), C.text2)
                else if (searchState == "error") Note8("Couldn't search right now. Check your connection and try again.", Modifier.testTag("friends.error"), C.text2)
                Note8("Friends who signed up with Apple and hid their email can only be found by nickname.")
            } else {
                Row(Modifier.padding(top = 4.dp).fillMaxWidth().card8().padding(vertical = 14.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    T("Sign up to find friends by email or nickname and compare records.", F.t(13, color = C.text2), Modifier.weight(1f))
                    YellowPill("Sign up", Modifier.testTag("friends.signup")) { Router.toAuth(Scr.Friends) }
                }
            }

            Requests()

            Note8("The selected friend's records are used as the Full Simulation comparison and as Training split targets.", Modifier.padding(bottom = 4.dp), C.text2)
            if (Store.friends.isNotEmpty()) {
                // 친구 n / 10 (꽉 차면 노랑)
                Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), horizontalArrangement = Arrangement.End) {
                    val n = Store.friends.size
                    T("$n / ${Store.FRIEND_LIMIT}", F.num(13, W400, if (n >= Store.FRIEND_LIMIT) C.accent else C.text2), Modifier.testTag("friends.count"),
                        translate = false)
                }
                Column(Modifier.fillMaxWidth().card8()) {
                    Store.friends.forEachIndexed { i, f -> FriendRow(f, i == Store.friends.size - 1) }
                }
            }
            Note8("Tap to compare · Tap again to clear · VS is against your best")
            Sent()
            Blocked()
        }
    }
}

/** 받은 요청: Decline (흰 0.12) · Accept (노랑). 수락해야 친구가 되고 그 뒤에만 서로 기록이 보임 */
@Composable
private fun Requests() {
    val list = Store.incoming
    if (!Store.signedIn || list.isEmpty()) return
    Row(Modifier.fillMaxWidth().padding(top = 14.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        T(SectionText.shown("REQUESTS"), F.t(F.sub, W600), maxLines = 1, translate = false)
        CountBadge(list.size)
    }
    Column(Modifier.fillMaxWidth().card8()) {
        list.forEachIndexed { i, q ->
            Row(Modifier.fillMaxWidth().rowLine(i < list.size - 1).padding(vertical = 12.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar8(34.dp, q.name.take(1).uppercase())
                Column(Modifier.weight(1f)) {
                    T("@" + q.name, F.t(15, W600), maxLines = 1, translate = false)
                    T(q.div, F.t(13, color = C.text2), maxLines = 1, translate = false)
                }
                Pill("Decline", false, "friends.decline") { Store.respond(q, false) }
                Pill("Accept", true, "friends.accept") { if (!Store.respond(q, true)) limitAsk() }
            }
        }
    }
    Note8("Records are shared only after you accept.")
}

/** 보낸 요청: 상대가 수락할 때까지 · Cancel 로 취소 */
@Composable
private fun Sent() {
    val list = Store.outgoing
    if (!Store.signedIn || list.isEmpty()) return
    SectionLabel("SENT")
    Column(Modifier.fillMaxWidth().card8()) {
        list.forEachIndexed { i, q ->
            Row(Modifier.fillMaxWidth().rowLine(i < list.size - 1).padding(vertical = 12.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar8(34.dp, q.name.take(1).uppercase())
                Column(Modifier.weight(1f)) {
                    T("@" + q.name, F.t(15, W600), maxLines = 1, translate = false)
                    T(q.div + " · " + "Requested".l10n, F.t(13, color = C.text2), maxLines = 1, translate = false)
                }
                Pill("Cancel", false, "friends.cancelRequest") { Store.cancelRequest(q) }
            }
        }
    }
    Note8("They'll see your request in Friends. Records are shared once they accept.")
}

/** 차단한 사람 (Unblock 으로 풂) */
@Composable
private fun Blocked() {
    val list = Store.settings.blocked
    if (list.isEmpty()) return
    SectionLabel("BLOCKED")
    Column(Modifier.fillMaxWidth().card8()) {
        list.forEachIndexed { i, b ->
            Row(Modifier.fillMaxWidth().rowLine(i < list.size - 1).padding(vertical = 11.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically) {
                T("@" + b.name, F.t(17, color = C.text2), Modifier.weight(1f), maxLines = 1, translate = false)
                Pill("Unblock", false, "friends.unblock") { Store.unblock(b.id) }
            }
        }
    }
}

/** 32 높이 알약 */
@Composable
private fun Pill(title: String, yellow: Boolean, tag: String, enabled: Boolean = true, dim: Boolean = false, onClick: () -> Unit) {
    Box(Modifier.height(32.dp).clip(CircleShape).background(if (yellow) C.accent else Color.White.copy(alpha = 0.12f))
        .press(0.96f, enabled = enabled, tag = tag, onClick = onClick).padding(horizontal = 14.dp), contentAlignment = Alignment.Center) {
        T(title, F.t(13, W600, if (yellow) Color.Black else if (dim) C.text2 else Color.White), maxLines = 1)
    }
}

/** 검색 결과: 34 원 · @닉네임 · 디비전 · Add / Requested / Friends / Accept · ··· */
@Composable
private fun HitCard(h: RemoteProfile, n: String) {
    val isFriend = Store.friends.any { it.id == h.id }
    val got = Store.incoming.firstOrNull { it.id == h.id }
    val req = h.id in Store.requested || isFriend || Store.outgoing.any { it.id == h.id }
    val title = when { got != null -> "Accept"; isFriend -> "Friends"; req -> "Requested"; else -> "Add" }
    val yellow = got != null || !req
    Row(Modifier.fillMaxWidth().card8().padding(vertical = 12.dp).padding(start = 18.dp, end = 6.dp).testTag("friends.hit"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Avatar8(34.dp, n.take(1).uppercase())
        Column(Modifier.weight(1f)) {
            T("@$n", F.t(15, W600), maxLines = 1, translate = false)
            T(h.division ?: "", F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Pill(title, yellow, "friends.add", enabled = got != null || !req, dim = !yellow) {
            if (got != null) { if (!Store.respond(got, true)) limitAsk() }
            else if (!Store.addFriend(h.id)) limitAsk()
        }
        MoreButton(h.id, n)
    }
}

/** 친구 줄: 40 원 · 이름 17 (고르면 600) + 디비전 · 날짜 · 최고 Full Sim 시간 + 내 최고와의 차이 · 체크 · ··· */
@Composable
private fun FriendRow(f: Friend, last: Boolean) {
    val on = Store.settings.friendId == f.id
    val myBest = Store.book.simBest?.total
    val d = if (myBest != null && f.hasSplits) f.total - myBest else null
    Row(Modifier.fillMaxWidth().rowLine(!last), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f).tap { if (f.hasSplits) Store.toggleFriend(f) }.testTag("friend." + f.name)
            .padding(vertical = 14.dp).padding(start = 18.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Avatar8(40.dp, f.ini)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(f.name, F.t(17, if (on) W600 else W400), maxLines = 1, translate = false)
                T(f.div + " · " + (if (f.hasSplits) f.date else "No Full Simulation record".l10n), F.t(13, color = C.text2), maxLines = 1, translate = false)
            }
            Column(horizontalAlignment = Alignment.End) {
                T(if (f.hasSplits) Fm.t(f.total) else "--:--", F.num(17, tracking = -0.34f), maxLines = 1, translate = false)
                if (d != null) T(Fm.d(d), F.num(11, color = if (d > 0) C.good else if (d < 0) C.bad else C.text2), maxLines = 1, translate = false)
            }
            if (on) Check8(size = 20.dp) else Spacer(Modifier.size(20.dp))
        }
        Box(Modifier.padding(end = 6.dp)) { MoreButton(f.id, f.name) }
    }
}

/** ··· (신고 · 차단 메뉴) */
@Composable
private fun MoreButton(id: String, name: String) {
    Row(Modifier.size(36.dp, 44.dp).tap { Router.userMenu = BlockedUser(id, name) }.testTag("friends.more"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterHorizontally)) {
        repeat(3) { Box(Modifier.size(4.dp).clip(CircleShape).background(C.text2)) }
    }
}

/** ··· 을 누르면 아래에서 올라오는 메뉴: Report (운영자에게 메일) · Block user */
@Composable
fun UserMenuSheet(u: BlockedUser) {
    val ctx = LocalContext.current
    Column(Modifier.padding(horizontal = 16.dp).padding(top = 4.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        T("@" + u.name, F.t(15, W600, C.text2), Modifier.fillMaxWidth(), align = TextAlign.Center, maxLines = 1, translate = false)
        Column(Modifier.fillMaxWidth().card8(14.dp)) {
            Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).rowLine(true).tap {
                Router.userMenu = null
                // 신고: 메일 앱을 열어 운영자에게 (누구를 신고하는지 미리 적어 둠). 메일 앱이 없으면 주소를 알려 줌
                val body = "Reported user: @${u.name}\nUser ID: ${u.id}\n\n" + "Tell us what is wrong (nickname, photo or records):".l10n + "\n"
                val uri = Uri.parse("mailto:$SUPPORT_EMAIL?subject=" + Uri.encode("[SPLITS8] Report @" + u.name) + "&body=" + Uri.encode(body))
                val ok = runCatching { ctx.startActivity(Intent(Intent.ACTION_SENDTO, uri)) }.isSuccess
                if (!ok) Router.ask = Ask("Report by email", SUPPORT_EMAIL, cancel = null)
            }.testTag("menu.report").padding(horizontal = 18.dp), contentAlignment = Alignment.CenterStart) {
                T("Report", F.t(17), maxLines = 1)
            }
            Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).tap {
                Router.userMenu = null
                Router.ask = Ask("Block this user?", "They are removed from your friends and hidden from your search and rankings. You can unblock them here later.",
                    ok = "Block user", destructive = true) { Store.block(u.id, u.name) }
            }.testTag("menu.block").padding(horizontal = 18.dp), contentAlignment = Alignment.CenterStart) {
                T("Block user", F.t(17, color = C.bad), maxLines = 1)
            }
        }
        Box(Modifier.fillMaxWidth().height(52.dp).card8(14.dp).tap { Router.userMenu = null }, contentAlignment = Alignment.Center) {
            T("Cancel", F.t(17, W600), maxLines = 1)
        }
    }
}

