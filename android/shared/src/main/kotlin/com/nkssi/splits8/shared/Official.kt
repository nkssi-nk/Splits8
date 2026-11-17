package com.nkssi.splits8.shared

import kotlinx.serialization.Serializable
import java.time.Instant
import kotlin.math.abs

// 1.2.4 · 공식 결과 (대회 결과 캡처 글자 읽기 → 공식 기록). 아이폰 Shared/HyroxRank.swift 아래쪽과 같음

/** 1.2.4: 대회 공식 결과로 넣은 기록. 대략 상위 % 는 RecordBook.kt HyroxRank (80번) 그대로 */
val Record.isOfficial: Boolean get() = official != null

/** 1.2.4 · 공식 기록 (대회 공식 결과 캡처에서 읽은 값, 사용자가 확인 · 고친 것). 아이폰 OfficialResult 와 같은 이름 */
@Serializable
data class OfficialResult(
    /** Rank (M/W) — 같은 디비전 · 성별 안 순위 */
    val rank: Int? = null,
    /** Rank (AG) — 나이대 순위 */
    val ageRank: Int? = null,
    /** 참가 인원 (선택, 사용자가 넣음) → 상위 % */
    val field: Int? = null,
    /** 공식 완주 시간(초) */
    val time: Int,
    val event: String,
    val division: String,
) {
    val topPct: Double?
        get() {
            val r = rank ?: return null
            val f = this.field ?: return null   // "field" 만 쓰면 Kotlin 의 뒷받침 필드로 읽힘
            if (f <= 0 || r <= 0 || r > f) return null
            return r.toDouble() / f * 100
        }
}

/**
 * 공식 결과 캡처의 글자 → 값. 홈페이지 ocr.js 와 같은 규칙 + 순위 (Rank (M/W) · Rank (AG)).
 * results.hyrox.com: "Running 1 00:03:09" · "1000m SkiErg 00:04:07 45" · "Roxzone Time" · "Overall Time 01:06:47" · "Rank (M/W) 90"
 */
object OfficialParse {
    data class Draft(
        val total: Int? = null,
        val rank: Int? = null,
        val ageRank: Int? = null,
        val runs: List<Int?> = List(8) { null },
        val st: List<Int?> = List(8) { null },
        val rox: Int? = null,
        /** 1.2.5: 화면에서 읽은 디비전 이름 (Division.all 이름, 모르면 null) */
        val division: String? = null,
    ) {
    val found: Int get() = listOfNotNull(total, rank, ageRank, rox).size + runs.count { it != null } + st.count { it != null }
    }

    private val TIME = Regex("""(?:\d{1,2}:)?\d{1,2}:\d{2}(?:\.\d+)?""")

    /** 시간 글자 → 초. 0:04:35 · 04:35 · 4:35.2 */
    fun sec(t: String): Int? {
        val parts = t.split(":")
        val p = parts.mapNotNull { it.toDoubleOrNull() }
        if (p.size != parts.size || p.size < 2) return null
        val s = if (p.size == 3) p[0] * 3600 + p[1] * 60 + p[2] else p[0] * 60 + p[1]
        return s.r()
    }

    /** 한 줄의 시간들 (10초 미만 버림). 숫자 사이의 O→0, l·I·|→1 */
    fun times(line: String): List<Int> {
        val l = line.replace(Regex("""\s*:\s*"""), ":").replace(Regex("""[\dOolI|:]{3,}""")) { m ->
            val w = m.value
            if (w.any { it.isDigit() } && w.contains(':')) w.replace(Regex("[Oo]"), "0").replace(Regex("[lI|]"), "1") else w
        }
        return TIME.findAll(l).mapNotNull { sec(it.value) }.filter { it >= 10 }.toList()
    }

    private fun has(l: String, p: String) = Regex(p, RegexOption.IGNORE_CASE).containsMatchIn(l)

    /** 스테이션 이름 → Station.all 순서 (0~7). 공식 결과 페이지 (영어) + 1.2.5: 줄임말 · 한국어 (BBJ · Farmers C. · S. Lunges · 스키 · 슬레드 …) */
    private val stKeys = listOf(
        1 to """sled\s*push|슬레드\s*푸[시쉬]""", 2 to """sled\s*pull|슬레드\s*풀""", 0 to """ski\s*-?\s*erg|스키""",
        3 to """burpee|\bbbj\b|버피""", 4 to """\brow(ing)?\b|로잉""", 5 to """farmer|파머""", 6 to """lunge|런지""",
        7 to """wall\s*-?\s*balls?|월\s*볼""",
    )

    /** 1.2.5: 요약 머리줄 이름표 (TrainRox: "달리기 · 스테이션 · ROXZONE · 페이스" 아래 줄에 값) */
    private val headKeys = listOf("run" to """달리기|run\s*total""", "st" to """스테이션|stations?""",
        "rox" to """rox\s*zone|록스존""", "pace" to """페이스|pace""")

    /** 구간이 아닌 줄 (페이스 · 합계 · 리그 점수) */
    private const val SKIP = """페이스|pace|/\s*km|best\s*run|run\s*total|league|리그"""

    private val RANK = Regex("""(?:rank\s*\(\s*m\s*/?\s*w\s*\)|전체|overall|순위)\s*#?\s*(\d{1,6})""", RegexOption.IGNORE_CASE)
    private val AG = Regex("""(?:rank\s*\(\s*ag\s*\)|age\s*group|나이대?)\s*#?\s*(\d{1,6})|\bAG\s*#\s*(\d{1,6})""", RegexOption.IGNORE_CASE)
    private val RANK_LABEL = Regex("""rank\s*\(\s*(m\s*/?\s*w|ag)\s*\)|^\s*(전체|순위)\s*$""", RegexOption.IGNORE_CASE)
    private val ONLY_NUM = Regex("""^\s*#?\s*(\d{1,6})\s*$""")
    private val RUN = Regex("""\brun(?:ning)?\s*([1-8])\b|러닝\s*([1-8])(?!\d)""", RegexOption.IGNORE_CASE)

    /** 1.2.5: 화면 글자에서 디비전 (Doubles Men · Pro Women …). 모르면 null */
    fun division(text: String): String? {
        val l = text.lowercase()
        val pro = Regex("""\bpro\b""").containsMatchIn(l)
        val women = Regex("""women|여자""").containsMatchIn(l)
        val men = Regex("""\bmen\b|남자""").containsMatchIn(l)
        if (Regex("""doubles?|더블""").containsMatchIn(l)) {
            if (Regex("""mixed|혼성""").containsMatchIn(l)) return "Doubles Mixed"
            if (women) return if (pro) "Doubles Women Pro" else "Doubles Women"
            if (men) return if (pro) "Doubles Men Pro" else "Doubles Men"
            return null
        }
        if (Regex("""relay|릴레이""").containsMatchIn(l)) return null
        if (women) return if (pro) "Pro Women" else "Open Women"
        if (men) return if (pro) "Pro Men" else "Open Men"
        return null
    }

    /**
     * 캡처 글자 → 값. 1.2.5: 공식 결과 사이트(영어) + TrainRox 같은 한국어 화면
     *  - 이름 있는 줄은 이름으로, 이름을 못 읽은 줄은 위에서부터 시간 16개를 러닝 · 스테이션 번갈아 채움
     *  - 요약 줄(달리기 · 스테이션 · ROXZONE · 페이스)은 구간으로 안 잡음 (ROXZONE 만 씀)
     */
    fun parse(text: String): Draft {
        val lines = text.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        var total: Int? = null
        var rank: Int? = null
        var ageRank: Int? = null
        val runs = MutableList<Int?>(8) { null }
        val st = MutableList<Int?>(8) { null }
        var rox: Int? = null
        val all = ArrayList<Int>()
        val seq = ArrayList<Int>()
        for ((i, l) in lines.withIndex()) {
            val ts = times(l)
            all.addAll(ts)
            val next = lines.getOrNull(i + 1)
            // 순위: "Rank (M/W) 90" · "전체 #1141" · "AG #82" (숫자가 다음 줄이면 다음 줄)
            val r = RANK.find(l)?.groupValues?.get(1)?.toIntOrNull()
            val a = AG.find(l)?.let { m -> (m.groupValues[1].ifEmpty { m.groupValues[2] }).toIntOrNull() }
            if (r != null && rank == null) rank = r
            if (a != null && ageRank == null) ageRank = a
            if (r == null && a == null && ts.isEmpty() && next != null && RANK_LABEL.containsMatchIn(l)) {
                val n = ONLY_NUM.find(next)?.groupValues?.get(1)?.toIntOrNull()
                if (n != null && n > 0) { if (has(l, "ag")) { if (ageRank == null) ageRank = n } else if (rank == null) rank = n }
                continue
            }
            if ((r != null || a != null) && ts.isEmpty()) continue
            // 요약 머리줄 (이름표 여럿 · 시간 없음) → 다음 줄 시간과 칸 순서로 맞춤
            val hk = headKeys.mapNotNull { (k, p) -> Regex(p, RegexOption.IGNORE_CASE).find(l)?.let { k to it.range.first } }.sortedBy { it.second }
            if (hk.size >= 2 && ts.isEmpty() && next != null) {
                val nt = times(next)
                if (nt.size >= hk.size) hk.forEachIndexed { j, (k, _) -> if (k == "rox" && rox == null) rox = nt[j] }
                continue
            }
            val tsx = ts.ifEmpty { if (next != null) times(next) else emptyList() }     // 이름과 시간이 다른 줄로 읽힌 경우
            val rm = RUN.find(l)
            if (rm != null && tsx.isNotEmpty()) {
                val k = (rm.groupValues[1].ifEmpty { rm.groupValues[2] }).toIntOrNull()
                if (k != null && k in 1..8 && runs[k - 1] == null) runs[k - 1] = tsx[0]
                if (ts.isNotEmpty()) seq.add(ts[0])
                continue
            }
            if (has(l, SKIP)) continue
            if (has(l, """\brun(ning)?\b|러닝|달리기""") && !has(l, "rox")) continue      // Run Total · Best Run Lap · 표 머리
            if (has(l, """rox\s*zone|록스존""")) { if (rox == null) rox = tsx.firstOrNull(); continue }
            val k = stKeys.firstOrNull { has(l, it.second) }
            if (k != null) {
                if (st[k.first] == null) st[k.first] = tsx.firstOrNull()
                if (ts.isNotEmpty()) seq.add(ts[0])
                continue
            }
            if (has(l, """(overall|finish|final|total)\s*time|^total\b|^time\b|완주""") && !has(l, "rox|run") && ts.isNotEmpty()) {
                total = maxOf(total ?: 0, ts.max())
                continue
            }
            // 이름 없는 줄: 구간 시간 하나면 순서 목록에 (완주 시간처럼 큰 값은 빼기)
            if (ts.size == 1 && ts[0] in 20..1200) seq.add(ts[0])
        }
        if (total == null) total = all.filter { it in 40 * 60..4 * 3600 }.maxOrNull()
        // 1.2.5: 이름을 다 못 읽었으면 순서로 — 위에서부터 16개 = 러닝 1 · 스테이션 1 · 러닝 2 …
        val named = runs.count { it != null } + st.count { it != null }
        if (named < 16 && seq.size == 16) {
            for ((j, v) in seq.withIndex()) {
                if (j % 2 == 0) { if (runs[j / 2] == null) runs[j / 2] = v } else { if (st[j / 2] == null) st[j / 2] = v }
            }
        }
        // 말이 안 되는 값 빼기 (러닝 1~20분 — 대회장 러닝이 짧을 수 있음, 스테이션 20초~20분, Roxzone 1~25분)
        for (i in 0 until 8) {
            runs[i]?.let { if (it < 60 || it > 1200) runs[i] = null }
            st[i]?.let { if (it < 20 || it > 1200) st[i] = null }
        }
        rox?.let { if (it < 60 || it > 1500) rox = null }
        return Draft(total, rank, ageRank, runs, st, rox, division(text))
    }

    /** 확인 · 고친 값 → 기록 (레이스 · 공식). 러닝 8 · 스테이션 8 을 하이록스 순서로, 록스존은 맨 뒤에 합 하나 */
    fun record(runs: List<Int>, st: List<Int>, rox: Int, official: OfficialResult, date: Instant): Record {
        val d = Division.of(official.division)
        val segs = ArrayList<SegResult>()
        for (i in 0 until 8) {
            segs.add(SegResult("run", "Run ${i + 1}", "1KM", SegKind.Run, runs[i], 0))
            val s = Station.all[i]
            segs.add(SegResult(s.key, s.name, s.detail(d), SegKind.St, st[i], 0))
        }
        if (rox > 0) segs.add(SegResult("roxzone", "Roxzone", "Transition", SegKind.Rox, rox, 0))
        return Record(
            mode = Mode.Race, title = official.event, date = date, total = official.time, segs = segs, hr = emptyList(),
            kcal = 0, avgHR = 0, maxHR = 0, division = official.division, vsWord = "VS GOAL",
            source = "official", complete = true, official = official,
        )
    }

    @Suppress("unused") private fun near(a: Int, b: Int) = abs(a - b) <= 3
}
