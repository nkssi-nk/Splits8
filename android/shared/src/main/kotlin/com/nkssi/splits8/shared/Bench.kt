package com.nkssi.splits8.shared

/** 표 한 줄: band = 완주 시간(분), run = 1km 러닝(초), st = 스테이션 8개(초, 대회 순서), rox = Roxzone 8개 합(초) */
data class BenchRow(val band: Int, val run: Int, val st: List<Int>, val rox: Int)

/** 아이폰 HyroxBench (Shared/Benchmarks.swift) — 실제 대회 완주 시간대별 중간값. 표 숫자는 BenchData.kt (자동 생성) */
object HyroxBench {
    private class Row(val run: Double, val st: List<Double>, val rox: Double)

    /** 디비전 키("openM") 또는 이름("Open Men") → 표. 모르는 값은 Open Men */
    fun table(division: String): List<BenchRow> = when (Division.of(division).key) {
        "openW" -> BenchData.openWomen
        "proM" -> BenchData.proMen
        "proW" -> BenchData.proWomen
        "dblM" -> BenchData.doublesMen
        "dblW" -> BenchData.doublesWomen
        "dblX" -> BenchData.doublesMixed
        "dblMP" -> BenchData.proDoublesMen
        "dblWP" -> BenchData.proDoublesWomen
        else -> BenchData.openMen
    }

    /** 완주 시간(초)에 맞는 줄: 두 시간대 사이는 비례로 섞고, 범위 밖이면 끝 줄을 시간 비율로 늘리거나 줄임 */
    private fun row(division: String, finish: Int): Row {
        val t = table(division)
        val first = t.firstOrNull()
        val last = t.lastOrNull()
        if (first == null || last == null) {
            return Row(270.0, Defaults.stationGoals.map { it.toDouble() }, (8 * Defaults.roxTarget).toDouble())
        }
        val m = finish / 60.0
        fun scaled(r: BenchRow, f: Double) = Row(r.run * f, r.st.map { it * f }, r.rox * f)
        if (m <= first.band) return scaled(first, m / first.band)
        if (m >= last.band) return scaled(last, m / last.band)
        for (i in 0 until t.size - 1) {
            val a = t[i]
            val b = t[i + 1]
            if (m < a.band || m > b.band) continue
            val f = (m - a.band) / maxOf(1, b.band - a.band)
            return Row(
                a.run + (b.run - a.run) * f,
                (0 until 8).map { a.st[it] + (b.st[it] - a.st[it]) * f },
                a.rox + (b.rox - a.rox) * f,
            )
        }
        return scaled(last, 1.0)
    }

    /** 같은 완주 시간대 중간값 그대로 (비교용): run = 1km 러닝(초), st = 스테이션 8개(초) */
    fun bench(division: String, finish: Int): Pair<Int, List<Int>> {
        val r = row(division, finish)
        return r.run.r() to r.st.map { it.r() }
    }

    /** 같은 완주 시간대 Roxzone 8개 합(초) 중간값 */
    fun roxTotal(division: String, finish: Int): Int = row(division, finish).rox.r()

    /** 같은 완주 시간대 Roxzone 1번 목표(초): 실제 중간값 ÷ 8, 5초 단위, 20초~2분 사이 */
    fun roxEach(goal: Int, division: String): Int {
        val each = row(division, goal).rox / 8
        return minOf(120, maxOf(20, (each / 5).r() * 5))
    }

    /** 목표 시간(Roxzone 포함)을 16칸 [Run1, St1, Run2, St2, …] 로 나눔 */
    fun splits16(goal: Int, division: String, rox: Int = Defaults.roxTarget): List<Int> {
        val r = row(division, goal)
        val raw = ArrayList<Double>(16)
        for (i in 0 until 8) {
            raw.add(r.run)
            raw.add(r.st[i])
        }
        val want = maxOf(16 * 30, goal - 8 * rox).toDouble()
        val sum = maxOf(1.0, raw.sum())
        return raw.map { (it * want / sum).r() }
    }
}
