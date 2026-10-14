import Foundation

// MARK: - 운동이 끝났을 때 한 줄 멘트 (빌드 22 · 51번)
//
// 위에서부터 먼저 맞는 것 하나를 고름 (시안1b 23가지 + PFT 10가지).
// 아이폰은 기록 전체를 보고 모두 채우고, 워치는 아는 것만 채움 (나머지는 비워 두면 그 경우는 건너뜀).
// 같은 기록은 언제 열어도 같은 문장 (seed = 기록 id 로 만든 값).

struct CheerInput {
    var mode: Mode
    var title: String
    var total: Int
    var complete: Bool
    /// 너무 빠른 구간이 있음 (Record.flag == .check)
    var check: Bool
    var start: Date
    var end: Date
    var seed: Int

    var isHIIT = false
    var isRun = false
    var hiitRounds = 0
    var runKm: Double = 0
    /// 높은 심박(Z4–Z5) 비율 0…1. 심박이 없으면 nil (아이폰으로만 기록)
    var hiShare: Double? = nil

    // 아이폰이 기록 목록으로 채우는 것 (워치는 비워 둠)
    var firstEver = false
    var firstFullSim = false
    /// 레이스 목표와의 차이 (total − goal). 음수 = 목표보다 빠름
    var goalDelta: Int? = nil
    /// 이번이 최고 기록(PB)이면 이전 최고와의 차이 (음수)
    var pbDelta: Int? = nil
    /// 지난번(같은 종류)과의 차이
    var lastDelta: Int? = nil
    /// 이번에 최고 기록이 된 스테이션 이름
    var segBest: String? = nil
    var daysToRace: Int? = nil
    var daysSinceLast: Int? = nil
    var streak = 0
    var weekCount = 0

    // PFT: 이전 최고 총 시간 (nil = 첫 도전) · 전에 골드가 있었는지
    var pftPrevBest: Int? = nil
    var pftEverGold = false
}

struct Cheer: Equatable {
    enum Tone: Equatable { case celebrate, normal, check }
    var line: String
    var tone: Tone
    /// 카드 · 워치에 붙는 작은 표시 (★ PB · GOLD · GOAL …). 없으면 nil
    var tag: String? = nil
}

enum CheerPicker {
    static func pick(_ x: CheerInput) -> Cheer {
        // 같은 경우에 문장이 둘이면 기록마다 번갈아 (같은 기록은 늘 같은 문장)
        func alt(_ a: String, _ b: String) -> String { (abs(x.seed) % 2 == 0) ? a : b }

        // 먼저 확인 (1 · 2)
        if x.check { return Cheer(line: String(localized: "Saved. A few splits look off."), tone: .check, tag: "CHECK") }
        if !x.complete { return Cheer(line: String(localized: "Ended early. All the way next time."), tone: .normal) }

        // PFT 는 따로 10가지
        if x.mode == .pft { return pft(x) }

        // 축하할 일 (3 ~ 9)
        if x.firstEver {
            return Cheer(line: alt(String(localized: "Your first record. Welcome to SPLITS8."),
                                   String(localized: "Day one. Every split counts from here.")), tone: .celebrate, tag: "FIRST")
        }
        if x.mode == .race, let g = x.goalDelta, g < 0 {
            return Cheer(line: String(localized: "Goal beaten by \(Fm.t(-g)). Great race."), tone: .celebrate, tag: "GOAL")
        }
        if x.mode == .race {
            return Cheer(line: alt(String(localized: "Race done. You did it."),
                                   String(localized: "That's a race in the books.")), tone: .celebrate, tag: "FINISHER")
        }
        if let p = x.pbDelta, p < 0 {
            return Cheer(line: alt(String(localized: "New personal best!"),
                                   String(localized: "Faster than ever. −\(Fm.t(-p)).")), tone: .celebrate, tag: "★ PB")
        }
        if x.firstFullSim && x.mode == .sim {
            return Cheer(line: String(localized: "All 16 splits. Your first full sim."), tone: .celebrate, tag: "FIRST")
        }

        // 좋아진 것 (10 ~ 13)
        if let s = x.segBest { return Cheer(line: String(localized: "New best on \(s.l10n)."), tone: .normal) }
        if x.mode == .sim, let l = x.lastDelta, l <= -5 {
            return Cheer(line: String(localized: "\(Fm.t(-l)) faster than last time."), tone: .normal)
        }
        if x.isRun {
            let km = Int(x.runKm.rounded(.down))
            if [5, 10, 21, 42].contains(km) || km >= 10 && km % 5 == 0 {
                return Cheer(line: String(localized: "\(km) km done."), tone: .normal)
            }
        }
        if x.isHIIT && x.hiitRounds >= 10 {
            return Cheer(line: String(localized: "\(x.hiitRounds) rounds. Strong finish."), tone: .normal)
        }

        // 꾸준함 · 때 (14 ~ 19)
        if let d = x.daysToRace, (1...7).contains(d) {
            return Cheer(line: String(localized: "\(d) days to race day. Stay sharp."), tone: .normal)
        }
        if let d = x.daysSinceLast, d >= 14 {
            return Cheer(line: alt(String(localized: "Welcome back."), String(localized: "Good to see you again.")), tone: .normal)
        }
        if x.streak >= 3 { return Cheer(line: String(localized: "\(x.streak) days in a row. Keep it going."), tone: .normal) }
        if x.weekCount >= 3 { return Cheer(line: String(localized: "Workout \(x.weekCount) this week."), tone: .normal) }
        let cal = Calendar.current
        if cal.component(.hour, from: x.start) < 7 { return Cheer(line: String(localized: "Early start. Nice work."), tone: .normal) }
        let endH = cal.component(.hour, from: x.end)
        if endH >= 22 || endH < 3 { return Cheer(line: String(localized: "Late session done. Rest well."), tone: .normal) }

        // 힘든 정도 (20 ~ 23)
        if x.total >= 60 * 60 { return Cheer(line: String(localized: "Over an hour. Serious work."), tone: .normal) }
        if x.total >= 30 * 60 || (x.hiShare ?? 0) >= 0.5 {
            return Cheer(line: alt(String(localized: "That was a tough one."), String(localized: "You pushed hard today.")), tone: .normal)
        }
        if x.total >= 10 * 60 {
            return Cheer(line: alt(String(localized: "Nice work."), String(localized: "Another one in the books.")), tone: .normal)
        }
        return Cheer(line: alt(String(localized: "Good start."), String(localized: "Short, but it counts.")), tone: .normal)
    }

    /// PFT 10가지 (위에서부터 먼저 맞는 것)
    private static func pft(_ x: CheerInput) -> Cheer {
        let g: PFTGrade = PFT.grade(x.total)
        let tag: String = g.label
        guard let prev = x.pftPrevBest else {
            switch g {
            case .gold: return Cheer(line: String(localized: "Gold on your first try. Impressive."), tone: .celebrate, tag: tag)
            case .silver: return Cheer(line: String(localized: "Silver on your first try. Strong start."), tone: .celebrate, tag: tag)
            case .bronze: return Cheer(line: String(localized: "Bronze on your first try. Not bad at all."), tone: .celebrate, tag: tag)
            }
        }
        let pg: PFTGrade = PFT.grade(prev)
        func rank(_ v: PFTGrade) -> Int { v == .gold ? 2 : v == .silver ? 1 : 0 }
        if g == .gold && !x.pftEverGold { return Cheer(line: String(localized: "Gold. Well earned."), tone: .celebrate, tag: tag) }
        if rank(g) > rank(pg) {
            return Cheer(line: String(localized: "Up to \(g.word.l10n). Gold is next."), tone: .celebrate, tag: tag)
        }
        // 다음 등급까지 30초 안
        if g != .gold {
            let limit: Int = g == .silver ? PFT.goldLimit - 1 : PFT.silverLimit
            let gap: Int = x.total - limit
            if gap > 0 && gap <= 30 {
                let next: PFTGrade = g == .silver ? .gold : .silver
                return Cheer(line: String(localized: "\(g.word.l10n) — just \(gap)s from \(next.word.l10n)."), tone: .normal, tag: tag)
            }
        }
        if rank(g) == rank(pg) && x.total < prev && g != .gold {
            return Cheer(line: String(localized: "Still \(g.word.l10n), but \(Fm.t(prev - x.total)) faster."), tone: .normal, tag: tag)
        }
        if g == .gold { return Cheer(line: String(localized: "Gold again. Consistent."), tone: .celebrate, tag: tag) }
        if rank(g) < rank(pg) {
            return Cheer(line: String(localized: "\(g.word.l10n) this time. Every test counts."), tone: .normal, tag: tag)
        }
        return Cheer(line: String(localized: "\(g.word.l10n). Nice work."), tone: .normal, tag: tag)
    }

    /// 기록 id → 늘 같은 숫자 (hashValue 는 앱을 켤 때마다 바뀌어서 쓰지 않음)
    static func seed(_ id: UUID) -> Int {
        id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
    }

    /// 높은 심박(Z4–Z5) 비율
    static func hiShare(_ hr: [HRPoint], settings: Settings) -> Double? {
        let p = hr.sorted { $0.t < $1.t }
        guard p.count > 1 else { return nil }
        var hi = 0, all = 0
        for i in 0..<(p.count - 1) {
            let dt = min(30, max(0, p[i + 1].t - p[i].t))
            all += dt
            if settings.zone(Double(p[i].b)) >= 4 { hi += dt }
        }
        return all > 0 ? Double(hi) / Double(all) : nil
    }
}
