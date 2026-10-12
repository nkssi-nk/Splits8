package com.nkssi.splits8.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.ScreenScaffold
import androidx.compose.ui.tooling.preview.Preview

class WearActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { WearPlaceholder() }
    }
}

/** 뼈대 확인용 — 다음 단계에서 모드 4개 홈으로 바뀜 */
@Composable
fun WearPlaceholder() {
    AppScaffold {
        ScreenScaffold {
            Column(
                Modifier.fillMaxSize().background(Color.Black),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Image(painterResource(R.drawable.wordmark_yellow), "SPLITS8", Modifier.width(110.dp))
                Spacer(Modifier.height(8.dp))
                BasicText("Watch", style = TextStyle(color = Color(0xFF8E8E93), fontSize = 13.sp))
            }
        }
    }
}

@Preview(device = "id:wearos_large_round", showSystemUi = true)
@Composable
private fun WearPlaceholderPreview() = WearPlaceholder()
