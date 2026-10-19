package com.nkssi.splits8.screens

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.nkssi.splits8.Ask
import com.nkssi.splits8.Config
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.RoutePt
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.NavBar3
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.Toggle8
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min

// 공유 화면 (아이폰 ShareViews.swift 의 ShareView). 미리보기 · Story/Post · Poster/Ticket/Block · 옵션 · Share / Save image

/** 시험용: 마지막으로 만든 공유 그림 (저장 · 공유 직전) */
object ShareDebug {
    var last: Bitmap? = null
    /** 시험에서는 실제 저장 · 공유 창 대신 그림만 만들고 끝냄 */
    var dryRun = false
}

@Composable
fun ShareView() {
    val rec = Router.detail
    val data = remember(rec, Store.book) { rec?.let { ShareData.of(it) } ?: ShareData() }
    var ratio by remember { mutableStateOf("story") }
    var variant by remember { mutableStateOf("poster") }
    var splits by remember { mutableStateOf(true) }
    var textColor by remember { mutableStateOf("white") }
    var mono by remember { mutableStateOf(false) }   // 빌드 24: 흑백 사진은 기본 꺼짐
    var gradient by remember { mutableStateOf(true) }
    var nickOn by remember { mutableStateOf(true) }
    var glow by remember { mutableStateOf(Store.settings.glow) }
    var photo by remember { mutableStateOf(ShareDemo.photo) }
    var saved by remember { mutableStateOf(false) }
    var mapOn by remember { mutableStateOf(false) }
    var mapShotH by remember { mutableStateOf(0) }
    var smoke by remember { mutableStateOf("off") }
    var layout by remember { mutableStateOf(PosterLayout()) }
    var blockRects by remember { mutableStateOf<Map<String, Rect>>(emptyMap()) }
    var dragKey by remember { mutableStateOf<String?>(null) }
    var dragStart by remember { mutableStateOf(Rect.Zero) }
    var dragOffset by remember { mutableStateOf(Offset.Zero) }
    val post = ratio == "post"
    val smokeValue = when (smoke) { "strong" -> 1.0; "light" -> 0.6; else -> 0.0 }
    // 가입한 사람만 닉네임
    val nickName = if (Store.signedIn) Store.settings.nickname ?: "" else ""
    val canNick = nickName.isNotEmpty()
    val shownNick = if (canNick && nickOn) nickName else ""
    val route: List<RoutePt>? = rec?.route?.takeIf { it.size >= 2 }

    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = runCatching { ctx.contentResolver.openInputStream(uri)?.use { android.graphics.BitmapFactory.decodeStream(it) } }.getOrNull()
        if (bmp != null) { photo = shrink(bmp).asImageBitmap(); mapOn = false }
    }

    fun opts(placeholder: Boolean) = ShareOpts(
        variant, ratio, splits, photo, placeholder, textColor == "black", mono, gradient, shownNick, smokeValue, layout,
        if (placeholder) dragKey else null, if (placeholder) dragOffset else Offset.Zero, glow,
    )

    // 저장용 그림: 화면에 보이지 않는 곳에서 3배 크기로 (1080 너비) 그려 둠
    val layer = rememberGraphicsLayer()
    suspend fun image(): Bitmap? = runCatching { layer.toImageBitmap().asAndroidBitmap() }.getOrNull()
        ?.takeIf { it.width > 0 && it.height > 0 }?.also { ShareDebug.last = it }

    Scroll8(bottom = 40.dp) {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            NavBar3("Close", "Share", onLeft = { Router.go(Scr.Detail) })
            // 미리보기: Story 0.72 → 259×461, Post 0.86 → 310×387, 모서리 14, 바깥 1px #262626
            val scale = if (post) 0.86f else 0.72f
            val pw = if (post) 310.dp else 259.dp
            val ph = if (post) 387.dp else 461.dp
            val density = LocalDensity.current
            val cur by rememberUpdatedState(blockRects)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Box(
                    Modifier.size(pw, ph).border(1.dp, Color(0xFF262626), RoundedCornerShape(15.dp)).padding(1.dp).clip(RoundedCornerShape(14.dp))
                        .testTag("share.photo")
                        // 짧게 누르면 사진 고르기 (Block 은 사진을 쓰지 않는 모양이라 아무 일도 없음)
                        .pointerInput(variant) {
                            detectTapGestures {
                                if (variant != "block") runCatching { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
                            }
                        }
                        // Poster: 글자 덩어리를 꾹 눌러 끌어서 옮김 (쓸면 화면 넘기기)
                        .pointerInput(variant, ratio) {
                            if (variant != "poster") return@pointerInput
                            val k = scale * density.density
                            var total = Offset.Zero
                            detectDragGesturesAfterLongPress(
                                onDragStart = { start ->
                                    val p = Offset(start.x / k, start.y / k)
                                    // 겹치면 작은 덩어리부터 (표 위에 걸친 시간 덩어리를 잡기 쉽게)
                                    val hit = cur.filter { Rect(it.value.left - 6, it.value.top - 8, it.value.right + 6, it.value.bottom + 8).contains(p) }
                                        .minByOrNull { it.value.height }?.key
                                    if (hit != null) {
                                        dragKey = hit; dragStart = cur[hit] ?: Rect.Zero; total = Offset.Zero
                                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    }
                                },
                                onDrag = { ch, d ->
                                    if (dragKey == null) return@detectDragGesturesAfterLongPress
                                    ch.consume()
                                    total += Offset(d.x / k, d.y / k)
                                    dragOffset = total
                                },
                                onDragEnd = {
                                    val key = dragKey
                                    if (key != null) {
                                        val nl = movedLayout(layout, key, dragStart, total, if (post) 450f else 640f)
                                        if (nl != layout) haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                        layout = nl
                                    }
                                    dragKey = null; dragOffset = Offset.Zero
                                },
                                onDragCancel = { dragKey = null; dragOffset = Offset.Zero },
                            )
                        },
                ) {
                    ShareCard(data, opts(true),
                        Modifier.wrapContentSize(Alignment.TopStart, unbounded = true)
                            .graphicsLayer { scaleX = scale; scaleY = scale; transformOrigin = TransformOrigin(0f, 0f) }) { blockRects = it }
                }
            }
            // 저장용 (보이지 않음)
            CaptureCard(layer) { ShareCard(data, opts(false)) }
            // 경로 지도 그림 만들기 (보이지 않음, 구글 지도 키가 있을 때)
            if (route != null && mapOn && mapShotH > 0 && Config.hasMaps) {
                val h = mapShotH
                RouteMapShot(route, h) { img -> if (img != null && mapOn && mapShotH == h) { photo = img.asImageBitmap(); mono = false } }
            }
            if (variant == "poster") MoveHint(layout != PosterLayout()) { layout = PosterLayout() }
            Seg8(listOf("story" to "Story 9:16", "post" to "Post 4:5"), ratio, track = Color(0xFF141414)) { ratio = it }
            VariantButtons(variant) { variant = it }
            // 옵션 카드 (모서리 14, 줄 최소 48, 15pt)
            Column(Modifier.fillMaxWidth().card8(14.dp)) {
                if (route != null) OptionRow("Route map") {
                    Toggle8(mapOn, Modifier.testTag("share.map"), w = 50.dp, h = 30.dp) { on ->
                        mapOn = on
                        // 실외 러닝: 경로를 배경으로. 먼저 지도 없이 그린 경로 → 구글 지도 그림이 만들어지면 바꿈
                        if (on) { photo = routeImage(route, if (post) 1350 else 1920).asImageBitmap(); mono = false; mapShotH = if (post) 1350 else 1920 }
                        else { photo = null; mapShotH = 0 }
                    }
                }
                OptionRow("Text color") { MiniSeg(listOf("white" to "White", "black" to "Black"), textColor, 64, "share.text") { textColor = it } }
                OptionRow("Split times") { Toggle8(splits, Modifier.testTag("share.splits"), w = 50.dp, h = 30.dp) { splits = it } }
                OptionRow("Black & white photo") { Toggle8(mono, Modifier.testTag("share.mono"), w = 50.dp, h = 30.dp) { mono = it } }
                OptionRow("Dark gradient") { Toggle8(gradient, Modifier.testTag("share.gradient"), w = 50.dp, h = 30.dp) { gradient = it } }
                // Haze: 사진 위에 연기를 겹쳐 영화 느낌 + 글자 바탕 (Poster)
                OptionRow("Haze") { MiniSeg(listOf("off" to "Off", "light" to "Light", "strong" to "Heavy"), smoke, 56, "share.smoke") { smoke = it } }
                // Glow: Block · Ticket 뒤에 비치는 빛의 색
                if (variant != "poster") OptionRow("Glow") { GlowSwatches(glow, "share.glow", 22.dp) { glow = it } }
                Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T("Nickname", F.t(15), maxLines = 1)
                        if (!canNick) T("Sign up to add your nickname", F.t(12, color = C.text2), maxLines = 1)
                    }
                    Toggle8(canNick && nickOn, Modifier.testTag("share.nick"), w = 50.dp, h = 30.dp) { if (canNick) nickOn = it }
                }
            }
            // Share (노랑) · Save image (#1A1A1A): 50 높이, 모서리 14, 15/600, gap 10
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    Modifier.weight(1f).height(50.dp).yellowFill(RoundedCornerShape(14.dp)).press(tag = "share.instagram") {
                        scope.launch {
                            val img = image()
                            if (img == null) { Router.ask = Ask("Couldn't save", "Couldn't create the image. Please try again.".l10n, cancel = null); return@launch }
                            if (!ShareDebug.dryRun) shareImage(ctx, img)
                        }
                    },
                    contentAlignment = Alignment.Center,
                ) { T("Share", F.t(15, W600, Color.Black), maxLines = 1) }
                Box(
                    Modifier.weight(1f).height(50.dp).clip(RoundedCornerShape(14.dp)).background(C.btn1A).press(tag = "share.save") {
                        scope.launch {
                            val img = image()
                            val ok = img != null && (ShareDebug.dryRun || saveImage(ctx, img))
                            if (!ok) {
                                Router.ask = Ask("Couldn't save", (if (img == null) "Couldn't create the image. Please try again." else "Couldn't save to Photos. Please try again.").l10n, cancel = null)
                                return@launch
                            }
                            saved = true
                            delay(1600)
                            saved = false
                        }
                    },
                    contentAlignment = Alignment.Center,
                ) { T(if (saved) "Saved" else "Save image", F.t(15, W600), maxLines = 1) }
            }
        }
    }
}

object ShareDemo {
    /** 화면 확인용 예시 사진 (아이폰 --sharephoto) */
    var photo: ImageBitmap? = null
    /** 예시 사진은 컬러로 (아이폰 --sharephoto 처럼 흑백 끔) */
    var colorDemo = false
}

/** 카드를 화면에 보이지 않게 3배 (360 → 1080) 로 그려 layer 에 담아 둠 */
@Composable
internal fun CaptureCard(layer: GraphicsLayer, content: @Composable () -> Unit) {
    Box(Modifier.layout { m, _ ->
        val p = m.measure(Constraints())
        layout(0, 0) { p.place(0, 0) }
    }) {
        CompositionLocalProvider(LocalDensity provides Density(3f, 1f)) {
            Box(Modifier.drawWithContent { layer.record { this@drawWithContent.drawContent() } }) { content() }
        }
    }
}

/** 놓은 자리로 덩어리 옮기기: 위 · 가운데 · 아래 중 가장 가까운 곳. 시간 덩어리는 옆으로 민 만큼 정렬도 바뀜 */
fun movedLayout(l: PosterLayout, key: String, start: Rect, off: Offset, cardH: Float): PosterLayout {
    val fy = (start.center.y + off.y) / cardH
    fun third(f: Float) = if (f < 0.36f) 0 else if (f < 0.64f) 1 else 2
    return when (key) {
        "head" -> l.copy(head = if (fy < 0.5f) 0 else 2)
        "table" -> l.copy(table = third(fy))
        else -> {
            val step = when {
                off.x > 130 -> 2; off.x > 44 -> 1; off.x < -130 -> -2; off.x < -44 -> -1; else -> 0
            }
            l.copy(time = third(fy), timeAlign = (l.timeAlign + step).coerceIn(0, 2))
        }
    }
}

/** 미리보기 아래 한 줄: 끌어서 옮길 수 있다는 안내 + (옮겼으면) 되돌리기 */
@Composable
private fun MoveHint(moved: Boolean, reset: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 0.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        T("Press and hold the time, splits or logo to move it", F.t(12, color = C.text3), Modifier.weight(1f, fill = false), maxLines = 1)
        if (moved) {
            Spacer(Modifier.width(10.dp))
            Box(Modifier.heightIn(min = 28.dp).tap(onClick = reset).testTag("share.resetLayout"), contentAlignment = Alignment.Center) {
                T("Reset", F.t(12, W600, C.accent), maxLines = 1)
            }
        }
    }
}

/** Poster · Ticket · Block (38 높이, 모서리 10, #111, 고른 것 1.5 노랑 테두리 + 노란 글자) */
@Composable
private fun VariantButtons(selected: String, onPick: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for ((k, l) in listOf("poster" to "Poster", "ticket" to "Ticket", "block" to "Block")) {
            val on = selected == k
            val shape = RoundedCornerShape(10.dp)
            Box(
                Modifier.weight(1f).height(38.dp).clip(shape).background(Color(0xFF111111))
                    .border(if (on) 1.5.dp else 1.dp, if (on) C.accent else Color(0xFF1C1C1C), shape).tap { onPick(k) }.testTag(l),
                contentAlignment = Alignment.Center,
            ) { T(l, F.t(13, W600, if (on) C.accent else C.aeb), maxLines = 1) }
        }
    }
}

@Composable
private fun OptionRow(label: String, trailing: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().rowLine(true).heightIn(min = 48.dp).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        T(label, F.t(15), Modifier.weight(1f), maxLines = 1)
        trailing()
    }
}

/** White / Black · Off / Light / Heavy (트랙 #141414 모서리 9 안쪽 2, 칸 ×28 모서리 7, 13/600, 고른 칸 흰 0.16) */
@Composable
private fun MiniSeg(items: List<Pair<String, String>>, selected: String, w: Int, tag: String, onPick: (String) -> Unit) {
    Row(Modifier.clip(RoundedCornerShape(9.dp)).background(Color(0xFF141414)).padding(2.dp)) {
        for ((k, l) in items) {
            val on = selected == k
            Box(
                Modifier.size(w.dp, 28.dp).clip(RoundedCornerShape(7.dp)).background(if (on) Color.White.copy(alpha = 0.16f) else Color.Transparent)
                    .tap { onPick(k) }.testTag("$tag.$k"),
                contentAlignment = Alignment.Center,
            ) { T(l, F.t(13, W600), maxLines = 1) }
        }
    }
}

// MARK: 그림 만들기 · 저장 · 공유

/** 고른 사진이 너무 크면 줄임 (긴 쪽 2160) — 메모리 */
private fun shrink(b: Bitmap): Bitmap {
    val long = max(b.width, b.height)
    if (long <= 2160) return b
    val k = 2160f / long
    return Bitmap.createScaledBitmap(b, (b.width * k).toInt(), (b.height * k).toInt(), true)
}

/** 실외 러닝 경로를 배경 그림으로 (지도 없이 어두운 바탕 + 노란 경로). 1080 너비 */
fun routeImage(route: List<RoutePt>, h: Int): Bitmap {
    val w = 1080
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val c = android.graphics.Canvas(bmp)
    c.drawColor(0xFF1B1C1E.toInt())
    val grid = android.graphics.Paint().apply { color = 0x09FFFFFF }
    var x = 0f
    while (x < w) { c.drawRect(x, 0f, x + 2, h.toFloat(), grid); x += 84f }
    var y = 0f
    while (y < h) { c.drawRect(0f, y, w.toFloat(), y + 2, grid); y += 84f }
    val lat0 = route.first().a
    val kx = cos(Math.toRadians(lat0))
    val xs = route.map { it.o * kx }
    val ys = route.map { it.a }
    val spanX = max(1e-6, xs.max() - xs.min())
    val spanY = max(1e-6, ys.max() - ys.min())
    val s = min(w * 0.6 / spanX, h * 0.6 / spanY)
    val cx = (xs.min() + xs.max()) / 2
    val cy = (ys.min() + ys.max()) / 2
    val path = android.graphics.Path()
    route.indices.forEach { i ->
        val px = (w / 2 + (xs[i] - cx) * s).toFloat()
        val py = (h / 2 - (ys[i] - cy) * s).toFloat()
        if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
    }
    val p = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFFFE600.toInt(); style = android.graphics.Paint.Style.STROKE; strokeWidth = max(6f, w / 120f)
        strokeCap = android.graphics.Paint.Cap.ROUND; strokeJoin = android.graphics.Paint.Join.ROUND
    }
    c.drawPath(path, p)
    return bmp
}

private val fileTime: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss")

/** 사진(갤러리)의 Pictures/SPLITS8 에 PNG 로 저장. Android 10 이상은 권한 필요 없음 */
fun saveImage(ctx: Context, bmp: Bitmap): Boolean = runCatching {
    val name = "SPLITS8-" + java.time.LocalDateTime.now().format(fileTime) + ".png"
    val v = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, name)
        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/SPLITS8")
        put(MediaStore.Images.Media.IS_PENDING, 1)
    }
    val cr = ctx.contentResolver
    val uri = cr.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, v) ?: return false
    val ok = cr.openOutputStream(uri)?.use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) } ?: false
    if (!ok) { cr.delete(uri, null, null); return false }
    v.clear(); v.put(MediaStore.Images.Media.IS_PENDING, 0)
    cr.update(uri, v, null, null)
    true
}.getOrDefault(false)

/** 안드로이드 공유 창 (인스타그램 · 카카오톡 등) */
fun shareImage(ctx: Context, bmp: Bitmap, text: String? = null) {
    runCatching {
        val dir = File(ctx.cacheDir, "share").apply { mkdirs() }
        val f = File(dir, "SPLITS8.png")
        f.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text != null) putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        ctx.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
