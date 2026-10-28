import SwiftUI
import UIKit

// MARK: - 더블 계획 시트 (빌드 27) — Race 설정에서 디비전이 더블일 때만 열림
// 스테이션마다 "몇 m(개)씩 번갈아 · 누가 먼저"를 정함. 저장하면 워치로도 감 (WatchContext.doublesPlan).
// 공유: 계획 그림 + 링크 (받은 사람은 먼저 하는 사람이 바뀐 채로 저장됨 — Router.acceptIncomingDoubles)

/// .sheet(item:) 에 쓰는 스테이션 번호
private struct DblIndex: Identifiable {
    let id: Int
}

/// 막대 색: 나 = 노랑, 파트너 = 회색
enum DblColor {
    static let me: Color = C.accent
    static let partner: Color = Color(hex: 0x48484A)
}

struct DoublesPlanSheet: View {
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var plan: DoublesPlan = Store.shared.settings.doublesPlan ?? DoublesPlan()
    @State private var editing: DblIndex? = nil

    var body: some View {
        VStack(spacing: 10) {
            NavBar3(left: "Cancel", title: "Doubles plan", right: "Save",
                    onLeft: { dismiss() }, onRight: save, edgeBack: false)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    partnerCard
                    Note8(text: "Choose how much each of you does per turn and who goes first. Tap a station to change it.")
                    stationsCard
                    HStack(spacing: 10) { resetButton; shareButton }
                    Note8(text: "In Doubles, you run all 8 runs together. Only stations are split.")
                        .padding(.bottom, 16)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: 0x141414).ignoresSafeArea())
        .sheet(item: $editing) { e in
            DoublesStationSheet(plan: $plan, index: e.id)
                .presentationDetents([.large])
        }
    }

    private func save() {
        var p: DoublesPlan = plan
        p.partnerName = DoublesPlan.cleanName(p.partnerName)
        if p.partnerName == nil { p.partnerId = nil }
        store.settings.doublesPlan = p
        dismiss()
    }

    // MARK: 파트너

    private var nameBinding: Binding<String> {
        Binding<String>(
            get: { plan.partnerName ?? "" },
            set: { v in
                let t: String = String(v.prefix(20))
                plan.partnerName = t.isEmpty ? nil : t
                // 친구를 고른 뒤 이름을 고치면 친구 연결을 끊음
                if let id = plan.partnerId, let f = store.friends.first(where: { $0.id == id }), f.name != t {
                    plan.partnerId = nil
                }
            })
    }

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label8("PARTNER")
            TextField("", text: nameBinding, prompt: Text("Partner".l10n).foregroundColor(C.text3))
                .font(F.t(17)).foregroundStyle(.white)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("dbl.partner")
            if !store.shownFriends.isEmpty {
                Text("Or pick a friend").font(F.t(13)).foregroundStyle(C.text2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.shownFriends) { f in
                            friendChip(f)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
    }

    private func friendChip(_ f: Friend) -> some View {
        let on: Bool = plan.partnerId == f.id
        return Button {
            if on {
                plan.partnerId = nil
                plan.partnerName = nil
            } else {
                plan.partnerId = f.id
                plan.partnerName = DoublesPlan.cleanName(f.name)
            }
        } label: {
            Text(f.name).font(F.t(13, .semibold)).lineLimit(1)
                .foregroundStyle(on ? Color.black : Color.white)
                .padding(.horizontal, 14).frame(height: 34)
                .background(on ? C.accent : Color.white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.96))
        .accessibilityIdentifier("dbl.friend." + f.id)
    }

    // MARK: 스테이션 8줄

    private var stationsCard: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { i in
                stationRow(i, last: i == 7)
            }
        }
        .card8()
    }

    /// 아이콘 + 이름 + "150 m씩 · 나 먼저 ›" / 막대 / "나 550 m · 파트너 450 m"
    private func stationRow(_ i: Int, last: Bool) -> some View {
        let s: Station = Station.all[i]
        return Button { editing = DblIndex(id: i) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Icon8(s.key, 20, C.accent)
                    Text(s.name.l10n).font(F.t(15, .semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(DblText.summary(plan, i)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Chevron8()
                }
                DoublesBar(plan: plan, index: i, height: 8)
                Text(DblText.totals(plan, i)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("dbl." + s.key)
    }

    // MARK: 버튼

    private var resetButton: some View {
        Button {
            let name: String? = plan.partnerName, id: String? = plan.partnerId
            plan = DoublesPlan()
            plan.partnerName = name
            plan.partnerId = id
        } label: {
            Text("Reset".l10n).font(F.t(15, .semibold))
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("dbl.reset")
    }

    /// 계획 그림 + 링크를 iOS 공유 창으로
    private var shareButton: some View {
        Button { share() } label: {
            Text("Share".l10n).font(F.t(15, .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("dbl.share")
    }

    @MainActor private func share() {
        let sender: String? = store.settings.nickname
        var items: [Any] = []
        if let img = DoublesShare.image(plan: plan, division: store.div.name) { items.append(img) }
        var text: String = "SPLITS8 Doubles plan".l10n
        if let u = DoublesLink.webURL(plan, sender: sender) { text += "\n" + u.absoluteString }
        items.append(text)
        ShareSheet.present(items)
    }
}

// MARK: - 글자 모음

enum DblText {
    /// "150 m씩 · 나 먼저" / "한 바퀴(12.5 m)씩 · 가테부 먼저"
    static func summary(_ p: DoublesPlan, _ i: Int) -> String {
        chunkLabel(p.chunk(i), i) + " · " + firstLabel(p, me: p.meFirst(i))
    }
    /// "150 m씩" / "1 length (12.5 m)"
    static func chunkLabel(_ v: Double, _ i: Int) -> String {
        if DoublesPlan.isFixed(i) { return "1 length (12.5 m)".l10n }
        return String(format: "%@ each".l10n, DoublesPlan.amountText(i, v))
    }
    /// "나 먼저" / "가테부 먼저"
    static func firstLabel(_ p: DoublesPlan, me: Bool) -> String {
        me ? "Me first".l10n : String(format: "%@ first".l10n, p.partnerShown)
    }
    /// "나 550 m · 파트너 450 m"
    static func totals(_ p: DoublesPlan, _ i: Int) -> String {
        "Me".l10n + " " + DoublesPlan.amountText(i, p.mine(i)) + " · "
            + p.partnerShown + " " + DoublesPlan.amountText(i, p.partners(i))
    }
    /// 공유 그림 한 줄: "나 150 → 파 150 → 나 150 → …"
    static func flow(_ p: DoublesPlan, _ i: Int, max: Int = 4) -> String {
        let me: String = "Me".l10n
        let yu: String = String(p.partnerShown.prefix(1))
        let seq: [(me: Bool, amount: Double)] = p.sequence(i)
        var parts: [String] = []
        for t in seq.prefix(max) { parts.append((t.me ? me : yu) + " " + DoublesPlan.num(t.amount)) }
        var s: String = parts.joined(separator: " → ")
        if seq.count > max { s += " → …" }
        return s
    }
    static func turns(_ n: Int) -> String { String(format: "%lld turns".l10n, Int64(n)) }
}

// MARK: - 막대 (나 노랑 · 파트너 회색, 차례마다 한 칸)

struct DoublesBar: View {
    let plan: DoublesPlan
    let index: Int
    var height: CGFloat = 8

    var body: some View {
        let seq: [(me: Bool, amount: Double)] = plan.sequence(index)
        let total: Double = max(1, DoublesPlan.total(index))
        let gap: CGFloat = 2
        return GeometryReader { g in
            let free: CGFloat = max(0, g.size.width - gap * CGFloat(max(0, seq.count - 1)))
            HStack(spacing: gap) {
                ForEach(Array(seq.enumerated()), id: \.offset) { _, t in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(t.me ? DblColor.me : DblColor.partner)
                        .frame(width: max(1, free * CGFloat(t.amount / total)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - 스테이션 하나 고치기 시트

struct DoublesStationSheet: View {
    @Binding var plan: DoublesPlan
    let index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DoublesPlan = DoublesPlan()
    @State private var loaded = false

    var body: some View {
        let s: Station = Station.all[index]
        return VStack(spacing: 10) {
            NavBar3(left: "Cancel", title: s.name, right: "Done",
                    onLeft: { dismiss() }, onRight: { plan = draft; dismiss() }, edgeBack: false)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    choiceCard
                    listCard
                }
                .padding(.top, 4).padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: 0x141414).ignoresSafeArea())
        .onAppear {
            if !loaded { draft = plan; loaded = true }
        }
    }

    private var choiceCard: some View {
        let i: Int = index
        let opts: [Double] = DoublesPlan.options[i]
        return VStack(alignment: .leading, spacing: 12) {
            Label8("EACH TURN")
            if DoublesPlan.isFixed(i) {
                Text("1 length (12.5 m)".l10n).font(F.t(15, .semibold))
            } else {
                Seg8(items: opts.map { (DoublesPlan.num($0), DoublesPlan.amountText(i, $0)) },
                     selected: DoublesPlan.num(draft.chunk(i))) { k in
                    if let v = opts.first(where: { DoublesPlan.num($0) == k }) { draft.setChunk(i, v) }
                }
                .accessibilityIdentifier("dbl.chunk")
            }
            Label8("WHO GOES FIRST").padding(.top, 4)
            Seg8(items: [("me", "Me"), ("partner", draft.partnerShown)],
                 selected: draft.meFirst(i) ? "me" : "partner") { k in
                draft.setMeFirst(i, k == "me")
            }
            .accessibilityIdentifier("dbl.first")
            DoublesBar(plan: draft, index: i, height: 10).padding(.top, 4)
            HStack {
                Text(DblText.totals(draft, i)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                Spacer(minLength: 8)
                Text(DblText.turns(draft.turns(i))).font(F.t(13)).foregroundStyle(C.text3).lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
    }

    /// "1  나  150 m   0 → 150 m"
    private var listCard: some View {
        let i: Int = index
        let seq: [(me: Bool, amount: Double)] = draft.sequence(i)
        var starts: [Double] = []
        var acc: Double = 0
        for t in seq { starts.append(acc); acc += t.amount }
        let unit: String = DoublesPlan.isReps(i) ? "" : " m"
        return VStack(spacing: 0) {
            ForEach(Array(seq.enumerated()), id: \.offset) { n, t in
                HStack(spacing: 12) {
                    Text("\(n + 1)").font(F.num(13)).foregroundStyle(C.text3).frame(width: 22, alignment: .leading)
                    Circle().fill(t.me ? DblColor.me : DblColor.partner).frame(width: 8, height: 8)
                    Text(t.me ? "Me".l10n : draft.partnerShown).font(F.t(15, .semibold)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(DoublesPlan.amountText(i, t.amount)).font(F.num(15)).foregroundStyle(.white)
                    Text(DoublesPlan.num(starts[n]) + " → " + DoublesPlan.num(starts[n] + t.amount) + unit)
                        .font(F.num(13, .regular)).foregroundStyle(C.text2)
                        .frame(minWidth: 96, alignment: .trailing)
                }
                .padding(.vertical, 11).padding(.horizontal, 16)
                .rowLine(n < seq.count - 1)
            }
        }
        .card8()
    }
}

// MARK: - 공유 그림

/// 공유용 카드 (360pt 너비 → 3배로 그림)
struct DoublesShareCard: View {
    let plan: DoublesPlan
    let division: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 22)
            Text("Our doubles plan".l10n).font(F.t(28, .semibold)).foregroundStyle(.white)
                .padding(.top, 18)
            Text(division.l10n + " · " + "Me".l10n + " & " + plan.partnerShown)
                .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                .padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    row(i)
                }
            }
            .padding(.top, 16)
            HStack(spacing: 14) {
                legend(DblColor.me, "Me".l10n)
                legend(DblColor.partner, plan.partnerShown)
            }
            .padding(.top, 14)
        }
        .padding(22)
        .frame(width: 360, alignment: .leading)
        .background(Color.black)
    }

    private func row(_ i: Int) -> some View {
        let s: Station = Station.all[i]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Icon8(s.key, 16, C.accent)
                Text(s.name.l10n).font(F.t(13, .semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 6)
                Text(DblText.chunkLabel(plan.chunk(i), i)).font(F.t(11)).foregroundStyle(C.text2).lineLimit(1)
            }
            Text(DblText.flow(plan, i)).font(F.num(13, .regular)).foregroundStyle(C.d1).lineLimit(1)
                .minimumScaleFactor(0.7)
            DoublesBar(plan: plan, index: i, height: 5)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { if i < 7 { Rectangle().fill(C.line).frame(height: 1) } }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 12, height: 6)
            Text(t).font(F.t(11)).foregroundStyle(C.text2).lineLimit(1)
        }
    }
}

enum DoublesShare {
    @MainActor static func image(plan: DoublesPlan, division: String) -> UIImage? {
        let rr = ImageRenderer(content: DoublesShareCard(plan: plan, division: division).environment(\.colorScheme, .dark))
        rr.scale = 3
        if let img = rr.uiImage { return img }
        rr.scale = 2
        return rr.uiImage
    }
}
