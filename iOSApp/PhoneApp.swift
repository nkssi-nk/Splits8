import SwiftUI
import UIKit
import Observation

@main
struct Splits8App: App {
    init() { Store.shared.activate() }
    var body: some Scene {
        WindowGroup {
            LaunchGate {
                PhoneRoot()
            }
            .preferredColorScheme(.dark)
            .tint(C.accent)
        }
    }
}

/// 앱을 새로 켤 때마다(백그라운드에서 돌아올 때는 제외) 가운데 로고를 잠깐 보여 줍니다.
struct LaunchGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var show = !CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--launch")

    var body: some View {
        ZStack {
            content
            if show {
                LaunchLogoView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard show else { return }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeOut(duration: 0.4)) { show = false }
        }
    }
}

enum Scr: String {
    case splash, ob1, ob2, ob3
    case home, training, builder, sim, race, settings
    case setHr, setDiv, setRun, setGoals, setEvent, friends
    case auth, code, nick, findEvent, account
    case detail, share
    case phoneLive          // 워치 없이 아이폰으로 기록 (PhoneLiveView)
}

/// 운동 예약 시트 요청 (달력 날짜 / 홈 UPCOMING 에서 엶)
struct PlanRequest: Equatable {
    var date: Date
    var mode: Mode                     // .training 또는 .sim (기본 선택)
    var existing: PlannedWorkout? = nil
}

/// 아이폰으로 기록 시작 요청
struct PhoneRunRequest: Equatable {
    var mode: Mode
    var program: Program? = nil        // 트레이닝이면 프로그램
    var from: Scr = .home              // 끝나면 / 취소하면 돌아갈 화면
}

/// 화면 이동 (시안의 screen 상태와 같은 구조)
@Observable
final class Router {
    static let shared = Router()
    var scr: Scr = Store.shared.settings.hasOnboarded ? .home : .splash
    var detail: Record?
    var detailFrom: Scr = .race
    /// Division · 심박 화면을 어디서 열었는지 (돌아갈 곳)
    var subFrom: Scr = .account
    var setDivFrom: Scr { get { subFrom } set { subFrom = newValue } }

    // 계정
    var authReturn: Scr = .training     // 가입 끝나면 돌아갈 화면
    var authMode = "signup"             // signup / signin
    var email = ""
    var code = ""
    var nickDraft = ""

    // 대회 편집
    var evDraft: RaceEvent? = nil

    // 운동 예약 시트 (nil 이면 닫힘)
    var planRequest: PlanRequest? = nil
    func openPlan(date: Date, mode: Mode = .training, existing: PlannedWorkout? = nil) {
        planRequest = PlanRequest(date: date, mode: mode, existing: existing)
    }

    // 사진 크게 보기 (nil 이면 닫힘)
    var photoView: PhotoItem? = nil

    // 아이폰으로 기록
    var phoneRun: PhoneRunRequest? = nil
    func startOnPhone(_ mode: Mode, program: Program? = nil) {
        phoneRun = PhoneRunRequest(mode: mode, program: program, from: scr)
        go(.phoneLive)
    }

    // 만들기 화면
    var editId: String?
    var draftSeq: [ProgItem] = []
    var draftName = ""
    var draftSets = 1
    var saveOpen = false

    /// 지금 화면의 "뒤로" 동작 (‹ 버튼이 화면에 뜰 때 등록) — 왼쪽 끝에서 밀어 뒤로 가기에 씀
    var backAction: (() -> Void)?

    func go(_ s: Scr) {
        guard s != scr else { return }
        backAction = nil
        TabBarScroll.shared.reset()
        withAnimation(.easeInOut(duration: 0.25)) { scr = s }
    }

    func newTraining() {
        editId = nil; draftName = ""; draftSets = 1
        // 기본: HYROX 한 바퀴 16구간 (Run 1KM + 스테이션 8개 순서대로) — 한 세트 최대 16
        let hyrox: [ProgItem] = Station.all.flatMap { [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: $0.key)] }
        draftSeq = Array(hyrox.prefix(BuilderView.maxSeq))
        go(.builder)
    }
    func edit(_ p: Program) {
        editId = p.id; draftName = p.name; draftSets = p.sets; draftSeq = p.seq
        go(.builder)
    }
    func open(_ r: Record, from: Scr) {
        detail = r; detailFrom = from; go(.detail)
    }
    func sub(_ s: Scr, from: Scr) { subFrom = from; go(s) }
    func toAuth(from: Scr, mode: String = "signup") {
        authReturn = from; authMode = mode; code = ""; nickDraft = ""; go(.auth)
    }
    var subBackLabel: String {
        switch subFrom {
        case .setEvent: return "Race event"
        case .ob1, .ob2: return "Back"
        case .settings: return "Settings"
        case .race: return "Race"
        case .sim: return "Full Sim"
        case .home: return "Home"
        default: return "Profile"
        }
    }

    // MARK: 위 고정 바 (시안 homeVals: bar · titles · backs)

    /// 고정 바 제목
    var barTitle: String {
        switch scr {
        case .home: return "Home"
        case .training: return "Training"
        case .sim: return "Full Sim"
        case .race: return "Race"
        case .settings: return "Settings"
        case .findEvent: return "Find event"
        case .account: return "Profile"
        case .setHr: return "Max heart rate"
        case .setGoals: return "Split goals"
        case .setDiv: return "Division"
        case .setRun: return "Running"
        case .friends: return "Friends"
        default: return ""
        }
    }
    /// 고정 바 왼쪽 뒤로 (없으면 SPLITS8 워드마크)
    var barBack: (label: String, action: () -> Void)? {
        switch scr {
        case .findEvent: return ("Race event", { self.go(.setEvent) })
        case .account, .setGoals, .setRun, .friends: return ("Settings", { self.go(.settings) })
        case .setDiv, .setHr:
            let to = subFrom == scr ? Scr.account : subFrom
            return (subBackLabel, { self.go(to) })
        default: return nil
        }
    }
}

// MARK: - 화면별 배경 빛

extension Scr {
    var ambient: Ambient {
        switch self {
        case .training: return .y(0.26, 1.2, 0.5, 0.5, 0)
        case .home: return .y(0.24, 1.3, 0.55, 0.5, 0)
        case .ob1: return .y(0.24, 1.2, 0.55, 0.5, 0)
        case .ob2: return Ambient(hex: 0xFF453A, alpha: 0.18, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.3)
        case .ob3: return Ambient(hex: 0x30D158, alpha: 0.16, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.3)
        case .builder: return .y(0.20, 1.1, 0.55, 0.5, 0.08)
        case .sim: return .y(0.20, 1.3, 0.55, 0.5, 0.3)
        case .race: return .y(0.28, 1.3, 0.55, 0.5, 1.0)
        case .settings: return Ambient(hex: 0xFFFFFF, alpha: 0.10, rx: 1.2, ry: 0.5, cx: 0.5, cy: 0)
        case .setHr: return Ambient(hex: 0xFF453A, alpha: 0.20, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.2)
        case .setGoals: return .y(0.18, 1.2, 0.55, 0.5, 0.4)
        case .setDiv: return .y(0.18, 1.2, 0.55, 0.5, 0.2)
        case .setRun: return Ambient(hex: 0x0A84FF, alpha: 0.20, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.2)
        case .setEvent: return .y(0.22, 1.2, 0.55, 0.5, 0.2)
        case .friends: return Ambient(hex: 0x30D158, alpha: 0.16, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.2)
        case .detail: return .y(0.24, 1.3, 0.5, 0.5, 0.1)
        case .share: return .y(0.14, 1.2, 0.55, 0.5, 0.5)
        case .auth: return .y(0.22, 1.2, 0.55, 0.5, 0)
        case .code: return .y(0.18, 1.2, 0.55, 0.5, 0.2)
        case .nick: return Ambient(hex: 0x30D158, alpha: 0.14, rx: 1.2, ry: 0.55, cx: 0.5, cy: 0.2)
        case .findEvent: return .y(0.22, 1.3, 0.5, 0.5, 0)
        case .account: return .y(0.18, 1.2, 0.5, 0.5, 0)
        case .splash: return .none
        case .phoneLive: return .y(0.18, 1.3, 0.5, 0.5, 0)
        }
    }

    var tab: Scr? {
        switch self {
        case .home: return .home
        case .training, .builder: return .training
        case .sim: return .sim
        case .race, .setEvent, .findEvent: return .race
        case .settings, .setHr, .setGoals, .setDiv, .friends, .setRun, .account: return .settings
        default: return nil
        }
    }

    var showsTabs: Bool {
        [.home, .training, .sim, .race, .settings, .findEvent, .account, .setHr, .setGoals, .setDiv, .setRun, .setEvent, .friends].contains(self)
    }
    /// 위 고정 바 (44pt, 반투명 검정 + 흐림, 스크롤해도 제자리)
    var showsBar: Bool {
        [.home, .training, .sim, .race, .settings, .findEvent, .account, .setHr, .setGoals, .setDiv, .setRun, .friends].contains(self)
    }
}

// MARK: - 루트

struct PhoneRoot: View {
    let r = Router.shared
    @State private var edgeDrag: CGFloat = 0

    /// 왼쪽 끝에서 밀어 뒤로: 화면 안 ‹/Cancel 이 등록한 동작, 없으면 고정 바의 뒤로
    private var edgeBack: (() -> Void)? { r.backAction ?? r.barBack?.action }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZStack {
                ForEach([r.scr], id: \.self) { s in
                    AmbientLayer(a: s.ambient).transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: r.scr)

            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(x: edgeDrag)

            // 상태바 뒤 검은 그라데이션 (시안: linear-gradient(#000 60%, transparent), 54px)
            if r.scr != .splash {
                GeometryReader { g in
                    LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .black.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: g.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
            }

            if r.scr.showsBar { TopBar8() }

            // 아이폰처럼 화면 왼쪽 끝에서 오른쪽으로 밀면 뒤로.
            // SwiftUI 제스처는 스크롤 화면이 터치를 먼저 가져가서 안 먹었음 → UIKit 화면 가장자리 제스처로 교체
            // (다른 스크롤 제스처들이 이 제스처가 실패할 때까지 기다리게 해서 가장자리 밀기가 항상 우선)
            EdgeSwipeBack(
                enabled: edgeBack != nil && !r.saveOpen && r.photoView == nil,
                onChanged: { dx in edgeDrag = max(0, dx) * 0.6 },
                onEnded: { dx, vx in
                    let go: Bool = dx > 80 || (dx > 30 && vx > 500)
                    if go, let back = edgeBack {
                        edgeDrag = 0
                        back()
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { edgeDrag = 0 }
                    }
                }
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

            if r.scr.showsTabs {
                TabBar8()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                    .ignoresSafeArea(edges: .bottom)
            }

            if r.saveOpen { SaveSheet() }

            if let p = r.photoView {
                PhotoViewer(item: p)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.2), value: r.photoView)
        .sheet(isPresented: Binding(get: { r.planRequest != nil }, set: { if !$0 { r.planRequest = nil } })) {
            if let req = r.planRequest {
                PlanSheet(request: req)
                    .presentationDetents([.large])
                    .presentationBackground(Color(hex: 0x1C1C1E))
                    .preferredColorScheme(.dark)
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch r.scr {
        case .splash: SplashView()
        case .ob1: Onboarding1()
        case .ob2: Onboarding2()
        case .ob3: Onboarding3()
        case .home: Scroll8 { HomeView() }
        case .training: Scroll8 { TrainingView() }
        case .builder: Scroll8 { BuilderView() }
        case .sim: Scroll8 { SimView() }
        case .race: Scroll8 { RaceView() }
        case .settings: Scroll8 { SettingsView() }
        case .setHr: Scroll8 { SetHrView() }
        case .setDiv: Scroll8 { SetDivView() }
        case .setRun: Scroll8 { SetRunView() }
        case .setGoals: Scroll8 { SetGoalsView() }
        case .setEvent: Scroll8 { SetEventView() }
        case .friends: Scroll8 { FriendsView() }
        case .auth: AuthView()
        case .code: CodeView()
        case .nick: NickView()
        case .findEvent: Scroll8 { FindEventView() }
        case .account: Scroll8 { AccountView() }
        case .detail: Scroll8 { DetailView() }
        case .share: Scroll8(bottom: 40) { ShareView() }
        case .phoneLive: PhoneLiveView()
        }
    }
}

/// 세로 스크롤. 시안 padding: 위 106(고정 바 있음) / 58(없음) — 상태바 54 를 빼면 52 / 4, 아래 120 (탭바 자리)
struct Scroll8<Content: View>: View {
    var bottom: CGFloat = 120
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(.top, Router.shared.scr.showsBar ? 52 : 4)
                .padding(.bottom, bottom)
                .background(alignment: .top) {
                    GeometryReader { g in
                        Color.clear.preference(key: ScrollY8.self, value: -g.frame(in: .named("s8scroll")).minY)
                    }
                    .frame(height: 0)
                }
        }
        .coordinateSpace(name: "s8scroll")
        .onPreferenceChange(ScrollY8.self) { y in TabBarScroll.shared.update(y) }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// 스크롤 위치 (위로 얼마나 올라갔는지, pt)
struct ScrollY8: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 아래 탭 바 접기/펴기: 내용을 아래로 읽어 내려가면(손가락을 위로) 아이콘만, 다시 위로 올리면(손가락을 아래로) 글자까지 펼침
@Observable
final class TabBarScroll {
    static let shared = TabBarScroll()
    var compact = false
    @ObservationIgnored private var last: CGFloat = 0

    func update(_ y: CGFloat) {
        if y < 24 {                       // 맨 위 근처에서는 항상 펼침
            set(false); last = y; return
        }
        let d: CGFloat = y - last
        if d > 8 { set(true); last = y }       // 아래로 읽어 내려감 → 접기
        else if d < -8 { set(false); last = y } // 위로 되돌아감 → 펼치기
    }
    func reset() { last = 0; set(false) }
    private func set(_ v: Bool) {
        guard v != compact else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { compact = v }
    }
}

// MARK: - 위 고정 바

/// 시안: top 54, 44 높이, 좌우 20, rgba(0,0,0,0.55) + blur 20, 아래 1px rgba(255,255,255,0.06).
/// 왼쪽 SPLITS8 (17/800) 또는 노랑 ‹ 뒤로, 오른쪽 제목 17/600
struct TopBar8: View {
    let r = Router.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let b = r.barBack {
                    Button(action: b.action) {
                        HStack(spacing: 2) {
                            Glyph("i_chevL", 22, C.accent)
                            Text(b.label.l10n).font(F.t(17))
                        }
                        .foregroundStyle(C.accent)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, -6)
                    .accessibilityIdentifier("back")
                } else {
                    Wordmark(size: 17, tracking: -0.03)
                }
                Spacer(minLength: 12)
                Text(r.barTitle.l10n).font(F.t(17, .semibold)).tracking(-0.17).lineLimit(1)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(Color.black.opacity(0.55))
                }
                .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 떠 있는 탭바

/// 시안: 20 안쪽, 아래 26, 높이 62 캡슐, rgba(22,22,22,0.8) + blur 20 saturate 180, inset 0.5 rgba(255,255,255,0.1),
/// 그림자 0 8 24 rgba(0,0,0,0.5). 버튼 54 높이, 선택 rgba(255,255,255,0.08). 아이콘 26 · 글자 11/600
struct TabBar8: View {
    let r = Router.shared
    let scroll = TabBarScroll.shared
    @Namespace private var ns
    struct Tab: Identifiable { let scr: Scr; let label: String; let icon: String; var id: String { label } }
    private let tabs: [Tab] = [
        Tab(scr: .home, label: "Home", icon: "i_home"), Tab(scr: .training, label: "Training", icon: "modeTraining"),
        Tab(scr: .sim, label: "Full Sim", icon: "i_sim"), Tab(scr: .race, label: "Race", icon: "i_race"),
        Tab(scr: .settings, label: "Settings", icon: "i_gear"),
    ]

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { t in
                let on = r.scr.tab == t.scr
                let c = on ? C.accent : C.text2
                Button { r.go(t.scr) } label: {
                    VStack(spacing: 2) {
                        if t.icon == "modeTraining" { Icon8(t.icon, 26, c) } else { Glyph(t.icon, 25, c) }
                        if !scroll.compact {   // 아래로 읽어 내려갈 땐 아이콘만, 위로 올리면 글자까지
                            Text(t.label.l10n).font(F.t(11, .semibold)).lineLimit(1).fixedSize()
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .foregroundStyle(c)
                    .frame(maxWidth: .infinity).frame(height: scroll.compact ? 40 : 54)
                    .background {
                        if on {
                            Capsule().fill(Color.white.opacity(0.08))
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab." + t.label)
            }
        }
        .padding(4)
        .frame(height: scroll.compact ? 48 : 62)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: r.scr.tab)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scroll.compact)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            row
                .glassEffect(.regular.tint(Color(hex: 0x161616, alpha: 0.12)), in: Capsule())   // 뒤 화면이 비치도록 아주 옅게
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        } else {
            row
                .background(.ultraThinMaterial, in: Capsule())
                .background(Color(hex: 0x161616, alpha: 0.25), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        }
    }
}

// MARK: - 왼쪽 가장자리 밀어서 뒤로 (UIKit)

/// 창(window)에 UIScreenEdgePanGestureRecognizer 를 하나 붙임.
/// 다른 팬 제스처(스크롤 등)는 이 제스처가 실패해야 시작하므로 가장자리에서 밀면 항상 뒤로 가기가 먼저 잡힘.
struct EdgeSwipeBack: UIViewRepresentable {
    var enabled: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        context.coordinator.host = v
        context.coordinator.attachSoon()
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.recognizer?.isEnabled = enabled
        if context.coordinator.recognizer == nil { context.coordinator.attachSoon() }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let g = coordinator.recognizer { g.view?.removeGestureRecognizer(g) }
        coordinator.recognizer = nil
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: EdgeSwipeBack
        weak var host: UIView?
        var recognizer: UIScreenEdgePanGestureRecognizer?
        private var tries = 0

        init(_ parent: EdgeSwipeBack) { self.parent = parent }

        func attachSoon() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.attach() }
        }

        private func attach() {
            guard recognizer == nil else { return }
            guard let window = host?.window else {
                tries += 1
                if tries < 40 { attachSoon() }
                return
            }
            let g = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handle(_:)))
            g.edges = .left
            g.delegate = self
            g.isEnabled = parent.enabled
            window.addGestureRecognizer(g)
            recognizer = g
        }

        @objc func handle(_ g: UIScreenEdgePanGestureRecognizer) {
            let dx: CGFloat = g.translation(in: g.view).x
            switch g.state {
            case .changed:
                parent.onChanged(dx)
            case .ended:
                parent.onEnded(dx, g.velocity(in: g.view).x)
            case .cancelled, .failed:
                parent.onEnded(0, 0)
            default:
                break
            }
        }

        // 다른 제스처(스크롤 팬 등)는 가장자리 제스처가 실패할 때까지 기다림
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 탭(버튼)은 그대로, 끌기(스크롤·드래그) 제스처만 기다리게 함
            guard otherGestureRecognizer is UIPanGestureRecognizer else { return false }
            return !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer)
        }
    }
}
