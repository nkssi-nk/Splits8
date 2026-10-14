import Foundation

// MARK: - 62번 · 같은 코스 바퀴 수 (트랙 · 공원 한 바퀴를 여러 번 돈 러닝)
//
// 경로에서 가장 자주 지나간 곳(약 20 m 칸)을 '출발선'으로 정하고,
// 출발선에서 80 m 넘게 멀어졌다가 다시 20 m 안으로 돌아오면 한 바퀴.
// (계획은 150 m 였지만 400 m 트랙은 출발선에서 가장 먼 곳이 약 100 m 라서 80 m 로 낮춤)
// 출발선을 지날 때마다 가장 가까이 지난 순간의 시간으로 바퀴 시간을 셈.
// 3바퀴 이상일 때만 보여 줌 (한 번 갔다 오는 코스는 바퀴가 아님).

enum RunLaps {
    /// 출발선 칸 크기 · 돌아왔다고 보는 거리 (m)
    static let cell: Double = 20
    /// 이만큼 멀어져야 한 바퀴를 돈 것으로 봄 (m). 400 m 트랙도 잡히게 80
    static let away: Double = 80
    /// 이보다 짧은 바퀴는 GPS 흔들림으로 보고 셈하지 않음 (초)
    static let minLap: Int = 20
    static let minLaps: Int = 3

    /// 바퀴마다 걸린 시간(초). 시간 없는 경로 · 바퀴가 3개 미만이면 nil
    static func laps(_ route: [RoutePt]?) -> [Int]? {
        guard let route else { return nil }
        let pts: [(x: Double, y: Double, t: Int)] = flat(route)
        guard pts.count >= 10 else { return nil }
        guard let gate = gatePoint(pts) else { return nil }

        var passes: [Int] = []
        var inGate = false, wentAway = false
        var bestD: Double = .infinity, bestT: Int = 0
        // 출발선 안에 있다가 나올 때: 가장 가까이 지난 시간을 '지난 순간'으로
        func closeVisit() {
            if passes.isEmpty || wentAway {
                if let last = passes.last, bestT - last < minLap { return }
                passes.append(bestT)
                wentAway = false
            }
        }
        for p in pts {
            let d: Double = hypot(p.x - gate.x, p.y - gate.y)
            if d <= cell {
                if !inGate { inGate = true; bestD = d; bestT = p.t } else if d < bestD { bestD = d; bestT = p.t }
            } else {
                if inGate { closeVisit(); inGate = false }
                if d > away { wentAway = true }
            }
        }
        if inGate { closeVisit() }
        guard passes.count >= minLaps + 1 else { return nil }
        let out: [Int] = zip(passes, passes.dropFirst()).map { $1 - $0 }
        return out.count >= minLaps ? out : nil
    }

    /// 시간 있는 점들을 평면 좌표(m)로 (첫 점 기준, 짧은 거리라 단순 계산)
    private static func flat(_ route: [RoutePt]) -> [(x: Double, y: Double, t: Int)] {
        guard let o = route.first(where: { $0.t != nil }) else { return [] }
        let k: Double = 111_320
        let kx: Double = k * cos(o.a * .pi / 180)
        return route.compactMap { p in
            guard let t = p.t else { return nil }
            return ((p.o - o.o) * kx, (p.a - o.a) * k, t)
        }
    }

    /// 가장 여러 번 '들어간' 20 m 칸의 가운데 (같은 칸에 연달아 있는 점은 한 번으로 셈)
    private static func gatePoint(_ pts: [(x: Double, y: Double, t: Int)]) -> (x: Double, y: Double)? {
        struct Key: Hashable { let i: Int; let j: Int }
        var visits: [Key: Int] = [:]
        var sums: [Key: (x: Double, y: Double, n: Double)] = [:]
        var prev: Key? = nil
        for p in pts {
            let key = Key(i: Int((p.x / cell).rounded(.down)), j: Int((p.y / cell).rounded(.down)))
            if key != prev { visits[key, default: 0] += 1 }
            prev = key
            let s = sums[key] ?? (0, 0, 0)
            sums[key] = (s.x + p.x, s.y + p.y, s.n + 1)
        }
        // 같은 횟수면 칸 번호가 작은 쪽 (열 때마다 같은 결과)
        guard let best = visits.max(by: { a, b in
            a.value != b.value ? a.value < b.value : (a.key.i, a.key.j) > (b.key.i, b.key.j)
        }), best.value >= minLaps, let s = sums[best.key], s.n > 0 else { return nil }
        return (s.x / s.n, s.y / s.n)
    }
}
