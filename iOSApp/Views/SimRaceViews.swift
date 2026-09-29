import SwiftUI

// MARK: - I3 Full Simulation

struct SimView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var metric = "total"

    private struct Metric { let key: String; let label: String; let caption: String; let st: Int? }
    private let metrics: [Metric] = [
        Metric(key: "total", label: "TOTAL", caption: "Total time · latest", st: nil),
        Metric(key: "run", label: "RUN AVG", caption: "Avg 1KM run · latest", st: nil),
        Metric(key: "rox", label: "ROXZONE", caption: "Roxzone total · latest", st: nil),
    ] + [("skiErg", "SKIERG", "SkiErg"), ("sledPush", "SLED PUSH", "Sled Push"), ("sledPull", "SLED PULL", "Sled Pull"),
         ("burpeeBroadJump", "BBJ", "BBJ"), ("row", "ROW", "Row"), ("farmersCarry", "FARMERS", "Farmers Carry"),
         ("sandbagLunges", "LUNGES", "Lunges"), ("wallBalls", "WALL BALLS", "Wall Balls")].enumerated().map { i, m in
        Metric(key: m.0, label: m.1, caption: m.2 + " · latest", st: i)
    }

    private func value(_ rec: Record, _ m: String) -> Int? {
        switch m {
        case "total": return rec.total
        case "run":
            let runs = rec.runs.map(\.time)
            return runs.isEmpty ? nil : Int((Double(runs.reduce(0, +)) / Double(runs.count)).rounded())
        case "rox": return rec.roxTotal
        default: return rec.segs.last { $0.icon == m }?.time
        }
    }

    /// 비교 기준 (Goal / Last / 친구)
    private func ref(prev: Int?) -> Int? {
        let g = store.settings.goals
        let gsum = g.reduce(0, +)
        let goalOf: Int
        switch metric {
        case "total": goalOf = gsum + 8 * Defaults.roxTarget
        case "run": goalOf = Int((Double(stride(from: 0, to: 16, by: 2).map { g[$0] }.reduce(0, +)) / 8).rounded())
        case "rox": goalOf = 8 * Defaults.roxTarget
        default: goalOf = g[(stIndex ?? 7) * 2 + 1]
        }
        switch store.settings.simCmp {
        case "goal": return goalOf
        case "friend":
            if let f = store.friend {
                switch metric {
                case "total": return f.total
                case "run": return Int((Double(stride(from: 0, to: 16, by: 2).map { f.splits[$0] }.reduce(0, +)) / 8).rounded())
                case "rox": return 8 * Defaults.roxTarget
                default: return f.hasSplits ? f.splits[(stIndex ?? 7) * 2 + 1] : nil
                }
            }
            return prev
        default: return prev
        }
    }

    private var stIndex: Int? { metrics.first { $0.key == metric }?.st }

    private var cmpLabel: String {
        switch store.settings.simCmp {
        case "goal": return "VS GOAL"
        case "friend": return store.friend.map { "VS " + $0.first.uppercased() } ?? "VS LAST"
        default: return "VS LAST"
        }
    }

    var body: some View {
        let recs = store.records(.sim)
        let series = Array(recs.prefix(6).reversed())
        let pts = series.compactMap { rec in value(rec, metric).map { (rec.date, $0) } }
        let m = metrics.first { $0.key == metric } ?? metrics[0]
        let last = pts.last?.1
        let prev = pts.count >= 2 ? pts[pts.count - 2].1 : nil
        let rf = ref(prev: prev)

        VStack(spacing: 10) {
            LargeTitle(text: "Full Simulation")

            VStack(alignment: .leading, spacing: 18) {
                Flow(spacing: 6) {
                    ForEach(metrics, id: \.key) { c in
                        Button { withAnimation(.easeOut(duration: 0.2)) { metric = c.key } } label: {
                            Text(c.label).font(F.t(11, .semibold)).tracking(0.88)
                                .foregroundStyle(metric == c.key ? Color.black : C.aeb)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(metric == c.key ? C.accent : C.btn1A, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.caption).font(F.t(13)).foregroundStyle(C.text2)
                        Text(last.map { Fm.t($0) } ?? "--:--").font(F.num(44)).tracking(-1.76)
                    }
                    Spacer()
                    if let last, let rf {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text((last <= rf ? "−" : "+") + Fm.t(abs(last - rf)))
                                .font(F.num(20)).foregroundStyle(last <= rf ? C.good : C.bad)
                            Text(cmpLabel).font(F.t(11, .semibold)).tracking(0.88).foregroundStyle(C.text2)
                        }
                    }
                }

                if pts.count >= 2 {
                    TrendChart(values: pts.map(\.1))
                        .frame(height: 150)
                        .padding(.horizontal, 8).padding(.top, 6)
                    HStack {
                        ForEach(Array(pts.enumerated()), id: \.offset) { i, p in
                            Text(Fm.axis(p.0)).font(F.num(11, .regular)).foregroundStyle(C.text3)
                            if i < pts.count - 1 { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.horizontal, -2)
                }
            }
            .padding(18)
            .card8()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label8("BEST")
                    Text(store.simBest.map { Fm.ddmy.string(from: $0.date) } ?? "아직 없어요").font(F.t(13)).foregroundStyle(C.text3)
                }
                Spacer()
                Text(store.simBest.map { Fm.t($0.total) } ?? "--:--")
                    .font(F.num(28)).tracking(-0.84).foregroundStyle(C.accent).lineLimit(1)
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .card8()

            VStack(spacing: 0) {
                Button { r.sub(.setDiv, from: .sim) } label: {
                    HStack(spacing: 12) {
                        Text("Division").font(F.t(16))
                        Spacer()
                        HStack(spacing: 8) {
                            Text(store.div.name).font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(C.chev)
                        }
                    }
                    .frame(minHeight: 52).padding(.horizontal, 18).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowLine(true)
                HStack(spacing: 12) {
                    Text("Compare with").font(F.t(16))
                    Spacer()
                    Seg8(items: [("goal", "Goal"), ("last", "Last")] + (store.friend.map { [("friend", $0.first)] } ?? []),
                         selected: store.settings.simCmp, height: 28, radius: 9, fontSize: 13, minWidth: 56) { store.settings.simCmp = $0 }
                }
                .frame(minHeight: 52).padding(.horizontal, 18)
                .rowLine(true)
                HStack(spacing: 12) {
                    Text("Auto Roxzone").font(F.t(16))
                    Spacer()
                    Toggle8(on: Binding(get: { store.settings.roxAuto }, set: { store.settings.roxAuto = $0 }), w: 51, h: 31)
                }
                .frame(minHeight: 52).padding(.horizontal, 18)
            }
            .card8()

            if !recs.isEmpty {
                SectionLabel(text: "HISTORY")
                VStack(spacing: 0) {
                    ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                        let older = i + 1 < recs.count ? recs[i + 1] : nil
                        let isBest = rec.id == store.simBest?.id
                        let d = older.map { rec.total - $0.total }
                        HistoryRow(title: Fm.wdm.string(from: rec.date),
                                   sub: isBest ? "Personal best" : d.map { ($0 <= 0 ? "↓ " : "↑ ") + Fm.t(abs($0)) + " vs last" } ?? " ",
                                   subColor: isBest ? C.accent : (d ?? 0) <= 0 ? C.good : C.bad,
                                   time: Fm.t(rec.total), last: i == recs.count - 1) { r.open(rec, from: .sim) }
                    }
                }
                .card8()
            }
        }
        .padding(.horizontal, 16)
    }
}

/// 변화 그래프: 노란 선 + 점 + 값
struct TrendChart: View {
    let values: [Int]
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let mn = values.min() ?? 0, mx = values.max() ?? 1
            let n = values.count
            let xs = (0..<n).map { w * (0.04 + CGFloat($0) * 0.92 / CGFloat(max(1, n - 1))) }
            let ys = values.map { v -> CGFloat in 30 + CGFloat(v - mn) / CGFloat(max(1, mx - mn)) * 90 }
            ZStack(alignment: .topLeading) {
                ForEach([30.0, 75.0, 120.0], id: \.self) { y in
                    Rectangle().fill(Color(hex: 0x1C1C1C)).frame(width: w, height: 1).offset(y: y)
                }
                Path { p in
                    for i in 0..<n { i == 0 ? p.move(to: CGPoint(x: xs[i], y: ys[i])) : p.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                }
                .stroke(C.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(0..<n, id: \.self) { i in
                    let lastDot = i == n - 1
                    let dotSize: CGFloat = lastDot ? 10 : 6
                    let labelGap: CGFloat = lastDot ? 7 : 6
                    ZStack {
                        Circle().fill(lastDot ? C.accent : Color.black)
                            .overlay(Circle().stroke(C.accent, lineWidth: 2))
                            .frame(width: dotSize, height: dotSize)
                        Text(Fm.t(values[i])).font(F.num(lastDot ? 13 : 10))
                            .foregroundStyle(lastDot ? Color.white : C.text3)
                            .fixedSize()
                            .offset(y: -(dotSize / 2 + 12 + labelGap))
                    }
                    .position(x: xs[i], y: ys[i])
                }
            }
        }
    }
}

// MARK: - I4 Race

struct RaceView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var goalSheet = false

    var body: some View {
        let s = store.settings
        let best = store.raceBest?.total
        let recs = store.records(.race)

        VStack(spacing: 10) {
            LargeTitle(text: "Race")

            // 목표 카드 (유리)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label8("GOAL")
                        Text(Fm.t(s.goalTime)).font(F.num(52)).tracking(-2.34).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(best.map { Fm.d(s.goalTime - $0) } ?? "--:--")
                            .font(F.num(14)).foregroundStyle(C.accent)
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(C.accent.opacity(0.14), in: Capsule())
                        Text("vs best").font(F.t(11)).foregroundStyle(C.text3)
                    }
                    .padding(.top, 2)
                }
                VStack(spacing: 10) {
                    bar("Goal", frac: best.map { min(1, Double(s.goalTime) / Double($0)) } ?? 1, fill: C.accent,
                        value: Fm.t(s.goalTime), valueColor: .white)
                    bar("Best", frac: best.map { min(1, Double($0) / Double(max($0, s.goalTime))) } ?? 0, fill: Color.white.opacity(0.35),
                        value: best.map { Fm.t($0) } ?? "--:--", valueColor: C.text2)
                }
                Text(goalLine(best: best, goal: s.goalTime)).font(F.t(12)).foregroundStyle(C.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
            }
            .padding(.top, 20).padding(.horizontal, 18).padding(.bottom, 18)
            .card8()

            VStack(spacing: 0) {
                row("Event", value: s.event.isSet ? "\(s.event.name) · \(Fm.wdmy.string(from: s.event.date)) ›" : "Not set ›") { r.go(.setEvent) }
                row("Division", value: "\(store.div.name) ›") { r.sub(.setDiv, from: .race) }
                row("Goal time", value: Fm.t(s.goalTime) + " ›", numeric: true) { goalSheet = true }
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Split targets").font(F.t(16))
                        Spacer()
                        Text(s.tgtSrc == "friend" ? (store.friend?.first ?? "Auto") : "Auto")
                            .font(F.t(12, .semibold)).foregroundStyle(C.accent)
                    }
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(s.goals.enumerated()), id: \.offset) { i, t in
                            Rectangle().fill(i % 2 == 0 ? C.control : C.accent)
                                .frame(height: 40 * min(1, CGFloat(t) / 335))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 40, alignment: .bottom)
                }
                .padding(.top, 14).padding(.horizontal, 18).padding(.bottom, 16)
            }
            .card8()

            SectionLabel(text: "FRIENDS")
            if store.signedIn { Leaderboard() } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: -8) {
                        ForEach(Array([("J", C.accent), ("M", C.good), ("T", Color(hex: 0x0A84FF))].enumerated()), id: \.offset) { _, g in
                            Text(g.0).font(F.t(13, .bold)).foregroundStyle(.black)
                                .frame(width: 34, height: 34).background(g.1, in: Circle())
                                .overlay(Circle().stroke(Color(hex: 0x0A0A0A), lineWidth: 2))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("친구와 순위를 비교해 보세요").font(F.t(17, .semibold))
                        Text("닉네임으로 친구를 추가하면 Full Sim·대회·스테이션별 순위를 볼 수 있어요.")
                            .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(5)
                    }
                    Button { r.toAuth(from: .race) } label: {
                        Text("Sign up · 30초").font(F.t(15, .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .yellowFill(14)
                    }
                    .buttonStyle(Press())
                }
                .padding(.vertical, 20).padding(.horizontal, 18)
                .card8()
            }

            if !recs.isEmpty {
                SectionLabel(text: "HISTORY")
                VStack(spacing: 0) {
                    ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                        let d = rec.total - (rec.goal ?? s.goalTime)
                        HistoryRow(title: rec.title, sub: Fm.wdmy.string(from: rec.date), time: Fm.t(rec.total),
                                   delta: Fm.d(d) + " vs goal", deltaColor: d < 0 ? C.good : C.bad,
                                   last: i == recs.count - 1) { r.open(rec, from: .race) }
                    }
                }
                .card8()
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $goalSheet) { GoalTimeSheet().presentationDetents([.height(340)]) }
    }

    private func goalLine(best: Int?, goal: Int) -> String {
        guard let b = best else { return "대회 기록이 생기면 최고 기록과 비교해 드려요" }
        if b > goal { return "16개 구간에서 평균 \(Int((Double(b - goal) / 16).rounded()))초씩 줄이면 됩니다" }
        if b < goal { return "최고 기록보다 \(Fm.t(goal - b)) 여유가 있어요" }
        return "최고 기록과 같은 목표예요"
    }

    private func bar(_ t: String, frac: Double, fill: Color, value: String, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(t).font(F.t(12, .medium)).foregroundStyle(C.text2).frame(width: 44, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(fill).frame(width: g.size.width * CGFloat(max(0, min(1, frac))))
                }
            }
            .frame(height: 4)
            Text(value).font(F.num(14)).foregroundStyle(valueColor).frame(width: 64, alignment: .trailing).lineLimit(1)
        }
    }

    private func row(_ t: String, value: String, numeric: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack {
                Text(t).font(F.t(16))
                Spacer()
                Text(value).font(numeric ? F.num(16, .regular) : F.t(16)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("race." + t)
        .rowLine(true)
    }
}

/// Goal time 고르기 → 구간 목표를 같은 비율로 나눔
struct GoalTimeSheet: View {
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var h = 1
    @State private var m = 12
    @State private var s = 0

    var body: some View {
        VStack(spacing: 16) {
            NavBar3(left: "Cancel", title: "Goal time", right: "Save", onLeft: { dismiss() }, onRight: save)
            HStack(spacing: 0) {
                picker($h, 0..<3, "h"); picker($m, 0..<60, "m"); picker($s, 0..<60, "s")
            }
            .frame(height: 180)
            Text("구간 목표가 이 시간에 맞게 같은 비율로 나뉩니다.").font(F.t(12)).foregroundStyle(C.text3)
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .background(Color(hex: 0x141414).ignoresSafeArea())
        .onAppear {
            let t = store.settings.goalTime
            h = t / 3600; m = (t % 3600) / 60; s = t % 60
        }
    }

    private func picker(_ b: Binding<Int>, _ r: Range<Int>, _ u: String) -> some View {
        Picker(u, selection: b) { ForEach(r, id: \.self) { Text("\($0) \(u)").tag($0) } }
            .pickerStyle(.wheel)
    }

    private func save() {
        let total = h * 3600 + m * 60 + s
        guard total > 600 else { dismiss(); return }
        var st = store.settings
        let cur = st.goals.reduce(0, +)
        let target = max(16 * 30, total - 8 * Defaults.roxTarget)
        if cur > 0 {
            let f = Double(target) / Double(cur)
            st.goals = st.goals.map { max(30, Int((Double($0) * f / 5).rounded()) * 5) }
        }
        st.goalTime = total
        store.settings = st
        dismiss()
    }
}

