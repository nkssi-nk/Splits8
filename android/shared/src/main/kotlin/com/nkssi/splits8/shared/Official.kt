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

    /** 줄 안의 순위 숫자 (시간 글자 · 이름표를 뺀 뒤 첫 정수) */
    fun rankNum(line: String): Int? {
        val noTime = line.replace(TIME, " ")
        val after = noTime.replace(Regex("""(?i)rank\s*\((?:m/?w|ag)\)|rank|순위|\(m/?w\)|\(ag\)"""), " ")
        return Regex("""\d{1,6}""").find(after)?.value?.toIntOrNull()?.takeIf { it > 0 }
    }

    private fun has(l: String, p: String) = Regex(p, RegexOption.IGNORE_CASE).containsMatchIn(l)

    /** 스테이션 이름 → Station.all 순서 (0~7) */
    private val stKeys = listOf(
        1 to """sled\s*push""", 2 to """sled\s*pull""", 0 to """ski\s*-?\s*erg""", 3 to "burpee",
        4 to """\brow(ing)?\b""", 5 to "farmer", 6 to "lunge", 7 to """wall\s*-?\s*ball""",
    )

    fun parse(text: String): Draft {
        val lines = text.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        var total: Int? = null
        var rank: Int? = null
        var ageRank: Int? = null
        val runs = MutableList<Int?>(8) { null }
        val st = MutableList<Int?>(8) { null }
        var rox: Int? = null
        val all = ArrayList<Int>()
        val runRe = Regex("""(?i)\brun(?:ning)?\s*([1-8])\b|러닝\s*([1-8])""")
        for ((i, l) in lines.withIndex()) {
            var ts = times(l)
            if (ts.isEmpty() && i + 1 < lines.size) ts = times(lines[i + 1])      // 이름과 시간이 다른 줄로 읽힌 경우
            all.addAll(times(l))
            if (has(l, "rank|순위")) {
                val n = rankNum(l) ?: if (i + 1 < lines.size && times(lines[i + 1]).isEmpty()) rankNum(lines[i + 1]) else null
                if (has(l, """\(\s*ag\s*\)|age\s*group|나이""")) { if (ageRank == null) ageRank = n }
                else if (rank == null) rank = n
                continue
            }
            val rm = runRe.find(l)
            if (rm != null && ts.isNotEmpty()) {
                val k = (rm.groupValues[1].ifEmpty { rm.groupValues[2] }).toIntOrNull()
                if (k != null && k in 1..8 && runs[k - 1] == null) runs[k - 1] = ts[0]
                continue
            }
            if (has(l, """\brun(ning)?\b|러닝""") && !has(l, "rox")) continue      // Run Total · Best Run Lap
            if (has(l, """rox\s*zone|록스존""")) { if (rox == null) rox = ts.firstOrNull(); continue }
            val k = stKeys.firstOrNull { has(l, it.second) }
            if (k != null) { if (st[k.first] == null) st[k.first] = ts.firstOrNull(); continue }
            if (has(l, """(overall|finish|final|total)\s*time|^total\b|^time\b|완주""") && !has(l, "rox|run")) {
                ts.maxOrNull()?.let { total = maxOf(total ?: 0, it) }
            }
        }
        if (total == null) total = all.filter { it in 40 * 60..4 * 3600 }.maxOrNull()
        // 말이 안 되는 값 빼기 (러닝 2~20분, 스테이션 30초~20분, Roxzone 1~25분)
        for (i in 0 until 8) {
            runs[i]?.let { if (it < 120 || it > 1200) runs[i] = null }
            st[i]?.let { if (it < 30 || it > 1200) st[i] = null }
        }
        rox?.let { if (it < 60 || it > 1500) rox = null }
        return Draft(total, rank, ageRank, runs, st, rox)
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
