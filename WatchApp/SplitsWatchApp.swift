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
            } else {
                switch nav.screen {
                case .home: WHome()
                case .programs: WPrograms()
                case .quick: WQuick()
                case .confirm: WConfirm()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

/// ‹ 제목
struct WBackHeader<Trailing: View>: View {
    let title: String
    let back: () -> Void
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 4) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(C.accent)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(F.t(14, .semibold))
                .lineLimit(1)
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

/// 모드 아이콘: Training 은 PNG 22, Sim/Race 는 도형 20
struct WModeIcon: View {
    let mode: Mode
    var color: Color = C.accent
    var body: some View {
        Icon8(mode.icon, mode == .training ? 22 : 20, color)
    }
}

// MARK: - W1 Home

struct WHome: View {
    let store = WatchStore.shared
    let nav = WNav.shared

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.22, 0.9, 0.4, 0.5, -0.06))
            ScrollView {
                VStack(spacing: 6) {
                    HStack {
                        Wordmark(size: 12)
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.top, 2).padding(.bottom, 8)

                    ForEach(Mode.allCases) { m in
                        Button { open(m) } label: { card(m) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 16)
            }
        }
        .ignoresSafeArea()
    }

    private func desc(_ m: Mode) -> String {
        switch m {
        case .training: return "Custom blocks"
        case .sim: return "8 runs · 8 stations"
        case .race: return "Goal " + Fm.t(store.settings.goalTime)
        }
    }

    private func card(_ m: Mode) -> some View {
        HStack(spacing: 10) {
            WModeIcon(mode: m)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(F.t(13, .semibold)).tracking(-0.26).lineLimit(1)
                Text(desc(m)).font(F.t(10, .medium)).foregroundStyle(C.text2).lineLimit(1)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(m == .training ? Color(hex: 0x262626) : C.accent)
                if m == .training {
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .black)).foregroundStyle(C.accent)
                } else {
                    Icon8("play", 9, .black)
                }
            }
            .frame(width: 22, height: 22)
        }
        .padding(.vertical, 11).padding(.horizontal, 12)
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
                        Button { nav.quick = []; nav.screen = .quick } label: {
                            HStack {
                                Text("Quick training").font(F.t(13, .semibold))
                                Spacer()
                                Image(systemName: "plus").font(.system(size: 12, weight: .heavy))
                            }
                            .foregroundStyle(.black)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        ForEach(store.programs) { p in
                            Button { nav.program = p; nav.screen = .confirm } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(F.t(13, .semibold)).lineLimit(1)
                                    Text(p.watchMeta).font(F.t(10)).foregroundStyle(C.text2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10).padding(.horizontal, 12)
                                .wCard(14)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Edit names on iPhone")
                            .font(F.t(9)).foregroundStyle(C.text3)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18).padding(.bottom, 12)
        }
        .ignoresSafeArea()
    }
}

// MARK: - W2q Quick training

struct WQuick: View {
    let store = WatchStore.shared
    let nav = WNav.shared
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    private let stCols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient.y(0.16, 0.7, 0.45, 0, 0))
            VStack(spacing: 0) {
                WBackHeader(title: "Quick training", back: { nav.screen = .programs }) {
                    if !nav.quick.isEmpty {
                        Button("Clear") { nav.quick = [] }
                            .buttonStyle(.plain)
                            .font(F.t(10, .semibold)).foregroundStyle(C.bad)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 6)

                ScrollView {
                    VStack(spacing: 6) {
                        LazyVGrid(columns: cols, spacing: 5) {
                            ForEach(Defaults.runs, id: \.self) { r in
                                Button { nav.quick.append(ProgItem(icon: "run", run: r)) } label: {
                                    Text(r).font(F.t(12, .semibold))
                                        .frame(maxWidth: .infinity).frame(height: 34)
                                        .wCard(9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        LazyVGrid(columns: stCols, spacing: 5) {
                                ForEach(Station.all, id: \.key) { s in
                                Button { nav.quick.append(ProgItem(icon: s.key)) } label: {
                                    VStack(spacing: 3) {
                                        Icon8(s.key, 28, tint: .yellow)
                                        Text(s.name.replacingOccurrences(of: "Farmers Carry", with: "Farmers")
                                                .replacingOccurrences(of: "Wall Balls", with: "Wall Ball")
                                                .replacingOccurrences(of: "Sandbag Lunges", with: "Lunges")
                                                .replacingOccurrences(of: "Burpee Broad Jump", with: "Burpee"))
                                            .font(F.t(9, .semibold)).foregroundStyle(C.text2).lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 58)
                                    .wCard(9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 3) {
                                if nav.quick.isEmpty {
                                    Text("Tap to add").font(F.t(9)).foregroundStyle(C.text3)
                                }
                                ForEach(Array(nav.quick.enumerated()), id: \.offset) { _, q in
                                    HStack(spacing: 2) {
                                        Icon8(q.icon, 14, tint: q.icon == "run" ? .white : .yellow)
                                        Text(chipLabel(q)).font(F.t(10, .semibold)).lineLimit(1)
                                    }
                                    .padding(.vertical, 2).padding(.horizontal, 5)
                                    .background(Color(hex: 0x1C1C1C), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .frame(minHeight: 26)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !nav.quick.isEmpty {
                    Button {
                        let p = store.saveQuick(nav.quick)
                        nav.program = p; nav.quick = []; nav.screen = .confirm
                    } label: {
                        Text("Start · \(nav.quick.count) segments")
                            .font(F.t(14, .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(C.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.top, 4)
                }
            }
            .padding(.top, 18).padding(.bottom, 10)
        }
        .ignoresSafeArea()
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

                if mode == .training {
                    Text("\(seq.count) segments · \(program.sets) sets")
                        .font(F.t(10, .medium)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.bottom, 8)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(seq.filter { $0.kind != .rox }.enumerated()), id: \.offset) { _, s in
                                HStack(spacing: 8) {
                                    Icon8(s.icon, 14, tint: .yellow)
                                    Text(s.name).font(F.t(12)).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(Fm.t(s.target)).font(F.round(12, .medium)).foregroundStyle(C.text2)
                                }
                                .padding(.vertical, 5).padding(.horizontal, 4)
                                .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x161616)).frame(height: 1) }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else if noEvent {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("No race set up").font(F.t(14, .semibold)).tracking(-0.14)
                        Text("iPhone 앱 Race 탭에서 대회를 등록하면 여기에 표시됩니다.")
                            .font(F.t(10)).foregroundStyle(C.text2).lineSpacing(3)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(mode == .race ? ev.name : "Full Simulation")
                            .font(F.t(18, .semibold)).tracking(-0.36).multilineTextAlignment(.center)
                        Text(small).font(F.t(11)).foregroundStyle(C.text2)
                        Text(goal).font(F.round(30)).tracking(-0.6).padding(.top, 8)
                        Text(mode == .race ? "GOAL" : "BEST").font(F.t(9, .semibold)).tracking(0.9).foregroundStyle(C.text2)
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }

                if !noEvent {
                    Button { start() } label: {
                        Text("Start").font(F.t(12, .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: mode == .training ? 36 : 44)
                            .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 4)
                }
            }
            .padding(.top, 18).padding(.bottom, 12)
        }
        .ignoresSafeArea()
    }

    private var small: String {
        if mode == .race {
            return Fm.wdm.string(from: ev.date) + " · " + store.settings.div.name
        }
        return store.settings.div.name + " · 8 runs · 8 stations"
    }

    private var goal: String {
        if mode == .race { return Fm.t(store.settings.goalTime) }
        if let b = store.ctx.simBestTotal { return Fm.t(b) }
        return Fm.t(seq.map(\.target).reduce(0, +))
    }

    private func start() {
        let title: String
        switch mode {
        case .training: title = program.name
        case .sim: title = "Full Simulation"
        case .race: title = ev.name
        }
        engine.settings = store.settings
        engine.start(mode: mode, title: title, sets: mode == .training ? program.sets : 1, seq: seq)
    }
}
