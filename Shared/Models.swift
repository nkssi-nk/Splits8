import Foundation

// MARK: - 체급 (reference_data.js)

struct Division: Codable, Hashable {
    let key: String
    let name: String
    let push: Int, pull: Int, fc: Int, sb: Int, wb: Int, wbReps: Int
    let wbNote: String

    static let all: [Division] = [
        Division(key: "openM", name: "Open Men", push: 152, pull: 103, fc: 24, sb: 20, wb: 6, wbReps: 100, wbNote: ""),
        Division(key: "openW", name: "Open Women", push: 102, pull: 78, fc: 16, sb: 10, wb: 4, wbReps: 100, wbNote: ""),
        Division(key: "proM", name: "Pro Men", push: 202, pull: 153, fc: 32, sb: 30, wb: 9, wbReps: 100, wbNote: ""),
        Division(key: "proW", name: "Pro Women", push: 152, pull: 103, fc: 24, sb: 20, wb: 6, wbReps: 100, wbNote: ""),
        Division(key: "dblM", name: "Doubles Men", push: 152, pull: 103, fc: 24, sb: 20, wb: 6, wbReps: 100, wbNote: " · shared"),
        Division(key: "dblMP", name: "Doubles Men Pro", push: 202, pull: 153, fc: 32, sb: 30, wb: 9, wbReps: 100, wbNote: " · shared"),
        Division(key: "dblW", name: "Doubles Women", push: 102, pull: 78, fc: 16, sb: 10, wb: 4, wbReps: 100, wbNote: " · shared"),
        Division(key: "dblWP", name: "Doubles Women Pro", push: 152, pull: 103, fc: 24, sb: 20, wb: 6, wbReps: 100, wbNote: " · shared"),
        Division(key: "dblX", name: "Doubles Mixed", push: 152, pull: 103, fc: 24, sb: 20, wb: 6, wbReps: 100, wbNote: " · shared"),
    ]
    static func of(_ key: String) -> Division { all.first { $0.key == key } ?? all[0] }

    /// Push 152 · Pull 103 · FC 2×24 · SB 20 · WB 6KG
    var spec: String { "Push \(push) · Pull \(pull) · FC 2×\(fc) · SB \(sb) · WB \(wb)KG" }
}

// MARK: - 스테이션

struct Station {
    let key: String
    let name: String
    let target: Int          // 기본 목표(초) — 워치 ST
    func detail(_ d: Division) -> String {
        switch key {
        case "skiErg": return "1K"
        case "sledPush": return "50M · \(d.push)KG"
        case "sledPull": return "50M · \(d.pull)KG"
        case "burpeeBroadJump": return "80M"
        case "row": return "1K"
        case "farmersCarry": return "200M · 2×\(d.fc)KG"
        case "sandbagLunges": return "100M · \(d.sb)KG"
        case "wallBalls": return "\(d.wbReps) REPS · \(d.wb)KG\(d.wbNote)"
        default: return ""
        }
    }
    static let all: [Station] = [
        Station(key: "skiErg", name: "SkiErg", target: 255),
        Station(key: "sledPush", name: "Sled Push", target: 190),
        Station(key: "sledPull", name: "Sled Pull", target: 270),
        Station(key: "burpeeBroadJump", name: "BBJ", target: 250),
        Station(key: "row", name: "Row", target: 265),
        Station(key: "farmersCarry", name: "Farmers Carry", target: 110),
        Station(key: "sandbagLunges", name: "Lunges", target: 270),
        Station(key: "wallBalls", name: "Wall Balls", target: 330),
    ]
    static func of(_ key: String) -> Station? { all.first { $0.key == key } }
}

/// 기본 구간 목표 (Split goals 초기값) — Run 270, 스테이션 tgtS0
enum Defaults {
    static let stationGoals = [240, 200, 270, 250, 265, 115, 270, 330]
    static var goals: [Int] { (0..<8).flatMap { [270, stationGoals[$0]] } }
    static let goalTime = 4320          // 1:12:00
    static let runs = ["200M", "400M", "800M", "1KM"]
    static let roxTarget = 30
}

// MARK: - 목표 시간 → 구간별 목표 나누기

/// 총 목표 시간을 러닝 8개 · 종목 8개(16칸)로 나눔. Roxzone(8 × 30초)은 빼고 나눔.
/// 비율은 공식 수치가 아니라 앱이 정한 값: 균형형 = 기본 목표 비율, 러너형 = 러닝을 더 빠르게, 근력형 = 종목을 더 빠르게
enum GoalSplit {
    /// keep = 지금 내 구간 비율 그대로 / balanced / runner / strong / best = 내 최고 풀 시뮬레이션 비율
    static let styles: [String] = ["keep", "balanced", "runner", "strong", "best"]

    static func name(_ k: String) -> String {
        ["keep": "Current", "balanced": "Balanced", "runner": "Runner", "strong": "Strong", "best": "My best"][k] ?? "Balanced"
    }
    static func note(_ k: String) -> String {
        ["keep": "Keeps the ratio of your current split goals.",
         "balanced": "An even mix of running and stations.",
         "runner": "Faster runs, a little more time on stations.",
         "strong": "Faster stations, a little more time on runs.",
         "best": "Follows the ratio of your best Full Simulation."][k] ?? ""
    }

    /// 16칸 비율 (합은 아무 값이나 됨 — 나눌 때 맞춤)
    static func weights(_ style: String, current: [Int], best: [Int]?) -> [Double] {
        let base: [Double] = Defaults.goals.map(Double.init)
        func tilt(run: Double, st: Double) -> [Double] {
            base.enumerated().map { $0.offset % 2 == 0 ? $0.element * run : $0.element * st }
        }
        switch style {
        case "runner": return tilt(run: 0.94, st: 1.07)
        case "strong": return tilt(run: 1.06, st: 0.93)
        case "best":
            if let b = best, b.count == 16, b.reduce(0, +) > 0 { return b.map(Double.init) }
            return base
        case "keep":
            if current.count == 16, current.reduce(0, +) > 0 { return current.map(Double.init) }
            return base
        default: return base
        }
    }

    /// 16칸 목표(초). 5초 단위, 칸마다 최소 30초, 합계 = (총 목표 − Roxzone) 을 5초 단위로 맞춘 값
    static func split(total: Int, style: String, current: [Int], best: [Int]?) -> [Int] {
        let w: [Double] = weights(style, current: current, best: best)
        let sumW: Double = max(1, w.reduce(0, +))
        let raw: Int = max(16 * 30, total - 8 * Defaults.roxTarget)
        let target: Int = Int((Double(raw) / 5).rounded()) * 5
        let exact: [Double] = w.map { $0 / sumW * Double(target) }
        var out: [Int] = exact.map { max(30, Int(($0 / 5).rounded()) * 5) }
        // 반올림으로 생긴 차이를 5초씩 나눠서 합계를 맞춤 (반올림에서 손해·이득을 가장 많이 본 칸부터)
        var diff: Int = target - out.reduce(0, +)
        var guardCount = 0
        while diff != 0 && guardCount < 200 {
            guardCount += 1
            let step: Int = diff > 0 ? 5 : -5
            var pick: Int = -1
            var bestErr: Double = -Double.greatestFiniteMagnitude
            for i in 0..<out.count {
                if step < 0 && out[i] - 5 < 30 { continue }
                let err: Double = (exact[i] - Double(out[i])) * (step > 0 ? 1 : -1)
                if err > bestErr { bestErr = err; pick = i }
            }
            if pick < 0 { break }
            out[pick] += step
            diff -= step
        }
        return out
    }
}

// MARK: - 모드

/// 순서 = 화면에 나오는 순서 (워치 홈 카드 · 달력 점): Training → PFT → Full Simulation → Race
enum Mode: String, Codable, CaseIterable, Identifiable {
    case training, pft, sim, race
    var id: String { rawValue }
    var name: String {
        switch self {
        case .training: return "Training"
        case .pft: return "PFT"
        case .sim: return "Full Simulation"
        case .race: return "Race"
        }
    }
    var icon: String {
        switch self {
        case .training: return "modeTraining"
        case .pft: return "modePFT"
        case .sim: return "modeSim"
        case .race: return "modeRace"
        }
    }
}

// MARK: - PFT (Physical Fitness Test)

/// 등급: Gold 22:00 미만 · Silver 22:00–26:00 · Bronze 26:00 초과 (남녀 같음).
/// HYROX 공식 등급이 아니라 SPLITS8 자체 기준.
enum PFTGrade: String, Codable, CaseIterable {
    case gold, silver, bronze

    var label: String { rawValue.uppercased() }
    /// Gold / Silver / Bronze (문장 안에서)
    var word: String { rawValue.capitalized }

    /// 뱃지 바탕 그라데이션 (왼쪽 위 → 오른쪽 아래)
    var hex1: UInt32 {
        switch self { case .gold: return 0xFFE08A; case .silver: return 0xEEF1F4; case .bronze: return 0xE8A66E }
    }
    var hex2: UInt32 {
        switch self { case .gold: return 0xC9981E; case .silver: return 0x9098A1; case .bronze: return 0x9A5A28 }
    }
    /// 뱃지 글자색
    var inkHex: UInt32 {
        switch self { case .gold: return 0x201600; case .silver: return 0x15181C; case .bronze: return 0x1D0F04 }
    }
}

enum PFT {
    static let title = "PFT"
    /// 이 시간 미만이면 Gold
    static let goldLimit: Int = 22 * 60
    /// 이 시간 이하이면 Silver, 넘으면 Bronze
    static let silverLimit: Int = 26 * 60

    static func grade(_ total: Int) -> PFTGrade {
        if total < goldLimit { return .gold }
        if total <= silverLimit { return .silver }
        return .bronze
    }

    /// 여자 체급은 월볼 4 kg, 그 외 6 kg
    static func wallBallKg(_ d: Division) -> Int {
        ["openW", "proW", "dblW", "dblWP"].contains(d.key) ? 4 : 6
    }

    /// 종목 6개 (순서 고정). name = 기록에 남는 짧은 이름, long = 설명 화면용, amount = 설명 화면 오른쪽 값
    struct Item {
        let icon: String
        let name: String
        let long: String
        let kind: SegKind
        let target: Int         // 기본 목표(초). 합계 22:00
    }
    static let items: [Item] = [
        Item(icon: "run", name: "Run", long: "Run", kind: .run, target: 285),
        Item(icon: "burpeeBroadJump", name: "BBJ", long: "Burpee Broad Jumps", kind: .st, target: 225),
        Item(icon: "sandbagLunges", name: "Lunges", long: "Lunges", kind: .st, target: 195),
        Item(icon: "row", name: "Row", long: "Row", kind: .st, target: 240),
        Item(icon: "pushUp", name: "Push-Ups", long: "Push-Ups", kind: .st, target: 75),
        Item(icon: "wallBalls", name: "Wall Balls", long: "Wall Balls", kind: .st, target: 300),
    ]

    /// 운동 중·기록에 쓰는 세부 (러닝은 거리 계산 때문에 "1KM" 그대로)
    static func detail(_ i: Int, _ d: Division) -> String {
        switch i {
        case 0: return "1KM"
        case 1: return "50 REPS"
        case 2: return "100 REPS"
        case 3: return "1K"
        case 4: return "30 REPS"
        default: return "100 REPS · \(wallBallKg(d))KG"
        }
    }

    /// 설명 화면 오른쪽 값: 1000 M · 50 · 100 · 1000 M · 30 · 100 · 6 KG
    static func amount(_ i: Int, _ d: Division) -> String {
        switch i {
        case 0, 3: return "1000 M"
        case 1: return "50"
        case 2: return "100"
        case 4: return "30"
        default: return "100 · \(wallBallKg(d)) KG"
        }
    }

    /// 구간 순서. targets = 내 최고 기록의 구간 시간 6개 (없으면 기본 목표)
    static func seq(div: Division, targets: [Int]? = nil) -> [Seg] {
        var o: [Seg] = []
        for (i, it) in items.enumerated() {
            let t: Int = (targets?.count == items.count) ? targets![i] : it.target
            o.append(Seg(icon: it.icon, name: it.name, detail: detail(i, div), kind: it.kind, target: t))
        }
        return o
    }
}

enum SegKind: String, Codable { case run, st, rox }

/// 운동 중 구간 하나
struct Seg: Codable, Hashable {
    var icon: String
    var name: String
    var detail: String
    var kind: SegKind
    var target: Int
}

/// 러닝 거리 (m)
func runMeters(_ detail: String) -> Double {
    let s = detail.uppercased()
    if s.hasSuffix("KM"), let v = Double(s.dropLast(2)) { return v * 1000 }
    if s.hasSuffix("M"), let v = Double(s.dropLast(1)) { return v }
    return 1000
}

/// 기본 목표 (워치 tgt): 러닝은 1KM당 270초
func defaultTarget(icon: String, detail: String) -> Int {
    if icon == "run" { return Int((runMeters(detail) / 1000 * 270).rounded()) }
    return Station.of(icon)?.target ?? 120
}

// MARK: - 트레이닝 프로그램

struct ProgItem: Codable, Hashable {
    var icon: String          // run 또는 스테이션 key
    var run: String?          // 러닝 거리 라벨 (200M/400M/800M/1KM)

    func name() -> String { icon == "run" ? "Run" : (Station.of(icon)?.name ?? icon) }
    func detail(_ d: Division) -> String { icon == "run" ? (run ?? "1KM") : (Station.of(icon)?.detail(d) ?? "") }
}

struct Program: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var sets: Int
    var seq: [ProgItem]
    var meta: String? = nil        // 기본 프로그램 설명 (예: 1 set · about 12 min)
    var quick: Bool = false        // 워치에서 만든 Quick training
    /// nil = 하이록스 트레이닝 / "hiit" = 고강도 인터벌 / "run" = 러닝 (예전 파일엔 없음)
    var kind: String? = nil
    var runKm: Int? = nil          // 러닝 총거리 km (0 = 자유)
    var indoor: Bool? = nil        // 러닝: 실내(러닝머신)

    var isHIIT: Bool { kind == "hiit" }
    var isRun: Bool { kind == "run" }
    var isOpen: Bool { isHIIT || isRun }

    /// 만들어 둘 수 있는 트레이닝 개수 (기본 카드 · HIIT · 러닝 카드 포함 전체). 이미 더 많이 가진 경우 있던 것은 그대로 두고 새로 만드는 것만 막음
    static let freeLimit: Int = 5

    static let runChoices: [Int] = [3, 5, 10, 21, 0]
    /// "Run 5K" / "Free run" (번역 키)
    static func runName(_ km: Int) -> String { km > 0 ? "Run \(km)K" : "Free run" }

    static func hiit() -> Program {
        Program(id: "hiit." + UUID().uuidString.prefix(6), name: "HIIT", sets: 1, seq: [ProgItem(icon: "hiit")],
                meta: "Intervals · heart rate · calories", kind: "hiit")
    }
    static func run(km: Int, indoor: Bool, id: String? = nil) -> Program {
        Program(id: id ?? ("run." + UUID().uuidString.prefix(6)), name: runName(km), sets: 1,
                seq: [ProgItem(icon: "run", run: "1KM")],
                meta: indoor ? "Indoor · 1 km splits" : "Outdoor · 1 km splits",
                kind: "run", runKm: km, indoor: indoor)
    }

    static func presets() -> [Program] {
        return [
            Program(id: "p1", name: "Sled Intervals", sets: 1,
                    seq: [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "sledPush"),
                          ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "sledPull")],
                    meta: "1 set · about 12 min"),
            Program(id: "p2", name: "Wall Ball Run", sets: 1,
                    seq: [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "wallBalls"), ProgItem(icon: "sandbagLunges")],
                    meta: "1 set · about 14 min"),
        ]
    }

    /// 아이폰 카드 설명
    var cardMeta: String { meta.map { $0.l10n } ?? watchMeta }
    /// 워치 목록 설명
    var watchMeta: String { isOpen ? (meta ?? "").l10n : Self.setsText(sets, seq.count) }
    /// 1 set · 8 segments (번역됨)
    static func setsText(_ sets: Int, _ segs: Int) -> String {
        if sets == 1 { return String(localized: "1 set · \(segs) segments") }
        return String(localized: "\(sets) sets · \(segs) segments")
    }
}

// MARK: - 대회

struct RaceEvent: Codable, Hashable {
    var name: String = ""
    var loc: String = ""
    var date: Date = Fm.ymd.date(from: "2026-09-13") ?? Date()
    var time: String = "09:00"
    var dateEnd: Date? = nil
    var isSet: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - 친구 (계정 · Supabase)

struct Friend: Codable, Hashable, Identifiable {
    var id: String             // 상대 user id
    var name: String           // 닉네임
    var div: String            // Open Men
    var date: String           // 13 Sep 2026 (최고 Full Sim 날짜)
    var splits: [Int]          // 16개 (Run1, SkiErg, Run2, …) — 없으면 빈 배열
    var avatarUrl: String? = nil

    var first: String { name }
    var ini: String { String(name.prefix(1)).uppercased() }
    var total: Int { splits.reduce(0, +) + 8 * Defaults.roxTarget }
    var hasSplits: Bool { splits.count == 16 }
}

// MARK: - 대회 목록 (hyrox.com Find My Race · 2026-09-29 확인)

struct EventItem: Codable, Hashable, Identifiable {
    var city: String
    var venue: String
    var region: String         // korea / asia / europe / americas
    var start: String          // yyyy-MM-dd
    var end: String
    var id: String { city + start }

    static let regions = [("all", "All"), ("korea", "Korea"), ("asia", "Asia-Pacific"), ("europe", "Europe"), ("americas", "Americas")]
    static let bundled: [EventItem] = [
        ["Seoul","KINTEX, Goyang","korea","2026-11-13","2026-11-15"],
        ["Incheon","Songdo Convensia","korea","2027-05-13","2027-05-16"],
        ["Shanghai","China","asia","2026-10-31","2026-11-01"],
        ["Guangzhou","China","asia","2026-11-21","2026-11-22"],
        ["Singapore","Singapore","asia","2026-11-26","2026-11-29"],
        ["Sanya","China","asia","2026-12-05","2026-12-06"],
        ["Melbourne","Australia","asia","2026-12-09","2026-12-13"],
        ["Kuala Lumpur","Malaysia","asia","2026-12-10","2026-12-13"],
        ["Hong Kong","Hong Kong","asia","2027-01-07","2027-01-10"],
        ["Osaka","Japan","asia","2027-01-21","2027-01-25"],
        ["Auckland","New Zealand","asia","2027-02-04","2027-02-07"],
        ["Bangkok","Thailand","asia","2027-02-11","2027-02-14"],
        ["Taipei","Chinese Taipei","asia","2027-03-12","2027-03-14"],
        ["Brisbane","Australia","asia","2027-03-31","2027-04-04"],
        ["Nagoya","Japan","asia","2027-04-16","2027-04-18"],
        ["World Championships","AsiaWorld-Expo, Hong Kong","asia","2027-06-10","2027-06-13"],
        ["Hamburg","Germany","europe","2026-10-28","2026-11-01"],
        ["Barcelona","Spain","europe","2026-11-11","2026-11-15"],
        ["London","ExCeL London","europe","2026-12-02","2026-12-06"],
        ["Stockholm","Sweden","europe","2026-12-10","2026-12-13"],
        ["Paris","France","europe","2026-12-12","2026-12-20"],
        ["Amsterdam","Netherlands","europe","2027-01-22","2027-01-31"],
        ["Dallas","USA","americas","2026-11-18","2026-11-22"],
        ["Anaheim","USA","americas","2026-12-03","2026-12-06"],
        ["Chicago","USA","americas","2027-02-11","2027-02-15"],
    ].map { EventItem(city: $0[0], venue: $0[1], region: $0[2], start: $0[3], end: $0[4]) }
}

// MARK: - 기록

struct SegResult: Codable, Hashable {
    var icon: String
    var name: String
    var detail: String
    var kind: SegKind
    var time: Int
    var target: Int
    var hr: Int?
    var dist: Double?          // 러닝 거리(m)
    /// 워치가 팔 움직임으로 센 횟수 (스키 당긴 횟수 · 로잉 저은 횟수 · 월볼 던진 횟수). 참고용 짐작값 — 시간·순위·등급에는 쓰지 않음. 예전 기록엔 없음
    var reps: Int? = nil
}

/// 경로 한 점 (위도·경도)
struct RoutePt: Codable, Hashable {
    var a: Double   // latitude
    var o: Double   // longitude
}

struct HRPoint: Codable, Hashable {
    var t: Int                 // 시작부터 초
    var b: Int                 // bpm
}

struct Record: Codable, Hashable, Identifiable {
    var id = UUID()
    var mode: Mode
    var title: String          // 프로그램 이름 / 대회 이름 / Full Simulation
    var sets: Int = 1
    var date: Date
    var total: Int
    var segs: [SegResult]
    var hr: [HRPoint]
    var kcal: Int
    var avgHR: Int
    var maxHR: Int
    var division: String
    var goal: Int?             // 레이스 목표 시간
    var vsWord: String         // VS GOAL / VS BEST / VS JIHO
    var vsTarget: Int?         // 비교 기준 총 시간
    var partner: String? = nil // 더블 파트너 닉네임 (@ 없이). 예전 기록엔 없음
    var source: String? = nil  // "phone" = 워치 없이 아이폰으로 기록. nil = 워치
    var complete: Bool? = nil  // 끝까지 다 했는지 (End 로 중간에 끝내면 false). 예전 기록엔 없음 → 구간 수로 판단
    var endDate: Date? = nil   // 끝난 시각 (예전 기록엔 없음 → date + total)
    var place: String? = nil   // 동네 이름 "성수동, 서울" (폰에만 저장, 서버로 안 보냄)
    var route: [RoutePt]? = nil // 실외 러닝 경로 (폰에만)
    var kind: String? = nil    // "hiit" / "run" (트레이닝 중 HIIT·러닝 카드로 한 것)

    /// 시작–끝
    var end: Date { endDate ?? date.addingTimeInterval(Double(total)) }
    var isHIIT: Bool { kind == "hiit" }
    var isRunKind: Bool { kind == "run" }

    /// 러닝·스테이션 16개 (Roxzone 제외)
    var splits16: [Int]? {
        let s = segs.filter { $0.kind != .rox }.map(\.time)
        return s.count == 16 ? s : nil
    }
    /// PFT 구간 6개
    var pftSplits: [Int]? {
        guard mode == .pft else { return nil }
        let s = segs.filter { $0.kind != .rox }.map(\.time)
        return s.count == PFT.items.count ? s : nil
    }
    /// PFT 등급 (끝까지 한 정상 기록만)
    var pftGrade: PFTGrade? {
        guard mode == .pft, counts else { return nil }
        return PFT.grade(total)
    }
    var roxTotal: Int { segs.filter { $0.kind == .rox }.map(\.time).reduce(0, +) }
    var runs: [SegResult] { segs.filter { $0.kind == .run } }
    var runTotal: Int { runs.map(\.time).reduce(0, +) }
    var stationTotal: Int { segs.filter { $0.kind == .st }.map(\.time).reduce(0, +) }

    /// 평균 러닝 페이스 (초/km)
    var runPace: Int? {
        let r = runs
        guard !r.isEmpty else { return nil }
        let meters = r.map { $0.dist ?? runMeters($0.detail) }.reduce(0, +)
        guard meters > 0 else { return nil }
        return Int((Double(runTotal) / meters * 1000).rounded())
    }
}

// MARK: - 설정 (아이폰이 원본, 워치로 전달)

struct Settings: Codable, Hashable {
    var division = "openM"
    var hrMode = "age"            // age / manual
    var age = 32
    var manualHr = 190
    var runMode = "treadmill"     // outdoor / treadmill / curved
    var roxAuto = true
    var goals: [Int] = Defaults.goals
    var goalTime = Defaults.goalTime
    var event = RaceEvent()
    var friendId: String? = nil
    var tgtSrc = "mine"           // mine / friend
    var simCmp = "goal"           // goal / last / friend
    var hasOnboarded = false

    // 계정 (Supabase) — 없어도 앱은 다 됩니다
    var nickname: String? = nil
    var email: String? = nil
    var signMethod: String? = nil          // Email code / Apple
    var visibility = "friends"             // friends / public / private
    var lbTab = "sim"                      // 순위표: sim / race / stations
    var lbStation = "skiErg"
    var lbAllDivisions = false

    // 진동 알림 (워치) — 예전 저장 파일과 호환되도록 옵셔널로 저장
    var hapticZoneOpt: Bool? = nil          // 심박 존 바뀔 때 진동
    var hapticPaceOpt: Bool? = nil          // 목표보다 느려질 때 진동 (Race · Full Sim)
    var hapticZone: Bool {
        get { hapticZoneOpt ?? true }
        set { hapticZoneOpt = newValue }
    }
    var hapticPace: Bool {
        get { hapticPaceOpt ?? true }
        set { hapticPaceOpt = newValue }
    }

    // 차단한 사용자 (이 기기에 저장). 친구 목록 · 검색 · 순위표에서 숨김 — 예전 저장 파일과 호환되도록 옵셔널
    var blockedOpt: [BlockedUser]? = nil
    var blocked: [BlockedUser] {
        get { blockedOpt ?? [] }
        set { blockedOpt = newValue.isEmpty ? nil : newValue }
    }

    var signedIn: Bool { nickname != nil }

    var div: Division { Division.of(division) }
    var maxHR: Int { hrMode == "age" ? 220 - age : manualHr }

    /// 1~5
    func zone(_ bpm: Double) -> Int {
        let p = bpm / Double(max(1, maxHR))
        return p >= 0.9 ? 5 : p >= 0.8 ? 4 : p >= 0.7 ? 3 : p >= 0.6 ? 2 : 1
    }
}

/// 차단한 사용자 (id = 서버 user id, name = 차단할 때의 닉네임 — 차단 목록에 보여 주려고)
struct BlockedUser: Codable, Hashable, Identifiable {
    var id: String
    var name: String
}

/// 닉네임에 쓸 수 없는 말 거르기 (기본 욕설 · 운영자 사칭). 숫자로 바꿔 쓴 것(0→o, 1→i …)과 밑줄을 풀어서 봄
enum NickFilter {
    private static let banned: [String] = [
        "fuck", "shit", "bitch", "cunt", "nigg", "fagg", "pussy", "whore", "slut",
        "nazi", "hitler", "porn", "asshole", "bastard", "retard",
        "admin", "official", "splits8", "moderator",
        "ssibal", "sibal", "gaesaek", "byungsin",
    ]

    static func plain(_ n: String) -> String {
        let map: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b"]
        return String(n.lowercased().filter { $0 != "_" }.map { map[$0] ?? $0 })
    }

    /// 써도 되는 닉네임인지
    static func allowed(_ n: String) -> Bool {
        let p: String = plain(n)
        let raw: String = n.lowercased().filter { $0 != "_" }
        return !banned.contains { p.contains($0) || raw.contains($0) }
    }
}

enum RunModes {
    static let keys = ["outdoor", "treadmill", "curved"]
    static func name(_ k: String) -> String {
        ["outdoor": "Outdoor", "treadmill": "Treadmill", "curved": "Curved treadmill"][k] ?? "Treadmill"
    }
    static func spec(_ k: String) -> String {
        ["outdoor": "GPS pace and distance",
         "treadmill": "Motion estimate · may differ from the machine",
         "curved": "Motion estimate · pace shown as approximate"][k] ?? ""
    }
}

// MARK: - 구간 순서 만들기

enum SeqBuilder {
    /// Full Simulation / Race: Run i, Roxzone, Station, Roxzone … (마지막 스테이션 뒤 Roxzone 없음)
    static func full(div: Division, rox: Bool, targets16: [Int]) -> [Seg] {
        var o: [Seg] = []
        for i in 0..<8 {
            o.append(Seg(icon: "run", name: "Run \(i + 1)", detail: "1KM", kind: .run, target: targets16[i * 2]))
            if rox { o.append(Seg(icon: "roxzone", name: "Roxzone", detail: "TRANSITION", kind: .rox, target: Defaults.roxTarget)) }
            let s = Station.all[i]
            o.append(Seg(icon: s.key, name: s.name, detail: s.detail(div), kind: .st, target: targets16[i * 2 + 1]))
            if rox && i < 7 { o.append(Seg(icon: "roxzone", name: "Roxzone", detail: "TRANSITION", kind: .rox, target: Defaults.roxTarget)) }
        }
        return o
    }

    /// HIIT 라운드 (끝 없이 늘어남, 목표 없음)
    static func hiitRound(_ n: Int) -> Seg {
        Seg(icon: "hiit", name: "Round \(n)", detail: "INTERVAL", kind: .st, target: 0)
    }
    /// 러닝 1km 구간
    static func runKm(_ n: Int, target: Int = 0) -> Seg {
        Seg(icon: "run", name: "KM \(n)", detail: "1KM", kind: .run, target: target)
    }

    /// 기본(워치 ST) 목표 16개
    static var defaultTargets16: [Int] { (0..<8).flatMap { [270, Station.all[$0].target] } }

    /// 트레이닝: 순서 × 세트, Roxzone 없음
    static func training(_ p: Program, div: Division, bests: [String: Int]) -> [Seg] {
        if p.isHIIT { return [hiitRound(1)] }
        if p.isRun {
            let n: Int = max(1, p.runKm ?? 0)
            return (1...n).map { runKm($0, target: bests[SegKey.of(icon: "run", detail: "1KM")] ?? 0) }
        }
        var o: [Seg] = []
        for _ in 0..<max(1, p.sets) {
            for it in p.seq {
                let d = it.detail(div)
                let key = SegKey.of(icon: it.icon, detail: d)
                o.append(Seg(icon: it.icon, name: it.name(), detail: d, kind: it.icon == "run" ? .run : .st,
                             target: bests[key] ?? defaultTarget(icon: it.icon, detail: d)))
            }
        }
        return o
    }
}

enum SegKey {
    static func of(icon: String, detail: String) -> String { icon == "run" ? "run|\(detail)" : icon }
}

// MARK: - 아이폰 → 워치

struct WatchContext: Codable {
    var settings: Settings
    var programs: [Program]
    var friend: Friend?
    var simBest: [Int]?           // 최고 Full Simulation 16구간
    var simBestTotal: Int?
    var segBests: [String: Int]   // 트레이닝 구간별 최고
    var pftBest: [Int]? = nil     // 최고 PFT 6구간 (예전 저장 파일엔 없음)
    var pftBestTotal: Int? = nil
}

enum SyncKey {
    static let context = "ctx"
    static let record = "record"
    static let quick = "quick"     // 워치에서 만든 Quick training → 아이폰
}

enum JSONStore {
    static let enc: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    static let dec: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    static func url(_ n: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(n)
    }
    static func save<T: Encodable>(_ v: T, _ n: String) {
        if let d = try? enc.encode(v) { try? d.write(to: url(n), options: .atomic) }
    }
    static func load<T: Decodable>(_ t: T.Type, _ n: String) -> T? {
        guard let d = try? Data(contentsOf: url(n)) else { return nil }
        return try? dec.decode(t, from: d)
    }
}

// MARK: - 운동 예약 (달력 · 미리 알림)

enum PlanReminder: String, Codable, CaseIterable, Identifiable {
    case none, hourBefore, dayBefore, weekBefore
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .hourBefore: return "1 hour before"
        case .dayBefore: return "Day before (8:00 PM)"
        case .weekBefore: return "Week before"
        }
    }
    var short: String {
        switch self {
        case .none: return ""
        case .hourBefore: return "1 hour before"
        case .dayBefore: return "Day before"
        case .weekBefore: return "Week before"
        }
    }
}

/// 달력에 예약한 운동. 레이스는 등록한 대회(settings.event)가 자동으로 달력에 뜨므로 여기엔 training / sim만.
struct PlannedWorkout: Codable, Hashable, Identifiable {
    var id = UUID()
    var mode: Mode                 // .training / .sim (.race는 대회 알림용으로만)
    var programId: String? = nil   // 트레이닝이면 프로그램 id
    var title: String              // 표시 이름 (프로그램 이름 / Full Simulation)
    var date: Date                 // 날짜 + 시간
    var reminder: PlanReminder = .dayBefore
}

extension Mode {
    /// 달력 점 색: 트레이닝 노랑 · PFT 보라 · 풀시뮬 하늘색 · 레이스 주황
    var calendarHex: UInt32 {
        switch self {
        case .training: return 0xFFE600
        case .pft: return 0xBF5AF2
        case .sim: return 0x64D2FF
        case .race: return 0xFF9F0A
        }
    }
}


// MARK: - 이상한 기록 (미완료 · 확인 필요) — PB·최고 기록에서 뺌

enum RecordFlag: String {
    case incomplete     // 끝까지 안 하고 End
    case check          // 말이 안 되게 빠름 (세계기록보다 훨씬 빠르거나 탭 실수)

    var label: String { self == .incomplete ? "Incomplete" : "Check" }
}

extension Record {
    /// 개인 50분, 더블 45분보다 빠르면 확인 필요 (세계기록: Pro 남 51:59, 더블 Pro 남 47:41 — 2026)
    static let minSolo: Int = 50 * 60
    static let minDoubles: Int = 45 * 60
    /// 1km 런 2:30, 스테이션 30초보다 빠르면 확인 필요
    static let minRun: Int = 150
    static let minStation: Int = 30
    static let minPFT: Int = 10 * 60
    static let minPFTStation: Int = 15

    var isDoubles: Bool { division.lowercased().hasPrefix("doubles") || division.hasPrefix("dbl") }

    /// 끝까지 했는지 (예전 기록: Full Sim·Race 는 16구간이 다 있으면 끝까지 한 것으로 봄)
    var isComplete: Bool {
        if let complete { return complete }
        if mode == .pft { return pftSplits != nil }
        return mode == .training ? true : splits16 != nil
    }

    /// nil = 정상
    var flag: RecordFlag? {
        if !isComplete { return .incomplete }
        guard mode != .training else { return nil }
        if mode == .pft {
            // PFT: 전체 10분, 러닝 2:30, 그 외 15초보다 빠르면 확인 필요
            if total < Self.minPFT { return .check }
            for s in segs {
                if s.kind == .run && s.time < Self.minRun { return .check }
                if s.kind == .st && s.time < Self.minPFTStation { return .check }
            }
            return nil
        }
        if total < (isDoubles ? Self.minDoubles : Self.minSolo) { return .check }
        for s in segs {
            if s.kind == .run && s.time < Self.minRun { return .check }
            if s.kind == .st && s.time < Self.minStation { return .check }
        }
        return nil
    }

    /// PB·최고 기록·비교 기준에 넣어도 되는 기록인지
    var counts: Bool { flag == nil }
}
