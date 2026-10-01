import Foundation

/// 런 피로도: 각 스테이션 바로 다음 1KM 러닝이 내 평균 러닝보다 얼마나 느린지 (초)
struct FatigueResult {
    /// 스테이션 이름 8개 (SkiErg … Wall Balls)
    let names: [String]
    /// 스테이션별 차이(초). Wall Balls 다음엔 러닝이 없으므로 nil
    let deltas: [Int?]
    /// 기준이 된 평균 러닝 (초, 1KM)
    let avgRun: Int
    /// 계산에 쓴 기록 수
    let count: Int

    /// 가장 많이 느려지는 스테이션 번호 (0보다 클 때만)
    var worst: Int? {
        var best: Int? = nil
        var bestValue: Int = 0
        for (i, d) in deltas.enumerated() {
            if let d, d > bestValue { bestValue = d; best = i }
        }
        return best
    }

    /// 막대 길이 기준 (가장 큰 양수 차이, 최소 1)
    var maxDelta: Int {
        let vals: [Int] = deltas.compactMap { $0 }
        return max(1, vals.max() ?? 1)
    }
}

enum Fatigue {
    static let names: [String] = ["SkiErg", "Sled Push", "Sled Pull", "BBJ", "Row", "Farmers", "Lunges", "Wall Balls"]

    /// 16구간(Run1, SkiErg, Run2, Sled Push, …, Run8, Wall Balls)이 있는 기록 중 최근 `limit`개로 계산.
    /// splits16 가 있는 기록이 하나도 없으면 nil.
    static func analyze(_ records: [Record], limit: Int = 5) -> FatigueResult? {
        let usable: [Record] = records.filter { $0.splits16 != nil }.sorted { $0.date > $1.date }
        let recent: [Record] = Array(usable.prefix(max(1, limit)))
        guard !recent.isEmpty else { return nil }

        var sums: [Double] = Array(repeating: 0, count: 7)
        var runSum: Double = 0
        for rec in recent {
            guard let s = rec.splits16 else { continue }
            let runs: [Int] = stride(from: 0, to: 16, by: 2).map { s[$0] }
            let avg: Double = Double(runs.reduce(0, +)) / 8
            runSum += avg
            for i in 0..<7 {
                // 스테이션 i 다음 러닝 = Run (i+2) = splits16[2*(i+1)]
                let after: Double = Double(s[2 * (i + 1)])
                sums[i] += after - avg
            }
        }
        let n: Double = Double(recent.count)
        var deltas: [Int?] = sums.map { Int(($0 / n).rounded()) }
        deltas.append(nil)   // Wall Balls 다음엔 러닝 없음
        let avgRun: Int = Int((runSum / n).rounded())
        return FatigueResult(names: names, deltas: deltas, avgRun: avgRun, count: recent.count)
    }
}
