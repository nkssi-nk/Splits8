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
    static var page: Int { shot == "controls" ? 1 : (shot == "segments" ? 2 : 0) }

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
        case "programs": nav.screen = .programs; nav.mode = .training
        case "quick": nav.screen = .quick; nav.mode = .training
        case "confirm_training": nav.screen = .confirm; nav.mode = .training; nav.program = preset
        case "confirm_race": nav.screen = .confirm; nav.mode = .race
        case "confirm_sim": nav.screen = .confirm; nav.mode = .sim
        case "confirm_pft": nav.screen = .confirm; nav.mode = .pft
        case "pft_live":
            let seq = PFT.seq(div: s.div, targets: ctx.pftBest)
            engine.demoRun(mode: .pft, title: PFT.title, seq: seq, idx: 5, elapsed: 134, hr: 171, done: false)
        case "summary", "pft_summary":
            // 끝 화면은 PFT 로 확인 (등급 뱃지 + 최고 기록 대비가 같이 나오는 가장 꽉 찬 모양)
            let seq = PFT.seq(div: s.div, targets: ctx.pftBest)
            engine.demoRun(mode: .pft, title: PFT.title, seq: seq, idx: 0, elapsed: 0, hr: 171, done: true, vsBest: true)
        case "live", "controls", "segments", "end":
            let seq = SeqBuilder.full(div: s.div, rox: true, targets16: Defaults.goals)
            engine.demoRun(mode: .race, title: "Incheon", seq: seq, idx: 6, elapsed: 74, hr: 162, done: false)
        case "summary_training":
            let seq = SeqBuilder.training(preset, div: s.div, bests: [:])
            engine.demoRun(mode: .training, title: preset.name, seq: seq, idx: 0, elapsed: 0, hr: 150, done: true)
        default: nav.screen = .home
        }
    }
}
