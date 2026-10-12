import Foundation
import WatchConnectivity
import Observation
import WidgetKit

/// 워치 저장소: 아이폰에서 받은 설정·프로그램·친구, 워치에서 만든 Quick training
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()

    private(set) var ctx: WatchContext
    private(set) var quickSaved: [Program] = []

    private let ctxFile = "w_ctx.json"
    private let quickFile = "w_quick.json"
    private let pendingFile = "w_pending.json"
    /// 아직 아이폰에 전달이 확인되지 않은 기록 (앱이 꺼져도 남게 파일에 저장)
    @ObservationIgnored private var pending: [Record] = []

    override init() {
        ctx = JSONStore.load(WatchContext.self, "w_ctx.json")
            ?? WatchContext(settings: Settings(), programs: Program.presets(), friend: nil,
                            simBest: nil, simBestTotal: nil, segBests: [:])
        super.init()
        GlowTheme.current = ctx.settings.glow
        // 저장된 언어로 번역을 바로 맞춤 (앱을 다시 켜지 않아도 되게)
        L10n.set(ctx.settings.lang)
        pending = JSONStore.load([Record].self, pendingFile) ?? []
        // 63번: 워치에는 마지막 Quick 하나만 남김 (예전 빌드에서 쌓인 Quick 들 정리)
        quickSaved = Array((JSONStore.load([Program].self, quickFile) ?? []).prefix(1))
        JSONStore.save(quickSaved, quickFile)
    }

    var settings: Settings { ctx.settings }
    var div: Division { ctx.settings.div }

    /// 목록: 아이폰 트레이닝 목록이 원본(63번). 워치에는 '방금 만든 Quick' 하나만 위에 붙음
    var programs: [Program] {
        let ids = Set(ctx.programs.map(\.id))
        return quickSaved.filter { !ids.contains($0.id) } + ctx.programs
    }

    /// 화면 캡처용 샘플 (--shot)
    func demoLoad(_ c: WatchContext) { GlowTheme.current = c.settings.glow; ctx = c }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Quick training: 이번 운동에 쓰는 것. 63번 — 아이폰 트레이닝 목록에는 더 이상 자동으로 안 쌓음
    /// (예전: 시작할 때마다 Quick 1, 2, 3… 이 아이폰 · 워치 양쪽에 쌓이고 워치 쪽은 지워지지도 않았음)
    /// 워치에는 마지막 Quick 하나만 남겨 다시 할 수 있게 함. 기록은 평소처럼 아이폰으로 감
    func saveQuick(_ seq: [ProgItem]) -> Program {
        let p = Program(id: "q" + UUID().uuidString.prefix(8), name: "Quick · \(Fm.dm.string(from: Date()))",
                        sets: 1, seq: seq, quick: true)
        quickSaved = [p]
        JSONStore.save(quickSaved, quickFile)
        return p
    }

    /// 기록을 아이폰으로. 전달이 확인될 때까지 보류 목록에도 남겨 둠 (아이폰이 꺼져 있거나 멀어도 안 잃어버리게)
    func send(_ r: Record) {
        guard let d = try? JSONStore.enc.encode(r) else { return }
        pending.append(r)
        if pending.count > 20 { pending.removeFirst(pending.count - 20) }   // 최근 20개까지만
        JSONStore.save(pending, pendingFile)
        WCSession.default.transferUserInfo([SyncKey.record: d])
    }

    /// 기록 전달이 끝남: 잘 갔으면 보류 목록에서 지움
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error == nil,
              let d = userInfoTransfer.userInfo[SyncKey.record] as? Data,
              let r = try? JSONStore.dec.decode(Record.self, from: d) else { return }
        DispatchQueue.main.async {
            self.pending.removeAll { $0.id == r.id }
            JSONStore.save(self.pending, self.pendingFile)
        }
    }

    /// 보류 중인데 지금 보내는 중도 아닌 기록을 다시 보냄 (아이폰이 다시 가까워졌을 때)
    private func resendPending(_ session: WCSession) {
        guard !pending.isEmpty else { return }
        let inFlight = Set(session.outstandingUserInfoTransfers.compactMap { t -> UUID? in
            guard let d = t.userInfo[SyncKey.record] as? Data,
                  let r = try? JSONStore.dec.decode(Record.self, from: d) else { return nil }
            return r.id
        })
        for r in pending where !inFlight.contains(r.id) {
            guard let d = try? JSONStore.enc.encode(r) else { continue }
            session.transferUserInfo([SyncKey.record: d])
        }
    }

    // MARK: 구간 목표

    /// Full Simulation 목표 16개와 비교 이름: 아이폰 Full Sim 화면의 "Compare with" (Goal / Last / 친구) 를 따름
    var simPick: (targets: [Int], word: String) {
        SimTarget.pick(cmp: ctx.settings.simCmp, goals: ctx.settings.goals, last: ctx.simLast,
                       friend: ctx.friend?.splits, friendFirst: ctx.friend?.first, best: ctx.simBest)
    }
    var simTargets: [Int] { simPick.targets }

    func seq(mode: Mode, program: Program?) -> [Seg] {
        let s = ctx.settings
        switch mode {
        case .race: return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: s.goals.count == 16 ? s.goals : Defaults.goals, roxTarget: s.roxTarget)
        case .sim: return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: simTargets, roxTarget: s.roxTarget)
        case .training: return SeqBuilder.training(program ?? Program.presets()[0], div: s.div, bests: ctx.segBests)
        case .pft: return PFT.seq(div: s.div, targets: ctx.pftBest)
        }
    }

    // MARK: WCSession

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
        DispatchQueue.main.async { self.resendPending(session) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    /// 63번: 아이폰 앱에서 고른 언어를 워치에도. 워치 앱을 다음에 열 때부터 적용됨(언어는 앱이 켜질 때 정해짐)
    static func applyLanguage(_ lang: String?) {
        let d = UserDefaults.standard
        if let l = lang, l == "ko" || l == "en" {
            if (d.array(forKey: "AppleLanguages") as? [String])?.first != l { d.set([l], forKey: "AppleLanguages") }
        } else if d.object(forKey: "AppleLanguages") != nil {
            d.removeObject(forKey: "AppleLanguages")
        }
    }

    private func apply(_ c: [String: Any]) {
        guard let d = c[SyncKey.context] as? Data,
              let v = try? JSONStore.dec.decode(WatchContext.self, from: d) else { return }
        DispatchQueue.main.async {
            GlowTheme.current = v.settings.glow      // 아이폰에서 고른 배경 빛 색 (화면보다 먼저 넣어 둠)
            WatchStore.applyLanguage(v.settings.lang)
            L10n.set(v.settings.lang)                // 앱을 다시 켜지 않아도 번역이 바로 바뀜
            self.ctx = v
            JSONStore.save(v, self.ctxFile)
            // 운동 중에는 설정을 바꾸지 않음 (목표·구분이 운동 도중에 바뀌면 기록이 틀어짐)
            if !WorkoutEngine.shared.active { WorkoutEngine.shared.settings = v.settings }
            // 53번: 워치 컴플리케이션(D-day)이 읽는 요약
            let snap = WidgetSnap.make(records: [], settings: v.settings, best: v.simBestTotal)
            if snap.save() { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}
