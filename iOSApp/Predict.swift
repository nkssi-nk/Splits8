import SwiftUI

// MARK: - 예상 완주 시간 (최근 90일 최고 구간 기록으로 짐작)

enum Predict {
    /// 최근 90일의 트레이닝 · 풀 시뮬레이션에서 구간별 최고 시간을 모아 완주 시간을 짐작.
    /// 모자란 구간은 같은 완주 시간대 중간값(HyroxBench)으로 채우고, 두 번 돌려 시간대를 수렴시킴.
    /// 최근 풀 시뮬이 있으면 그 최고 시간보다 길게 나오지는 않음. 스테이션 8개 중 4개 미만이면 nil (자료 부족)
    static func finish(records: [Record], division: String, now: Date = Date()) -> Int? {
        let cutoff: Date = now.addingTimeInterval(-90 * 86400)
        // 18번: 인터벌 러닝 · 타바타 등 새 종류는 빼고 (빠른 1 km 반복이 예상 시간을 당기지 않게)
        let recent: [Record] = records.filter { $0.date >= cutoff && $0.counts && (($0.mode == .training && !$0.isNewKind) || $0.mode == .sim) }
        var bestRun: Int? = nil
        var bestSt: [String: Int] = [:]
        for r in recent {
            for s in r.segs where s.kind != .rox {
                guard SegKey.plausible(icon: s.icon, detail: s.detail, time: s.time) else { continue }
                if s.kind == .run {
                    // 1km 러닝만 (짧은 전력 질주를 1km 로 늘려 셈하지 않음)
                    let m: Double = s.dist ?? runMeters(s.detail)
                    guard m >= 900, m <= 1100 else { continue }
                    bestRun = min(bestRun ?? .max, s.time)
                } else if Station.of(s.icon) != nil {
                    bestSt[s.icon] = min(bestSt[s.icon] ?? .max, s.time)
                }
            }
        }
        guard bestSt.count >= 4 else { return nil }
        let bestSim: Int? = recent.filter { $0.mode == .sim && $0.splits16 != nil }.map(\.total).min()
        var guess: Int = bestSim ?? 80 * 60
        for _ in 0..<2 {
            let b: (run: Int, st: [Int]) = HyroxBench.bench(for: division, finish: guess)
            var sum: Int = (bestRun ?? b.run) * 8
            for i in 0..<8 { sum += bestSt[Station.all[i].key] ?? b.st[i] }
            sum += HyroxBench.roxTotal(for: division, finish: guess)
            guess = sum
        }
        if let s = bestSim { return min(s, guess) }
        return guess
    }
}

/// Full Sim · Race 탭의 예상 완주 시간 카드. 자료가 모자라면 아무것도 안 보임
struct PredictCard: View {
    let store = Store.shared

    var body: some View {
        if let p = Predict.finish(records: store.records, division: store.settings.division) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Label8("PREDICTED FINISH")
                    Spacer()
                    Text(Fm.t(p)).font(F.num(28)).tracking(-0.84).foregroundStyle(C.accent).lineLimit(1)
                }
                Text("Estimated from your best segments in the last 90 days — not a guarantee.")
                    .font(F.t(F.foot)).foregroundStyle(C.text3).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .card8()
            .accessibilityIdentifier("predict.card")
        }
    }
}
