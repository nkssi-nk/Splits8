package com.nkssi.splits8.shared

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * 러닝 기록 분석용 계산 (아이폰 Shared/RunMetrics.swift).
 * 경로 점의 높이 · 시간으로 오르막, 걸음 수로 케이던스 · 보폭.
 */
object RunMetrics {
    /** 이보다 작은 높이 변화는 GPS 흔들림으로 보고 버림 (m) */
    const val climbStep = 3.0
    /** 높이를 고르게 할 때 같이 보는 점 수 (5점 이동 평균) */
    const val smoothWindow = 5

    data class HPoint(val h: Double, val t: Int?, val m: Double)
    data class Climb(val up: Double, val down: Double)

    /** 이동 평균으로 높이를 고르게 (가장자리는 있는 점만 평균) */
    fun smooth(v: List<Double>, window: Int = smoothWindow): List<Double> {
        if (v.size <= 2 || window <= 1) return v
        val half = window / 2
        return v.indices.map { i ->
            val a = maxOf(0, i - half)
            val b = minOf(v.size - 1, i + half)
            var s = 0.0
            for (j in a..b) s += v[j]
            s / (b - a + 1)
        }
    }

    /** 높이가 있는 점들 (고른 높이 · 그 점의 시간 · 시작부터 거리 m) */
    fun heights(route: List<RoutePt>): List<HPoint> {
        val raw = ArrayList<HPoint>()
        var dist = 0.0
        var prev: RoutePt? = null
        for (p in route) {
            prev?.let { dist += meters(it, p) }
            prev = p
            p.h?.let { raw.add(HPoint(it, p.t, dist)) }
        }
        if (raw.size < 2) return emptyList()
        val sm = smooth(raw.map { it.h })
        return raw.indices.map { HPoint(sm[it], raw[it].t, raw[it].m) }
    }

    /** 점마다 그때까지 오른 높이 · 내려간 높이 합 (3 m 미만 오르내림은 무시) */
    fun climbSeries(hs: List<Double>): Pair<List<Double>, List<Double>> {
        val first = hs.firstOrNull() ?: return emptyList<Double>() to emptyList()
        var ref = first
        var up = 0.0
        var down = 0.0
        val ups = ArrayList<Double>()
        val downs = ArrayList<Double>()
        for (h in hs) {
            if (h - ref >= climbStep) {
                up += h - ref; ref = h
            } else if (ref - h >= climbStep) {
                down += ref - h; ref = h
            }
            ups.add(up); downs.add(down)
        }
        return ups to downs
    }

    /** 전체 오르막 합계(m). 높이가 있는 점이 부족하면 null */
    fun ascent(route: List<RoutePt>?): Double? {
        if (route == null) return null
        val hs = heights(route)
        if (hs.size < 2) return null
        return climbSeries(hs.map { it.h }).first.lastOrNull()
    }

    /** 구간별 (오르막, 내리막) m. 시간 없는 예전 경로는 null */
    fun segClimbs(route: List<RoutePt>?, splits: List<Int>): List<Climb>? {
        if (route == null || splits.isEmpty()) return null
        val hs = heights(route).filter { it.t != null }
        if (hs.size < 2) return null
        val (ups, downs) = climbSeries(hs.map { it.h })
        val ends = ArrayList<Int>()
        var acc = 0
        for (s in splits) { acc += s; ends.add(acc) }
        fun upTo(t: Int): Pair<Double, Double> {
            var u = 0.0
            var d = 0.0
            for (i in hs.indices) {
                val pt = hs[i].t ?: break
                if (pt > t) break
                u = ups[i]; d = downs[i]
            }
            return u to d
        }
        val out = ArrayList<Climb>()
        var last = 0.0 to 0.0
        for (e in ends) {
            val now = upTo(e)
            out.add(Climb(maxOf(0.0, now.first - last.first), maxOf(0.0, now.second - last.second)))
            last = now
        }
        return out
    }

    /** 높이 그래프용 (km, 고른 높이 m). 점이 많으면 최대 n 개로 줄임 */
    fun profile(route: List<RoutePt>?, maxPoints: Int = 200): List<Pair<Double, Double>> {
        if (route == null) return emptyList()
        val hs = heights(route)
        if (hs.size < 2) return emptyList()
        val step = maxOf(1, hs.size / maxOf(2, maxPoints))
        val out = (0 until hs.size step step).map { hs[it].m / 1000 to hs[it].h }.toMutableList()
        val l = hs.last()
        if (out.lastOrNull()?.first != l.m / 1000) out.add(l.m / 1000 to l.h)
        return out
    }

    /** 분당 걸음 수. 걸음·시간이 없거나 달리기·걷기 범위 밖이면 null */
    fun cadence(steps: Double, seconds: Int): Int? {
        if (steps <= 0 || seconds < 20) return null
        val v = steps * 60 / seconds
        if (v < 60 || v > 260) return null
        return v.r()
    }

    /**
     * 기록 만들 때 러닝 분석 값 채우기 (워치 · 폰 엔진 공통).
     * segSteps = 구간별 걸음 수 (r.segs 와 같은 순서), strideHealth = 워치 측정 보폭 평균(m, 없으면 거리 ÷ 걸음)
     */
    fun fill(r: Record, segSteps: List<Double?>, strideHealth: Double?): Record {
        val segs = r.segs.toMutableList()
        var stepSum = 0.0
        var timeSum = 0
        var distForStride = 0.0
        var stepsForStride = 0.0
        for (i in segs.indices) {
            if (segs[i].kind != SegKind.Run) continue
            val st = segSteps.getOrNull(i) ?: continue
            if (st <= 0) continue
            val cad = cadence(st, segs[i].time)
            segs[i] = segs[i].copy(cad = cad)
            if (cad != null) { stepSum += st; timeSum += segs[i].time }
            val d = segs[i].dist
            if (d != null && d > 0) { distForStride += d; stepsForStride += st }
        }
        val cadence = cadence(stepSum, timeSum)
        val stride: Double? = when {
            strideHealth != null && strideHealth > 0.3 && strideHealth < 3 -> strideHealth
            stepsForStride > 0 -> (distForStride / stepsForStride).takeIf { it > 0.3 && it < 3 }
            else -> r.stride
        }
        val ascent = ascent(r.route)
        val cl = segClimbs(r.route, segs.map { it.time })
        if (cl != null && cl.size == segs.size) {
            for (i in segs.indices) if (segs[i].kind == SegKind.Run) segs[i] = segs[i].copy(up = cl[i].up)
        }
        return r.copy(segs = segs, cadence = cadence, stride = stride, ascent = ascent)
    }

    /** 두 점 사이 거리(m) — 지구를 공으로 보고 계산 */
    fun meters(a: RoutePt, b: RoutePt): Double {
        val r = 6_371_000.0
        val la1 = a.a * Math.PI / 180
        val la2 = b.a * Math.PI / 180
        val dla = la2 - la1
        val dlo = (b.o - a.o) * Math.PI / 180
        val x = sin(dla / 2) * sin(dla / 2) + cos(la1) * cos(la2) * sin(dlo / 2) * sin(dlo / 2)
        return 2 * r * atan2(sqrt(x), sqrt(maxOf(0.0, 1 - x)))
    }
}
