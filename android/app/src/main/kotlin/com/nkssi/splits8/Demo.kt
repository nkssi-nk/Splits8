package com.nkssi.splits8

import com.nkssi.splits8.shared.Defaults
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.Friend
import com.nkssi.splits8.shared.HRPoint
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.RaceEvent
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.SegResult
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.Station
import com.nkssi.splits8.shared.newId
import java.time.Instant
import java.time.LocalDate
import kotlin.math.min
import kotlin.math.sin

/**
 * 화면 확인용 예시 데이터 (아이폰 Demo.swift 와 같은 숫자).
 * 아이폰 화면 사진과 나란히 비교할 수 있게 같은 기록 · 같은 시간으로 채움.
 */
object Demo {
    data class Opts(
        val onboarded: Boolean = true,
        /** 가입한 상태 + 친구 순위표 예시 */
        val friends: Boolean = false,
        /** 대회가 며칠 뒤인지 (null = 대회 없음) */
        val raceDays: Int? = null,
        val pft: Boolean = true,
    )

    fun settings(o: Opts, today: LocalDate): Settings {
        var s = Settings(hasOnboarded = o.onboarded, division = "openM", age = 32, goalTime = 4320, goals = Defaults.goals)
        if (o.raceDays != null) {
            s = s.copy(event = RaceEvent(name = "HYROX Incheon", loc = "Songdo Convensia",
                date = today.plusDays(o.raceDays.toLong()).atStartOfDay(Fm.zone).toInstant()))
        }
        if (o.friends) s = s.copy(nickname = "nkssi", email = "you@example.com", signMethod = "Email code")
        return s
    }

    fun leaderboard(): List<LBRow> = listOf(
        LBRow("demo.1", "jiho", "Open Men", null, 4388),
        LBRow("demo.me", "nkssi", "Open Men", null, 4565),
        LBRow("demo.2", "minseo", "Open Women", null, 4712),
        LBRow("demo.3", "taeyang", "Pro Men", null, 4930),
    )

    fun friends(): List<Friend> = listOf(
        Friend("demo.1", "jiho", "Open Men", "20 Sep 2026", Defaults.goals.map { maxOf(30, it - 8) }),
        Friend("demo.2", "minseo", "Open Women", "", emptyList()),
    )

    /** 받은 응원 예시 (빌드 24, 아이폰 Demo.cheers 와 같음) */
    fun cheers(now: java.time.Instant = java.time.Instant.now()): List<CheerRow> = listOf(
        CheerRow(3, "demo.1", "jiho", null, "pb", now.minusSeconds(600), false),
        CheerRow(2, "demo.2", "minseo", null, "fire", now.minusSeconds(7200), false),
        CheerRow(1, "demo.1", "jiho", null, "race", now.minusSeconds(90000), true),
    )

    fun requests(): List<FriendReq> = listOf(
        FriendReq("demo.4", "hana", "Open Women", null, incoming = true),
        FriendReq("demo.5", "woojin", "Pro Men", null, incoming = false),
    )

    /** 기본 카드 2장 + 16구간짜리 한 장 */
    fun programs(): List<Program> {
        val full = Station.all.flatMap { listOf(ProgItem("run", "1KM"), ProgItem(it.key)) }
        return Program.presets() + Program("demo.full", "Full HYROX", 1, full)
    }

    private fun day(s: String): Instant = Fm.ymdParse(s) ?: Instant.now()

    fun records(o: Opts = Opts()): List<Record> {
        val out = ArrayList<Record>()
        val runs = listOf(261, 275, 280, 278, 281, 284, 287, 292)
        val stT = listOf(252, 198, 281, 255, 268, 112, 276, 335)
        val div = Division.of("openM")
        val base = runs.sum() + stT.sum()

        fun full(mode: Mode, title: String, date: String, want: Int, goal: Int? = null): Record {
            val scale = (want - 15 * 18).toDouble() / base
            val segs = ArrayList<SegResult>()
            for (i in 0 until 8) {
                val r = (runs[i] * scale).toInt()
                val s = (stT[i] * scale).toInt()
                segs.add(SegResult("run", "Run ${i + 1}", "1KM", SegKind.Run, r, 270, hr = 158 + (i % 3) * 3, dist = 1000.0))
                segs.add(SegResult("roxzone", "Roxzone", "Transition", SegKind.Rox, 18, 30, hr = 150))
                val st = Station.all[i]
                val reps = mapOf("skiErg" to 118, "row" to 104, "wallBalls" to 97)[st.key]
                segs.add(SegResult(st.key, st.name, st.detail(div), SegKind.St, s, Defaults.stationGoals[i], hr = 165 + (i % 4) * 4, reps = reps))
                if (i < 7) segs.add(SegResult("roxzone", "Roxzone", "Transition", SegKind.Rox, 18, 30, hr = 150))
            }
            val fix = want - segs.sumOf { it.time }
            val li = segs.indexOfLast { it.kind == SegKind.St }
            segs[li] = segs[li].copy(time = segs[li].time + fix)
            val total = segs.sumOf { it.time }
            val hr = ArrayList<HRPoint>()
            var t = 0
            var i = 0
            while (t <= total) {
                val x = i / 120.0
                val b = 96 + 70 * min(1.0, x * 6)
                val wig = sin(i * 0.9) * 5 + sin(i * 0.23) * 7 + (if ((i / 7) % 2 == 1) 6 else -4)
                hr.add(HRPoint(t, min(186.0, b + wig + x * 10).toInt()))
                t += maxOf(5, total / 120); i++
            }
            return Record(newId(), mode, title, 1, day(date), total, segs, hr, 1042, 164, 183, "openM", goal,
                if (mode == Mode.Race) "VS GOAL" else "VS LAST", goal)
        }
        out.add(full(Mode.Race, "Incheon", "2026-09-13", 4503, 4530))
        out.add(full(Mode.Race, "Seoul", "2026-05-23", 4711, 4580))
        out.add(full(Mode.Race, "Busan", "2026-03-08", 4902, 4680))
        for ((d, tt) in listOf("2026-06-14" to 5050, "2026-07-05" to 4951, "2026-07-26" to 4862, "2026-08-16" to 4787,
            "2026-09-06" to 4667, "2026-09-20" to 4565)) out.add(full(Mode.Sim, "Full Simulation", d, tt))

        fun training(title: String, date: String, total: Int): Record {
            val seq = listOf(
                listOf("run", "Run", "1KM", SegKind.Run, 270), listOf("sledPush", "Sled Push", "50M · 152KG", SegKind.St, 190),
                listOf("run", "Run", "1KM", SegKind.Run, 270), listOf("sledPull", "Sled Pull", "50M · 103KG", SegKind.St, 270),
            )
            val per = total / seq.size
            val segs = seq.map {
                val k = it[3] as SegKind
                SegResult(it[0] as String, it[1] as String, it[2] as String, k, per, it[4] as Int, hr = 160, dist = if (k == SegKind.Run) 1000.0 else null)
            }
            return Record(newId(), Mode.Training, title, 1, day(date), total, segs,
                (0..20).map { HRPoint(it * total / 20, 150 + (it % 5) * 6) }, 412, 161, 176, "openM", null, "VS BEST", null)
        }
        out.add(training("Sled Intervals", "2026-09-24", 1822))
        out.add(training("Wall Ball Run", "2026-09-21", 2410))
        out.add(training("Sled Intervals", "2026-09-17", 1875))

        if (o.pft) {
            val base6 = listOf(262, 236, 188, 245, 82, 295)
            val sum6 = base6.sum()
            fun pft(date: String, want: Int): Record {
                val seq = PFT.seq(div)
                val segs = seq.mapIndexed { i, s ->
                    SegResult(s.icon, s.name, s.detail, s.kind, (base6[i] * want.toDouble() / sum6).toInt(), s.target,
                        hr = 162 + i * 3, dist = if (s.kind == SegKind.Run) 1000.0 else null,
                        reps = mapOf("row" to 96, "wallBalls" to 99)[s.icon])
                }.toMutableList()
                val fix = want - segs.sumOf { it.time }
                segs[segs.size - 1] = segs.last().copy(time = segs.last().time + fix)
                return Record(newId(), Mode.Pft, PFT.title, 1, day(date).plusSeconds(7 * 3600 + 120), want, segs,
                    (0..24).map { HRPoint(it * want / 24, 138 + min(40, it * 4) + (it % 3) * 2) }, 318, 171, 186, "openM",
                    null, "VS BEST", null, complete = true)
            }
            out.add(pft("2026-10-04", 1308))
            out.add(pft("2026-09-12", 1390))
            out.add(pft("2026-08-16", 1655))
        }
        return out
    }

    /**
     * 러닝 기록 화면 확인용 (아이폰 runRecord): 공원 1 km 한 바퀴 코스를 6바퀴 (서울숲 근처).
     * 한쪽에 작은 언덕(4번째 km 는 조금 더 높게) · km 마다 페이스와 케이던스가 조금씩 다름
     */
    fun runRecord(): Record {
        val lat0 = 37.5444
        val lon0 = 127.0374
        val radius = 1000 / (2 * Math.PI)
        val kx = 111_320 * kotlin.math.cos(lat0 * Math.PI / 180)
        val paces = listOf(298, 292, 295, 309, 290, 284)
        val cads = listOf(174, 175, 173, 168, 166, 165)
        val hills = listOf(8.0, 8.0, 8.0, 15.0, 8.0, 8.0)
        val route = ArrayList<com.nkssi.splits8.shared.RoutePt>()
        val segs = ArrayList<SegResult>()
        var t = 0.0
        for (k in 0 until 6) {
            val n = 100
            for (j in 0 until n) {
                val ang = j.toDouble() / n * 2 * Math.PI
                val x = radius * sin(ang)
                val y = radius - radius * kotlin.math.cos(ang)
                val hill = if (ang < Math.PI) hills[k] * sin(ang) else 0.0
                val h = 24 + hill + sin(j * 1.7) * 0.6
                val slope = if (ang < Math.PI) kotlin.math.cos(ang) else 0.0
                val dt = paces[k].toDouble() / n * (1 + 0.18 * slope)
                route.add(com.nkssi.splits8.shared.RoutePt(lat0 + y / 111_320, lon0 + x / kx, h, Math.round(t).toInt()))
                t += dt
            }
            segs.add(SegResult("run", "KM ${k + 1}", "1KM", SegKind.Run, paces[k], 0, hr = 152 + k * 3, dist = 1000.0, cad = cads[k]))
        }
        route.first().let { route.add(it.copy(t = Math.round(t).toInt())) }
        val total = paces.sum()
        val start = day("2026-09-27").plusSeconds(7 * 3600 + 300)
        val r = Record(newId(), Mode.Training, "Easy 6K", 1, start, total, segs,
            (0..30).map { HRPoint(it * total / 30, 138 + min(22, it * 2) + (it % 4) * 2) }, 402, 156, 171, "openM", null,
            "VS BEST", null, complete = true, kind = "run", place = "Seongsu-dong, Seoul", route = route)
        // 오르막 · 구간 오르막 · 보폭은 실제 기록과 같은 계산으로 (걸음 = 케이던스 × 시간)
        val steps = segs.map { (it.cad ?: 0) * it.time / 60.0 }
        return com.nkssi.splits8.shared.RunMetrics.fill(r, steps, null)
    }

    /**
     * 공유 화면 확인용 예시 사진 (아이폰 ShareView.demoPhoto · --sharephoto): 밝고 복잡한 체육관 느낌의 그림.
     * 연기 · 그라데이션 위 글자가 읽히는지 보려고
     */
    fun sharePhoto(): android.graphics.Bitmap {
        val w = 720
        val h = 1280
        val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val c = android.graphics.Canvas(bmp)
        val p = android.graphics.Paint()
        p.shader = android.graphics.LinearGradient(0f, 0f, 0f, h.toFloat(),
            intArrayOf(android.graphics.Color.rgb(219, 219, 219), android.graphics.Color.rgb(140, 153, 168), android.graphics.Color.rgb(77, 77, 77)),
            floatArrayOf(0f, 0.5f, 1f), android.graphics.Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), p)
        p.shader = null
        val rng = com.nkssi.splits8.screens.SeededRandom(99)
        // 천장 조명 줄 · 기둥 · 바닥 선 · 사람 그림자 같은 덩어리
        p.color = android.graphics.Color.argb(217, 255, 255, 255)
        for (i in 0 until 9) {
            val y = (60 + rng.unit() * 30).toFloat()
            c.drawRect(40f + i * 78, y, 84f + i * 78, y + 10, p)
        }
        repeat(26) {
            val bw = (30 + rng.unit() * 150).toFloat()
            val bh = (60 + rng.unit() * 360).toFloat()
            val hue = ((0.05 + rng.unit() * 0.6) * 360).toFloat()
            val sat = (0.25 + rng.unit() * 0.4).toFloat()
            val bri = (0.25 + rng.unit() * 0.7).toFloat()
            p.color = android.graphics.Color.HSVToColor(191, floatArrayOf(hue, sat, bri))
            val x = (rng.unit() * w - 40).toFloat()
            val y = (160 + rng.unit() * 980).toFloat()
            c.drawRect(x, y, x + bw, y + bh, p)
        }
        p.color = android.graphics.Color.argb(230, 20, 20, 20)
        c.drawOval(250f, 330f, 380f, 460f, p)                       // 머리
        c.drawRect(215f, 450f, 415f, 870f, p)                       // 몸
        p.color = android.graphics.Color.argb(128, 255, 255, 255)
        for (i in 0 until 14) c.drawRect(0f, 900f + i * 28, w.toFloat(), 903f + i * 28, p)
        return bmp
    }
}
