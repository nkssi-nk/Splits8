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
    case home, training, builder, sim, race, settings
    case setHr, setDiv, setRun, setGoals, setEvent, friends
    case auth, code, nick, findEvent, account
    case detail, share
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
        withAnimation(.easeInOut(duration: 0.25)) { scr = s }
    }

    func newTraining() {
        editId = nil; draftName = ""; draftSets = 1
        // 기본: HYROX 순서 앞 8구간 (Run, SkiErg, Run, Sled Push, Run, Sled Pull, Run, BBJ) — 한 세트 최대 8
        let hyrox: [ProgItem] = Station.all.flatMap { [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: $0.key)] }
        draftSeq = Array(hyrox.prefix(8))
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

            // 아이폰처럼 화면 왼쪽 끝에서 오른쪽으로 밀면 뒤로
            if edgeBack != nil && !r.saveOpen {
                Color.clear
                    .frame(width: 22)
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { v in edgeDrag = max(0, v.translation.width) * 0.6 }
                            .onEnded { v in
                                let go = v.translation.width > 80 || v.predictedEndTranslation.width > 200
                                if go, let back = edgeBack {
                                    edgeDrag = 0
                                    back()
                                } else {
                                    withAnimation(.snappy(duration: 0.25)) { edgeDrag = 0 }
                                }
                            }
                    )
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
        }
        .scrollDismissesKeyboard(.interactively)
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
                            Text(b.label).font(F.t(17))
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
                Text(r.barTitle).font(F.t(17, .semibold)).tracking(-0.17).lineLimit(1)
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
                        Text(t.label).font(F.t(11, .semibold)).lineLimit(1).fixedSize()
                    }
                    .foregroundStyle(c)
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
            row
                .glassEffect(.regular.tint(Color(hex: 0x161616, alpha: 0.55)), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        } else {
            row
                .background(.ultraThinMaterial, in: Capsule())
                .background(Color(hex: 0x161616, alpha: 0.8), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        }
    }
}
