import SwiftUI
import HealthKit
import CoreLocation

// MARK: - 가입·온보딩 공통 틀

/// 시안: 스크롤 영역 padding 58(위, 상태바 54 포함) · 120(아래), 안쪽 div 는 padding 0 24 · min-height 100%.
/// 안전 영역 기준으로 위 4 · 아래 (120 − 아래 안전 영역). 키보드가 떠 있으면 아래 여백 없이 키보드 바로 위까지.
/// 내용이 길면 스크롤 (온보딩 1 체급 목록).
struct Page8<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { g in
            let bottom = bottomPad(g.safeAreaInsets.bottom)
            let minH = max(0, g.size.height - 4 - bottom)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) { content }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: minH, alignment: .top)
                    .padding(.top, 4)
                    .padding(.bottom, bottom)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func bottomPad(_ inset: CGFloat) -> CGFloat {
        // 키보드가 올라오면 inset 이 커짐 → 버튼이 키보드 바로 위에 붙도록 0
        if inset > 80 { return 0 }
        return max(0, 120 - inset)
    }
}

/// h1 아래 회색 설명 (15, #8E8E93, 줄간 1.45)
struct PageSub: View {
    let text: String
    var body: some View {
        Text(text.l10n).font(F.t(15)).foregroundStyle(C.text2).lineSpacing(15 * 0.45 - 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - I0 Launch

struct SplashView: View {
    let r = Router.shared
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { g in
                Image("splash").resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height, alignment: Alignment(horizontal: .center, vertical: .splashFocus))
                    .clipped()
            }
            .ignoresSafeArea()
            LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.3),
                                   .init(color: .clear, location: 0.45), .init(color: .black.opacity(0.92), location: 0.78)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { r.go(.ob1) }      // 시안: 화면 아무 곳이나 누르면 온보딩
            bottomBlock
                .padding(.horizontal, 28).padding(.bottom, 30)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var bottomBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("8 RUNS · 8 STATIONS").font(F.t(11, .semibold)).tracking(0.28 * 11).foregroundStyle(C.accent)
            Wordmark(size: 72)   // 로고 이미지 (시안 v4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Every run. Every station. Every second on your wrist.")
                .font(F.t(15)).lineSpacing(15 * 0.45 - 3).foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: 300, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            YellowButton(action: { r.go(.ob1) }) { Text("Get started") }
                .padding(.top, 10)
                .accessibilityIdentifier("splash.start")
            HStack(spacing: 0) {
                Text("Have an account? ").foregroundStyle(.white.opacity(0.7))
                Button { r.toAuth(from: .ob1, mode: "signin") } label: {
                    Text("Sign in").font(F.t(15, .semibold)).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("splash.signin")
            }
            .font(F.t(15))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 앱 켤 때 로고 (시작 화면 사진 + 가운데 SPLITS8, 버튼 없음)

struct LaunchLogoView: View {
    @State private var appear = false
    var body: some View {
        ZStack {
            Color.black
            GeometryReader { g in
                Image("splash").resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height, alignment: Alignment(horizontal: .center, vertical: .splashFocus))
                    .clipped()
            }
            Color.black.opacity(0.5)
            LinearGradient(stops: [.init(color: .black.opacity(0.4), location: 0), .init(color: .clear, location: 0.35),
                                   .init(color: .clear, location: 0.6), .init(color: .black.opacity(0.85), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            Wordmark(size: 56, tracking: -0.03)
                .scaleEffect(appear ? 1 : 0.94)
                .opacity(appear ? 1 : 0)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .accessibilityIdentifier("launch.logo")
        .onAppear { withAnimation(.easeOut(duration: 0.35)) { appear = true } }
    }
}

/// 사진 초점 (CSS background-position center 30%)
private extension VerticalAlignment {
    enum SplashFocus: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d.height * 0.3 }
    }
    static let splashFocus = VerticalAlignment(SplashFocus.self)
}

// MARK: - 온보딩 공통

struct ObFrame<Content: View>: View {
    let step: Int
    let title: String
    let sub: String
    let button: String
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Page8(spacing: 10) {
            header
            LargeTitle(text: title, top: 10)
            PageSub(text: sub).padding(.bottom, 10)
            content
            Spacer(minLength: 0)
            YellowButton(action: action) { Text(button.l10n) }
                .padding(.bottom, 14)
                .accessibilityIdentifier("ob.next")
        }
        .onAppear {
            // 왼쪽 끝에서 밀면 이전 단계로
            let prev: Scr = step == 1 ? .splash : step == 2 ? .ob1 : .ob2
            Router.shared.backAction = { Router.shared.go(prev) }
        }
    }

    /// 점 3개 (선택 22×6 노랑, 나머지 6×6 #2C2C2E) · "1 / 3" 13/600 자간 0.1em
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(n == step ? C.accent : C.control)
                        .frame(width: n == step ? 22 : 6, height: 6)
                }
            }
            Spacer()
            Text("\(step) / 3").font(F.t(13, .semibold)).tracking(0.1 * 13).foregroundStyle(C.text2).lineLimit(1)
        }
        .frame(height: 44)
    }
}

// MARK: - I0a Division (Settings › Division 과 같은 목록)

/// 시안 divRows: 이름 17 (선택 600 / 400), 스펙 13 회색 고정폭 숫자, 노란 체크 (온보딩 20 · 설정 18)
struct DivisionList: View {
    let store = Store.shared
    var checkSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Division.all.enumerated()), id: \.offset) { i, d in
                row(d, last: i == Division.all.count - 1)
            }
        }
        .card8()
    }

    private func row(_ d: Division, last: Bool) -> some View {
        let on = store.settings.division == d.key
        return Button { store.settings.division = d.key } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(F.t(17, on ? .semibold : .regular)).foregroundStyle(.white)
                    Text(d.spec).font(F.num(13, .regular)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if on { Check8(size: checkSize) }
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("div." + d.key)
    }
}

struct Onboarding1: View {
    var body: some View {
        ObFrame(step: 1, title: "Your division", sub: "This sets your default weights and reps. You can change it anytime in Settings.",
                button: "Continue", action: { Router.shared.go(.ob2) }) {
            DivisionList(checkSize: 20)
        }
    }
}

// MARK: - I0b Heart rate zones

struct Onboarding2: View {
    let store = Store.shared

    var body: some View {
        let s = store.settings
        ObFrame(step: 2, title: "Heart rate zones", sub: "Z1–Z5 are calculated from your max heart rate. Heart rate colors on your watch follow these ranges.",
                button: "Continue", action: { Router.shared.go(.ob3) }) {
            Seg8(items: [("age", "By age"), ("manual", "Manual")], selected: s.hrMode) { store.settings.hrMode = $0 }
            inputCard
            HStack {
                Text("Max heart rate").font(F.t(13)).foregroundStyle(C.text2)
                Spacer()
                Text("\(s.maxHR) BPM").font(F.num(15)).lineLimit(1)
            }
            .padding(.horizontal, 4)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in Rectangle().fill(C.zones[i]) }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    /// AGE / 32 (44/600, 자간 −0.03em) · − (rgba 255 0.14) + (노란 유리) 44 원
    private var inputCard: some View {
        let s = store.settings
        let age = s.hrMode == "age"
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label8(age ? "AGE" : "MAX HEART RATE")
                Text("\(age ? s.age : s.manualHr)").font(F.num(44)).tracking(-0.03 * 44).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { bump(-1) } label: {
                    Text("−").font(F.t(20)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.14), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(Press(scale: 0.94))
                .accessibilityIdentifier("hr.down")
                Button { bump(1) } label: {
                    Text("+").font(F.t(20)).foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .yellowCapsule()
                }
                .buttonStyle(Press(scale: 0.94))
                .accessibilityIdentifier("hr.up")
            }
        }
        .padding(.vertical, 18).padding(.horizontal, 20)
        .card8()
    }

    private func bump(_ v: Int) {
        if store.settings.hrMode == "age" { store.settings.age += v } else { store.settings.manualHr += v }
    }
}

// MARK: - I0c Connect Apple Watch

struct Onboarding3: View {
    let store = Store.shared
    @State private var granted = false
    @State private var loc = CLLocationManager()

    var body: some View {
        ObFrame(step: 3, title: "Connect Apple Watch",
                sub: "Workouts and heart rate are measured on Apple Watch. Please allow access to Health data.",
                button: granted ? "Start training" : "Allow & connect", action: tap) {
            VStack(spacing: 0) {
                perm("i_permWatch", "Apple Watch", granted ? "Connected" : "Tap Allow to pair", last: false)
                perm("i_permHealth", "Health data", granted ? "Allowed · heart rate, workouts" : "Heart rate, workouts, distance", last: false)
                perm("i_permLoc", "Location", granted ? "Allowed · outdoor runs" : "Outdoor run pace (optional)", last: true)
            }
            .card8()
            Note8(text: "No account needed. Records are saved only on this device and in iCloud.")
        }
    }

    /// 36 사각 (radius 10, 허용 전 #2C2C2E / 후 초록 0.15) · 이름 17/500 · 설명 13 회색 · 초록 체크 20
    private func perm(_ icon: String, _ name: String, _ sub: String, last: Bool) -> some View {
        HStack(spacing: 14) {
            Glyph(icon, 18, granted ? C.good : .white)
                .frame(width: 36, height: 36)
                .background(granted ? C.good.opacity(0.15) : C.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(name.l10n).font(F.t(17, .medium))
                Text(sub.l10n).font(F.t(13)).foregroundStyle(C.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if granted { Check8(color: C.good, size: 20) }
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .rowLine(!last)
    }

    private func tap() {
        if granted {
            store.settings.hasOnboarded = true
            Router.shared.go(.home)
            return
        }
        let hs = HKHealthStore()
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
                                       HKQuantityType(.distanceWalkingRunning), HKObjectType.workoutType()]
        hs.requestAuthorization(toShare: [HKObjectType.workoutType()], read: read) { _, _ in
            DispatchQueue.main.async {
                loc.requestWhenInUseAuthorization()
                withAnimation { granted = true }
            }
        }
    }
}
