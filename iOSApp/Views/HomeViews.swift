import SwiftUI

// MARK: - I1h Home (시안 SplitsPhone.dc.html · isHomeTab / homeVals)

struct HomeView: View {
    let store = Store.shared
    let r = Router.shared
    /// 이번 주 / 이번 달 요약 선택 (week / month)
    @AppStorage("home.summaryPeriod") private var period: String = "week"

    var body: some View {
        VStack(spacing: 10) {
            // 대표님 요청 순서: 프로필 → 대회 일정 → 기록 달력(예약·기록 확인) → 주/월 요약 (예정된 운동 목록은 달력으로 대체)
            Group {
                profileCard
                SectionLabel(text: "NEXT RACE")
                nextRace
                SectionLabel(text: "CALENDAR")
                HistoryCalendar()
                summaryHeader
                summaryCard
            }
            SectionLabel(text: "MODES")
            startTiles
            SectionLabel(text: "PERSONAL BESTS")
            bests
            let rec = recent
            if !rec.isEmpty {
                SectionLabel(text: "RECENT")
                VStack(spacing: 0) {
                    ForEach(Array(rec.enumerated()), id: \.element.id) { i, x in
                        recentRow(x, last: i == rec.count - 1)
                    }
                }
                .card8()
            }
            SectionLabel(text: "FRIENDS")
            friends
        }
        .padding(.top, 6)
        .padding(.horizontal, 16)
    }

    // 프로필: 52 원, @nick 17/600, 체급 13 회색 · 오른쪽에 내 최고 기록 (편집은 설정 → 프로필에서만)
    private var profileCard: some View {
        let signed = store.signedIn, nick = store.settings.nickname ?? ""
        return HStack(spacing: 14) {
            Avatar8(size: 52, photo: store.photo, initial: signed ? String(nick.prefix(1)).uppercased() : "?",
                    bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2, fontSize: 20)
                .photoTap(store.photo.map { PhotoItem(image: $0, title: signed ? "@" + nick : "My profile".l10n, sub: store.div.name) })
                .accessibilityIdentifier("home.photo")
            VStack(alignment: .leading, spacing: 2) {
                // 아이디 옆에 PFT 등급 뱃지 (내 최고 PFT 기록의 등급)
                HStack(spacing: 8) {
                    Text(signed ? "@" + nick : "My profile".l10n).font(F.t(17, .semibold)).tracking(-0.17).lineLimit(1)
                    if let g = store.pftGrade {
                        PFTBadge(grade: g).accessibilityIdentifier("home.pftBadge")
                    }
                }
                Text(store.div.name).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            profileBest
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .card8()
        .accessibilityIdentifier("home.profile")
    }

    /// 내 최고 기록: Full Sim 최고 (없으면 Race 최고). 둘 다 없으면 표시 안 함
    @ViewBuilder private var profileBest: some View {
        let sim: Record? = store.simBest
        let best: Record? = sim ?? store.raceBest
        if let b = best {
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .semibold))
                    Text("PB").font(F.t(11, .semibold)).tracking(0.22)
                }
                .foregroundStyle(C.accent)
                Text(Fm.t(b.total)).font(F.num(22)).tracking(-0.44).lineLimit(1)
                Text(sim != nil ? "Full Sim" : "Race").font(F.t(F.foot)).foregroundStyle(C.text2)
            }
            .fixedSize()
        } else {
            // 기록이 아직 없으면 목표 시간
            VStack(alignment: .trailing, spacing: 1) {
                Text("GOAL").font(F.t(11, .semibold)).tracking(0.22).foregroundStyle(C.text2)
                Text(Fm.t(store.settings.goalTime)).font(F.num(22)).tracking(-0.44).lineLimit(1)
                Text("Race goal").font(F.t(F.foot)).foregroundStyle(C.text2)
            }
            .fixedSize()
        }
    }

    // 다음 대회: 이름 20/600 · 장소·날짜·시간 13 · D-day 28/600 노랑 · 체급 11
    @ViewBuilder private var nextRace: some View {
        let ev = store.settings.event
        if ev.isSet {
            Button { r.go(.race) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ev.name).font(F.t(20, .semibold)).tracking(-0.2).lineLimit(1)
                        Text(eventSub(ev)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dday(ev.date)).font(F.num(28)).tracking(-0.84).foregroundStyle(C.accent).lineLimit(1)
                        Text(store.div.name).font(F.t(F.foot)).foregroundStyle(C.text2)
                    }
                    .fixedSize()
                }
                .padding(.vertical, 16).padding(.horizontal, 18)
                .background { raceCardBg(near: isNear(ev.date)) }
                .contentShape(Rectangle())
            }
            .buttonStyle(Press())
        } else {
            HStack(spacing: 12) {
                Text("No race added yet. Add one to start it right away from Race on your watch.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                YellowPill(title: "Add event") { r.evDraft = store.settings.event; r.go(.findEvent) }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .card8()
        }
    }

    // 시작: 4칸 86 높이 (워치 홈과 같은 순서: Training · PFT · Full Sim · Race)
    private var startTiles: some View {
        HStack(spacing: 8) {
            startTile("Training", to: .training) { Icon8("modeTraining", 28, C.accent) }
            startTile("PFT", to: .pft) { Icon8("modePFT", 28, C.accent) }
            startTile("Full Sim", to: .sim) { Glyph("i_sim", 28, C.accent) }   // 탭 바와 같은 아이콘
            startTile("Race", to: .race) { Glyph("i_race", 28, C.accent) }
        }
    }
    private func startTile<I: View>(_ label: String, to: Mode, @ViewBuilder icon: () -> I) -> some View {
        Button { r.goMode(to) } label: {
            VStack(spacing: 8) {
                icon()
                Text(label.l10n).font(F.t(13, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 86)
            .card8()
            .contentShape(Rectangle())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("home.start." + label)
    }

    // 최고 기록: 3칸
    private var bests: some View {
        let sim = store.simBest, race = store.raceBest
        let pace = (store.records(.sim) + store.records(.race)).filter(\.counts).compactMap(\.runPace).min()
        return HStack(spacing: 8) {
            bestTile("FULL SIM", sim.map { Fm.t($0.total) } ?? "--", sim.map { Fm.dm.string(from: $0.date) } ?? "No record")
            bestTile("RACE", race.map { Fm.t($0.total) } ?? "--", race?.title ?? "No record")
            bestTile("RUN AVG", pace.map { Fm.t($0) } ?? "--", "per km")
        }
    }
    private func bestTile(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label8(label, spacing: 0.08)
            Text(value).font(F.num(20)).tracking(-0.4).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 6)
            Text(sub.l10n).font(F.t(F.foot)).foregroundStyle(C.text3).lineLimit(1).minimumScaleFactor(0.85).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 12)
        .card8()
    }

    // 최근 3개
    private var recent: [Record] { Array(store.records.sorted { $0.date > $1.date }.prefix(3)) }
    private func recentRow(_ x: Record, last: Bool) -> some View {
        let d = Fm.wdm.string(from: x.date)
        let sub: String = Self.recentSub(x.mode, d)
        let title: String = x.mode == .sim ? "Full Simulation".l10n : x.title.l10n
        return Button { r.goMode(x.mode) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(F.t(15, .semibold)).lineLimit(1)
                        if let g = x.pftGrade { PFTBadge(grade: g) }
                        if let f = x.flag { FlagPill(flag: f) }
                    }
                    Text(sub).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Fm.t(x.total)).font(F.num(17)).tracking(-0.34).lineLimit(1)
                Chevron8()
            }
            .padding(.horizontal, 18).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }

    /// Training · Wed 24 Sep / Race · … / (Full Sim 은 날짜만)
    private static func recentSub(_ m: Mode, _ d: String) -> String {
        switch m {
        case .training: return "Training".l10n + " · " + d
        case .race: return "Race".l10n + " · " + d
        case .sim, .pft: return d
        }
    }

    // 친구: 가입 전 카드 / 순위 3줄
    @ViewBuilder private var friends: some View {
        if !store.signedIn {
            HStack(spacing: 12) {
                Text("Sign up to compare workouts and rankings with friends.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                YellowPill(title: "Sign up") { r.toAuth(from: .home) }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .card8()
        } else {
            let rows = Array(store.leaderboard.sorted { $0.t < $1.t }.prefix(3))
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("No friend records yet").font(F.t(13)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).frame(minHeight: 52)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, x in
                    let me = x.nickname == store.settings.nickname
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(F.num(15)).foregroundStyle(i == 0 ? C.accent : .white).frame(width: 22, alignment: .leading)
                        Text("@" + x.nickname + (me ? " (you)".l10n : "")).font(F.t(15, me ? .semibold : .medium))
                            .foregroundStyle(me ? C.accent : .white).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Fm.t(x.t)).font(F.num(17)).tracking(-0.34)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 52)
                    .background(me ? Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.08) : .clear)
                    .rowLine(i < rows.count - 1)
                }
            }
            .card8()
        }
    }

    // MARK: 이번 주 / 이번 달 요약 (Phase 2 · m1)

    private var isWeek: Bool { period != "month" }

    private var summaryHeader: some View {
        HStack(spacing: 8) {
            Label8(isWeek ? "THIS WEEK" : "THIS MONTH")
            Spacer(minLength: 0)
            Seg8(items: [("week", "Week"), ("month", "Month")], selected: isWeek ? "week" : "month",
                 height: 28, radius: 10, fontSize: 13, minWidth: 56) { k in
                withAnimation(.easeInOut(duration: 0.2)) { period = k }
            }
            .fixedSize()
            .accessibilityIdentifier("home.summary.period")
        }
        .padding(.top, 14).padding(.horizontal, 4)
    }

    /// 월요일 시작 달력
    private var monCal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    /// 지금 보고 있는 기간 (이번 주 월~일 / 이번 달)
    private var periodInterval: DateInterval {
        let now = Date()
        let comp: Calendar.Component = isWeek ? .weekOfYear : .month
        return monCal.dateInterval(of: comp, for: now) ?? DateInterval(start: now, duration: 1)
    }

    private func recordsIn(_ iv: DateInterval) -> [Record] {
        store.records.filter { $0.date >= iv.start && $0.date < iv.end }
    }

    private var summaryCard: some View {
        let recs: [Record] = recordsIn(periodInterval)
        let secs: Int = recs.map(\.total).reduce(0, +)
        let kcal: Int = recs.map(\.kcal).reduce(0, +)
        let meters: Double = recs.map { Self.runDistance(of: $0) }.reduce(0, +)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                statCell("Workouts", "\(recs.count)", Fm.isKorean ? "unit.workouts".l10n : "")
                statCell("Time", Self.hmText(secs), "h")
            }
            HStack(alignment: .top, spacing: 12) {
                statCell("Calories", Self.grouped(kcal), "kcal")
                statCell("Run distance", String(format: "%.1f", meters / 1000), "km")
            }
            .padding(.top, 16)
            barChart.padding(.top, 18)
        }
        .padding(.top, 16).padding(.horizontal, 18).padding(.bottom, 14)
        .card8()
        .accessibilityIdentifier("home.summary")
    }

    private func statCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(F.num(28)).tracking(-0.56).lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(F.t(13, .medium)).foregroundStyle(C.text2).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 막대 하나: 라벨 · 그 기간 총 시간 · 가장 많이 한 모드 색
    private struct Bar: Identifiable {
        let id: Int
        let label: String
        let secs: Int
        let color: Color
    }

    private var bars: [Bar] {
        let ivs: [(String, DateInterval)] = isWeek ? weekDays : monthWeeks
        var out: [Bar] = []
        for (i, pair) in ivs.enumerated() {
            let recs: [Record] = recordsIn(pair.1)
            let secs: Int = recs.map(\.total).reduce(0, +)
            out.append(Bar(id: i, label: pair.0, secs: secs, color: Self.topModeColor(recs)))
        }
        return out
    }

    /// 월~일 7칸
    private var weekDays: [(String, DateInterval)] {
        let labels: [String] = Self.monFirstWeekdayLetters
        let start: Date = periodInterval.start
        var out: [(String, DateInterval)] = []
        for i in 0..<7 {
            guard let d = monCal.date(byAdding: .day, value: i, to: start),
                  let e = monCal.date(byAdding: .day, value: 1, to: d) else { continue }
            out.append((labels[i], DateInterval(start: d, end: e)))
        }
        return out
    }

    /// 이번 달의 주 (월요일 기준, 달 밖 날짜는 잘라냄)
    private var monthWeeks: [(String, DateInterval)] {
        let month: DateInterval = periodInterval
        var out: [(String, DateInterval)] = []
        var cursor: Date = month.start
        var n = 1
        while cursor < month.end && n <= 6 {
            guard let wk = monCal.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let s: Date = max(wk.start, month.start)
            let e: Date = min(wk.end, month.end)
            if e > s { out.append((String(localized: "W\(n)"), DateInterval(start: s, end: e))) }
            cursor = wk.end
            n += 1
        }
        return out
    }

    private var barChart: some View {
        let list: [Bar] = bars
        let mx: CGFloat = CGFloat(max(1, list.map(\.secs).max() ?? 1))
        let maxH: CGFloat = 26
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(list) { b in
                VStack(spacing: 4) {
                    barShape(b, height: b.secs > 0 ? max(6, maxH * CGFloat(b.secs) / mx) : 2)
                        .frame(height: maxH, alignment: .bottom)
                    Text(b.label).font(F.t(F.cap2, .medium)).foregroundStyle(C.text3).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barShape(_ b: Bar, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: b.secs > 0 ? 4 : 1, style: .continuous)
            .fill(b.secs > 0 ? b.color : Color.white.opacity(0.14))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    /// 그날(그 주) 가장 오래 한 모드 색
    private static func topModeColor(_ recs: [Record]) -> Color {
        var byMode: [Mode: Int] = [:]
        for x in recs { byMode[x.mode, default: 0] += x.total }
        var best: Mode = .training
        var bestT: Int = -1
        for m in Mode.allCases {
            let t: Int = byMode[m] ?? 0
            if t > bestT { bestT = t; best = m }
        }
        return Color(hex: best.calendarHex)
    }

    /// 러닝 구간 거리 합 (m)
    private static func runDistance(of x: Record) -> Double {
        x.runs.map { $0.dist ?? runMeters($0.detail) }.reduce(0, +)
    }

    /// 3:42 (시:분)
    private static func hmText(_ s: Int) -> String {
        let m: Int = max(0, s) / 60
        return "\(m / 60):" + String(format: "%02d", m % 60)
    }

    private static let groupFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()
    private static func grouped(_ v: Int) -> String {
        groupFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    // MARK: 다가오는 운동 (예약 + 등록한 대회)

    private struct UpItem: Identifiable {
        let id: String
        let date: Date
        let title: String
        let sub: String
        let color: Color
        let plan: PlannedWorkout?
    }

    private var upcomingItems: [UpItem] {
        var out: [UpItem] = []
        for p in store.upcomingPlans.prefix(3) {
            out.append(UpItem(id: p.id.uuidString, date: p.date, title: p.title, sub: planSub(p),
                              color: Color(hex: p.mode.calendarHex), plan: p))
        }
        let ev = store.settings.event
        let cal = Calendar.current
        // 대회는 바로 위 NEXT RACE 카드에 있으므로 UPCOMING에는 예약한 운동만 (중복 방지)
        if false && ev.isSet && cal.startOfDay(for: ev.date) >= cal.startOfDay(for: Date()) {
            let parts: [String] = [Fm.wdm.string(from: ev.date), dday(ev.date), "🔔 " + PlanReminder.weekBefore.short.l10n]
            out.append(UpItem(id: "race", date: Self.eventStart(ev), title: ev.name, sub: parts.joined(separator: " · "),
                              color: Color(hex: Mode.race.calendarHex), plan: nil))
        }
        return out.sorted { $0.date < $1.date }
    }

    /// 대회 날짜 + 시작 시각 (정렬용)
    private static func eventStart(_ ev: RaceEvent) -> Date {
        let p: [Int] = ev.time.split(separator: ":").compactMap { Int($0) }
        let day: Date = Calendar.current.startOfDay(for: ev.date)
        guard p.count == 2 else { return day }
        return Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 0, of: day) ?? day
    }

    private static var timeFormatter: DateFormatter { Fm.time12 }

    /// M T W T F S S (한국어: 월 화 수 목 금 토 일)
    private static var monFirstWeekdayLetters: [String] {
        var c = Calendar(identifier: .gregorian)
        c.locale = Fm.isKorean ? Locale(identifier: "ko_KR") : Locale(identifier: "en_US")
        let s: [String] = c.veryShortWeekdaySymbols      // 일요일부터
        guard s.count == 7 else { return ["M", "T", "W", "T", "F", "S", "S"] }
        return Array(s[1...]) + [s[0]]
    }

    /// Tomorrow · 7:00 AM · 🔔 Day before
    private func planSub(_ p: PlannedWorkout) -> String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(p.date) { day = "Today".l10n }
        else if cal.isDateInTomorrow(p.date) { day = "Tomorrow".l10n }
        else { day = Fm.wdm.string(from: p.date) }
        var parts: [String] = [day, Self.timeFormatter.string(from: p.date)]
        if p.reminder != PlanReminder.none { parts.append("🔔 " + p.reminder.short.l10n) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var upcoming: some View {
        let up: [UpItem] = upcomingItems
        if !up.isEmpty {
            SectionLabel(text: "UPCOMING")
            VStack(spacing: 0) {
                ForEach(Array(up.enumerated()), id: \.element.id) { i, x in
                    upcomingRow(x, last: i == up.count - 1)
                }
            }
            .card8()
        }
    }

    private func upcomingRow(_ x: UpItem, last: Bool) -> some View {
        Button {
            if let p = x.plan { r.openPlan(date: p.date, mode: p.mode, existing: p) } else { r.go(.race) }
        } label: {
            HStack(spacing: 12) {
                Circle().fill(x.color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(x.title.l10n).font(F.t(15, .semibold)).lineLimit(1)
                    Text(x.sub).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron8()
            }
            .padding(.horizontal, 18).frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("home.upcoming." + x.id)
    }

    /// 대회가 0~7일 남았으면 노란 강조 카드 (시안 v4: 그라데이션 + 노란 테두리 0.38 + 은은한 노란 그림자)
    private func isNear(_ d: Date) -> Bool {
        let cal = Calendar.current
        let n: Int = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? -1
        return n >= 0 && n <= 7
    }
    @ViewBuilder private func raceCardBg(near: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if near {
            shape
                .fill(LinearGradient(stops: [.init(color: Color.white.opacity(0.05), location: 0.3),
                                             .init(color: Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.20), location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(shape.strokeBorder(Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.38), lineWidth: 1))
                .shadow(color: Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.14), radius: 14, y: 8)
        } else {
            shape
                .fill(C.card)
                .overlay(shape.strokeBorder(C.cardBorder, lineWidth: 1))
        }
    }

    // 장소 · 13 Sep · 9:00 AM
    private func eventSub(_ ev: RaceEvent) -> String {
        [ev.loc, Fm.dm.string(from: ev.date), Self.hm12(ev.time)].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    static func hm12(_ t: String) -> String {
        let p = t.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return "" }
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1; c.hour = p[0]; c.minute = p[1]
        guard let d = Calendar.current.date(from: c) else { return "" }
        return Fm.time12.string(from: d)      // 9:00 AM (한국어: 오전 9:00)
    }
    private func dday(_ d: Date) -> String {
        let cal = Calendar.current
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
        return n == 0 ? "D-DAY" : n > 0 ? "D-\(n)" : "D+\(-n)"
    }
}
