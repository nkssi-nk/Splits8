import SwiftUI
import HealthKit
import WatchConnectivity

// MARK: - 98번(빌드 28): 설정 › 운동 · 측정
// 러닝(장소) · 횟수 보정(스키 · 로잉 · 월볼) · 심박 · 진동을 한 곳에. 예전엔 설정 첫 화면에 '러닝' 한 줄과 '진동' 칸이 따로 있었음

struct SetWorkoutView: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "RUNNING", top: 4)
            VStack(spacing: 0) {
                SettingRow(title: "Running place", value: RunModes.name(store.settings.runMode), last: true) {
                    r.sub(.setRun, from: .setWorkout)
                }
                .accessibilityIdentifier("workout.running")
            }
            .card8()
            Note8(text: "Run cards ask Outdoor or Indoor when you start on the watch. Indoors there is no GPS, so distance is estimated from arm motion. A few outdoor runs with GPS make indoor distance more accurate.")

            SectionLabel(text: "REP COUNT CALIBRATION", top: 14)
            VStack(spacing: 0) {
                ForEach(Array(RepTune.icons.enumerated()), id: \.offset) { i, icon in
                    calRow(icon, last: i == RepTune.icons.count - 1)
                }
            }
            .card8()
            Note8(text: "Do 20 reps with your watch and counting fits your own movement.")

            SectionLabel(text: "HEART RATE", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Max heart rate", value: "\(store.settings.maxHR) BPM", numeric: true, last: true) {
                    r.sub(.setHr, from: .setWorkout)
                }
                .accessibilityIdentifier("workout.hr")
            }
            .card8()

            SectionLabel(text: "VIBRATION", top: 14)
            VStack(spacing: 0) {
                toggleRow("Heart rate zone change", sub: nil, on: zoneBinding, last: false)
                    .accessibilityIdentifier("settings.hapticZone")
                toggleRow("Behind target pace", sub: "Race · Full Sim", on: paceBinding, last: true)
                    .accessibilityIdentifier("settings.hapticPace")
            }
            .card8()
            Note8(text: "Apple Watch alerts you with a vibration during workouts.")
        }
        .padding(.horizontal, 16)
    }

    /// 종목 이름 · 오른쪽 상태(기본값 / 보정됨 · 날짜)
    private func calRow(_ icon: String, last: Bool) -> some View {
        let tune: RepTune? = store.settings.repCal?[icon]
        let value: String = tune?.date.map { String(localized: "Calibrated · \(Fm.dm.string(from: $0))") } ?? "Default".l10n
        return Button {
            r.calibIcon = icon
            r.go(.setCalib)
        } label: {
            HStack(spacing: 12) {
                Text(CalibText.name(icon)).font(F.t(17)).frame(maxWidth: .infinity, alignment: .leading)
                Text(value).font(F.t(15)).foregroundStyle(tune == nil ? C.text2 : C.good).lineLimit(1).fixedSize()
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("workout.cal." + icon)
    }

    private var zoneBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticZone }, set: { store.settings.hapticZone = $0 })
    }
    private var paceBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticPace }, set: { store.settings.hapticPace = $0 })
    }

    private func toggleRow(_ title: String, sub: String?, on: Binding<Bool>, last: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.l10n).font(F.t(17)).lineLimit(1)
                if let sub { Text(sub.l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle8(on: on)
        }
        .padding(.vertical, sub == nil ? 10 : 11).padding(.horizontal, 18)
        .rowLine(!last)
    }
}

/// 종목 이름 · 안내 글
enum CalibText {
    static func name(_ icon: String) -> String {
        ["skiErg": "SkiErg", "row": "Row", "wallBalls": "Wall Balls"][icon] ?? icon
    }
    /// "월볼 20개를" / "스키 20번 당기기를"
    static func task(_ icon: String) -> String {
        icon == "wallBalls" ? "Do 20 wall balls as usual" : (icon == "row" ? "Do 20 row strokes as usual" : "Do 20 SkiErg pulls as usual")
    }
}

// MARK: - 종목 보정 (안내 + 워치에서 시작)

struct SetCalibView: View {
    /// 워치 앱 켜기 요청이 끝날 때까지 살아 있게 하나만 둠
    private static let health = HKHealthStore()
    let store = Store.shared
    let r = Router.shared
    @State private var sent = false
    @State private var askReset = false

    private var icon: String { r.calibIcon }

    var body: some View {
        let tune: RepTune? = store.settings.repCal?[icon]
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "CALIBRATE · \(CalibText.name(icon).uppercased())"))
                    .font(F.t(12, .semibold)).tracking(0.9).foregroundStyle(C.accent)
                Text(CalibText.task(icon).l10n).font(F.t(26, .bold)).tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Text("We measure how hard your arm moves on each rep and set counting to match you.".l10n)
                    .font(F.t(15)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
                if let d = tune?.date {
                    Text(String(localized: "Calibrated · \(Fm.dm.string(from: d))")).font(F.t(13, .semibold)).foregroundStyle(C.good)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .card8()

            SectionLabel(text: "HOW", top: 14)
            VStack(spacing: 0) {
                step(1, "Tap the button below. The calibration screen opens on your watch.")
                step(2, "Start on the watch, then do exactly 20.")
                step(3, "Tap Done and confirm how many you did. That's it.", last: true)
            }
            .card8()
            Note8(text: "Wear the watch on the wrist that moves. You can redo it or go back to default anytime.")

            Button { start() } label: {
                Text((sent ? "Sent to watch" : "Start on watch").l10n).font(F.t(17, .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(Press())
            .padding(.top, 10)
            .accessibilityIdentifier("calib.start")
            if sent {
                Note8(text: "If nothing shows on the watch, open SPLITS8 on the watch.", color: C.text2)
            }

            if tune != nil {
                Button { askReset = true } label: {
                    Text("Reset to default".l10n).font(F.t(17, .semibold)).foregroundStyle(C.bad)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .card8(14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(Press())
                .padding(.top, 6)
                .accessibilityIdentifier("calib.reset")
            }
        }
        .padding(.horizontal, 16)
        .alert("Reset to default?".l10n, isPresented: $askReset) {
            Button("Reset".l10n, role: .destructive) {
                var m: [String: RepTune] = store.settings.repCal ?? [:]
                m[icon] = nil
                store.settings.repCal = m.isEmpty ? nil : m
                store.pushToWatch()
            }
            Button("Cancel".l10n, role: .cancel) {}
        }
    }

    private func step(_ n: Int, _ t: String, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(F.t(13, .bold)).foregroundStyle(.black)
                .frame(width: 24, height: 24).background(C.accent, in: Circle())
            Text(t.l10n).font(F.t(15)).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .rowLine(!last)
    }

    /// 워치 앱을 켜서 보정 화면으로 (운동 종류로 종목을 알림) + 켜져 있으면 메시지, 아니면 다음에 켤 때 받게 userInfo
    private func start() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sent = true
        let cfg = HKWorkoutConfiguration()
        switch icon {
        case "skiErg": cfg.activityType = .crossCountrySkiing
        case "row": cfg.activityType = .rowing
        default: cfg.activityType = .functionalStrengthTraining
        }
        cfg.locationType = .indoor
        if HKHealthStore.isHealthDataAvailable() {
            Self.health.startWatchApp(with: cfg) { _, _ in }
        }
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage([SyncKey.calib: icon], replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo([SyncKey.calib: icon, "at": Date().timeIntervalSince1970])
        }
    }
}
