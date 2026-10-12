package com.nkssi.splits8.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 칩 묶음 (아이폰 FoldChips): 접으면 한 줄 + 오른쪽 겹꺾쇠(︾), 누르면 전부 펼쳐지고 끝에 ︽.
 * 접힌 상태에서도 고른 칩(pinned)은 항상 보임
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FoldChips(
    open: Boolean, onToggle: () -> Unit, modifier: Modifier = Modifier, spacing: Dp = 6.dp, height: Dp = 34.dp,
    radius: Dp = 10.dp, pinned: Int? = null, tag: String = "chips.more", chips: @Composable () -> Unit,
) {
    val toggleW = height + 6.dp
    val toggle: @Composable () -> Unit = {
        Box(Modifier.size(toggleW, height).strokeBorder(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.16f), radius)
            .doubleChevron(open).tap(onClick = onToggle).testTag(tag))
    }
    if (open) {
        FlowRow(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(spacing), verticalArrangement = Arrangement.spacedBy(spacing)) {
            chips()
            toggle()
        }
    } else {
        Layout(content = { chips(); toggle() }, modifier = modifier.fillMaxWidth()) { measurables, c ->
            val sp = spacing.roundToPx()
            val loose = Constraints(maxHeight = c.maxHeight)
            val chipM = measurables.dropLast(1).map { it.measure(loose) }
            val tog = measurables.last().measure(loose)
            val room = c.maxWidth - tog.width - sp
            val shown = OneRowFit.fit(chipM.map { it.width }, room, sp, pinned)
            val h = maxOf(tog.height, chipM.maxOfOrNull { it.height } ?: 0)
            layout(c.maxWidth, h) {
                var x = 0
                for (i in shown) { chipM[i].placeRelative(x, 0); x += chipM[i].width + sp }
                tog.placeRelative(c.maxWidth - tog.width, 0)
            }
        }
    }
}

object OneRowFit {
    /** 한 줄에 보일 칩 번호 (왼쪽부터 놓을 순서). 고른 칩이 안 보이면 뒤에서부터 빼서 자리를 만듦 */
    fun fit(widths: List<Int>, room: Int, spacing: Int, pinned: Int?): List<Int> {
        var x = 0
        val shown = ArrayList<Int>()
        for ((i, w) in widths.withIndex()) {
            val need = (if (shown.isEmpty()) 0 else spacing) + w
            if (x + need > room) break
            x += need
            shown.add(i)
        }
        if (pinned != null && pinned in widths.indices && pinned !in shown) {
            while (shown.isNotEmpty() && x + spacing + widths[pinned] > room) {
                val last = shown.removeAt(shown.size - 1)
                x -= widths[last] + (if (shown.isEmpty()) 0 else spacing)
            }
            shown.add(pinned)
        }
        if (shown.isEmpty() && widths.isNotEmpty()) shown.add(pinned?.takeIf { it in widths.indices } ?: 0)
        return shown
    }
}
