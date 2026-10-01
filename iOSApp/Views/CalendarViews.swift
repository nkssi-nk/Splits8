import SwiftUI

// MARK: - HISTORY 머리줄

/// HISTORY 라벨 줄 (모드 화면 기록은 목록만. 달력은 홈 한 곳에서 모드 필터로 확인)
struct HistoryHeader: View {
    var body: some View {
        SectionLabel(text: "HISTORY", top: 20)
    }
}

// MARK: - 기록 달력 (모드별)

/// 홈 달력: 채운 점 = 기록, 빈 링 = 예약, 깃발 = 대회 날. 날짜를 누르면 아래에 그날 기록·예약.
/// 위쪽 필터(All · Training · Full Sim · Race)로 모드별로 볼 수 있음. All 이면 점 색으로 구분
struct HistoryCalendar: View {
    /// 모드 필터는 뺌 (밑의 MODES 와 헷갈려서) → 항상 전체
    private var mode: Mode? { nil }
    let store = Store.shared
    let r = Router.shared

    @State private var month: Date = HistoryCalendar.monthStart(Date())
    @State private var selected: Date = Calendar.current.startOfDay(for: Date())

    private enum DayMark { case empty, filled([Color]), ring(Color), race }

    private static var monthFmt: DateFormatter { Fm.monthYear }
    private static var timeFmt: DateFormatter { Fm.time12 }

    static func monthStart(_ d: Date) -> Date {
        let c = Calendar.current
        let comps: DateComponents = c.dateComponents([.year, .month], from: d)
        return c.date(from: comps) ?? c.startOfDay(for: d)
    }

    private var cal: Calendar { Calendar.current }
    private static let raceColor: Color = Color(hex: Mode.race.calendarHex)
    private var tint: Color { mode.map { Color(hex: $0.calendarHex) } ?? C.text2 }

    private var isPast: Bool { selected < cal.startOfDay(for: Date()) }

    /// 기록을 연 화면 (홈 달력 → 홈으로 돌아옴)
    private func backScreen(_ rec: Record) -> Scr { .home }

    private static func label(for m: Mode) -> String {
        switch m {
        case .training: return "Training"
        case .sim: return "Full Sim"
        case .race: return "Race"
        }
    }

    var body: some View {
        let recs: [Record] = store.records(on: selected, mode: mode)
        let plans: [PlannedWorkout] = plansOn(selected)
        let race: Bool = isRaceDay(selected)
        return VStack(spacing: 10) {
            calendarCard
            SectionLabel(text: Fm.wdm.string(from: selected).uppercased(), top: 10)
            if !recs.isEmpty { recordsCard(recs) }
            if !plans.isEmpty || race { plansCard(plans, race: race) }
            if recs.isEmpty && plans.isEmpty && !race && isPast {
                Text("No records on this day")
                    .font(F.t(13)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .card8()
            }
            if !isPast { planButton }
        }
    }

    // MARK: 달력 카드

    private var calendarCard: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow.padding(.bottom, 6)
            grid
            legend.padding(.top, 10)
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 10)
        .card8()
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button { shift(-1) } label: { arrow("chevron.left") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cal.prev")
            Spacer(minLength: 0)
            Text(Self.monthFmt.string(from: month)).font(F.t(17, .semibold)).lineLimit(1)
            Spacer(minLength: 0)
            Button { shift(1) } label: { arrow("chevron.right") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cal.next")
        }
        .padding(.bottom, 10)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15, weight: .semibold))
            .foregroundStyle(C.accent)
            .frame(width: 40, height: 32)
            .contentShape(Rectangle())
    }

    /// 요일 머리글 (영문 한 글자, 주 시작 요일은 기기 설정)
    private var weekdaySymbols: [String] {
        var g = Calendar(identifier: .gregorian)
        g.locale = Fm.isKorean ? Locale(identifier: "ko_KR") : Fm.gb
        let s: [String] = g.veryShortStandaloneWeekdaySymbols
        guard s.count == 7 else { return ["S", "M", "T", "W", "T", "F", "S"] }
        let k: Int = max(0, min(6, cal.firstWeekday - 1))
        return Array(s[k..<7]) + Array(s[0..<k])
    }

    private var weekdayRow: some View {
        let syms: [String] = weekdaySymbols
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(syms[i]).font(F.t(11)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 칸 목록 (0 = 빈 칸)
    private var cells: [Int] {
        let wd: Int = cal.component(.weekday, from: month)
        let lead: Int = (wd - cal.firstWeekday + 7) % 7
        let n: Int = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        var o: [Int] = Array(repeating: 0, count: lead)
        o.append(contentsOf: Array(1...max(1, n)))
        while o.count % 7 != 0 { o.append(0) }
        return o
    }

    private var grid: some View {
        let cs: [Int] = cells
        let weeks: Int = cs.count / 7
        return VStack(spacing: 6) {
            ForEach(0..<weeks, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        dayCell(cs[w * 7 + c])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        if day == 0 {
            Color.clear.frame(maxWidth: .infinity).frame(height: 41)
        } else {
            dayButton(day)
        }
    }

    private func date(of day: Int) -> Date {
        cal.date(byAdding: .day, value: day - 1, to: month) ?? month
    }

    private func dayButton(_ day: Int) -> some View {
        let d: Date = date(of: day)
        let isSel: Bool = cal.isDate(d, inSameDayAs: selected)
        let isToday: Bool = cal.isDateInToday(d)
        let m: DayMark = mark(for: d)
        let raceDay: Bool = isRaceDay(d)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selected = cal.startOfDay(for: d) }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)").font(F.t(15, isSel ? .semibold : .regular)).monospacedDigit()
                    .foregroundStyle(isSel ? Color.black : Color.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSel ? C.accent : (raceDay ? Self.raceColor.opacity(0.22) : Color.clear)))
                    .overlay {
                        if raceDay && !isSel { Circle().strokeBorder(Self.raceColor, lineWidth: 1.5) }
                        else if isToday && !isSel { Circle().strokeBorder(C.accent, lineWidth: 1) }
                    }
                markView(m)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cal.day.\(day)")
    }

    private func mark(for d: Date) -> DayMark {
        let recs: [Record] = store.records(on: d, mode: mode)
        if !recs.isEmpty {
            // 그날 한 운동 종류별 점 (최대 3개, 트레이닝 → 풀시뮬 → 레이스 순)
            let modes: [Mode] = Mode.allCases.filter { m in recs.contains { $0.mode == m } }
            return .filled(modes.map { Color(hex: $0.calendarHex) })
        }
        if isRaceDay(d) { return .race }      // 대회 날은 깃발 표시 (가장 우선)
        if let p = plansOn(d).first { return .ring(Color(hex: p.mode.calendarHex)) }
        return .empty
    }

    @ViewBuilder
    private func markView(_ m: DayMark) -> some View {
        switch m {
        case .empty:
            Color.clear.frame(width: 7, height: 7)
        case .filled(let colors):
            HStack(spacing: 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                    Circle().fill(c).frame(width: 6, height: 6)
                }
            }
            .frame(height: 7)
        case .ring(let c):
            Circle().strokeBorder(c, lineWidth: 1.5).frame(width: 7, height: 7)
        case .race:
            Glyph("i_race", 9, Self.raceColor).frame(width: 9, height: 7)
        }
    }

    private var legendModes: [Mode] { mode.map { [$0] } ?? Mode.allCases }

    /// 한 줄에 들어가면 한 줄, 안 들어가면 두 줄 (모드들 / Planned · Race day) — 영어에서 넘치지 않게
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                legendModeItems
                legendExtraItems
            }
            VStack(spacing: 6) {
                HStack(spacing: 12) { legendModeItems }
                HStack(spacing: 12) { legendExtraItems }
            }
        }
        .font(F.t(13)).foregroundStyle(C.text2)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var legendModeItems: some View {
        ForEach(legendModes) { m in
            HStack(spacing: 5) {
                Circle().fill(Color(hex: m.calendarHex)).frame(width: 7, height: 7)
                Text(Self.label(for: m).l10n).lineLimit(1).fixedSize()
            }
        }
    }

    @ViewBuilder private var legendExtraItems: some View {
        if mode != .race {
            HStack(spacing: 5) {
                Circle().strokeBorder(tint, lineWidth: 1.5).frame(width: 7, height: 7)
                Text("Planned").lineLimit(1).fixedSize()
            }
        }
        if mode == nil || mode == .race {
            HStack(spacing: 4) {
                Glyph("i_race", 10, Self.raceColor)
                Text("Race day").lineLimit(1).fixedSize()
            }
        }
    }

    // MARK: 데이터

    private func plansOn(_ d: Date) -> [PlannedWorkout] {
        store.plans(on: d).filter { mode == nil || $0.mode == mode! }
    }

    private func isRaceDay(_ d: Date) -> Bool {
        guard mode == nil || mode == .race else { return false }
        let ev: RaceEvent = store.settings.event
        guard ev.isSet else { return false }
        return cal.isDate(ev.date, inSameDayAs: d)
    }

    private func shift(_ by: Int) {
        guard let m = cal.date(byAdding: .month, value: by, to: month) else { return }
        let start: Date = Self.monthStart(m)
        withAnimation(.easeOut(duration: 0.2)) {
            month = start
            let today: Date = cal.startOfDay(for: Date())
            selected = cal.isDate(today, equalTo: start, toGranularity: .month) ? today : start
        }
    }

    // MARK: 선택한 날

    private func recordsCard(_ recs: [Record]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                recordRow(rec, last: i == recs.count - 1)
            }
        }
        .card8()
    }

    private func recordRow(_ rec: Record, last: Bool) -> some View {
        let title: String = rec.mode == .training ? (rec.kind != nil ? rec.title.l10n : "\(rec.title.l10n) × \(rec.sets)") : (rec.mode == .sim ? "Full Simulation" : rec.title.l10n)
        let sub: String = Fm.wdm.string(from: rec.date) + " · " + Self.timeFmt.string(from: rec.date)
        let from: Scr = backScreen(rec)
        return HistoryRow(title: title, sub: sub, time: Fm.t(rec.total), last: last, pb: store.isPB(rec), flag: rec.flag,
                          partner: rec.partner,
                          onDelete: { store.delete(rec) }) { r.open(rec, from: from) }
    }

    private func plansCard(_ plans: [PlannedWorkout], race: Bool) -> some View {
        VStack(spacing: 0) {
            if race { raceRow(last: plans.isEmpty) }
            ForEach(Array(plans.enumerated()), id: \.element.id) { i, p in
                planRow(p, last: i == plans.count - 1)
            }
        }
        .card8()
    }

    private func planSub(_ p: PlannedWorkout) -> String {
        var s: String = "Planned".l10n + " · " + Self.timeFmt.string(from: p.date)
        if p.reminder != PlanReminder.none { s += " · " + p.reminder.short.l10n }
        return s
    }

    private func planRow(_ p: PlannedWorkout, last: Bool) -> some View {
        Button { r.openPlan(date: p.date, mode: p.mode, existing: p) } label: {
            HStack(spacing: 12) {
                Circle().strokeBorder(Color(hex: p.mode.calendarHex), lineWidth: 1.5).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title.l10n).font(F.t(15, .semibold)).lineLimit(1)
                    Text(planSub(p)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("cal.plan")
    }

    private func raceRow(last: Bool) -> some View {
        let ev: RaceEvent = store.settings.event
        return Button { r.go(.setEvent) } label: {
            HStack(spacing: 12) {
                Glyph("i_race", 14, Self.raceColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ev.name).font(F.t(15, .semibold)).lineLimit(1)
                    Text("Race day · \(ev.time)").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }

    private var planButton: some View {
        YellowButton(height: 44, radius: 22, action: { planTap() }) {
            Text("＋ Plan a workout on this day").font(F.t(15, .semibold))
        }
        .padding(.top, 4)
        .accessibilityIdentifier("cal.planButton")
    }

    private func planTap() {
        let at: Date = cal.date(bySettingHour: 7, minute: 0, second: 0, of: selected) ?? selected
        let m: Mode = (mode == nil || mode == .race) ? .training : mode!
        r.openPlan(date: at, mode: m, existing: nil)
    }
}
