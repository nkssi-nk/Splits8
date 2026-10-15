package com.nkssi.splits8.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Badge
import com.nkssi.splits8.shared.Badges
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.SectionText
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.outerGlow
import com.nkssi.splits8.ui.press

// 배지 화면 부품 (아이폰 Badges.swift 의 BadgeIcon · BadgesCard · NewBadgesRow)

/** 아이폰 SF Symbol 이름 → 안드로이드 그림 */
private fun badgeSym(icon: String): Int = when (icon) {
    "flag.checkered" -> R.drawable.sym_flag
    "medal" -> R.drawable.sym_medal
    "stopwatch", "timer" -> R.drawable.sym_stopwatch
    "square.grid.3x3.fill" -> R.drawable.sym_grid
    "bolt.fill" -> R.drawable.sym_bolt
    "crown.fill" -> R.drawable.sym_crown
    "star.fill" -> R.drawable.sym_star
    "arrow.up.right" -> R.drawable.sym_arrow_ur
    "chart.line.uptrend.xyaxis" -> R.drawable.sym_trend
    "calendar" -> R.drawable.sym_calendar
    "calendar.badge.checkmark" -> R.drawable.sym_calendar_check
    "figure.run" -> R.drawable.sym_run
    else -> R.drawable.sym_road
}

/** 배지 하나 (동그라미 + 아이콘). 못 받은 것은 흐리게 */
@Composable
fun BadgeIcon(b: Badge, on: Boolean, size: Dp = 54.dp, modifier: Modifier = Modifier) {
    Box(
        modifier.size(size)
            .then(if (on) Modifier.outerGlow(C.accent.copy(alpha = 0.35f), size / 2, 8.dp) else Modifier)
            .clip(CircleShape)
            .background(if (on) Brush.verticalGradient(listOf(Color(0xFFFFE600), Color(0xFFFFB800))) else Brush.linearGradient(listOf(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.06f))))
            .border(1.dp, if (on) Color.White.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.10f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Sym(badgeSym(b.icon), size * 0.42f, if (on) Color.Black else C.text3)
    }
}

/** 내 정보(프로필 화면)의 배지 모음 */
@Composable
fun BadgesCard() {
    val got = remember(Store.records) { Badges.earned(Store.records) }
    Column(Modifier.fillMaxWidth().testTag("badges"), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth().padding(top = 14.dp, start = 4.dp, end = 4.dp), verticalAlignment = Alignment.Bottom) {
            T(SectionText.shown("BADGES"), F.t(F.sub, W600), Modifier.weight(1f), maxLines = 1, translate = false)
            T("${got.size} / ${Badges.all.size}", F.num(13, color = C.text2), Modifier.testTag("badges.count"), maxLines = 1, translate = false)
        }
        Column(Modifier.fillMaxWidth().card8().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            for ((g, label) in Badges.groups) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Label8(label, size = 11)
                    // 4칸 격자 (칸 사이 8, 줄 사이 12)
                    Badges.all.filter { it.group == g }.chunked(4).forEach { row ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            for (b in row) {
                                val d = got[b.id]
                                Column(
                                    Modifier.weight(1f).press(0.95f) {
                                        val msg = b.sub.l10n + (d?.let { "\n" + L10n.t("Earned %@", Fm.wdm(it)) } ?: "")
                                        Router.ask = Ask(b.title.l10n, msg, cancel = null)
                                    }.testTag("badge.${b.id}"),
                                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    BadgeIcon(b, d != null)
                                    T(b.title, F.t(11, W500, if (d != null) Color.White else C.text3), Modifier.fillMaxWidth().height(28.dp),
                                        maxLines = 2, align = TextAlign.Center)
                                }
                            }
                            repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
            }
        }
    }
}

/** 운동 끝 카드 안: "새 배지" 한 줄 (여러 개면 아이콘을 나란히) */
@Composable
fun NewBadgesRow(badges: List<Badge>, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier.fillMaxWidth().clip(shape).background(C.accent.copy(alpha = 0.10f)).border(1.dp, C.accent.copy(alpha = 0.30f), shape)
            .padding(vertical = 10.dp, horizontal = 12.dp).testTag("finish.badges"),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        val shown = badges.take(3)
        Box(Modifier.width(36.dp + 26.dp * (shown.size - 1)).height(36.dp)) {
            shown.forEachIndexed { i, b -> BadgeIcon(b, true, 36.dp, Modifier.offset(x = 26.dp * i)) }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(if (badges.size == 1) "New badge".l10n else L10n.t("%lld new badges", badges.size), F.t(F.cap1, W700, C.accent, tracking = 0.72f),
                maxLines = 1, translate = false)
            T(badges.joinToString(" · ") { it.title.l10n }, F.t(15, W600), maxLines = 1, translate = false)
        }
    }
}
