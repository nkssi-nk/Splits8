import SwiftUI
import Observation

@main
struct Splits8App: App {
    init() { Store.shared.activate() }
    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .preferredColorScheme(.dark)
                .tint(C.accent)
        }
    }
}

enum Scr: String {
    case splash, ob1, ob2, ob3
    case training, builder, sim, race, settings
    case setHr, setDiv, setRun, setGoals, setEvent, friends
    case auth, code, nick, findEvent, account
    case detail, share
}

/// 화면 이동 (시안의 screen 상태와 같은 구조)
@Observable
final class Router {
    static let shared = Router()
    var scr: Scr = Store.shared.settings.hasOnboarded ? .training : .splash
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

    // 만들기 화면
    var editId: String?
    var draftSeq: [ProgItem] = []
    var draftName = ""
    var draftSets = 1
    var saveOpen = false

    func go(_ s: Scr) { withAnimation(.easeInOut(duration: 0.25)) { scr = s } }

    func newTraining() {
        editId = nil; draftName = ""; draftSets = 1
        // 기본: HYROX 순서 16구간
        draftSeq = Station.all.flatMap { [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: $0.key)] }
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
        case .sim: return "Full Simulation"
        default: return "Profile"
        }
    }
}

// MARK: - 화면별 배경 빛

extension Scr {
    var ambient: Ambient {
        switch self {
        case .training: return .y(0.26, 1.2, 0.5, 0.5, 0)
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
        }
    }

    var tab: Scr? {
        switch self {
        case .training, .builder: return .training
        case .sim: return .sim
        case .race, .setEvent, .findEvent: return .race
        case .settings, .setHr, .setGoals, .setDiv, .friends, .setRun, .account: return .settings
        default: return nil
        }
    }

    var showsTabs: Bool {
        [.training, .sim, .race, .settings, .findEvent, .account, .setHr, .setGoals, .setDiv, .setRun, .setEvent, .friends].contains(self)
    }
}

// MARK: - 루트

struct PhoneRoot: View {
    let r = Router.shared

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

            // 상태바 뒤 검은 그라데이션 (시안: linear-gradient(#000 60%, transparent))
            if r.scr != .splash {
                GeometryReader { g in
                    LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .black.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: g.safeAreaInsets.top + 8)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
            }

            if r.scr.showsTabs {
                TabBar8()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                    .ignoresSafeArea(edges: .bottom)
            }

            if r.saveOpen { SaveSheet() }
        }
    }

    @ViewBuilder private var screen: some View {
        switch r.scr {
        case .splash: SplashView()
        case .ob1: Onboarding1()
        case .ob2: Onboarding2()
        case .ob3: Onboarding3()
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
        }
    }
}

/// 세로 스크롤 (탭바 자리 120pt 비움)
struct Scroll8<Content: View>: View {
    var bottom: CGFloat = 120
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            content.padding(.bottom, bottom)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - 떠 있는 탭바

struct TabBar8: View {
    let r = Router.shared
    @Namespace private var ns
    struct Tab: Identifiable { let scr: Scr; let label: String; let icon: String; var id: String { label } }
    private let tabs: [Tab] = [
        Tab(scr: .training, label: "Training", icon: "modeTraining"), Tab(scr: .sim, label: "Simulation", icon: "modeSim"),
        Tab(scr: .race, label: "Race", icon: "modeRace"), Tab(scr: .settings, label: "Settings", icon: "gearTab"),
    ]

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { t in
                let on = r.scr.tab == t.scr
                Button { r.go(t.scr) } label: {
                    VStack(spacing: 3) {
                        Icon8(t.icon, t.scr == .training ? 22 : 21, on ? C.accent : C.text2)
                        Text(t.label).font(F.t(10, .semibold))
                    }
                    .foregroundStyle(on ? C.accent : C.text2)
                    .frame(maxWidth: .infinity).frame(height: 54)
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
        .frame(height: 62)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: r.scr.tab)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: 애플 Liquid Glass (뒤 화면이 굴절돼 비침)
            row
                .glassEffect(.regular.tint(Color.black.opacity(0.6)).interactive(), in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        } else {
            // iOS 17–18: 시안 그대로 (반투명 어두운 캡슐)
            row
                .background(.ultraThinMaterial, in: Capsule())
                .background(Color(hex: 0x161616, alpha: 0.8), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        }
    }
}
