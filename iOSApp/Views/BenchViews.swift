import SwiftUI

// MARK: - 같은 기록대 선수들과 비교 (기록 상세 · Full Simulation · Race)

/// 스테이션마다 내 시간을, 같은 완주 시간대 선수들의 중간값(HyroxBench)과 비교.
/// 16구간이 다 있는 Full Sim · Race 기록에서만 보임 — DetailView 에서 한 줄로 부름
struct BenchSection: View {
    let rec: Record

    var body: some View {
        if (rec.mode == .sim || rec.mode == .race), let me = rec.splits16 {
            // 80번(빌드 28): 전 세계 출전자 중 대략 위치 (홈페이지 '내 기록 분석'과 같은 기준 · 같은 계산)
            if let rk = HyroxRank.of(division: rec.division, total: rec.total) {
                SectionLabel(text: "WHERE YOU STAND", top: 20)
                RankCard(rank: rk)
            }
            SectionLabel(text: "VS ATHLETES AT YOUR TIME", top: 20)
            BenchCard(rec: rec, me: me)
        }
    }
}

/// 줄: 이름 · 내 시간 · 중간값 · 차이(빠르면 초록, 느리면 빨강) + 차이 크기만큼 작은 막대
private struct BenchCard: View {
    let rec: Record
    let me: [Int]
    /// 막대가 꽉 차는 차이 (초)
    private static let barCap: Double = 90
    private static let fr: [CGFloat] = [1.25, 1, 1, 1]

    var body: some View {
        let bench: (run: Int, st: [Int]) = HyroxBench.bench(for: rec.division, finish: rec.total)
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 10) {
                if let mine = rec.runPace {
                    row(name: "Run pace".l10n, mine: mine, bench: bench.run, pace: true)
                }
                ForEach(0..<8, id: \.self) { i in
                    row(name: Station.all[i].name, mine: me[i * 2 + 1], bench: bench.st[i])
                }
            }
            .padding(.top, 14)
            Text("Worldwide medians (2025/26 season) at this finish time — not an official ranking.")
                .font(F.t(F.foot)).foregroundStyle(C.text3).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(18)
        .card8()
        .accessibilityIdentifier("detail.bench")
    }

    private var header: some View {
        Cols(fr: Self.fr, spacing: 8) {
            Color.clear.frame(height: 1)
            Label8("ME", spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
            Label8("MEDIAN", spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
            Label8("DIFF", spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// pace = 러닝 줄 (1km 페이스끼리 비교)
    private func row(name: String, mine: Int, bench: Int, pace: Bool = false) -> some View {
        let d: Int = mine - bench
        let color: Color = d <= 0 ? C.good : C.bad
        return VStack(alignment: .leading, spacing: 4) {
            Cols(fr: Self.fr, spacing: 8) {
                Text(name).font(F.t(15)).frame(maxWidth: .infinity, alignment: .leading)
                Text(Fm.t(mine) + (pace ? " /KM" : "")).font(F.num(15)).frame(maxWidth: .infinity, alignment: .trailing)
                Text(Fm.t(bench)).font(F.num(15)).foregroundStyle(C.text2).frame(maxWidth: .infinity, alignment: .trailing)
                Text(Fm.d(d)).font(F.num(15)).foregroundStyle(color).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            bar(d, color: color)
        }
    }

    /// 차이 크기만큼 길어지는 3pt 막대 (90초에 꽉 참)
    private func bar(_ d: Int, color: Color) -> some View {
        let f: CGFloat = CGFloat(min(1, abs(Double(d)) / Self.barCap))
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().fill(color).frame(width: max(2, g.size.width * f))
            }
        }
        .frame(height: 3)
    }
}

// 80번 HyroxRank 는 1.2.4 부터 Shared/HyroxRank.swift (워치 · 공유 카드도 씀)

private struct RankCard: View {
    let rank: HyroxRank

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rank.level.l10n).font(F.t(30, .bold)).tracking(-0.6).foregroundStyle(C.accent).lineLimit(1).minimumScaleFactor(0.7)
            if let p = rank.pct {
                Text(String(localized: "Top ~\(p)% of \(rank.group.l10n) finishers")).font(F.t(16)).padding(.top, 4)
                bar(p).padding(.top, 16)
            }
            if let n = rank.next {
                let gap: Int = rank.total - n.time + 1
                Text(String(localized: "\(Fm.t(gap)) to \(n.name.l10n) (\(Fm.t(n.time))) — about \(Int((Double(gap) / 16).rounded(.up))) sec per split"))
                    .font(F.t(14)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            Text("Rough position from published worldwide race results (2025/26) — not an official ranking.")
                .font(F.t(F.foot)).foregroundStyle(C.text3).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
        .accessibilityIdentifier("detail.rank")
    }

    /// 상위 10 · 25 · 50 · 75% 눈금 + 내 위치
    private func bar(_ p: Int) -> some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [C.accent, Color(hex: 0x6E6A3A), Color(hex: 0x2A2924)],
                                                  startPoint: .leading, endPoint: .trailing))
                    RoundedRectangle(cornerRadius: 3).fill(Color.white)
                        .frame(width: 5, height: 18)
                        .offset(x: g.size.width * CGFloat(min(100, max(0, p))) / 100 - 2.5)
                }
            }
            .frame(height: 10)
            GeometryReader { g in
                ForEach([10, 25, 50, 75], id: \.self) { m in
                    Text(m == 10 ? String(localized: "Top \(m)%") : "\(m)%").font(F.t(11)).foregroundStyle(C.text3)
                        .fixedSize()
                        .position(x: g.size.width * CGFloat(m) / 100, y: 7)
                }
            }
            .frame(height: 14)
        }
    }
}
