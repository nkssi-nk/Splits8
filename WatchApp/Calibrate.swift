import SwiftUI
import CoreMotion
import HealthKit
import WatchKit
import WatchConnectivity
import Observation

// MARK: - 98번(빌드 28): 횟수 보정 (스키 · 로잉 · 월볼)
// 아이폰 설정 › 운동 · 측정 › 종목 › "워치에서 시작" → 워치 앱이 켜지며 이 화면.
// 평소처럼 20회 → 끝 → 실제 개수 확인 → 그 사람 동작에 맞는 기준값(RepTune.fit)을 찾아 저장 · 아이폰으로 보냄.
// 화면이 꺼져도 센서를 계속 받으려고 운동 세션을 켜 두지만 건강 앱에는 아무것도 저장하지 않음.

@Observable
final class Calib: NSObject, HKWorkoutSessionDelegate {
    static let shared = Calib()

    enum Phase { case ready, counting, confirm, saved }

    /// 보정할 종목 아이콘 (nil = 보정 화면 아님)
    var icon: String?
    var phase: Phase = .ready
    /// 지금 기준으로 센 횟수 (참고용으로 화면에 보여 줌)
    var live: Int = 0
    /// 실제로 한 개수 (끝난 뒤 크라운으로 맞춤)
    var actual: Int = 20
    /// 저장된 새 기준 (끝 화면에 보여 줌)
    var saved: RepTune?

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private let queue: OperationQueue = {
        let q = OperationQueue(); q.maxConcurrentOperationCount = 1; q.name = "splits8.calib"; return q
    }()
    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private var mags: [Double] = []
    @ObservationIgnored private var times: [Double] = []
    @ObservationIgnored private var level: Double = 0
    @ObservationIgnored private var armed = true
    @ObservationIgnored private var lastHit: Double = -1000
    @ObservationIgnored private let health = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?

    /// 아이폰이 보낸 요청: 보정 화면을 띄움 (운동 중이면 무시)
    func request(_ icon: String, keepAwake: Bool = false) {
        guard RepTune.defaults[icon] != nil, !WorkoutEngine.shared.active else { return }
        if self.icon == icon && phase != .saved { return }
        self.icon = icon
        phase = .ready; live = 0; actual = 20; saved = nil
        // 아이폰이 워치 앱을 켜 준 경우: 바로 세션을 켜야 함(안 켜면 워치가 기다리다 취소) — 세기는 시작을 눌러야
        if keepAwake { startSession(icon) }
    }

    /// 아이폰이 워치 앱을 켜면서 넘긴 운동 종류로 종목을 알아냄
    static func icon(for type: HKWorkoutActivityType) -> String? {
        switch type {
        case .crossCountrySkiing: return "skiErg"
        case .rowing: return "row"
        case .functionalStrengthTraining: return "wallBalls"
        default: return nil
        }
    }

    static func activity(for icon: String) -> HKWorkoutActivityType {
        switch icon {
        case "skiErg": return .crossCountrySkiing
        case "row": return .rowing
        default: return .functionalStrengthTraining
        }
    }

    static func name(_ icon: String) -> String {
        ["skiErg": "SkiErg", "row": "Row", "wallBalls": "Wall Balls"][icon] ?? icon
    }

    // MARK: 세기

    func begin() {
        guard let icon, let tune = RepCounter.tuning(icon) else { return }
        lock.lock(); mags = []; times = []; level = 0; armed = true; lastHit = -1000; lock.unlock()
        live = 0
        phase = .counting
        startSession(icon)
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: queue) { [weak self] m, _ in
            guard let self, let m else { return }
            let a = m.userAcceleration
            let mag: Double = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            self.lock.lock()
            if self.mags.count < 50 * 60 * 8 {          // 8분까지만 (메모리 보호)
                self.mags.append(mag); self.times.append(m.timestamp)
            }
            // 화면용: 지금 기준으로 센 숫자
            self.level = tune.smooth * self.level + (1 - tune.smooth) * mag
            var hit = false
            if self.armed {
                if self.level >= tune.threshold && m.timestamp - self.lastHit >= tune.minGap {
                    self.lastHit = m.timestamp; self.armed = false; hit = true
                }
            } else if self.level <= tune.release {
                self.armed = true
            }
            self.lock.unlock()
            if hit { DispatchQueue.main.async { self.live += 1 } }
        }
    }

    /// 끝: 실제 개수 확인 화면으로 (기본값 = 20)
    func stop() {
        motion.stopDeviceMotionUpdates()
        actual = 20
        phase = .confirm
        WKInterfaceDevice.current().play(.stop)
    }

    /// 실제 개수로 기준을 찾아 저장하고 아이폰으로 보냄
    func save() {
        guard let icon else { return }
        lock.lock(); let m = mags, t = times; lock.unlock()
        endSession()
        guard let tune = RepTune.fit(icon: icon, mags: m, times: t, actual: actual) else {
            saved = nil; phase = .saved; return
        }
        saved = tune
        WatchStore.shared.applyCalibration(icon: icon, tune: tune)
        phase = .saved
        WKInterfaceDevice.current().play(.success)
    }

    /// 닫기 (언제든). 세션 · 센서 정리, 저장 안 함
    func close() {
        motion.stopDeviceMotionUpdates()
        endSession()
        icon = nil; phase = .ready; live = 0; saved = nil
    }

    // MARK: 화면이 꺼져도 앱이 멈추지 않게 운동 세션만 켬 (기록 · 건강 앱 저장 없음)

    private func startSession(_ icon: String) {
        guard session == nil else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = Self.activity(for: icon)
        cfg.locationType = .indoor
        guard let s = try? HKWorkoutSession(healthStore: health, configuration: cfg) else { return }
        s.delegate = self
        session = s
        s.startActivity(with: Date())
    }

    private func endSession() {
        session?.end()
        session = nil
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

/// 아이폰의 "워치에서 시작"(HKHealthStore.startWatchApp)으로 워치 앱이 켜질 때 받는 곳
final class WDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        guard let icon = Calib.icon(for: workoutConfiguration.activityType) else { return }
        DispatchQueue.main.async { Calib.shared.request(icon, keepAwake: true) }
    }
}

// MARK: - 보정 화면

struct WCalibView: View {
    @Bindable var c = Calib.shared

    var body: some View {
        let icon: String = c.icon ?? "wallBalls"
        let unit: String = icon == "wallBalls" ? "reps".l10n : "pulls".l10n
        VStack(spacing: 4) {
            HStack {
                Text("Calibrate".l10n + " · " + Calib.name(icon))
                    .font(F.t(13, .semibold)).foregroundStyle(C.accent).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                // 언제든 닫기 (세는 중이어도 — 센서 · 세션 정리, 저장 안 함)
                Button { c.close() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(C.text2)
                        .frame(width: 26, height: 26).background(Color(hex: 0x262626), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("w.calib.close")
            }
            switch c.phase {
            case .ready:
                Text(String(format: "Do 20 %@ as usual, then tap Done.".l10n, unit))
                    .font(F.t(14)).foregroundStyle(C.text2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 6)
                bigButton("Start", color: C.accent) { c.begin() }
                    .accessibilityIdentifier("w.calib.start")
            case .counting:
                Text(String(format: "Do 20 %@, then tap Done".l10n, unit)).font(F.t(12)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(c.live)").font(F.num(64)).tracking(-2).lineLimit(1).minimumScaleFactor(0.6)
                    Text("/ 20").font(F.num(20)).foregroundStyle(C.text2)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                bigButton("Done", color: C.accent) { c.stop() }
                    .accessibilityIdentifier("w.calib.done")
            case .confirm:
                Text("How many did you do?").font(F.t(13)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $c.actual) {
                    ForEach(1...60, id: \.self) { n in Text("\(n)").font(F.num(28)).tag(n) }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: .infinity)
                bigButton("Save", color: C.good) { c.save() }
                    .accessibilityIdentifier("w.calib.save")
            case .saved:
                VStack(alignment: .leading, spacing: 6) {
                    if c.saved != nil {
                        Text("Saved").font(F.t(22, .semibold)).foregroundStyle(C.good)
                        Text("Counting now fits your movement. You can redo it anytime from the iPhone.")
                            .font(F.t(13)).foregroundStyle(C.text2)
                    } else {
                        Text("Not enough movement").font(F.t(18, .semibold))
                        Text("Try again from the iPhone and keep the watch on the hand that moves.")
                            .font(F.t(13)).foregroundStyle(C.text2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 6)
                bigButton("Close", color: Color(hex: 0x262626), dark: false) { c.close() }
                    .accessibilityIdentifier("w.calib.finish")
            }
        }
        .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 6)
    }

    private func bigButton(_ t: String, color: Color, dark: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t.l10n).font(F.t(15, .semibold)).foregroundStyle(dark ? .black : .white)
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(color, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
