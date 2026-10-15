package com.nkssi.splits8

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.shared.WidgetKo
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

/**
 * 빌드 24 · 위젯 바탕 고르기 (아이폰: 위젯 길게 누르기 → 위젯 편집 → Background).
 * 안드로이드: 위젯을 길게 눌러 설정(연필) → 이 화면. 처음 놓을 때는 묻지 않고 '자동' (configuration_optional).
 */
class WidgetLookActivity : ComponentActivity() {
    private var id = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // 취소(뒤로)하면 위젯을 놓지 않음 — 다만 다시 고르기(이미 있는 위젯)에서는 그대로 둠
        setResult(Activity.RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        Store.init(applicationContext)
        enableEdgeToEdge()
        setContent { LookPicker(id) { look -> choose(look) } }
    }

    private fun choose(look: String) {
        Widgets.setLook(this, id, look)
        Widgets.refresh(this)
        setResult(Activity.RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        finish()
    }
}

@Composable
private fun LookPicker(id: Int, onPick: (String) -> Unit) {
    val ctx = LocalContext.current
    var cur by remember { mutableStateOf(Widgets.look(ctx, id)) }
    val snap = remember { Widgets.snap() }
    val looks = listOf("auto" to "Automatic", "black" to "Black", "white" to "White", "theme" to "Theme color")
    Column(
        Modifier.fillMaxSize().background(Color.Black).statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        T(WidgetKo.t("Background"), F.t(28, W600, tracking = -0.5f), maxLines = 1, translate = false)
        T(WidgetKo.t("Choose the widget background."), F.t(15, color = C.text2), translate = false)
        // 미리보기 (지금 고른 바탕)
        val night = (ctx.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val pal = WidgetPal.of(cur, night, snap.themeHex)
        val now = Store.now()
        val k = ctx.resources.displayMetrics.density
        val bmp = remember(cur) {
            val isWeek = runCatching {
                AppWidgetManager.getInstance(ctx).getAppWidgetInfo(id)?.provider?.className?.endsWith("WeekWidget")
            }.getOrNull() == true
            if (isWeek) WidgetArt.week(ctx, snap, now, 170f, 170f, k, pal) else WidgetArt.dday(ctx, snap, now, 170f, 170f, k, pal)
        }
        Box(Modifier.fillMaxWidth().padding(vertical = 6.dp), contentAlignment = Alignment.Center) {
            Image(bmp.asImageBitmap(), null, Modifier.size(170.dp))
        }
        Column(Modifier.fillMaxWidth().card8()) {
            looks.forEachIndexed { i, (key, label) ->
                Row(
                    Modifier.fillMaxWidth().rowLine(i < looks.size - 1).tap { cur = key }.padding(vertical = 14.dp, horizontal = 18.dp).testTag("look.$key"),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    T(WidgetKo.t(label), F.t(17), Modifier.weight(1f), maxLines = 1, translate = false)
                    if (cur == key) Check8()
                }
            }
        }
        Box(
            Modifier.fillMaxWidth().height(52.dp).clip(RoundedCornerShape(14.dp)).background(C.accent).tap { onPick(cur) }.testTag("look.done"),
            contentAlignment = Alignment.Center,
        ) { T(WidgetKo.t("Done"), F.t(17, W600, Color.Black), maxLines = 1, translate = false) }
    }
}
