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

// MARK: - 모드

enum Mode: String, Codable, CaseIterable, Identifiable {
    case training, sim, race
    var id: String { rawValue }
    var name: String {
        switch self { case .training: return "Training"; case .sim: return "Full Simulation"; case .race: return "Race" }
    }
    var icon: String {
        switch self { case .training: return "modeTraining"; case .sim: return "modeSim"; case .race: return "modeRace" }
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

    static func presets() -> [Program] {
        // 부분 시뮬 (HYROX 앞 4구간 / 뒤 4구간: Run 1KM + 스테이션 × 4 = 8 segments). id 는 "preset." 으로 시작
        let firstKeys: [String] = ["skiErg", "sledPush", "sledPull", "burpeeBroadJump"]
        let secondKeys: [String] = ["row", "farmersCarry", "sandbagLunges", "wallBalls"]
        let firstHalf: [ProgItem] = firstKeys.flatMap { [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: $0)] }
        let secondHalf: [ProgItem] = secondKeys.flatMap { [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: $0)] }
        return [
            Program(id: "p1", name: "Sled Intervals", sets: 1,
                    seq: [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "sledPush"),
                          ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "sledPull")],
                    meta: "1 set · about 12 min"),
            Program(id: "p2", name: "Wall Ball Run", sets: 1,
                    seq: [ProgItem(icon: "run", run: "1KM"), ProgItem(icon: "wallBalls"), ProgItem(icon: "sandbagLunges")],
                    meta: "1 set · about 14 min"),
            Program(id: "preset.firstHalf", name: "First half", sets: 1, seq: firstHalf,
                    meta: "1 set · 8 segments · about 34 min"),
            Program(id: "preset.secondHalf", name: "Second half", sets: 1, seq: secondHalf,
                    meta: "1 set · 8 segments · about 34 min"),
        ]
    }

    /// 아이폰 카드 설명
    var cardMeta: String { meta.map { $0.l10n } ?? watchMeta }
    /// 워치 목록 설명
    var watchMeta: String { Self.setsText(sets, seq.count) }
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

    /// 러닝·스테이션 16개 (Roxzone 제외)
    var splits16: [Int]? {
        let s = segs.filter { $0.kind != .rox }.map(\.time)
        return s.count == 16 ? s : nil
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

    var signedIn: Bool { nickname != nil }

    var div: Division { Division.of(division) }
    var maxHR: Int { hrMode == "age" ? 220 - age : manualHr }

    /// 1~5
    func zone(_ bpm: Double) -> Int {
        let p = bpm / Double(max(1, maxHR))
        return p >= 0.9 ? 5 : p >= 0.8 ? 4 : p >= 0.7 ? 3 : p >= 0.6 ? 2 : 1
    }
}

enum RunModes {
    static let keys = ["outdoor", "treadmill", "curved"]
    static func name(_ k: String) -> String {
        ["outdoor": "Outdoor", "treadmill": "Treadmill", "curved": "Curved treadmill"][k] ?? "Treadmill"
    }
    static func spec(_ k: String) -> String {
        ["outdoor": "GPS pace and distance",
         "treadmill": "Motion estimate · calibrate with machine distance",
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

    /// 기본(워치 ST) 목표 16개
    static var defaultTargets16: [Int] { (0..<8).flatMap { [270, Station.all[$0].target] } }

    /// 트레이닝: 순서 × 세트, Roxzone 없음
    static func training(_ p: Program, div: Division, bests: [String: Int]) -> [Seg] {
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
    /// 달력 점 색: 트레이닝 노랑 · 풀시뮬 하늘색 · 레이스 주황
    var calendarHex: UInt32 {
        switch self {
        case .training: return 0xFFE600
        case .sim: return 0x64D2FF
        case .race: return 0xFF9F0A
        }
    }
}
