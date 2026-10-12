import SwiftUI
import Observation
import WatchKit

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

enum WScreen: Hashable { case home, programs, quick, confirm }

/// 워치 화면 이동 상태
/// 58번: 워치 기본 화면 넘기기(NavigationStack) — 왼쪽 끝에서 밀면 뒤로, 왼쪽 위 기본 ‹ 버튼
@Observable
final class WNav {
    static let shared = WNav()
    /// 첫 화면 위에 쌓인 화면들 (비면 첫 화면)
    var path: [WScreen] = []
    var mode: Mode = .race
    var program: Program?
    var quick: [ProgItem] = []

    /// 예전 코드와 같은 쓰임: 지금 맨 위 화면. 넣으면 그 화면까지의 길을 만들어 줌
    /// (모드를 먼저 정한 다음 screen 을 넣을 것 — 확인 화면 앞에 트레이닝 목록을 둘지 모드로 정함)
    var screen: WScreen {
        get { path.last ?? .home }
        set {
            switch newValue {
            case .home: path = []
            case .programs: path = [.programs]
            case .quick: path = [.programs, .quick]
            case .confirm: path = mode == .training ? [.programs, .confirm] : [.confirm]
            }
        }
    }
}

struct WRoot: View {
    @Bindable var nav = WNav.shared
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
                NavigationStack(path: $nav.path) {
                    WHome()
                        .navigationDestination(for: WScreen.self) { sc in
                            switch sc {
                            case .home: WHome()
                            case .programs: WPrograms()
                            case .quick: WQuick()
                            case .confirm: WConfirm()
                            }
                        }
                }
            }
        }
    }
}

/// 넘어간 화면의 바탕 (워치 기본 내비게이션 바탕 자리에 노란 빛)
struct WNavBG: ViewModifier {
    let a: Ambient
    func body(content: Content) -> some View {
        content.containerBackground(for: .navigation) {
            ZStack { Color.black; AmbientLayer(a: a) }
        }
    }
}
extension View {
    func wNavBG(_ a: Ambient) -> some View { modifier(WNavBG(a: a)) }
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
        // 57번: 카드 4개를 화면 세로 가운데에 둠. 화면에 다 들어가도 끌면 따라오고 놓으면 제자리(스프링)
        GeometryReader { g in
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Mode.allCases) { m in
                        Button { open(m) } label: { card(m) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("w.mode." + m.rawValue)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: g.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.always)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Wordmark(size: 12)
            }
        }
        .wNavBG(Ambient.y(0.22, 0.9, 0.4, 0.5, -0.06))
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
            // ▶ 는 9 → 12 (동그라미 22 그대로). 세모는 정가운데면 왼쪽으로 쏠려 보여서 오른쪽으로 1pt
            ZStack {
                Circle().fill(C.accent)
                Icon8("i_play", 12, .black)
                    .offset(x: 1)
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
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
        .navigationTitle(Text("Training".l10n))
        .wNavBG(Ambient.y(0.16, 0.7, 0.45, 1.0, 0))
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
    private let maxSegs = 16   // 트레이닝 세트 최대 16구간 (오너 지정)
    private let gap: CGFloat = 5
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    /// 59번: 누르면 1초쯤 뜨는 "＋ Sled Push · 3번째"
    @State private var toast: String?
    @State private var toastID = 0

    var body: some View {
        // 59번: 첫 화면 = 러닝 4칸 + 스테이션 8칸이 화면을 꽉 채움. 쌓인 구간 · 지우기 · 시작은 스크롤하면 나옴
        GeometryReader { g in
            let h: CGFloat = max(120, g.size.height - 4)
            let runH: CGFloat = (h * 0.2).rounded()
            let stH: CGFloat = ((h - runH - gap * 2) / 2).rounded(.down)
            ScrollView {
                VStack(spacing: gap) {
                    runGrid(runH)
                    stationGrid(stH)
                    below
                        .padding(.top, 10)
                }
                .padding(.horizontal, 10).padding(.bottom, 8)
            }
            .overlay(alignment: .bottom) { toastView }
        }
        .navigationTitle(Text("Quick training".l10n))
        .wNavBG(Ambient.y(0.16, 0.7, 0.45, 0, 0))
    }

    private func add(_ q: ProgItem) {
        guard nav.quick.count < maxSegs else {
            WKInterfaceDevice.current().play(.failure)
            show(String(format: "Max %lld segments".l10n, maxSegs))
            return
        }
        nav.quick.append(q)
        WKInterfaceDevice.current().play(.click)
        show("＋ " + chipLabel(q, full: true) + " · " + String(format: "No. %lld".l10n, nav.quick.count))
    }

    private func show(_ t: String) {
        toastID += 1
        let id = toastID
        withAnimation(.easeOut(duration: 0.12)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if id == toastID { withAnimation(.easeIn(duration: 0.2)) { toast = nil } }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let t = toast {
            Text(t).font(F.t(13, .semibold)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 10).frame(height: 26)
                .background(C.accent, in: Capsule())
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .accessibilityIdentifier("w.quickToast")
        }
    }

    private func runGrid(_ hgt: CGFloat) -> some View {
        LazyVGrid(columns: cols, spacing: gap) {
            ForEach(Defaults.runs, id: \.self) { r in
                Button { add(ProgItem(icon: "run", run: r)) } label: {
                    Text(r).font(F.t(14, .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity).frame(height: hgt)
                        .wCard(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 4×2 — 칸 높이는 화면에 맞춰 계산, 아이콘은 칸 높이의 45% (최대 30)
    private func stationGrid(_ hgt: CGFloat) -> some View {
        let icon: CGFloat = min(30, max(20, (hgt * 0.45).rounded()))
        return LazyVGrid(columns: cols, spacing: gap) {
            ForEach(Station.all, id: \.key) { s in
                Button { add(ProgItem(icon: s.key)) } label: {
                    VStack(spacing: 3) {
                        Icon8(s.key, icon, tint: .yellow)
                        Text(shortName(s.name))
                            .font(F.t(12, .semibold)).foregroundStyle(C.text2)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.horizontal, 1)
                    }
                    .frame(maxWidth: .infinity).frame(height: hgt)
                    .wCard(10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("w.quick." + s.key)
            }
        }
    }

    private func shortName(_ n: String) -> String {
        n.replacingOccurrences(of: "Farmers Carry", with: "Farmers")
            .replacingOccurrences(of: "Wall Balls", with: "Wall Ball")
    }

    /// 스크롤하면 나오는 부분: 쌓인 구간 · 마지막 지우기 · 모두 지우기 · 시작
    private var below: some View {
        VStack(spacing: 8) {
            WFlow(spacing: 3) {
                if nav.quick.isEmpty {
                    Text("Tap to add").font(F.t(12)).foregroundStyle(C.text3)
                }
                ForEach(Array(nav.quick.enumerated()), id: \.offset) { _, q in
                    chip(q)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)

            if !nav.quick.isEmpty {
                HStack(spacing: 6) {
                    smallButton("Remove last") { _ = nav.quick.popLast(); WKInterfaceDevice.current().play(.click) }
                        .accessibilityIdentifier("w.quickUndo")
                    smallButton("Clear all") { nav.quick = []; WKInterfaceDevice.current().play(.click) }
                        .accessibilityIdentifier("w.quickClear")
                }
                startButton
            }
        }
    }

    private func smallButton(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t.l10n).font(F.t(13, .semibold)).foregroundStyle(C.bad)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(Color(hex: 0x1C1C1C), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ q: ProgItem) -> some View {
        HStack(spacing: 2) {
            Icon8(q.icon, 9, tint: q.icon == "run" ? .white : .yellow)
            Text(chipLabel(q)).font(F.t(12, .semibold)).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, 2).padding(.horizontal, 5)
        .background(Color(hex: 0x1C1C1C), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    /// 60번: "시작 · 3구간" (16 은 다 찼을 때만 안내)
    private var startButton: some View {
        Button {
            let p = store.saveQuick(nav.quick)
            nav.program = p; nav.quick = []; nav.screen = .confirm
        } label: {
            Text("Start · \(nav.quick.count) segments")
                .font(F.t(16, .semibold)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(C.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("w.quickStart")
    }

    private func chipLabel(_ q: ProgItem, full: Bool = false) -> String {
        if q.icon == "run" { return q.run ?? "1KM" }
        if full { return q.name() }
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
        VStack(spacing: 0) {
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
        .padding(.bottom, 4)
        .navigationTitle(Text((mode == .training ? program.name : mode.name).l10n))
        .wNavBG(Ambient.y(0.22, 1.1, 0.5, 0.5, 1.08))
    }

    private var trainingList: some View {
        VStack(spacing: 0) {
            Text(String(format: "%lld segments".l10n, seq.count) + " · " + setsLabel)
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
        program.sets == 1 ? "1 set".l10n : String(format: "%lld sets".l10n, program.sets)
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
        .padding(.horizontal, 14).padding(.top, 6)
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
