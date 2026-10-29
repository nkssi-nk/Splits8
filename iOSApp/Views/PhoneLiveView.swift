import SwiftUI
import UIKit
import CoreLocation
import CoreMotion
import Observation

// MARK: - 워치 없이 아이폰으로 기록 (시안 ⑤)
// 큰 Next 버튼으로 구간을 넘김. 화면은 꺼지지 않음. 심박 없음.
// 구간 순서는 워치(WatchStore.seq)와 같은 규칙: SeqBuilder 를 그대로 씀.

/// 아이폰 운동 진행 (워치 WorkoutEngine 의 HealthKit 없는 축소판)
@Observable
final class PhoneRunEngine: NSObject, CLLocationManagerDelegate {
    private(set) var active = false
    private(set) var finished = false
    private(set) var mode: Mode = .sim
    private(set) var title = ""
    private(set) var sets = 1
    private(set) var seq: [Seg] = []
    private(set) var idx = 0
    private(set) var splits: [Int] = []
    private(set) var running = true

    // 시간 (일시정지 제외). Date 로 계산하므로 백그라운드에 다녀와도 맞음
    private(set) var startDate = Date()
    @ObservationIgnored private var segStart = Date()
    @ObservationIgnored private var pauseAt: Date?
    @ObservationIgnored private var segPaused: Double = 0

    // 야외 러닝 GPS 거리 (Settings.runMode == outdoor, 레이스 제외 — 워치와 같음)
    @ObservationIgnored private var location: CLLocationManager?
    @ObservationIgnored private var lastLoc: CLLocation?
    private(set) var useGPS = false
    private(set) var segDist: Double = 0
    @ObservationIgnored private var segDists: [Double?] = []
    /// 빌드 27: GPS 로 잰 지금 속도(m/s, 부드럽게). 0 = 모름 (일시정지 · GPS 안 씀)
    private(set) var curSpeed: Double = 0
    @ObservationIgnored private var lastSpeedAt: Date = .distantPast
    /// 화면용 지금 속도: 10초 넘게 새 값이 없으면 0 (멈춰 섰는데 예전 페이스가 남지 않게)
    func speedNow(_ now: Date) -> Double {
        guard useGPS, running, curSpeed > 0, now.timeIntervalSince(lastSpeedAt) <= 10 else { return 0 }
        return curSpeed
    }

    @ObservationIgnored private var settings = Settings()
    /// Full Sim 비교 이름 (시작할 때 정함: VS GOAL / VS LAST / VS 친구 / VS BEST)
    @ObservationIgnored private var simWord = "VS BEST"
    /// PFT: 시작할 때 이미 최고 기록이 있었는지 (있으면 그 구간 시간이 목표)
    @ObservationIgnored private var hasPFTBest = false

    // HIIT · 러닝 카드
    private(set) var kind: String? = nil
    @ObservationIgnored private var runKm = 0
    var isHIIT: Bool { kind == "hiit" }
    var isRunKind: Bool { kind == "run" }
    /// 64번: GPS 로 잰 전체 거리(m) — 끝난 구간 + 지금 구간
    var totalDist: Double { segDists.compactMap { $0 }.reduce(0, +) + segDist }
    /// 끝 없이 늘어나는 운동 (HIIT · AMRAP · 자유 러닝)
    var growsOpen: Bool { isHIIT || kind == WKind.amrap || (isRunKind && runKm == 0) }
    // 18번 · 새 종류 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성) — 워치 WorkoutEngine 과 같은 규칙
    /// 시작한 카드 (AMRAP 총 시간 · 할 일 글자 · 기능성 종목)
    @ObservationIgnored private(set) var program: Program?
    var isNewKind: Bool { WKind.isNew(kind) }
    var isInterval: Bool { kind == WKind.interval }
    /// 러닝처럼 GPS · 거리 · 페이스를 쓰는 종류
    var runLike: Bool { isRunKind || isInterval }
    var amrapCap: Int? { kind == WKind.amrap ? program?.cap : nil }
    /// EMOM: 이번 라운드를 "끝" 낸 초 (nil = 아직)
    private(set) var doneAt: Int? = nil
    /// 구간이 넘어갈 때마다 +1 (시간으로 저절로 넘어갈 때도 화면이 번쩍이게)
    private(set) var advanceCount = 0
    @ObservationIgnored private var segWork: [Int?] = []
    /// 기능성: 세트 끝에 고친 실제 횟수 · 무게
    @ObservationIgnored private var segActual: [Int?] = []
    @ObservationIgnored private var segKg: [Double?] = []
    @ObservationIgnored private var partialLast = false
    /// 시간 단계 넘김 (0.25초마다 — 새 종류만)
    @ObservationIgnored private var timedTimer: Timer?
    @ObservationIgnored private var cdKey = String()
    /// GPS 러닝이 총거리를 다 뛰어서 저절로 끝났을 때 (화면이 받아서 저장)
    private(set) var autoDone: Record? = nil
    // 동네 이름 · 경로
    @ObservationIgnored private var place: String?
    @ObservationIgnored private var placeLookup: PlaceLookup?
    @ObservationIgnored private var routePts: [RoutePt] = []
    @ObservationIgnored private var lastRouteLoc: CLLocation?
    // 62번 · 러닝 카드 걸음 수 (아이폰 모션 센서 · 케이던스용)
    @ObservationIgnored private var pedometer: CMPedometer?
    @ObservationIgnored private var steps: Double = 0          // 시작부터 걸음 (일시정지 중 걸음은 뺌)
    @ObservationIgnored private var rawSteps: Double = 0       // 센서가 준 그대로
    @ObservationIgnored private var pausedSteps: Double = 0    // 일시정지 동안 걸은 걸음 합
    @ObservationIgnored private var pauseStepAt: Double = 0
    @ObservationIgnored private var segStepStart: Double = 0
    @ObservationIgnored private var segSteps: [Double?] = []
    /// 빌드 24: 앱이 꺼졌다 이어 받을 때, 그 전까지 센 걸음 (걸음 센서는 다시 켜면 0부터 셈)
    @ObservationIgnored private var stepBase: Double = 0
    /// 빌드 24: 끝나면 / 취소하면 돌아갈 화면 (이어 받기용으로 저장)
    @ObservationIgnored var from: Scr = .home

    // 잘못 넘김 되돌리기 (방금 넘긴 것 한 번만) — 워치와 같음
    private struct UndoPoint {
        let idx: Int
        let segStart: Date
        let segPaused: Double
        let segDist: Double
        let grew: Bool
        var segStepStart: Double = 0
    }
    @ObservationIgnored private var undoPoint: UndoPoint?
    private(set) var canUndo = false

    /// 19번: 음성 안내 1초 타이머 (아이폰만으로 운동할 때만 — 워치 운동을 같이 보여 줄 때는 워치가 말함)
    @ObservationIgnored private var voiceTimer: Timer?

    // MARK: 값

    var cur: Seg {
        if seq.indices.contains(idx) { return seq[idx] }
        return seq.last ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 270)
    }
    var hasNext: Bool { seq.indices.contains(idx + 1) }
    var next: Seg? { hasNext ? seq[idx + 1] : nil }

    func segEl(_ now: Date) -> Int {
        let p: Double = pauseAt.map { now.timeIntervalSince($0) } ?? 0
        let v: Double = now.timeIntervalSince(segStart) - segPaused - p
        return max(0, Int(v))
    }
    func doneT() -> Int { splits.prefix(idx).reduce(0, +) }
    func total(_ now: Date) -> Int { doneT() + segEl(now) }

    /// Roxzone 을 뺀 구간 수 (시안: 4 / 16)
    var countTotal: Int { seq.filter { $0.kind != .rox }.count }
    /// 현재 구간이 Roxzone 을 뺀 몇 번째인지
    var countNow: Int {
        let upTo: ArraySlice<Seg> = seq.prefix(idx + 1)
        return upTo.filter { $0.kind != .rox }.count
    }

    // MARK: 구간 순서 (워치 WatchStore.seq 와 같은 규칙)

    static func buildSeq(mode: Mode, program: Program?, store: Store) -> [Seg] {
        let s: Settings = store.settings
        switch mode {
        case .race:
            let g: [Int] = s.goals.count == 16 ? s.goals : Defaults.goals
            return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: g, roxTarget: s.roxTarget)
        case .sim:
            return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: simTargets(store), roxTarget: s.roxTarget)
        case .pft:
            return PFT.seq(div: s.div, targets: store.pftBest?.pftSplits)
        case .training:
            let p: Program = program ?? Program.presets()[0]
            return SeqBuilder.training(p, div: s.div, bests: store.segBests)
        }
    }

    /// Full Simulation 목표 16개와 비교 이름: Full Sim 화면의 "Compare with" (Goal / Last / 친구) 를 따름
    static func simPick(_ store: Store) -> (targets: [Int], word: String) {
        SimTarget.pick(cmp: store.settings.simCmp, goals: store.settings.goals, last: store.simLast?.splits16,
                       friend: store.friend?.splits, friendFirst: store.friend?.first, best: store.simBest?.splits16)
    }
    static func simTargets(_ store: Store) -> [Int] { simPick(store).targets }

    static func title(mode: Mode, program: Program?, store: Store) -> String {
        switch mode {
        case .training: return (program ?? Program.presets()[0]).name
        case .sim: return "Full Simulation"
        case .pft: return PFT.title
        case .race:
            let n: String = store.settings.event.name.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? "Race" : n
        }
    }

    // MARK: 시작

    func start(_ req: PhoneRunRequest) {
        guard !active else { return }
        let store = Store.shared
        settings = store.settings
        simWord = PhoneRunEngine.simPick(store).word
        hasPFTBest = store.pftBest != nil
        mode = req.mode
        title = PhoneRunEngine.title(mode: req.mode, program: req.program, store: store)
        sets = req.mode == .training ? max(1, (req.program ?? Program.presets()[0]).sets) : 1
        seq = PhoneRunEngine.buildSeq(mode: req.mode, program: req.program, store: store)
        idx = 0; splits = []; running = true; finished = false
        segDists = Array(repeating: nil, count: seq.count)
        segDist = 0; lastLoc = nil
        curSpeed = 0; lastSpeedAt = .distantPast
        segPaused = 0; pauseAt = nil
        undoPoint = nil; canUndo = false
        let now = Date()
        startDate = now; segStart = now
        active = true
        kind = req.mode == .training ? req.program?.kind : nil
        program = req.mode == .training ? req.program : nil
        runKm = req.program?.runKm ?? 0
        doneAt = nil; partialLast = false; cdKey = String()
        segWork = Array(repeating: nil, count: seq.count)
        segActual = Array(repeating: nil, count: seq.count)
        segKg = Array(repeating: nil, count: seq.count)
        autoDone = nil; place = nil; routePts = []; lastRouteLoc = nil
        segSteps = Array(repeating: nil, count: seq.count)
        steps = 0; rawSteps = 0; pausedSteps = 0; pauseStepAt = 0; segStepStart = 0; stepBase = 0
        from = req.from
        if isRunKind { startSteps(now) }

        if runLike {
            useGPS = !(req.program?.indoor ?? true)
        } else if isNewKind {
            useGPS = false
        } else {
            useGPS = req.mode != .race && settings.runMode == "outdoor"
        }
        if useGPS {
            startGPS()
        } else {
            let p = PlaceLookup()
            placeLookup = p
            p.fetch { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
        // 19번: 음성 안내 "운동을 시작합니다" (+ 첫 구간)
        VoiceCoach.shared.begin(settings, seq: seq, runCard: runLike, open: growsOpen, kind: kind)
        startVoice()
        startTimed()
        persist()
    }

    /// HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임
    private func growSeq() {
        let n: Int = seq.count + 1
        seq.append(kind == WKind.amrap ? SeqBuilder.amrapRound(n) : (isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)))
        segDists.append(nil)
        segSteps.append(nil)
        segWork.append(nil)
        segActual.append(nil)
        segKg.append(nil)
    }

    /// 다음 구간 (HIIT·자유 러닝은 아직 순서에 없는 다음 라운드/km)
    var nextSeg: Seg? {
        if growsOpen && !hasNext {
            let n: Int = seq.count + 1
            return kind == WKind.amrap ? SeqBuilder.amrapRound(n) : (isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n))
        }
        return next
    }

    // MARK: 진행

    /// 다음 구간. 마지막 구간이면 끝내고 기록을 돌려줌
    /// reps · kg: 기능성 세트 끝에 확인한 실제 횟수 · 무게
    func advance(reps: Int? = nil, kg: Double? = nil) -> Record? {
        guard active, !finished, running else { return nil }
        if kind == WKind.emom { markDone(); return nil }   // 18번: EMOM 은 "끝" (남은 시간 = 휴식)
        if isRunKind && useGPS { return nil }            // GPS 러닝은 1km마다 저절로 넘어감
        if kind == WKind.strength, cur.tag == "set", segActual.indices.contains(idx) {
            segActual[idx] = reps
            segKg[idx] = kg
        }
        return advanceCore(Date(), manual: true)
    }

    /// 다음 구간으로 (손으로 · 18번 시간/거리 자동 모두). now = 이 구간이 끝난 시각
    private func advanceCore(_ now: Date, manual: Bool) -> Record? {
        let up = UndoPoint(idx: idx, segStart: segStart, segPaused: segPaused, segDist: segDist,
                           grew: growsOpen && splits.count + 1 >= seq.count, segStepStart: segStepStart)
        closeSeg(now)
        if growsOpen && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            return finish(complete: true)
        }
        undoPoint = manual ? up : nil
        canUndo = manual && kind != WKind.tabata
        idx = splits.count
        segStart = now; segPaused = 0
        segDist = 0
        segStepStart = steps
        doneAt = nil
        advanceCount += 1
        // 19번: 음성 안내 — 다음 구간 이름 (실내 러닝 카드를 손으로 넘기면 1 km 안내)
        if isNewKind {
            VoiceCoach.shared.phase(seq, idx: idx)
        } else if isRunKind {
            VoiceCoach.shared.runMark(meters: Double(idx) * 1000, totalSec: total(now), avgHR: nil)
        } else {
            VoiceCoach.shared.segment(seq, idx: idx)
        }
        persist()
        return nil
    }

    /// 잘못 넘겼을 때: 방금 넘긴 것을 한 번 되돌림 (앞 구간 시간이 끊기지 않고 이어짐)
    func undo() {
        guard active, !finished, canUndo, let u = undoPoint else { return }
        guard idx == u.idx + 1, splits.count == u.idx + 1 else { undoPoint = nil; canUndo = false; return }
        let newIdx: Int = idx
        splits.removeLast()
        if segDists.indices.contains(u.idx) { segDists[u.idx] = nil }
        if segSteps.indices.contains(u.idx) { segSteps[u.idx] = nil }
        if segActual.indices.contains(u.idx) { segActual[u.idx] = nil }
        if segKg.indices.contains(u.idx) { segKg[u.idx] = nil }
        if u.grew, seq.count == newIdx + 1 {
            seq.removeLast()
            if segDists.count > seq.count { segDists.removeLast() }
            if segSteps.count > seq.count { segSteps.removeLast() }
            if segWork.count > seq.count { segWork.removeLast() }
            if segActual.count > seq.count { segActual.removeLast() }
            if segKg.count > seq.count { segKg.removeLast() }
        }
        idx = u.idx
        segStart = u.segStart
        segPaused = u.segPaused + segPaused
        segDist = u.segDist + segDist
        segStepStart = u.segStepStart
        undoPoint = nil
        canUndo = false
        persist()
    }

    func togglePause() {
        guard active, !finished else { return }
        if running {
            pauseAt = Date(); running = false
            curSpeed = 0                                // 빌드 27: 멈추면 속도 모름
            pauseStepAt = rawSteps
            VoiceCoach.shared.paused()
        } else {
            if let p = pauseAt { segPaused += Date().timeIntervalSince(p) }
            pauseAt = nil; running = true
            lastLoc = nil
            // 62번: 일시정지 동안 걸은 걸음은 케이던스에서 뺌
            pausedSteps += max(0, rawSteps - pauseStepAt)
            steps = stepBase + max(0, rawSteps - pausedSteps)
            VoiceCoach.shared.resumed()
        }
        persist()
    }

    /// End → Save: 현재 구간까지 기록하고 끝냄
    func endNow() -> Record? {
        guard active, !finished else { return nil }
        if !running { togglePause() }
        let now = Date()
        closeSeg(now)
        if let c = amrapCap {
            // 18번: AMRAP 을 시간 전에 끝냄 → 하던 라운드는 덜 한 라운드
            partialLast = true
            return finish(complete: total(now) >= c - 1)
        }
        return finish(complete: growsOpen || splits.count >= seq.count)
    }

    /// End → Discard
    func discard() {
        stopGPS()
        stopSteps()
        stopVoice()
        stopTimed()
        VoiceCoach.shared.stop()
        active = false; finished = true
        PhoneRunEngine.clearSnapshot()
    }

    private func closeSeg(_ now: Date) {
        splits.append(segEl(now))
        if useGPS, cur.kind == .run, segDists.indices.contains(idx), segDist > 0 {
            segDists[idx] = segDist
        }
        // 62번: 이 구간 걸음 수 (러닝 카드)
        if isRunKind, cur.kind == .run, steps > segStepStart, segSteps.indices.contains(idx) {
            segSteps[idx] = steps - segStepStart
        }
    }

    private func finish(complete: Bool) -> Record {
        stopGPS()
        stopSteps()
        stopVoice()
        stopTimed()
        if isNewKind { VoiceCoach.shared.endedKind(kind, timeUp: complete) } else { VoiceCoach.shared.ended() }   // 19번: "운동 끝! 수고하셨어요."
        undoPoint = nil; canUndo = false
        finished = true
        PhoneRunEngine.clearSnapshot()
        return makeRecord(complete: complete)
    }

    /// 워치 WorkoutEngine.makeRecord 와 같은 모양 (심박·칼로리 없음)
    private func makeRecord(complete: Bool) -> Record {
        var results: [SegResult] = []
        for (i, t) in splits.enumerated() where seq.indices.contains(i) {
            let s: Seg = seq[i]
            let d: Double? = segDists.indices.contains(i) ? segDists[i] : nil
            var sr = SegResult(icon: s.icon, name: s.name, detail: s.detail, kind: s.kind, time: t, target: s.target,
                               hr: nil, dist: d)
            if isNewKind {
                sr.fillKind(s, kind: kind, work: segWork.indices.contains(i) ? segWork[i] : nil,
                            partial: partialLast && i == splits.count - 1)
                // 기능성: 세트 끝에 고친 값
                if s.tag == "set", segActual.indices.contains(i) {
                    if let a = segActual[i] { sr.reps = a }
                    if let k = segKg[i] { sr.kg = k }
                }
            }
            results.append(sr)
        }
        let total: Int = splits.reduce(0, +)
        let tg: Int = seq.prefix(splits.count).map(\.target).reduce(0, +)
        var r = Record(mode: mode, title: title, sets: sets, date: startDate, total: total, segs: results, hr: [],
                       kcal: 0, avgHR: 0, maxHR: 0, division: settings.div.name,
                       goal: mode == .race ? settings.goalTime : nil,
                       vsWord: deltaWord, vsTarget: (kind == nil && (mode != .pft || hasPFTBest)) ? tg : nil, complete: complete)
        r.endDate = startDate.addingTimeInterval(Double(total))
        r.place = place
        r.kind = kind
        if runLike && !useGPS { r.indoor = true }          // 94번 · 18번 인터벌 러닝도
        if runLike && useGPS && routePts.count >= 2 { r.route = routePts }
        // 62번: 러닝 카드 — 케이던스 · 보폭(GPS 거리 ÷ 걸음) · 오르막 (경로 높이로)
        if isRunKind { RunMetrics.fill(&r, segSteps: segSteps, strideHK: nil) }
        return r
    }

    // MARK: 19번 · 음성 안내 (1초마다)

    private func startVoice() {
        voiceTimer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.voiceTick() }
        RunLoop.main.add(t, forMode: .common)
        voiceTimer = t
    }

    private func stopVoice() {
        voiceTimer?.invalidate()
        voiceTimer = nil
    }

    /// 러닝 카드(GPS)는 알림 간격마다 거리 · 시간 · 평균 페이스, 그 외는 스테이션 중간 응원
    private func voiceTick() {
        guard active, !finished, running else { return }
        let now = Date()
        if isNewKind {
            VoiceCoach.shared.timerTick(seq: seq, idx: idx, segEl: segEl(now), total: total(now), cap: amrapCap)
            if isInterval && useGPS { VoiceCoach.shared.runMark(meters: totalDist, totalSec: total(now), avgHR: nil) }
        } else if isRunKind {
            if useGPS { VoiceCoach.shared.runMark(meters: totalDist, totalSec: total(now), avgHR: nil) }
        } else {
            VoiceCoach.shared.tick(seq: seq, idx: idx, segEl: segEl(now))
        }
    }

    // MARK: 18번 · 시간 · 라운드 (0.25초마다)

    private func startTimed() {
        timedTimer?.invalidate()
        guard isNewKind else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.timedTick() }
        RunLoop.main.add(t, forMode: .common)
        timedTimer = t
    }

    private func stopTimed() {
        timedTimer?.invalidate()
        timedTimer = nil
    }

    /// 시간 단계가 끝나면 다음 (경계 시각에 정확히 맞춤), 3 · 2 · 1초 전 진동, AMRAP 총 시간이 되면 끝
    private func timedTick() {
        guard active, !finished, running else { return }
        let now = Date()
        if let c = amrapCap, c > 0, total(now) >= c {
            closeSeg(now)
            let before: Int = splits.dropLast().reduce(0, +)
            if !splits.isEmpty { splits[splits.count - 1] = max(0, c - before) }
            partialLast = true
            autoDone = finish(complete: true)
            return
        }
        var n = 0
        while n < 20, active, !finished, running, let a = cur.auto, segEl(now) >= a {
            if let rec = advanceCore(segStart.addingTimeInterval(segPaused + Double(a)), manual: false) {
                autoDone = rec
                return
            }
            n += 1
        }
        guard let a = cur.auto else { return }
        let left: Int = a - segEl(now)
        if left >= 1 && left <= 3 {
            let key: String = "\(idx).\(left)"
            if key != cdKey {
                cdKey = key
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
    }

    /// EMOM: 할 일을 끝냄 → 그 라운드 시간 저장, 남은 시간은 휴식
    func markDone() {
        guard active, !finished, running, kind == WKind.emom, doneAt == nil else { return }
        let el: Int = segEl(Date())
        doneAt = el
        if segWork.indices.contains(idx) { segWork[idx] = el }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        persist()
    }

    /// 기능성: 이 종목 · 세트를 지난번에 한 값 (횟수 · 무게) — 세트 끝 확인 칸을 미리 채움
    func lastSetValues() -> (reps: Int, kg: Double) {
        let c: Seg = cur
        let plan: (reps: Int, kg: Double) = (c.reps ?? 0, c.kg ?? 0)
        guard c.tag == "set" else { return plan }
        let prev: Record? = Store.shared.records
            .filter { r in r.kind == WKind.strength && r.segs.contains { $0.tag == "set" && $0.name == c.name } }
            .max { $0.date < $1.date }
        guard let p = prev else { return plan }
        let sets: [SegResult] = p.segs.filter { $0.tag == "set" && $0.name == c.name }
        let same: SegResult? = sets.first { $0.no == c.no } ?? sets.last
        guard let x = same else { return plan }
        return (x.reps ?? plan.reps, x.kg ?? plan.kg)
    }

    // MARK: 걸음 수 (62번 · 아이폰 모션 센서)

    /// 운동 시작부터 걸음 수를 받음 (모션 권한은 처음 한 번 물어봄). 못 쓰는 기기면 조용히 건너뜀
    private func startSteps(_ from: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let p = CMPedometer()
        pedometer = p
        p.startUpdates(from: from) { [weak self] data, _ in
            guard let n = data?.numberOfSteps.doubleValue else { return }
            DispatchQueue.main.async { self?.gotSteps(n) }
        }
    }

    private func stopSteps() {
        pedometer?.stopUpdates()
        pedometer = nil
    }

    private func gotSteps(_ n: Double) {
        guard active, !finished else { return }
        rawSteps = n
        if running { steps = stepBase + max(0, n - pausedSteps) }
    }

    /// VS GOAL / VS LAST / VS JIHO / VS BEST (워치와 같음)
    var deltaWord: String {
        if mode == .race { return "VS GOAL" }
        if mode == .sim { return simWord }
        return "VS BEST"
    }

    // MARK: GPS

    private func startGPS() {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyBest
        m.activityType = .fitness
        m.distanceFilter = 5
        location = m
        if m.authorizationStatus == .notDetermined {
            m.requestWhenInUseAuthorization()
        } else {
            m.startUpdatingLocation()
        }
    }

    private func stopGPS() {
        location?.stopUpdatingLocation()
        location?.delegate = nil
        location = nil
        lastLoc = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let st = manager.authorizationStatus
        if st == .authorizedWhenInUse || st == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            DispatchQueue.main.async { self.gotLocation(loc) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func gotLocation(_ loc: CLLocation) {
        guard active, !finished else { return }
        guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 30 else { return }
        if place == nil, placeLookup == nil {
            let p = PlaceLookup()
            placeLookup = p
            p.name(for: loc) { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
        guard running, cur.kind == .run else { lastLoc = nil; return }
        // 빌드 27: 실시간 속도 — CLLocation.speed (정확도 20 m 미만만), 지수 이동 평균 alpha 0.3
        if loc.speed >= 0, loc.horizontalAccuracy < 20 {
            let now = Date()
            let fresh: Bool = curSpeed <= 0 || now.timeIntervalSince(lastSpeedAt) > 10
            curSpeed = fresh ? loc.speed : (0.3 * loc.speed + 0.7 * curSpeed)
            lastSpeedAt = now
        }
        if let prev = lastLoc {
            let d: Double = loc.distance(from: prev)
            if d < 100 { segDist += d }       // 튀는 값은 버림
        }
        lastLoc = loc
        if runLike {
            if lastRouteLoc == nil || loc.distance(from: lastRouteLoc!) >= 8 {
                lastRouteLoc = loc
                // 62번: 높이(못 쟀으면 nil) · 시작부터 초(일시정지 뺀 시간, 구간 시간과 같은 시계)
                let h: Double? = loc.verticalAccuracy > 0 ? loc.altitude : nil
                routePts.append(RoutePt(a: loc.coordinate.latitude, o: loc.coordinate.longitude, h: h, t: total(loc.timestamp)))
            }
            autoSplitIfNeeded()
        }
    }

    /// GPS 러닝: 1km 넘으면 저절로 다음 km (총거리 다 뛰면 끝 → autoDone)
    private func autoSplitIfNeeded() {
        // 18번: 인터벌 러닝 거리 단계 — 그 거리를 뛰면 다음 단계
        if isInterval {
            guard useGPS, active, !finished, running, let m = cur.autoM, segDist >= Double(m) else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if let rec = advanceCore(Date(), manual: false) { autoDone = rec }
            return
        }
        guard isRunKind, useGPS, active, !finished, running, segDist >= 1000 else { return }
        let now = Date()
        undoPoint = nil; canUndo = false
        closeSeg(now)
        if runKm == 0 && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            autoDone = finish(complete: true)
            return
        }
        idx = splits.count
        segStart = now; segPaused = 0
        segDist = 0
        segStepStart = steps
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        persist()
    }

    // MARK: 빌드 24 · 앱이 꺼져도 이어서 (phone_run.json)
    // 시작 · 넘기기 · 되돌리기 · 일시정지 · 1 km 자동 넘김 때마다 + 운동 중 5초마다 저장.
    // 끝내거나 버리면 지움. 앱을 켤 때 파일이 있고 시작한 지 12시간 안이면 3 · 2 · 1 없이 바로 이어서.
    // 시간은 시계 기준이라 꺼져 있던 동안도 운동 시간에 들어감 (일시정지 중이었으면 그대로 일시정지).

    static let snapFile = "phone_run.json"

    struct Snapshot: Codable {
        var mode: Mode
        var title: String
        var sets: Int
        var seq: [Seg]
        var idx: Int
        var splits: [Int]
        var running: Bool
        var startDate: Date
        var segStart: Date
        var pauseAt: Date?
        var segPaused: Double
        var useGPS: Bool
        var segDist: Double
        var segDists: [Double?]
        var settings: Settings
        var simWord: String
        var hasPFTBest: Bool
        var kind: String?
        var runKm: Int
        var place: String?
        var routePts: [RoutePt]
        var steps: Double
        var segStepStart: Double
        var segSteps: [Double?]
        var from: String
        // 18번 (예전 파일엔 없음)
        var program: Program? = nil
        var work: [Int?]? = nil
        var actual: [Int?]? = nil
        var kgs: [Double?]? = nil
        var doneAt: Int? = nil
    }

    func persist() {
        guard active, !finished, !Demo.enabled else { return }
        let snap = Snapshot(mode: mode, title: title, sets: sets, seq: seq, idx: idx, splits: splits, running: running,
                            startDate: startDate, segStart: segStart, pauseAt: pauseAt, segPaused: segPaused,
                            useGPS: useGPS, segDist: segDist, segDists: segDists, settings: settings, simWord: simWord,
                            hasPFTBest: hasPFTBest, kind: kind, runKm: runKm, place: place, routePts: routePts,
                            steps: steps, segStepStart: segStepStart, segSteps: segSteps, from: from.rawValue,
                            program: program, work: segWork, actual: segActual, kgs: segKg, doneAt: doneAt)
        JSONStore.save(snap, PhoneRunEngine.snapFile)
    }

    static func clearSnapshot() {
        try? FileManager.default.removeItem(at: JSONStore.url(snapFile))
    }

    /// 이어 받을 기록 (없거나 12시간 넘었으면 nil, 넘은 것은 지움)
    static func pendingSnapshot(now: Date = Date()) -> Snapshot? {
        guard let s = JSONStore.load(Snapshot.self, snapFile) else { return nil }
        if now.timeIntervalSince(s.startDate) > 12 * 3600 || s.seq.isEmpty { clearSnapshot(); return nil }
        return s
    }

    /// 저장해 둔 상태로 바로 이어서 (3 · 2 · 1 없음)
    func resume(_ s: Snapshot) {
        guard !active else { return }
        mode = s.mode; title = s.title; sets = s.sets; seq = s.seq
        idx = min(s.idx, max(0, s.seq.count - 1)); splits = s.splits; running = s.running
        startDate = s.startDate; segStart = s.segStart; pauseAt = s.pauseAt; segPaused = s.segPaused
        useGPS = s.useGPS; segDist = s.segDist; segDists = s.segDists
        if segDists.count < seq.count { segDists += Array(repeating: nil, count: seq.count - segDists.count) }
        settings = s.settings; simWord = s.simWord; hasPFTBest = s.hasPFTBest
        kind = s.kind; runKm = s.runKm; place = s.place; routePts = s.routePts
        segSteps = s.segSteps
        if segSteps.count < seq.count { segSteps += Array(repeating: nil, count: seq.count - segSteps.count) }
        segStepStart = s.segStepStart
        from = Scr(rawValue: s.from) ?? .home
        program = s.program
        let n: Int = seq.count
        segWork = PhoneRunEngine.padded(s.work, n)
        segActual = PhoneRunEngine.padded(s.actual, n)
        segKg = PhoneRunEngine.padded(s.kgs, n)
        doneAt = s.doneAt; partialLast = false; cdKey = String()
        // 걸음: 센서는 0부터 다시 셈 → 저장한 걸음에 이어서 더함
        steps = s.steps; stepBase = s.steps; rawSteps = 0; pausedSteps = 0; pauseStepAt = 0
        undoPoint = nil; canUndo = false
        finished = false; autoDone = nil; lastLoc = nil; lastRouteLoc = nil
        active = true
        if isRunKind { startSteps(Date()) }
        if useGPS { startGPS() }
        // 19번: 이어 받을 때는 말없이 상태만 (지난 거리 안내를 다시 하지 않음)
        VoiceCoach.shared.begin(settings, seq: seq, runCard: runLike, open: growsOpen, announce: false, kind: kind)
        startVoice()
        startTimed()
        persist()
    }

    /// 저장해 둔 배열을 구간 수에 맞춤 (모자라면 nil 로 채움)
    static func padded<T>(_ a: [T?]?, _ n: Int) -> [T?] {
        let x: [T?] = a ?? []
        return x.count >= n ? x : x + Array(repeating: nil, count: n - x.count)
    }
}

// MARK: - 화면 높이별 크기 (6.1" 기준 1.0, SE 는 줄이고 Pro Max 는 키움)

struct PhoneLiveMetrics {
    let k: CGFloat

    init(height h: CGFloat) {
        let v: CGFloat = h / 760
        k = max(0.8, min(1.14, v))
    }

    var totalFont: CGFloat { 76 * k }
    var segFont: CGFloat { 64 * k }
    var icon: CGFloat { 52 * k }
    // 빌드 21 (시안 A-1): 지금 종목 이름 · NEXT 줄은 키우고, Next 버튼은 70% 로 줄여 위로 올림
    var nameFont: CGFloat { 28 * min(k, 1.08) }
    var detailFont: CGFloat { 16 * min(k, 1.08) }
    var nextFont: CGFloat { 27 * min(k, 1.08) }
    var nextIcon: CGFloat { 34 * min(k, 1.08) }
    var nextLabel: CGFloat { 16.5 * min(k, 1.08) }
    var top: CGFloat { 24 * k }
    var segTop: CGFloat { 36 * k }
    var nameTop: CGFloat { 10 * k }
    var dividerTop: CGFloat { 26 * k }
    var buttonH: CGFloat { max(58, min(74, 66 * k)) }
    var buttonFont: CGFloat { 22 * min(k, 1.08) }
    var pillH: CGFloat { max(46, min(58, 53 * k)) }
    /// Next 버튼과 아래 세 버튼(End · Undo · Pause) 사이
    var pillGap: CGFloat { 27 * k }
    /// 아래 버튼 묶음(Next · End · Undo · Pause) 밑의 여백 — 버튼들이 화면 맨 아래에 붙지 않고 손이 닿기 쉬운 높이로 올라옴
    var bottom: CGFloat { 90 * k }
}

// MARK: - 화면

struct PhoneLiveView: View {
    let r = Router.shared
    @State private var eng = PhoneRunEngine()
    @State private var askEnd = false
    @State private var flash: Double = 0
    /// 시작 전 3 · 2 · 1 (nil = 세는 중 아님)
    @State private var count: Int? = nil
    @State private var countTimer: Timer? = nil
    @State private var saveTimer: Timer? = nil
    /// 18번 · 기능성: 세트 끝 → 실제 횟수 · 무게 확인
    @State private var setAsk: StrengthSetAsk? = nil

    private var req: PhoneRunRequest { r.phoneRun ?? PhoneRunRequest(mode: .sim) }

    var body: some View {
        GeometryReader { g in
            let m = PhoneLiveMetrics(height: g.size.height)
            content(m)
                .frame(width: g.size.width, height: g.size.height)
        }
        .overlay {
            C.accent.opacity(flash * 0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .overlay { if let n = count { countdownView(n) } }
        .onAppear(perform: begin)
        .onDisappear(perform: leave)
        .onChange(of: eng.autoDone) { _, rec in
            if let rec {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                done(rec)
            }
        }
        // 18번: 시간으로 저절로 넘어갈 때도 번쩍 + 진동
        .onChange(of: eng.advanceCount) { _, _ in
            guard eng.isNewKind else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            flashNow()
        }
        .sheet(item: $setAsk) { a in
            StrengthSetSheet(ask: a) { reps, kg in
                setAsk = nil
                advanceNow(reps: reps, kg: kg)
            }
            .presentationDetents([.height(340)])
            .presentationBackground(Color(hex: 0x1C1C1E))
            .preferredColorScheme(.dark)
        }
        .alert("End workout?", isPresented: $askEnd) {
            Button("Save") { save() }
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the segments you've done so far?")
        }
    }

    private func content(_ m: PhoneLiveMetrics) -> some View {
        VStack(spacing: 0) {
            // 빌드 24: 제목 / ● iPhone · No HR / n / 16 / 막대 (워치 같이 보기 화면과 같은 머리)
            LiveHeader(f: frame(Date()), status: "iPhone · No HR", live: false, idPrefix: "phone")
            if eng.isNewKind {
                // 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 — 큰 남은 시간 화면
                TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                    TimerLiveBody(f: timerFace(ctx.date), total: eng.total(ctx.date), m: m,
                                  pace: eng.runLike && eng.useGPS ? LivePace.text(el: eng.segEl(ctx.date), dist: eng.segDist,
                                                                                  imperial: false, speed: eng.speedNow(ctx.date)) : nil,
                                  paceColor: paceColor(ctx.date))
                }
                .padding(.top, m.top * 0.6)
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                    LiveBody(f: frame(ctx.date), m: m, idPrefix: "phone")
                }
                .padding(.top, m.top * 0.6)
                LiveNextRow(next: eng.nextSeg, m: m)
            }
            Spacer(minLength: 16)
            nextButton(m)
            HStack(spacing: 10) {
                endPill(m)
                undoPill(m)
                pausePill(m)
            }
            .padding(.top, m.pillGap)
            .padding(.bottom, m.bottom)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 위

    /// 엔진 → 화면 한 장면
    private func frame(_ now: Date) -> LiveFrame {
        LiveFrame(mode: eng.mode, title: eng.title, seq: eng.seq, idx: eng.idx, segEl: eng.segEl(now), total: eng.total(now),
                  running: eng.running, open: eng.growsOpen || eng.isNewKind,
                  segDist: eng.useGPS ? eng.segDist : nil, totalDist: eng.useGPS ? eng.totalDist : nil,
                  runKind: eng.isRunKind,
                  speed: eng.useGPS ? eng.speedNow(now) : nil)
    }

    /// 18번: 새 종류 화면 한 장
    private func timerFace(_ now: Date) -> TimerFace {
        TimerFaces.make(kind: eng.kind ?? "", seq: eng.seq, idx: eng.idx, segEl: eng.segEl(now), total: eng.total(now),
                        cap: eng.amrapCap, segDist: eng.useGPS ? eng.segDist : nil, done: eng.doneAt, task: eng.program?.task)
    }

    /// 인터벌 러닝: 목표 페이스보다 빠르면 초록, 느리면 빨강
    private func paceColor(_ now: Date) -> Color {
        let sp: Double = eng.speedNow(now)
        guard let tp = eng.cur.tp, sp > 0.5 else { return C.text2 }
        return Int(1000 / sp) <= tp ? C.good : C.bad
    }

    // MARK: 아래 버튼

    /// 가운데 큰 버튼 글자 (18번 새 종류는 종류마다 다름)
    private var nextLabel: String {
        if eng.isRunKind && eng.useGPS { return "Auto split every 1 km" }
        switch eng.kind ?? "" {
        case WKind.emom: return eng.doneAt == nil ? "Done" : "Resting"
        case WKind.amrap: return "Round done"
        case WKind.strength: return eng.cur.tag == "rest" ? "Skip rest" : "Set done"
        case WKind.interval: return eng.hasNext ? "Next step" : "Finish"
        case WKind.tabata: return "Skip"
        default: return (eng.hasNext || eng.growsOpen) ? "Next" : "Finish"
        }
    }

    private var nextOn: Bool {
        eng.running && !(eng.isRunKind && eng.useGPS) && !(eng.kind == WKind.emom && eng.doneAt != nil)
    }

    private func nextButton(_ m: PhoneLiveMetrics) -> some View {
        YellowButton(height: m.buttonH, radius: m.buttonH / 2, enabled: nextOn,
                     action: { next() }) {
            HStack(spacing: 10) {
                Text(nextLabel.l10n)
                Text("›")
            }
            .font(F.t(m.buttonFont, .semibold))
        }
        .accessibilityIdentifier("phone.next")
    }

    /// ■ End (빨강 글자, 빨강 22% 바탕)
    private func endPill(_ m: PhoneLiveMetrics) -> some View {
        Button { askEnd = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill").font(.system(size: 13, weight: .semibold))
                Text("End").font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(C.bad)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color(hex: 0xFF453A, alpha: 0.22), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("phone.end")
    }

    /// ❚❚ Pause / ▶ Resume (회색 12%)
    private func pausePill(_ m: PhoneLiveMetrics) -> some View {
        Button { eng.togglePause() } label: {
            HStack(spacing: 7) {
                Image(systemName: eng.running ? "pause.fill" : "play.fill").font(.system(size: 13, weight: .semibold))
                Text(eng.running ? "Pause" : "Resume").font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(eng.running ? Color.white : C.accent)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color.white.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("phone.pause")
    }

    /// ↩ Undo (회색 12%, 되돌릴 것이 없으면 흐리게): 방금 넘긴 것을 한 번 되돌림
    private func undoPill(_ m: PhoneLiveMetrics) -> some View {
        let on: Bool = eng.canUndo
        return Button { undo() } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 13, weight: .semibold))
                Text("Undo").font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.white : C.text3)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color.white.opacity(on ? 0.12 : 0.05), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .disabled(!on)
        .accessibilityIdentifier("phone.undo")
    }

    // MARK: 시작 전 3 · 2 · 1

    /// 화면 전체를 덮는 큰 숫자. 숫자마다 가벼운 진동, 시작 순간은 세게. 누르면 취소하고 돌아감
    private func countdownView(_ n: Int) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()      // 뒤의 준비 화면이 비치지 않게 완전히 가림
            VStack(spacing: 14) {
                Text(verbatim: "\(n)")
                    .font(F.num(160, .bold)).foregroundStyle(C.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.25), value: n)
                    .accessibilityIdentifier("phone.count")
                Text("Tap to cancel").font(F.t(15)).foregroundStyle(C.text2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { cancelCount() }
        .transition(.opacity)
    }

    /// 18번: 타이머 운동은 3 · 2 · 1 을 소리로도
    private var countVoice: Bool { req.mode == .training && WKind.isTimer(req.program?.kind) }

    private func startCount() {
        count = 3
        if countVoice { VoiceCoach.shared.count(Store.shared.settings, 3) }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async { countTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        countTimer = t
    }

    private func countTick() {
        guard let c = count else { return }
        if c > 1 {
            count = c - 1
            if countVoice { VoiceCoach.shared.count(Store.shared.settings, c - 1) }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } else {
            stopCountTimer()
            withAnimation(.easeOut(duration: 0.15)) { count = nil }
            if !eng.active { eng.start(req) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            flashNow()
        }
    }

    private func stopCountTimer() {
        countTimer?.invalidate()
        countTimer = nil
    }

    private func cancelCount() {
        stopCountTimer()
        count = nil
        UIApplication.shared.isIdleTimerDisabled = false
        r.go(req.from)
    }

    // MARK: 동작

    private func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        // 3 · 2 · 1 을 센 뒤 시작 (화면 확인용 --nocount 는 바로 시작)
        if !eng.active && count == nil {
            // 빌드 24: 앱이 꺼졌다 켜졌으면 3 · 2 · 1 없이 그대로 이어서
            if req.resume, let snap = PhoneRunEngine.pendingSnapshot() {
                eng.resume(snap)
            } else if CommandLine.arguments.contains("--nocount") { eng.start(req) } else { startCount() }
        }
        // 운동 중 5초마다 저장 (앱이 갑자기 꺼져도 이어 받게)
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in eng.persist() }
        // 왼쪽 끝에서 밀기 = End 확인 (실수로 나가지 않게). 세는 중이면 취소
        r.backAction = { if count != nil { cancelCount() } else { askEnd = true } }
    }

    private func leave() {
        saveTimer?.invalidate(); saveTimer = nil
        stopCountTimer()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func undo() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        eng.undo()
    }

    private func next() {
        // 18번 · 기능성: 세트 끝 → 실제 횟수 · 무게 확인 (지난번 값으로 미리 채움) → 휴식
        if eng.kind == WKind.strength && eng.cur.tag == "set" && eng.running {
            let v = eng.lastSetValues()
            setAsk = StrengthSetAsk(name: eng.cur.name, no: eng.cur.no ?? 1, reps: v.reps, kg: v.kg)
            return
        }
        advanceNow(reps: nil, kg: nil)
    }

    private func advanceNow(reps: Int?, kg: Double?) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if !eng.isNewKind { flashNow() }          // 새 종류는 advanceCount 로 번쩍
        if let rec = eng.advance(reps: reps, kg: kg) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            done(rec)
        }
    }

    private func flashNow() {
        withAnimation(.linear(duration: 0.06)) { flash = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.26)) { flash = 0 }
        }
    }

    private func save() {
        if let rec = eng.endNow() { done(rec) }
    }

    /// 9번: 편집 화면(.builder) 등 탭이 아닌 곳에서 시작했으면 기록 종류의 탭으로 돌아가기
    /// (안 그러면 기록 화면 뒤로 가기가 "‹ Race" 로 나오고 편집 화면으로 감)
    private func backTab(_ mode: Mode) -> Scr {
        let from: Scr = eng.from
        if [.home, .training, .sim, .race].contains(from) { return from }
        switch mode {
        case .training: return .training
        case .race: return .race
        case .pft: r.testTab = "pft"; return .sim
        case .sim: r.testTab = "sim"; return .sim
        }
    }

    private func done(_ rec: Record) {
        let from: Scr = backTab(rec.mode)
        UIApplication.shared.isIdleTimerDisabled = false
        Store.shared.addPhoneRecord(rec)
        // addPhoneRecord 가 source = "phone" 을 붙여 저장 → 저장된 것으로 상세 열기
        var shown = rec
        shown.source = "phone"
        // 기록 상세 위로 "수고했어요" 카드 (51번)
        r.showFinish(shown, from: from)
    }

    private func discard() {
        let from: Scr = eng.from   // 버리기는 시작한 화면(편집 화면 포함)으로 그대로
        eng.discard()
        UIApplication.shared.isIdleTimerDisabled = false
        r.go(from)
    }
}

// MARK: - Start on iPhone (탭 화면에 놓는 작은 회색 버튼)

struct StartOnPhoneButton: View {
    let mode: Mode
    var program: Program? = nil
    /// 시작 직전에 할 일 (예: 시트 닫기). 있으면 닫힌 뒤 조금 있다가 시작
    var before: (() -> Void)? = nil
    /// true = 가로로 꽉 찬 큰 노란 버튼 (PFT 첫 화면)
    var big: Bool = false
    @State private var confirm = false

    @ViewBuilder
    private var label: some View {
        if big {
            YellowButton(height: 50, radius: 16, action: { confirm = true }) {
                Text("Start on iPhone")
            }
        } else {
            Button { confirm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone").font(.system(size: 14, weight: .semibold))
                    Text("Start on iPhone").font(F.t(14, .semibold)).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 36)
                .background(Color.white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(Press(scale: 0.96))
            .fixedSize()
        }
    }

    var body: some View {
        label
        .accessibilityIdentifier("startOnPhone." + mode.rawValue)
        // 시작 전 확인: 아이폰 기록은 워치 기능(심박 등)을 못 씀
        .alert("Start on iPhone?", isPresented: $confirm) {
            Button("Start") {
                if let before {
                    before()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Router.shared.startOnPhone(mode, program: program) }
                } else {
                    Router.shared.startOnPhone(mode, program: program)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Recording on iPhone can't measure heart rate, calories or HR zones, and there are no watch vibration alerts. Only split times are recorded (plus GPS distance for outdoor runs).")
        }
    }
}
