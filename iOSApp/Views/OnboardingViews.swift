import SwiftUI
import HealthKit
import CoreLocation
import WatchConnectivity

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
            VStack(alignment: .leading, spacing: 14) {
                Text("8 RUNS · 8 STATIONS").font(F.t(16, .bold)).tracking(4.48).foregroundStyle(C.accent)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("SPLITS").foregroundStyle(.white)
                    Text("8").foregroundStyle(C.accent).padding(.leading, 8)
                }
                .font(.system(size: 72, weight: .heavy)).tracking(-2.16)
                .lineLimit(1).minimumScaleFactor(0.8)
                Text("Every run. Every station. Every second on your wrist.")
                    .font(F.t(15)).lineSpacing(15 * 0.45 - 3).foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: 300, alignment: .leading)
                YellowButton(action: { r.go(.ob1) }) {
                    Text("Get started").font(F.t(16, .semibold))
                }
                .padding(.top, 10)
                HStack(spacing: 4) {
                    Text("Have an account?").foregroundStyle(.white.opacity(0.7))
                    Button("Sign in") { r.toAuth(from: .ob1, mode: "signin") }
                        .fontWeight(.semibold).foregroundStyle(.white).buttonStyle(.plain)
                }
                .font(F.t(14))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 28).padding(.bottom, 30)
        }
    }
}

/// 사진 초점 (CSS object-position 50% 30%)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { n in
                        RoundedRectangle(cornerRadius: 3).fill(n == step ? C.accent : C.control)
                            .frame(width: n == step ? 22 : 6, height: 6)
                    }
                }
                Spacer()
                Text("\(step) / 3").font(F.t(12, .semibold)).tracking(1.2).foregroundStyle(C.text2)
            }
            .frame(height: 44)
            Text(title).font(F.t(34, .bold)).tracking(-1.02).padding(.top, 10)
            Text(sub).font(F.t(15)).foregroundStyle(C.text2).lineSpacing(15 * 0.45 - 3).padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
            YellowButton(action: action) { Text(button).font(F.t(16, .semibold)) }
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // 왼쪽 끝에서 밀면 이전 단계로
            let prev: Scr = step == 1 ? .splash : step == 2 ? .ob1 : .ob2
            Router.shared.backAction = { Router.shared.go(prev) }
        }
    }
}

// MARK: - I0a Division

struct DivisionList: View {
    let store = Store.shared
    var checkSize: CGFloat = 20
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Division.all.enumerated()), id: \.offset) { i, d in
                let on = store.settings.division == d.key
                Button { store.settings.division = d.key } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.name).font(F.t(16, on ? .semibold : .regular))
                            Text(d.spec).font(F.t(12)).monospacedDigit().foregroundStyle(C.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if on { Check8(size: checkSize) }
                    }
                    .padding(.vertical, 14).padding(.horizontal, 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowLine(i < Division.all.count - 1)
            }
        }
        .card8()
    }
}

struct Onboarding1: View {
    var body: some View {
        ObFrame(step: 1, title: "Your division", sub: "무게와 횟수의 기본값이 됩니다. Settings에서 언제든 바꿀 수 있어요.",
                button: "Continue", action: { Router.shared.go(.ob2) }) {
            ScrollView(showsIndicators: false) { DivisionList() }
        }
    }
}

// MARK: - I0b Heart rate zones

struct Onboarding2: View {
    let store = Store.shared
    var body: some View {
        let s = store.settings
        ObFrame(step: 2, title: "Heart rate zones", sub: "최대 심박을 기준으로 Z1–Z5를 계산합니다. 워치의 심박 색이 이 범위를 따라요.",
                button: "Continue", action: { Router.shared.go(.ob3) }) {
            Seg8(items: [("age", "By age"), ("manual", "Manual")], selected: s.hrMode) { store.settings.hrMode = $0 }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label8(s.hrMode == "age" ? "AGE" : "MAX HEART RATE")
                    Text("\(s.hrMode == "age" ? s.age : s.manualHr)").font(F.num(44)).tracking(-1.32)
                }
                Spacer()
                HStack(spacing: 8) {
                    round("−", bg: Color.white.opacity(0.14), fg: .white) { bump(-1) }
                    round("+", bg: C.accent, fg: .black) { bump(1) }
                }
            }
            .padding(.vertical, 18).padding(.horizontal, 20)
            .card8()
            HStack {
                Text("Max heart rate").font(F.t(13)).foregroundStyle(C.text2)
                Spacer()
                Text("\(s.maxHR) BPM").font(F.t(15, .semibold)).monospacedDigit()
            }
            .padding(.horizontal, 4)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in Rectangle().fill(C.zones[i]) }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func bump(_ v: Int) {
        if store.settings.hrMode == "age" { store.settings.age += v } else { store.settings.manualHr += v }
    }
    private func round(_ t: String, bg: Color, fg: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(F.t(22)).foregroundStyle(fg).frame(width: 44, height: 44).background(bg, in: Circle())
        }
        .buttonStyle(Press(scale: 0.94))
    }
}

// MARK: - I0c Connect Apple Watch

struct Onboarding3: View {
    let store = Store.shared
    @State private var granted = false
    @State private var loc = CLLocationManager()

    var body: some View {
        ObFrame(step: 3, title: "Connect Apple Watch",
                sub: "운동 기록과 심박은 Apple Watch에서 측정합니다. 건강 데이터 접근을 허용해 주세요.",
                button: granted ? "Start training" : "Allow & connect", action: tap) {
            VStack(spacing: 0) {
                perm("permWatch", "Apple Watch", granted ? "Connected" : "Tap Allow to pair", last: false)
                perm("permHeart", "Health data", granted ? "Allowed · heart rate, workouts" : "Heart rate, workouts, distance", last: false)
                perm("permLoc", "Location", granted ? "Allowed · outdoor runs" : "Outdoor run pace (optional)", last: true)
            }
            .card8()
            Text("계정은 필요 없습니다. 기록은 이 기기와 iCloud에만 저장돼요.")
                .font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6).padding(.horizontal, 4)
        }
    }

    private func perm(_ icon: String, _ name: String, _ sub: String, last: Bool) -> some View {
        HStack(spacing: 14) {
            Icon8(icon, 18, granted ? C.good : .white)
                .frame(width: 36, height: 36)
                .background(granted ? C.good.opacity(0.15) : C.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(F.t(16, .medium))
                Text(sub).font(F.t(12)).foregroundStyle(C.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if granted { Check8(color: C.good) }
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .rowLine(!last)
    }

    private func tap() {
        if granted {
            store.settings.hasOnboarded = true
            Router.shared.go(.training)
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
