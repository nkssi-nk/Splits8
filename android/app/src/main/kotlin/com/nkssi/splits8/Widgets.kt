package com.nkssi.splits8

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.WidgetKo
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.WidgetSnap
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/**
 * 홈 화면 위젯 (아이폰 위젯 53번과 같은 모양): 다음 대회 D-day · 이번 주.
 * 안드로이드 위젯은 앱 화면 부품을 쓸 수 없어서, 위젯 크기 그대로 그림을 그려 넣음 (Pretendard · 노란 빛까지 아이폰과 같게)
 */
/**
 * 빌드 24 · 위젯 바탕 (자동 / 검정 / 흰색 / 테마 색) — 아이폰 WPal.
 * 흰 바탕에서는 노란 글자가 안 보이므로 D-day 숫자 · GOAL 막대는 진한 황토(#8A7400), 글자는 검정, 빛은 연한 노랑.
 */
data class WidgetPal(
    val fg: Int, val sub: Int, val dim: Int, val accent: Int, val glow: Int, val track: Int, val bg: Int, val light: Boolean,
) {
    companion object {
        val dark = WidgetPal(Color.WHITE, 0xFF8E8E93.toInt(), 0xFF6E6E73.toInt(), 0xFFFFE600.toInt(), 0xFFFFE600.toInt(),
            Color.argb(31, 255, 255, 255), 0xFF0C0C0C.toInt(), false)
        val light = WidgetPal(Color.BLACK, 0xFF6E6E73.toInt(), 0xFFAEAEB2.toInt(), 0xFF8A7400.toInt(), 0xFFFFE600.toInt(),
            Color.argb(26, 0, 0, 0), Color.WHITE, true)

        /** 테마 색 바탕: 그 색을 진하게 깐 어두운 바탕 (글자는 흰색, 강조는 테마 색 밝게) */
        fun theme(hex: Long): WidgetPal = dark.copy(
            bg = (0xFF000000 or blend(hex, 0x000000, 0.72)).toInt(),
            accent = if (hex == 0xFFE600L) 0xFFFFE600.toInt() else (0xFF000000 or blend(hex, 0xFFFFFF, 0.25)).toInt(),
            glow = (0xFF000000 or hex).toInt(),
            track = Color.argb(41, 255, 255, 255), sub = Color.argb(173, 255, 255, 255), dim = Color.argb(107, 255, 255, 255),
        )

        /** look: auto / black / white / theme. 자동은 폰의 라이트/다크 모드를 따라감 */
        fun of(look: String, night: Boolean, themeHex: Long?): WidgetPal = when (look) {
            "black" -> dark
            "white" -> light
            "theme" -> theme(themeHex ?: 0xFFE600)
            else -> if (night) dark else light
        }

        /** 두 색 섞기. t = b 쪽 비율 */
        fun blend(a: Long, b: Long, t: Double): Long {
            fun ch(v: Long, sh: Int) = ((v shr sh) and 0xFF).toDouble()
            fun mix(sh: Int) = Math.round(ch(a, sh) * (1 - t) + ch(b, sh) * t) shl sh
            return mix(16) or mix(8) or mix(0)
        }
    }
}

object WidgetArt {
    private class Pen(val ctx: Context, val k: Float, val pal: WidgetPal) {
        private val faces = HashMap<Int, Typeface>()
        fun face(w: Int): Typeface = faces.getOrPut(w) {
            val id = when (w) { 500 -> R.font.pretendard_medium; 600 -> R.font.pretendard_semibold; 700 -> R.font.pretendard_bold; else -> R.font.pretendard_regular }
            runCatching { ResourcesCompat.getFont(ctx, id) }.getOrNull() ?: Typeface.DEFAULT
        }
        fun paint(size: Float, w: Int = 400, color: Int = pal.fg, track: Float = 0f, num: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = face(w); textSize = size * k; this.color = color
            if (track != 0f) letterSpacing = track / size
            if (num) fontFeatureSettings = "tnum"
        }
        /** 글자를 왼쪽 위 기준 (x, y = 글자 상자 위)으로. 자리가 모자라면 minScale 까지 작게. 그린 높이를 돌려줌 */
        fun text(c: Canvas, s: String, x: Float, top: Float, p: Paint, maxW: Float = Float.MAX_VALUE, minScale: Float = 1f, right: Boolean = false): Float {
            var size = p.textSize
            while (p.measureText(s) > maxW && p.textSize > size * minScale) p.textSize *= 0.96f
            var t = s
            while (p.measureText(t) > maxW && t.length > 1) t = t.dropLast(2) + "…"
            val fm = p.fontMetrics
            val w = p.measureText(t)
            c.drawText(t, if (right) x - w else x, top - fm.ascent, p)
            val h = fm.descent - fm.ascent
            p.textSize = size
            return h
        }
    }

    private fun dp(v: Float, k: Float) = v * k

    private fun card(w: Int, h: Int, k: Float, stage: Int, pal: WidgetPal): Pair<Bitmap, Canvas> {
        val bmp = Bitmap.createBitmap(max(1, w), max(1, h), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val r = RectF(0f, 0f, w.toFloat(), h.toFloat())
        val radius = dp(22f, k)
        c.drawRoundRect(r, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pal.bg })
        // 대회가 가까울수록 진해지는 빛 (오른쪽 아래, 흰 바탕은 0.9배)
        val a = listOf(0f, 0.14f, 0.26f, 0.48f)[stage.coerceIn(0, 3)] * (if (pal.light) 0.9f else 1f)
        if (a > 0f) {
            val gr = Color.red(pal.glow); val gg = Color.green(pal.glow); val gb = Color.blue(pal.glow)
            val g = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(w.toFloat(), h.toFloat(), max(w, h) * 0.9f,
                    Color.argb((a * 255).toInt(), gr, gg, gb), Color.argb(0, gr, gg, gb), Shader.TileMode.CLAMP)
            }
            c.drawRoundRect(r, radius, radius, g)
        }
        return bmp to c
    }

    /** 1.2.8: "HYROX RACE" 앞 깃발 = 앱의 Race 모드 아이콘 (mode_race, 노랑으로 칠함) + 라벨. 그린 높이를 돌려줌 */
    private fun flagLabel(c: Canvas, pen: Pen, x: Float, y: Float, text: String): Float {
        val k = pen.k
        val p = pen.paint(10f, 700, pen.pal.sub, track = 0.7f)
        val fm = p.fontMetrics
        val lh = fm.descent - fm.ascent
        val sz = dp(12f, k)
        flagBmp(pen.ctx)?.let { b ->
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                colorFilter = PorterDuffColorFilter(pen.pal.accent, PorterDuff.Mode.SRC_IN)
            }
            val top = y + (lh - sz) / 2
            c.drawBitmap(b, null, RectF(x, top, x + sz, top + sz), paint)
        }
        pen.text(c, text, x + sz + dp(5f, k), y, p)
        return lh
    }

    private var flagCache: Bitmap? = null
    private fun flagBmp(ctx: Context): Bitmap? = flagCache ?: runCatching {
        android.graphics.BitmapFactory.decodeResource(ctx.resources, R.drawable.mode_race)
    }.getOrNull().also { flagCache = it }

    private fun ddayText(d: Int) = if (d == 0) "D-DAY" else "D-$d"
    private fun raceDay(s: WidgetSnap, d: Int) = if (d == 0) "Today" else s.raceDate?.let { enDate(it) } ?: ""
    /** 위젯 글자는 모두 영어 (1.2.8): "Thu, May 13" */
    private fun enDate(i: Instant) = java.time.format.DateTimeFormatter.ofPattern("EEE, MMM d", Locale.US).format(i.atZone(Fm.zone))
    private fun hours(s: Int) = String.format(Locale.US, "%d:%02d", s / 3600, (s % 3600) / 60)
    private fun grouped(n: Int) = String.format(Locale.US, "%,d", n)
    private fun blue(pal: WidgetPal) = 0xFF1E78FA.toInt()
    private fun kcalCol(pal: WidgetPal) = if (pal.light) 0xFFAEAEB2.toInt() else 0xFFE5E5EA.toInt()

    /**
     * 1.2.8: "D-170" 을 그리되 가운데 "-" 만 위로 올려 대문자 · 숫자 높이 한가운데에 맞춤
     * (글꼴의 하이픈은 소문자 높이 가운데라 큰 숫자 옆에서 처져 보임 — 대표님 11-25). 자리가 모자라면 minScale 까지 작게.
     */
    fun drawDday(c: Canvas, s: String, x: Float, baseline: Float, p: Paint, maxW: Float = Float.MAX_VALUE, minScale: Float = 0.6f) {
        val size0 = p.textSize
        while (p.measureText(s) > maxW && p.textSize > size0 * minScale) p.textSize *= 0.96f
        val i = s.indexOf('-')
        if (i < 0) { c.drawText(s, x, baseline, p); p.textSize = size0; return }
        val a = s.substring(0, i); val b = s.substring(i + 1)
        val bD = android.graphics.Rect(); p.getTextBounds("D", 0, 1, bD)
        val bH = android.graphics.Rect(); p.getTextBounds("-", 0, 1, bH)
        val dy = (bD.top + bD.bottom) / 2f - (bH.top + bH.bottom) / 2f
        var cx = x
        c.drawText(a, cx, baseline, p); cx += p.measureText(a)
        c.drawText("-", cx, baseline + dy, p); cx += p.measureText("-")
        c.drawText(b, cx, baseline, p)
        p.textSize = size0
    }

    /** 다음 대회 (작게 · 가로형). wDp · hDp = 위젯 크기. side = 가로형 오른쪽 칸 (today / weeks / week / last / best) */
    fun dday(ctx: Context, snap0: WidgetSnap, now: Instant, wDp: Float, hDp: Float, density: Float, pal: WidgetPal = WidgetPal.dark,
             side: String = "today"): Bitmap {
        val snap = snap0.fresh(now).todayFresh(now)
        val k = density
        val w = (wDp * k).toInt(); val h = (hDp * k).toInt()
        val d = snap.daysLeft(now)
        val (bmp, c) = card(w, h, k, WidgetSnap.stage(d), pal)
        val pen = Pen(ctx, k, pal)
        val pad = dp(16f, k)
        val inner = w - pad * 2
        val name = snap.raceName
        if (d == null || name == null) {
            noRace(c, pen, pad, inner, h)
            return bmp
        }
        // 1.2.8 (대표님 11-24): 대회 정보는 작게 위젯 만큼만 — 깃발 HYROX RACE · 대회 이름 · 날짜 · Division · D-170
        // 내용 묶음을 위아래 가운데 (위 여백 = 아래 여백). 가로형은 세로 선 오른쪽에 고른 칸 (폭 134)
        val wide = wDp >= 250
        val rightW = dp(134f, k)
        val lineGap = dp(12f, k)
        val leftW = if (wide) inner - rightW - lineGap * 2 - dp(1f, k) else inner
        val lab = pen.paint(10f, 700, pal.sub, track = 0.7f)
        val nm = pen.paint(15f, 600)
        val sub = pen.paint(11.5f, 400, pal.sub)
        val big = pen.paint(48f, 700, pal.accent, track = -1.6f, num = true)
        fun hOf(p: Paint) = p.fontMetrics.let { it.descent - it.ascent }
        // D-170 높이는 대문자 높이 (글자 위아래 빈칸 빼고)
        val capB = android.graphics.Rect(); big.getTextBounds("D", 0, 1, capB)
        val bigCap = capB.height().toFloat()
        val labH = hOf(lab); val nmH = hOf(nm); val subH = hOf(sub)
        val blockH = labH + dp(4f, k) + nmH + subH * 2 + dp(14f, k) + bigCap
        val top = (h - blockH) / 2
        var y = top
        flagLabel(c, pen, pad, y, if (d == 0) "RACE DAY" else "HYROX RACE")
        y += labH + dp(4f, k)
        y += pen.text(c, name, pad, y, nm, leftW, 0.8f)
        y += pen.text(c, raceDay(snap, d), pad, y, sub, leftW)
        if (snap.division.isNotEmpty()) pen.text(c, snap.division, pad, y, sub, leftW)
        y += subH + dp(14f, k)
        val ddBase = y + bigCap
        drawDday(c, ddayText(d), pad, ddBase, big, leftW, 0.6f)
        if (wide) {
            val lx = pad + leftW + lineGap
            c.drawRect(lx, pad, lx + dp(1f, k), h - pad, Paint().apply { color = if (pal.light) 0x1F000000 else 0xFF262626.toInt() })
            val rx = lx + dp(1f, k) + lineGap
            right(c, pen, snap, now, side, rx, top, rightW, ddBase, labH)
        }
        return bmp
    }

    /** 가로형 오른쪽 칸: 이름표는 왼쪽 "HYROX RACE" 와 같은 줄(top), 내용 아래끝 = D-170 아래끝(bottom) */
    private fun right(c: Canvas, pen: Pen, s: WidgetSnap, now: Instant, side: String, x: Float, top: Float, w: Float, bottom: Float, labH: Float) {
        val k = pen.k
        val pal = pen.pal
        val lab = pen.paint(10f, 700, pal.sub, track = 0.7f)
        val sub = pen.paint(11.5f, 400, pal.sub)
        val subB = pen.paint(11.5f, 600, pal.fg, num = true)
        fun hOf(p: Paint) = p.fontMetrics.let { it.descent - it.ascent }
        val title = when (side) { "weeks" -> "LAST 4 WEEKS"; "week" -> "THIS WEEK"; "last" -> "LAST WORKOUT"; "best" -> "BEST vs GOAL"; else -> "TODAY" }
        pen.text(c, title, x, top, lab, w)
        val y0 = top + labH + dp(8f, k)
        when (side) {
            "weeks" -> {
                // 7칸 × 4줄 네모 점 (월요일 시작). 노랑 = 하이록스 연습 · 파랑 = 러닝만 · 빈칸 = 쉰 날 · 오늘 = 흰 테두리
                val gap = dp(5f, k)
                val sz = min(dp(13f, k), (w - gap * 6) / 7)
                val lineH = hOf(sub)
                val gridH = sz * 4 + gap * 3
                val gy = max(y0, bottom - lineH - dp(8f, k) - gridH)
                val today = now.atZone(Fm.zone).toLocalDate()
                val start = WidgetSnap.monday(now).minusDays(21)
                for (i in 0 until 28) {
                    val day = start.plusDays(i.toLong())
                    if (day.isAfter(today)) continue
                    val cx = x + (i % 7) * (sz + gap); val cy = gy + (i / 7) * (sz + gap)
                    val col = when (s.last28.getOrNull(i)) { "hyrox" -> pal.accent; "run" -> blue(pal); else -> pal.track }
                    val r = dp(4f, k)
                    c.drawRoundRect(RectF(cx, cy, cx + sz, cy + sz), r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = col })
                    if (day == today) c.drawRoundRect(RectF(cx + dp(0.75f, k), cy + dp(0.75f, k), cx + sz - dp(0.75f, k), cy + sz - dp(0.75f, k)), r, r,
                        Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(1.5f, k); color = pal.fg })
                }
                mixLine(c, pen, x, bottom - lineH, w, listOf("${s.count28}" to true, " workouts · " to false, "${s.streak}" to true, " streak" to false))
            }
            "week" -> {
                mixLine(c, pen, x, y0, w, listOf("${s.weekCount}" to true, " workouts · " to false, hours(s.weekSec) to true, " h" to false))
                val barTop = y0 + hOf(sub) + dp(8f, k)
                weekBars(c, pen, s, now, x, bottom, w, max(dp(16f, k), bottom - barTop - dp(13f, k)), labels = true)
            }
            "last" -> {
                val nameP = pen.paint(14f, 600)
                val col = if (s.lastKind == "run") blue(pal) else pal.accent
                val lastName = s.lastName
                if (lastName == null) { pen.text(c, "No workout yet", x, y0, sub, w); return }
                val dot = dp(6f, k)
                val nh = hOf(nameP)
                c.drawCircle(x + dot / 2, y0 + nh / 2, dot / 2, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = col })
                pen.text(c, lastName, x + dot + dp(5f, k), y0, nameP, w - dot - dp(5f, k), 0.85f)
                pen.text(c, ago(s.lastDate, now), x, y0 + nh, sub, w)
                val timeP = pen.paint(26f, 700, pal.fg, track = -0.8f, num = true)
                val vs = s.lastVsGoal
                val vsH = if (vs != null) hOf(sub) else 0f
                val tb = android.graphics.Rect(); timeP.getTextBounds("0", 0, 1, tb)
                val timeBase = bottom - vsH - (if (vs != null) dp(5f, k) else 0f)
                c.drawText(Fm.t(s.lastSec), x, timeBase, timeP)
                if (vs != null) {
                    val fast = vs <= 0
                    val txt = (if (fast) "−" else "+") + Fm.t(kotlin.math.abs(vs))
                    val vp = pen.paint(11.5f, 600, if (fast) pal.accent else pal.sub, num = true)
                    val tw = pen.text(c, txt, x, bottom - vsH, vp, w)
                    pen.text(c, " vs goal", x + vp.measureText(txt), bottom - vsH, sub, w)
                }
            }
            "best" -> {
                val g = s.goal ?: 0; val b = s.best ?: 0
                if (g <= 0 || b <= 0) { pen.text(c, "Set a goal in Race", x, y0, sub, w); return }
                val vp = pen.paint(15f, 600, pal.fg, num = true)
                val rh = hOf(vp)
                pen.text(c, "Best", x, y0 + (rh - hOf(sub)) / 2, sub, w)
                pen.text(c, Fm.t(b), x + w, y0, vp, right = true)
                val vpY = pen.paint(15f, 600, pal.accent, num = true)
                pen.text(c, "Goal", x, y0 + rh + dp(4f, k) + (rh - hOf(sub)) / 2, sub, w)
                pen.text(c, Fm.t(g), x + w, y0 + rh + dp(4f, k), vpY, right = true)
                val wn = s.weakName
                if (wn != null && s.weakDiff > 0) {
                    val np = pen.paint(13f, 600, if (s.weakKind == "run") blue(pal) else pal.accent)
                    val nH = hOf(np)
                    pen.text(c, "Weakest", x, bottom - nH - hOf(sub), sub, w)
                    pen.text(c, wn, x, bottom - nH, np, w * 0.62f, 0.8f)
                    pen.text(c, "+" + Fm.t(s.weakDiff), x + w, bottom - nH, pen.paint(13f, 600, pal.sub, num = true), right = true)
                }
            }
            else -> {
                // TODAY 링 3개: 바깥 노랑 = 하이록스 연습 시간 · 가운데 파랑 = 러닝 km · 안쪽 연회색 = 칼로리. 꽉 참 = 지난 28일 운동한 날 평균
                val dia = min(dp(80f, k), bottom - y0)
                val cy = bottom - dia / 2
                val cx = x + dia / 2
                val sw = dp(7f, k)
                val gapR = dp(2.5f, k)
                val rings = listOf(
                    Triple(pal.accent, s.todayHyroxSec.toFloat() / max(1, s.avgHyroxSec), 0),
                    Triple(blue(pal), (s.todayRunKm / max(0.1, s.avgRunKm)).toFloat(), 1),
                    Triple(kcalCol(pal), s.todayKcal.toFloat() / max(1, s.avgKcal), 2),
                )
                for ((col, frac, i) in rings) {
                    val r = dia / 2 - sw / 2 - i * (sw + gapR)
                    val oval = RectF(cx - r, cy - r, cx + r, cy + r)
                    val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = sw; color = col; alpha = 51 }
                    c.drawArc(oval, 0f, 360f, false, track)
                    val f = frac.coerceAtLeast(0f)
                    if (f > 0f) {
                        val pp = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = sw; color = col; strokeCap = Paint.Cap.ROUND }
                        c.drawArc(oval, -90f, min(f, 1f) * 360f, false, pp)
                        if (f > 1f) c.drawArc(oval, -90f, (f - 1f).coerceAtMost(1f) * 360f, false, pp.apply { setShadowLayer(dp(2f, k), 0f, 0f, 0x66000000) })
                    }
                }
                val lx = x + dia + dp(8f, k)
                val lw = x + w - lx
                val lines = listOf(
                    (s.todayHyroxSec / 60).toString() to " min",
                    String.format(Locale.US, "%.1f", s.todayRunKm) to " km",
                    grouped(s.todayKcal) to " kcal",
                )
                val lh = hOf(sub)
                val step = lh + dp(6f, k)
                var ly = cy - (lh * 3 + dp(12f, k)) / 2
                for ((v, u) in lines) { mixLine(c, pen, lx, ly, lw, listOf(v to true, u to false)); ly += step }
            }
        }
    }

    /** 굵은 숫자 + 회색 글자를 한 줄로 이어 그리기 */
    private fun mixLine(c: Canvas, pen: Pen, x: Float, y: Float, w: Float, parts: List<Pair<String, Boolean>>) {
        val b = pen.paint(11.5f, 600, pen.pal.fg, num = true)
        val n = pen.paint(11.5f, 400, pen.pal.sub)
        var cx = x
        for ((t, bold) in parts) {
            val p = if (bold) b else n
            if (cx - x + p.measureText(t) > w) break
            pen.text(c, t, cx, y, p)
            cx += p.measureText(t)
        }
    }

    private fun ago(d: Instant?, now: Instant): String {
        d ?: return ""
        val n = java.time.temporal.ChronoUnit.DAYS.between(d.atZone(Fm.zone).toLocalDate(), now.atZone(Fm.zone).toLocalDate()).toInt()
        return when { n <= 0 -> "Today"; n == 1 -> "Yesterday"; else -> "$n days ago" }
    }

    /** 대회가 없을 때: "Add a race" */
    private fun noRace(c: Canvas, pen: Pen, pad: Float, inner: Float, h: Int) {
        val k = pen.k
        flagLabel(c, pen, pad, pad, "HYROX RACE")
        val p2 = pen.paint(12f, 400, pen.pal.sub)
        val p1 = pen.paint(17f, 600)
        val lines = wrap("Count down to race day.", p2, inner, 2)
        val lh2 = p2.fontMetrics.let { it.descent - it.ascent }
        var y = h - pad - lh2 * lines.size
        val lh1 = p1.fontMetrics.let { it.descent - it.ascent }
        pen.text(c, "Add a race", pad, y - lh1 - dp(4f, k), p1, inner)
        for (l in lines) { pen.text(c, l, pad, y, p2, inner); y += lh2 }
    }

    private fun wrap(s: String, p: Paint, maxW: Float, maxLines: Int): List<String> {
        val words = s.split(" ")
        val out = ArrayList<String>()
        var cur = ""
        for (wd in words) {
            val t = if (cur.isEmpty()) wd else "$cur $wd"
            if (p.measureText(t) <= maxW || cur.isEmpty()) cur = t else { out.add(cur); cur = wd }
        }
        if (cur.isNotEmpty()) out.add(cur)
        return out.take(maxLines)
    }

    /** 요일 막대 (막대 색 = 그날 한 운동 종류), 오늘 글자만 흰색 */
    private fun weekBars(c: Canvas, pen: Pen, snap: WidgetSnap, now: Instant, x: Float, bottom: Float, w: Float, barH: Float, labels: Boolean) {
        val k = pen.k
        val mx = max(30, snap.dayMin.maxOrNull() ?: 0)
        val gap = dp(5f, k)
        val bw = (w - gap * 6) / 7
        val today = now.atZone(ZoneId.systemDefault()).dayOfWeek.value - 1
        val labelH = if (labels) dp(13f, k) else 0f
        val lp = pen.paint(8f, 600, pen.pal.dim)
        val days = listOf("M", "T", "W", "T", "F", "S", "S")
        for (i in 0 until 7) {
            val m = snap.dayMin[i]
            // 1.2.8: 하이록스 연습 = 노랑 · 러닝만 = 파랑 (예전 값(Mode)은 노랑)
            val col = when (snap.dayMode[i]) { "" -> pen.pal.track; "run" -> 0xFF1E78FA.toInt(); else -> pen.pal.accent }
            val hh = if (m > 0) max(dp(8f, k), barH * m / mx) else dp(3f, k)
            val l = x + i * (bw + gap)
            val b = bottom - labelH
            val r = dp(2f, k)
            c.drawRoundRect(RectF(l, b - hh, l + bw, b), r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = col })
            if (labels) {
                lp.color = if (i == today) pen.pal.fg else pen.pal.dim
                val tw = lp.measureText(days[i])
                pen.text(c, days[i], l + (bw - tw) / 2, b + dp(3f, k), lp)
            }
        }
    }

    /** 이번 주 (작게 · 가로형) */
    fun week(ctx: Context, snap0: WidgetSnap, now: Instant, wDp: Float, hDp: Float, density: Float, pal: WidgetPal = WidgetPal.dark): Bitmap {
        val snap = snap0.fresh(now)
        val k = density
        val w = (wDp * k).toInt(); val h = (hDp * k).toInt()
        val (bmp, c) = card(w, h, k, 0, pal)
        val pen = Pen(ctx, k, pal)
        val pad = dp(16f, k)
        val inner = w - pad * 2
        if (wDp < 250) {
            var y = pad
            y += pen.text(c, WidgetKo.t("THIS WEEK"), pad, y, pen.paint(11f, 600, pen.pal.sub, track = 0.9f))
            y += dp(4f, k)
            val big = pen.paint(40f, 700, if (snap.weekCount > 0) pen.pal.fg else pen.pal.sub, num = true)
            val bigH = pen.text(c, "${snap.weekCount}", pad, y, big)
            val bw = big.measureText("${snap.weekCount}")
            val small = pen.paint(14f, 400, pen.pal.sub)
            pen.text(c, WidgetKo.t("workouts"), pad + bw + dp(5f, k), y + bigH * 0.78f - small.fontMetrics.let { it.descent - it.ascent }, small)
            y += bigH
            val line = if (snap.weekCount > 0) "${hours(snap.weekSec)} h · ${grouped(snap.weekKcal)} kcal" else WidgetKo.t("Start your first one")
            pen.text(c, line, pad, y, pen.paint(13f, 400, pen.pal.sub), inner, 0.8f)
            weekBars(c, pen, snap, now, pad, h - pad, inner, dp(26f, k), labels = false)
        } else {
            // 왼쪽: 제목 · 날짜 범위 · 숫자 4개 / 오른쪽: 요일 막대
            val leftW = inner * 0.5f
            var y = pad
            val tp = pen.paint(11f, 600, pen.pal.sub, track = 0.9f)
            val th = pen.text(c, WidgetKo.t("THIS WEEK"), pad, y, tp)
            val end = snap.weekStart.plusDays(6)
            val range = Fm.dm(snap.weekStart.atStartOfDay(Fm.zone).toInstant()) + " – " + Fm.dm(end.atStartOfDay(Fm.zone).toInstant())
            pen.text(c, range, pad + tp.measureText(WidgetKo.t("THIS WEEK")) + dp(6f, k), y, pen.paint(11f, 400, pen.pal.dim), leftW, 0.8f)
            y += th
            val colW = (leftW - dp(18f, k)) / 2
            val statH = dp(38f, k)
            val top = h - pad - statH * 2 - dp(10f, k)
            stat(c, pen, pad, top, colW, "WORKOUTS", "${snap.weekCount}", "")
            stat(c, pen, pad, top + statH + dp(10f, k), colW, "CALORIES", grouped(snap.weekKcal), "")
            stat(c, pen, pad + colW + dp(18f, k), top, colW, "TIME", hours(snap.weekSec), "H")
            stat(c, pen, pad + colW + dp(18f, k), top + statH + dp(10f, k), colW, "RUN", String.format(Locale.US, "%.1f", snap.weekRunKm), "KM")
            val bx = pad + leftW + dp(14f, k)
            weekBars(c, pen, snap, now, bx, h - pad, w - pad - bx, min(dp(70f, k), h - pad * 2 - dp(13f, k)), labels = true)
        }
        return bmp
    }

    private fun stat(c: Canvas, pen: Pen, x: Float, y: Float, w: Float, label: String, v: String, unit: String) {
        val k = pen.k
        val lh = pen.text(c, WidgetKo.t(label), x, y, pen.paint(9f, 600, pen.pal.sub, track = 0.7f), w)
        val vp = pen.paint(19f, 600, pen.pal.fg, num = true)
        pen.text(c, v, x, y + lh + dp(1f, k), vp, w, 0.7f)
        if (unit.isNotEmpty()) {
            val vw = min(vp.measureText(v), w)
            val vh = vp.fontMetrics.let { it.descent - it.ascent }
            val up = pen.paint(9f, 600, pen.pal.sub)
            pen.text(c, WidgetKo.t(unit), x + vw + dp(1f, k), y + lh + dp(1f, k) + vh * 0.78f - up.fontMetrics.let { it.descent - it.ascent }, up)
        }
    }
}

/** 위젯 새로 그리기 (기록 · 대회 · 목표가 바뀌면 앱이 부름) */
object Widgets {
    /** 앱 데이터로 만든 요약 (아이폰 publishWidgets 와 같음: 정상 기록만, 최고 = Full Sim · 레이스 중 빠른 것) */
    fun snap(): WidgetSnap {
        val b = Store.book
        val bestRec = listOfNotNull(b.simBest, b.raceBest).minByOrNull { it.total }
        return WidgetSnap.make(Store.records.filter { it.counts }, Store.settings, bestRec?.total, Store.now(), bestRec)
    }

    fun refresh(ctx: Context) {
        val m = AppWidgetManager.getInstance(ctx) ?: return
        for (cls in listOf(DdayWidget::class.java, WeekWidget::class.java)) {
            val ids = runCatching { m.getAppWidgetIds(ComponentName(ctx, cls)) }.getOrNull() ?: continue
            if (ids.isEmpty()) continue
            ctx.sendBroadcast(Intent(ctx, cls).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids))
        }
    }

    /** 위젯 크기 (dp). 세로 화면 기준: 가로는 최소 폭, 세로는 최대 높이 */
    fun size(m: AppWidgetManager, id: Int, defW: Float, defH: Float): Pair<Float, Float> {
        val o: Bundle = runCatching { m.getAppWidgetOptions(id) }.getOrNull() ?: return defW to defH
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return (if (w > 40) w.toFloat() else defW).coerceAtMost(600f) to (if (h > 40) h.toFloat() else defH).coerceAtMost(600f)
    }

    // MARK: 빌드 24 · 위젯마다 고른 바탕 (위젯 길게 누르기 → 설정)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("widgets", Context.MODE_PRIVATE)
    /** auto / black / white / theme */
    fun look(ctx: Context, id: Int): String = prefs(ctx).getString("look.$id", "auto") ?: "auto"
    fun setLook(ctx: Context, id: Int, look: String) { prefs(ctx).edit().putString("look.$id", look).apply() }
    fun forget(ctx: Context, ids: IntArray) { prefs(ctx).edit().apply { ids.forEach { remove("look.$it"); remove("side.$it") } }.apply() }

    /** 1.2.8: 가로형 D-day 위젯 오른쪽 칸 — today / weeks / week / last / best (기본 today) */
    val sides = listOf("today" to "Today", "weeks" to "Last 4 weeks", "week" to "This week", "last" to "Last workout", "best" to "Best vs goal")
    fun side(ctx: Context, id: Int): String = prefs(ctx).getString("side.$id", "today") ?: "today"
    fun setSide(ctx: Context, id: Int, side: String) { prefs(ctx).edit().putString("side.$id", side).apply() }

    fun pal(ctx: Context, id: Int, snap: WidgetSnap): WidgetPal {
        val night = (ctx.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
        return WidgetPal.of(look(ctx, id), night, snap.themeHex)
    }

    fun views(ctx: Context, bmp: Bitmap, label: String, open: String): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_image)
        v.setImageViewBitmap(R.id.widget_image, bmp)
        v.setContentDescription(R.id.widget_image, label)
        val i = Intent(ctx, MainActivity::class.java).putExtra("open", open)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        v.setOnClickPendingIntent(R.id.widget_image, PendingIntent.getActivity(ctx, open.hashCode(), i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        return v
    }
}

/** 다음 대회 D-day (2×2 · 늘리면 오른쪽에 고른 칸 — 1.2.8). 누르면 Race 탭 */
class DdayWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) {
        Store.init(ctx.applicationContext)
        val snap = Widgets.snap()
        val now = Store.now()
        val k = ctx.resources.displayMetrics.density
        for (id in ids) {
            val (w, h) = Widgets.size(m, id, 160f, 160f)
            val d = snap.daysLeft(now)
            val label = if (d != null && snap.raceName != null) "${snap.raceName} D-$d" else "Add a race"
            m.updateAppWidget(id, Widgets.views(ctx, WidgetArt.dday(ctx, snap, now, w, h, k, Widgets.pal(ctx, id, snap), Widgets.side(ctx, id)), label, "race"))
        }
    }

    override fun onDeleted(ctx: Context, ids: IntArray) = Widgets.forget(ctx, ids)

    override fun onAppWidgetOptionsChanged(ctx: Context, m: AppWidgetManager, id: Int, o: Bundle?) = onUpdate(ctx, m, intArrayOf(id))
}

/** 이번 주 (2×2 · 늘리면 숫자 4개 + 요일 막대). 누르면 홈 */
class WeekWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) {
        Store.init(ctx.applicationContext)
        val snap = Widgets.snap()
        val now = Store.now()
        val k = ctx.resources.displayMetrics.density
        for (id in ids) {
            val (w, h) = Widgets.size(m, id, 160f, 160f)
            m.updateAppWidget(id, Widgets.views(ctx, WidgetArt.week(ctx, snap, now, w, h, k, Widgets.pal(ctx, id, snap)), WidgetKo.t("This week") + " ${snap.weekCount}", "home"))
        }
    }

    override fun onDeleted(ctx: Context, ids: IntArray) = Widgets.forget(ctx, ids)

    override fun onAppWidgetOptionsChanged(ctx: Context, m: AppWidgetManager, id: Int, o: Bundle?) = onUpdate(ctx, m, intArrayOf(id))
}
