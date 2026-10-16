import Foundation
import HealthKit
import UIKit
import Observation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - 52번 · 워치 운동을 아이폰에 같이 보여 주기
//
// 워치가 미러링을 시작하면 아이폰 앱이 뒤에서 켜지고 여기로 세션이 옴.
// 워치가 보내는 LiveState 를 받아 화면(WatchLiveView) · 잠금 화면(Live Activity)에 보여 주고,
// 아이폰에서 누른 Next · Undo · Pause · End 는 워치로 보냄. 기록은 워치가 끝낸 뒤 평소처럼 도착함.

@Observable
final class WatchMirror: NSObject, HKWorkoutSessionDelegate {
    static let shared = WatchMirror()

    @ObservationIgnored private let health = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?

    /// 워치에서 받은 마지막 상태
    private(set) var state: LiveState?
    /// 그 상태를 받은 시각 (아이폰 시계 기준)
    private(set) var received = Date()
    /// 미러링 중
    private(set) var on = false
    /// 워치가 운동을 끝냄 → 기록이 오기를 기다리는 중
    private(set) var ended = false
    /// 한동안 소식이 없음 (워치와 끊김)
    private(set) var reconnecting = false
    /// 워치에서 버림(Discard): finished 를 한 번도 못 받고 세션이 끝남 → 기록이 안 오니 바로 홈으로
    private(set) var discarded = false

    @ObservationIgnored private var watchdog: Timer?
    /// close 가 예약한 '홈으로 가기'를 새 미러링이 시작되면 무시하기 위한 세대 번호
    @ObservationIgnored private var closeGen = 0
    @ObservationIgnored private var lastCard: LiveCardState?
    @ObservationIgnored private var lastCardAt = Date.distantPast
    #if canImport(ActivityKit)
    @ObservationIgnored private var activity: Activity<Splits8Activity>?
    #endif

    /// 앱을 켤 때 한 번 (워치가 미러링을 시작하면 이 처리기가 불림)
    func setUp() {
        // 빌드 27: 지난번에 끝내지 못하고 남은 잠금 화면 카드 정리 (앱을 켤 때)
        if !Demo.enabled { endLeftoverActivities() }
        guard HKHealthStore.isHealthDataAvailable(), !Demo.enabled else { return }
        health.workoutSessionMirroringStartHandler = { [weak self] s in
            DispatchQueue.main.async { self?.attach(s) }
        }
    }

    private func attach(_ s: HKWorkoutSession) {
        closeGen += 1          // 지난 세션이 예약해 둔 '홈으로 가기'를 무시
        session = s
        s.delegate = self
        on = true
        ended = false
        reconnecting = false
        discarded = false
        state = nil
        received = Date()
        startWatchdog()
        let r = Router.shared
        r.liveMirror = true
        // 아이폰으로 직접 기록 중이면 화면을 바꾸지 않음
        if r.scr != .phoneLive && UIApplication.shared.applicationState == .active { r.go(.watchLive) }
    }

    // MARK: 받기

    private func apply(_ st: LiveState) {
        let first: Bool = state == nil
        state = st
        received = Date()
        reconnecting = false
        if st.finished {
            // 빌드 27: 워치가 끝냄 → 세션 종료 소식을 기다리지 않고 잠금 화면 카드를 바로 끝냄 (5초 뒤 사라짐)
            ended = true
            endActivity()
        } else {
            updateActivity(force: first)
        }
    }

    /// 아이폰 화면을 처음 열었을 때 (앱이 뒤에서 켜졌다가 앞으로 나옴)
    func appBecameActive() {
        let r = Router.shared
        if on && !ended && r.scr != .phoneLive && r.scr != .watchLive && r.finish == nil { r.go(.watchLive) }
        endLeftoverActivities()
        updateActivity(force: true)
    }

    /// 빌드 27: 워치 기록이 도착했을 때 (Store 의 WCSession 받기에서 부름)
    func recordArrived() {
        guard !Demo.enabled else { return }
        endLeftoverActivities()
    }

    private func startWatchdog() {
        watchdog?.invalidate()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.check() }
        RunLoop.main.add(t, forMode: .common)
        watchdog = t
    }

    private func check() {
        guard on, !ended else { return }
        let stale: Bool = Date().timeIntervalSince(received) > 12
        if stale != reconnecting {
            reconnecting = stale
            updateActivity(force: true)
        }
    }

    // MARK: 보내기

    func send(_ c: LiveCommand) {
        guard on, !ended else { return }
        if Demo.enabled { demoCommand(c); return }
        guard let s = session, let d = LivePacket(command: c).data() else { return }
        s.sendToRemoteWorkoutSession(data: d) { _, _ in }
    }

    // MARK: 끝

    private func close() {
        watchdog?.invalidate()
        watchdog = nil
        session = nil
        on = false
        ended = true
        // finished 를 한 번도 못 받고 끝남 = 워치에서 버림 → 기록을 기다리지 않고 바로 홈으로
        discarded = state?.finished != true
        endActivity()
        let r = Router.shared
        r.liveMirror = false
        // 끝난 뒤: 버렸으면 1.5초, 저장 중이면 기록이 15초 안에 안 올 때 홈으로.
        // 그 사이 새 미러링이 시작되면(closeGen 이 바뀜) 이 예약은 무시
        let g = closeGen
        DispatchQueue.main.asyncAfter(deadline: .now() + (discarded ? 1.5 : 15)) {
            guard g == self.closeGen else { return }
            if r.scr == .watchLive && r.finish == nil { r.go(.home) }
        }
    }

    // MARK: HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended || toState == .stopped {
            DispatchQueue.main.async { self.close() }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        let states: [LiveState] = data.compactMap { LivePacket.read($0)?.state }
        guard let last = states.last else { return }
        DispatchQueue.main.async { self.apply(last) }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        DispatchQueue.main.async {
            self.reconnecting = true
            self.updateActivity(force: true)
        }
    }

    // MARK: 잠금 화면 · 다이내믹 아일랜드 (Live Activity)

    func card(now: Date = Date()) -> LiveCardState? {
        guard let st = state, let cur = st.cur else { return nil }
        let seg: Int = st.segEl(now, received: received)
        let tot: Int = st.total(now, received: received)
        let nx: Seg? = st.nextSeg
        return LiveCardState(segName: cur.name, segIcon: cur.icon, segDetail: cur.kind == .rox ? "Transition".l10n : cur.detail,
                             nextName: nx?.name ?? (st.open ? nil : "Finish".l10n), nextIcon: nx?.icon,
                             idx: st.seq.liveCountNow(st.idx) - 1, count: st.open ? 0 : st.seq.liveCountTotal,
                             progress: st.open ? nil : st.seq.liveProgress(st.idx),
                             segStart: now.addingTimeInterval(-Double(seg)), totalStart: now.addingTimeInterval(-Double(tot)),
                             paused: !st.running, segSec: seg, totalSec: tot, hr: st.hr, zone: st.zone, kcal: st.kcal,
                             reconnecting: reconnecting, finished: st.finished)
    }

    private var liveTitle: String {
        guard let st = state else { return "" }
        return st.mode == .training ? st.title : st.mode.name
    }

    /// 구간 · 멈춤이 바뀌면 바로, 심박만 바뀌면 15초에 한 번
    private func updateActivity(force: Bool) {
        #if canImport(ActivityKit)
        guard let c = card() else { return }
        let changed: Bool = lastCard.map { $0.idx != c.idx || $0.paused != c.paused || $0.reconnecting != c.reconnecting || $0.finished != c.finished } ?? true
        guard force || changed || Date().timeIntervalSince(lastCardAt) >= 15 else { return }
        lastCard = c
        lastCardAt = Date()
        // 빌드 27: 3분 동안 새 소식이 없으면 잠금 화면 카드가 흐려짐 (staleDate)
        let stale: Date = Date().addingTimeInterval(180)
        if let a = activity {
            Task { await a.update(ActivityContent(state: c, staleDate: stale)) }
            return
        }
        guard !ended, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // 시작은 앱이 앞에 있을 때만 됨 (아이폰 규칙) → 안 되면 앱을 열 때 다시 시도
        activity = try? Activity.request(attributes: Splits8Activity(title: liveTitle),
                                         content: ActivityContent(state: c, staleDate: stale), pushType: nil)
        #endif
    }

    private func endActivity() {
        #if canImport(ActivityKit)
        guard let a = activity else { return }
        activity = nil
        var c: LiveCardState = card() ?? lastCard ?? a.content.state
        c.finished = true
        c.paused = true
        // 빌드 27: 운동이 끝나고 5초 뒤 잠금 화면에서 사라짐 (예전엔 2분)
        let gone: Date = Date().addingTimeInterval(5)
        Task { await a.end(ActivityContent(state: c, staleDate: nil), dismissalPolicy: .after(gone)) }
        #endif
    }

    /// 빌드 27: 지금 쓰는 카드가 아닌 Splits8 잠금 화면 카드를 모두 바로 끝냄
    /// (앱이 꺼졌거나 세션 종료 소식을 못 받아 남아 있던 카드)
    private func endLeftoverActivities() {
        #if canImport(ActivityKit)
        let keepID: String? = activity?.id
        for a in Activity<Splits8Activity>.activities where a.id != keepID {
            // 이미 끝낸 카드(방금 운동이 끝나 5초 뒤 사라질 카드 포함)는 그대로 둠
            if a.activityState == .ended || a.activityState == .dismissed { continue }
            var c: LiveCardState = a.content.state
            c.finished = true
            c.paused = true
            Task { await a.end(ActivityContent(state: c, staleDate: nil), dismissalPolicy: .immediate) }
        }
        #endif
    }

    // MARK: 화면 확인용 (--mirror)

    func demoStart() {
        let div = Division.of("openM")
        let seq: [Seg] = SeqBuilder.full(div: div, rox: true, targets16: Defaults.goals)
        let idx = 6
        let st = LiveState(mode: .sim, title: "Full Simulation", seq: seq, idx: idx,
                           splits: seq.prefix(idx).map { Int(Double($0.target) * 1.03) }, segElapsed: 80, running: true,
                           hr: 165, kcal: 286, zone: 4, canUndo: true, finished: false, vsWord: "VS GOAL", delta: 14)
        state = st
        received = Date()
        on = true
        ended = false
        reconnecting = CommandLine.arguments.contains("--mirrorlost")
        Router.shared.liveMirror = true
    }

    private func demoCommand(_ c: LiveCommand) {
        guard var st = state else { return }
        let now = Date()
        switch c {
        case .next:
            st.splits.append(st.segEl(now, received: received))
            st.idx = min(st.idx + 1, st.seq.count - 1)
            st.segElapsed = 0
            st.canUndo = true
        case .undo:
            if st.canUndo, let last = st.splits.popLast() {
                st.idx = max(0, st.idx - 1)
                st.segElapsed = last + st.segEl(now, received: received)
                st.canUndo = false
            }
        case .pause:
            st.segElapsed = st.segEl(now, received: received); st.running = false
        case .resume:
            st.running = true
        case .end:
            st.finished = true
        }
        apply(st)
    }
}
