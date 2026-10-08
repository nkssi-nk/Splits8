import SwiftUI
import Observation

@main
struct Splits8WatchApp: App {
    init() {
        if WatchDemo.enabled { WatchDemo.apply(); return }
        WatchStore.shared.activate()
        WorkoutEngine.shared.settings = WatchStore.shared.settings
        WorkoutEngine.shared.requestAuthorization()
    }
    var body: some Scene {
        WindowGroup { WRoot() }
    }
}

enum WScreen { case home, programs, quick, confirm }

/// 워치 화면 이동 상태
@Observable
final class WNav {
    static let shared = WNav()
    var screen: WScreen = .home
    var mode: Mode = .race
    var program: Program?
    var quick: [ProgItem] = []
}

struct WRoot: View {
    let nav = WNav.shared
    let engine = WorkoutEngine.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if engine.active && engine.finished {
                WSummary()
            } else if engine.active {
                WWorkoutPager()
            } else if let n = engine.countdown {
                WCountdown(n: n)
            } else {
                switch nav.screen {
                case .home: WHome()
                case .programs: WPrograms()
                case .quick: WQuick()
                case .confirm: WConfirm()
                }
            }
        }
    }
}

// MARK: - 시작 전 3 · 2 · 1

/// Start 를 누르면 3 · 2 · 1 을 센 뒤 시간이 시작됨. 화면을 누르면 취소
struct WCountdown: View {
    let n: Int
    let engine = WorkoutEngine.shared

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.30, 1.0, 0.6, 0.5, 0.5))
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(verbatim: "\(n)")
                    .font(F.num(96, .bold)).foregroundStyle(C.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.25), value: n)
                    .accessibilityIdentifier("w.count")
                Spacer(minLength: 0)
                Text("Tap to cancel").font(F.t(13)).foregroundStyle(C.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { engine.cancelCountdown() }
        .ignoresSafeArea()
    }
}

// MARK: - 공통 부품

/// 워치 카드 (#151515, 1px #222)
struct WCardBG: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(C.wCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(C.wBorder, lineWidth: 1))
    }
}
extension View {
    func wCard(_ r: CGFloat = 14) -> some View { modifier(WCardBG(radius: r)) }
}

/// ‹ 제목  (padding 은 부르는 쪽에서)
struct WBackHeader<Trailing: View>: View {
    let title: String
    let back: () -> Void
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 4) {
            Button(action: back) {
                Icon8("i_chevLw", 13, C.accent)
                    .frame(width: 13, height: 13)
                    .contentShape(Rectangle().inset(by: -8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("w.back")
            Text(title.l10n)
                .font(F.t(16, .semibold))
                .lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            trailing
        }
    }
}
extension WBackHeader where Trailing == EmptyView {
    init(title: String, back: @escaping () -> Void) {
        self.title = title; self.back = back; self.trailing = EmptyView()
    }
}

/// 모드 아이콘: Training = modeTraining PNG 22, PFT = modePFT 22, Full Sim = i_sim 20, Race = i_race 20 (노랑)
struct WModeIcon: View {
    let mode: Mode
    var color: Color = C.accent
    var body: some View {
        switch mode {
        case .training: Icon8("modeTraining", 22, color)
        case .pft: Icon8("modePFT", 22, color)
        case .sim: Icon8("i_sim", 20, color)
        case .race: Icon8("i_race", 20, color)
        }
    }
}

/// 칩이 줄바꿈되는 배치 (가로 스크롤 없음)
struct WFlow: Layout {
    var spacing: CGFloat = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW: CGFloat = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW {
                y += rowH + spacing; x = 0; rowH = 0
            }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: proposal.width ?? width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - W1 Home

/// 시계는 시스템 시계 하나만: 워드마크를 내비게이션 막대 왼쪽에 두면 시스템 시계가 같은 줄 오른쪽에 나옴
struct WHome: View {
    let store = WatchStore.shared
    let nav = WNav.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Mode.allCases) { m in
                        Button { open(m) } label: { card(m) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("w.mode." + m.rawValue)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Wordmark(size: 12)
                }
            }
            .containerBackground(for: .navigation) {
                ZStack {
                    Color.black
                    AmbientLayer(a: Ambient.y(0.22, 0.9, 0.4, 0.5, -0.06))
                }
            }
        }
    }

    @ViewBuilder
    private func action(_ m: Mode) -> some View {
        if m == .training {
            ZStack {
                Circle().fill(Color(hex: 0x262626))
                Icon8("i_chevRw", 10, C.accent)
            }
            .frame(width: 22, height: 22)
            .fixedSize()
        } else {
            ZStack {
                Circle().fill(C.accent)
                Icon8("i_play", 9, .black)
            }
            .frame(width: 22, height: 22)
            .fixedSize()
        }
    }

    private func card(_ m: Mode) -> some View {
        // 설명 줄 없음: 아이콘 · 이름 · 버튼만 (카드 4개가 한 화면에 들어오게)
        // 버튼(22)은 크기 고정 — 이름이 길면 글자만 조금 줄어듦
        HStack(spacing: 10) {
            WModeIcon(mode: m)
                .frame(width: 22, height: 22)
            Text(m.name.l10n).font(F.t(15, .semibold)).tracking(-0.24)
                .lineLimit(1).allowsTightening(true).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            action(m)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wCard(18)
    }

    private func open(_ m: Mode) {
        nav.mode = m
        nav.program = nil
        nav.screen = m == .training ? .programs : .confirm
    }
}

// MARK: - W2a Training list

struct WPrograms: View {
    let store = WatchStore.shared
    let nav = WNav.shared

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.16, 0.7, 0.45, 1.0, 0))
            VStack(spacing: 0) {
                WBackHeader(title: "Training", back: { nav.screen = .home })
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 6) {
                        quickCard
                        ForEach(store.programs) { p in
                            Button { nav.program = p; nav.screen = .confirm } label: { programCard(p) }
                                .buttonStyle(.plain)
                        }
                        Text("Edit names on iPhone")
                            .font(F.t(12)).foregroundStyle(C.text3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18).padding(.bottom, 12)
        }
        .ignoresSafeArea()
    }

    private var quickCard: some View {
        Button { nav.quick = []; nav.screen = .quick } label: {
            HStack {
                Text("Quick training").font(F.t(15, .semibold))
                Spacer(minLength: 0)
                Icon8("i_plus", 14, .black)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("w.quick")
    }

    private func programCard(_ p: Program) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.name.l10n).font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.85)
            Text(p.watchMeta).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .wCard(14)
    }
}

// MARK: - W2q Quick training

struct WQuick: View {
    let store = WatchStore.shared
    let nav = WNav.shared
    private let maxSegs = 16   // 트레이닝 세트 최대 16구간 (오너 지정, 디자인의 8 대신)
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.16, 0.7, 0.45, 0, 0))
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 6) {
                        runGrid
                        stationGrid
                        sequence
                    }
                    .padding(.horizontal, 16)
                }
                if !nav.quick.isEmpty { startButton }
            }
            .padding(.top, 18).padding(.bottom, 10)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        WBackHeader(title: "Quick training", back: { nav.screen = .programs }) {
            if !nav.quick.isEmpty {
                Button("Clear") { nav.quick = [] }
                    .buttonStyle(.plain)
                    .font(F.t(13, .semibold)).foregroundStyle(C.bad)
            }
        }
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 6)
    }

    private func add(_ q: ProgItem) {
        guard nav.quick.count < maxSegs else { return }
        nav.quick.append(q)
    }

    private var runGrid: some View {
        LazyVGrid(columns: cols, spacing: 5) {
            ForEach(Defaults.runs, id: \.self) { r in
                Button { add(ProgItem(icon: "run", run: r)) } label: {
                    Text(r).font(F.t(13, .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity).frame(height: 30)
                        .wCard(9)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 4×2 — 아이콘·이름은 디자인(15 / 6.5pt)보다 크게: 20 / 8pt, 높이 44
    private var stationGrid: some View {
        LazyVGrid(columns: cols, spacing: 5) {
            ForEach(Station.all, id: \.key) { s in
                Button { add(ProgItem(icon: s.key)) } label: { stationTile(s) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func stationTile(_ s: Station) -> some View {
        VStack(spacing: 2) {
            Icon8(s.key, 20, tint: .yellow)
            Text(shortName(s.name))
                .font(F.t(12, .semibold)).foregroundStyle(C.text2)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity).frame(height: 44)
        .wCard(9)
    }

    private func shortName(_ n: String) -> String {
        n.replacingOccurrences(of: "Farmers Carry", with: "Farmers")
            .replacingOccurrences(of: "Wall Balls", with: "Wall Ball")
    }

    private var sequence: some View {
        WFlow(spacing: 3) {
            if nav.quick.isEmpty {
                Text("Tap to add").font(F.t(12)).foregroundStyle(C.text3)
            }
            ForEach(Array(nav.quick.enumerated()), id: \.offset) { _, q in
                chip(q)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func chip(_ q: ProgItem) -> some View {
        HStack(spacing: 2) {
            Icon8(q.icon, 9, tint: q.icon == "run" ? .white : .yellow)
            Text(chipLabel(q)).font(F.t(12, .semibold)).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, 2).padding(.horizontal, 5)
        .background(Color(hex: 0x1C1C1C), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var startButton: some View {
        Button {
            let p = store.saveQuick(nav.quick)
            nav.program = p; nav.quick = []; nav.screen = .confirm
        } label: {
            Text("Start · \(nav.quick.count)/\(maxSegs) segments")
                .font(F.t(16, .semibold)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(C.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 4)
        .accessibilityIdentifier("w.quickStart")
    }

    private func chipLabel(_ q: ProgItem) -> String {
        if q.icon == "run" { return q.run ?? "1KM" }
        return q.name().replacingOccurrences(of: "Farmers Carry", with: "FC")
            .replacingOccurrences(of: "Wall Balls", with: "WB")
            .replacingOccurrences(of: "Sled Push", with: "Push")
            .replacingOccurrences(of: "Sled Pull", with: "Pull")
    }
}

// MARK: - W2b Confirm

struct WConfirm: View {
    let store = WatchStore.shared
    let nav = WNav.shared
    let engine = WorkoutEngine.shared

    private var mode: Mode { nav.mode }
    private var program: Program { nav.program ?? Program.presets()[0] }
    private var seq: [Seg] { store.seq(mode: mode, program: mode == .training ? program : nil) }
    private var ev: RaceEvent { store.settings.event }
    private var noEvent: Bool { mode == .race && !ev.isSet }

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.22, 1.1, 0.5, 0.5, 1.08))
            VStack(spacing: 0) {
                WBackHeader(title: mode == .training ? program.name : mode.name, back: {
                    nav.screen = .home; nav.program = nil
                })
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 2)

                if mode == .training && program.isOpen {
                    openInfo
                } else if mode == .pft {
                    pftList
                } else if mode == .training {
                    trainingList
                } else if noEvent {
                    emptyRace
                } else {
                    simple
                }

                if !noEvent { startButton }
            }
            .padding(.top, 18).padding(.bottom, 12)
        }
        .ignoresSafeArea()
    }

    private var trainingList: some View {
        VStack(spacing: 0) {
            Text(String(localized: "\(seq.count) segments") + " · " + setsLabel)
                .font(F.t(13, .medium)).foregroundStyle(C.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(seq.filter { $0.kind != .rox }.enumerated()), id: \.offset) { _, s in
                        previewRow(s)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// PFT: 최고 기록(등급) 한 줄 + 종목 6개와 횟수
    private var pftList: some View {
        let best: Int? = store.ctx.pftBestTotal
        let head: String = best.map { "BEST".l10n + " " + Fm.t($0) } ?? "6 movements · for time".l10n
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(head).font(F.num(13, .medium)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let best { PFTBadge(grade: PFT.grade(best), width: 62, height: 18, fontSize: 10) }
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(seq.enumerated()), id: \.offset) { _, s in
                        pftRow(s)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func pftRow(_ s: Seg) -> some View {
        HStack(spacing: 8) {
            Icon8(s.icon, 14, tint: .yellow)
            Text(s.name).font(F.t(14)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            Text(s.detail.components(separatedBy: " · ").first ?? s.detail)
                .font(F.num(13, .medium)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, 5).padding(.horizontal, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x161616)).frame(height: 1) }
    }

    /// 1 set / 3 sets
    private var setsLabel: String {
        program.sets == 1 ? String(localized: "1 set") : String(localized: "\(program.sets) sets")
    }

    private func previewRow(_ s: Seg) -> some View {
        HStack(spacing: 8) {
            Icon8(s.icon, 14, tint: .yellow)
            Text(s.name).font(F.t(14)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            Text(s.target > 0 ? Fm.t(s.target) : "–").font(F.num(14, .medium)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, 5).padding(.horizontal, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x161616)).frame(height: 1) }
    }

    /// HIIT · 러닝: 이름 + 한 줄 설명
    private var openInfo: some View {
        VStack(spacing: 6) {
            Icon8(program.isHIIT ? "hiit" : "run", 30, tint: .yellow)
            Text(program.name.l10n).font(F.t(18, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            Text((program.meta ?? "").l10n).font(F.t(15)).foregroundStyle(C.text2)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyRace: some View {
        VStack(spacing: 6) {
            Text("No race set up").font(F.t(16, .semibold)).tracking(-0.14)
            Text("Add a race in the Race tab of the iPhone app and it will show up here.")
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(4)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var simple: some View {
        VStack(spacing: 4) {
            Text(mode == .race ? ev.name : "Full Simulation".l10n)
                .font(F.t(18, .semibold)).tracking(-0.36)
                .multilineTextAlignment(.center).lineLimit(2)
            Text(small).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
            Text(goal).font(F.num(30)).tracking(-0.6).lineLimit(1).minimumScaleFactor(0.85).padding(.top, 8)
            Text(goalWord.l10n).font(F.t(12, .semibold)).tracking(0.9).foregroundStyle(C.text2)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var startButton: some View {
        Button { start() } label: {
            Text("Start").font(F.t(14, .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: (mode == .training || mode == .pft) ? 36 : 44)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 16)
        .accessibilityIdentifier("w.start")
    }

    private var small: String {
        if mode == .race {
            return Fm.wdm.string(from: ev.date) + " · " + store.settings.div.name
        }
        return store.settings.div.name + " · " + "8 runs · 8 stations".l10n
    }

    /// Full Sim: 이번에 겨룰 기준의 합계 시간 (아이폰 Full Sim 화면의 "Compare with" 를 따름 — 구간 목표와 같은 기준)
    private var goal: String {
        if mode == .race { return Fm.t(store.settings.goalTime) }
        return Fm.t(seq.map(\.target).reduce(0, +))
    }
    /// GOAL / VS LAST / VS JIHO / VS BEST
    private var goalWord: String {
        if mode == .race { return "GOAL" }
        let w: String = store.simPick.word
        return w == "VS GOAL" ? "GOAL" : w
    }

    private func start() {
        let title: String
        switch mode {
        case .training: title = program.name
        case .pft: title = PFT.title
        case .sim: title = "Full Simulation"
        case .race: title = ev.name
        }
        engine.settings = store.settings
        // 3 · 2 · 1 을 센 뒤 시작
        engine.startAfterCountdown(mode: mode, title: title, sets: mode == .training ? program.sets : 1, seq: seq,
                                   program: mode == .training ? program : nil)
    }
}
