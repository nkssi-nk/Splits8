import Foundation
import WatchConnectivity
import Observation

/// 워치 저장소: 아이폰에서 받은 설정·프로그램·친구, 워치에서 만든 Quick training
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()

    private(set) var ctx: WatchContext
    private(set) var quickSaved: [Program] = []

    private let ctxFile = "w_ctx.json"
    private let quickFile = "w_quick.json"

    override init() {
        ctx = JSONStore.load(WatchContext.self, "w_ctx.json")
            ?? WatchContext(settings: Settings(), programs: Program.presets(), friend: nil,
                            simBest: nil, simBestTotal: nil, segBests: [:])
        super.init()
        GlowTheme.current = ctx.settings.glow
        quickSaved = JSONStore.load([Program].self, quickFile) ?? []
    }

    var settings: Settings { ctx.settings }
    var div: Division { ctx.settings.div }

    /// 목록: 워치 Quick + 아이폰 프로그램 (아이폰에 이미 올라간 Quick 은 중복 제거)
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

    /// Quick training 저장 → 아이폰으로
    func saveQuick(_ seq: [ProgItem]) -> Program {
        let n = quickSaved.count + 1
        let p = Program(id: "q" + UUID().uuidString.prefix(8), name: "Quick \(n) · \(Fm.dm.string(from: Date()))",
                        sets: 1, seq: seq, quick: true)
        quickSaved.insert(p, at: 0)
        JSONStore.save(quickSaved, quickFile)
        if let d = try? JSONStore.enc.encode(p) {
            WCSession.default.transferUserInfo([SyncKey.quick: d])
        }
        return p
    }

    func send(_ r: Record) {
        guard let d = try? JSONStore.enc.encode(r) else { return }
        WCSession.default.transferUserInfo([SyncKey.record: d])
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
        case .race: return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: s.goals.count == 16 ? s.goals : Defaults.goals)
        case .sim: return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: simTargets)
        case .training: return SeqBuilder.training(program ?? Program.presets()[0], div: s.div, bests: ctx.segBests)
        case .pft: return PFT.seq(div: s.div, targets: ctx.pftBest)
        }
    }

    // MARK: WCSession

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ c: [String: Any]) {
        guard let d = c[SyncKey.context] as? Data,
              let v = try? JSONStore.dec.decode(WatchContext.self, from: d) else { return }
        DispatchQueue.main.async {
            GlowTheme.current = v.settings.glow      // 아이폰에서 고른 배경 빛 색 (화면보다 먼저 넣어 둠)
            self.ctx = v
            JSONStore.save(v, self.ctxFile)
            WorkoutEngine.shared.settings = v.settings
        }
    }
}
