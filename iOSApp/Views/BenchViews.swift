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

// MARK: - 80번(빌드 28): 상위 몇 % (홈페이지 splits8/hyrox.html 과 같은 숫자)

/// Open: HyroxDataLab(2026.3, 전 세계 Open 기록 70만 건+) 상위 10 / 25 / 50 / 75% 경계, 사이는 곧게 이음.
/// Pro: Rox Lyfe 단계(Elite 15 · 세계 수준 · 경쟁 수준 · Pro 평균). 더블 · 릴레이는 자료가 없어 안 보임
struct HyroxRank {
    let level: String           // "Advanced" 등 (번역 키)
    let pct: Int?               // 상위 약 x% (Open 만)
    let group: String           // "Open Men"
    let next: (name: String, time: Int)?   // 다음 단계와 그 기준 시간
    let total: Int

    static let open: [String: [Int]] = ["M": [75 * 60, 85 * 60, 100 * 60, 114 * 60], "W": [86 * 60, 98 * 60, 114 * 60, 130 * 60]]
    static let pro: [String: [Int]] = ["M": [54 * 60, 58 * 60, 65 * 60, 81 * 60 + 1], "W": [57 * 60, 62 * 60, 70 * 60, 86 * 60 + 36]]

    static func of(division: String, total: Int) -> HyroxRank? {
        // 이름이나 키가 정확히 맞는 디비전만 (릴레이 등 모르는 값이 Open Men 으로 잡히지 않게)
        guard let d = Division.all.first(where: { $0.key == division || $0.name.caseInsensitiveCompare(division) == .orderedSame }) else { return nil }
        guard total >= 40 * 60, total <= 4 * 3600 else { return nil }
        let g: String = d.key.hasSuffix("W") ? "W" : "M"
        if d.key == "openM" || d.key == "openW", let b = open[g] {
            let names: [String] = ["Elite", "Advanced", "Intermediate", "Beginner"]
            let i: Int? = b.firstIndex { total < $0 }
            let level: String = i.map { names[$0] } ?? "First finish"
            let next: (name: String, time: Int)? = HyroxRank.nextStep(i, names: names, b: b)
            return HyroxRank(level: level, pct: max(1, Int(openPct(total, b).rounded())), group: d.name, next: next, total: total)
        }
        if d.key == "proM" || d.key == "proW", let b = pro[g] {
            let names: [String] = ["Elite 15 level", "World level", "Competitive level", "Faster than Pro average"]
            let i: Int? = b.firstIndex { total < $0 }
            let level: String = i.map { names[$0] } ?? "Slower than Pro average"
            let next: (name: String, time: Int)? = HyroxRank.nextStep(i, names: names, b: b)
            return HyroxRank(level: level, pct: nil, group: d.name, next: next, total: total)
        }
        return nil
    }

    /// 다음 단계 (i = 지금 단계 번호, nil = 마지막 경계보다 느림 → 맨 끝 단계가 다음)
    static func nextStep(_ i: Int?, names: [String], b: [Int]) -> (name: String, time: Int)? {
        guard let i else { return (name: names[3], time: b[3]) }
        if i == 0 { return nil }
        return (name: names[i - 1], time: b[i - 1])
    }

    /// 홈페이지 openPct 와 같음: (경계×0.85 → 1%), 10, 25, 50, 75, (경계×1.25 → 97%)
    static func openPct(_ t: Int, _ b: [Int]) -> Double {
        let pts: [(Double, Double)] = [(Double(b[0]) * 0.85, 1), (Double(b[0]), 10), (Double(b[1]), 25),
                                       (Double(b[2]), 50), (Double(b[3]), 75), (Double(b[3]) * 1.25, 97)]
        let x: Double = Double(t)
        if x <= pts[0].0 { return 1 }
        if x >= pts[5].0 { return 97 }
        for i in 1..<pts.count where x <= pts[i].0 {
            let a = pts[i - 1], c = pts[i]
            return a.1 + (c.1 - a.1) * (x - a.0) / (c.0 - a.0)
        }
        return 97
    }
}

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
