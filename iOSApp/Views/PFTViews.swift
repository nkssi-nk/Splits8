import SwiftUI

// MARK: - Test 탭 (세 번째 탭): 위에서 PFT / Full Sim 을 고름

struct TestView: View {
    let r = Router.shared

    var body: some View {
        VStack(spacing: 10) {
            TestSeg(selected: r.testTab) { k in r.testTab = k }
                .padding(.horizontal, 16)
            if r.testTab == "sim" {
                SimView()
            } else {
                PFTView()
            }
        }
    }
}

/// PFT | Full Sim (40 높이, 고른 쪽은 노랑 바탕 + 검정 글자)
struct TestSeg: View {
    let selected: String
    let onSelect: (String) -> Void
    private let keys: [String] = ["pft", "sim"]
    private let labels: [String] = ["PFT", "Full Sim"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(keys.indices, id: \.self) { i in
                segButton(keys[i], labels[i])
            }
        }
        .padding(3)
        .background(C.segTrack, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func segButton(_ key: String, _ label: String) -> some View {
        let on: Bool = selected == key
        return Button { onSelect(key) } label: {
            Text(label.l10n).font(F.t(15, .semibold)).lineLimit(1)
                .foregroundStyle(on ? Color.black : C.text2)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(on ? C.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("test.seg." + key)
    }
}

/// 한 줄 설명 + ⓘ (누르면 설명 시트)
struct TestIntro: View {
    let text: String
    let id: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text.l10n).font(F.t(F.foot)).foregroundStyle(C.text2).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            InfoButton(id: id, action: action)
        }
        .padding(.leading, 4)
    }
}

/// ⓘ 버튼 (회색, 누르는 자리 36)
struct InfoButton: View {
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle").font(.system(size: 20, weight: .regular))
                .foregroundStyle(C.text2)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - PFT 문구

enum PFTText {
    /// Gold 기준까지 얼마나 남았는지 / 얼마나 여유 있는지
    static func gap(_ total: Int) -> String {
        switch PFT.grade(total) {
        case .gold:
            return String(localized: "\(Fm.t(PFT.goldLimit - total)) inside Gold")
        case .silver:
            return String(localized: "\(Fm.t(total - PFT.goldLimit + 1)) to Gold")
        case .bronze:
            return String(localized: "\(Fm.t(total - PFT.silverLimit)) to Silver")
        }
    }

    /// 그 등급의 기준 한 줄
    static func rule(_ g: PFTGrade) -> String {
        switch g {
        case .gold: return String(localized: "Gold is under 22:00")
        case .silver: return String(localized: "Silver is 22:00 – 26:00")
        case .bronze: return String(localized: "Bronze is over 26:00")
        }
    }

    /// 설명 카드의 등급 기준
    static func range(_ g: PFTGrade) -> String {
        switch g {
        case .gold: return String(localized: "Under 22:00")
        case .silver: return "22:00 – 26:00"
        case .bronze: return String(localized: "Over 26:00")
        }
    }
}

// MARK: - PFT 화면

struct PFTView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var info = false

    var body: some View {
        let recs: [Record] = store.records(.pft)
        return VStack(spacing: 10) {
            if recs.isEmpty {
                // 처음: 무엇인지 + 등급 기준 + 종목 + 시작
                PFTAboutCard(onInfo: { info = true })
                PFTMovesCard(div: store.div)
                StartOnPhoneButton(mode: .pft, big: true)
                Text("or start PFT on your Apple Watch")
                    .font(F.t(F.foot)).foregroundStyle(C.text3)
                    .frame(maxWidth: .infinity)
            } else {
                TestIntro(text: "Physical Fitness Test · six movements back to back, for time.", id: "pft.info") {
                    info = true
                }
                bestCard
                PFTMovesCard(div: store.div)
                StartOnPhoneButton(mode: .pft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HistoryHeader()
                historyCard(recs)
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $info) {
            PFTInfoSheet()
                .presentationDetents([.large])
                .presentationBackground(Color(hex: 0x1C1C1E))
                .preferredColorScheme(.dark)
        }
    }

    // MARK: 최고 기록 카드 (등급 뱃지 + 등급 막대)

    private var bestCard: some View {
        let best: Record? = store.pftBest
        let grade: PFTGrade? = best?.pftGrade
        let line: String = best.map { "Best".l10n + " · " + Fm.ddmy.string(from: $0.date) } ?? "None yet".l10n
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(line).font(F.t(F.foot)).foregroundStyle(C.text2).lineLimit(1)
                Spacer(minLength: 8)
                if let grade { PFTBadge(grade: grade) }
            }
            HStack(alignment: .bottom, spacing: 8) {
                Text(best.map { Fm.t($0.total) } ?? "--:--")
                    .font(F.num(44)).tracking(-1.76).lineLimit(1)
                Spacer(minLength: 8)
                if let best {
                    Text(PFTText.gap(best.total))
                        .font(F.t(F.foot, .semibold))
                        .foregroundStyle(grade == .gold ? C.good : C.text2)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.bottom, 7)
                }
            }
            .padding(.top, 10)
            PFTScale(total: best?.total)
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
        .accessibilityIdentifier("pft.best")
    }

    // MARK: HISTORY

    private func historyCard(_ recs: [Record]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                historyRow(recs, i, rec)
            }
        }
        .card8()
    }

    private func historyRow(_ recs: [Record], _ i: Int, _ rec: Record) -> some View {
        let older: Record? = recs.dropFirst(i + 1).first { $0.counts }
        let isBest: Bool = rec.id == store.pftBest?.id
        let d: Int? = (rec.counts ? older : nil).map { rec.total - $0.total }
        let sub: String
        if isBest && recs.filter(\.counts).count >= 2 { sub = "Personal best".l10n }
        else if let d {
            let arrow: String = d <= 0 ? "↓ " : "↑ "
            sub = arrow + Fm.t(abs(d)) + " " + "vs last".l10n
        }
        else { sub = Fm.time12.string(from: rec.date) }
        let color: Color = sub == "Personal best".l10n ? C.accent : (d == nil ? C.text2 : ((d ?? 0) <= 0 ? C.good : C.bad))
        return HistoryRow(title: Fm.wdm.string(from: rec.date), sub: sub, subColor: color,
                          time: Fm.t(rec.total), last: i == recs.count - 1, flag: rec.flag, grade: rec.pftGrade,
                          onDelete: { store.delete(rec) }) { r.open(rec, from: .sim) }
    }
}

// MARK: - 설명 카드 (무엇인지 + 등급 기준)

struct PFTAboutCard: View {
    /// 있으면 제목 오른쪽에 ⓘ
    var onInfo: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Physical Fitness Test").font(F.t(F.title3, .semibold)).tracking(-0.4)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onInfo {
                    InfoButton(id: "pft.info", action: onInfo)
                        .padding(.vertical, -8).padding(.trailing, -8)
                }
            }
            Text("Six movements back to back, no rest. Your total time shows your level.")
                .font(F.t(F.sub)).foregroundStyle(C.text2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PFTGrade.allCases, id: \.self) { g in
                    HStack(spacing: 10) {
                        PFTBadge(grade: g)
                        Text(PFTText.range(g)).font(F.num(F.sub, .regular)).lineLimit(1)
                    }
                }
            }
            .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
        .accessibilityIdentifier("pft.about")
    }
}

// MARK: - 종목 6개

struct PFTMovesCard: View {
    let div: Division

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PFT.items.indices, id: \.self) { i in
                row(i)
            }
        }
        .card8()
    }

    private func row(_ i: Int) -> some View {
        let it: PFT.Item = PFT.items[i]
        return HStack(spacing: 12) {
            Icon8(it.icon, 24, tint: .yellow)
            Text(it.long.l10n).font(F.t(F.body)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(PFT.amount(i, div)).font(F.num(F.foot)).tracking(0.39)
                .foregroundStyle(C.text2).lineLimit(1).fixedSize()
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .rowLine(i < PFT.items.count - 1)
    }
}

// MARK: - 등급 막대 (Gold | Silver | Bronze + 내 기록 위치)

struct PFTScale: View {
    let total: Int?

    private static let goldEnd: CGFloat = 0.44
    private static let silverEnd: CGFloat = 0.70

    /// 기록 위치 0…1 (Gold 12:00–22:00 · Silver 22:00–26:00 · Bronze 26:00–36:00)
    static func pos(_ t: Int) -> CGFloat {
        let x: CGFloat = CGFloat(t)
        let g: CGFloat = CGFloat(PFT.goldLimit), s: CGFloat = CGFloat(PFT.silverLimit)
        let lo: CGFloat = 12 * 60, hi: CGFloat = 36 * 60
        if x < g { return goldEnd * max(0, (x - lo) / (g - lo)) }
        if x <= s { return goldEnd + (silverEnd - goldEnd) * (x - g) / (s - g) }
        return silverEnd + (1 - silverEnd) * min(1, (x - s) / (hi - s))
    }

    var body: some View {
        GeometryReader { geo in
            content(width: geo.size.width)
        }
        .frame(height: 38)
    }

    private func bar(_ g: PFTGrade, width: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color(hex: g.hex2), Color(hex: g.hex1)], startPoint: .leading, endPoint: .trailing))
            .frame(width: max(0, width), height: 10)
    }

    private func tick(_ s: String, width: CGFloat) -> some View {
        Text(verbatim: s).font(F.num(F.cap2)).foregroundStyle(C.text2)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: max(0, width), alignment: .leading)
    }

    private func content(width w: CGFloat) -> some View {
        let gw: CGFloat = w * Self.goldEnd
        let sw: CGFloat = w * (Self.silverEnd - Self.goldEnd)
        let bw: CGFloat = w - gw - sw
        let markerX: CGFloat = total.map { min(w - 4, max(0, w * Self.pos($0) - 2)) } ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    bar(.gold, width: gw - 1)
                    bar(.silver, width: sw - 2)
                    bar(.bronze, width: bw - 1)
                }
                .clipShape(Capsule())
                if total != nil {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.white)
                        .frame(width: 4, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.black, lineWidth: 2))
                        .offset(x: markerX)
                }
            }
            .frame(width: w, height: 18, alignment: .leading)
            HStack(spacing: 0) {
                tick("Gold", width: gw)
                tick("22:00 · Silver", width: sw)
                tick("26:00 · Bronze", width: bw)
            }
        }
    }
}

// MARK: - 설명 시트 (ⓘ)

/// 시트 안 설명 줄: 아이콘 · 이름 · 한 줄 설명
private struct InfoRow: View {
    let icon: String
    let title: String
    let sub: String
    let last: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Icon8(icon, 24, tint: .yellow).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.l10n).font(F.t(F.body, .medium))
                Text(sub.l10n).font(F.t(F.foot)).foregroundStyle(C.text2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .rowLine(!last)
    }
}

struct PFTInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var rows: [(String, String, String)] {
        return [
            ("run", "Run", "1000 m. Outdoors, or on a treadmill at 2% incline."),
            ("burpeeBroadJump", "Burpee Broad Jumps", "50 reps."),
            ("sandbagLunges", "Stationary Lunges", "100 reps, no weight."),
            ("row", "Row", "1000 m."),
            ("pushUp", "Hand-Release Push-Ups", "30 reps. Lift your hands off the floor at the bottom."),
            ("wallBalls", "Wall Balls", "100 reps. 6 kg ball for men, 4 kg for women."),
        ]
    }

    var body: some View {
        let list: [(String, String, String)] = rows
        return ScrollView {
            VStack(spacing: 10) {
                NavBar3(left: "Close", title: "PFT", onLeft: { dismiss() }, edgeBack: false)
                PFTAboutCard()
                SectionLabel(text: "HOW IT WORKS", top: 10)
                VStack(spacing: 0) {
                    ForEach(list.indices, id: \.self) { i in
                        InfoRow(icon: list[i].0, title: list[i].1, sub: list[i].2, last: i == list.count - 1)
                    }
                }
                .card8()
                Note8(text: "The clock keeps running between movements. Tap Next (or swipe left on your watch) when you finish each one.")
                    .padding(.top, 4)
                Note8(text: "Grades are SPLITS8's own guide, not an official HYROX result.")
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
    }
}

struct SimInfoSheet: View {
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let div: Division = store.div
        return ScrollView {
            VStack(spacing: 10) {
                NavBar3(left: "Close", title: "Full Simulation", onLeft: { dismiss() }, edgeBack: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Full Simulation").font(F.t(F.title3, .semibold)).tracking(-0.4)
                    Text("The full race order for time: a 1 km run before each of the 8 stations.")
                        .font(F.t(F.sub)).foregroundStyle(C.text2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card8()
                SectionLabel(text: "STATIONS", top: 10)
                VStack(spacing: 0) {
                    ForEach(Station.all.indices, id: \.self) { i in
                        stationRow(i, div)
                    }
                }
                .card8()
                Note8(text: "Weights follow your division. Turn on Add Roxzone to time the transitions separately.")
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
    }

    private func stationRow(_ i: Int, _ div: Division) -> some View {
        let s: Station = Station.all[i]
        return HStack(spacing: 12) {
            Icon8(s.key, 24, tint: .yellow)
            Text("\(i + 1). " + s.name).font(F.t(F.body)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(s.detail(div)).font(F.num(F.foot)).foregroundStyle(C.text2).lineLimit(1).fixedSize()
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .rowLine(i < Station.all.count - 1)
    }
}
