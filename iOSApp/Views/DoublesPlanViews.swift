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
                    Text(DblText.summaryLine(plan, i)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
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
    /// "150 m씩" / "한 바퀴(12.5 m)씩" (1.2.1: 슬레드는 반 · 한 · 두 바퀴)
    static func chunkLabel(_ v: Double, _ i: Int) -> String {
        if DoublesPlan.isSled(i) { return sledLabel(v) }
        return String(format: "%@ each".l10n, DoublesPlan.amountText(i, v))
    }
    /// 슬레드 한 번 양 이름
    static func sledLabel(_ v: Double) -> String {
        if abs(v - 6.25) < 0.001 { return "Half length (6.25 m)".l10n }
        if abs(v - 25) < 0.001 { return "2 lengths (25 m)".l10n }
        return "1 length (12.5 m)".l10n
    }
    /// 세그먼트 버튼용 짧은 이름 ("½ 바퀴" · "1 바퀴" · "2 바퀴")
    static func sledShort(_ v: Double) -> String {
        if abs(v - 6.25) < 0.001 { return "½ length".l10n }
        if abs(v - 25) < 0.001 { return "2 lengths".l10n }
        return "1 length".l10n
    }
    /// 스테이션 줄 요약: 손으로 고쳤으면 "직접 설정 · 나 먼저"
    static func summaryLine(_ p: DoublesPlan, _ i: Int) -> String {
        (p.isEdited(i) ? "Custom turns".l10n : chunkLabel(p.chunk(i), i)) + " · " + firstLabel(p, me: p.meFirst(i))
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
    /// 1.2.1: 고친 차례가 있을 때 한 번 양을 다시 고르면 먼저 물어봄
    @State private var pendingChunk: Double? = nil
    /// 1.2.1: 못 누르는 이유 안내 ("SkiErg 는 모두 1000 m 예요" 등). 잠깐 보였다 사라짐
    @State private var hint: String = ""
    @State private var hintTick: Int = 0

    var body: some View {
        let s: Station = Station.all[index]
        return VStack(spacing: 10) {
            NavBar3(left: "Cancel", title: s.name, right: "Done",
                    onLeft: { dismiss() }, onRight: { plan = draft; dismiss() }, edgeBack: false)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    choiceCard
                    listCard
                    Note8(text: "Tap + or − to change a turn. The last turn is whatever is left, so the total always adds up.")
                }
                .padding(.top, 4).padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: 0x141414).ignoresSafeArea())
        .onAppear {
            if !loaded { draft = plan; loaded = true }
        }
        .alert("Reset your custom turns?", isPresented: Binding(get: { pendingChunk != nil }, set: { if !$0 { pendingChunk = nil } }),
               presenting: pendingChunk) { c in
            Button("Reset", role: .destructive) { draft.resetTurns(index); draft.setChunk(index, c); pendingChunk = nil }
            Button("Cancel", role: .cancel) { pendingChunk = nil }
        } message: { _ in
            Text("Choosing a new amount per turn replaces the turns you changed by hand.")
        }
    }

    private func pick(_ c: Double) {
        if draft.isEdited(index) { pendingChunk = c } else { draft.setChunk(index, c) }
    }

    private func showHint(_ t: String) {
        hint = t
        hintTick += 1
        let tick: Int = hintTick
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if hintTick == tick { hint = "" }
        }
    }

    private var choiceCard: some View {
        let i: Int = index
        let opts: [Double] = DoublesPlan.options[i]
        return VStack(alignment: .leading, spacing: 12) {
            Label8("EACH TURN")
            // 1.2.1: 슬레드도 반 · 한 · 두 바퀴 중 고름. 고친 차례가 있으면 바꾸기 전에 확인
            Seg8(items: opts.map { (DoublesPlan.num($0), DoublesPlan.isSled(i) ? DblText.sledShort($0) : DoublesPlan.amountText(i, $0)) },
                 selected: draft.isEdited(i) ? "" : DoublesPlan.num(draft.chunk(i))) { k in
                if let v = opts.first(where: { DoublesPlan.num($0) == k }) { pick(v) }
            }
            .accessibilityIdentifier("dbl.chunk")
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

    /// "1  나  150 m   0 → 150 m   − +"  (1.2.1: 줄마다 +/−, 마지막 줄은 나머지)
    private var listCard: some View {
        let i: Int = index
        let seq: [(me: Bool, amount: Double)] = draft.sequence(i)
        let fixedCount: Int = draft.fixedTurns(i).count
        var starts: [Double] = []
        var acc: Double = 0
        for t in seq { starts.append(acc); acc += t.amount }
        let unit: String = DoublesPlan.isReps(i) ? "" : " m"
        let full: Bool = draft.remainder(i) < DoublesPlan.eps
        return VStack(spacing: 0) {
            ForEach(Array(seq.enumerated()), id: \.offset) { n, t in
                let isRest: Bool = n >= fixedCount
                HStack(spacing: 10) {
                    Text("\(n + 1)").font(F.num(13)).foregroundStyle(C.text3).frame(width: 20, alignment: .leading)
                    Circle().fill(t.me ? DblColor.me : DblColor.partner).frame(width: 8, height: 8).opacity(isRest ? 0.6 : 1)
                    HStack(spacing: 6) {
                        Text(t.me ? "Me".l10n : draft.partnerShown).font(F.t(15, isRest ? .medium : .semibold)).lineLimit(1)
                            .foregroundStyle(isRest ? C.text2 : .white)
                        if isRest {
                            Text("Remainder".l10n).font(F.t(10, .semibold)).foregroundStyle(C.text3)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(C.line, lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(DoublesPlan.amountText(i, t.amount)).font(F.num(15)).foregroundStyle(isRest ? C.text2 : .white)
                        Text(DoublesPlan.num(starts[n]) + " → " + DoublesPlan.num(starts[n] + t.amount) + unit)
                            .font(F.num(11, .regular)).foregroundStyle(C.text3)
                    }
                    HStack(spacing: 6) {
                        stepButton("minus", on: isRest ? draft.canSplitRemainder(i) : draft.canMinus(i, n), id: "dbl.minus.\(n)") {
                            if isRest { draft.splitRemainder(i) } else { draft.minus(i, n) }
                        } blocked: {
                            showHint(isRest ? String(format: "Only %@ left — can't split it further.".l10n, DoublesPlan.amountText(i, t.amount))
                                            : String(format: "A turn is at least %@.".l10n, DoublesPlan.amountText(i, DoublesPlan.unit(i))))
                        }
                        stepButton("plus", on: !isRest && !full, id: "dbl.plus.\(n)") {
                            draft.plus(i, n)
                        } blocked: {
                            showHint(isRest ? "The last turn is whatever is left.".l10n
                                            : String(format: "%@ is %@ in total — nothing left to add.".l10n, Station.all[i].name.l10n, DoublesPlan.amountText(i, DoublesPlan.total(i))))
                        }
                    }
                }
                .padding(.vertical, 9).padding(.horizontal, 16)
                .rowLine(n < seq.count - 1)
                .accessibilityIdentifier("dbl.turn.\(n)")
            }
            if !hint.isEmpty {
                Text(hint).font(F.t(12)).foregroundStyle(C.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: hint)
        .card8()
    }

    /// 동그란 +/− 버튼. 못 누르는 상태면 흐리게 보이고, 누르면 이유를 알려 줌
    private func stepButton(_ symbol: String, on: Bool, id: String, action: @escaping () -> Void, blocked: @escaping () -> Void) -> some View {
        Button {
            if on {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.15)) { action() }
            } else {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                blocked()
            }
        } label: {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? Color.white : C.text3)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(on ? 0.12 : 0.05)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
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
                Text(plan.isEdited(i) ? "Custom turns".l10n : DblText.chunkLabel(plan.chunk(i), i)).font(F.t(11)).foregroundStyle(C.text2).lineLimit(1)
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
