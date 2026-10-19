import Foundation
import CoreMotion

/// 스키 · 로잉 · 월볼 횟수 세기 (참고용 짐작값).
/// 워치의 움직임 센서(가속도)로 팔이 한 번 크게 움직일 때마다 하나로 셈.
/// 운동 중 화면에는 보여 주지 않고, 끝난 뒤 아이폰 기록 화면에 "≈ 98" 처럼 참고 숫자로만 나옴.
/// 시간·순위·최고 기록·등급에는 쓰지 않음.
final class RepCounter {
    /// 종목별 기준값 (RepTune, Models.swift). 98번(빌드 28): 아이폰 설정 › 운동 · 측정에서 워치로 20회 보정하면
    /// 그 사람 값(settings.repCal)을 쓰고, 없으면 기본값(RepTune.defaults)
    typealias Tuning = RepTune

    static func tuning(_ icon: String) -> Tuning? {
        WatchStore.shared.settings.repCal?[icon] ?? RepTune.defaults[icon]
    }

    /// 이 종목은 횟수를 세는지
    static func counts(_ icon: String) -> Bool { RepTune.defaults[icon] != nil }

    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "splits8.reps"
        return q
    }()
    private let lock = NSLock()

    // lock 으로 보호
    private var tune: Tuning?
    private var count: Int = 0
    private var level: Double = 0
    private var armed: Bool = true
    private var lastHit: TimeInterval = 0
    private var paused: Bool = false

    /// 그 종목의 횟수 세기를 시작 (세지 않는 종목이면 아무것도 안 하고 멈춤). base = 이어서 셀 때의 시작 값
    func start(icon: String, base: Int = 0) {
        motion.stopDeviceMotionUpdates()
        let t: Tuning? = Self.tuning(icon)
        lock.lock()
        tune = t; count = max(0, base); level = 0; armed = true; lastHit = 0; paused = false
        lock.unlock()
        guard t != nil, motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: queue) { [weak self] m, _ in
            guard let self, let m else { return }
            self.feed(m.userAcceleration, at: m.timestamp)
        }
    }

    /// 일시정지 동안은 세지 않음
    func setPaused(_ p: Bool) {
        lock.lock(); paused = p; if p { level = 0; armed = true }; lock.unlock()
    }

    /// 세기를 멈추고 지금까지 센 횟수를 돌려줌 (세지 않는 종목이었으면 nil)
    @discardableResult
    func stop() -> Int? {
        motion.stopDeviceMotionUpdates()
        lock.lock()
        let out: Int? = tune == nil ? nil : count
        tune = nil
        lock.unlock()
        return out
    }

    private func feed(_ a: CMAcceleration, at t: TimeInterval) {
        let mag: Double = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
        lock.lock()
        defer { lock.unlock() }
        guard let tune, !paused else { return }
        level = tune.smooth * level + (1 - tune.smooth) * mag
        if armed {
            if level >= tune.threshold && (lastHit == 0 || t - lastHit >= tune.minGap) {
                count += 1
                lastHit = t
                armed = false
            }
        } else if level <= tune.release {
            armed = true
        }
    }
}
