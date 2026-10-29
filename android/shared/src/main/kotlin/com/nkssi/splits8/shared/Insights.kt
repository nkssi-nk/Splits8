package com.nkssi.splits8.shared

import java.time.temporal.ChronoUnit
import kotlin.math.abs
import kotlin.math.ceil

// 기록 화면 "Insights" (아이폰 iOSApp/Insights.swift). 기록 숫자로 계산한 분석 2~4줄, AI 아님.
//  ① 최대 4줄, 같은 묶음에서는 하나만
//  ② 점수 큰 것부터: 새 최고(400) > 큰 차이 30초+(300) > 3번 연속(200) > 참고(100)
//  ③ 5초 미만 차이는 안 보여 줌   ④ 같은 기록은 늘 같은 4줄
//  ⑤ 회색 조언은 4줄 중 1개에만   ⑥ 폰으로만 기록한 것은 심박 · 횟수 줄 빠짐
// 문장 안의 [y]…[/y] 노랑, [r]…[/r] 빨강, [g]…[/g] 초록 (번역 문장에도 같은 표시)

data class Insight(
    /** 규칙 번호 */
    val id: Int,
    val group: String,
    val score: Int,
    val mark: Mark,
    val text: String,
    val tip: String? = null,
) {
    enum class Mark { Up, Down, Star, Time, Pct, Heart, Even, Info }
}

object Insights {
    const val NEW_BEST = 400
    const val BIG = 300
    const val TREND = 200
    const val INFO = 100
    const val MIN_DIFF = 5

    /** 이 기록의 분석 줄 (최대 4) */
    fun make(r: Record, book: RecordBook): List<Insight> {
        val phone = r.source == "phone" || r.hr.isEmpty()
        val sorted = candidates(r, book)
            .filter { !(phone && (it.group == "hr" || it.group == "reps")) }
            .sortedWith(compareByDescending<Insight> { it.score }.thenBy { it.id })
        val used = HashSet<String>()
        val out = ArrayList<Insight>()
        for (x in sorted) {
            if (!used.add(x.group)) continue
            out.add(x)
            if (out.size == 4) break
        }
        var tipShown = false
        for (i in out.indices) {
            if (out[i].tip != null) {
                if (tipShown) out[i] = out[i].copy(tip = null) else tipShown = true
            }
        }
        return out
    }

    /** 문장을 (글자, 색 표시) 조각으로: "y" 노랑 · "r" 빨강 · "g" 초록 · null 기본 */
    fun pieces(s: String): List<Pair<String, String?>> {
        val out = ArrayList<Pair<String, String?>>()
        var rest = s
        while (rest.isNotEmpty()) {
            var first: Pair<Int, String>? = null
            for (t in listOf("y", "r", "g")) {
                val i = rest.indexOf("[$t]")
                if (i >= 0 && (first == null || i < first.first)) first = i to t
            }
            val f = first
            val close = f?.let { rest.indexOf("[/${it.second}]", it.first + 3) } ?: -1
            if (f == null || close < 0) { out.add(rest to null); break }
            if (f.first > 0) out.add(rest.substring(0, f.first) to null)
            out.add(rest.substring(f.first + 3, close) to f.second)
            rest = rest.substring(close + 4)
        }
        return out
    }

    private fun sec(v: Int) = Fm.t(abs(v))
    private fun t(key: String, vararg a: Any?) = L10n.t(key, *a)
    private fun ceilDiv(a: Int, b: Int): Int = ceil(a.toDouble() / b).toInt()

    @Suppress("CyclomaticComplexMethod", "LongMethod")
    private fun candidates(r: Record, book: RecordBook): List<Insight> {
        if (!(r.isComplete || r.mode == Mode.Training)) return emptyList()
        // 18번 종류(타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동)는 하이록스 분석을 하지 않음
        if (Kinds.isNew(r.kind)) return emptyList()
        val o = ArrayList<Insight>()
        val main = r.mainSegs
        val runs = r.runs
        val stations = main.filter { it.kind == SegKind.St }
        val before = book.records.filter { it.id != r.id && it.date < r.date && it.counts }
        val fullRace = (r.mode == Mode.Sim || r.mode == Mode.Race) && r.splits16 != null
        val st = book.settings
        val s16 = r.splits16

        // ── 러닝 ──
        if (fullRace && s16 != null) {
            val rs = (0 until 16 step 2).map { s16[it] }
            val avg = rs.sum() / 8
            // 1 어디서 처졌나
            var worstI = -1
            var worstD = 0
            for (i in 0 until 7) if (rs[i + 1] - avg > worstD) { worstD = rs[i + 1] - avg; worstI = i }
            if (worstI >= 0 && worstD >= MIN_DIFF) {
                o.add(Insight(1, "run", if (worstD >= 30) BIG else INFO, Insight.Mark.Down,
                    t("Your runs slowed most after [y]%@[/y] — [r]+%llds[/r] on your average run.", Fatigue.names[worstI], worstD)))
            }
            // 18 초반이 너무 빠름
            val rest = rs.drop(1)
            val restAvg = rest.sum() / maxOf(1, rest.size)
            val late = rs.takeLast(4).sum() / 4
            val early = rs.take(4).sum() / 4
            if (restAvg - rs[0] >= 20 && late > early) {
                o.add(Insight(18, "run", BIG, Insight.Mark.Down,
                    t("You started fast — Run 1 was [y]%llds[/y] quicker than your average run.", restAvg - rs[0]),
                    t("A steadier first km usually pays back later.")))
            }
            // 19 썰매 다음 러닝
            val sled = (rs[2] + rs[3]) / 2
            val others = listOf(rs[1], rs[4], rs[5], rs[6], rs[7])
            val oAvg = others.sum() / others.size
            if (sled - oAvg >= 20) {
                o.add(Insight(19, "run", TREND, Insight.Mark.Down,
                    t("Runs after the sleds were [r]%llds[/r] slower than your other runs.", sled - oAvg)))
            }
            // 2 고른가
            val spread = rs.max() - rs.min()
            if (spread <= 15) {
                o.add(Insight(2, "run", INFO, Insight.Mark.Even, t("Your 8 runs were within [g]%llds[/g]. Very even.", spread)))
            } else if (rs[7] - rs[0] >= 45) {
                o.add(Insight(2, "run", BIG, Insight.Mark.Down, t("Run 8 was [r]%@[/r] slower than Run 1.", sec(rs[7] - rs[0]))))
            }
        }
        if (runs.size >= 3) {
            val paces = runs.map { r.pace(it) }
            val fi = paces.indices.minByOrNull { paces[it] }!!
            val si = paces.indices.maxByOrNull { paces[it] }!!
            if (paces[si] - paces[fi] >= MIN_DIFF) {
                fun label(i: Int) = if (r.isRunKind) "km ${i + 1}" else "Run ${i + 1}"
                if (r.isRunKind) {
                    o.add(Insight(22, "run", INFO, Insight.Mark.Up, t("Fastest km: [y]%@[/y] (%@).", label(fi), Fm.t(paces[fi]))))
                } else {
                    o.add(Insight(20, "run", INFO, Insight.Mark.Info,
                        t("Fastest: [g]%@[/g] (%@). Slowest: [r]%@[/r] (%@).", label(fi), Fm.t(paces[fi]), label(si), Fm.t(paces[si]))))
                }
            }
            // 3 갈수록 빨라짐
            val last = paces.last()
            if (r.isRunKind && paces.dropLast(1).all { it > last }) {
                o.add(Insight(3, "run2", TREND, Insight.Mark.Up, t("[g]Negative split[/g] — your last km was your fastest.")))
            }
        }
        // 21 목표 페이스
        val pace = r.runPace
        if (fullRace && pace != null) {
            val tg = runs.map { it.target }.filter { it > 0 }
            if (tg.size == runs.size && tg.isNotEmpty()) {
                val goalPace = tg.sum() / tg.size
                val d = pace - goalPace
                if (abs(d) >= MIN_DIFF) {
                    o.add(Insight(21, "run2", if (abs(d) >= 30) BIG else INFO, if (d < 0) Insight.Mark.Up else Insight.Mark.Down,
                        if (d < 0) t("Runs averaged [y]%@/km[/y] — [g]%llds faster[/g] than goal pace.", Fm.t(pace), -d)
                        else t("Runs averaged [y]%@/km[/y] — [r]%llds slower[/r] than goal pace.", Fm.t(pace), d)))
                }
            }
        }

        // ── 구간 (목표 · 지난번 · 최고) ──
        val hasTargets = r.mode != Mode.Training && r.mode != Mode.Pft && main.any { it.target > 0 }
        if (hasTargets) {
            val ds = main.filter { it.target > 0 }.map { it to it.time - it.target }
            val w = ds.maxByOrNull { it.second }
            if (w != null && w.second >= MIN_DIFF) {
                o.add(Insight(4, "seg", if (w.second >= 30) BIG else INFO, Insight.Mark.Time,
                    t("Most time lost vs target: [y]%@[/y], [r]+%@[/r].", w.first.name, sec(w.second))))
            }
            val sd = ds.filter { it.first.kind == SegKind.St }
            val b = sd.minByOrNull { it.second }
            val ww = sd.maxByOrNull { it.second }
            if (b != null && ww != null && b.second <= -MIN_DIFF && ww.second >= MIN_DIFF) {
                o.add(Insight(23, "seg", INFO, Insight.Mark.Info,
                    t("Strongest: [g]%@[/g] (−%llds). Weakest: [r]%@[/r] (+%llds).", b.first.name, -b.second, ww.first.name, ww.second)))
            }
        }
        // 5 레이스: 어디까지 앞섰나
        if (r.mode == Mode.Race && hasTargets) {
            var cum = 0
            var aheadUntil: String? = null
            var wasAhead = false
            for (s in main) {
                if (s.target <= 0) continue
                cum += s.time - s.target
                if (cum <= 0) wasAhead = true else if (wasAhead && aheadUntil == null && s.kind == SegKind.St) aheadUntil = s.name
            }
            // 결승 차이는 기록 화면 위 "VS GOAL" 칸과 같은 계산 (Roxzone 포함 총 시간 − 목표 시간).
            // 예전에는 Roxzone 을 뺀 구간 합으로 계산해서, 목표보다 빨리 끝났는데도 "결승에서 +2:13" 처럼 반대로 나왔음
            val goal = r.goal ?: r.vsTarget
            val finish = goal?.let { r.total - it }
            if (aheadUntil != null && finish != null && finish >= MIN_DIFF) {
                o.add(Insight(5, "goal", BIG, Insight.Mark.Time,
                    t("Ahead of goal until [y]%@[/y], then [r]+%@[/r] by the finish.", aheadUntil, sec(finish))))
            }
        }
        // 6 지난번과
        if (fullRace && s16 != null) {
            val l = before.filter { it.mode == r.mode && it.splits16 != null }.maxByOrNull { it.date }?.splits16
            if (l != null) {
                val names = main.map { it.name }
                val d = (0 until 16).map { s16[it] - l[it] }
                val gi = d.indices.minByOrNull { d[it] }!!
                val wi = d.indices.maxByOrNull { d[it] }!!
                if (d[gi] <= -MIN_DIFF) {
                    o.add(Insight(6, "last", if (d[gi] <= -30) BIG else INFO, Insight.Mark.Up,
                        t("Biggest gain since last time: [y]%@[/y], [g]−%llds[/g].", names[gi], -d[gi])))
                } else if (d[wi] >= MIN_DIFF) {
                    o.add(Insight(6, "last", if (d[wi] >= 30) BIG else INFO, Insight.Mark.Down,
                        t("Biggest drop since last time: [y]%@[/y], [r]+%llds[/r].", names[wi], d[wi])))
                }
            }
        }
        // 7 구간 최고 기록
        if (r.counts) {
            var bestName: String? = null
            var bestTime = 0
            var gain = 0
            if (r.mode == Mode.Training) {
                val prev = HashMap<String, Int>()
                for (b in before) {
                    if (b.mode != Mode.Training) continue
                    for (s in b.segs) {
                        if (s.kind == SegKind.Rox || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                        val k = SegKey.of(s.icon, s.detail)
                        prev[k] = minOf(prev[k] ?: Int.MAX_VALUE, s.time)
                    }
                }
                for (s in main) {
                    if (s.kind != SegKind.St || !SegKey.plausible(s.icon, s.detail, s.time)) continue
                    val p = prev[SegKey.of(s.icon, s.detail)] ?: continue
                    if (p - s.time > gain) { gain = p - s.time; bestName = s.name; bestTime = s.time }
                }
            } else if (r.mode == Mode.Sim && s16 != null) {
                val prev = before.filter { it.mode == Mode.Sim }.mapNotNull { it.splits16 }
                if (prev.isNotEmpty()) {
                    for (i in 1 until 16 step 2) {
                        val p = prev.minOf { it[i] }
                        if (p - s16[i] > gain && s16[i] >= Record.MIN_STATION) { gain = p - s16[i]; bestName = main[i].name; bestTime = s16[i] }
                    }
                }
            }
            if (bestName != null && gain >= 1) {
                o.add(Insight(7, "best", NEW_BEST, Insight.Mark.Star, t("New best: [y]%@ %@[/y].", bestName, Fm.t(bestTime))))
            }
        }

        // ── 시간 비중 · 스테이션 ──
        if (fullRace) {
            val tot = maxOf(1, r.total).toDouble()
            val sp = (r.stationTotal / tot * 100).r()
            val rp = (r.runTotal / tot * 100).r()
            val xp = maxOf(0, 100 - sp - rp)
            o.add(Insight(8, "share", INFO, Insight.Mark.Pct,
                t("Stations [y]%lld%%[/y] · Runs %lld%% · Roxzone %lld%%", sp, rp, xp),
                if (sp > rp) t("Stations are your bigger lever.") else t("Runs are your bigger lever.")))
            stations.maxByOrNull { it.time }?.let { lg ->
                val pc = (lg.time / tot * 100).r()
                o.add(Insight(24, "share", INFO, Insight.Mark.Time,
                    t("[y]%@[/y] was your longest station (%@) — %lld%% of your total.", lg.name, Fm.t(lg.time), pc)))
            }
        }
        if (r.mode == Mode.Sim && s16 != null) {
            val hist = before.filter { it.mode == Mode.Sim }.sortedBy { it.date }.mapNotNull { it.splits16 }
            // 25 3번 연속 좋아짐
            if (hist.size >= 3) {
                val last3 = hist.takeLast(3) + listOf(s16)
                for (i in 1 until 16 step 2) {
                    val v = last3.map { it[i] }
                    if (v[1] < v[0] && v[2] < v[1] && v[3] < v[2]) {
                        o.add(Insight(25, "streak", TREND, Insight.Mark.Up,
                            t("Your [y]%@[/y] has improved [g]3 times in a row[/g].", main[i].name)))
                        break
                    }
                }
            }
            // 26 들쭉날쭉한 스테이션 (최근 5번)
            val last5 = hist.takeLast(4) + listOf(s16)
            if (last5.size >= 4) {
                var wi = -1
                var wv = 0
                for (i in 1 until 16 step 2) {
                    val v = last5.map { it[i] }
                    val half = (v.max() - v.min()) / 2
                    if (half > wv) { wv = half; wi = i }
                }
                if (wi >= 0 && wv >= 20) {
                    o.add(Insight(26, "streak", INFO, Insight.Mark.Info,
                        t("[y]%@[/y] varies the most between your sims (±%llds).", main[wi].name, wv),
                        t("Steady pacing there is easy time.")))
                }
            }
        }
        // 28 횟수 속도 (참고값)
        val rep = r.mainSegs.firstOrNull { it.reps != null && it.time > 0 }
        val n = rep?.reps
        if (rep != null && n != null && n > 0) {
            if (rep.icon == "wallBalls") {
                val per = rep.time.toDouble() / n
                o.add(Insight(28, "reps", INFO, Insight.Mark.Info,
                    t("[y]%@[/y]: about one rep every %@s.", rep.name, "%.1f".format(java.util.Locale.ROOT, per))))
            } else {
                val spm = (n * 60.0 / rep.time).r()
                o.add(Insight(28, "reps", INFO, Insight.Mark.Info, t("[y]%@[/y]: about %lld strokes a minute.", rep.name, spm)))
            }
        }

        // ── Roxzone ──
        val rox = r.segs.filter { it.kind == SegKind.Rox }
        if (rox.isNotEmpty()) {
            val share = r.roxTotal.toDouble() / maxOf(1, r.total)
            if (share >= 0.08) {
                o.add(Insight(9, "rox", BIG, Insight.Mark.Time,
                    t("Roxzone took [r]%@[/r]. Faster transitions are free time.", Fm.t(r.roxTotal))))
            } else {
                val avg = r.roxTotal / rox.size
                o.add(Insight(29, "rox", INFO, Insight.Mark.Info, t("Average Roxzone: [y]%llds[/y].", avg),
                    if (avg > 30) t("Under 30s is a good target.") else null))
            }
        } else if (r.mode == Mode.Sim && s16 != null) {
            o.add(Insight(30, "rox", INFO, Insight.Mark.Info,
                t("Add ~4 min of Roxzone and a race would be about [y]%@[/y].", Fm.t(r.total + 240))))
        }

        // ── 심박 ──
        if (r.hr.size > 1) {
            CheerPicker.hiShare(r.hr, st)?.let { hi ->
                val p = (hi * 100).r()
                if (p >= 40) o.add(Insight(10, "hr", INFO, Insight.Mark.Heart, t("[y]%lld%%[/y] of the time in Z4–Z5.", p)))
            }
            if (r.maxHR > 0) {
                val pc = (r.maxHR.toDouble() / maxOf(1, st.maxHR) * 100).r()
                if (pc >= 95) o.add(Insight(33, "hr", TREND, Insight.Mark.Heart, t("You touched [r]%lld%%[/r] of your max heart rate.", pc)))
            }
            // 31 후반 심박 상승 (페이스는 비슷)
            val pts = r.hr.sortedBy { it.t }
            val half = r.total / 2
            val a = pts.filter { it.t < half }.map { it.b }
            val b = pts.filter { it.t >= half }.map { it.b }
            if (a.size >= 3 && b.size >= 3 && runs.size >= 4) {
                val rise = b.sum() / b.size - a.sum() / a.size
                val ps = runs.map { r.pace(it) }
                val h = ps.size / 2
                val pd = ps.takeLast(ps.size - h).sum() / maxOf(1, ps.size - h) - ps.take(h).sum() / maxOf(1, h)
                if (rise >= 10 && abs(pd) <= 10) {
                    o.add(Insight(31, "hr", TREND, Insight.Mark.Heart,
                        t("Heart rate rose [r]%lld bpm[/r] in the second half while your pace held.", rise)))
                }
            }
            val withHR = main.filter { (it.hr ?: 0) > 0 }
            withHR.maxByOrNull { it.hr ?: 0 }?.let { pk ->
                o.add(Insight(11, "hr", INFO, Insight.Mark.Heart, t("Heart rate peaked on [y]%@[/y] (%lld).", pk.name, pk.hr ?: 0)))
            }
            val stHR = withHR.filter { it.kind == SegKind.St }
            if (stHR.size >= 4) {
                stHR.minByOrNull { it.hr ?: 0 }?.let { lo ->
                    o.add(Insight(32, "hr", INFO - 1, Insight.Mark.Heart,
                        t("Your heart rate was lowest on [y]%@[/y] (%lld) — room to push there.", lo.name, lo.hr ?: 0)))
                }
            }
        }

        // ── PFT ──
        val ps6 = r.pftSplits
        if (r.mode == Mode.Pft && ps6 != null) {
            val g = PFT.grade(r.total)
            if (g != PFTGrade.Gold) {
                val gap = r.total - (PFT.goldLimit - 1)
                val each = ceilDiv(gap, PFT.items.size)
                o.add(Insight(12, "pft", if (gap <= 30) BIG else TREND, Insight.Mark.Star, t("[y]%@[/y] from Gold.", sec(gap)),
                    t("About %lld seconds faster on each movement gets you there.", each)))
            } else if (PFT.goldLimit - r.total >= 30) {
                o.add(Insight(39, "pft", BIG, Insight.Mark.Star, t("Gold with [g]%@[/g] to spare.", sec(PFT.goldLimit - r.total))))
            }
            val d = ps6.indices.map { ps6[it] - PFT.items[it].target }
            val wi = d.indices.maxByOrNull { d[it] }!!
            if (d[wi] >= MIN_DIFF) {
                o.add(Insight(13, "pft2", INFO, Insight.Mark.Down,
                    t("Most room: [y]%@[/y], [r]+%llds[/r] on Gold pace.", PFT.items[wi].name, d[wi])))
            }
            val bi = d.indices.minByOrNull { d[it] }!!
            if (d[bi] <= -MIN_DIFF) {
                o.add(Insight(14, "pft3", INFO, Insight.Mark.Up,
                    t("Strongest: [y]%@[/y], [g]%llds under[/g] Gold pace.", PFT.items[bi].name, -d[bi])))
            }
            val l = before.filter { it.mode == Mode.Pft }.maxByOrNull { it.date }?.pftSplits
            if (l != null) {
                val dd = ps6.indices.map { ps6[it] - l[it] }
                val gi = dd.indices.minByOrNull { dd[it] }!!
                if (dd[gi] <= -MIN_DIFF) {
                    o.add(Insight(38, "last", if (dd[gi] <= -30) BIG else INFO, Insight.Mark.Up,
                        t("Biggest gain since last PFT: [y]%@[/y], [g]−%llds[/g].", PFT.items[gi].name, -dd[gi])))
                }
            }
        }

        // ── 트레이닝 ──
        if (r.mode == Mode.Training && !r.isBonus) {
            val sets = maxOf(1, r.sets)
            if (sets >= 2 && main.size % sets == 0) {
                val per = main.size / sets
                val tots = (0 until sets).map { k -> main.subList(k * per, (k + 1) * per).sumOf { it.time } }
                val joined = tots.joinToString(" · ") { Fm.t(it) }
                if (tots.last() - tots.first() >= 60) {
                    o.add(Insight(15, "sets", BIG, Insight.Mark.Down,
                        t("Set %lld was [r]%@[/r] slower than set 1.", sets, sec(tots.last() - tots.first()))))
                } else if (tots.max() - tots.min() <= 30) {
                    o.add(Insight(15, "sets", INFO, Insight.Mark.Even, t("%lld sets, very even: [y]%@[/y]", sets, joined)))
                }
                // 27 세트마다 느려진 종목
                if (sets >= 3) {
                    for (j in 0 until per) {
                        if (main[j].kind != SegKind.St) continue
                        val v = (0 until sets).map { main[it * per + j].time }
                        if (v.zipWithNext().all { (x, y) -> y > x } && v.last() - v.first() >= MIN_DIFF) {
                            o.add(Insight(27, "streak", TREND, Insight.Mark.Down,
                                t("[y]%@[/y] got slower each set: [r]%@[/r].", main[j].name, v.joinToString(" → ") { Fm.t(it) })))
                            break
                        }
                    }
                }
            }
            before.filter { it.mode == Mode.Training && it.title == r.title && it.sets == r.sets }.maxByOrNull { it.date }?.let { last ->
                val d = r.total - last.total
                if (abs(d) >= MIN_DIFF) {
                    o.add(Insight(16, "last", if (abs(d) >= 30) BIG else INFO, if (d < 0) Insight.Mark.Up else Insight.Mark.Down,
                        if (d < 0) t("[g]%@ faster[/g] than last time on this training.", sec(d))
                        else t("[r]%@ slower[/r] than last time on this training.", sec(d))))
                }
            }
        }

        // ── 목표 · 흐름 ──
        if (fullRace && r.counts) {
            val goal = if (r.mode == Mode.Race) (r.goal ?: st.goalTime) else st.goalTime
            val d = r.total - goal
            if (d >= MIN_DIFF && goal > 0) {
                o.add(Insight(34, "goal", INFO, Insight.Mark.Time,
                    t("To hit [y]%@[/y]: about %llds faster on each split.", Fm.t(goal), ceilDiv(d, 16))))
            }
        }
        if (r.counts && r.mode != Mode.Training) {
            val same = before.filter { it.mode == r.mode && (r.mode != Mode.Sim || it.splits16 != null) }.sortedBy { it.date }
            val last3 = same.takeLast(2).map { it.total } + r.total
            if (last3.size == 3 && last3[1] < last3[0] && last3[2] < last3[1]) {
                val word = when (r.mode) { Mode.Sim -> t("sims"); Mode.Race -> t("races"); else -> "PFTs" }
                o.add(Insight(35, "trend", TREND, Insight.Mark.Up,
                    t("Your last 3 %@: %@. [g]Trending down.[/g]", word, last3.joinToString(" → ") { Fm.t(it) })))
            }
            val best = same.minOfOrNull { it.total }
            if (best != null && r.total - best >= MIN_DIFF) {
                o.add(Insight(36, "trend", INFO, Insight.Mark.Info, t("[y]%@[/y] off your best.", sec(r.total - best))))
            }
        }
        if (r.mode == Mode.Sim && st.event.isSet) {
            val day = r.date.localDate()
            val days = ChronoUnit.DAYS.between(day, st.event.date.localDate()).toInt()
            if (days in 1..30) {
                val month = (before + r).count { it.mode == Mode.Sim && it.date.localDate().let { d -> d.year == day.year && d.month == day.month } }
                o.add(Insight(37, "race", INFO, Insight.Mark.Time,
                    t("[y]%lld days[/y] to race. Your full sim #%lld this month.", days, month)))
            }
        }

        // ── 친구 · 파트너 · 시간대 ──
        val f = book.friend
        if (r.mode == Mode.Sim && s16 != null && f != null && f.hasSplits) {
            val won = (1 until 16 step 2).count { s16[it] < f.splits[it] }
            val behind = r.total - f.total
            if (behind >= MIN_DIFF) {
                val gaps = (0 until 16).map { s16[it] - f.splits[it] }
                val wi = gaps.indices.maxByOrNull { gaps[it] }!!
                if (gaps[wi] >= MIN_DIFF) {
                    o.add(Insight(40, "friend", TREND, Insight.Mark.Info,
                        t("You're [r]%@[/r] behind @%@ — most of it on [y]%@[/y] (%llds).", sec(behind), f.name, main[wi].name, gaps[wi])))
                }
            } else {
                o.add(Insight(17, "friend", INFO, Insight.Mark.Up, t("You beat @%@ on [g]%lld of 8[/g] stations.", f.name, won)))
            }
        }
        val p = r.partner
        if (!p.isNullOrEmpty()) {
            val cnt = (before + r).count { it.partner == p }
            if (cnt >= 2) o.add(Insight(41, "friend", INFO - 1, Insight.Mark.Info, t("With @%@: your session #%lld together.", p, cnt)))
        }
        if (r.mode == Mode.Sim || r.mode == Mode.Pft) {
            val all = (before + r).filter { it.mode == r.mode }
            val am = all.filter { it.date.atZone(Fm.zone).hour < 12 }.map { it.total }
            val pm = all.filter { it.date.atZone(Fm.zone).hour >= 12 }.map { it.total }
            if (am.size >= 3 && pm.size >= 3) {
                val d = am.sum() / am.size - pm.sum() / pm.size
                if (abs(d) >= MIN_DIFF) {
                    o.add(Insight(42, "time", INFO - 2, Insight.Mark.Time,
                        if (d < 0) t("You're faster in the morning — [g]−%@[/g] on average.", sec(d))
                        else t("You're faster in the afternoon — [g]−%@[/g] on average.", sec(d))))
                }
            }
        }
        if (r.mode == Mode.Training && r.isRunKind) o.addAll(runMode(r))
        return o
    }

    /** 러닝 카드 기록만의 분석 (오르막 · 칼로리 · 케이던스 · 후반 페이스) */
    private fun runMode(r: Record): List<Insight> {
        val o = ArrayList<Insight>()
        val kms = r.runs.withIndex().filter { (it.value.dist ?: runMeters(it.value.detail)) >= 500 }
        val avg = r.avgKmPace

        val total = r.ascent
        if (total != null) {
            val climbs = kms.mapNotNull { k -> k.value.up?.let { Triple(k.index, k.value, it) } }
            val top = climbs.maxByOrNull { it.third }
            if (top != null && top.third >= 10 && avg != null) {
                val d = r.pace(top.second) - avg
                val up = top.third.r()
                if (d >= MIN_DIFF) {
                    o.add(Insight(43, "elev", if (d >= 15) TREND else INFO + 1, Insight.Mark.Down,
                        t("Biggest climb: [y]km %lld[/y] (+%lld m) — [r]%llds slower[/r] than your average km.", top.first + 1, up, d)))
                } else {
                    o.add(Insight(43, "elev", if (up >= 15) TREND else INFO + 1, Insight.Mark.Up,
                        t("Biggest climb: [y]km %lld[/y] (+%lld m) — and you [g]held your pace[/g].", top.first + 1, up)))
                }
            }
            val cl = RunMetrics.segClimbs(r.route, r.segs.map { it.time })
            if (cl != null && cl.size == r.segs.size && kms.size >= 3) {
                val runIdx = r.segs.indices.filter { r.segs[it].kind == SegKind.Run }
                val fst = kms.minByOrNull { r.pace(it.value) }
                if (fst != null && fst.index in runIdx.indices) {
                    val down = cl[runIdx[fst.index]].down.r()
                    if (down >= 10) {
                        o.add(Insight(44, "elev", INFO, Insight.Mark.Info,
                            t("Your fastest km, [y]km %lld[/y], was mostly downhill (−%lld m).", fst.index + 1, down)))
                    }
                }
            }
            val tt = total.r()
            if (tt >= 10) o.add(Insight(45, "elev", INFO - 1, Insight.Mark.Up, t("[y]+%lld m[/y] of climbing on this run.", tt)))
        }

        val km = r.runDistance / 1000
        if (r.kcal > 0 && km >= 1 && r.total > 0) {
            val perKm = (r.kcal / km).r()
            val perHour = (r.kcal * 3600.0 / r.total).r()
            o.add(Insight(46, "kcal", INFO - 1, Insight.Mark.Info, t("[y]%lld kcal[/y] per km · %lld kcal per hour.", perKm, perHour)))
        }

        val cads = kms.mapNotNull { it.value.cad }
        if (cads.size >= 3) {
            val third = maxOf(1, cads.size / 3)
            val early = cads.take(third).sum() / third
            val late = cads.takeLast(third).sum() / third
            if (early - late >= 5) {
                o.add(Insight(48, "cad", TREND, Insight.Mark.Down,
                    t("Cadence dropped [r]%lld spm[/r] in the last third (%lld → %lld).", early - late, early, late),
                    t("Quick, short steps help when your legs get tired.")))
            }
        }
        r.cadence?.let { o.add(Insight(47, "cad", INFO - 1, Insight.Mark.Info, t("Average cadence: [y]%lld spm[/y].", it))) }

        if (kms.size >= 4) {
            val ps = kms.map { r.pace(it.value) }
            val h = ps.size / 2
            val first = ps.take(h).sum() / h
            val second = ps.takeLast(ps.size - h).sum() / (ps.size - h)
            val d = second - first
            when {
                d <= -MIN_DIFF -> o.add(Insight(49, "run2", TREND, Insight.Mark.Up,
                    t("[g]Negative split[/g] — your second half was %llds/km faster.", -d)))
                d < MIN_DIFF -> o.add(Insight(49, "run2", INFO, Insight.Mark.Even,
                    t("You held your pace — both halves within [g]%llds/km[/g].", abs(d))))
                d >= 15 -> o.add(Insight(49, "run2", INFO, Insight.Mark.Down,
                    t("Your second half was [r]%llds/km slower[/r] than the first.", d)))
            }
        }
        return o
    }
}
