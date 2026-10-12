package com.nkssi.splits8.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.LBRow
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.ui.Avatar8
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.FoldChips
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

// 아이폰 SimRaceViews.swift 의 RaceLeaderboard — 홈 FRIENDS 순위표 (가입 후)

private val lbStations = listOf(
    "skiErg" to "SkiErg", "sledPush" to "Sled Push", "sledPull" to "Sled Pull", "burpeeBroadJump" to "BBJ",
    "row" to "Row", "farmersCarry" to "Farmers", "sandbagLunges" to "Lunges", "wallBalls" to "Wall Balls",
)

@Composable
fun RaceLeaderboard() {
    val s = Store.settings
    var chipsOpen by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Seg8(listOf("sim" to "Full Sim", "race" to "Race", "stations" to "Stations"), s.lbTab) { k ->
            Store.update { it.copy(lbTab = k) }
        }
        if (s.lbTab == "stations") {
            FoldChips(chipsOpen, { chipsOpen = !chipsOpen }, height = 34.dp, radius = 17.dp,
                pinned = lbStations.indexOfFirst { it.first == s.lbStation }.takeIf { it >= 0 }, tag = "lb.chips.more") {
                lbStations.forEach { (k, name) ->
                    val on = s.lbStation == k
                    Row(
                        Modifier.height(34.dp).clip(CircleShape).background(if (on) C.accent else Color.White.copy(alpha = 0.08f))
                            .tap { Store.update { it.copy(lbStation = k) } }.padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Icon8(k, 14.dp, if (on) Color.Black else C.accent)
                        T(name, F.t(13, W600, if (on) Color.Black else Color.White), maxLines = 1, translate = false)
                    }
                }
            }
        }
        // 설명 줄 + 디비전 전환
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            val caption = when (s.lbTab) {
                "sim" -> L10n.t("Best Full Simulation · All time")
                "race" -> L10n.t("Best race time · All events")
                else -> L10n.t("Best %@ split · All time", lbStations.firstOrNull { it.first == s.lbStation }?.second ?: "")
            }
            T(caption, F.t(13, color = C.text2), Modifier.weight(1f), maxLines = 1, translate = false)
            T(if (s.lbAllDivisions) L10n.t("All divisions") else s.div.name, F.t(13, W600, C.accent),
                Modifier.tap { Store.update { it.copy(lbAllDivisions = !it.lbAllDivisions) } }.testTag("lb.division"), translate = false)
        }
        // 순위
        val rows = Store.leaderboard
        val me = Store.myId
        val meT = rows.firstOrNull { it.user_id == me }?.t
        Column(Modifier.fillMaxWidth().card8()) {
            if (rows.isEmpty()) {
                T("No records yet. Finish a Full Simulation once and it will show up here.", F.t(13, color = C.text2),
                    Modifier.fillMaxWidth().padding(vertical = 22.dp, horizontal = 18.dp), align = TextAlign.Center)
            }
            rows.forEachIndexed { i, row -> LbRow(i, row, row.user_id == me, meT, i == rows.size - 1) }
        }
        T("+ Add friends", F.t(15, W600, C.accent),
            Modifier.fillMaxWidth().tap { Router.friendsFrom = Scr.Home; Router.go(Scr.Friends) }.padding(6.dp).testTag("race.addFriends"),
            align = TextAlign.Center)
    }
}

@Composable
private fun LbRow(i: Int, row: LBRow, me: Boolean, meT: Int?, last: Boolean) {
    Row(
        Modifier.fillMaxWidth().rowLine(!last)
            .background(if (me) Color(0x14FFE600) else Color.Transparent)
            .tap { openFriend(row, me) }
            .padding(vertical = 12.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        T("${i + 1}", F.num(17, color = if (i == 0) C.accent else Color.White), Modifier.width(22.dp), translate = false)
        Avatar8(34.dp, row.nickname.take(1).uppercase(), bg = if (me) C.accent else C.control, fg = if (me) Color.Black else Color.White)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(if (me) L10n.t("@%@ (you)", row.nickname) else "@${row.nickname}", F.t(15, if (me) W600 else W500, if (me) C.accent else Color.White),
                maxLines = 1, translate = false)
            T(row.division, F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Column(horizontalAlignment = Alignment.End) {
            T(Fm.t(row.t), F.num(17, tracking = -0.34f), maxLines = 1, translate = false)
            if (!me && meT != null) {
                T(Fm.d(row.t - meT), F.num(13, color = if (row.t < meT) C.bad else C.good), maxLines = 1, translate = false)
            }
        }
    }
}

/** 친구를 누르면 Full Simulation 에서 그 친구와 비교 */
private fun openFriend(row: LBRow, me: Boolean) {
    if (me) return
    val f = Store.friends.firstOrNull { it.id == row.user_id } ?: return
    Store.update { it.copy(friendId = f.id, simCmp = "friend") }
    Router.goTest("sim")
}
