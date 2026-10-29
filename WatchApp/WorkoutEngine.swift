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
    /// PFT: 시작할 때 이미 최고 기록이 있었는지 (있으면 그 구간 시간이 목표 → 끝 화면에 최고 기록 대비 표시)
    @ObservationIgnored private var hasPFTBest = false
    /// Full Sim 비교 이름 (시작할 때 정함: VS GOAL / VS LAST / VS 친구 / VS BEST)
    @ObservationIgnored private var simWordAtStart: String?
    private var simWord: String { simWordAtStart ?? WatchStore.shared.simPick.word }
    @ObservationIgnored private var outdoorRun = false
    var isHIIT: Bool { kind == "hiit" }
    var isRunKind: Bool { kind == "run" }
    /// 끝 없이 늘어나는 운동 (HIIT · AMRAP · 자유 러닝)
    var growsOpen: Bool { isHIIT || kind == WKind.amrap || (isRunKind && runKm == 0) }
    // 18번 · 새 종류 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성)
    /// 시작한 카드 (AMRAP 총 시간 · 할 일 글자)
    @ObservationIgnored private(set) var program: Program?
    var isNewKind: Bool { WKind.isNew(kind) }
    var isInterval: Bool { kind == WKind.interval }
    /// 러닝처럼 GPS · 거리 · 페이스를 쓰는 종류
    var runLike: Bool { isRunKind || isInterval }
    /// AMRAP 총 시간(초)
    var amrapCap: Int? { kind == WKind.amrap ? program?.cap : nil }
    /// EMOM: 이번 라운드를 "끝" 낸 초 (nil = 아직)
    private(set) var doneAt: Int? = nil
    @ObservationIgnored private var segWork: [Int?] = []
    /// AMRAP: 마지막 구간이 덜 한 라운드인지
    @ObservationIgnored private var partialLast = false
    /// 단계 끝 3 · 2 · 1 진동을 이미 울린 자리 ("구간.남은초")
    @ObservationIgnored private var cdBuzzKey = ""
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
    // 62번 · 러닝 카드: 걸음 수(케이던스) · 보폭 (건강 앱 운동 기록에서 받음)
    @ObservationIgnored private var steps: Double = 0             // 누적 걸음
    @ObservationIgnored private var segStepStart: Double = 0
    @ObservationIgnored private var segSteps: [Double?] = []
    @ObservationIgnored private var strideAvg: Double? = nil      // 평균 보폭(m), 워치가 재 줄 때만
    // 빌드 27: 실시간 속도 (애플 운동 앱 · 나이키처럼 "지금" 페이스)
    /// 지금 속도(m/s). 0 = 모름 (일시정지 · 10초 넘게 새 값 없음)
    private(set) var curSpeed: Double = 0
    /// 건강 앱(runningSpeed)에서 마지막으로 받은 때 — 최근에 받았으면 GPS 속도는 안 씀
    @ObservationIgnored private var lastHKSpeedAt: Date = .distantPast
    /// 아무 쪽에서든 마지막으로 속도를 받은 때 (오래되면 0 으로)
    @ObservationIgnored private var lastSpeedAt: Date = .distantPast

    // 시간 (일시정지 제외)
    private(set) var startDate = Date()
    @ObservationIgnored private var segStart = Date()
    @ObservationIgnored private var pauseAt: Date?
    @ObservationIgnored private var segPaused: Double = 0

    // 시작 전 3 · 2 · 1 (nil = 세는 중 아님)
    private(set) var countdown: Int? = nil
    @ObservationIgnored private var countTimer: Timer?
    @ObservationIgnored private var pendingStart: (() -> Void)?
    /// 18번: 타이머 운동이면 3 · 2 · 1 을 소리로도
    @ObservationIgnored private var countVoice = false

    // 잘못 넘김 되돌리기 (방금 넘긴 것 한 번만)
    private struct UndoPoint {
        let idx: Int
        let segStart: Date
        let segPaused: Double
        let segDistStart: Double
        let grew: Bool
        let reps: Int?
        var segStepStart: Double = 0
    }
    @ObservationIgnored private var undoPoint: UndoPoint?
    /// 조작 화면의 Undo 를 누를 수 있는지
    private(set) var canUndo = false

    // 횟수 세기 (스키 · 로잉 · 월볼 — 참고용)
    @ObservationIgnored private let repCounter = RepCounter()
    @ObservationIgnored private var segReps: [Int?] = []

    // 진동 알림 (설정: hapticZone / hapticPace)
    @ObservationIgnored private var lastZone = 0                 // 0 = 아직 심박 없음
    @ObservationIgnored private var lastZoneBuzz: Date = .distantPast
    @ObservationIgnored private var paceBuzzed: Set<Int> = []     // 목표 초과 진동을 이미 울린 구간
    @ObservationIgnored private var tickTimer: Timer?

    // 아이폰에 같이 보여 주기 (52번 · HealthKit 운동 미러링)
    @ObservationIgnored private var mirroring = false
    @ObservationIgnored private var liveTicks = 0
    /// 운동 중에 아이폰과 끊김 → 30초마다 다시 이어 봄
    @ObservationIgnored private var mirrorLost = false

    // MARK: 권한

    func requestAuthorization() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        // 62번: 걸음 수 · 보폭 (러닝 카드 케이던스)
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
                                       HKQuantityType(.distanceWalkingRunning), HKObjectType.workoutType(),
                                       HKQuantityType(.stepCount), HKQuantityType(.runningStrideLength),
                                       HKQuantityType(.runningSpeed)]      // 빌드 27: 실시간 페이스
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

    /// 빌드 27: 지금 속도로 계산한 1 km 페이스(초). 속도를 모르거나 0.5 m/s 이하면 nil
    var livePaceSec: Int? {
        let sp: Double = curSpeed
        guard sp > 0.5 else { return nil }
        return Int(1000 / sp)
    }

    /// 빌드 27: 워치 화면의 PACE 글자 (1 km 당, imperial = true 면 1 mi 당).
    ///  - "5:12": 지금 속도로 계산한 페이스 (속도를 모르면 이 구간 평균 페이스)
    ///  - nil: 아직 측정 중 → 화면에서 "Measuring"(측정 중) 으로 보여 줄 것
    ///         (속도도 모르고 이 구간에서 50 m 도 안 달렸을 때)
    ///  - "–:––": 계산할 수 없음
    ///  예: `engine.paceText(el: engine.segEl(now), dist: engine.segDist)`
    func paceText(el: Int, dist: Double, imperial: Bool = false) -> String? {
        switch LivePace.reading(el: el, dist: dist, imperial: imperial, speed: curSpeed) {
        case .pace(let p): return LivePace.fmt(p)
        case .measuring: return nil
        case .unknown: return "–:––"
        }
    }

    /// 속도 하나 받음: 부드럽게(지수 이동 평균 alpha 0.3). 처음 값은 그대로
    private func blendSpeed(_ v: Double, _ now: Date) {
        guard v >= 0, v.isFinite else { return }
        let fresh: Bool = curSpeed <= 0 || now.timeIntervalSince(lastSpeedAt) > 10
        curSpeed = fresh ? v : (0.3 * v + 0.7 * curSpeed)
        lastSpeedAt = now
    }

    // MARK: 시작 전 3 · 2 · 1

    /// 3 · 2 · 1 을 센 뒤 시작. 숫자마다 짧은 진동, 시작 순간은 길게(약 1초)
    func startAfterCountdown(mode: Mode, title: String, sets: Int = 1, seq: [Seg], program: Program? = nil) {
        guard !active, countdown == nil else { return }
        pendingStart = { [weak self] in
            self?.start(mode: mode, title: title, sets: sets, seq: seq, program: program, buzz: false)
        }
        countdown = WBuzz.countFrom
        countVoice = mode == .training && WKind.isTimer(program?.kind)
        if countVoice { VoiceCoach.shared.count(settings, WBuzz.countFrom) }    // 18번: "셋 · 둘 · 하나"
        WKInterfaceDevice.current().play(WBuzz.tick)
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.countTick() }
        RunLoop.main.add(t, forMode: .common)
        countTimer = t
    }

    private func countTick() {
        guard let c = countdown else { stopCount(); return }
        if c > 1 {
            countdown = c - 1
            if countVoice { VoiceCoach.shared.count(settings, c - 1) }
            WKInterfaceDevice.current().play(WBuzz.tick)
        } else {
            stopCount()
            countdown = nil
            let go: (() -> Void)? = pendingStart
            pendingStart = nil
            go?()
            // 시작: 길고 센 진동을 이어서 두 번 (약 1초)
            WKInterfaceDevice.current().play(WBuzz.go1)
            DispatchQueue.main.asyncAfter(deadline: .now() + WBuzz.goGap) {
                WKInterfaceDevice.current().play(WBuzz.go2)
            }
        }
    }

    private func stopCount() {
        countTimer?.invalidate()
        countTimer = nil
    }

    /// 세는 중에 취소 (화면을 누르면)
    func cancelCountdown() {
        stopCount()
        countdown = nil
        pendingStart = nil
    }

    // MARK: 시작

    func start(mode: Mode, title: String, sets: Int = 1, seq: [Seg], program: Program? = nil, buzz: Bool = true) {
        guard !active else { return }
        kind = mode == .training ? program?.kind : nil
        self.program = mode == .training ? program : nil
        runKm = program?.runKm ?? 0
        outdoorRun = runLike && !(program?.indoor ?? true)
        doneAt = nil; partialLast = false; cdBuzzKey = ""
        segWork = Array(repeating: nil, count: seq.count)
        hasPFTBest = mode == .pft && WatchStore.shared.ctx.pftBest?.count == PFT.items.count
        place = nil; routePts = []; lastRouteLoc = nil
        simWordAtStart = mode == .sim ? WatchStore.shared.simPick.word : nil
        self.mode = mode
        self.title = title
        self.sets = sets
        self.seq = seq
        idx = 0; splits = []; running = true; finished = false; lastRecord = nil
        hr = 0; kcal = 0; distance = 0; hrSamples = []
        segHR = Array(repeating: [], count: seq.count)
        segDists = Array(repeating: nil, count: seq.count)
        segReps = Array(repeating: nil, count: seq.count)
        segSteps = Array(repeating: nil, count: seq.count)
        steps = 0; segStepStart = 0; strideAvg = nil
        curSpeed = 0; lastHKSpeedAt = .distantPast; lastSpeedAt = .distantPast
        segDistStart = 0; segPaused = 0; pauseAt = nil
        undoPoint = nil; canUndo = false
        let now = Date()
        startDate = now; segStart = now
        lastZone = 0; lastZoneBuzz = .distantPast; paceBuzzed = []
        mirroring = false; mirrorLost = false; liveTicks = 0
        active = true
        startTick()
        repCounter.start(icon: cur.icon)
        // 19번: 음성 안내 "운동을 시작합니다" (+ 첫 구간)
        VoiceCoach.shared.begin(settings, seq: seq, runCard: runLike, open: growsOpen, kind: kind)

        let cfg = HKWorkoutConfiguration()
        if isHIIT || WKind.isTimer(kind) {
            cfg.activityType = .highIntensityIntervalTraining
            cfg.locationType = .indoor
        } else if kind == WKind.strength {
            cfg.activityType = .traditionalStrengthTraining
            cfg.locationType = .indoor
        } else if runLike {
            cfg.activityType = .running
            cfg.locationType = outdoorRun ? .outdoor : .indoor
        } else {
            cfg.activityType = .running
            let outdoor = mode != .race && settings.runMode == "outdoor"
            cfg.locationType = outdoor ? .outdoor : .indoor
        }
        if let s = try? HKWorkoutSession(healthStore: health, configuration: cfg) {
            let b = s.associatedWorkoutBuilder()
            let src = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: cfg)
            // 62번: 러닝 카드는 걸음 수 · 보폭도 모음 (케이던스 계산용)
            if runLike {
                src.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
                src.enableCollection(for: HKQuantityType(.runningStrideLength), predicate: nil)
            }
            // 빌드 27: 러닝 속도 (실시간 페이스) — 러닝 운동이면 모두
            if cfg.activityType == .running {
                src.enableCollection(for: HKQuantityType(.runningSpeed), predicate: nil)
            }
            b.dataSource = src
            s.delegate = self
            b.delegate = self
            session = s; builder = b
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { _, _ in }
            // 설정 › Device › Show on iPhone 이 켜져 있으면 아이폰에 같이 보여 줌 (아이폰 앱이 뒤에서 켜짐)
            if settings.mirror {
                Task { @MainActor in
                    do {
                        try await s.startMirroringToCompanionDevice()
                        self.mirroring = true
                        self.pushLive()
                    } catch {
                        // 시작할 때 아이폰이 잠겨 있으면 실패함 → 30초마다 다시 시도
                        self.mirroring = false
                        self.mirrorLost = true
                    }
                }
            }
        }
        if buzz { WKInterfaceDevice.current().play(.start) }
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
        // 빌드 27: GPS 속도 — 건강 앱 속도(runningSpeed)가 10초 넘게 안 올 때만 씀
        if Date().timeIntervalSince(lastHKSpeedAt) > 10 {
            for l in good where l.speed >= 0 && l.horizontalAccuracy < 20 {
                blendSpeed(l.speed, Date())
            }
        }
        for l in good {
            if let prev = lastRouteLoc, l.distance(from: prev) < 8 { continue }
            lastRouteLoc = l
            // 62번: 높이(못 쟀으면 nil) · 시작부터 초(일시정지 뺀 시간) — 오르막 · 속도 색 지도용
            let h: Double? = l.verticalAccuracy > 0 ? l.altitude : nil
            routePts.append(RoutePt(a: l.coordinate.latitude, o: l.coordinate.longitude, h: h, t: total(l.timestamp)))
        }
    }

    // MARK: 진행

    /// 다음 구간 (왼쪽 스와이프 · 더블탭 · Next)
    func advance() {
        guard active, !finished, running else { return }
        if kind == WKind.emom { markDone(); return }     // 18번: EMOM 은 "끝" (남은 시간 = 휴식)
        if isRunKind && !outdoorRun && distance <= 0 {
            // 실내 러닝인데 워치 거리값이 없으면 손으로 1km 넘김
        } else if isRunKind {
            return                                    // 러닝은 1km마다 자동으로 넘어감
        }
        advanceCore(Date(), manual: true)
    }

    /// 다음 구간으로 (손으로 넘김 · 18번 시간/거리 자동 넘김 모두). now = 이 구간이 끝난 시각
    private func advanceCore(_ now: Date, manual: Bool) {
        let prevIdx: Int = idx
        let prevStart: Date = segStart
        let prevPaused: Double = segPaused
        let prevDistStart: Double = segDistStart
        let prevStepStart: Double = segStepStart
        closeSeg(now)
        var grew = false
        if splits.count >= seq.count && growsOpen {
            growSeq()
            grew = true
        }
        if splits.count >= seq.count {
            finish(now, complete: true)
        } else {
            // 되돌리기용으로 방금 구간의 상태를 기억 (한 번만 되돌릴 수 있음)
            undoPoint = UndoPoint(idx: prevIdx, segStart: prevStart, segPaused: prevPaused, segDistStart: prevDistStart,
                                  grew: grew, reps: segReps.indices.contains(prevIdx) ? segReps[prevIdx] : nil,
                                  segStepStart: prevStepStart)
            canUndo = manual && !isRunKind && kind != WKind.tabata
            idx = splits.count
            segStart = now; segPaused = 0
            segDistStart = distance
            segStepStart = steps
            doneAt = nil
            advanceCount += 1
            repCounter.start(icon: cur.icon)
            // 19번: 음성 안내 — 다음 구간 이름 (실내 러닝 카드를 손으로 넘기면 1 km 안내)
            if isNewKind {
                VoiceCoach.shared.phase(seq, idx: idx)
            } else if isRunKind {
                VoiceCoach.shared.runMark(meters: Double(idx) * 1000, totalSec: total(now), avgHR: avgHRNow)
            } else {
                VoiceCoach.shared.segment(seq, idx: idx)
            }
            // 다음 구간 알림: .click 은 너무 약해서 운동 중에는 느껴지지 않음
            WKInterfaceDevice.current().play(.notification)
            pushLive()
        }
    }

    /// 잘못 넘겼을 때: 방금 넘긴 것을 한 번 되돌림.
    /// 앞 구간으로 돌아가고 그 구간 시간이 끊기지 않고 이어짐 (넘긴 뒤 흐른 시간은 앞 구간에 합쳐짐)
    func undo() {
        guard active, !finished, canUndo, let u = undoPoint else { return }
        guard idx == u.idx + 1, splits.count == u.idx + 1 else { undoPoint = nil; canUndo = false; return }
        let newIdx: Int = idx
        splits.removeLast()
        if segHR.indices.contains(newIdx), segHR.indices.contains(u.idx) {
            segHR[u.idx].append(contentsOf: segHR[newIdx])
            segHR[newIdx] = []
        }
        if segDists.indices.contains(u.idx) { segDists[u.idx] = nil }
        if segReps.indices.contains(u.idx) { segReps[u.idx] = nil }
        if segSteps.indices.contains(u.idx) { segSteps[u.idx] = nil }
        if u.grew, seq.count == newIdx + 1 {          // HIIT·자유 러닝에서 붙였던 다음 라운드를 뗌
            seq.removeLast()
            if segHR.count > seq.count { segHR.removeLast() }
            if segDists.count > seq.count { segDists.removeLast() }
            if segReps.count > seq.count { segReps.removeLast() }
            if segSteps.count > seq.count { segSteps.removeLast() }
            if segWork.count > seq.count { segWork.removeLast() }
        }
        idx = u.idx
        segStart = u.segStart
        segPaused = u.segPaused + segPaused       // 넘긴 뒤에 일시정지한 시간도 빼 줌
        segDistStart = u.segDistStart
        segStepStart = u.segStepStart
        paceBuzzed.remove(newIdx)
        undoPoint = nil
        canUndo = false
        repCounter.start(icon: cur.icon, base: u.reps ?? 0)
        if !running { repCounter.setPaused(true) }
        WKInterfaceDevice.current().play(.directionDown)
        pushLive()
    }

    /// HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임
    private func growSeq() {
        let n: Int = seq.count + 1
        seq.append(kind == WKind.amrap ? SeqBuilder.amrapRound(n) : (isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)))
        segHR.append([])
        segDists.append(nil)
        segReps.append(nil)
        segSteps.append(nil)
        segWork.append(nil)
    }

    /// 러닝: 1km 넘으면 자동으로 다음 km (총거리 다 뛰면 끝)
    private func autoSplitIfNeeded() {
        // 18번: 인터벌 러닝 거리 단계 — 그 거리를 뛰면 다음 단계
        if isInterval {
            guard active, !finished, running, let m = cur.autoM, segDist >= Double(m) else { return }
            advanceCore(Date(), manual: false)
            return
        }
        guard isRunKind, active, !finished, running, segDist >= 1000 else { return }
        let now = Date()
        undoPoint = nil; canUndo = false
        closeSeg(now)
        if runKm == 0 && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            finish(now, complete: true)
        } else {
            idx = splits.count
            segStart = now; segPaused = 0
            segDistStart = distance
            segStepStart = steps
            advanceCount += 1
            WKInterfaceDevice.current().play(.notification)
            pushLive()
        }
    }

    func togglePause() {
        guard active else { return }
        if running {
            pauseAt = Date(); running = false
            curSpeed = 0                                // 빌드 27: 멈추면 속도 모름
            session?.pause()
            repCounter.setPaused(true)
            VoiceCoach.shared.paused()
        } else {
            if let p = pauseAt { segPaused += Date().timeIntervalSince(p) }
            pauseAt = nil; running = true
            session?.resume()
            repCounter.setPaused(false)
            VoiceCoach.shared.resumed()
        }
        pushLive()
    }

    /// End: 현재 구간까지 기록하고 끝냄
    func endNow() {
        guard active, !finished else { return }
        if !running { togglePause() }
        let now = Date()
        closeSeg(now)
        // HIIT·자유 러닝은 끝이 없으니 End 가 정상 종료. 그 외는 마지막 구간에서 End 눌러도 다 한 것
        let open: Bool = isHIIT || (isRunKind && runKm == 0)
        if let c = amrapCap {
            // 18번: AMRAP 을 시간 전에 끝냄 → 하던 라운드는 덜 한 라운드
            partialLast = true
            finish(now, complete: total(now) >= c - 1)
            return
        }
        finish(now, complete: open || splits.count >= seq.count)
    }

    /// 61번 · 버리기: 기록 안 만듦 · 아이폰으로 안 보냄 · 건강 앱 운동도 저장 안 함 → 첫 화면
    func discardNow() {
        guard active, !finished else { return }
        stopTick()
        repCounter.stop()
        undoPoint = nil; canUndo = false
        mirroring = false
        mirrorLost = false
        VoiceCoach.shared.stop()
        session?.end()
        builder?.discardWorkout()
        builder = nil
        routeBuilder?.discard()
        stopRoute(workout: nil)
        WKInterfaceDevice.current().play(.click)
        active = false; finished = false; lastRecord = nil
    }

    func reset() {
        stopTick()
        repCounter.stop()
        undoPoint = nil; canUndo = false
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
        // 아이폰에 5초마다 심박 · 칼로리 · 시간 맞추기
        liveTicks += 1
        // 빌드 27: 10초 넘게 새 속도가 없으면 모름(0) — 멈춰 섰는데 예전 페이스가 남지 않게
        if curSpeed > 0 && Date().timeIntervalSince(lastSpeedAt) > 10 { curSpeed = 0 }
        if mirroring && liveTicks % 5 == 0 { pushLive() }
        if mirrorLost && active && !finished && liveTicks % 30 == 0, let s = session {
            Task { @MainActor in
                if (try? await s.startMirroringToCompanionDevice()) != nil {
                    self.mirrorLost = false
                    self.mirroring = true
                    self.pushLive()
                }
            }
        }
        guard active, !finished, running else { return }
        if isNewKind {
            timedTick()
            guard active, !finished else { return }
        }
        voiceTick()
        guard settings.hapticPace, mode == .race || mode == .sim else { return }
        let c: Seg = cur
        guard c.kind != .rox, c.target > 0, !paceBuzzed.contains(idx) else { return }
        if segEl(Date()) > c.target {
            paceBuzzed.insert(idx)
            WKInterfaceDevice.current().play(.retry)
        }
    }

    /// 19번: 음성 안내 1초마다 — 러닝 카드는 알림 간격마다 거리 · 시간 · 평균 페이스 · 평균 심박, 그 외는 스테이션 중간 응원
    private func voiceTick() {
        let now = Date()
        if isNewKind {
            VoiceCoach.shared.timerTick(seq: seq, idx: idx, segEl: segEl(now), total: total(now), cap: amrapCap)
            if isInterval && distance > 0 { VoiceCoach.shared.runMark(meters: distance, totalSec: total(now), avgHR: avgHRNow) }
        } else if isRunKind {
            if distance > 0 { VoiceCoach.shared.runMark(meters: distance, totalSec: total(now), avgHR: avgHRNow) }
        } else {
            VoiceCoach.shared.tick(seq: seq, idx: idx, segEl: segEl(now))
        }
    }

    // MARK: 18번 · 시간 · 라운드

    /// 1초마다: 시간 단계가 끝나면 다음 (경계 시각을 정확히 맞춤 → 20초 단계는 꼭 20초),
    /// 끝나기 3 · 2 · 1초 전 진동, AMRAP 총 시간이 되면 끝
    private func timedTick() {
        let now = Date()
        if let c = amrapCap, c > 0, total(now) >= c {
            amrapEnd(now, cap: c)
            return
        }
        var n = 0
        while n < 20, active, !finished, running, let a = cur.auto, segEl(now) >= a {
            // 타이머가 조금 늦게 불려도 이 구간은 a 초 (끝난 시각 = 시작 + 일시정지 + a)
            advanceCore(segStart.addingTimeInterval(segPaused + Double(a)), manual: false)
            n += 1
        }
        guard active, !finished, let a = cur.auto else { return }
        let left: Int = a - segEl(now)
        if left >= 1 && left <= 3 {
            let key: String = "\(idx).\(left)"
            if key != cdBuzzKey {
                cdBuzzKey = key
                WKInterfaceDevice.current().play(WBuzz.tick)
            }
        }
    }

    /// EMOM: 할 일을 끝냄 → 그 라운드 시간 저장, 남은 시간은 휴식 (다음 라운드는 간격이 끝나면 저절로)
    func markDone() {
        guard active, !finished, running, kind == WKind.emom, doneAt == nil else { return }
        let el: Int = segEl(Date())
        doneAt = el
        if segWork.indices.contains(idx) { segWork[idx] = el }
        WKInterfaceDevice.current().play(.success)
        pushLive()
    }

    /// AMRAP: 총 시간이 다 됨 → 하던 라운드는 덜 한 라운드로 저장하고 끝
    private func amrapEnd(_ now: Date, cap: Int) {
        closeSeg(now)
        let before: Int = splits.dropLast().reduce(0, +)
        if !splits.isEmpty { splits[splits.count - 1] = max(0, cap - before) }
        partialLast = true
        finish(now, complete: true)
    }

    /// 지금까지 평균 심박 (5초마다 모은 값). 없으면 nil
    private var avgHRNow: Int? {
        guard !hrSamples.isEmpty else { return nil }
        return hrSamples.map(\.b).reduce(0, +) / hrSamples.count
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
        // 62번: 이 구간 걸음 수 (러닝 카드에서 걸음을 받았을 때만)
        if isRunKind, cur.kind == .run, steps > segStepStart, segSteps.indices.contains(idx) {
            segSteps[idx] = steps - segStepStart
        }
        let reps: Int? = repCounter.stop()
        if segReps.indices.contains(idx) { segReps[idx] = reps }
    }

    private func makeRecord(complete: Bool) -> Record {
        let bpms = hrSamples.map(\.b)
        var results: [SegResult] = []
        for (i, t) in splits.enumerated() where seq.indices.contains(i) {
            let s = seq[i]
            let h = segHR.indices.contains(i) ? segHR[i] : []
            var sr = SegResult(icon: s.icon, name: s.name, detail: s.detail, kind: s.kind, time: t, target: s.target,
                               hr: h.isEmpty ? nil : Int((h.reduce(0, +) / Double(h.count)).rounded()),
                               dist: segDists.indices.contains(i) ? segDists[i] : nil,
                               reps: segReps.indices.contains(i) ? segReps[i] : nil)
            if isNewKind { sr.fillKind(s, kind: kind, work: segWork.indices.contains(i) ? segWork[i] : nil,
                                       partial: partialLast && i == splits.count - 1) }
            results.append(sr)
        }
        let total = splits.reduce(0, +)
        let tg = seq.prefix(splits.count).map(\.target).reduce(0, +)
        var r = Record(mode: mode, title: title, sets: sets, date: startDate, total: total, segs: results, hr: hrSamples,
                       kcal: Int(kcal.rounded()), avgHR: bpms.isEmpty ? 0 : bpms.reduce(0, +) / bpms.count,
                       maxHR: bpms.max() ?? 0, division: settings.div.name,
                       goal: mode == .race ? settings.goalTime : nil,
                       vsWord: deltaWord, vsTarget: (kind == nil && (mode != .pft || hasPFTBest)) ? tg : nil, complete: complete)
        r.endDate = startDate.addingTimeInterval(Double(total))
        r.place = place
        r.kind = kind
        if runLike && !outdoorRun { r.indoor = true }     // 94번 · 18번 인터벌 러닝도
        if outdoorRun && routePts.count >= 2 { r.route = routePts }
        // 62번: 러닝 카드 — 케이던스 · 보폭 · 오르막 (경로 높이로)
        if isRunKind { RunMetrics.fill(&r, segSteps: segSteps, strideHK: strideAvg) }
        return r
    }

    private func finish(_ now: Date, complete: Bool) {
        stopTick()
        repCounter.stop()
        undoPoint = nil; canUndo = false
        let r = makeRecord(complete: complete)
        lastRecord = r
        finished = true
        pushLive()                      // 아이폰: "Apple Watch 에 저장 중…" → 기록이 도착하면 카드
        mirroring = false
        mirrorLost = false
        WatchStore.shared.send(r)
        WKInterfaceDevice.current().play(.success)
        if isNewKind { VoiceCoach.shared.endedKind(kind, timeUp: complete) } else { VoiceCoach.shared.ended() }   // 19번: "운동 끝! 수고하셨어요."

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
    func demoRun(mode: Mode, title: String, seq: [Seg], idx: Int, elapsed: Int, hr: Double, done: Bool, vsBest: Bool = false) {
        kind = nil; hasPFTBest = vsBest
        self.mode = mode; self.title = title; sets = 1; self.seq = seq
        running = true; finished = false; lastRecord = nil
        self.hr = hr; kcal = 214; distance = 380
        segHR = Array(repeating: [], count: seq.count)
        segDists = Array(repeating: nil, count: seq.count)
        segReps = Array(repeating: nil, count: seq.count)
        segSteps = Array(repeating: nil, count: seq.count)
        steps = 0; segStepStart = 0; strideAvg = nil
        curSpeed = 0
        segDistStart = 0; segPaused = 0; pauseAt = nil
        undoPoint = nil; canUndo = !done && idx > 0      // 화면 캡처에서 Undo 가 켜진 모습
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

    // MARK: 아이폰에 같이 보여 주기 (52번)

    /// 지금 상태를 아이폰으로 (미러링 중일 때만)
    func pushLive() {
        guard mirroring, let s = session else { return }
        let now = Date()
        let hasTarget: Bool = kind == nil && seq.contains { $0.target > 0 }
        let st = LiveState(mode: mode, title: title, seq: seq, idx: idx, splits: splits, segElapsed: segEl(now),
                           running: running, hr: Int(hr.rounded()), kcal: Int(kcal.rounded()), zone: hr > 0 ? zone : 0,
                           canUndo: canUndo, finished: finished, vsWord: deltaWord,
                           delta: hasTarget ? delta(now) : nil, open: growsOpen, autoSplit: isRunKind && !(distance <= 0 && !outdoorRun),
                           segDist: segDist, dist: distance, spd: curSpeed > 0 ? curSpeed : nil)
        guard let d = LivePacket(state: st).data() else { return }
        s.sendToRemoteWorkoutSession(data: d) { _, _ in }
    }

    /// 아이폰에서 누른 버튼
    fileprivate func gotCommand(_ c: LiveCommand) {
        guard active, !finished else { return }
        switch c {
        case .next: advance()
        case .undo: undo()
        case .pause: if running { togglePause() }
        case .resume: if !running { togglePause() }
        case .end: endNow()
        }
        pushLive()
    }

    /// VS GOAL / VS LAST / VS JIHO / VS BEST
    var deltaWord: String {
        if mode == .race { return "VS GOAL" }
        if mode == .sim { return simWord }
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
    /// 62번: 누적 걸음 수 (러닝 카드 케이던스)
    fileprivate func gotSteps(_ v: Double) {
        guard active, !finished else { return }
        steps = v
    }
    /// 빌드 27: 건강 앱이 잰 지금 러닝 속도(m/s)
    fileprivate func gotSpeed(_ v: Double) {
        guard active, !finished, running else { return }
        let now = Date()
        lastHKSpeedAt = now
        blendSpeed(v, now)
    }
    /// 62번: 평균 보폭(m)
    fileprivate func gotStride(_ v: Double) {
        guard active, !finished, v > 0 else { return }
        strideAvg = v
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

    /// 아이폰에서 보낸 버튼 (Next · Undo · Pause · Resume · End)
    func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        for d in data {
            guard let c = LivePacket.read(d)?.command else { continue }
            DispatchQueue.main.async { self.gotCommand(c) }
        }
    }

    /// 아이폰과 연결이 끊김: 워치 혼자 계속 (다시 이어지지 않으면 끝까지 워치 기록만)
    func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        DispatchQueue.main.async {
            if self.mirroring && self.active && !self.finished { self.mirrorLost = true }
            self.mirroring = false
        }
    }
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
            } else if qt == HKQuantityType(.stepCount) {
                // 62번: 걸음 수는 누적(합계)
                if let v = st.sumQuantity()?.doubleValue(for: .count()) {
                    DispatchQueue.main.async { self.gotSteps(v) }
                }
            } else if qt == HKQuantityType(.runningSpeed) {
                // 빌드 27: 지금 속도 (가장 최근 값, m/s)
                let mps: HKUnit = HKUnit.meter().unitDivided(by: HKUnit.second())
                if let v = st.mostRecentQuantity()?.doubleValue(for: mps) {
                    DispatchQueue.main.async { self.gotSpeed(v) }
                }
            } else if qt == HKQuantityType(.runningStrideLength) {
                // 62번: 보폭은 그때그때 재는 값 → 지금까지 평균
                if let v = st.averageQuantity()?.doubleValue(for: .meter()) {
                    DispatchQueue.main.async { self.gotStride(v) }
                }
            }
        }
    }
}

/// 워치 진동 종류를 한곳에 (실제 워치로 느껴 본 뒤 여기만 바꾸면 됨).
/// 워치는 진동 길이를 마음대로 정할 수 없고 정해진 종류 중에서 골라야 함
enum WBuzz {
    /// 3 · 2 · 1
    static let countFrom: Int = 3
    /// 숫자마다: 짧게 한 번
    static let tick: WKHapticType = .start
    /// 시작 순간: 긴 진동 두 가지를 goGap 초 간격으로 이어 울림 (합쳐서 약 1초)
    static let go1: WKHapticType = .notification
    static let go2: WKHapticType = .success
    static let goGap: Double = 0.5
}
