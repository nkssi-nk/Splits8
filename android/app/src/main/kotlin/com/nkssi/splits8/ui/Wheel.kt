package com.nkssi.splits8.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * 돌려서 고르는 숫자 바퀴 (아이폰 Picker .wheel 대신). 높이 150, 한 칸 36, 가운데 칸이 고른 값.
 * 가운데 칸 뒤에 옅은 회색 띠, 위아래로 갈수록 흐려짐
 */
@Composable
fun Wheel8(
    values: List<Int>, selected: Int, modifier: Modifier = Modifier, label: (Int) -> String = { "$it" }, tag: String = "wheel",
    onChange: (Int) -> Unit,
) {
    val itemH = 36.dp
    val start = values.indexOf(selected).coerceAtLeast(0)
    val state = rememberLazyListState(start)
    val fling = rememberSnapFlingBehavior(state)
    LaunchedEffect(state) {
        snapshotFlow { state.firstVisibleItemIndex + if (state.firstVisibleItemScrollOffset > 0 && state.layoutInfo.visibleItemsInfo.isNotEmpty() &&
            state.firstVisibleItemScrollOffset > state.layoutInfo.visibleItemsInfo.first().size / 2) 1 else 0 }
            .distinctUntilChanged()
            .collect { i -> values.getOrNull(i)?.let { if (it != selected) onChange(it) } }
    }
    // 밖에서 값이 바뀌면 (예: 시트를 다시 열 때) 그 자리로
    LaunchedEffect(selected) {
        val i = values.indexOf(selected)
        if (i >= 0 && i != state.firstVisibleItemIndex && !state.isScrollInProgress) state.scrollToItem(i)
    }
    Box(modifier.height(150.dp).testTag(tag), contentAlignment = Alignment.Center) {
        Box(Modifier.fillMaxWidth().height(itemH).background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.08f), RoundedCornerShape(8.dp)))
        val pad = (150.dp - itemH) / 2
        LazyColumn(Modifier.fillMaxWidth().height(150.dp), state = state, flingBehavior = fling, contentPadding = PaddingValues(vertical = pad)) {
            items(values.size) { i ->
                val d = kotlin.math.abs(i - state.firstVisibleItemIndex)
                Box(Modifier.fillMaxWidth().height(itemH).alpha(if (d == 0) 1f else if (d == 1) 0.55f else 0.3f), contentAlignment = Alignment.Center) {
                    T(label(values[i]), F.num(20, if (d == 0) W600 else W400), maxLines = 1, translate = false)
                }
            }
        }
    }
}
