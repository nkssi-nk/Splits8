import Foundation

// MARK: - 62번 · 러닝 기록 분석용 계산 (워치 · 아이폰 엔진 · 기록 화면이 같이 씀)
//
// 경로 점(RoutePt)의 높이(h) · 시간(t)으로 오르막 합계 · 구간별 오르막/내리막 · 높이 그래프를,
// 걸음 수로 케이던스(분당 걸음) · 보폭을 계산. 화면 없는 순수 계산만 둠.

enum RunMetrics {
    /// 이보다 작은 높이 변화는 GPS 흔들림으로 보고 버림 (m)
    static let climbStep: Double = 3
    /// 높이를 고르게 할 때 앞뒤로 같이 보는 점 수 (5점 이동 평균)
    static let smoothWindow: Int = 5

    // MARK: 높이

    /// 이동 평균으로 높이를 고르게 (가장자리는 있는 점만 평균)
    static func smooth(_ v: [Double], window: Int = smoothWindow) -> [Double] {
        guard v.count > 2, window > 1 else { return v }
        let half: Int = window / 2
        var out: [Double] = []
        out.reserveCapacity(v.count)
        for i in v.indices {
            let a: Int = max(0, i - half), b: Int = min(v.count - 1, i + half)
            var s: Double = 0
            for j in a...b { s += v[j] }
            out.append(s / Double(b - a + 1))
        }
        return out
    }

    /// 높이가 있는 점들 (고른 높이 · 그 점의 시간 · 시작부터 거리 m)
    static func heights(_ route: [RoutePt]) -> [(h: Double, t: Int?, m: Double)] {
        var raw: [(h: Double, t: Int?, m: Double)] = []
        var dist: Double = 0
        var prev: RoutePt? = nil
        for p in route {
            if let q = prev { dist += meters(q, p) }
            prev = p
            if let h = p.h { raw.append((h, p.t, dist)) }
        }
        guard raw.count >= 2 else { return [] }
        let sm: [Double] = smooth(raw.map(\.h))
        return raw.indices.map { (sm[$0], raw[$0].t, raw[$0].m) }
    }

    /// 점마다 그때까지 오른 높이 · 내려간 높이 합 (3 m 미만 오르내림은 무시)
    static func climbSeries(_ hs: [Double]) -> (up: [Double], down: [Double]) {
        guard let first = hs.first else { return ([], []) }
        var ref: Double = first
        var up: Double = 0, down: Double = 0
        var ups: [Double] = [], downs: [Double] = []
        for h in hs {
            if h - ref >= climbStep {
                up += h - ref; ref = h
            } else if ref - h >= climbStep {
                down += ref - h; ref = h
            }
            ups.append(up); downs.append(down)
        }
        return (ups, downs)
    }

    /// 전체 오르막 합계(m). 높이가 있는 점이 부족하면 nil
    static func ascent(_ route: [RoutePt]?) -> Double? {
        guard let route else { return nil }
        let hs = heights(route)
        guard hs.count >= 2 else { return nil }
        return climbSeries(hs.map(\.h)).up.last
    }

    /// 구간별 (오르막, 내리막) m. splits = 구간 시간(초) 순서대로, 경로 점의 t 와 같은 시계(일시정지 뺀 시간).
    /// 시간 없는 예전 경로는 nil
    static func segClimbs(_ route: [RoutePt]?, splits: [Int]) -> [(up: Double, down: Double)]? {
        guard let route, !splits.isEmpty else { return nil }
        let hs = heights(route).filter { $0.t != nil }
        guard hs.count >= 2 else { return nil }
        let (ups, downs) = climbSeries(hs.map(\.h))
        // 구간 끝 시각(초)
        var ends: [Int] = []
        var acc: Int = 0
        for s in splits { acc += s; ends.append(acc) }
        // 그 시각까지 쌓인 값 (그 시각 이전 마지막 점)
        func upTo(_ t: Int) -> (Double, Double) {
            var u: Double = 0, d: Double = 0
            for i in hs.indices {
                guard let pt = hs[i].t, pt <= t else { break }
                u = ups[i]; d = downs[i]
            }
            return (u, d)
        }
        var out: [(up: Double, down: Double)] = []
        var last: (Double, Double) = (0, 0)
        for e in ends {
            let now = upTo(e)
            out.append((max(0, now.0 - last.0), max(0, now.1 - last.1)))
            last = now
        }
        return out
    }

    /// 높이 그래프용 (km, 고른 높이 m). 점이 많으면 최대 n 개로 줄임
    static func profile(_ route: [RoutePt]?, maxPoints n: Int = 200) -> [(km: Double, h: Double)] {
        guard let route else { return [] }
        let hs = heights(route)
        guard hs.count >= 2 else { return [] }
        let step: Int = max(1, hs.count / max(2, n))
        var out: [(km: Double, h: Double)] = stride(from: 0, to: hs.count, by: step).map { (hs[$0].m / 1000, hs[$0].h) }
        if let l = hs.last, out.last?.km != l.m / 1000 { out.append((l.m / 1000, l.h)) }
        return out
    }

    // MARK: 걸음

    /// 분당 걸음 수. 걸음·시간이 없거나 말이 안 되는 값(달리기·걷기 범위 밖)이면 nil
    static func cadence(steps: Double, seconds: Int) -> Int? {
        guard steps > 0, seconds >= 20 else { return nil }
        let v: Double = steps * 60 / Double(seconds)
        guard v >= 60, v <= 260 else { return nil }
        return Int(v.rounded())
    }

    /// 기록 만들 때 러닝 분석 값 채우기 (워치 · 아이폰 엔진 공통).
    /// segSteps = 구간별 걸음 수 (r.segs 와 같은 순서), strideHK = 워치 건강 앱 보폭 평균(m, 없으면 nil → 거리 ÷ 걸음)
    static func fill(_ r: inout Record, segSteps: [Double?], strideHK: Double?) {
        var stepSum: Double = 0, timeSum: Int = 0
        var distForStride: Double = 0, stepsForStride: Double = 0
        for i in r.segs.indices where r.segs[i].kind == .run {
            guard segSteps.indices.contains(i), let st = segSteps[i], st > 0 else { continue }
            r.segs[i].cad = cadence(steps: st, seconds: r.segs[i].time)
            if r.segs[i].cad != nil { stepSum += st; timeSum += r.segs[i].time }
            if let d = r.segs[i].dist, d > 0 { distForStride += d; stepsForStride += st }
        }
        r.cadence = cadence(steps: stepSum, seconds: timeSum)
        if let s = strideHK, s > 0.3, s < 3 {
            r.stride = s
        } else if stepsForStride > 0 {
            let s: Double = distForStride / stepsForStride
            r.stride = (s > 0.3 && s < 3) ? s : nil
        }
        // 오르막: 경로 높이로 (실외 러닝만 경로가 있음)
        r.ascent = ascent(r.route)
        if let cl = segClimbs(r.route, splits: r.segs.map(\.time)), cl.count == r.segs.count {
            for i in r.segs.indices where r.segs[i].kind == .run { r.segs[i].up = cl[i].up }
        }
    }

    // MARK: 거리

    /// 두 점 사이 거리(m) — 짧은 거리라 지구를 공으로 보고 계산 (CoreLocation 없이, 위젯 대상에서도 씀)
    static func meters(_ a: RoutePt, _ b: RoutePt) -> Double {
        let r: Double = 6_371_000
        let la1: Double = a.a * .pi / 180, la2: Double = b.a * .pi / 180
        let dla: Double = la2 - la1
        let dlo: Double = (b.o - a.o) * .pi / 180
        let x: Double = sin(dla / 2) * sin(dla / 2) + cos(la1) * cos(la2) * sin(dlo / 2) * sin(dlo / 2)
        return 2 * r * atan2(sqrt(x), sqrt(max(0, 1 - x)))
    }
}
