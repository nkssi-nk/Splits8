import SwiftUI

// MARK: - I3 Full Simulation (위 고정 바가 제목을 맡음)

struct SimView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var metric = "total"
    @State private var info = false
    /// 그래프 칩: 접으면 한 줄, 겹꺾쇠를 누르면 전부
    @State private var chipsOpen = false
    fileprivate struct Metric { let key: String; let label: String; let caption: String; let st: Int? }
    private static let stationMetrics: [(String, String, String)] = [
        ("skiErg", "SKIERG", "SkiErg"), ("sledPush", "SLED PUSH", "Sled Push"), ("sledPull", "SLED PULL", "Sled Pull"),
        ("burpeeBroadJump", "BBJ", "BBJ"), ("row", "ROW", "Row"), ("farmersCarry", "FARMERS", "Farmers Carry"),
        ("sandbagLunges", "LUNGES", "Lunges"), ("wallBalls", "WALL BALLS", "Wall Balls"),
    ]
    private static let metrics: [Metric] = {
        var o: [Metric] = [
            Metric(key: "total", label: "TOTAL", caption: "Total time · latest", st: nil),
            Metric(key: "run", label: "RUN AVG", caption: "Avg 1KM run · latest", st: nil),
            Metric(key: "rox", label: "ROXZONE", caption: "Roxzone total · latest", st: nil),
        ]
        for (i, m) in stationMetrics.enumerated() {
            o.append(Metric(key: m.0, label: m.1, caption: m.2 + " · " + "latest".l10n, st: i))
        }
        return o
    }()

    private var current: Metric { Self.metrics.first { $0.key == metric } ?? Self.metrics[0] }
    private var stIndex: Int? { current.st }

    private func value(_ rec: Record, _ m: String) -> Int? {
        switch m {
        case "total": return rec.total
        case "run":
            let runs: [Int] = rec.runs.map(\.time)
            return runs.isEmpty ? nil : Int((Double(runs.reduce(0, +)) / Double(runs.count)).rounded())
        case "rox": return rec.roxTotal
        default: return rec.segs.last { $0.icon == m }?.time
        }
    }

    private func runAvg(_ a: [Int]) -> Int {
        guard a.count >= 16 else { return 0 }
        let runs: [Int] = stride(from: 0, to: 16, by: 2).map { a[$0] }
        return Int((Double(runs.reduce(0, +)) / 8).rounded())
    }

    /// 비교 기준 (Goal / Last / 친구)
    private func ref(prev: Int?) -> Int? {
        let g: [Int] = store.settings.goals
        let goalOf: Int
        switch metric {
        case "total": goalOf = g.reduce(0, +) + 8 * Defaults.roxTarget
        case "run": goalOf = runAvg(g)
        case "rox": goalOf = 8 * Defaults.roxTarget
        default:
            let k = (stIndex ?? 7) * 2 + 1
            goalOf = g.indices.contains(k) ? g[k] : 0
        }
        switch store.settings.simCmp {
        case "goal": return goalOf
        case "friend":
            guard let f = store.friend else { return prev }
            switch metric {
            case "total": return f.total
            case "run": return f.hasSplits ? runAvg(f.splits) : nil
            case "rox": return 8 * Defaults.roxTarget
            default: return f.hasSplits ? f.splits[(stIndex ?? 7) * 2 + 1] : nil
            }
        default: return prev
        }
    }

    private var cmpLabel: String {
        switch store.settings.simCmp {
        case "goal": return "VS GOAL".l10n
        case "friend": return store.friend.map { "VS " + $0.first.uppercased() } ?? "VS LAST".l10n
        default: return "VS LAST".l10n
        }
    }

    private var points: [(Date, Int)] {
        let series: [Record] = Array(store.records(.sim).filter(\.counts).prefix(6).reversed())
        var o: [(Date, Int)] = []
        for rec in series {
            if let v = value(rec, metric) { o.append((rec.date, v)) }
        }
        return o
    }

    var body: some View {
        VStack(spacing: 10) {
            TestIntro(text: "Full Simulation · the full race order, 8 runs + 8 stations, for time.", id: "sim.info") {
                info = true
            }
            graphCard
            bestCard
            settingsCard
            // "풀 시뮬 목표는 어디서 정하나요?" → 여기 Compare with 가 운동 중 구간 목표도 정함
            Note8(text: "Compare with also sets your split targets during a Full Simulation: Goal uses your Race split targets, Last uses your latest Full Sim.")
            StartOnPhoneButton(mode: .sim)          // 워치 없이 아이폰으로 기록
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let f = Fatigue.analyze(store.records(.sim).filter(\.counts)) {
                SectionLabel(text: "RUN FATIGUE", top: 20)
                RunFatigueCard(result: f, footnote: String(localized: "Average of your last \(f.count) Full Sims"))
            }
            history
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $info) {
            SimInfoSheet()
                .presentationDetents([.large])
                .presentationBackground(Color(hex: 0x1C1C1E))
                .preferredColorScheme(.dark)
        }
    }

    // MARK: 그래프 카드 (padding 18, gap 18)

    private var graphCard: some View {
        let pts = points
        return VStack(alignment: .leading, spacing: 18) {
            metricChips
            headline(pts)
            if pts.count >= 2 {
                TrendChart(values: pts.map(\.1))
                    .frame(height: 150)
                    .padding(.horizontal, 8).padding(.top, 6)
                dateAxis(pts.map(\.0))
            }
        }
        .padding(18)
        .card8()
    }

    private var metricChips: some View {
        FoldChips(spacing: 6, height: 30, radius: 8, pinned: Self.metrics.firstIndex { $0.key == metric },
                  id: "sim.chips.more", open: $chipsOpen) {
            ForEach(Self.metrics, id: \.key) { c in
                let on = metric == c.key
                Button { withAnimation(.easeOut(duration: 0.2)) { metric = c.key } } label: {
                    Text(c.label.l10n).font(F.t(11, .semibold)).tracking(0.88)
                        .foregroundStyle(on ? Color.black : C.aeb)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(on ? C.accent : C.btn1A, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sim.metric." + c.key)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headline(_ pts: [(Date, Int)]) -> some View {
        let last: Int? = pts.last?.1
        let prev: Int? = pts.count >= 2 ? pts[pts.count - 2].1 : nil
        let rf: Int? = ref(prev: prev)
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(current.caption.l10n).font(F.t(13)).foregroundStyle(C.text2)
                Text(last.map { Fm.t($0) } ?? "--:--").font(F.num(44)).tracking(-1.76).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let last, let rf {
                VStack(alignment: .trailing, spacing: 2) {
                    Text((last <= rf ? "−" : "+") + Fm.t(abs(last - rf)))
                        .font(F.num(20)).foregroundStyle(last <= rf ? C.good : C.bad).lineLimit(1)
                    Text(cmpLabel).font(F.t(11, .semibold)).tracking(0.88).foregroundStyle(C.text2).lineLimit(1)
                }
            }
        }
    }

    private func dateAxis(_ dates: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(dates.enumerated()), id: \.offset) { i, d in
                Text(Fm.axis(d)).font(F.num(11, .regular)).foregroundStyle(C.text3).lineLimit(1)
                if i < dates.count - 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, -2)
    }

    // MARK: BEST

    private var bestCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label8("BEST")
                Text(store.simBest.map { Fm.ddmy.string(from: $0.date) } ?? "None yet".l10n).font(F.t(13)).foregroundStyle(C.text3)
            }
            Spacer()
            Text(store.simBest.map { Fm.t($0.total) } ?? "--:--")
                .font(F.num(28)).tracking(-0.84).foregroundStyle(C.accent).lineLimit(1)
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .card8()
    }

    // MARK: 설정 카드 (줄 높이 52)

    private var cmpItems: [(String, String)] {
        var o: [(String, String)] = [("goal", "Goal"), ("last", "Last")]
        if let f = store.friend { o.append(("friend", f.first)) }
        return o
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Button { r.sub(.setDiv, from: .sim) } label: {
                HStack(spacing: 12) {
                    Text("Division").font(F.t(17))
                    Spacer()
                    HStack(spacing: 8) {
                        Text(store.div.name).font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
                        Chevron8()
                    }
                }
                .frame(minHeight: 52).padding(.horizontal, 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sim.division")
            .rowLine(true)
            HStack(spacing: 12) {
                Text("Compare with").font(F.t(17))
                Spacer()
                Seg8(items: cmpItems, selected: store.settings.simCmp, height: 28, radius: 9, fontSize: 13, minWidth: 56) {
                    store.settings.simCmp = $0
                }
                .fixedSize()
            }
            .frame(minHeight: 52).padding(.horizontal, 18)
            .rowLine(true)
            HStack(spacing: 12) {
                Text("Add Roxzone").font(F.t(17))
                Spacer()
                Toggle8(on: Binding(get: { store.settings.roxAuto }, set: { store.settings.roxAuto = $0 }))
            }
            .frame(minHeight: 52).padding(.horizontal, 18)
        }
        .card8()
    }

    // MARK: HISTORY

    @ViewBuilder
    private var history: some View {
        let recs: [Record] = store.records(.sim)
        HistoryHeader()
        if !recs.isEmpty {
            PagedCard(ids: recs.map(\.id)) { i, last in
                simRow(recs, i, recs[i], last: last)
            }
        } else {
            EmptyHistory()
        }
    }

    private func simRow(_ recs: [Record], _ i: Int, _ rec: Record, last: Bool) -> some View {
        let older: Record? = i + 1 < recs.count ? recs[i + 1] : nil
        let isBest: Bool = rec.id == store.simBest?.id
        let d: Int? = older.map { rec.total - $0.total }
        let sub: String
        if isBest { sub = "Personal best".l10n }
        else if let d {
            let arrow: String = d <= 0 ? "↓ " : "↑ "
            sub = arrow + Fm.t(abs(d)) + " " + "vs last".l10n
        }
        else { sub = " " }
        let color: Color = isBest ? C.accent : ((d ?? 0) <= 0 ? C.good : C.bad)
        return HistoryRow(title: Fm.wdm.string(from: rec.date), sub: sub, subColor: color,
                          time: Fm.t(rec.total), last: last, pb: store.isPB(rec), flag: rec.flag, partner: rec.partner,
                          onDelete: { store.delete(rec) }) { r.open(rec, from: .sim) }
    }
}

/// 변화 그래프 (높이 150): 격자 y 30/75/120 #1C1C1C · 노란 2pt 선 · 점 6(검정+노란 테) · 마지막 10 노랑 · 값 라벨
struct TrendChart: View {
    let values: [Int]

    var body: some View {
        GeometryReader { g in
            chart(width: g.size.width)
        }
    }

    private func xs(_ w: CGFloat) -> [CGFloat] {
        let n = values.count
        return (0..<n).map { i in w * (0.04 + CGFloat(i) * 0.92 / CGFloat(max(1, n - 1))) }
    }

    private var ys: [CGFloat] {
        let mn = values.min() ?? 0, mx = values.max() ?? 1
        let span = CGFloat(max(1, mx - mn))
        return values.map { v in 30 + CGFloat(v - mn) / span * 90 }
    }

    private func chart(width w: CGFloat) -> some View {
        let x = xs(w), y = ys
        let n = values.count
        return ZStack(alignment: .topLeading) {
            ForEach([30.0, 75.0, 120.0], id: \.self) { gy in
                Rectangle().fill(Color(hex: 0x1C1C1C)).frame(width: w, height: 1).offset(y: gy - 0.5)
            }
            Path { p in
                for i in 0..<n {
                    let pt = CGPoint(x: x[i], y: y[i])
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            .stroke(C.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ForEach(0..<n, id: \.self) { i in
                dot(i, last: i == n - 1).position(x: x[i], y: y[i])
            }
        }
        .frame(width: w, height: 150, alignment: .topLeading)
    }

    private func dot(_ i: Int, last: Bool) -> some View {
        let size: CGFloat = last ? 10 : 6
        let fs: CGFloat = last ? 13 : 10
        // 라벨 아래 끝이 점 상자 아래에서 12 위 (bottom:12px)
        let lift: CGFloat = (12 - size / 2) + fs * 0.6
        return ZStack {
            Circle().fill(last ? C.accent : Color.black)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(C.accent, lineWidth: 2).frame(width: size + 2, height: size + 2))
            Text(Fm.t(values[i])).font(F.num(fs))
                .foregroundStyle(last ? Color.white : C.text3)
                .fixedSize()
                .offset(y: -lift)
        }
    }
}

// MARK: - I4 Race (위 고정 바가 제목을 맡음)

struct RaceView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var goalSheet = false
    var body: some View {
        VStack(spacing: 10) {
            goalCard
            rowsCard
            StartOnPhoneButton(mode: .race)
                .frame(maxWidth: .infinity, alignment: .trailing)
            // 친구 순위표는 홈의 FRIENDS 로 옮김 (빌드 20)
            history
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $goalSheet) { GoalTimeSheet().presentationDetents([.height(GoalTimeSheet.height)]) }
    }

    // MARK: GOAL 카드 (padding 20/18/18, gap 18)

    private var goalCard: some View {
        let goal: Int = store.settings.goalTime
        let best: Int? = store.raceBest?.total
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label8("GOAL")
                    Text(Fm.t(goal)).font(F.num(52)).tracking(-2.34).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(best.map { Fm.d(goal - $0) } ?? "--:--")
                        .font(F.num(15)).foregroundStyle(C.accent).lineLimit(1)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.14), in: Capsule())
                    Text("vs best").font(F.t(F.foot)).foregroundStyle(C.text3)
                }
                .padding(.top, 2)
            }
            VStack(spacing: 10) {
                bar("Goal", frac: best.map { min(1, Double(goal) / Double(max(1, $0))) } ?? 1, fill: C.accent,
                    value: Fm.t(goal), valueColor: .white)
                bar("Best", frac: best == nil ? 0 : 1, fill: Color.white.opacity(0.35),
                    value: best.map { Fm.t($0) } ?? "--:--", valueColor: C.text2)
            }
            Text(goalLine(best: best, goal: goal)).font(F.t(F.sub)).foregroundStyle(C.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
        }
        .padding(.top, 20).padding(.horizontal, 18).padding(.bottom, 18)
        .card8()
    }

    private func goalLine(best: Int?, goal: Int) -> String {
        guard let b = best else { return String(localized: "Once you have a race record, we'll compare it with your best") }
        let perSplit: Int = Int((Double(b - goal) / 16).rounded())
        if b > goal { return String(localized: "Cut an average of \(perSplit) sec from each of the 16 splits") }
        if b < goal { return String(localized: "\(Fm.t(goal - b)) of room compared with your best") }
        return String(localized: "Same as your best")
    }

    /// 44 | 막대 | 64, gap 10 · 막대 4 높이 radius 2
    private func bar(_ t: String, frac: Double, fill: Color, value: String, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(t.l10n).font(F.t(13, .medium)).foregroundStyle(C.text2).frame(width: 44, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2).fill(fill)
                        .frame(width: g.size.width * CGFloat(max(0, min(1, frac))))
                }
            }
            .frame(height: 4)
            Text(value).font(F.num(15)).foregroundStyle(valueColor)
                .frame(width: 64, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // MARK: 설정 줄 카드

    private var eventValue: String {
        let e = store.settings.event
        return e.isSet ? "\(e.name) · \(Fm.wdmy.string(from: e.date)) ›" : "Not set".l10n + " ›"
    }

    private var rowsCard: some View {
        VStack(spacing: 0) {
            row("Event", value: eventValue) { r.go(.setEvent) }
            row("Division", value: "\(store.div.name) ›") { r.sub(.setDiv, from: .race) }
            row("Goal time", value: Fm.t(store.settings.goalTime) + " ›", numeric: true) { goalSheet = true }
            splitTargets
        }
        .card8()
    }

    private func row(_ t: String, value: String, numeric: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 12) {
                Text(t.l10n).font(F.t(17))
                Spacer(minLength: 8)
                Text(value).font(numeric ? F.num(17, .regular) : F.t(17)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("race." + t)
        .rowLine(true)
    }

    /// 16 막대 (40 높이, gap 3) · 러닝 #2C2C2E · 스테이션 노랑 · 높이 = 목표/335
    /// 누르면 구간별 목표 고치는 화면 (목표는 여기 한 곳에서만 — 설정의 "Split goals" 줄은 없앰)
    private var splitTargets: some View {
        Button { r.go(.setGoals) } label: { splitTargetsLabel }
            .buttonStyle(.plain)
            .accessibilityIdentifier("race.splitTargets")
    }

    private var splitTargetsLabel: some View {
        let goals: [Int] = store.settings.goals
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Split targets").font(F.t(17))
                Spacer()
                Text("Edit".l10n + " ›").font(F.t(17)).foregroundStyle(C.text2)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(goals.enumerated()), id: \.offset) { i, t in
                    Rectangle().fill(i % 2 == 0 ? C.control : C.accent)
                        .frame(height: 40 * min(1, max(0, CGFloat(t) / 335)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40, alignment: .bottom)
        }
        .padding(.top, 14).padding(.horizontal, 18).padding(.bottom, 16)
        .contentShape(Rectangle())
    }

    // MARK: HISTORY

    @ViewBuilder
    private var history: some View {
        let recs: [Record] = store.records(.race)
        HistoryHeader()
        if !recs.isEmpty {
            PagedCard(ids: recs.map(\.id)) { i, last in
                raceRow(recs, i, recs[i], last: last)
            }
        } else {
            EmptyHistory()
        }
    }

    private func raceRow(_ recs: [Record], _ i: Int, _ rec: Record, last: Bool) -> some View {
        let d: Int = rec.total - (rec.goal ?? store.settings.goalTime)
        return HistoryRow(title: rec.title, sub: Fm.wdmy.string(from: rec.date), time: Fm.t(rec.total),
                          delta: Fm.d(d) + " " + "vs goal".l10n, deltaColor: d < 0 ? C.good : C.bad,
                          last: last, pb: store.isPB(rec), flag: rec.flag, partner: rec.partner,
                          onDelete: { store.delete(rec) }) { r.open(rec, from: .race) }
    }
}

// MARK: - Home › FRIENDS 순위표 (가입 후) — 빌드 19 까지는 Race 탭에 있었음

struct RaceLeaderboard: View {
    let store = Store.shared
    let r = Router.shared
    /// 스테이션 칩: 접으면 한 줄, 겹꺾쇠를 누르면 전부
    @State private var chipsOpen = false

    private static let stations: [(String, String)] = [
        ("skiErg", "SkiErg"), ("sledPush", "Sled Push"), ("sledPull", "Sled Pull"), ("burpeeBroadJump", "BBJ"),
        ("row", "Row"), ("farmersCarry", "Farmers"), ("sandbagLunges", "Lunges"), ("wallBalls", "Wall Balls"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            Seg8(items: [("sim", "Full Sim"), ("race", "Race"), ("stations", "Stations")], selected: store.settings.lbTab) {
                store.settings.lbTab = $0
                Task { await store.refreshLeaderboard() }
            }
            if store.settings.lbTab == "stations" { stationChips }
            captionRow
            rowsCard
            Button { r.friendsFrom = .home; r.go(.friends) } label: {
                Text("+ Add friends").font(F.t(15, .semibold)).foregroundStyle(C.accent)
                    .frame(maxWidth: .infinity).padding(6).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("race.addFriends")
        }
        .task { await store.refreshLeaderboard() }
    }

    private var stationChips: some View {
        FoldChips(spacing: 6, height: 34, radius: 17, pinned: Self.stations.firstIndex { $0.0 == store.settings.lbStation },
                  id: "lb.chips.more", open: $chipsOpen) {
            ForEach(Self.stations.indices, id: \.self) { i in
                let st = Self.stations[i]
                let on = store.settings.lbStation == st.0
                Button {
                    store.settings.lbStation = st.0
                    Task { await store.refreshLeaderboard() }
                } label: {
                    HStack(spacing: 6) {
                        Icon8(st.0, 14, on ? Color.black : C.accent)
                        Text(st.1).font(F.t(13, .semibold))
                    }
                    .foregroundStyle(on ? Color.black : Color.white)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(on ? C.accent : Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lb.st." + st.0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captionRow: some View {
        HStack {
            Text(caption).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            Spacer()
            Button {
                store.settings.lbAllDivisions.toggle()
                Task { await store.refreshLeaderboard() }
            } label: {
                Text(store.settings.lbAllDivisions ? "All divisions".l10n : store.div.name)
                    .font(F.t(13, .semibold)).foregroundStyle(C.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("lb.division")
        }
        .padding(.horizontal, 4)
    }

    private var caption: String {
        switch store.settings.lbTab {
        case "sim": return String(localized: "Best Full Simulation · All time")
        case "race": return String(localized: "Best race time · All events")
        default:
            let n = Self.stations.first { $0.0 == store.settings.lbStation }?.1 ?? ""
            return String(localized: "Best \(n) split · All time")
        }
    }

    private var rowsCard: some View {
        let rows: [LBRow] = store.leaderboard
        let meT: Int? = rows.first { $0.user_id == store.myId }?.t
        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text("No records yet. Finish a Full Simulation once and it will show up here.")
                    .font(F.t(13)).foregroundStyle(C.text2).multilineTextAlignment(.center).lineSpacing(3)
                    .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 18)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                lbRow(i, row, meT: meT, last: i == rows.count - 1)
            }
        }
        .card8()
    }

    private func lbRow(_ i: Int, _ row: LBRow, meT: Int?, last: Bool) -> some View {
        let me: Bool = row.user_id == store.myId
        return Button { open(row) } label: {
            HStack(spacing: 12) {
                Text("\(i + 1)").font(F.num(17)).foregroundStyle(i == 0 ? C.accent : Color.white)
                    .frame(width: 22, alignment: .leading)
                RaceLbAvatar(me: me, photo: me ? store.photo : nil, url: me ? nil : row.avatar_url,
                             initial: String(row.nickname.prefix(1)).uppercased())
                VStack(alignment: .leading, spacing: 1) {
                    Text(me ? "@\(row.nickname) (you)" : "@\(row.nickname)")
                        .font(F.t(15, me ? .semibold : .medium)).foregroundStyle(me ? C.accent : Color.white).lineLimit(1)
                    Text(row.division).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Fm.t(row.t)).font(F.num(17)).tracking(-0.34).lineLimit(1)
                    if !me, let meT {
                        Text(Fm.d(row.t - meT)).font(F.num(13)).foregroundStyle(row.t < meT ? C.bad : C.good).lineLimit(1)
                    }
                }
                .fixedSize()
            }
            .padding(.vertical, 12).padding(.horizontal, 18)
            .background(me ? Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }

    /// 친구를 누르면 Full Simulation 에서 그 친구와 비교
    private func open(_ row: LBRow) {
        guard row.user_id != store.myId else { return }
        guard let f = store.friends.first(where: { $0.id == row.user_id }) else { return }
        var s = store.settings
        s.friendId = f.id
        s.simCmp = "friend"
        store.settings = s
        r.goTest("sim")
    }
}

/// 순위표 동그라미 (34): 나 = 사진 또는 노랑+검정 글자, 친구 = 사진 URL 또는 #2C2C2E
private struct RaceLbAvatar: View {
    let me: Bool
    let photo: UIImage?
    let url: String?
    let initial: String

    var body: some View {
        if let s = url, let u = URL(string: s) {
            AsyncImage(url: u) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                fallback
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Avatar8(size: 34, photo: photo, initial: initial,
                bg: me ? C.accent : C.control, fg: me ? Color.black : Color.white, fontSize: 15)
    }
}

// MARK: - Goal time 고르기 → 구간 목표를 같은 비율로 나눔

struct GoalTimeSheet: View {
    static let height: CGFloat = 470
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var h = 1
    @State private var m = 12
    @State private var s = 0
    /// 구간으로 나누는 방식 (GoalSplit.styles)
    @State private var style = "keep"

    private var total: Int { h * 3600 + m * 60 + s }
    private var bestSplits: [Int]? { store.simBest?.splits16 }
    /// 내 최고 풀 시뮬레이션이 있을 때만 "My best" 를 보여 줌
    private var styles: [String] { GoalSplit.styles.filter { $0 != "best" || bestSplits != nil } }
    private var preview: [Int] {
        GoalSplit.split(total: max(600, total), style: style, current: store.settings.goals, best: bestSplits)
    }

    var body: some View {
        VStack(spacing: 14) {
            NavBar3(left: "Cancel", title: "Goal time", right: "Save", onLeft: { dismiss() }, onRight: save, edgeBack: false)
            HStack(spacing: 0) {
                picker($h, 0..<3, String(localized: "unit.h", defaultValue: "h")); picker($m, 0..<60, String(localized: "unit.m", defaultValue: "m")); picker($s, 0..<60, String(localized: "unit.s", defaultValue: "s"))
            }
            .frame(height: 150)
            // 구간으로 나누는 방식: 지금 비율 · 균형형 · 러너형 · 근력형 · 내 최고 기록 비율
            Seg8(items: styles.map { ($0, GoalSplit.name($0)) }, selected: style, height: 34, radius: 11, fontSize: 13) { k in
                withAnimation(.easeOut(duration: 0.2)) { style = k }
            }
            .accessibilityIdentifier("goal.style")
            bars
            Text(GoalSplit.note(style).l10n).font(F.t(13)).foregroundStyle(C.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .background(Color(hex: 0x141414).ignoresSafeArea())
        .onAppear {
            let t = store.settings.goalTime
            h = t / 3600; m = (t % 3600) / 60; s = t % 60
        }
    }

    /// 나눈 결과 미리 보기: 16 막대 (러닝 회색 · 종목 노랑), 가장 긴 칸 기준 높이
    private var bars: some View {
        let g: [Int] = preview
        let mx: CGFloat = CGFloat(max(1, g.max() ?? 1))
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(g.enumerated()), id: \.offset) { i, t in
                Rectangle().fill(i % 2 == 0 ? C.control : C.accent)
                    .frame(height: 44 * max(0.08, CGFloat(t) / mx))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 44, alignment: .bottom)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .card8(14)
        .accessibilityIdentifier("goal.preview")
    }

    private func picker(_ b: Binding<Int>, _ r: Range<Int>, _ u: String) -> some View {
        Picker(u, selection: b) { ForEach(r, id: \.self) { Text("\($0) \(u)").tag($0) } }
            .pickerStyle(.wheel)
    }

    private func save() {
        guard total > 600 else { dismiss(); return }
        var st = store.settings
        st.goals = GoalSplit.split(total: total, style: style, current: st.goals, best: bestSplits)
        st.goalTime = total
        store.settings = st
        dismiss()
    }
}

// MARK: - RUN FATIGUE 카드 (Full Sim 탭 · 기록 상세)

/// 스테이션 다음 1KM 가 내 평균 러닝보다 얼마나 느려지는지. 가장 큰 것 노랑.
struct RunFatigueCard: View {
    let result: FatigueResult
    let footnote: String

    var body: some View {
        let worst: Int? = result.worst
        return VStack(alignment: .leading, spacing: 0) {
            Text("How much slower the 1 km after each station is, against your average run of \(Fm.t(result.avgRun)) /km")
                .font(F.t(F.sub)).foregroundStyle(C.text2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 9) {
                ForEach(0..<result.names.count, id: \.self) { i in
                    barRow(i, top: worst == i)
                }
            }
            .padding(.top, 14)
            tip(worst)
                .padding(.top, 14)
            Text(footnote.l10n).font(F.t(F.foot)).foregroundStyle(C.text2)
                .padding(.top, 10)
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
    }

    private func valueText(_ d: Int?) -> String {
        guard let d else { return "—" }
        return Fm.d(d)
    }

    private func frac(_ d: Int?) -> CGFloat {
        guard let d, d > 0 else { return 0.03 }
        return max(0.03, min(1, CGFloat(d) / CGFloat(result.maxDelta)))
    }

    private func barRow(_ i: Int, top: Bool) -> some View {
        let d: Int? = result.deltas[i]
        let f: CGFloat = frac(d)
        return HStack(spacing: 10) {
            Text(result.names[i]).font(F.t(F.sub)).lineLimit(1).minimumScaleFactor(0.85)
                .frame(width: 104, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(top ? C.accent : C.text2)
                        .frame(width: g.size.width * f)
                }
            }
            .frame(height: 10)
            Text(valueText(d)).font(F.num(F.sub)).foregroundStyle(top ? C.accent : Color.white)
                .lineLimit(1)
                .frame(width: 56, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func tip(_ worst: Int?) -> some View {
        if let w = worst, let d = result.deltas[w] {
            let name: String = result.names[w]
            let delta: String = Fm.d(d)
            let head: Text = Text("The run after \(name)").foregroundColor(C.accent).fontWeight(.semibold)
            let rest: Text = Text(" is your slowest (\(delta)). Practice compromised running straight off \(name).")
            (head + rest)
                .font(F.t(F.sub)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.10),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text("You're holding your average pace on the runs after stations too.")
                .font(F.t(F.sub))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
