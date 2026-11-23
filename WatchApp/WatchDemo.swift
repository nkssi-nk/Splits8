import Foundation

/// 화면 캡처 전용: `--shot <이름>` 으로 켜면 건강 앱·아이폰 없이 해당 화면을 바로 보여줍니다.
/// 이름: home programs quick confirm_training confirm_race confirm_sim confirm_pft live controls segments end summary
///       pft_live pft_summary summary_training
/// (화면 확인 작업은 summary 이름으로 PFT 끝 화면을 찍음)
enum WatchDemo {
    static var shot: String? {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--shot"), a.indices.contains(i + 1) { return a[i + 1] }
        return nil
    }
    static var enabled: Bool { shot != nil }
    /// 1.2.7: 조작 화면은 오른쪽으로 밀면 덮이는 화면 (페이지 아님). "segments" = 크라운 1칸(목표 대비), "stats" = 2칸
    static var page: Int { shot == "segments" || shot == "goal" ? 1 : (shot == "stats" ? 2 : 0) }
    static var controls: Bool { shot == "controls" }

    static func apply() {
        guard let name = shot else { return }
        var s = Settings()
        s.division = "openM"; s.age = 32; s.goalTime = 4320
        s.event = RaceEvent(name: "Incheon", loc: "Songdo Convensia",
                            date: Fm.ymd.date(from: "2026-10-18") ?? Date(), time: "09:00")
        var ctx = WatchContext(settings: s, programs: Program.presets(), friend: nil,
                               simBest: nil, simBestTotal: 4210, segBests: [:])
        ctx.pftBest = [262, 236, 188, 245, 82, 295]      // 21:48
        ctx.pftBestTotal = 1308
        let store = WatchStore.shared
        store.demoLoad(ctx)
        let engine = WorkoutEngine.shared
        engine.settings = s
        let nav = WNav.shared
        let preset = Program.presets()[0]

        switch name {
        case "programs": nav.mode = .training; nav.screen = .programs
        case "quick": nav.mode = .training; nav.screen = .quick
        case "confirm_training": nav.mode = .training; nav.program = preset; nav.screen = .confirm
        case "confirm_race": nav.mode = .race; nav.screen = .confirm
        case "confirm_sim": nav.mode = .sim; nav.screen = .confirm
        case "confirm_pft": nav.mode = .pft; nav.screen = .confirm
        case "pft_live":
            let seq = PFT.seq(div: s.div, targets: ctx.pftBest)
            engine.demoRun(mode: .pft, title: PFT.title, seq: seq, idx: 5, elapsed: 134, hr: 171, done: false)
        case "summary", "pft_summary":
            // 끝 화면은 PFT 로 확인 (등급 뱃지 + 최고 기록 대비가 같이 나오는 가장 꽉 찬 모양)
            let seq = PFT.seq(div: s.div, targets: ctx.pftBest)
            engine.demoRun(mode: .pft, title: PFT.title, seq: seq, idx: 0, elapsed: 0, hr: 171, done: true, vsBest: true)
        case "live", "controls", "segments", "goal", "stats", "end":
            let seq = SeqBuilder.full(div: s.div, rox: true, targets16: Defaults.goals)
            engine.demoRun(mode: .race, title: "Incheon", seq: seq, idx: 6, elapsed: 74, hr: 162, done: false)
        case let n where n.hasPrefix("st_z") || n.hasPrefix("run_z") || n.hasPrefix("rox_z"):
            // 1.2.7 화면 확인: 스테이션 · 러닝 · Roxzone × 심박 존 1~5 (레이스 Incheon 구간 6 = Sled Push, 4 = Run 2, 5 = Roxzone)
            let z: Int = Int(String(n.last ?? "3")) ?? 3
            let bpm: [Double] = [100, 118, 136, 155, 176]
            let idx: Int = n.hasPrefix("st") ? 6 : (n.hasPrefix("run") ? 4 : 5)
            let seq = SeqBuilder.full(div: s.div, rox: true, targets16: Defaults.goals)
            engine.demoRun(mode: .race, title: "Incheon", seq: seq, idx: idx, elapsed: idx == 5 ? 21 : 74,
                           hr: bpm[max(0, min(4, z - 1))], done: false)
        case "summary_training":
            let seq = SeqBuilder.training(preset, div: s.div, bests: [:])
            engine.demoRun(mode: .training, title: preset.name, seq: seq, idx: 0, elapsed: 0, hr: 150, done: true)
        default: nav.screen = .home
        }
    }
}
