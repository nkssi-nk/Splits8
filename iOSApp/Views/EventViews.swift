import SwiftUI

// MARK: - I4b Race event (달력·시간 카드 안에서 바로 고르기)

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
                    onRight: {
                        guard ev.isSet else { return }
                        store.settings.event = ev
                        r.evDraft = nil
                        r.go(.race)
                    })

            Button { r.go(.findEvent) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 36, height: 36).background(C.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find event").font(F.t(16, .semibold))
                        Text("다가오는 대회 목록에서 고르기").font(F.t(12)).foregroundStyle(C.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(C.chev)
                }
                .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                .card8()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ev.find")
            .padding(.top, 6)

            SectionLabel(text: "EVENT", top: 6)
            Field8(placeholder: "Event name (e.g. Incheon)", text: Binding(get: { ev.name }, set: { v in set { $0.name = v } }), size: 16)
            Field8(placeholder: "Venue / City", text: Binding(get: { ev.loc }, set: { v in set { $0.loc = v } }), size: 16)

            SectionLabel(text: "DATE & WAVE", top: 14)
            VStack(spacing: 0) {
                pickRow("Date", value: Fm.wdmy.string(from: ev.date), open: pick == "date") { toggle("date") }
                if pick == "date" { calendar.rowLine(true) }
                pickRow("Start time", value: timeLabel, open: pick == "time") { toggle("time") }
                if pick == "time" { timeGrid.rowLine(true) }
                Button { r.sub(.setDiv, from: .setEvent) } label: {
                    HStack {
                        Text("Division").font(F.t(16))
                        Spacer()
                        Text("\(store.div.name) ›").font(F.t(16)).foregroundStyle(C.text2)
                    }
                    .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .card8()
            .animation(.easeInOut(duration: 0.2), value: pick)

            Note("저장하면 Apple Watch의 Race 시작 화면에 대회명·날짜·체급이 표시됩니다.").padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .onAppear { if r.evDraft == nil { r.evDraft = store.settings.event } }
    }

    private func toggle(_ k: String) {
        pick = pick == k ? nil : k
        calMonth = nil
    }

    private func pickRow(_ t: String, value: String, open: Bool, _ a: @escaping () -> Void) -> some View {
        HStack {
            Text(t).font(F.t(16))
            Spacer()
            Button(action: a) {
                Text(value).font(F.num(16, .regular)).foregroundStyle(open ? C.accent : .white)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(open ? C.accent.opacity(0.16) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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

    private var calendar: some View {
        let today = cal.startOfDay(for: Date())
        let base = monthBase
        let first = cal.component(.weekday, from: base) - 1
        let dim = cal.range(of: .day, in: .month, for: base)?.count ?? 30
        let title: String = { let f = DateFormatter(); f.locale = Fm.gb; f.dateFormat = "MMMM yyyy"; return f.string(from: base) }()
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 0) {
            HStack {
                Text(title).font(F.t(17, .semibold))
                Spacer()
                HStack(spacing: 4) {
                    arrow("chevron.left") { calMonth = cal.date(byAdding: .month, value: -1, to: base) }
                    arrow("chevron.right") { calMonth = cal.date(byAdding: .month, value: 1, to: base) }
                }
            }
            .padding(.horizontal, 4).padding(.bottom, 10)
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, w in
                    Text(w).font(F.t(11, .semibold)).foregroundStyle(C.text3).padding(.bottom, 6)
                }
                ForEach(0..<(first + dim), id: \.self) { i in
                    if i < first {
                        Color.clear.frame(height: 40)
                    } else {
                        let d = i - first + 1
                        let dt = cal.date(byAdding: .day, value: d - 1, to: base)!
                        let on = cal.isDate(dt, inSameDayAs: ev.date)
                        let isT = cal.isDate(dt, inSameDayAs: today)
                        let past = dt < today
                        Button {
                            if !past { set { $0.date = dt }; pick = nil }
                        } label: {
                            Text("\(d)").font(F.num(17, on || isT ? .bold : .regular))
                                .foregroundStyle(on ? Color.black : past ? C.chev : isT ? C.accent : Color.white)
                                .frame(width: 36, height: 36)
                                .background(on ? C.accent : Color.clear, in: Circle())
                                .frame(maxWidth: .infinity).frame(height: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(past)
                    }
                }
            }
        }
        .padding(.top, 12).padding(.horizontal, 14).padding(.bottom, 14)
    }

    private func arrow(_ n: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: n).font(.system(size: 16, weight: .bold)).foregroundStyle(C.accent).frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    // MARK: 시간

    private var hm: (Int, Int) {
        let p = ev.time.split(separator: ":").compactMap { Int($0) }
        return (p.count > 0 ? p[0] : 9, p.count > 1 ? p[1] : 0)
    }
    private var timeLabel: String {
        let (h, m) = hm
        return "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", m)) \(h >= 12 ? "PM" : "AM")"
    }
    private func setTime(_ h: Int, _ m: Int) { set { $0.time = String(format: "%02d:%02d", h, m) } }

    private var timeGrid: some View {
        let (hh, mi) = hm
        let pm = hh >= 12, h12 = hh % 12 == 0 ? 12 : hh % 12
        return VStack(spacing: 12) {
            Seg8(items: [("AM", "AM"), ("PM", "PM")], selected: pm ? "PM" : "AM") { setTime((h12 % 12) + ($0 == "PM" ? 12 : 0), mi) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(1...12, id: \.self) { h in
                    cell("\(h)", on: h == h12) { setTime((h % 12) + (pm ? 12 : 0), mi) }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    cell(":" + String(format: "%02d", m), on: m == mi) { setTime(hh, m) }
                }
            }
            Text("티켓에 적힌 웨이브 시작 시간을 고르세요. 15분 단위.").font(F.t(12)).foregroundStyle(C.text3)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 2)
        }
        .padding(.top, 12).padding(.horizontal, 14).padding(.bottom, 14)
    }

    private func cell(_ t: String, on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(F.num(16)).foregroundStyle(on ? Color.black : Color.white)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(on ? C.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - I4e Find event

struct FindEventView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var query = ""
    @State private var region = "all"

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let list = store.events
            .filter { (region == "all" || $0.region == region) && (q.isEmpty || ($0.city + " " + $0.venue).lowercased().contains(q)) }
            .sorted { $0.start < $1.start }
        VStack(spacing: 10) {
            BackLink(label: "Race event") { r.go(.setEvent) }
            Text("Find event").font(F.t(34, .bold)).tracking(-1.02)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4).padding(.horizontal, 4).padding(.bottom, 6)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .bold)).foregroundStyle(C.text2)
                TextField("", text: $query, prompt: Text("City or venue").foregroundColor(C.text3))
                    .font(F.t(16)).autocorrectionDisabled()
                    .padding(.vertical, 11)
            }
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Flow(spacing: 6) {
                ForEach(EventItem.regions.indices, id: \.self) { i in
                    let k = EventItem.regions[i].0, l = EventItem.regions[i].1
                    Button { region = k } label: {
                        Text(l).font(F.t(13, .semibold)).foregroundStyle(region == k ? Color.black : Color.white)
                            .padding(.horizontal, 14).frame(height: 32)
                            .background(region == k ? C.accent : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SectionLabel(text: "UPCOMING", top: 8)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                    let st = Fm.ymd.date(from: e.start) ?? today, en = Fm.ymd.date(from: e.end) ?? st
                    let days = Calendar.current.dateComponents([.day], from: today, to: st).day ?? 0
                    Button { pickEvent(e) } label: {
                        HStack(spacing: 14) {
                            VStack(spacing: 0) {
                                Text(Fm.mon.string(from: st).uppercased()).font(F.t(10, .bold)).tracking(1).foregroundStyle(C.accent)
                                Text("\(Calendar.current.component(.day, from: st))").font(F.num(24))
                            }
                            .frame(width: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.city).font(F.t(16, .semibold))
                                Text(e.venue).font(F.t(12)).foregroundStyle(C.text2).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("D-\(days)").font(F.t(12, .semibold)).foregroundStyle(days <= 60 ? C.accent : C.text2)
                                Text(range(st, en)).font(F.t(11)).foregroundStyle(C.text3)
                            }
                        }
                        .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .rowLine(i < list.count - 1)
                }
                if list.isEmpty {
                    Text("검색 결과가 없어요").font(F.t(14)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 18)
                }
            }
            .card8()

            Button { r.go(.setEvent) } label: {
                (Text("목록에 없나요? ").foregroundStyle(C.text2) + Text("직접 입력").foregroundStyle(C.accent).fontWeight(.semibold))
                    .font(F.t(14)).frame(maxWidth: .infinity).padding(10).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("hyrox.com Find My Race 기준 · 2026년 9월 29일 확인").font(F.t(11)).foregroundStyle(C.chev)
        }
        .padding(.horizontal, 16)
        .task { await store.refreshEvents() }
    }

    private func range(_ a: Date, _ b: Date) -> String {
        let c = Calendar.current
        let da = c.component(.day, from: a), db = c.component(.day, from: b)
        if c.component(.month, from: a) == c.component(.month, from: b) { return "\(da)–\(db) \(Fm.mon.string(from: b))" }
        return "\(da) \(Fm.mon.string(from: a))–\(db) \(Fm.mon.string(from: b))"
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
