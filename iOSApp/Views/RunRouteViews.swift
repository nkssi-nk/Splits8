import SwiftUI
import MapKit
import Charts

// MARK: - 62번 · 러닝 기록 화면: 속도 색 경로 · 높이 그래프 · 바퀴 카드

/// 경로를 잘게 나눈 한 토막 (지도에 따로 그려 속도별 색을 입힘)
struct RouteChunk: Identifiable {
    let id: Int
    let cs: [CLLocationCoordinate2D]
    let color: Color
}

enum RouteSpeed {
    /// 느릴 때 (어두운 노랑) → 빠를 때 (밝은 노랑)
    static let dim: (r: Double, g: Double, b: Double) = (0.36, 0.32, 0.0)
    static let bright: (r: Double, g: Double, b: Double) = (1.0, 0.902, 0.0)

    static func color(_ f: Double) -> Color {
        let k: Double = max(0, min(1, f))
        return Color(red: dim.r + (bright.r - dim.r) * k,
                     green: dim.g + (bright.g - dim.g) * k,
                     blue: dim.b + (bright.b - dim.b) * k)
    }

    /// 경로를 최대 약 150 토막으로 나눠 토막마다 페이스로 색을 정함.
    /// 시간(t)이 없는 점이 하나라도 있으면(예전 기록) nil → 한 가지 색으로 그림
    static func chunks(_ route: [RoutePt], maxChunks: Int = 150) -> [RouteChunk]? {
        guard route.count >= 3, route.allSatisfy({ $0.t != nil }) else { return nil }
        let n: Int = max(2, route.count / maxChunks)
        var ranges: [(a: Int, b: Int, pace: Double?)] = []
        var i: Int = 0
        while i < route.count - 1 {
            let j: Int = min(i + n, route.count - 1)
            var m: Double = 0
            for k in i..<j { m += RunMetrics.meters(route[k], route[k + 1]) }
            let dt: Double = Double((route[j].t ?? 0) - (route[i].t ?? 0))
            // 거의 안 움직였거나 시간이 거꾸로면 페이스 없음 (앞 토막 색을 씀)
            let pace: Double? = (m >= 5 && dt > 0) ? dt / m : nil
            ranges.append((i, j, pace))
            i = j
        }
        let ps: [Double] = ranges.compactMap { $0.pace }.sorted()
        guard ps.count >= 2 else { return nil }
        // 너무 튀는 값에 끌려가지 않게 10% · 90% 지점을 가장 빠름 · 가장 느림으로
        let fast: Double = ps[ps.count / 10]
        let slow: Double = ps[min(ps.count - 1, ps.count * 9 / 10)]
        let span: Double = max(0.0001, slow - fast)
        var out: [RouteChunk] = []
        var lastF: Double = 0.5
        for (k, r) in ranges.enumerated() {
            if let p = r.pace { lastF = 1 - (p - fast) / span }
            let cs: [CLLocationCoordinate2D] = (r.a...r.b).map { CLLocationCoordinate2D(latitude: route[$0].a, longitude: route[$0].o) }
            out.append(RouteChunk(id: k, cs: cs, color: color(lastF)))
        }
        return out
    }
}

/// 지도 왼쪽 아래 작은 안내: SLOW ▬▬ FAST
struct RouteSpeedLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("SLOW").font(F.t(10, .semibold)).foregroundStyle(C.text2)
            LinearGradient(colors: [RouteSpeed.color(0), RouteSpeed.color(1)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 44, height: 5)
                .clipShape(Capsule())
            Text("FAST").font(F.t(10, .semibold)).foregroundStyle(C.accent)
        }
        .padding(.vertical, 5).padding(.horizontal, 9)
        .background(Color.black.opacity(0.55), in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
    }
}

// MARK: 높이 그래프 (지도 아래, 가로 = km)

struct ElevationCard: View {
    let route: [RoutePt]
    let ascent: Double?

    private struct Pt: Identifiable {
        let id: Int
        let km: Double
        let h: Double
    }

    var body: some View {
        let raw = RunMetrics.profile(route)
        let pts: [Pt] = raw.indices.map { Pt(id: $0, km: raw[$0].km, h: raw[$0].h) }
        let lo: Double = (pts.map(\.h).min() ?? 0)
        let hi: Double = (pts.map(\.h).max() ?? 0)
        // 평지에서도 선이 바닥에 붙지 않게 높이 범위를 최소 20 m 로
        let pad: Double = max(4, (20 - (hi - lo)) / 2)
        let y0: Double = (lo - pad).rounded(.down)
        let y1: Double = (hi + pad).rounded(.up)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("ELEVATION")
                Spacer(minLength: 8)
                if let a = ascent {
                    Text(verbatim: "+\(Int(a.rounded())) m").font(F.num(15)).lineLimit(1)
                }
            }
            Chart(pts) { p in
                AreaMark(x: .value("km", p.km), yStart: .value("base", y0), yEnd: .value("m", p.h))
                    .foregroundStyle(LinearGradient(colors: [C.accent.opacity(0.32), C.accent.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("km", p.km), y: .value("m", p.h))
                    .foregroundStyle(C.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: y0...y1)
            .chartXScale(domain: 0...max(0.1, pts.last?.km ?? 0.1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisGridLine().foregroundStyle(C.line)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(verbatim: String(format: "%g km", d)).font(F.num(10, .regular)).foregroundStyle(C.text3)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(C.line)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(verbatim: "\(Int(d)) m").font(F.num(10, .regular)).foregroundStyle(C.text3)
                        }
                    }
                }
            }
            .frame(height: 110)
            .padding(.top, 14)
        }
        .padding(18)
        .card8()
        .accessibilityIdentifier("detail.elevation")
    }
}

// MARK: 같은 코스 바퀴 (12 laps · avg 1:52 · fastest #7 1:46)

struct LapsCard: View {
    let laps: [Int]

    var body: some View {
        let avg: Int = laps.reduce(0, +) / max(1, laps.count)
        let fi: Int = laps.indices.min(by: { laps[$0] < laps[$1] }) ?? 0
        let mn: Int = laps.min() ?? 0, mx: Int = laps.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            Label8("LAPS")
            Text(String(localized: "\(laps.count) laps · avg \(Fm.t(avg)) · fastest #\(fi + 1) \(Fm.t(laps[fi]))"))
                .font(F.num(15)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 10)
            // 바퀴마다 막대 (빠를수록 높게, 가장 빠른 바퀴 노랑) — 너무 많으면 막대는 뺌
            if laps.count <= 40 {
                HStack(alignment: .bottom, spacing: laps.count > 20 ? 2 : 4) {
                    ForEach(laps.indices, id: \.self) { i in
                        let f: Double = mx > mn ? Double(mx - laps[i]) / Double(mx - mn) : 1
                        Rectangle().fill(i == fi ? C.accent : C.control)
                            .frame(height: 12 + 30 * CGFloat(f))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 42, alignment: .bottom)
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card8()
        .accessibilityIdentifier("detail.laps")
    }
}
