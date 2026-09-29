import Foundation
import HealthKit
import WatchKit
import CoreLocation
import Observation

/// 워치 운동 진행: HealthKit 세션(심박·칼로리·거리) + 구간 타이머
@Observable
final class WorkoutEngine: NSObject {
    static let shared = WorkoutEngine()

    let health = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private let location = CLLocationManager()

    var settings = Settings()

    private(set) var active = false
    private(set) var finished = false
    private(set) var mode: Mode = .race
    private(set) var title = ""
    private(set) var sets = 1
    private(set) var seq: [Seg] = []
    private(set) var idx = 0
    private(set) var splits: [Int] = []
    private(set) var running = true
    private(set) var lastRecord: Record?

    // 측정값
    private(set) var hr: Double = 0
    private(set) var kcal: Double = 0
    private(set) var distance: Double = 0          // 누적 m
    @ObservationIgnored private var hrSamples: [HRPoint] = []
    @ObservationIgnored private var segHR: [[Double]] = []
    @ObservationIgnored private var segDistStart: Double = 0
    @ObservationIgnored private var segDists: [Double?] = []

    // 시간 (일시정지 제외)
    private(set) var startDate = Date()
    @ObservationIgnored private var segStart = Date()
    @ObservationIgnored private var pauseAt: Date?
    @ObservationIgnored private var segPaused: Double = 0

    // MARK: 권한

    func requestAuthorization() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
                                       HKQuantityType(.distanceWalkingRunning), HKObjectType.workoutType()]
        health.requestAuthorization(toShare: share, read: read) { _, _ in }
        location.requestWhenInUseAuthorization()
    }

    // MARK: 값

    var cur: Seg { seq.indices.contains(idx) ? seq[idx] : (seq.last ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 270)) }
    var next: Seg { seq.indices.contains(idx + 1) ? seq[idx + 1] : cur }

    func segEl(_ now: Date) -> Int {
        let p = pauseAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, Int(now.timeIntervalSince(segStart) - segPaused - p))
    }
    func doneT() -> Int { splits.prefix(idx).reduce(0, +) }
    func total(_ now: Date) -> Int { doneT() + segEl(now) }

    /// 목표 대비: 끝낸 구간 합 − 목표 합 + 현재 구간 초과분
    func delta(_ now: Date) -> Int {
        let tg = seq.prefix(idx).map(\.target).reduce(0, +)
        let over = max(0, segEl(now) - cur.target)
        return doneT() - tg + over
    }

    var zone: Int { settings.zone(hr) }

    /// 현재 러닝 구간 거리(m)
    var segDist: Double { max(0, distance - segDistStart) }

    // MARK: 시작

    func start(mode: Mode, title: String, sets: Int = 1, seq: [Seg]) {
        guard !active else { return }
        self.mode = mode
        self.title = title
        self.sets = sets
        self.seq = seq
        idx = 0; splits = []; running = true; finished = false; lastRecord = nil
        hr = 0; kcal = 0; distance = 0; hrSamples = []
        segHR = Array(repeating: [], count: seq.count)
        segDists = Array(repeating: nil, count: seq.count)
        segDistStart = 0; segPaused = 0; pauseAt = nil
        let now = Date()
        startDate = now; segStart = now
        active = true

        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .running
        let outdoor = mode != .race && settings.runMode == "outdoor"
        cfg.locationType = outdoor ? .outdoor : .indoor
        if let s = try? HKWorkoutSession(healthStore: health, configuration: cfg) {
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: cfg)
            s.delegate = self
            b.delegate = self
            session = s; builder = b
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { _, _ in }
        }
        WKInterfaceDevice.current().play(.start)
    }

    // MARK: 진행

    /// 다음 구간 (왼쪽 스와이프 · 더블탭 · Next)
    func advance() {
        guard active, !finished, running else { return }
        let now = Date()
        closeSeg(now)
        if splits.count >= seq.count {
            finish(now)
        } else {
            idx = splits.count
            segStart = now; segPaused = 0
            segDistStart = distance
            WKInterfaceDevice.current().play(.click)
        }
    }

    func togglePause() {
        guard active else { return }
        if running {
            pauseAt = Date(); running = false
            session?.pause()
        } else {
            if let p = pauseAt { segPaused += Date().timeIntervalSince(p) }
            pauseAt = nil; running = true
            session?.resume()
        }
    }

    /// End: 현재 구간까지 기록하고 끝냄
    func endNow() {
        guard active else { return }
        if !running { togglePause() }
        let now = Date()
        closeSeg(now)
        finish(now)
    }

    func reset() {
        active = false; finished = false; lastRecord = nil
    }

    private func closeSeg(_ now: Date) {
        let t = segEl(now)
        splits.append(t)
        if cur.kind == .run, segDists.indices.contains(idx) { segDists[idx] = segDist }
    }

    private func makeRecord() -> Record {
        let bpms = hrSamples.map(\.b)
        var results: [SegResult] = []
        for (i, t) in splits.enumerated() where seq.indices.contains(i) {
            let s = seq[i]
            let h = segHR.indices.contains(i) ? segHR[i] : []
            results.append(SegResult(icon: s.icon, name: s.name, detail: s.detail, kind: s.kind, time: t, target: s.target,
                                     hr: h.isEmpty ? nil : Int((h.reduce(0, +) / Double(h.count)).rounded()),
                                     dist: segDists.indices.contains(i) ? segDists[i] : nil))
        }
        let total = splits.reduce(0, +)
        let tg = seq.prefix(splits.count).map(\.target).reduce(0, +)
        return Record(mode: mode, title: title, sets: sets, date: startDate, total: total, segs: results, hr: hrSamples,
                      kcal: Int(kcal.rounded()), avgHR: bpms.isEmpty ? 0 : bpms.reduce(0, +) / bpms.count,
                      maxHR: bpms.max() ?? 0, division: settings.div.name,
                      goal: mode == .race ? settings.goalTime : nil,
                      vsWord: deltaWord, vsTarget: tg)
    }

    private func finish(_ now: Date) {
        let r = makeRecord()
        lastRecord = r
        finished = true
        WatchStore.shared.send(r)
        WKInterfaceDevice.current().play(.success)

        session?.end()
        let b = builder
        b?.endCollection(withEnd: now) { _, _ in b?.finishWorkout { _, _ in } }
    }

    /// 화면 캡처용: 건강 앱·타이머 없이 운동 중 / 요약 상태를 만든다 (--shot)
    func demoRun(mode: Mode, title: String, seq: [Seg], idx: Int, elapsed: Int, hr: Double, done: Bool) {
        self.mode = mode; self.title = title; sets = 1; self.seq = seq
        running = true; finished = false; lastRecord = nil
        self.hr = hr; kcal = 214; distance = 380
        segHR = Array(repeating: [], count: seq.count)
        segDists = Array(repeating: nil, count: seq.count)
        segDistStart = 0; segPaused = 0; pauseAt = nil
        let now = Date()
        if done {
            splits = seq.enumerated().map { i, sg in max(20, Int(Double(sg.target) * (i % 2 == 0 ? 1.04 : 0.97))) }
            self.idx = max(0, seq.count - 1)
            for i in seq.indices { segHR[i] = [Double(150 + (i * 7) % 24)]; if seq[i].kind == .run { segDists[i] = 1000 } }
            hrSamples = (0..<40).map { HRPoint(t: $0 * 45, b: 120 + Int(45 * min(1, Double($0) / 8)) + ($0 % 5) * 3) }
            kcal = 612
            startDate = now.addingTimeInterval(-Double(splits.reduce(0, +)))
            lastRecord = makeRecord()
            finished = true
        } else {
            self.idx = idx
            splits = seq.prefix(idx).map { max(20, Int(Double($0.target) * 1.03)) }
            hrSamples = []
            startDate = now.addingTimeInterval(-Double(splits.reduce(0, +) + elapsed))
            segStart = now.addingTimeInterval(-Double(elapsed))
        }
        active = true
    }

    /// VS GOAL / VS JIHO / VS BEST
    var deltaWord: String {
        if mode == .race { return "VS GOAL" }
        if mode == .sim, let f = WatchStore.shared.ctx.friend { return "VS " + f.first.uppercased() }
        return "VS BEST"
    }

    fileprivate func gotHR(_ v: Double, _ date: Date) {
        hr = v
        guard active, !finished, running else { return }
        let t = total(date)
        if segHR.indices.contains(idx) { segHR[idx].append(v) }
        if let last = hrSamples.last, t - last.t < 5 { return }
        hrSamples.append(HRPoint(t: t, b: Int(v.rounded())))
    }
    fileprivate func gotEnergy(_ v: Double) { kcal = v }
    fileprivate func gotDistance(_ v: Double) { distance = v }
}

extension WorkoutEngine: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension WorkoutEngine: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let qt = type as? HKQuantityType, let st = workoutBuilder.statistics(for: qt) else { continue }
            if qt == HKQuantityType(.heartRate) {
                if let v = st.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    let d = st.mostRecentQuantityDateInterval()?.end ?? Date()
                    DispatchQueue.main.async { self.gotHR(v, d) }
                }
            } else if qt == HKQuantityType(.activeEnergyBurned) {
                if let v = st.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    DispatchQueue.main.async { self.gotEnergy(v) }
                }
            } else if qt == HKQuantityType(.distanceWalkingRunning) {
                if let v = st.sumQuantity()?.doubleValue(for: .meter()) {
                    DispatchQueue.main.async { self.gotDistance(v) }
                }
            }
        }
    }
}
