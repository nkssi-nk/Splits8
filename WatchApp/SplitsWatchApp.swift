import SwiftUI
import Observation
import WatchKit

@main
struct Splits8WatchApp: App {
    /// 98번: 아이폰의 "워치에서 시작"(보정)으로 켜질 때 운동 설정을 받음
    @WKApplicationDelegateAdaptor(WDelegate.self) var delegate
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
    let calib = Calib.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if calib.icon != nil && !engine.active && engine.countdown == nil {
                WCalibView()
            } else if engine.active && engine.finished {
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
        // 57번 → 66번(빌드 25): 카드 4개를 화면 세로 가운데에 고정.
        // 예전엔 ScrollView 라 실제 워치에서 위 로고 줄 때문에 내용이 살짝 커져 스크롤되고 놓은 자리에 멈췄음.
        // 이제 화면에 다 들어가면 스크롤 없이 가운데 + 끌면 따라오고 놓으면 제자리(스프링). 안 들어가는 작은 워치만 스크롤.
        // 96번(빌드 28): ViewThatFits 는 카드 4개(약 178pt)가 조금만 넘쳐도 ScrollView 를 골라서
        // 실제 워치에서 늘 스크롤 화면이 나왔음 → 항상 가운데 고정. 남는 높이를 재서 모자라면 카드 여백 · 간격만 줄임
        GeometryReader { geo in
            let fit = Self.fit(geo.size.height)
            WHomeFixed(cards: cards(pad: fit.pad, gap: fit.gap))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Wordmark(size: 12)
            }
        }
        .wNavBG(Ambient.y(0.22, 0.9, 0.4, 0.5, -0.06))
    }

    /// 카드 하나 = 위아래 여백 × 2 + 22(아이콘 · 버튼). 기본 여백 9 · 간격 6, 모자라면 여백 4 · 간격 3 까지 줄임
    static func fit(_ h: CGFloat) -> (pad: CGFloat, gap: CGFloat) {
        // 4 × (22 + 9 × 2) + 3 × 6 + 8 = 186 (컴파일러가 오래 걸리지 않게 숫자로)
        let need: CGFloat = 186
        if h >= need { return (9, 6) }
        let free: CGFloat = h - 96                               // 아이콘 4개(88) + 위아래 4 를 뺀 높이
        let room: CGFloat = free > 0 ? free : 0                  // 여백 8개 + 간격 3개에 쓸 수 있는 높이
        var gap: CGFloat = room / 10
        if gap > 6 { gap = 6 }
        if gap < 3 { gap = 3 }
        var pad: CGFloat = (room - gap * 3) / 8
        if pad > 9 { pad = 9 }
        if pad < 4 { pad = 4 }
        return (pad, gap)
    }

    private func cards(pad: CGFloat, gap: CGFloat) -> some View {
        VStack(spacing: gap) {
            ForEach(Mode.allCases) { m in
                Button { open(m) } label: { card(m, pad: pad) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("w.mode." + m.rawValue)
            }
        }
        .padding(.horizontal, 12)
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

    private func card(_ m: Mode, pad: CGFloat) -> some View {
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
        .padding(.vertical, pad).padding(.horizontal, 12)
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
    @State private var goalSheet = false

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

                if noEvent {
                } else if mode == .training && (program.isRun || program.isInterval) {
                    runStartButtons
                } else {
                    startButton
                }
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
            Icon8(WKind.icon(program.kind), 30, tint: .yellow)
            Text(program.name.l10n).font(F.t(18, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            Text(program.kindLine ?? (program.meta ?? "").l10n).font(F.t(15)).foregroundStyle(C.text2)
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

    /// 빌드 27 (71-1): Full Sim 은 맨 위 제목과 겹치던 큰 제목을 빼고 목표 시간을 크게. 목표를 누르면 워치에서 바로 바꿈(68-①)
    private var simple: some View {
        VStack(spacing: 4) {
            if mode == .race {
                Text(ev.name)
                    .font(F.t(18, .semibold)).tracking(-0.36)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
            Text(small).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
            if mode == .sim {
                Button { goalSheet = true } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(goal).font(F.num(34)).tracking(-0.6).lineLimit(1).minimumScaleFactor(0.85)
                            Image(systemName: "pencil").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.accent)
                        }
                        Text(goalWord.l10n).font(F.t(12, .semibold)).tracking(0.9).foregroundStyle(C.text2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityIdentifier("w.simGoal")
            } else {
                Text(goal).font(F.num(30)).tracking(-0.6).lineLimit(1).minimumScaleFactor(0.85).padding(.top, 8)
                Text(goalWord.l10n).font(F.t(12, .semibold)).tracking(0.9).foregroundStyle(C.text2)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $goalSheet) { WGoalPicker() }
    }

    /// 83번(빌드 28): 러닝은 시작할 때 실외(GPS) / 실내를 고름 — 애플 운동 앱처럼.
    /// 카드에 저장된 쪽이 노란 버튼, 다른 쪽은 회색. 실내는 GPS 없이 손목 움직임으로 거리를 짐작
    private var runStartButtons: some View {
        let cardIndoor: Bool = program.indoor ?? false
        return HStack(spacing: 6) {
            runButton(indoor: false, main: !cardIndoor)
            runButton(indoor: true, main: cardIndoor)
        }
        .padding(.horizontal, 14).padding(.top, 6)
    }

    private func runButton(indoor: Bool, main: Bool) -> some View {
        Button { start(indoor: indoor) } label: {
            VStack(spacing: 1) {
                Text((indoor ? "Indoor" : "Outdoor").l10n).font(F.t(14, .semibold))
                Text((indoor ? "No GPS" : "GPS").l10n).font(F.t(10, .medium)).opacity(0.7)
            }
            .foregroundStyle(main ? .black : .white)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(main ? C.accent : Color(hex: 0x262626), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(indoor ? "w.startIndoor" : "w.startOutdoor")
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
        // 86번: 워치에서 고른 목표는 그 숫자 그대로 보여 줌.
        // 예전엔 16칸 합(= 목표 − Roxzone 8번)만 보여서, Roxzone 을 안 켜면 고른 1:30 이 1:26 처럼 다르게 보였음
        if let g = store.watchGoal { return Fm.t(g) }
        let segs: [Seg] = seq
        let hasRox: Bool = segs.contains { $0.kind == .rox }
        return Fm.t(segs.map(\.target).reduce(0, +) + (hasRox ? 0 : 8 * store.settings.roxTarget))
    }
    /// GOAL / VS LAST / VS JIHO / VS BEST
    private var goalWord: String {
        if mode == .race { return "GOAL" }
        let w: String = store.simPick.word
        return w == "VS GOAL" ? "GOAL" : w
    }

    private func start(indoor: Bool? = nil) {
        // 83번: 러닝은 고른 실내/실외로 이번 운동만 바꿔서 시작 (카드 자체는 그대로)
        var prog: Program = program
        if let indoor { prog.indoor = indoor }
        let title: String
        switch mode {
        case .training: title = program.name
        case .pft: title = PFT.title
        case .sim: title = "Full Simulation"
        case .race: title = ev.name
        }
        engine.settings = store.settings
        // 3 · 2 · 1 을 센 뒤 시작
        engine.startAfterCountdown(mode: mode, title: title, sets: mode == .training ? prog.sets : 1, seq: seq,
                                   program: mode == .training ? prog : nil)
    }
}

/// 빌드 27 (68-①): 워치에서 Full Sim 목표 완주 시간 고르기 (크라운으로 1분 단위). 고르면 16구간을 다시 나눔
struct WGoalPicker: View {
    let store = WatchStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 90

    private static let range: [Int] = Array(45...180)

    var body: some View {
        VStack(spacing: 6) {
            Text("Goal time").font(F.t(13, .semibold)).foregroundStyle(C.text2)
            Picker("", selection: $minutes) {
                ForEach(Self.range, id: \.self) { v in
                    Text(Fm.t(v * 60)).font(F.num(22)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 70)
            Button {
                store.watchGoal = minutes * 60
                dismiss()
            } label: {
                Text("Set").font(F.t(14, .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            if store.watchGoal != nil {
                Button {
                    store.watchGoal = nil
                    dismiss()
                } label: {
                    Text("Use iPhone setting").font(F.t(12)).foregroundStyle(C.text2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            let cur: Int = store.watchGoal ?? store.simTargets.reduce(0, +) + 8 * store.settings.roxTarget
            minutes = min(180, max(45, Int((Double(cur) / 60).rounded())))
        }
    }
}

/// 66번: 화면 가운데 고정 + 위아래로 끌면 살짝 따라오고(저항) 놓으면 스프링으로 제자리
private struct WHomeFixed<C: View>: View {
    let cards: C
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        cards
            .offset(y: drag)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .updating($drag) { v, st, _ in
                        let t: CGFloat = v.translation.height
                        st = t / (1 + abs(t) / 60) * 0.6      // 멀리 끌수록 덜 따라옴
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: drag)
    }
}
