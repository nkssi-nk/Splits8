package com.nkssi.splits8.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.runMeters
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

// 운동 중 화면 공용 부품 — 폰으로 기록(PhoneLive) · 워치 운동 같이 보기(WatchLive) 두 화면이 같은 모양 (빌드 24, 인계-최신 3.1).
//  머리: 제목 / ● 상태 줄 / "n / 16" / 진행 막대 (끝 없는 운동은 막대 · 숫자 숨김)
//  가운데: TOTAL · 큰 전체 시간 · [아이콘 이름] · SPLIT | 오른쪽 칸 · 아래 줄
//  오른쪽 칸: 러닝 = PACE /KM, 목표가 있는 구간 = GOAL(트레이닝은 BEST) + 목표 시간 그대로, Roxzone 도 GOAL.
//  목표를 넘기면 SPLIT 숫자가 빨강.

/** 화면 한 장면에 필요한 값 (엔진 · 워치에서 받은 상태 어느 쪽이든 여기로 바꿔 그림) */
data class LiveFrame(
    val mode: Mode,
    val title: String,
    val seq: List<Seg>,
    val idx: Int,
    val segEl: Int,
    val total: Int,
    val running: Boolean,
    /** HIIT · 자유 러닝 (막대 · n/16 숨김) */
    val open: Boolean,
    /** 러닝 페이스용 지금 구간 거리(m) — 못 재면 null */
    val segDist: Double?,
    /** 운동 전체 거리(m) — 러닝 카드 "총 x km" 줄 */
    val totalDist: Double?,
    /** 러닝 카드(트레이닝 러닝)인지 */
    val runKind: Boolean,
    /** 다음 구간 (null = 마지막 → Finish) */
    val next: Seg?,
    /** 빌드 27: 지금 속도(m/s) — 실시간 페이스. null · 0 = 모름 */
    val speed: Double? = null,
    /** 빌드 27: lb · mi 로 보여 주는지 (설정 > Units) */
    val imperial: Boolean = false,
) {
    val cur: Seg get() = seq.getOrNull(idx) ?: seq.lastOrNull() ?: Seg("run", "Run", "1KM", SegKind.Run, 0)

    /** Roxzone 을 뺀 전체 구간 수 */
    val countTotal: Int get() = seq.count { it.kind != SegKind.Rox }
    /** 지금 번호 (Roxzone 동안은 앞 구간 번호 그대로) */
    val countNow: Int get() = max(1, seq.take(idx + 1).count { it.kind != SegKind.Rox })

    /** 막대 위 점 자리 0~1 (Roxzone 은 앞 구간과 다음 구간 사이) */
    val progress: Float
        get() {
            val n = countTotal
            if (n <= 1) return 0f
            val pos = (countNow - 1) + (if (cur.kind == SegKind.Rox) 0.5f else 0f)
            return min(1f, max(0f, pos / (n - 1)))
        }

    /** 목표 이름: 트레이닝은 최고 기록(BEST), 나머지는 GOAL */
    val goalWord: String get() = if (mode == Mode.Training) "BEST" else "GOAL"

    /** 목표를 넘겼는지 (SPLIT 빨강) */
    val over: Boolean get() = cur.target > 0 && segEl > cur.target

    /** 아래 줄: 러닝 = "0.62 / 1.00 KM (· 총 x km)", 스테이션 = 세부(50M · 152KG), Roxzone · 목표 없는 구간 = 빈 줄 */
    val detailLine: String
        get() {
            val c = cur
            if (c.kind == SegKind.Rox) return ""
            if (c.kind == SegKind.Run) {
                val sd = segDist ?: return Units.detail(c.detail, imperial)
                val segM = runMeters(c.detail)
                var s = Units.dist(min(segM, sd), imperial) + " / " + Units.dist(segM, imperial) + " " + Units.distUnit(imperial)
                val td = totalDist
                if ((open || runKind) && td != null && td >= 10) {
                    s += " · " + if (imperial) L10n.t("Total %@ mi", Units.dist(td, true))
                    else L10n.t("Total %@ km", String.format(Locale.US, "%.2f", td / 1000))
                }
                return s
            }
            return if (c.target > 0) Units.detail(c.detail, imperial) else ""
        }
}

/** 머리: 제목 · ● 상태 줄 · n / 16 · 진행 막대 */
@Composable
fun LiveHeader(f: LiveFrame, status: String, live: Boolean, tagPrefix: String) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(if (f.mode == Mode.Training) f.title else f.mode.title, F.t(17, W600), maxLines = 1)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(6.dp).clip(CircleShape).background(if (live) C.good else C.text3))
                    T(status, F.t(12, color = C.text2), Modifier.testTag("$tagPrefix.status"), maxLines = 1)
                }
            }
            Spacer(Modifier.width(12.dp))
            if (!f.open) {
                Box(Modifier.height(22.dp).border(1.dp, C.accent.copy(alpha = 0.5f), RoundedCornerShape(50)).padding(horizontal = 8.dp),
                    contentAlignment = Alignment.Center) {
                    T("${f.countNow} / ${f.countTotal}", F.num(12, color = C.accent), Modifier.testTag("$tagPrefix.of"), maxLines = 1, translate = false)
                }
            }
        }
        if (!f.open) LiveProgressBar(f.progress)
    }
}

/** 한 줄 막대 + 지금 자리에 빛나는 점 (아이폰 LiveProgress) */
@Composable
fun LiveProgressBar(fraction: Float, height: Float = 3f) {
    Canvas(Modifier.fillMaxWidth().height((height * 3).dp)) {
        val h = height.dp.toPx()
        val cy = size.height / 2
        val x = size.width * fraction
        drawRoundRect(Color.White.copy(alpha = 0.16f), Offset(0f, cy - h / 2), Size(size.width, h), CornerRadius(h / 2))
        drawRoundRect(C.accent, Offset(0f, cy - h / 2), Size(max(h, x), h), CornerRadius(h / 2))
        drawCircle(Brush.radialGradient(listOf(C.accent.copy(alpha = 0.6f), C.accent.copy(alpha = 0f)), Offset(x, cy), h * 3), h * 3, Offset(x, cy))
        drawCircle(C.accent, h * 1.5f, Offset(x, cy))
    }
}

/** TOTAL · 큰 전체 시간 · [아이콘 이름] · SPLIT | 오른쪽 칸 · 아래 줄 */
@Composable
fun LiveBody(f: LiveFrame, totalFont: Float, segFont: Float, icon: Float, nameFont: Float, detailFont: Float,
             segTop: Float, nameTop: Float, tagPrefix: String, modifier: Modifier = Modifier) {
    val cur = f.cur
    val timeColor = if (f.running) Color.White else C.text2
    // 지금 하는 구간의 시간은 노랑 (전체 시간은 흰색), 목표를 넘기면 빨강
    val segColor = if (!f.running) C.text2 else if (f.over) C.bad else C.accent
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        T("TOTAL", F.t(12, W600, C.text2, tracking = 1.44f), maxLines = 1)
        FitText(Fm.t(f.total), F.num(totalFont, color = timeColor, tracking = -0.02f * totalFont),
            Modifier.testTag("$tagPrefix.total"), minScale = 0.6f)
        Row(Modifier.padding(top = (segTop * 0.6f).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon8(cur.icon, (icon * 0.7f).dp, if (cur.kind == SegKind.Rox) C.text2 else C.accent)
            FitText(cur.name, F.t(nameFont, W600), minScale = 0.7f)
        }
        Row(Modifier.padding(top = nameTop.dp).fillMaxWidth(), verticalAlignment = Alignment.Top) {
            LiveCol("SPLIT", Fm.t(f.segEl), segColor, segFont * 0.85f, Modifier.testTag("$tagPrefix.seg"))
            // 가운데 세로선: 숫자 높이에 맞춤
            Box(Modifier.padding(top = 22.dp).width(1.dp).height((segFont * 0.85f).dp).background(Color.White.copy(alpha = 0.14f)))
            when {
                cur.kind == SegKind.Run -> LiveCol(if (f.imperial) "PACE /MI" else "PACE /KM",
                    LivePace.text(f.segEl, f.segDist, f.imperial, f.speed), timeColor, segFont * 0.85f)
                cur.target > 0 -> LiveCol(f.goalWord, Fm.t(cur.target), timeColor, segFont * 0.85f, Modifier.testTag("$tagPrefix.goal"))
                else -> LiveCol("", Units.detail(cur.detail, f.imperial), C.text2, nameFont)
            }
        }
        FitText(f.detailLine, F.num(detailFont, androidx.compose.ui.text.font.FontWeight.Normal, C.aeb),
            Modifier.padding(top = 6.dp).height((detailFont * 1.4f).dp), minScale = 0.7f)
    }
}

@Composable
private fun RowScope.LiveCol(label: String, value: String, color: Color, size: Float, modifier: Modifier = Modifier) {
    Column(modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Box(Modifier.height(18.dp), contentAlignment = Alignment.Center) { T(label, F.t(12, W600, C.text3, tracking = 1f), maxLines = 1) }
        FitText(value, F.num(size, color = color, tracking = -0.01f * size), minScale = 0.5f)
    }
}

/** 선 · NEXT [아이콘] 이름 (마지막이면 Finish) */
@Composable
fun LiveNextRow(next: Seg?, labelFont: Float, nameFont: Float, iconSize: Float, dividerTop: Float, k: Float, tagPrefix: String) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.padding(top = dividerTop.dp, bottom = (14 * k).dp).padding(horizontal = 20.dp).fillMaxWidth().height(1.dp)
            .background(Color.White.copy(alpha = 0.12f)))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            T("NEXT", F.t(labelFont, color = C.text2, tracking = 0.1f * labelFont), maxLines = 1)
            if (next != null) {
                Icon8(next.icon, iconSize.dp, if (next.kind == SegKind.Rox) C.text2 else C.accent)
                T(next.name, F.t(nameFont, W600), Modifier.testTag("$tagPrefix.nextName"), maxLines = 1)
            } else {
                T("Finish", F.t(nameFont, W600, C.accent), maxLines = 1)
            }
        }
    }
}
