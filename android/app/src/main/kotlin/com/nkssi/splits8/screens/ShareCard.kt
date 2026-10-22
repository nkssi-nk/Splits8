package com.nkssi.splits8.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PointMode
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.nkssi.splits8.R
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Units
import com.nkssi.splits8.shared.runDistance
import com.nkssi.splits8.shared.mainSegs
import com.nkssi.splits8.ui.Ambient
import com.nkssi.splits8.ui.AmbientLayer
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.Wordmark
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

// 공유 그림 (아이폰 ShareViews.swift 의 ShareCard). 시안 크기 360 × 640 (Story) / 360 × 450 (Post).
// 저장할 때는 3배 (1080 너비) 로 그림. 카드 안 글자는 아이폰처럼 영어 시안 그대로 (앱 언어와 상관없이)

// MARK: 카드에 들어갈 값

data class SharePair(val no: String, val icon: String, val sn: String, val rt: String, val st: String, val spec: String = "")
data class SharePart(val t: Int, val run: Boolean, val icon: String)

data class ShareData(
    val badge: String = "", val place: String = "", val divName: String = "", val date: String = "",
    val total: String = "", val avgHR: String = "", val rox: String = "", val hasRox: Boolean = true,
    val kcal: String = "", val vsWord: String = "", val vsValue: String = "", val pb: Boolean = false,
    val pairs: List<SharePair> = emptyList(), val seq: List<SharePart> = emptyList(),
    val runTotal: String = "", val stationTotal: String = "", val partner: String = "",
    /** 빌드 27: 러닝 기록은 "5K PB" 처럼 거리까지 */
    val pbText: String = "PB",
    /** 85번(빌드 28): 러닝 카드 기록 — 총거리 · 총시간 · 평균 페이스 3개만 크게 (구간 표 없음) */
    val isRun: Boolean = false, val distance: String = "", val avgPace: String = "",
) {
    /** "with @jiho" · 파트너 없으면 "" */
    val partnerText: String get() = if (partner.isEmpty()) "" else "with @$partner"

    companion object {
        /** 13 Sep 2026 — 공유 카드 전용 (영어 고정) */
        private val cardDate: DateTimeFormatter = DateTimeFormatter.ofPattern("d MMM yyyy", Locale.US)

        fun short(n: String): String = if (n == "Farmers Carry") "Farmers" else n

        /** 스테이션 이름 옆 사양: "50M · 152KG" · "1K" · "100 REPS · 6KG". 사양이 아닌 말(INTERVAL 등)은 뺌 */
        fun spec(detail: String): String {
            val skip = setOf("INTERVAL", "TRANSITION", "Transition", "Interval", "")
            return detail.split(" · ").map { it.trim() }
                .filter { it.uppercase() !in skip && it.lowercase() != "shared" }
                .take(2).joinToString(" · ")
        }

        fun kcalText(k: Int): String = if (k <= 0) "--" else String.format(Locale.US, "%,d", k)

        fun of(r: Record): ShareData {
            val div = Division.of(r.division)
            val (word, v) = Store.book.vs(r)
            val runs = r.runs
            val sts = r.segs.filter { it.kind == SegKind.St }
            val imp = Store.settings.imperial      // 빌드 27: 무게를 lb 로 (설정 > Units)
            val run = r.isRunKind
            return ShareData(
                badge = "${r.mode.title} · ${div.name}", place = r.title, divName = div.name,
                date = r.date.atZone(Fm.zone).format(cardDate), total = Fm.t(r.total),
                avgHR = if (r.avgHR > 0) "${r.avgHR}" else "--", rox = Fm.t(r.roxTotal), hasRox = r.roxTotal > 0,
                kcal = kcalText(r.kcal), vsWord = word, vsValue = v?.let { Fm.d(it) } ?: "--:--", pb = Store.book.isPB(r),
                pairs = (0 until max(runs.size, sts.size)).map { i ->
                    SharePair(
                        String.format(Locale.US, "%02d", i + 1),
                        if (i < sts.size) sts[i].icon else "run",
                        if (i < sts.size) short(sts[i].name) else "",
                        if (i < runs.size) Fm.t(runs[i].time) else "",
                        if (i < sts.size) Fm.t(sts[i].time) else "",
                        if (i < sts.size) spec(Units.detail(sts[i].detail, imp)) else "",
                    )
                }.takeIf { !run } ?: emptyList(),
                seq = if (run) emptyList() else r.mainSegs.map { SharePart(it.time, it.kind == SegKind.Run, it.icon) },
                runTotal = Fm.t(r.runTotal), stationTotal = Fm.t(r.stationTotal),
                partner = (r.partner ?: "").trim(),
                pbText = Store.book.runPBLabel(r) ?: "PB",
                isRun = run,
                distance = if (run) Units.dist(r.runDistance, imp) + " " + Units.distUnit(imp) else "",
                avgPace = if (run) (r.runPace?.let { Fm.t(Units.pace(it, imp)) } ?: "--:--") + " " + Units.paceUnit(imp) else "",
            )
        }
    }
}

/** Poster 글자 덩어리 자리. 미리보기에서 끌어서 옮기면 가장 가까운 자리에 붙음 */
data class PosterLayout(
    /** 로고 · 닉네임 줄: 0 위 / 2 아래 */
    val head: Int = 0,
    /** 장소 · 큰 시간 · 숫자: 0 위 / 1 가운데 / 2 아래 */
    val time: Int = 2,
    /** 그 덩어리의 정렬: 0 왼쪽 / 1 가운데 / 2 오른쪽 */
    val timeAlign: Int = 0,
    /** 구간 표: 0 위 / 1 가운데 / 2 아래 */
    val table: Int = 2,
)

/** 카드 모양 옵션 (공유 화면에서 고른 것) */
data class ShareOpts(
    val variant: String = "poster",          // poster / ticket / block
    val ratio: String = "story",             // story / post
    val showSplits: Boolean = true,
    val photo: ImageBitmap? = null,
    val placeholder: Boolean = false,
    val textBlack: Boolean = false,
    val mono: Boolean = false,
    val gradient: Boolean = true,
    /** "" 이면 닉네임 숨김 (@ 없이) */
    val nick: String = "",
    /** Haze: 0 끔 · 0.6 옅게 · 1 짙게 */
    val smoke: Double = 0.0,
    val layout: PosterLayout = PosterLayout(),
    val dragKey: String? = null,
    /** 끄는 중인 덩어리가 옮겨진 거리 (카드 dp) */
    val dragOffset: Offset = Offset.Zero,
    val glow: GlowTheme = GlowTheme.Yellow,
) {
    val post: Boolean get() = ratio == "post"
    val h: Float get() = if (post) 450f else 640f
}

// MARK: 항상 같은 모양이 나오는 난수 (미리보기와 저장한 그림이 같아야 함)

class SeededRandom(seed: Long) {
    private var state: Long = if (seed == 0L) -0x61c8864680b583ebL else seed
    fun next(): Long {
        state += -0x61c8864680b583ebL
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L
        return z xor (z ushr 31)
    }
    /** 0…1 */
    fun unit(): Double = (next() ushr 11).toDouble() / (1L shl 53).toDouble()
}

// MARK: 사진 효과 (흑백 · 대비 · 채도)

fun photoFilter(saturation: Float, contrast: Float): ColorFilter? {
    if (saturation == 1f && contrast == 1f) return null
    val m = ColorMatrix().apply { setToSaturation(saturation) }
    val t = (1 - contrast) * 0.5f * 255f
    m.timesAssign(ColorMatrix(floatArrayOf(contrast, 0f, 0f, 0f, t, 0f, contrast, 0f, 0f, t, 0f, 0f, contrast, 0f, t, 0f, 0f, 0f, 1f, 0f)))
    return ColorFilter.colorMatrix(m)
}

/**
 * 흐린 유리판 뒤에 깔 흐린 사진 (backdrop blur 18 대신): 카드 크기로 채운 사진을 아주 작게 줄여 상자 흐림을 세 번.
 * 어느 기기에서나 같은 그림이 나옴
 */
fun blurredCover(src: ImageBitmap, cardW: Float, cardH: Float): ImageBitmap {
    val b = src.asAndroidBitmap()
    val w = 45
    val h = max(1, (w * cardH / cardW).toInt())
    // 채우기(가운데 자르기)
    val scale = max(w.toFloat() / b.width, h.toFloat() / b.height)
    val sw = (w / scale).toInt().coerceIn(1, b.width)
    val sh = (h / scale).toInt().coerceIn(1, b.height)
    val crop = android.graphics.Bitmap.createBitmap(b, (b.width - sw) / 2, (b.height - sh) / 2, sw, sh)
    val small = android.graphics.Bitmap.createScaledBitmap(crop, w, h, true)
        .copy(android.graphics.Bitmap.Config.ARGB_8888, true)
    val px = IntArray(w * h)
    small.getPixels(px, 0, w, 0, 0, w, h)
    repeat(3) { boxBlur(px, w, h, 2) }
    small.setPixels(px, 0, w, 0, 0, w, h)
    return small.asImageBitmap()
}

private fun boxBlur(px: IntArray, w: Int, h: Int, r: Int) {
    val tmp = IntArray(px.size)
    fun pass(src: IntArray, dst: IntArray, horizontal: Boolean) {
        val n = if (horizontal) w else h
        val lines = if (horizontal) h else w
        for (l in 0 until lines) {
            for (i in 0 until n) {
                var a = 0; var rr = 0; var g = 0; var bb = 0; var c = 0
                for (k in -r..r) {
                    val j = (i + k).coerceIn(0, n - 1)
                    val p = if (horizontal) src[l * w + j] else src[j * w + l]
                    a += p ushr 24 and 0xFF; rr += p shr 16 and 0xFF; g += p shr 8 and 0xFF; bb += p and 0xFF; c++
                }
                val v = (a / c shl 24) or (rr / c shl 16) or (g / c shl 8) or (bb / c)
                if (horizontal) dst[l * w + i] = v else dst[i * w + l] = v
            }
        }
    }
    pass(px, tmp, true)
    pass(tmp, px, false)
}

// MARK: 글자 (자리가 모자라면 작아짐 — 아이폰 minimumScaleFactor)

@Composable
fun FitText(text: String, style: TextStyle, modifier: Modifier = Modifier, minScale: Float = 0.5f) {
    BoxWithConstraints(modifier) {
        val m = rememberTextMeasurer()
        val maxW = constraints.maxWidth
        val k = remember(text, style, maxW) {
            if (maxW == androidx.compose.ui.unit.Constraints.Infinity) 1f else {
                var s = 1f
                while (s > minScale && m.measure(text, style.copy(fontSize = style.fontSize * s), softWrap = false, maxLines = 1).size.width > maxW) s -= 0.03f
                max(s, minScale)
            }
        }
        BasicText(text, style = style.copy(fontSize = style.fontSize * k), maxLines = 1, softWrap = false)
    }
}

// MARK: 카드

@Composable
fun ShareCard(d: ShareData, o: ShareOpts, modifier: Modifier = Modifier, onRects: ((Map<String, Rect>) -> Unit)? = null) {
    val density = LocalDensity.current
    var root by remember { mutableStateOf<LayoutCoordinates?>(null) }
    // 글자 덩어리 자리 (카드 dp 좌표) — 헤이즈 띠 · 끌어서 옮기기에 씀
    val rects = remember { mutableStateMapOf<String, Rect>() }
    val cardBg = if (o.textBlack && o.variant == "poster") Color.White else Color.Black
    Box(
        modifier.size(360.dp, o.h.dp).clipToBounds().background(cardBg).onGloballyPositioned { root = it },
    ) {
        val track: (String) -> Modifier = { key ->
            Modifier.onGloballyPositioned { c ->
                val r = root ?: return@onGloballyPositioned
                if (!r.isAttached || !c.isAttached) return@onGloballyPositioned
                val p = r.localPositionOf(c, Offset.Zero)
                val rect = with(density) { Rect(p.x.toDp().value, p.y.toDp().value, (p.x + c.size.width).toDp().value, (p.y + c.size.height).toDp().value) }
                // 끄는 중인 덩어리는 옮겨진 자리 말고 원래 자리로 둠
                if (o.dragKey == key) return@onGloballyPositioned
                if (rects[key] != rect) {
                    rects[key] = rect
                    onRects?.invoke(rects.toMap())
                }
            }
        }
        val card = CardScope(d, o, rects, track)
        when (o.variant) {
            "ticket" -> card.Ticket()
            "block" -> card.Block()
            else -> card.Poster()
        }
    }
}

/** 카드 그리기 도구 모음 (아이폰 ShareCard 의 함수들) */
private class CardScope(val d: ShareData, val o: ShareOpts, val rects: Map<String, Rect>, val track: (String) -> Modifier) {
    val post = o.post
    val h = o.h
    val hasNick = o.nick.isNotEmpty()
    val nickText = "@" + o.nick
    val smokeOn = o.smoke > 0
    val tb = o.textBlack

    // 글자색 (시안 tc / acc / tcLine / pillBg)
    val tc = if (tb) Color.Black else Color.White
    val acc = if (tb) Color.Black else C.accent
    val tcLine = if (tb) Color.Black.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.16f)
    val pillBg = if (tb) Color.White.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.07f)

    // MARK: 공통

    /** SPLITS8 워드마크 20. 검은 글자 모드여도 8 은 항상 노랑 */
    @Composable
    fun Mark(black: Boolean) {
        Wordmark(20f, black = black)
    }

    /** 빛 radial-gradient. themed = Block · Ticket (고른 색), Poster 는 항상 노랑 */
    @Composable
    fun Glow(a: Double, rx: Float, ry: Float, cx: Float, cy: Float, themed: Boolean = false) {
        val hex = if (themed) o.glow.hex else 0xFFE600L
        val alpha = if (themed) min(1.0, a * o.glow.gain) else a
        AmbientLayer(Ambient(hex, alpha.toFloat(), rx, ry, cx, cy), Modifier.fillMaxSize())
    }

    @Composable
    fun PhotoView(filter: ColorFilter?) {
        val p = o.photo
        if (p != null) {
            Image(p, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop, colorFilter = filter)
        } else {
            // 1.1.2: "탭해서 사진 고르기" 를 가운데보다 위로 (가운데면 Poster 의 날짜 · 큰 시간과 겹쳤음). 미리보기에만 보이고 저장 그림에는 없음
            Box(Modifier.fillMaxSize().background(Color(0xFF0B0B0B)), contentAlignment = androidx.compose.ui.BiasAlignment(0f, -0.5f)) {
                if (o.placeholder) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Glyph("i_camera", 26.dp, C.text2)
                        T("Tap to choose a photo", F.t(13, W500, C.text2), maxLines = 1)
                    }
                }
            }
        }
    }

    /** Black & white photo: grayscale(1) contrast(1.05) */
    val baseFilter: ColorFilter? get() = if (o.mono) photoFilter(0f, 1.05f) else null

    /** 큰 시간 (line-height 0.95, 한 줄, 자리가 모자라면 작아짐) */
    @Composable
    fun Big(s: String, size: Float, track: Float, color: Color = Color.White, modifier: Modifier = Modifier) {
        FitText(s, F.num(size, W600, color, tracking = track * size),
            modifier.height((size * 0.95f).dp).wrapContentHeight(Alignment.CenterVertically, unbounded = true))
    }

    /** 8 / 600, 자간 0.12em */
    @Composable
    fun Tiny(s: String, color: Color, modifier: Modifier = Modifier) {
        T(s, F.t(8, W600, color, tracking = 0.96f), modifier, maxLines = 1, translate = false)
    }

    /** ★ PB 알약 (22 높이, 11 / 600, 별 10) */
    @Composable
    fun PbPill(fill: Color, ring: Color, fg: Color) {
        Row(
            Modifier.height(22.dp).clip(RoundedCornerShape(50)).background(fill).border(1.dp, ring, RoundedCornerShape(50))
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Sym(R.drawable.sym_star, 10.dp, fg)
            T(d.pbText, F.t(11, W600, fg), maxLines = 1, translate = false)
        }
    }

    @Composable
    fun YellowPB() = PbPill(C.accent.copy(alpha = 0.14f), C.accent.copy(alpha = 0.5f), C.accent)

    /** 스테이션 이름 + 옆에 작은 사양 (50M · 152KG). 사양도 이름과 같은 색 */
    @Composable
    fun NameCell(p: SharePair, size: Float, color: Color, modifier: Modifier) {
        Row(modifier, verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            T(p.sn, F.t(size, W500, color), maxLines = 1, translate = false)
            if (p.spec.isNotEmpty()) FitText(p.spec, F.num(max(8f, size - 3.5f), W500, color), Modifier.weight(1f, fill = false), minScale = 0.75f)
        }
    }

    // MARK: Poster

    /** 그 자리(0 위 · 1 가운데 · 2 아래)에 글자 덩어리가 있는지 */
    fun occupied(v: Int): Boolean = o.layout.head == v || o.layout.time == v || (o.showSplits && d.pairs.isNotEmpty() && o.layout.table == v)

    /** Poster 표의 줄 높이: Story 8줄이면 28, Post 8줄이면 19. 줄이 많으면 남는 높이를 나눠 씀 */
    val tableRowH: Float get() {
        val n = max(1, d.pairs.size).toFloat()
        val room = if (post) 164f else 343f
        val fit = kotlin.math.floor(room / n)
        return if (post) min(19f, max(10f, fit)) else min(28f, max(14f, fit))
    }
    val tableFont: Float get() = if (post) min(10f, max(7f, tableRowH * 0.53f)) else min(13f, max(8f, tableRowH * 0.48f))

    /** Story 에서 아래 자리의 표가 204pt 보다 커진 만큼 (카드 높이에 대한 비율) */
    val tableGrow: Double get() {
        if (post || !o.showSplits || d.pairs.isEmpty() || o.layout.table != 2) return 0.0
        val tableH = d.pairs.size * tableRowH + 20
        return (max(0f, tableH - 204) / 640f).toDouble()
    }

    /** 검은 글자 = 흰 스크림, 흰 글자 = 검은 스크림. 글자가 있는 자리만 어둡게(밝게). 부드러운 곡선으로만 이어 붙임 */
    fun scrimAlpha(y: Double): Double {
        fun ease(t: Double): Double { val u = t.coerceIn(0.0, 1.0); return u * u * (3 - 2 * u) }
        val topA = if (occupied(0)) (if (tb) 0.45 else 0.5) else 0.0
        val mid = occupied(1)
        val bot = occupied(2)
        val a = topA * (1 - ease(y / 0.22))
        var m = if (mid) 0.62 * ease((y - 0.16) / 0.16) else 0.0
        if (mid && !bot) m *= 1 - ease((y - 0.62) / 0.18)
        if (bot) {
            val g = tableGrow
            val b0 = if (mid) max(0.40, 0.60 - g) else (if (post) 0.22 else max(0.04, 0.30 - g))
            val b1 = if (mid) max(0.58, 0.78 - g) else (if (post) 0.60 else max(0.42, 0.74 - g))
            m += (1 - m) * ease((y - b0) / (b1 - b0))
        }
        return max(a, m)
    }

    /** 그라데이션일 때 아래에 글자가 있으면 사진은 위쪽만 (아래는 단색), 아니면 사진이 전체 */
    val posterPhotoH: Float get() {
        if (smokeOn || !o.gradient || !occupied(2)) return h
        if (occupied(1)) return h * 0.80f
        return h * (if (post) 0.62f else max(0.44, 0.76 - tableGrow).toFloat())
    }

    @Composable
    fun Poster() {
        val glowA = if (tb) 0.45 else 0.30
        val glowB = if (tb) 0.22 else 0.12
        Box(Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxWidth().height(posterPhotoH.dp).clipToBounds()) {
                // 연기를 켜면 사진을 영화처럼 조금 눌러 줌 (채도 ↓ · 대비 ↑)
                PhotoView(if (smokeOn) photoFilter(if (o.mono) 0f else 0.86f, if (o.mono) 1.05f * 1.08f else 1.08f) else baseFilter)
            }
            if (smokeOn) {
                SmokeHaze(o.smoke, Modifier.fillMaxSize())
                if (!tb) {
                    Canvas(Modifier.fillMaxSize()) {
                        drawRect(Brush.radialGradient(0.45f to Color.Transparent, 1f to Color.Black.copy(alpha = (0.42 * o.smoke).toFloat()),
                            center = center, radius = size.height * 0.72f))
                    }
                }
                FilmGrain(0.05 * o.smoke, Modifier.fillMaxSize())
            } else {
                if (o.gradient) {
                    val c = if (tb) Color.White else Color.Black
                    val stops = (0..32).map { i -> val y = i / 32.0; y.toFloat() to c.copy(alpha = scrimAlpha(y).toFloat()) }.toTypedArray()
                    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(*stops)))
                    // 아주 옅은 입자: 어두운 그라데이션에 계단 같은 줄이 생기지 않게
                    FilmGrain(0.02, Modifier.fillMaxSize())
                }
                Glow(glowA, 0.9f, 0.45f, 0.85f, 1.0f)
                Glow(glowB, 0.7f, 0.35f, 0f, 0.6f)
            }
            // 연기는 글자 덩어리 뒤에 더 짙게 모임 (덩어리를 옮기면 따라감)
            if (smokeOn) HazeBands()
            Column(Modifier.fillMaxSize().padding(top = 22.dp, start = 22.dp, end = 22.dp, bottom = 24.dp)) {
                Slot(0)
                Spacer(Modifier.weight(1f).heightIn(min = 10.dp))
                Slot(1)
                Spacer(Modifier.weight(1f).heightIn(min = 10.dp))
                Slot(2)
            }
        }
    }

    @Composable
    fun Slot(v: Int) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (o.layout.head == v) PosterBlock("head") { PosterHeader() }
            if (o.layout.time == v) PosterBlock("time") { PosterTime() }
            if (o.showSplits && d.pairs.isNotEmpty() && o.layout.table == v) PosterBlock("table") { PosterTableBox() }
        }
    }

    /** 옮길 수 있는 덩어리: 자리를 알리고, 끄는 동안은 손가락을 따라 움직임 */
    @Composable
    fun PosterBlock(key: String, content: @Composable () -> Unit) {
        val lifted = o.dragKey == key
        Box(
            track(key).zIndex(if (lifted) 1f else 0f)
                .offset(if (lifted) o.dragOffset.x.dp else 0.dp, if (lifted) o.dragOffset.y.dp else 0.dp)
                .graphicsLayer { val s = if (lifted) 1.03f else 1f; scaleX = s; scaleY = s; alpha = if (lifted) 0.85f else 1f }
                .testTag("share.block.$key"),
        ) { content() }
    }

    @Composable
    fun PosterHeader() {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Mark(tb)
                if (hasNick) T(nickText, textShadow(F.t(12, W600, tc)), maxLines = 1, translate = false)
            }
            Spacer(Modifier.weight(1f).width(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                if (d.pb) PbPill(pillBg, tcLine, acc)
                Box(Modifier.clip(RoundedCornerShape(50)).background(pillBg).border(1.dp, tcLine, RoundedCornerShape(50))
                    .padding(vertical = 5.dp, horizontal = 10.dp)) {
                    T(d.badge, F.t(11, W600, acc), maxLines = 1, translate = false)
                }
            }
        }
    }

    /** 연기 위에서는 글자에 옅은 그림자 */
    fun textShadow(s: TextStyle): TextStyle =
        if (!smokeOn) s else s.copy(shadow = Shadow((if (tb) Color.White else Color.Black).copy(alpha = 0.5f), Offset(0f, 1f), 3f))

    /** 장소·날짜 / 큰 시간 / 숫자 3개. 왼쪽 · 가운데 · 오른쪽 정렬 */
    @Composable
    fun PosterTime() {
        val i = o.layout.timeAlign.coerceIn(0, 2)
        val ha = listOf(Alignment.Start, Alignment.CenterHorizontally, Alignment.End)[i]
        Column(Modifier.fillMaxWidth(), horizontalAlignment = ha) {
            T("${d.place} · ${d.date}", textShadow(F.t(13, W500, tc)), maxLines = 1, translate = false)
            if (d.partner.isNotEmpty()) T(d.partnerText, textShadow(F.t(12, W500, tc.copy(alpha = 0.75f))), Modifier.padding(top = 2.dp), maxLines = 1, translate = false)
            Big(if (d.isRun) d.distance else d.total, if (post) 64f else 76f, -0.045f, tc, Modifier.padding(top = 6.dp))
            Row(Modifier.padding(top = 14.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (d.isRun) {
                    PosterStat("TIME", d.total, ha, 26)
                    PosterStat("AVG PACE", d.avgPace, ha, 26)
                } else {
                    PosterStat("AVG HR", d.avgHR, ha)
                    if (d.hasRox) PosterStat("ROXZONE", d.rox, ha)
                    PosterStat("KCAL", d.kcal, ha)
                }
            }
        }
    }

    @Composable
    fun androidx.compose.foundation.layout.RowScope.PosterStat(label: String, value: String, ha: Alignment.Horizontal, size: Int = 18) {
        Column(Modifier.weight(1f), horizontalAlignment = ha) {
            Tiny(label, tc)
            FitText(value, textShadow(F.num(size, W600, tc, tracking = -0.01f * size)), minScale = 0.7f)
        }
    }

    /** 그라데이션 위(아래 자리)나 연기 위에서는 표만, 사진 바로 위에서는 흐린 유리판 (padding 6 12 4, radius 16) */
    @Composable
    fun PosterTableBox() {
        if (smokeOn || (o.gradient && o.layout.table == 2)) {
            PosterTable()
        } else {
            val shape = RoundedCornerShape(16.dp)
            val tint = if (tb) Color.White.copy(alpha = 0.62f) else Color.Black.copy(alpha = 0.48f)
            val ring = if (tb) Color.Black.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.14f)
            Box(Modifier.clip(shape).border(1.dp, ring, shape)) {
                PanelBackdrop(Modifier.matchParentSize(), tint)
                Box(Modifier.padding(top = 6.dp, start = 12.dp, end = 12.dp, bottom = 4.dp)) { PosterTable() }
            }
        }
    }

    /** 같은 사진을 흐리게 해서 판 위치만큼 옮겨 깔고, 그 위에 색을 덮음 */
    @Composable
    fun PanelBackdrop(modifier: Modifier, tint: Color) {
        val p = o.photo
        val blurred = remember(p, h) { p?.let { blurredCover(it, 360f, h) } }
        val me = rects["table"]
        Canvas(modifier) {
            if (blurred != null && me != null) {
                val sat = if (o.mono) photoFilter(0f, 1.05f) else photoFilter(1.4f, 1f)
                drawImage(blurred, srcOffset = androidx.compose.ui.unit.IntOffset.Zero,
                    srcSize = androidx.compose.ui.unit.IntSize(blurred.width, blurred.height),
                    dstOffset = androidx.compose.ui.unit.IntOffset((-me.left.dp.toPx()).toInt(), (-me.top.dp.toPx()).toInt()),
                    dstSize = androidx.compose.ui.unit.IntSize(360.dp.roundToPx(), h.dp.roundToPx()),
                    colorFilter = sat, filterQuality = androidx.compose.ui.graphics.FilterQuality.High)
            } else if (blurred == null) {
                drawRect(Color(0xFF0B0B0B))
            }
            drawRect(tint)
        }
    }

    // 아이콘 18 | "1. 이름" | (빈칸) | 사양 | RUN | STN, column-gap 8
    @Composable
    fun PosterTable() {
        val rowH = tableRowH
        val size = tableFont
        val numW = if (size > 11.5f) 44.dp else 40.dp
        Column {
            Row(Modifier.fillMaxWidth().bottomLine(tcLine).padding(bottom = 6.dp), verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Spacer(Modifier.width(18.dp))
                Tiny("STATION", tc, Modifier.weight(1f))
                Box(Modifier.width(numW), contentAlignment = Alignment.CenterEnd) { Tiny("RUN", tc) }
                Box(Modifier.width(numW), contentAlignment = Alignment.CenterEnd) { Tiny("STN", tc) }
            }
            d.pairs.forEachIndexed { i, p ->
                val line = if (tb) Color.Black.copy(alpha = 0.10f) else Color.White.copy(alpha = 0.07f)
                val name = p.sn.ifEmpty { "Run" }
                val icon = max(8f, min(17f, min(size + 4, rowH - 3)))
                Row(
                    Modifier.fillMaxWidth().height(rowH.dp).then(if (i < d.pairs.size - 1) Modifier.bottomLine(line) else Modifier),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(Modifier.width(18.dp), contentAlignment = Alignment.Center) { Icon8(p.icon, icon.dp, acc) }
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        T("${i + 1}. $name", textShadow(F.t(size, W500, tc)), maxLines = 1, translate = false)
                        // 사양은 남는 자리 오른쪽 끝에 (모자랄 때만 작아짐)
                        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
                            if (p.spec.isNotEmpty()) FitText(p.spec, textShadow(F.num(max(8f, size - 3.5f), W500, tc)), minScale = 0.7f)
                        }
                    }
                    Box(Modifier.width(numW), contentAlignment = Alignment.CenterEnd) { FitText(p.rt, textShadow(F.num(size, W500, tc)), minScale = 0.8f) }
                    Box(Modifier.width(numW), contentAlignment = Alignment.CenterEnd) { FitText(p.st, textShadow(F.num(size, W600, tc)), minScale = 0.8f) }
                }
            }
        }
    }

    /** 헤이즈 띠들: 같은 자리(0 위 · 1 가운데 · 2 아래)의 글자 덩어리를 한 띠로 묶고, 위아래로 멀리(카드 높이의 28%) 옅게 퍼짐 */
    @Composable
    fun HazeBands() {
        Canvas(Modifier.fillMaxSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            for (slot in 0..2) {
                val keys = buildList {
                    if (o.layout.head == slot) add("head")
                    if (o.layout.time == slot) add("time")
                    if (o.layout.table == slot) add("table")
                }.filter { rects[it] != null }
                val rs = keys.mapNotNull { rects[it] }
                if (rs.isEmpty()) continue
                val u = rs.drop(1).fold(rs[0]) { a, b -> Rect(min(a.left, b.left), min(a.top, b.top), max(a.right, b.right), max(a.bottom, b.bottom)) }
                val onlyHead = keys == listOf("head")
                val ext = h * (if (onlyHead) 0.10f else 0.28f)
                val top = if (slot == 0) -24f else u.top - 10 - ext
                val bottom = if (slot == 2) h + 24 else u.bottom + 10 + ext
                val bh = max(1f, bottom - top)
                smokePuff(
                    dark = !tb, strength = o.smoke * (if (onlyHead) 0.55 else 1.0),
                    topFade = (if (slot == 0) 0f else ext) / bh, bottomFade = (if (slot == 2) 0f else ext) / bh,
                    seed = slot * 977L + 13, left = -30f, top = top, w = 420f, h = bh,
                )
            }
        }
    }

    // MARK: Ticket

    @Composable
    fun Ticket() {
        Box(Modifier.fillMaxSize()) {
            Glow(0.22, 0.9f, 0.4f, 0.5f, 1.0f, themed = true)
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                val topShape = RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = 4.dp, bottomEnd = 4.dp)
                Box(Modifier.fillMaxWidth().weight(1f).clip(topShape)) {
                    PhotoView(baseFilter)
                    Box(Modifier.align(Alignment.TopStart).padding(14.dp)) { Mark(tb) }
                    if (hasNick) {
                        T(nickText, F.t(12, W600, tc).copy(shadow = if (tb) null else Shadow(Color.Black.copy(alpha = 0.5f), Offset(0f, 1f), 3f)),
                            Modifier.align(Alignment.TopEnd).padding(top = 18.dp, end = 14.dp), maxLines = 1, translate = false)
                    }
                }
                TicketCut()
                TicketPanel()
            }
        }
    }

    /** 절취선 (16 높이, 양 끝 검은 원 16, 점선 흰 0.18) */
    @Composable
    fun TicketCut() {
        Canvas(Modifier.fillMaxWidth().height(16.dp)) {
            drawLine(Color.White.copy(alpha = 0.18f), Offset(12.dp.toPx(), 7.5.dp.toPx()), Offset(size.width - 12.dp.toPx(), 7.5.dp.toPx()),
                1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())))
            drawCircle(Color.Black, 8.dp.toPx(), Offset(-16.dp.toPx(), 8.dp.toPx()))
            drawCircle(Color.Black, 8.dp.toPx(), Offset(size.width + 16.dp.toPx(), 8.dp.toPx()))
        }
    }

    @Composable
    fun TicketPanel() {
        val shape = RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp, bottomStart = 18.dp, bottomEnd = 18.dp)
        Box(Modifier.fillMaxWidth().clip(shape).border(1.dp, Color.White.copy(alpha = 0.10f), shape)) {
            Box(Modifier.matchParentSize().background(Color.White.copy(alpha = 0.07f))) { Glow(0.30, 0.9f, 0.9f, 0.9f, 1.1f, themed = true) }
            Column(Modifier.fillMaxWidth().padding(top = 16.dp, start = 18.dp, end = 18.dp, bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                val small = F.t(12, W500, C.text2)
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("${d.place} · ${d.divName}", small, Modifier.weight(1f), maxLines = 1, translate = false)
                        if (d.pb) YellowPB()
                        T(d.date, small, maxLines = 1, translate = false)
                    }
                    if (d.partner.isNotEmpty()) T(d.partnerText, small, maxLines = 1, translate = false)
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    Big(if (d.isRun) d.distance else d.total, if (post) 48f else 56f, -0.04f, modifier = Modifier.weight(1f))
                    Spacer(Modifier.width(8.dp))
                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        T(if (d.isRun) d.avgPace else d.vsValue, F.num(14, W600, C.accent), maxLines = 1, translate = false)
                        T(if (d.isRun) d.total else "${d.avgHR} BPM", F.num(14, W600, if (d.isRun) Color.White else C.text2), maxLines = 1, translate = false)
                    }
                }
                if (o.showSplits && d.seq.isNotEmpty()) {
                    TicketStrip()
                    Row(Modifier.fillMaxWidth()) {
                        val st = F.num(8, W600, C.text3, tracking = 0.8f)
                        T("RUN ${d.runTotal}", st, maxLines = 1, translate = false)
                        Spacer(Modifier.weight(1f).width(4.dp))
                        T("STATIONS ${d.stationTotal}", st, maxLines = 1, translate = false)
                        if (d.hasRox) {
                            Spacer(Modifier.weight(1f).width(4.dp))
                            T("ROX ${d.rox}", st, maxLines = 1, translate = false)
                        }
                    }
                }
            }
        }
    }

    /** 16구간 막대 (러닝 흰 0.18, 스테이션 노랑, gap 2, 위 모서리 2) */
    @Composable
    fun TicketStrip() {
        val mx = max(1, d.seq.maxOf { it.t }).toFloat()
        val stripH = if (post) 32.dp else 56.dp
        Canvas(Modifier.fillMaxWidth().height(stripH)) {
            val gap = 2.dp.toPx()
            val n = d.seq.size
            val bw = (size.width - gap * (n - 1)) / n
            d.seq.forEachIndexed { i, s ->
                val bh = max(2.dp.toPx(), size.height * s.t / mx)
                val x = i * (bw + gap)
                val p = Path().apply {
                    addRoundRect(androidx.compose.ui.geometry.RoundRect(Rect(x, size.height - bh, x + bw, size.height),
                        topLeft = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()), topRight = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx())))
                }
                drawPath(p, if (s.run) Color.White.copy(alpha = 0.18f) else C.accent)
            }
        }
    }

    // MARK: Block (사진 없음 · 글자색 무시)

    @Composable
    fun Block() {
        Box(Modifier.fillMaxSize()) {
            Glow(0.34, 0.9f, 0.55f, 0.85f, 0f, themed = true)
            Glow(0.14, 0.8f, 0.45f, 0f, 1.0f, themed = true)
            Column(Modifier.fillMaxSize().padding(24.dp)) {
                BlockHeader()
                Spacer(Modifier.weight(1f))
                Big(if (d.isRun) d.distance else d.total, if (post) 56f else 76f, -0.045f)
                Row(Modifier.padding(top = 14.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (d.isRun) {
                        BlockTile("TIME", d.total, Color.White)
                        BlockTile("AVG PACE", d.avgPace, C.accent)
                    } else {
                        BlockTile(d.vsWord, d.vsValue, C.accent)
                        BlockTile("AVG HR", d.avgHR, Color.White)
                        if (d.hasRox) BlockTile("ROXZONE", d.rox, Color.White)
                    }
                }
                if (o.showSplits && d.pairs.isNotEmpty()) BlockTable(Modifier.padding(top = if (post) 10.dp else 20.dp))
            }
        }
    }

    @Composable
    fun BlockHeader() {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) {
                Mark(false)
                Row(Modifier.padding(top = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    T(d.badge, F.t(13, W600), maxLines = 1, translate = false)
                    if (d.pb) YellowPB()
                }
                T("${d.place} · ${d.date}", F.t(13, W500, Color.White.copy(alpha = 0.65f)), Modifier.padding(top = 3.dp), maxLines = 1, translate = false)
                if (d.partner.isNotEmpty()) T(d.partnerText, F.t(12, W500, Color.White.copy(alpha = 0.65f)), Modifier.padding(top = 2.dp), maxLines = 1, translate = false)
            }
            if (hasNick) T(nickText, F.t(13, W600, C.accent), Modifier.padding(top = 3.dp), maxLines = 1, translate = false)
        }
    }

    @Composable
    fun androidx.compose.foundation.layout.RowScope.BlockTile(label: String, value: String, color: Color) {
        val shape = RoundedCornerShape(14.dp)
        Column(
            Modifier.weight(1f).clip(shape).background(Color.White.copy(alpha = 0.07f)).border(1.dp, Color.White.copy(alpha = 0.10f), shape)
                .padding(vertical = 10.dp, horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Tiny(label, Color.White.copy(alpha = 0.55f))
            FitText(value, F.num(18, W600, color), minScale = 0.7f)
        }
    }

    // grid 20 | 16 | 1fr | 40 | 44, column-gap 8
    @Composable
    fun BlockTable(modifier: Modifier) {
        val rowH = if (post) 18.dp else 34.dp
        val shape = RoundedCornerShape(16.dp)
        val label = Color.White.copy(alpha = 0.5f)
        Column(modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = 0.07f)).border(1.dp, Color.White.copy(alpha = 0.10f), shape)
            .padding(vertical = 4.dp, horizontal = 12.dp)) {
            Row(Modifier.fillMaxWidth().height(22.dp).bottomLine(Color.White.copy(alpha = 0.10f)), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Spacer(Modifier.width(20.dp)); Spacer(Modifier.width(16.dp))
                Tiny("STATION", label, Modifier.weight(1f))
                Box(Modifier.width(40.dp), contentAlignment = Alignment.CenterEnd) { Tiny("RUN", label) }
                Box(Modifier.width(44.dp), contentAlignment = Alignment.CenterEnd) { Tiny("STN", label) }
            }
            val size = if (post) 11f else 14f
            val num = if (post) 13f else 17f
            d.pairs.forEachIndexed { i, p ->
                Row(Modifier.fillMaxWidth().height(rowH).then(if (i < d.pairs.size - 1) Modifier.bottomLine(Color.White.copy(alpha = 0.07f)) else Modifier),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    T(p.no, F.num(11, W600, C.accent), Modifier.width(20.dp), maxLines = 1, translate = false)
                    Box(Modifier.width(16.dp).graphicsLayer { alpha = 0.9f }, contentAlignment = Alignment.Center) { Icon8(p.icon, 14.dp, Color.White) }
                    NameCell(p, size, Color.White, Modifier.weight(1f))
                    Box(Modifier.width(40.dp), contentAlignment = Alignment.CenterEnd) { T(p.rt, F.num(size, W500, Color.White.copy(alpha = 0.5f)), maxLines = 1, translate = false) }
                    Box(Modifier.width(44.dp), contentAlignment = Alignment.CenterEnd) { FitText(p.st, F.num(num, W600), minScale = 0.8f) }
                }
            }
        }
    }
}

private fun Modifier.bottomLine(c: Color): Modifier = this.drawBehind {
    drawLine(c, Offset(0f, size.height - 0.5f), Offset(size.width, size.height - 0.5f), 1.dp.toPx())
}

// MARK: 연기 · 필름 입자

/**
 * 글자 뒤에 깔리는 헤이즈 띠 (카드 dp 좌표). dark = 어두운 것(흰 글자용) / 밝은 것(검은 글자용).
 * 가로로는 띠 전체를 고르게 덮고, 세로로는 topFade · bottomFade(띠 높이 대비 0~1)만큼 서서히 엷어짐
 */
private fun DrawScope.smokePuff(dark: Boolean, strength: Double, topFade: Float, bottomFade: Float, seed: Long,
                                left: Float, top: Float, w: Float, h: Float) {
    val k = 1.dp.toPx()
    val rng = SeededRandom(seed)
    val color = if (dark) Color.Black else Color.White
    val l = left * k; val t = top * k; val ww = w * k; val hh = h * k
    // 띠 하나를 따로 그린 뒤 위아래 엷어짐을 씌움 (DstIn)
    drawContext.canvas.saveLayer(Rect(l, t, l + ww, t + hh), androidx.compose.ui.graphics.Paint())
    drawRect(color.copy(alpha = (0.58 * strength).toFloat()), Offset(l, t), Size(ww, hh))
    val count = 14 + (w * h / 7000).toInt()
    repeat(count) {
        val x = l + (-0.1 + rng.unit() * 1.2).toFloat() * ww
        val y = t + (-0.05 + rng.unit() * 1.1).toFloat() * hh
        val r = (60 + rng.unit() * 70).toFloat() * k
        val rx = r * (1.2f + rng.unit().toFloat() * 0.9f)
        val a = ((0.12 + rng.unit() * 0.13) * strength).toFloat()
        withTransform({ scale(rx / r, 1f, Offset(x, y)) }) {
            drawCircle(Brush.radialGradient(0f to color.copy(alpha = a), 0.5f to color.copy(alpha = a * 0.55f), 1f to color.copy(alpha = 0f),
                center = Offset(x, y), radius = r), r, Offset(x, y))
        }
    }
    drawRect(Brush.verticalGradient(*fadeStops(topFade, bottomFade), startY = t, endY = t + hh), Offset(l, t), Size(ww, hh), blendMode = BlendMode.DstIn)
    drawContext.canvas.restore()
}

/** 0 → 1 (top 구간) · 1 유지 · 1 → 0 (bottom 구간). 곡선을 1.7제곱해 꼬리가 길고 옅게 */
private fun fadeStops(top: Float, bottom: Float): Array<Pair<Float, Color>> {
    val tt = top.coerceIn(0f, 0.49f)
    val b = bottom.coerceIn(0f, 0.49f)
    val n = 10
    val st = ArrayList<Pair<Float, Color>>()
    if (tt > 0.001f) {
        for (i in 0..n) { val u = i.toDouble() / n; val e = u * u * (3 - 2 * u); st.add(tt * u.toFloat() to Color.Black.copy(alpha = e.pow(1.7).toFloat())) }
    } else st.add(0f to Color.Black)
    if (b > 0.001f) {
        for (i in 0..n) { val u = i.toDouble() / n; val e = 1 - u * u * (3 - 2 * u); st.add(1 - b + b * u.toFloat() to Color.Black.copy(alpha = e.pow(1.7).toFloat())) }
    } else st.add(1f to Color.Black)
    return st.toTypedArray()
}

/** 화면 전체에 깔리는 옅은 안개 결 (밝은 회색) */
@Composable
private fun SmokeHaze(strength: Double, modifier: Modifier) {
    Canvas(modifier) {
        val rng = SeededRandom(41)
        val k = 1.dp.toPx()
        repeat(16) {
            val x = (rng.unit() * size.width).toFloat()
            val y = (rng.unit() * size.height).toFloat()
            val r = ((70 + rng.unit() * 130) * k).toFloat()
            val stretch = (1.6 + rng.unit() * 1.6).toFloat()
            val a = ((0.035 + rng.unit() * 0.06) * strength).toFloat()
            val c = Color(0.92f, 0.92f, 0.92f)
            withTransform({ scale(stretch, 1f, Offset(x, y)) }) {
                drawCircle(Brush.radialGradient(0f to c.copy(alpha = a), 1f to c.copy(alpha = 0f), center = Offset(x, y), radius = r), r, Offset(x, y))
            }
        }
    }
}

/** 필름 입자 (아주 옅은 흰·검은 점). 진하기를 네 단계로 묶어 한 번에 그림 */
@Composable
private fun FilmGrain(amount: Double, modifier: Modifier) {
    Canvas(modifier) {
        val rng = SeededRandom(7)
        val k = 1.dp.toPx()
        val w = size.width / k
        val h = size.height / k
        val n = (w * h / 22).toInt()
        val buckets = Array(8) { ArrayList<Offset>(n / 8 + 1) }
        for (i in 0 until n) {
            val x = (rng.unit() * size.width).toFloat()
            val y = (rng.unit() * size.height).toFloat()
            val lv = (rng.unit() * 4).toInt().coerceIn(0, 3)
            buckets[(i % 2) * 4 + lv].add(Offset(x, y))
        }
        for (b in 0 until 8) {
            val c = if (b < 4) Color.White else Color.Black
            val a = (amount * (0.4 + (b % 4 + 0.5) / 4 * 0.9)).toFloat()
            drawPoints(buckets[b], PointMode.Points, c.copy(alpha = a), strokeWidth = 0.9f * k)
        }
    }
}
