import SwiftUI

// MARK: - I4b Race event (자체 머리줄 Cancel · Race event · Save, 달력·시간은 카드 안에서 바로 고르기)

struct SetEventView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    @State private var pick: String? = nil          // date / time
    @State private var calMonth: Date? = nil

    private var ev: RaceEvent { r.evDraft ?? store.settings.event }
    private func set(_ f: (inout RaceEvent) -> Void) { var e = ev; f(&e); r.evDraft = e }

    var body: some View {
        VStack(spacing: 10) {
            NavBar3(left: "Cancel", title: "Race event", right: "Save",
                    rightColor: ev.isSet ? C.accent : C.g3A,
                    onLeft: { r.evDraft = nil; r.go(.race) },
                    onRight: { save() })

            findCard

            SectionLabel(text: "EVENT", top: 6)
            Field8(placeholder: "Event name (e.g. Incheon)", text: Binding(get: { ev.name }, set: { v in set { $0.name = v } }))
                .accessibilityIdentifier("ev.name")
            Field8(placeholder: "Venue / City", text: Binding(get: { ev.loc }, set: { v in set { $0.loc = v } }))
                .accessibilityIdentifier("ev.loc")

            SectionLabel(text: "DATE & WAVE", top: 14)
            dateWaveCard

            Note8(text: "Once saved, the event name, date and division appear on the Race start screen on Apple Watch.").padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .onAppear { if r.evDraft == nil { r.evDraft = store.settings.event } }
    }

    private func save() {
        guard ev.isSet else { return }
        store.settings.event = ev
        store.scheduleRaceReminders()   // 대회 일주일 전 · 전날 알림
        r.evDraft = nil
        r.go(.race)
    }

    /// Find event 카드 (노란 36 정사각 + 돋보기 18)
    private var findCard: some View {
        Button { r.go(.findEvent) } label: {
            HStack(spacing: 12) {
                Glyph("i_searchB", 18, .black)
                    .frame(width: 36, height: 36)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Find event").font(F.t(17, .semibold))
                    Text("Pick from upcoming events").font(F.t(13)).foregroundStyle(C.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
            .card8()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ev.find")
        .padding(.top, 6)
    }

    private var dateWaveCard: some View {
        VStack(spacing: 0) {
            pickRow("Date", value: Fm.wdmy.string(from: ev.date), open: pick == "date") { toggle("date") }
            if pick == "date" { calendar.rowLine(true) }
            pickRow("Start time", value: timeLabel, open: pick == "time") { toggle("time") }
            if pick == "time" { timeGrid.rowLine(true) }
            Button { r.sub(.setDiv, from: .setEvent) } label: {
                HStack(spacing: 12) {
                    Text("Division").font(F.t(17))
                    Spacer()
                    Text("\(store.div.name) ›").font(F.t(17)).foregroundStyle(C.text2).lineLimit(1)
                }
                .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ev.Division")
        }
        .card8()
        .animation(.easeInOut(duration: 0.2), value: pick)
    }

    private func toggle(_ k: String) {
        pick = pick == k ? nil : k
        calMonth = nil
    }

    /// 값 알약: 34 높이, 좌우 12, radius 8, 17pt 숫자. 열리면 노란 바탕 0.16 + 노란 글자
    private func pickRow(_ t: String, value: String, open: Bool, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(t.l10n).font(F.t(17))
            Spacer()
            Button(action: a) {
                Text(value).font(F.num(17, .regular)).foregroundStyle(open ? C.accent : Color.white).lineLimit(1)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(open ? Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.16) : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ev." + t)
        }
        .padding(.vertical, 10).padding(.horizontal, 18)
        .rowLine(true)
    }

    // MARK: 달력

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.locale = Fm.gb; c.firstWeekday = 1; return c }
    private var monthBase: Date {
        calMonth ?? cal.date(from: cal.dateComponents([.year, .month], from: ev.date)) ?? ev.date
    }
    private static var monthTitle: DateFormatter { Fm.monthYear }
    /// S M T W T F S (한국어: 일 월 화 …)
    private static var dow: [String] {
        var c = Calendar(identifier: .gregorian)
        c.locale = Fm.isKorean ? Locale(identifier: "ko_KR") : Locale(identifier: "en_US")
        let s: [String] = c.veryShortWeekdaySymbols
        return s.count == 7 ? s : ["S", "M", "T", "W", "T", "F", "S"]
    }
    private var calCols: [GridItem] { Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7) }

    private var calendar: some View {
        let base = monthBase
        let first = cal.component(.weekday, from: base) - 1
        let dim = cal.range(of: .day, in: .month, for: base)?.count ?? 30
        return VStack(spacing: 0) {
            HStack {
                Text(Self.monthTitle.string(from: base)).font(F.t(17, .semibold))
                Spacer()
                HStack(spacing: 4) {
                    arrow("i_chevL", id: "ev.calPrev") { calMonth = cal.date(byAdding: .month, value: -1, to: base) }
                    arrow("i_chevR", id: "ev.calNext") { calMonth = cal.date(byAdding: .month, value: 1, to: base) }
                }
            }
            .padding(.horizontal, 4).padding(.bottom, 10)
            LazyVGrid(columns: calCols, spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Self.dow[i]).font(F.t(11, .semibold)).foregroundStyle(C.text3)
                        .frame(maxWidth: .infinity).padding(.bottom, 6)
                }
                ForEach(0..<(first + dim), id: \.self) { i in
                    if i < first {
                        Color.clear.frame(height: 40)
                    } else {
                        dayCell(i - first + 1, base: base)
                    }
                }
            }
        }
        .padding(.top, 12).padding(.horizontal, 14).padding(.bottom, 14)
    }

    /// 40 높이 칸 · 36 원 · 17pt. 선택 = 노랑+검정 600, 오늘 = 노란 글자 600, 지난 날 = #48484C
    private func dayCell(_ d: Int, base: Date) -> some View {
        let today = cal.startOfDay(for: Date())
        let dt: Date = cal.date(byAdding: .day, value: d - 1, to: base) ?? base
        let on = cal.isDate(dt, inSameDayAs: ev.date)
        let isT = cal.isDate(dt, inSameDayAs: today)
        let past = dt < today
        let fg: Color = on ? Color.black : (past ? C.chev : (isT ? C.accent : Color.white))
        return Button {
            if !past { set { $0.date = dt }; pick = nil }
        } label: {
            Text("\(d)").font(F.num(17, on || isT ? .semibold : .regular))
                .foregroundStyle(fg)
                .frame(width: 36, height: 36)
                .background(on ? C.accent : Color.clear, in: Circle())
                .frame(maxWidth: .infinity).frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(past)
    }

    private func arrow(_ n: String, id: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Glyph(n, 18, C.accent).frame(width: 34, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: 시간

    private var hm: (Int, Int) {
        let p = ev.time.split(separator: ":").compactMap { Int($0) }
        return (p.count > 0 ? p[0] : 9, p.count > 1 ? p[1] : 0)
    }
    private var timeLabel: String {
        let (h, m) = hm
        return HomeView.hm12(String(format: "%02d:%02d", h, m))     // 9:00 AM (한국어: 오전 9:00)
    }
    private func setTime(_ h: Int, _ m: Int) { set { $0.time = String(format: "%02d:%02d", h, m) } }

    private var timeGrid: some View {
        let (hh, mi) = hm
        let pm = hh >= 12
        let h12 = hh % 12 == 0 ? 12 : hh % 12
        return VStack(spacing: 12) {
            Seg8(items: [("AM", "AM"), ("PM", "PM")], selected: pm ? "PM" : "AM") { setTime((h12 % 12) + ($0 == "PM" ? 12 : 0), mi) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 6), spacing: 6) {
                ForEach(1...12, id: \.self) { h in
                    cell("\(h)", on: h == h12) { setTime((h % 12) + (pm ? 12 : 0), mi) }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 4), spacing: 6) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    cell(":" + String(format: "%02d", m), on: m == mi) { setTime(hh, m) }
                }
            }
            Text("Pick the wave start time on your ticket. 15-minute steps.").font(F.t(13)).foregroundStyle(C.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
        .padding(.top, 12).padding(.horizontal, 14).padding(.bottom, 14)
    }

    /// 40 높이 · radius 10 · 17/600
    private func cell(_ t: String, on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(F.num(17)).foregroundStyle(on ? Color.black : Color.white)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(on ? C.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - I4e Find event (위 고정 바: 뒤로 = Race event)

struct FindEventView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var query = ""
    @State private var region = "all"

    private var list: [EventItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return store.events
            .filter { (region == "all" || $0.region == region) && (q.isEmpty || ($0.city + " " + $0.venue).lowercased().contains(q)) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(spacing: 10) {
            SearchField8(placeholder: "City or venue", text: $query)
                .accessibilityIdentifier("ev.search")
            regionChips
            SectionLabel(text: "UPCOMING", top: 8)
            listCard
            Button { r.go(.setEvent) } label: {
                (Text("Not on the list? ").foregroundColor(C.text2) + Text("Enter manually").foregroundColor(C.accent).fontWeight(.semibold))
                    .font(F.t(15)).frame(maxWidth: .infinity).padding(10).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ev.manual")
            Text("From hyrox.com Find My Race · checked 29 Sep 2026").font(F.t(F.foot)).foregroundStyle(C.chev)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .task { await store.refreshEvents() }
    }

    /// 지역 칩 (32 높이 알약, 13/600)
    private var regionChips: some View {
        Flow(spacing: 6) {
            ForEach(EventItem.regions.indices, id: \.self) { i in
                let k = EventItem.regions[i].0, l = EventItem.regions[i].1
                Button { region = k } label: {
                    Text(l.l10n).font(F.t(13, .semibold)).foregroundStyle(region == k ? Color.black : Color.white)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(region == k ? C.accent : Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ev.region." + k)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listCard: some View {
        let items = list
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                eventRow(e, last: i == items.count - 1)
            }
            if items.isEmpty {
                Text("No results").font(F.t(15)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 18)
            }
        }
        .card8()
    }

    private func eventRow(_ e: EventItem, last: Bool) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let st: Date = Fm.ymd.date(from: e.start) ?? today
        let en: Date = Fm.ymd.date(from: e.end) ?? st
        let days: Int = Calendar.current.dateComponents([.day], from: today, to: st).day ?? 0
        return Button { pickEvent(e) } label: {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(Fm.mon.string(from: st).uppercased()).font(F.t(11, .semibold)).tracking(1.1).foregroundStyle(C.accent)
                    Text("\(Calendar.current.component(.day, from: st))").font(F.num(20))
                }
                .frame(width: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.city).font(F.t(17, .semibold)).lineLimit(1)
                    Text(e.venue).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("D-\(days)").font(F.t(13, .semibold)).foregroundStyle(days <= 60 ? C.accent : C.text2)
                    Text(range(st, en)).font(F.t(F.foot)).foregroundStyle(C.text3)
                }
                .fixedSize()
            }
            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ev.item." + e.city)
        .rowLine(!last)
    }

    private func range(_ a: Date, _ b: Date) -> String {
        let c = Calendar.current
        let da = c.component(.day, from: a), db = c.component(.day, from: b)
        let ma: String = Fm.mon.string(from: a), mb: String = Fm.mon.string(from: b)
        if c.component(.month, from: a) == c.component(.month, from: b) { return String(localized: "\(da)–\(db) \(mb)") }
        return String(localized: "\(da) \(ma)–\(db) \(mb)")
    }

    private func pickEvent(_ e: EventItem) {
        var d = r.evDraft ?? store.settings.event
        d.name = e.city; d.loc = e.venue
        d.date = Fm.ymd.date(from: e.start) ?? d.date
        d.dateEnd = Fm.ymd.date(from: e.end)
        r.evDraft = d
        r.go(.setEvent)
    }
}
