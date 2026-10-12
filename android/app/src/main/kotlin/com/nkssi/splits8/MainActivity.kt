package com.nkssi.splits8

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { Placeholder() }
    }
}

/** 뼈대 확인용 첫 화면 — 다음 단계에서 시작 화면 · 탭 5개로 바뀜 */
@Composable
fun Placeholder() {
    Column(
        Modifier.fillMaxSize().background(C.bg).padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(
            painterResource(R.drawable.wordmark_yellow), contentDescription = "SPLITS8",
            modifier = Modifier.width(240.dp),
        )
        Spacer(Modifier.height(16.dp))
        BasicText(
            "8 RUNS · 8 STATIONS",
            style = TextStyle(fontFamily = F.family, fontWeight = FontWeight.SemiBold, fontSize = F.foot.sp, color = C.text2, letterSpacing = 1.sp),
        )
        Spacer(Modifier.height(24.dp))
        BasicText(
            "Android · ${Division.all.size} divisions\n안드로이드판 준비 중",
            style = TextStyle(fontFamily = F.family, fontSize = F.sub.sp, color = C.text3, textAlign = TextAlign.Center),
        )
    }
}

@Preview(widthDp = 390, heightDp = 844)
@Composable
private fun PlaceholderPreview() = Placeholder()
