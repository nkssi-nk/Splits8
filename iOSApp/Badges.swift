import SwiftUI

// MARK: - 빌드 24 · 배지 (폰 안 기록만으로 계산 → 서버 필요 없음, 무료)
// 처음에 넣는 묶음 (대표님 추천안): ① 처음 해 보기 ② 기록 넘기기 ③ 꾸준함.
// 예전 기록으로도 소급해서 받음 (기록 날짜 순서대로 다시 계산). 미완료 · 확인 필요 기록은 세지 않음.

struct Badge: Identifiable, Hashable {
    let id: String
    /// 묶음: first / record / habit
    let group: String
    let title: String
    let sub: String
    /// SF Symbol 이름
    let icon: String
}

enum Badges {
    static let all: [Badge] = [
        // ① 처음 해 보기
        Badge(id: "firstSim", group: "first", title: "First Full Sim", sub: "Finish your first Full Simulation.", icon: "flag.checkered"),
        Badge(id: "firstRace", group: "first", title: "Race day", sub: "Record your first HYROX race.", icon: "medal"),
        Badge(id: "firstPFT", group: "first", title: "First PFT", sub: "Finish your first PFT.", icon: "stopwatch"),
        Badge(id: "allStations", group: "first", title: "All 8 stations", sub: "Do every HYROX station at least once.", icon: "square.grid.3x3.fill"),
        // ② 기록 넘기기
        Badge(id: "sub130", group: "record", title: "Sub 1:30", sub: "Full Simulation or race under 1:30:00.", icon: "timer"),
        Badge(id: "sub120", group: "record", title: "Sub 1:20", sub: "Full Simulation or race under 1:20:00.", icon: "timer"),
        Badge(id: "sub110", group: "record", title: "Sub 1:10", sub: "Full Simulation or race under 1:10:00.", icon: "bolt.fill"),
        Badge(id: "sub100", group: "record", title: "Sub 1:00", sub: "Full Simulation or race under 1:00:00.", icon: "crown.fill"),
        Badge(id: "pb5", group: "record", title: "5 PBs", sub: "Beat your best Full Simulation 5 times.", icon: "arrow.up.right"),
        Badge(id: "pb10", group: "record", title: "10 PBs", sub: "Beat your best Full Simulation 10 times.", icon: "chart.line.uptrend.xyaxis"),
        // ③ 꾸준함
        Badge(id: "weeks4", group: "habit", title: "4 weeks in a row", sub: "Work out at least once a week for 4 weeks.", icon: "calendar"),
        Badge(id: "month12", group: "habit", title: "12 in a month", sub: "12 workouts in one calendar month.", icon: "calendar.badge.checkmark"),
        Badge(id: "run100", group: "habit", title: "100 km run", sub: "Run 100 km in total across your workouts.", icon: "figure.run"),
        Badge(id: "run500", group: "habit", title: "500 km run", sub: "Run 500 km in total across your workouts.", icon: "road.lanes"),
    ]

    static let groups: [(String, String)] = [("first", "FIRST STEPS"), ("record", "RECORDS"), ("habit", "CONSISTENCY")]

    /// 받은 배지 → 받은 날 (그 기준을 처음 넘긴 기록의 날짜)
    static func earned(_ records: [Record]) -> [String: Date] {
        let rs: [Record] = records.filter(\.counts).sorted { $0.date < $1.date }
        var got: [String: Date] = [:]
        func give(_ id: String, _ d: Date) { if got[id] == nil { got[id] = d } }

        var stations: Set<String> = []
        var best: Int? = nil
        var pbs = 0
        var ranM: Double = 0
        var weeks: [Date] = []          // 운동한 주의 시작일 (중복 없이, 순서대로)
        var monthCount: [String: Int] = [:]
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        for r in rs {
            let full: Bool = r.mode == .sim || r.mode == .race
            // ① 처음 해 보기
            if r.mode == .sim && r.isComplete { give("firstSim", r.date) }
            if r.mode == .race && r.isComplete { give("firstRace", r.date) }
            if r.mode == .pft && r.isComplete { give("firstPFT", r.date) }
            for s in r.segs where s.kind == .st && s.time > 0 && Station.of(s.icon) != nil { stations.insert(s.icon) }
            if stations.count >= Station.all.count { give("allStations", r.date) }
            // ② 기록 넘기기 (끝까지 한 풀 시뮬 · 레이스)
            if full && r.isComplete && r.splits16 != nil {
                if r.total < 5400 { give("sub130", r.date) }
                if r.total < 4800 { give("sub120", r.date) }
                if r.total < 4200 { give("sub110", r.date) }
                if r.total < 3600 { give("sub100", r.date) }
            }
            if r.mode == .sim && r.isComplete && r.splits16 != nil {
                if let b = best, r.total < b { pbs += 1 }
                best = min(best ?? Int.max, r.total)
                if pbs >= 5 { give("pb5", r.date) }
                if pbs >= 10 { give("pb10", r.date) }
            }
            // ③ 꾸준함
            for s in r.segs where s.kind == .run { ranM += s.dist ?? runMeters(s.detail) }
            if ranM >= 100_000 { give("run100", r.date) }
            if ranM >= 500_000 { give("run500", r.date) }
            if let w = cal.dateInterval(of: .weekOfYear, for: r.date)?.start, weeks.last != w {
                weeks.append(w)
                if weeks.count >= 4 {
                    let last4: ArraySlice<Date> = weeks.suffix(4)
                    let span: Double = last4.last!.timeIntervalSince(last4.first!)
                    // 4주 연속 = 첫 주와 넷째 주 시작일이 3주(±하루, 서머타임) 차이
                    if abs(span - 3 * 7 * 86400) < 26 * 3600 { give("weeks4", r.date) }
                }
            }
            let mk: String = Fm.ymd.string(from: r.date).prefix(7).description
            monthCount[mk, default: 0] += 1
            if monthCount[mk, default: 0] >= 12 { give("month12", r.date) }
        }
        return got
    }

    /// 이 기록으로 새로 받은 배지 (운동 끝 카드에 보여 줌)
    static func new(with rec: Record, in records: [Record]) -> [Badge] {
        let before: [String: Date] = earned(records.filter { $0.id != rec.id })
        let after: [String: Date] = earned(records.contains { $0.id == rec.id } ? records : records + [rec])
        return all.filter { after[$0.id] != nil && before[$0.id] == nil }
    }
}

/// 배지 하나 (동그라미 + 아이콘). 못 받은 것은 흐리게
struct BadgeIcon: View {
    let b: Badge
    let on: Bool
    var size: CGFloat = 54
    var body: some View {
        ZStack {
            Circle()
                .fill(on ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE600), Color(hex: 0xFFB800)], startPoint: .top, endPoint: .bottom))
                         : AnyShapeStyle(Color.white.opacity(0.06)))
            Circle().strokeBorder(on ? Color.white.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
            Image(systemName: b.icon).font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(on ? Color.black : C.text3)
        }
        .frame(width: size, height: size)
        .shadow(color: on ? C.accent.opacity(0.35) : .clear, radius: 8)
    }
}

/// 내 정보(프로필 화면)의 배지 모음
struct BadgesCard: View {
    let store = Store.shared
    @State private var pick: Badge?

    var body: some View {
        let got: [String: Date] = Badges.earned(store.records)
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionText("BADGES")
                Spacer(minLength: 0)
                Text(verbatim: "\(got.count) / \(Badges.all.count)").font(F.num(13)).foregroundStyle(C.text2)
                    .accessibilityIdentifier("badges.count")
            }
            .padding(.top, 14).padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Badges.groups, id: \.0) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        Label8(g.1, size: 11)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                            ForEach(Badges.all.filter { $0.group == g.0 }) { b in
                                Button { pick = b } label: {
                                    VStack(spacing: 6) {
                                        BadgeIcon(b: b, on: got[b.id] != nil)
                                        Text(b.title.l10n).font(F.t(11, .medium))
                                            .foregroundStyle(got[b.id] != nil ? .white : C.text3)
                                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                                            .frame(height: 28, alignment: .top)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(Press(scale: 0.95))
                                .accessibilityIdentifier("badge.\(b.id)")
                            }
                        }
                    }
                }
            }
            .padding(16)
            .card8()
        }
        .alert(pick?.title.l10n ?? "", isPresented: Binding(get: { pick != nil }, set: { if !$0 { pick = nil } })) {
            Button("OK", role: .cancel) { pick = nil }
        } message: {
            if let b = pick {
                if let d = got[b.id] {
                    Text(b.sub.l10n + "\n" + String(localized: "Earned \(Fm.wdm.string(from: d))"))
                } else {
                    Text(b.sub.l10n)
                }
            }
        }
    }
}

/// 운동 끝 카드 안: "새 배지" 한 줄 (여러 개면 아이콘을 나란히)
struct NewBadgesRow: View {
    let badges: [Badge]
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(badges.prefix(3)) { b in BadgeIcon(b: b, on: true, size: 36) }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(badges.count == 1 ? "New badge".l10n : String(localized: "\(badges.count) new badges"))
                    .font(F.t(F.cap1, .bold)).tracking(0.06 * 12).foregroundStyle(C.accent)
                Text(badges.map { $0.title.l10n }.joined(separator: " · ")).font(F.t(15, .semibold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(C.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(C.accent.opacity(0.30), lineWidth: 1))
        .accessibilityIdentifier("finish.badges")
    }
}
