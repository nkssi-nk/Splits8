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
    // HIIT · 러닝 카드 (nil = 하이록스 운동)
    private(set) var kind: String? = nil
    @ObservationIgnored private var runKm = 0              // 0 = 자유 러닝
    @ObservationIgnored private var outdoorRun = false
    var isHIIT: Bool { kind == "hiit" }
    var isRunKind: Bool { kind == "run" }
    /// 끝 없이 늘어나는 운동 (HIIT · 자유 러닝)
    var growsOpen: Bool { isHIIT || (isRunKind && runKm == 0) }
    // 동네 이름 · 경로
    @ObservationIgnored private var place: String?
    @ObservationIgnored private var placeLookup: PlaceLookup?
    @ObservationIgnored private var routeLoc: CLLocationManager?
    @ObservationIgnored private var routeBuilder: HKWorkoutRouteBuilder?
    @ObservationIgnored private var routePts: [RoutePt] = []
    @ObservationIgnored private var lastRouteLoc: CLLocation?

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
    /// 구간이 넘어갈 때마다 +1 (스와이프·더블탭·Next 모두 advance() 하나로 모임) → 화면 노랑 플래시
    private(set) var advanceCount = 0

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

    // 진동 알림 (설정: hapticZone / hapticPace)
    @ObservationIgnored private var lastZone = 0                 // 0 = 아직 심박 없음
    @ObservationIgnored private var lastZoneBuzz: Date = .distantPast
    @ObservationIgnored private var paceBuzzed: Set<Int> = []     // 목표 초과 진동을 이미 울린 구간
    @ObservationIgnored private var tickTimer: Timer?

    // MARK: 권한

    func requestAuthorization() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
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

    func start(mode: Mode, title: String, sets: Int = 1, seq: [Seg], program: Program? = nil) {
        guard !active else { return }
        kind = mode == .training ? program?.kind : nil
        runKm = program?.runKm ?? 0
        outdoorRun = isRunKind && !(program?.indoor ?? true)
        place = nil; routePts = []; lastRouteLoc = nil
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
        lastZone = 0; lastZoneBuzz = .distantPast; paceBuzzed = []
        active = true
        startTick()

        let cfg = HKWorkoutConfiguration()
        if isHIIT {
            cfg.activityType = .highIntensityIntervalTraining
            cfg.locationType = .indoor
        } else if isRunKind {
            cfg.activityType = .running
            cfg.locationType = outdoorRun ? .outdoor : .indoor
        } else {
            cfg.activityType = .running
            let outdoor = mode != .race && settings.runMode == "outdoor"
            cfg.locationType = outdoor ? .outdoor : .indoor
        }
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
        startPlaceAndRoute()
    }

    // MARK: 동네 이름 · 경로 (실외 러닝)

    private func startPlaceAndRoute() {
        if outdoorRun {
            routeBuilder = HKWorkoutRouteBuilder(healthStore: health, device: nil)
            let m = CLLocationManager()
            m.delegate = self
            m.desiredAccuracy = kCLLocationAccuracyBest
            m.activityType = .fitness
            m.distanceFilter = 5
            m.startUpdatingLocation()
            routeLoc = m
        } else {
            let p = PlaceLookup()
            placeLookup = p
            p.fetch { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
    }

    private func stopRoute(workout: HKWorkout?) {
        routeLoc?.stopUpdatingLocation()
        routeLoc?.delegate = nil
        routeLoc = nil
        if let w = workout, let rb = routeBuilder, !routePts.isEmpty {
            rb.finishRoute(with: w, metadata: nil) { _, _ in }
        }
        routeBuilder = nil
    }

    fileprivate func gotLocations(_ locs: [CLLocation]) {
        guard active, !finished else { return }
        let good: [CLLocation] = locs.filter { $0.horizontalAccuracy > 0 && $0.horizontalAccuracy <= 30 }
        guard !good.isEmpty else { return }
        if running { routeBuilder?.insertRouteData(good) { _, _ in } }
        if place == nil, placeLookup == nil, let first = good.first {
            let p = PlaceLookup()
            placeLookup = p
            p.name(for: first) { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
        guard running else { return }
        for l in good {
            if let prev = lastRouteLoc, l.distance(from: prev) < 8 { continue }
            lastRouteLoc = l
            routePts.append(RoutePt(a: l.coordinate.latitude, o: l.coordinate.longitude))
        }
    }

    // MARK: 진행

    /// 다음 구간 (왼쪽 스와이프 · 더블탭 · Next)
    func advance() {
        guard active, !finished, running else { return }
        if isRunKind && !outdoorRun && distance <= 0 {
            // 실내 러닝인데 워치 거리값이 없으면 손으로 1km 넘김
        } else if isRunKind {
            return                                    // 러닝은 1km마다 자동으로 넘어감
        }
        let now = Date()
        closeSeg(now)
        if splits.count >= seq.count && (isHIIT || (isRunKind && runKm == 0)) {
            growSeq()
        }
        if splits.count >= seq.count {
            finish(now, complete: true)
        } else {
            idx = splits.count
            segStart = now; segPaused = 0
            segDistStart = distance
            advanceCount += 1
            // 다음 구간 알림: .click 은 너무 약해서 운동 중에는 느껴지지 않음
            WKInterfaceDevice.current().play(.notification)
        }
    }

    /// HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임
    private func growSeq() {
        let n: Int = seq.count + 1
        seq.append(isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n))
        segHR.append([])
        segDists.append(nil)
    }

    /// 러닝: 1km 넘으면 자동으로 다음 km (총거리 다 뛰면 끝)
    private func autoSplitIfNeeded() {
        guard isRunKind, active, !finished, running, segDist >= 1000 else { return }
        let now = Date()
        closeSeg(now)
        if runKm == 0 && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            finish(now, complete: true)
        } else {
            idx = splits.count
            segStart = now; segPaused = 0
            segDistStart = distance
            advanceCount += 1
            WKInterfaceDevice.current().play(.notification)
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
        // HIIT·자유 러닝은 끝이 없으니 End 가 정상 종료. 그 외는 마지막 구간에서 End 눌러도 다 한 것
        let open: Bool = isHIIT || (isRunKind && runKm == 0)
        finish(now, complete: open || splits.count >= seq.count)
    }

    func reset() {
        stopTick()
        active = false; finished = false; lastRecord = nil
    }

    // MARK: 진동 알림

    private func startTick() {
        stopTick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTick() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// 1초마다: Race · Full Sim 에서 현재 구간이 목표 시간을 넘으면 그 구간에서 한 번만 .retry
    private func tick() {
        guard active, !finished, running else { return }
        guard settings.hapticPace, mode == .race || mode == .sim else { return }
        let c: Seg = cur
        guard c.kind != .rox, c.target > 0, !paceBuzzed.contains(idx) else { return }
        if segEl(Date()) > c.target {
            paceBuzzed.insert(idx)
            WKInterfaceDevice.current().play(.retry)
        }
    }

    /// 심박 존이 바뀌면: 올라가면 .directionUp, 내려가면 .directionDown (첫 측정값 제외, 10초에 한 번까지)
    private func checkZone(_ bpm: Double, _ now: Date) {
        let z: Int = max(1, min(5, settings.zone(bpm)))
        let prev: Int = lastZone
        lastZone = z
        guard prev > 0, z != prev else { return }
        guard active, !finished, running, settings.hapticZone else { return }
        guard now.timeIntervalSince(lastZoneBuzz) >= 10 else { return }
        lastZoneBuzz = now
        WKInterfaceDevice.current().play(z > prev ? .directionUp : .directionDown)
    }

    private func closeSeg(_ now: Date) {
        let t = segEl(now)
        splits.append(t)
        if cur.kind == .run, segDists.indices.contains(idx) { segDists[idx] = segDist }
    }

    private func makeRecord(complete: Bool) -> Record {
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
        var r = Record(mode: mode, title: title, sets: sets, date: startDate, total: total, segs: results, hr: hrSamples,
                       kcal: Int(kcal.rounded()), avgHR: bpms.isEmpty ? 0 : bpms.reduce(0, +) / bpms.count,
                       maxHR: bpms.max() ?? 0, division: settings.div.name,
                       goal: mode == .race ? settings.goalTime : nil,
                       vsWord: deltaWord, vsTarget: kind == nil ? tg : nil, complete: complete)
        r.endDate = startDate.addingTimeInterval(Double(total))
        r.place = place
        r.kind = kind
        if outdoorRun && routePts.count >= 2 { r.route = routePts }
        return r
    }

    private func finish(_ now: Date, complete: Bool) {
        stopTick()
        let r = makeRecord(complete: complete)
        lastRecord = r
        finished = true
        WatchStore.shared.send(r)
        WKInterfaceDevice.current().play(.success)

        session?.end()
        let b = builder
        b?.endCollection(withEnd: now) { _, _ in
            b?.finishWorkout { w, _ in
                DispatchQueue.main.async { self.stopRoute(workout: w) }
            }
        }
        if b == nil { stopRoute(workout: nil) }
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
            var sp: [Int] = []
            for i in seq.indices {
                let f: Double = i % 2 == 0 ? 1.04 : 0.97
                let t: Int = Int(Double(seq[i].target) * f)
                sp.append(max(20, t))
            }
            splits = sp
            self.idx = max(0, seq.count - 1)
            for i in seq.indices {
                let b: Int = 150 + (i * 7) % 24
                segHR[i] = [Double(b)]
                if seq[i].kind == .run { segDists[i] = 1000 }
            }
            var hs: [HRPoint] = []
            for k in 0..<40 {
                let ramp: Double = min(1, Double(k) / 8)
                let b: Int = 120 + Int(45 * ramp) + (k % 5) * 3
                hs.append(HRPoint(t: k * 45, b: b))
            }
            hrSamples = hs
            kcal = 612
            let passed: Int = splits.reduce(0, +)
            startDate = now.addingTimeInterval(-Double(passed))
            lastRecord = makeRecord(complete: true)
            finished = true
        } else {
            self.idx = idx
            var sp: [Int] = []
            for sg in seq.prefix(idx) {
                let t: Int = Int(Double(sg.target) * 1.03)
                sp.append(max(20, t))
            }
            splits = sp
            hrSamples = []
            let passed: Int = splits.reduce(0, +) + elapsed
            startDate = now.addingTimeInterval(-Double(passed))
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
        if v > 0 { checkZone(v, Date()) }
        guard active, !finished, running else { return }
        let t = total(date)
        if segHR.indices.contains(idx) { segHR[idx].append(v) }
        if let last = hrSamples.last, t - last.t < 5 { return }
        hrSamples.append(HRPoint(t: t, b: Int(v.rounded())))
    }
    fileprivate func gotEnergy(_ v: Double) { kcal = v }
    fileprivate func gotDistance(_ v: Double) {
        distance = v
        autoSplitIfNeeded()
    }
}

extension WorkoutEngine: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { self.gotLocations(locations) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
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
