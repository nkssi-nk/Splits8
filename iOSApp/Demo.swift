import Foundation

/// 화면 확인용 예시 데이터 (`--demo` 로 실행했을 때만)
/// 시안에 있던 숫자와 같게 채워서, 스크린샷을 시안과 나란히 비교할 수 있게 합니다.
enum Demo {
    static var enabled: Bool { CommandLine.arguments.contains("--demo") }
    static var onboarded: Bool { CommandLine.arguments.contains("--onboarded") }

    static func settings(_ s: inout Settings) {
        s.hasOnboarded = onboarded
        s.division = "openM"
        s.age = 32
        s.goalTime = 4320
        s.goals = Defaults.goals
        s.event = RaceEvent()      // 시안 I1h · I4 처럼 "대회 없음" 상태
    }

    static func records() -> [Record] {
        var out: [Record] = []
        let runs = [261, 275, 280, 278, 281, 284, 287, 292]
        let stT = [252, 198, 281, 255, 268, 112, 276, 335]
        let div = Division.of("openM")

        // 시안 예시값과 같은 총 시간이 나오도록 비율을 맞춤 (15×Roxzone 18초 포함)
        let base = runs.reduce(0, +) + stT.reduce(0, +)
        func full(_ mode: Mode, _ title: String, _ date: String, total want: Int, goal: Int? = nil) -> Record {
            let scale = Double(want - 15 * 18) / Double(base)
            var segs: [SegResult] = []
            for i in 0..<8 {
                let r = Int(Double(runs[i]) * scale), s = Int(Double(stT[i]) * scale)
                segs.append(SegResult(icon: "run", name: "Run \(i + 1)", detail: "1KM", kind: .run, time: r, target: 270, hr: 158 + (i % 3) * 3, dist: 1000))
                segs.append(SegResult(icon: "roxzone", name: "Roxzone", detail: "TRANSITION", kind: .rox, time: 18, target: 30, hr: 150, dist: nil))
                let st = Station.all[i]
                segs.append(SegResult(icon: st.key, name: st.name, detail: st.detail(div), kind: .st, time: s, target: Defaults.stationGoals[i], hr: 165 + (i % 4) * 4, dist: nil))
                if i < 7 { segs.append(SegResult(icon: "roxzone", name: "Roxzone", detail: "TRANSITION", kind: .rox, time: 18, target: 30, hr: 150, dist: nil)) }
            }
            let fix = want - segs.map(\.time).reduce(0, +)
            if let li = segs.lastIndex(where: { $0.kind == .st }) { segs[li].time += fix }
            let total = segs.map(\.time).reduce(0, +)
            var hr: [HRPoint] = []
            var t = 0
            var i = 0
            while t <= total {
                let x = Double(i) / 120
                let base = 96 + 70 * min(1, x * 6)
                let wig = sin(Double(i) * 0.9) * 5 + sin(Double(i) * 0.23) * 7 + ((i / 7) % 2 == 1 ? 6 : -4)
                hr.append(HRPoint(t: t, b: Int(min(186, base + wig + x * 10))))
                t += max(5, total / 120); i += 1
            }
            return Record(mode: mode, title: title, sets: 1, date: Fm.ymd.date(from: date) ?? Date(), total: total, segs: segs, hr: hr,
                          kcal: 1042, avgHR: 164, maxHR: 183, division: "openM", goal: goal, vsWord: mode == .race ? "VS GOAL" : "VS LAST", vsTarget: goal)
        }
        // Race
        out.append(full(.race, "Incheon", "2026-09-13", total: 4503, goal: 4530))
        out.append(full(.race, "Seoul", "2026-05-23", total: 4711, goal: 4580))
        out.append(full(.race, "Busan", "2026-03-08", total: 4902, goal: 4680))
        // Full Simulation (6회, 시안 그래프 값)
        for (d, t) in [("2026-06-14", 5050), ("2026-07-05", 4951), ("2026-07-26", 4862), ("2026-08-16", 4787), ("2026-09-06", 4667), ("2026-09-20", 4565)] {
            out.append(full(.sim, "Full Simulation", d, total: t))
        }
        // Training
        func training(_ title: String, _ date: String, _ total: Int) -> Record {
            let seq = [("run", "Run", "1KM", SegKind.run, 270), ("sledPush", "Sled Push", "50M · 152KG", SegKind.st, 190),
                       ("run", "Run", "1KM", SegKind.run, 270), ("sledPull", "Sled Pull", "50M · 103KG", SegKind.st, 270)]
            let per = total / seq.count
            let segs = seq.map { SegResult(icon: $0.0, name: $0.1, detail: $0.2, kind: $0.3, time: per, target: $0.4, hr: 160, dist: $0.3 == .run ? 1000 : nil) }
            return Record(mode: .training, title: title, sets: 1, date: Fm.ymd.date(from: date) ?? Date(), total: total, segs: segs,
                          hr: (0...20).map { HRPoint(t: $0 * total / 20, b: 150 + ($0 % 5) * 6) }, kcal: 412, avgHR: 161, maxHR: 176,
                          division: "openM", goal: nil, vsWord: "VS BEST", vsTarget: nil)
        }
        out.append(training("Sled Intervals", "2026-09-24", 1822))
        out.append(training("Wall Ball Run", "2026-09-21", 2410))
        out.append(training("Sled Intervals", "2026-09-17", 1875))
        return out
    }
}
