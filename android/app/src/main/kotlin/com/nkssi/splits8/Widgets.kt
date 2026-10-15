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

    /** 체크무늬 깃발 (아이폰 flag.checkered) + 라벨 */
    private fun flagLabel(c: Canvas, pen: Pen, x: Float, y: Float, text: String): Float {
        val k = pen.k
        val sq = dp(2.4f, k)
        val pole = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pen.pal.accent }
        c.drawRect(x, y + dp(1f, k), x + dp(1.4f, k), y + dp(12f, k), pole)
        for (r in 0 until 3) for (col in 0 until 3) if ((r + col) % 2 == 0) {
            val l = x + dp(1.4f, k) + col * sq
            val t = y + dp(1f, k) + r * sq
            c.drawRect(l, t, l + sq, t + sq, pole)
        }
        return pen.text(c, WidgetKo.t(text), x + dp(16f, k), y, pen.paint(11f, 600, pen.pal.sub, track = 0.88f))
    }

    private fun ddayText(d: Int) = if (d == 0) "D-DAY" else "D-$d"
    private fun raceDay(s: WidgetSnap, d: Int) = if (d == 0) WidgetKo.t("Today") else s.raceDate?.let { Fm.wdm(it) } ?: ""
    private fun hours(s: Int) = String.format(Locale.US, "%d:%02d", s / 3600, (s % 3600) / 60)
    private fun grouped(n: Int) = String.format(Locale.US, "%,d", n)

    /** 다음 대회 (작게 · 가로형). wDp · hDp = 위젯 크기 */
    fun dday(ctx: Context, snap: WidgetSnap, now: Instant, wDp: Float, hDp: Float, density: Float, pal: WidgetPal = WidgetPal.dark): Bitmap {
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
        val wide = wDp >= 250
        var y = pad
        y += flagLabel(c, pen, pad, y, if (d == 0) "RACE DAY" else "HYROX RACE")
        y += dp(6f, k)
        y += pen.text(c, name, pad, y, pen.paint(19f, 600), inner, 0.7f)
        val sub = raceDay(snap, d) + if (wide && snap.division.isNotEmpty()) " · " + WidgetKo.t(snap.division) else ""
        pen.text(c, sub, pad, y, pen.paint(13f, 400, pen.pal.sub), inner)
        // 아래: D-day (가로형이면 오른쪽에 GOAL · BEST 막대)
        val big = pen.paint(if (d == 0) 34f else if (wide) 42f else 44f, 700, pen.pal.accent, track = -0.03f * 44, num = true)
        val fm = big.fontMetrics
        val bigH = fm.descent - fm.ascent
        val bottom = h - pad - dp(9f, k)
        val barsW = dp(140f, k)
        pen.text(c, ddayText(d), pad, bottom - bigH + fm.descent * 0.6f, big, if (wide) inner - barsW - dp(16f, k) else inner, 0.6f)
        if (wide) {
            val g = snap.goal ?: 0; val b = snap.best ?: 0
            val mx = max(max(g, b), 1) * 1.04f
            val left = w - pad - barsW
            val mid = bottom - bigH / 2
            bar(c, pen, left, mid - dp(30f, k), barsW, "GOAL", g, mx, pen.pal.accent)
            bar(c, pen, left, mid + dp(2f, k), barsW, "BEST", b, mx, if (pen.pal.light) pen.pal.dim else pen.pal.sub)
        }
        return bmp
    }

    private fun bar(c: Canvas, pen: Pen, x: Float, y: Float, w: Float, label: String, v: Int, mx: Float, color: Int) {
        val k = pen.k
        val lh = pen.text(c, WidgetKo.t(label), x, y + dp(2f, k), pen.paint(10f, 600, pen.pal.sub, track = 0.8f))
        pen.text(c, if (v > 0) Fm.t(v) else "--:--", x + w, y, pen.paint(13f, 600, pen.pal.fg, num = true), right = true)
        val top = y + max(lh, dp(16f, k)) + dp(4f, k)
        val r = dp(2.5f, k)
        c.drawRoundRect(RectF(x, top, x + w, top + dp(5f, k)), r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = pen.pal.track })
        if (v > 0) c.drawRoundRect(RectF(x, top, x + w * min(1f, v / mx), top + dp(5f, k)), r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color })
    }

    /** 대회가 없을 때: "Add a race" */
    private fun noRace(c: Canvas, pen: Pen, pad: Float, inner: Float, h: Int) {
        val k = pen.k
        flagLabel(c, pen, pad, pad, "HYROX RACE")
        val p2 = pen.paint(12f, 400, pen.pal.sub)
        val p1 = pen.paint(17f, 600)
        val lines = wrap(WidgetKo.t("Count down to race day."), p2, inner, 2)
        val lh2 = p2.fontMetrics.let { it.descent - it.ascent }
        var y = h - pad - lh2 * lines.size
        val lh1 = p1.fontMetrics.let { it.descent - it.ascent }
        pen.text(c, WidgetKo.t("Add a race"), pad, y - lh1 - dp(4f, k), p1, inner)
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
            val col = Mode.of(snap.dayMode[i])?.let { (0xFF000000 or it.calendarHex).toInt() } ?: pen.pal.track
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
        val best = listOfNotNull(b.simBest?.total, b.raceBest?.total).minOrNull()
        return WidgetSnap.make(Store.records.filter { it.counts }, Store.settings, best, Store.now())
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
    fun forget(ctx: Context, ids: IntArray) { prefs(ctx).edit().apply { ids.forEach { remove("look.$it") } }.apply() }

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

/** 다음 대회 D-day (2×2 · 늘리면 목표 · 최고 막대까지). 누르면 Race 탭 */
class DdayWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) {
        Store.init(ctx.applicationContext)
        val snap = Widgets.snap()
        val now = Store.now()
        val k = ctx.resources.displayMetrics.density
        for (id in ids) {
            val (w, h) = Widgets.size(m, id, 160f, 160f)
            val d = snap.daysLeft(now)
            val label = if (d != null && snap.raceName != null) "${snap.raceName} D-$d" else WidgetKo.t("Add a race")
            m.updateAppWidget(id, Widgets.views(ctx, WidgetArt.dday(ctx, snap, now, w, h, k, Widgets.pal(ctx, id, snap)), label, "race"))
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
