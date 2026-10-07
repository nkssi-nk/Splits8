import SwiftUI

// MARK: - I1h Home (시안 SplitsPhone.dc.html · isHomeTab / homeVals)

struct HomeView: View {
    let store = Store.shared
    let r = Router.shared
    /// 이번 주 / 이번 달 요약 선택 (week / month)
    @AppStorage("home.summaryPeriod") private var period: String = "week"
    /// 달력에 보이는 달 · 고른 날짜 (nil = 안 고름). 아래 주/월 요약도 이 값을 따라감
    @State private var calMonth: Date = HistoryCalendar.monthStart(Date())
    @State private var calSelected: Date? = nil

    var body: some View {
        VStack(spacing: 10) {
            // 대표님 요청 순서: 프로필 → 대회 일정 → 기록 달력(예약·기록 확인) → 주/월 요약 (예정된 운동 목록은 달력으로 대체)
            Group {
                profileCard
                SectionLabel(text: "NEXT RACE")
                nextRace
                SectionLabel(text: "CALENDAR")
                HistoryCalendar(month: $calMonth, selected: $calSelected)
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
        // PFT 등급 색 테두리 (골드는 홈에 들어올 때마다 빛이 한 바퀴)
        .modifier(GradeBorder(grade: store.pftGrade))
        .accessibilityIdentifier("home.profile")
    }

    /// 오른쪽 두 줄 (왼쪽 아이디 / 체급 두 줄과 줄을 맞춤):
    /// 기록이 있으면 시간 / "★ PB · Full Sim" (Race 최고면 Race), 없으면 목표 시간 / "Race goal"
    @ViewBuilder private var profileBest: some View {
        let sim: Record? = store.simBest
        let best: Record? = sim ?? store.raceBest
        VStack(alignment: .trailing, spacing: 2) {
            Text(Fm.t(best?.total ?? store.settings.goalTime)).font(F.num(22)).tracking(-0.44).lineLimit(1)
            if best != nil {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .semibold)).foregroundStyle(C.accent)
                    Text("PB").font(F.t(F.foot, .semibold)).foregroundStyle(C.accent)
                    Text("· " + (sim != nil ? "Full Sim" : "Race").l10n).font(F.t(F.foot)).foregroundStyle(C.text2)
                }
                .lineLimit(1)
            } else {
                Text("Race goal").font(F.t(F.foot)).foregroundStyle(C.text2).lineLimit(1)
            }
        }
        .fixedSize()
        .accessibilityIdentifier("home.profileBest")
    }

    // 다음 대회: 왼쪽 3줄 (이름 20/600 · 장소·날짜·시간 13 · "Division · 디비전 이름" 13), 오른쪽에는 D-day 만 (34/600 노랑, 세로 가운데)
    @ViewBuilder private var nextRace: some View {
        let ev = store.settings.event
        if ev.isSet {
            Button { r.go(.race) } label: {
                HStack(alignment: .center, spacing: 12) {
                    // 세 줄 사이 빈틈이 눈으로 같게: 큰 글자(20) 아래는 글자 자체 여백이 커서 4, 작은 글자(13) 사이는 6
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ev.name).font(F.t(20, .semibold)).tracking(-0.2).lineLimit(1)
                        Text(eventSub(ev)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).padding(.top, 4)
                        (Text("Division".l10n + " · ").foregroundColor(C.text2) + Text(store.div.name).foregroundColor(C.d1))
                            .font(F.t(13)).lineLimit(1).padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(dday(ev.date)).font(F.num(34)).tracking(-1.02).foregroundStyle(C.accent).lineLimit(1)
                        .fixedSize()
                        .accessibilityIdentifier("home.dday")
                }
                .padding(.vertical, 16).padding(.horizontal, 18)
                .background { raceCardBg(stage: raceStage(ev.date)) }
                // 대회 30일 전부터 테두리에 빛이 계속 돎. 가까울수록 밝고 빠르게, 당일은 두 줄기 (프로필 빛에 이어서 시작)
                .modifier(raceLight(raceStage(ev.date)))
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

    // 친구: 가입 전 카드 / 가입 후 순위표 (Full Sim · Race · Stations) — 빌드 19 까지는 Race 탭에 있던 것
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
            RaceLeaderboard()
        }
    }

    // MARK: 이번 주 / 이번 달 요약 (Phase 2 · m1)

    private var isWeek: Bool { period != "month" }

    /// 요약 제목: 이번 주·이번 달이면 "This Week" / "This Month", 아니면 기간("7 Sep – 13 Sep") / 달("September 2026")
    private var summaryTitle: String {
        let iv: DateInterval = periodInterval
        let now = Date()
        if iv.start <= now && now < iv.end { return isWeek ? "THIS WEEK" : "THIS MONTH" }
        if !isWeek { return Fm.monthYear.string(from: iv.start) }
        let last: Date = monCal.date(byAdding: .day, value: -1, to: iv.end) ?? iv.end
        return Fm.dm.string(from: iv.start) + " – " + Fm.dm.string(from: last)
    }

    private var summaryHeader: some View {
        HStack(spacing: 8) {
            SectionText(summaryTitle).accessibilityIdentifier("home.summary.title")
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

    /// 지금 보고 있는 기간 — 달력을 따라감.
    /// 월: 달력에 보이는 달. 주: 고른 날짜가 든 주 / 안 골랐으면 이번 달은 이번 주, 다른 달은 그 달 첫째 주 (월요일 시작)
    private var periodInterval: DateInterval {
        let now = Date()
        let fallback = DateInterval(start: now, duration: 1)
        if !isWeek { return monCal.dateInterval(of: .month, for: calMonth) ?? fallback }
        let anchor: Date
        if let s = calSelected { anchor = s }
        else if monCal.isDate(now, equalTo: calMonth, toGranularity: .month) { anchor = now }
        else { anchor = calMonth }
        return monCal.dateInterval(of: .weekOfYear, for: anchor) ?? fallback
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

    /// 대회까지 남은 날 (오늘 = 0, 지났으면 음수)
    private func daysLeft(_ d: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? -1
    }
    /// 대회 카드 단계: 0 = 31일 넘게 남음(또는 지남) · 1 = D-30~11 · 2 = D-10~8 · 3 = D-7~1 · 4 = D-DAY
    private func raceStage(_ d: Date) -> Int {
        let n: Int = daysLeft(d)
        if n < 0 || n > 30 { return 0 }
        if n == 0 { return 4 }
        if n <= 7 { return 3 }
        if n <= 10 { return 2 }
        return 1
    }
    /// 대회 카드 테두리의 도는 빛 (계속 돎). 1: 아주 옅게 12초 · 2: 중간 9초 · 3: 밝게 6초 · 4: 두 줄기 4초
    private func raceLight(_ stage: Int) -> BorderLight {
        let intensity: [Double] = [0, 0.38, 0.65, 1, 1]
        let lap: [Double] = [6, 12, 9, 6, 4]
        let i: Int = min(max(stage, 0), 4)
        return BorderLight(light: C.accent, radius: 20, mode: i == 0 ? .off : .loop,
                           delay: store.pftGrade == .gold ? 2.0 : 0.3,
                           intensity: intensity[i], lap: lap[i], double: i == 4)
    }
    /// 카드 바탕: 0 · 1 보통 / 2 노란 기운 살짝 / 3 노란 강조 (시안 v4) / 4 가장 진하게
    @ViewBuilder private func raceCardBg(stage: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let y: Color = Color(red: 1, green: 230 / 255, blue: 0)
        if stage >= 2 {
            let fill: Double = stage == 2 ? 0.07 : (stage == 3 ? 0.20 : 0.30)
            let from: Double = stage == 4 ? 0.1 : 0.3
            let line: Double = stage == 2 ? 0.20 : (stage == 3 ? 0.38 : 0.55)
            let glow: Double = stage == 2 ? 0 : (stage == 3 ? 0.14 : 0.24)
            shape
                .fill(LinearGradient(stops: [.init(color: Color.white.opacity(0.05), location: from),
                                             .init(color: y.opacity(fill), location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(shape.strokeBorder(y.opacity(line), lineWidth: 1))
                .shadow(color: y.opacity(glow), radius: stage == 4 ? 16 : 14, y: 8)
        } else {
            shape
                .fill(C.card)
                .overlay(shape.strokeBorder(C.cardBorder, lineWidth: 1))
        }
    }

    // 장소 · 13 Sep · 9:00 AM
    private func eventSub(_ ev: RaceEvent) -> String {
        // 장소 · 날짜 (출발 시간은 넣지 않음: 대회장에 가야 알 수 있고, 넣으면 작은 화면에서 줄이 잘림)
        [ev.loc, Fm.dm.string(from: ev.date)].filter { !$0.isEmpty }.joined(separator: " · ")
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
