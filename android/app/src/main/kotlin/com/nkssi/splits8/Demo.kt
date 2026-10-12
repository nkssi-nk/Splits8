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
                segs.add(SegResult("roxzone", "Roxzone", "TRANSITION", SegKind.Rox, 18, 30, hr = 150))
                val st = Station.all[i]
                val reps = mapOf("skiErg" to 118, "row" to 104, "wallBalls" to 97)[st.key]
                segs.add(SegResult(st.key, st.name, st.detail(div), SegKind.St, s, Defaults.stationGoals[i], hr = 165 + (i % 4) * 4, reps = reps))
                if (i < 7) segs.add(SegResult("roxzone", "Roxzone", "TRANSITION", SegKind.Rox, 18, 30, hr = 150))
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
}
