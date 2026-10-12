package com.nkssi.splits8.shared

import java.time.Instant
import kotlin.math.abs
import kotlin.math.floor

// 운동이 끝났을 때 한 줄 멘트 (아이폰 Shared/Cheer.swift).
// 위에서부터 먼저 맞는 것 하나를 고름 (23가지 + PFT 10가지). 같은 기록은 언제 열어도 같은 문장.

data class CheerInput(
    val mode: Mode,
    val title: String,
    val total: Int,
    val complete: Boolean,
    /** 너무 빠른 구간이 있음 (Record.flag == Check) */
    val check: Boolean,
    val start: Instant,
    val end: Instant,
    val seed: Int,
    val isHIIT: Boolean = false,
    val isRun: Boolean = false,
    val hiitRounds: Int = 0,
    val runKm: Double = 0.0,
    /** 높은 심박(Z4–Z5) 비율 0…1. 심박이 없으면 null */
    val hiShare: Double? = null,
    // 폰이 기록 목록으로 채우는 것 (워치는 비워 둠)
    val firstEver: Boolean = false,
    val firstFullSim: Boolean = false,
    /** 레이스 목표와의 차이 (total − goal). 음수 = 목표보다 빠름 */
    val goalDelta: Int? = null,
    /** 이번이 최고 기록이면 이전 최고와의 차이 (음수) */
    val pbDelta: Int? = null,
    /** 지난번(같은 종류)과의 차이 */
    val lastDelta: Int? = null,
    /** 이번에 최고 기록이 된 스테이션 이름 */
    val segBest: String? = null,
    val daysToRace: Int? = null,
    val daysSinceLast: Int? = null,
    val streak: Int = 0,
    val weekCount: Int = 0,
    /** PFT: 이전 최고 총 시간 (null = 첫 도전) */
    val pftPrevBest: Int? = null,
    val pftEverGold: Boolean = false,
)

data class Cheer(val line: String, val tone: Tone, val tag: String? = null) {
    enum class Tone { Celebrate, Normal, Check }
}

object CheerPicker {
    fun pick(x: CheerInput): Cheer {
        // 같은 경우에 문장이 둘이면 기록마다 번갈아
        fun alt(a: String, b: String) = if (abs(x.seed) % 2 == 0) a else b
        val n = Cheer.Tone.Normal
        val c = Cheer.Tone.Celebrate

        if (x.check) return Cheer(L10n.t("Saved. A few splits look off."), Cheer.Tone.Check, "CHECK")
        if (!x.complete) return Cheer(L10n.t("Ended early. All the way next time."), n)

        if (x.mode == Mode.Pft) return pft(x)

        if (x.firstEver) {
            return Cheer(alt(L10n.t("Your first record. Welcome to SPLITS8."), L10n.t("Day one. Every split counts from here.")), c, "FIRST")
        }
        if (x.mode == Mode.Race && x.goalDelta != null && x.goalDelta < 0) {
            return Cheer(L10n.t("Goal beaten by %@. Great race.", Fm.t(-x.goalDelta)), c, "GOAL")
        }
        if (x.mode == Mode.Race) {
            return Cheer(alt(L10n.t("Race done. You did it."), L10n.t("That's a race in the books.")), c, "FINISHER")
        }
        if (x.pbDelta != null && x.pbDelta < 0) {
            return Cheer(alt(L10n.t("New personal best!"), L10n.t("Faster than ever. −%@.", Fm.t(-x.pbDelta))), c, "★ PB")
        }
        if (x.firstFullSim && x.mode == Mode.Sim) {
            return Cheer(L10n.t("All 16 splits. Your first full sim."), c, "FIRST")
        }

        x.segBest?.let { return Cheer(L10n.t("New best on %@.", it.l10n), n) }
        if (x.mode == Mode.Sim && x.lastDelta != null && x.lastDelta <= -5) {
            return Cheer(L10n.t("%@ faster than last time.", Fm.t(-x.lastDelta)), n)
        }
        if (x.isRun) {
            val km = floor(x.runKm).toInt()
            if (km in listOf(5, 10, 21, 42) || (km >= 10 && km % 5 == 0)) return Cheer(L10n.t("%lld km done.", km), n)
        }
        if (x.isHIIT && x.hiitRounds >= 10) return Cheer(L10n.t("%lld rounds. Strong finish.", x.hiitRounds), n)

        if (x.daysToRace != null && x.daysToRace in 1..7) {
            return Cheer(L10n.t("%lld days to race day. Stay sharp.", x.daysToRace), n)
        }
        if (x.daysSinceLast != null && x.daysSinceLast >= 14) {
            return Cheer(alt(L10n.t("Welcome back."), L10n.t("Good to see you again.")), n)
        }
        if (x.streak >= 3) return Cheer(L10n.t("%lld days in a row. Keep it going.", x.streak), n)
        if (x.weekCount >= 3) return Cheer(L10n.t("Workout %lld this week.", x.weekCount), n)
        if (x.start.atZone(Fm.zone).hour < 7) return Cheer(L10n.t("Early start. Nice work."), n)
        val endH = x.end.atZone(Fm.zone).hour
        if (endH >= 22 || endH < 3) return Cheer(L10n.t("Late session done. Rest well."), n)

        if (x.total >= 60 * 60) return Cheer(L10n.t("Over an hour. Serious work."), n)
        if (x.total >= 30 * 60 || (x.hiShare ?: 0.0) >= 0.5) {
            return Cheer(alt(L10n.t("That was a tough one."), L10n.t("You pushed hard today.")), n)
        }
        if (x.total >= 10 * 60) return Cheer(alt(L10n.t("Nice work."), L10n.t("Another one in the books.")), n)
        return Cheer(alt(L10n.t("Good start."), L10n.t("Short, but it counts.")), n)
    }

    /** PFT 10가지 (위에서부터 먼저 맞는 것) */
    private fun pft(x: CheerInput): Cheer {
        val g = PFT.grade(x.total)
        val tag = g.label
        val c = Cheer.Tone.Celebrate
        val n = Cheer.Tone.Normal
        val prev = x.pftPrevBest ?: return when (g) {
            PFTGrade.Gold -> Cheer(L10n.t("Gold on your first try. Impressive."), c, tag)
            PFTGrade.Silver -> Cheer(L10n.t("Silver on your first try. Strong start."), c, tag)
            PFTGrade.Bronze -> Cheer(L10n.t("Bronze on your first try. Not bad at all."), c, tag)
        }
        val pg = PFT.grade(prev)
        fun rank(v: PFTGrade) = when (v) { PFTGrade.Gold -> 2; PFTGrade.Silver -> 1; PFTGrade.Bronze -> 0 }
        if (g == PFTGrade.Gold && !x.pftEverGold) return Cheer(L10n.t("Gold. Well earned."), c, tag)
        if (rank(g) > rank(pg)) return Cheer(L10n.t("Up to %@. Gold is next.", g.word.l10n), c, tag)
        if (g != PFTGrade.Gold) {
            val limit = if (g == PFTGrade.Silver) PFT.goldLimit - 1 else PFT.silverLimit
            val gap = x.total - limit
            if (gap in 1..30) {
                val next = if (g == PFTGrade.Silver) PFTGrade.Gold else PFTGrade.Silver
                return Cheer(L10n.t("%@ — just %llds from %@.", g.word.l10n, gap, next.word.l10n), n, tag)
            }
        }
        if (rank(g) == rank(pg) && x.total < prev && g != PFTGrade.Gold) {
            return Cheer(L10n.t("Still %@, but %@ faster.", g.word.l10n, Fm.t(prev - x.total)), n, tag)
        }
        if (g == PFTGrade.Gold) return Cheer(L10n.t("Gold again. Consistent."), c, tag)
        if (rank(g) < rank(pg)) return Cheer(L10n.t("%@ this time. Every test counts.", g.word.l10n), n, tag)
        return Cheer(L10n.t("%@. Nice work.", g.word.l10n), n, tag)
    }

    /** 기록 id → 늘 같은 숫자 (아이폰과 같은 계산: 대문자 UUID 글자 × 31) */
    fun seed(id: String): Int {
        var h = 0L
        for (ch in id.uppercase()) h = (h * 31 + ch.code) and 0x7FFF_FFFFL
        return h.toInt()
    }

    /** 높은 심박(Z4–Z5) 비율 */
    fun hiShare(hr: List<HRPoint>, settings: Settings): Double? {
        val p = hr.sortedBy { it.t }
        if (p.size <= 1) return null
        var hi = 0
        var all = 0
        for (i in 0 until p.size - 1) {
            val dt = minOf(30, maxOf(0, p[i + 1].t - p[i].t))
            all += dt
            if (settings.zone(p[i].b.toDouble()) >= 4) hi += dt
        }
        return if (all > 0) hi.toDouble() / all else null
    }
}
