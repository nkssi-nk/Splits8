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

/// 넘어간 화면의 바탕 — 1.2.7: 검정 + 테마 빛 색(아이폰 설정 > Theme) 흐린 덩어리. 화면마다 다른 자리 (seed)
struct WNavBG: ViewModifier {
    let seed: Int
    func body(content: Content) -> some View {
        content.containerBackground(for: .navigation) {
            W8MenuBackground(seed: seed)
        }
    }
}
extension View {
    func wNavBG(_ seed: Int) -> some View { modifier(WNavBG(seed: seed)) }
}

// MARK: - 시작 전 3 · 2 · 1

/// Start 를 누르면 3 · 2 · 1 을 센 뒤 시간이 시작됨. 화면을 누르면 취소
struct WCountdown: View {
    let n: Int
    let engine = WorkoutEngine.shared

    /// 1.2.7 시안: 노란 숫자 110 + 귀퉁이 표시 (좌우 44, 숫자 위아래 18), "Tap to cancel" 은 아래 큰 버튼 자리 아래 끝
    var body: some View {
        W8Canvas { L in
            let s: CGFloat = L.s
            let hintY: CGFloat = L.b(12) - w8Cap(13) * s / 2
            let mid: CGFloat = (L.t(30) + hintY - w8Cap(13) * s / 2 - 12 * s) / 2
            let ch: CGFloat = w8Cap(110) * s
            ZStack {
                W8MenuBackground(seed: 60)
                W8Brackets(arm: 9 * s)
                    .stroke(Color.white.opacity(0.47), style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
                    .frame(width: L.w - 88 * s, height: ch + 36 * s)
                    .position(x: L.cx, y: mid)
                Text(verbatim: "\(n)")
                    .font(F.num(110 * s, .bold)).foregroundStyle(C.accent)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.25), value: n)
                    .position(x: L.cx, y: mid)
                    .accessibilityIdentifier("w.count")
                Text("Tap to cancel").font(F.t(13 * s, .semibold)).foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .position(x: L.cx, y: hintY)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { engine.cancelCountdown() }
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
    /// 1.2.7: 워치 카드도 맑은 유리 (흰 12% + 위쪽 옅은 빛 + 그림자)
    func wCard(_ r: CGFloat = 14) -> some View {
        background(W8Glass(shape: RoundedRectangle(cornerRadius: r, style: .continuous), fill: Color.white.opacity(0.12), rim: 0.45))
    }
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

// MARK: - W1 Home (1.2.7 시안 A: 카드 4개 높이 42 · 간격 6 · 좌우 12, 시계 줄 아래 ~ 화면 아래 10 의 가운데)

struct WHome: View {
    let store = WatchStore.shared
    let nav = WNav.shared

    var body: some View {
        W8Canvas { L in
            let s: CGFloat = L.s
            let hgt: CGFloat = 42 * s, gap: CGFloat = 6 * s
            let tot: CGFloat = 4 * hgt + 3 * gap
            let y0: CGFloat = (L.t(32) + L.b(10)) / 2 - tot / 2
            ZStack {
                // 시안: 왼쪽 위 로고 (x 16, 높이 11, 가운데 y 20.5 — 시계 줄과 같은 줄)
                Wordmark(size: 15 * s)
                    .padding(.leading, 16 * s)
                    .frame(width: L.w, alignment: .leading)
                    .position(x: L.cx, y: L.t(20.5))
                ForEach(Array(Mode.allCases.enumerated()), id: \.offset) { i, m in
                    Button { open(m) } label: { card(m, s: s, cw: L.w - 24 * s) }
                        .buttonStyle(W8Press())
                        .frame(width: L.w - 24 * s, height: hgt)
                        .position(x: L.cx, y: y0 + CGFloat(i) * (hgt + gap) + hgt / 2)
                        .accessibilityIdentifier("w.mode." + m.rawValue)
                }
            }
        }
        .wNavBG(40)
    }

    @ViewBuilder
    private func action(_ m: Mode, s: CGFloat) -> some View {
        if m == .training {
            ZStack {
                W8Glass(shape: Circle(), fill: Color.white.opacity(0.16), rim: 0.5)
                Image(systemName: "chevron.right").font(.system(size: 9 * s, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 22 * s, height: 22 * s)
        } else {
            ZStack {
                W8Glass(shape: Circle(), fill: Color(hex: 0xFFDC14).opacity(0.84), rim: 0.47, gloss: 0.27)
                Image(systemName: "play.fill").font(.system(size: 9 * s, weight: .bold)).foregroundStyle(.black)
                    .offset(x: 0.8 * s)
            }
            .frame(width: 22 * s, height: 22 * s)
        }
    }

    /// 아이콘 가운데 x 24 · 이름 x 44 · 오른쪽 동그라미 (r 11, 끝에서 22)
    private func card(_ m: Mode, s: CGFloat, cw: CGFloat) -> some View {
        let nameW: CGFloat = cw - 44 * s - 39 * s
        return ZStack {
            W8Glass(shape: RoundedRectangle(cornerRadius: 16 * s, style: .continuous), fill: Color.white.opacity(0.12), rim: 0.55)
            WModeIcon(mode: m)
                .frame(width: 24 * s, height: 22 * s)
                .position(x: 24 * s, y: 21 * s)
            Text(m.name.l10n).font(F.t(15 * s, .semibold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: nameW, alignment: .leading)
                .position(x: 44 * s + nameW / 2, y: 21 * s)
            action(m, s: s)
                .position(x: cw - 22 * s, y: 21 * s)
        }
        .frame(width: cw, height: 42 * s)
        .contentShape(RoundedRectangle(cornerRadius: 16 * s, style: .continuous))
    }

    private func open(_ m: Mode) {
        nav.mode = m
        nav.program = nil
        nav.screen = m == .training ? .programs : .confirm
    }
}

// MARK: - W2a Training list (제목 41 · 목록은 52 부터, Quick 38 · 카드 46 · 간격 6)

struct WPrograms: View {
    let store = WatchStore.shared
    let nav = WNav.shared

    var body: some View {
        W8Canvas { L in
            let s: CGFloat = L.s
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 6 * s) {
                        quickCard(s)
                        ForEach(store.programs) { p in
                            Button { nav.program = p; nav.screen = .confirm } label: { programCard(p, s) }
                                .buttonStyle(W8Press())
                        }
                        Text("Edit names on iPhone")
                            .font(F.t(11 * s, .medium)).foregroundStyle(C.text3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4 * s)
                    }
                    .padding(.horizontal, 12 * s).padding(.top, 2 * s).padding(.bottom, 12 * s)
                }
                .frame(width: L.w, height: L.h - L.t(52))
                .clipped()
                .offset(y: L.t(52))
                W8TitleAt(L: L, title: "Training")
            }
        }
        .wNavBG(23)
    }

    private func quickCard(_ s: CGFloat) -> some View {
        Button { nav.quick = []; nav.screen = .quick } label: {
            HStack {
                Text("Quick training").font(F.t(15 * s, .semibold))
                Spacer(minLength: 0)
                Image(systemName: "plus").font(.system(size: 13 * s, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14 * s)
            .frame(height: 38 * s)
            .background(W8Glass(shape: RoundedRectangle(cornerRadius: 14 * s, style: .continuous),
                                fill: Color(hex: 0xFFDC14).opacity(0.84), rim: 0.47, gloss: 0.27))
            .contentShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
        }
        .buttonStyle(W8Press())
        .accessibilityIdentifier("w.quick")
    }

    private func programCard(_ p: Program, _ s: CGFloat) -> some View {
        HStack(spacing: 6 * s) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(p.name.l10n).font(F.t(15 * s, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text(p.watchMeta).font(F.t(12 * s, .medium)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 10 * s, weight: .bold)).foregroundStyle(Color.white.opacity(0.47))
        }
        .padding(.horizontal, 14 * s)
        .frame(height: 46 * s)
        .background(W8Glass(shape: RoundedRectangle(cornerRadius: 14 * s, style: .continuous), fill: Color.white.opacity(0.12), rim: 0.55))
        .contentShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
    }
}

// MARK: - W2q Quick training (제목 41 · 칸은 52 ~ 화면 아래 18: 러닝 30 + 스테이션 두 줄, 간격 5)

struct WQuick: View {
    let store = WatchStore.shared
    let nav = WNav.shared
    private let maxSegs = 16   // 트레이닝 세트 최대 16구간 (오너 지정)
    /// 59번: 누르면 1초쯤 뜨는 "＋ Sled Push · 3번째"
    @State private var toast: String?
    @State private var toastID = 0

    var body: some View {
        W8Canvas { L in
            let s: CGFloat = L.s
            let gap: CGFloat = 5 * s
            let grid: CGFloat = L.b(18) - L.t(52)
            let runH: CGFloat = 30 * s
            let stH: CGFloat = (grid - runH - 2 * gap) / 2
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: gap) {
                        runGrid(runH, s: s)
                        stationGrid(stH, s: s)
                        below(s)
                            .frame(minHeight: L.h - L.t(52) - 4 * s)
                    }
                    .padding(.horizontal, 10 * s)
                }
                .frame(width: L.w, height: L.h - L.t(52))
                .clipped()
                .offset(y: L.t(52))
                W8TitleAt(L: L, title: "Quick training")
            }
            .overlay(alignment: .bottom) { toastView(s).padding(.bottom, 6 * s) }
        }
        .wNavBG(31)
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
    private func toastView(_ s: CGFloat) -> some View {
        if let t = toast {
            Text(t).font(F.t(13 * s, .semibold)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 10 * s).frame(height: 26 * s)
                .background(W8Glass(shape: Capsule(), fill: Color(hex: 0xFFDC14).opacity(0.92), rim: 0.47, gloss: 0.27))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .accessibilityIdentifier("w.quickToast")
        }
    }

    private func tile<V: View>(_ h: CGFloat, _ s: CGFloat, @ViewBuilder _ v: () -> V) -> some View {
        v()
            .frame(maxWidth: .infinity).frame(height: h)
            .background(W8Glass(shape: RoundedRectangle(cornerRadius: 11 * s, style: .continuous), fill: Color.white.opacity(0.12), rim: 0.55))
            .contentShape(RoundedRectangle(cornerRadius: 11 * s, style: .continuous))
    }

    private func runGrid(_ hgt: CGFloat, s: CGFloat) -> some View {
        HStack(spacing: 5 * s) {
            ForEach(Defaults.runs, id: \.self) { r in
                Button { add(ProgItem(icon: "run", run: r)) } label: {
                    tile(hgt, s) {
                        Text(r).font(F.t(13 * s, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
                .buttonStyle(W8Press())
            }
        }
    }

    /// 4×2 — 아이콘 24 (칸 40% 자리) · 이름 10 (칸 80% 자리)
    private func stationGrid(_ hgt: CGFloat, s: CGFloat) -> some View {
        let rows: [[Station]] = [Array(Station.all.prefix(4)), Array(Station.all.dropFirst(4).prefix(4))]
        return VStack(spacing: 5 * s) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 5 * s) {
                    ForEach(rows[r], id: \.key) { st in
                        Button { add(ProgItem(icon: st.key)) } label: {
                            tile(hgt, s) {
                                ZStack {
                                    Icon8(st.key, min(24 * s, hgt * 0.42), tint: .yellow)
                                        .offset(y: hgt * (0.40 - 0.5))
                                    Text(shortName(st.name)).font(F.t(10 * s, .semibold)).foregroundStyle(Color.white.opacity(0.65))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                        .padding(.horizontal, 2 * s)
                                        .offset(y: hgt * (0.80 - 0.5))
                                }
                            }
                        }
                        .buttonStyle(W8Press())
                        .accessibilityIdentifier("w.quick." + st.key)
                    }
                }
            }
        }
    }

    private func shortName(_ n: String) -> String {
        n.replacingOccurrences(of: "Farmers Carry", with: "Farmers")
            .replacingOccurrences(of: "Wall Balls", with: "Wall Ball")
            .replacingOccurrences(of: "Burpee Broad Jumps", with: "BBJ")
            .replacingOccurrences(of: "Sandbag Lunges", with: "Lunges")
    }

    /// 스크롤하면 나오는 부분: 쌓인 구간(줄마다 가운데) · 마지막 지우기 | 모두 지우기 — 가운데, Start 는 아래 큰 버튼 자리
    private func below(_ s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8 * s)
            VStack(spacing: 14 * s) {
                WFlow(spacing: 5 * s) {
                    if nav.quick.isEmpty {
                        Text("Tap to add").font(F.t(12 * s)).foregroundStyle(C.text3)
                    }
                    ForEach(Array(nav.quick.enumerated()), id: \.offset) { _, q in
                        chip(q, s)
                    }
                }
                .frame(maxWidth: .infinity)
                if !nav.quick.isEmpty {
                    HStack(spacing: 6 * s) {
                        smallButton("Remove last", s) { _ = nav.quick.popLast(); WKInterfaceDevice.current().play(.click) }
                            .accessibilityIdentifier("w.quickUndo")
                        smallButton("Clear all", s) { nav.quick = []; WKInterfaceDevice.current().play(.click) }
                            .accessibilityIdentifier("w.quickClear")
                    }
                }
            }
            Spacer(minLength: 8 * s)
            if !nav.quick.isEmpty {
                startButton(s)
                    .padding(.bottom, 12 * s)
            }
        }
    }

    private func smallButton(_ t: String, _ s: CGFloat, action: @escaping () -> Void) -> some View {
        W8GlassButton(title: t, height: 34 * s, fontSize: 13 * s, action: action)
    }

    private func chip(_ q: ProgItem, _ s: CGFloat) -> some View {
        HStack(spacing: 4 * s) {
            Icon8(q.icon, 12 * s, tint: q.icon == "run" ? .white : .yellow)
            Text(chipLabel(q)).font(F.t(12 * s, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.leading, 8 * s).padding(.trailing, 9 * s)
        .frame(height: 22 * s)
        .background(W8Glass(shape: RoundedRectangle(cornerRadius: 8 * s, style: .continuous), fill: Color.white.opacity(0.12), rim: 0.45))
    }

    /// 60번: "시작 · 3구간"
    private func startButton(_ s: CGFloat) -> some View {
        W8PrimaryButton(title: String(format: "Start · %lld segments".l10n, nav.quick.count), height: 40 * s) {
            let p = store.saveQuick(nav.quick)
            nav.program = p; nav.quick = []; nav.screen = .confirm
        }
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

// MARK: - W2b Confirm (제목 41 · 내용은 52 ~ 버튼 위 (196) 의 가운데 · 버튼 196 ~ 236)

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
    private let sub: Color = Color.white.opacity(0.65)

    var body: some View {
        W8Canvas { L in
            ZStack {
                content(L)
                W8TitleAt(L: L, title: mode == .training ? program.name : mode.name)
                if noEvent {
                } else if mode == .training && (program.isRun || program.isInterval) {
                    runStartButtons(L)
                } else {
                    W8PrimaryButton(title: "Start", icon: "play.fill", height: L.btnH) { start() }
                        .frame(width: L.btnW)
                        .position(x: L.cx, y: L.btnY())
                        .accessibilityIdentifier("w.start")
                }
            }
        }
        .wNavBG(47)
        .sheet(isPresented: $goalSheet) { WGoalPicker() }
    }

    @ViewBuilder
    private func content(_ L: W8Scale) -> some View {
        if mode == .training && program.isOpen {
            openInfo(L)
        } else if mode == .pft {
            pftList(L)
        } else if mode == .training {
            trainingList(L)
        } else if noEvent {
            W8Stack(L: L, parts: [
                .text("No race set up", size: 16, weight: .semibold),
                .view(height: 46, gap: 10, AnyView(
                    Text("Add a race in the Race tab of the iPhone app and it will show up here.")
                        .font(F.t(12 * L.s)).foregroundStyle(sub).multilineTextAlignment(.center)
                        .lineSpacing(2).padding(.horizontal, 18 * L.s)))
            ], top: L.t(52), bottom: L.b(12))
        } else if mode == .race {
            W8Stack(L: L, parts: [
                .text(ev.name, size: 17, weight: .bold),
                .text(small, size: 12, weight: .semibold, color: sub, gap: 8),
                .block(label: goalWord, value: goal, gap: 14)
            ], top: L.t(52), bottom: L.btnTop)
        } else {
            W8Stack(L: L, parts: [
                .text(small, size: 12, weight: .semibold, color: sub),
                .block(label: goalWord, value: goal, word: "TAP TO CHANGE", gap: 14, onTap: { goalSheet = true })
            ], top: L.t(52), bottom: L.btnTop)
            .accessibilityIdentifier("w.simGoal")
        }
    }

    /// 트레이닝: "8 segments · 1 set" (대문자 가운데 60) → 줄 23 씩 (74 부터) — 목록은 버튼 위까지 스크롤
    private func trainingList(_ L: W8Scale) -> some View {
        let s: CGFloat = L.s
        let rows: [Seg] = seq.filter { $0.kind != .rox }
        return ZStack(alignment: .topLeading) {
            Text(String(format: "%lld segments".l10n, seq.count) + " · " + setsLabel)
                .font(F.t(12 * s, .semibold)).foregroundStyle(sub).lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: L.w - 32 * s, alignment: .leading)
                .position(x: L.cx, y: L.t(60))
            rowList(L, rows.map { ($0.icon, $0.name, $0.target > 0 ? Fm.t($0.target) : "–") })
        }
    }

    /// PFT: BEST 21:48 + 등급 배지 (60) → 종목 줄
    private func pftList(_ L: W8Scale) -> some View {
        let s: CGFloat = L.s
        let best: Int? = store.ctx.pftBestTotal
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 6 * s) {
                if let best {
                    Text("BEST").font(F.t(11 * s, .bold)).tracking(0.6).foregroundStyle(sub)
                    Text(Fm.t(best)).font(F.num(15 * s, .semibold)).foregroundStyle(.white)
                } else {
                    Text("6 movements · for time".l10n).font(F.t(12 * s, .semibold)).foregroundStyle(sub)
                }
                Spacer(minLength: 0)
                if let best { PFTBadge(grade: PFT.grade(best), width: 54 * s, height: 18 * s, fontSize: 10 * s) }
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(width: L.w - 32 * s)
            .position(x: L.cx, y: L.t(60))
            rowList(L, seq.map { ($0.icon, $0.name, $0.detail.components(separatedBy: " · ").first ?? $0.detail) })
        }
    }

    /// 줄 23 · 아이콘 14 (x 24) · 이름 14 (x 38) · 오른쪽 값 (끝 16) · 사이 옅은 줄
    private func rowList(_ L: W8Scale, _ rows: [(String, String, String)]) -> some View {
        let s: CGFloat = L.s
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 0) {
                        Icon8(rows[i].0, 14 * s, tint: rows[i].0 == "run" ? .white : .yellow)
                            .frame(width: 14 * s)
                            .padding(.leading, 1 * s)
                        Text(rows[i].1).font(F.t(14 * s, .medium)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .padding(.leading, 7 * s)
                        Spacer(minLength: 4 * s)
                        Text(rows[i].2).font(F.num(14 * s, .medium)).foregroundStyle(sub).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(height: 23 * s)
                    .overlay(alignment: .bottom) {
                        if i < rows.count - 1 { Rectangle().fill(Color.white.opacity(0.09)).frame(height: 0.8 * s) }
                    }
                }
            }
            .padding(.horizontal, 16 * s)
        }
        .frame(width: L.w, height: L.btnTop - L.t(70) - 4 * s)
        .clipped()
        .position(x: L.cx, y: (L.t(70) + L.btnTop - 4 * s) / 2)
    }

    /// 1 set / 3 sets
    private var setsLabel: String {
        program.sets == 1 ? "1 set".l10n : String(format: "%lld sets".l10n, program.sets)
    }

    /// 러닝 카드: [DISTANCE · 5 · KM] → 설명 / HIIT · 18번 새 종류: 아이콘 · 이름 · 설명
    @ViewBuilder
    private func openInfo(_ L: W8Scale) -> some View {
        if program.isRun {
            let km: Int = program.runKm ?? 0
            W8Stack(L: L, parts: [
                .block(label: "DISTANCE", value: km > 0 ? String(format: "%.2f", Double(km)) : "FREE".l10n, word: km > 0 ? "KM" : nil),
                .text(program.kindLine ?? (program.meta ?? "").l10n, size: 12, weight: .semibold, color: sub, gap: 14)
            ], top: L.t(52), bottom: L.btnTop)
        } else {
            W8Stack(L: L, parts: [
                .view(height: 30, AnyView(Icon8(WKind.icon(program.kind), 30 * L.s, tint: .yellow))),
                .text(program.kindLine ?? (program.meta ?? "").l10n, size: 13, weight: .semibold, color: sub, gap: 14)
            ], top: L.t(52), bottom: L.btnTop)
        }
    }

    /// 83번: 러닝은 실외(GPS) / 실내 — 카드에 저장된 쪽이 노란 유리
    private func runStartButtons(_ L: W8Scale) -> some View {
        let cardIndoor: Bool = program.indoor ?? false
        return HStack(spacing: 6 * L.s) {
            runButton(indoor: false, main: !cardIndoor, s: L.s)
            runButton(indoor: true, main: cardIndoor, s: L.s)
        }
        .frame(width: L.btnW, height: L.btnH)
        .position(x: L.cx, y: L.btnY())
    }

    private func runButton(indoor: Bool, main: Bool, s: CGFloat) -> some View {
        Button { start(indoor: indoor) } label: {
            VStack(spacing: 1 * s) {
                Text((indoor ? "Indoor" : "Outdoor").l10n).font(F.t(14 * s, .semibold))
                Text((indoor ? "No GPS" : "GPS").l10n).font(F.t(10 * s, .semibold)).opacity(0.67)
            }
            .foregroundStyle(main ? .black : .white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(W8Glass(shape: Capsule(),
                                fill: main ? Color(hex: 0xFFDC14).opacity(0.84) : Color.white.opacity(0.13),
                                rim: main ? 0.47 : 0.55, gloss: main ? 0.27 : 0))
            .contentShape(Capsule())
        }
        .buttonStyle(W8Press())
        .accessibilityIdentifier(indoor ? "w.startIndoor" : "w.startOutdoor")
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

/// 빌드 27 (68-①): 워치에서 Full Sim 목표 완주 시간 고르기 (크라운으로 1분 단위). 1.2.7: 제목 41 · 휠은 가운데 · Set 은 아래 큰 버튼 자리
struct WGoalPicker: View {
    let store = WatchStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 90

    private static let range: [Int] = Array(45...180)

    var body: some View {
        W8Canvas { L in
            ZStack {
                W8MenuBackground(seed: 59)
                W8TitleAt(L: L, title: "Goal time")
                Picker("", selection: $minutes) {
                    ForEach(Self.range, id: \.self) { v in
                        Text(Fm.t(v * 60)).font(F.num(22 * L.s, .semibold)).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: L.w - 60 * L.s, height: 26 * 3 * L.s)
                .position(x: L.cx, y: (L.t(52) + L.btnTop) / 2 - (store.watchGoal != nil ? 8 * L.s : 0))
                if store.watchGoal != nil {
                    Button {
                        store.watchGoal = nil
                        dismiss()
                    } label: {
                        Text("Use iPhone setting").font(F.t(11 * L.s, .semibold)).foregroundStyle(Color.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .position(x: L.cx, y: L.btnTop - 10 * L.s)
                }
                W8PrimaryButton(title: "Set", height: L.btnH) {
                    store.watchGoal = minutes * 60
                    dismiss()
                }
                .frame(width: L.btnW)
                .position(x: L.cx, y: L.btnY())
            }
        }
        .onAppear {
            let cur: Int = store.watchGoal ?? store.simTargets.reduce(0, +) + 8 * store.settings.roxTarget
            minutes = min(180, max(45, Int((Double(cur) / 60).rounded())))
        }
    }
}
