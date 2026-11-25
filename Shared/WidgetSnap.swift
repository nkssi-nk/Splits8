import Foundation

// MARK: - 53번 · 위젯이 읽는 요약 (앱 · 위젯 공용 폴더 App Group 에 작은 파일 하나)
//
// 기록 원본은 그대로 앱 안(Documents)에 두고, 위젯에 필요한 숫자만 따로 써 둠 (옮기는 작업 없음).
// 아이폰 앱이 쓰고 아이폰 위젯이 읽음 / 워치 앱이 쓰고 워치 컴플리케이션이 읽음.

struct WidgetSnap: Codable, Equatable {
    // 다음 대회
    var raceName: String? = nil
    var raceDate: Date? = nil
    var division: String = ""
    var goal: Int? = nil
    var best: Int? = nil
    // 이번 주 (월요일 시작)
    var weekStart: Date = Date.distantPast
    var weekCount: Int = 0
    var weekSec: Int = 0
    var weekKcal: Int = 0
    var weekRunKm: Double = 0
    /// 요일 7칸(월…일): 1.2.8 그날 운동 종류 "hyrox" / "run" (예전: Mode rawValue), 없으면 ""
    var dayMode: [String] = Array(repeating: "", count: 7)
    /// 요일 7칸: 운동한 분
    var dayMin: [Int] = Array(repeating: 0, count: 7)
    /// 빌드 24: 앱 테마 색 (위젯 바탕 '테마 색' 고를 때). 예전 파일엔 없음 → 노랑
    var themeHex: UInt32? = nil
    /// 1.2.8 홈 위젯 오른쪽 칸 숫자 (Today 링 · 지난 4주 · 최근 운동 · 최고 vs 목표). 예전 파일엔 없음 → nil
    var right: Right? = nil

    /// 1.2.8 홈 위젯 오른쪽 칸 (안드로이드 WidgetSnap 과 같은 뜻)
    struct Right: Codable, Equatable {
        /// 오늘 (만든 날)
        var day: Date = Date.distantPast
        /// 오늘 하이록스 연습 시간(초, 러닝만 한 운동 빼고) · 러닝 km (모든 운동) · 칼로리
        var todayHyroxSec: Int = 0
        var todayRunKm: Double = 0
        var todayKcal: Int = 0
        /// 링이 꽉 차는 값 = 지난 28일 중 운동한 날의 하루 평균 (운동한 날 7일 미만이면 60분 · 5 km · 500 kcal)
        var avgHyroxSec: Int = 3600
        var avgRunKm: Double = 5
        var avgKcal: Int = 500
        /// 지난 4주 (3주 전 월요일부터 28칸): "" = 쉰 날 · "hyrox" = 하이록스 연습 · "run" = 러닝만
        var last28: [String] = Array(repeating: "", count: 28)
        var count28: Int = 0
        var streak: Int = 0
        /// 최근 운동
        var lastName: String? = nil
        var lastKind: String = "hyrox"
        var lastDate: Date? = nil
        var lastSec: Int = 0
        /// 목표와 차이(초, 빠르면 음수 — 레이스 · 풀 시뮬만)
        var lastVsGoal: Int? = nil
        /// 최고 기록에서 목표보다 가장 늦은 구간
        var weakName: String? = nil
        var weakKind: String = "hyrox"
        var weakDiff: Int = 0
    }

    /// 러닝만 한 운동 (러닝 카드 · 인터벌 러닝)
    static func isRunOnly(_ r: Record) -> Bool { r.kind == "run" || r.kind == "interval" }
    static func runKm(_ r: Record) -> Double { r.runs.map { $0.dist ?? runMeters($0.detail) }.reduce(0, +) / 1000 }
    /// 그날 운동 종류: 하이록스 연습이 하나라도 있으면 "hyrox", 러닝만이면 "run", 없으면 ""
    static func dayKind(_ rs: [Record]) -> String {
        if rs.isEmpty { return "" }
        return rs.contains { !isRunOnly($0) } ? "hyrox" : "run"
    }
    private static let shortSt: [String] = ["SkiErg", "Sled Push", "Sled Pull", "BBJ", "Row", "Farmers", "Lunges", "Wall Balls"]

    /// 날이 바뀌었으면 오늘 숫자는 0
    func todayFresh(_ now: Date) -> WidgetSnap {
        guard var r = right, !Calendar.current.isDate(r.day, inSameDayAs: now) else { return self }
        r.todayHyroxSec = 0; r.todayRunKm = 0; r.todayKcal = 0
        var s = self
        s.right = r
        return s
    }

    static let group = "group.com.nkssi.splits8"
    static let file = "widget.json"

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent(file)
    }

    static func load() -> WidgetSnap? {
        guard let u = url, let d = try? Data(contentsOf: u) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(WidgetSnap.self, from: d)
    }

    /// 바뀌었을 때만 씀. 썼으면 true (→ 위젯 새로 고침)
    @discardableResult
    func save() -> Bool {
        guard let u = Self.url else { return false }
        if Self.load() == self { return false }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        guard let d = try? enc.encode(self) else { return false }
        return (try? d.write(to: u, options: .atomic)) != nil
    }

    static var monday: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale.current
        return c
    }

    /// 기록 목록으로 만들기 (아이폰)
    static func make(records: [Record], settings: Settings, best: Int?, now: Date = Date(), bestRec: Record? = nil) -> WidgetSnap {
        var s = WidgetSnap()
        let ev = settings.event
        let cal = Calendar.current
        if ev.isSet, cal.startOfDay(for: ev.date) >= cal.startOfDay(for: now) {
            s.raceName = ev.name
            s.raceDate = ev.date
        }
        s.division = settings.div.name
        s.themeHex = settings.glow.hex
        s.goal = settings.goalTime > 0 ? settings.goalTime : nil
        s.best = best
        let mon = monday
        guard let wk = mon.dateInterval(of: .weekOfYear, for: now) else { return s }
        s.weekStart = wk.start
        let these: [Record] = records.filter { wk.contains($0.date) }
        s.weekCount = these.count
        s.weekSec = these.map(\.total).reduce(0, +)
        s.weekKcal = these.map(\.kcal).reduce(0, +)
        s.weekRunKm = these.flatMap(\.runs).map { ($0.dist ?? runMeters($0.detail)) }.reduce(0, +) / 1000
        for i in 0..<7 {
            guard let d0 = mon.date(byAdding: .day, value: i, to: wk.start),
                  let d1 = mon.date(byAdding: .day, value: 1, to: d0) else { continue }
            let day: [Record] = these.filter { $0.date >= d0 && $0.date < d1 }
            s.dayMin[i] = day.map(\.total).reduce(0, +) / 60
            s.dayMode[i] = dayKind(day)        // 1.2.8: 하이록스 연습 "hyrox" 노랑 · 러닝만 "run" 파랑
        }
        s.right = makeRight(records: records, settings: settings, now: now, bestRec: bestRec)
        return s
    }

    /// 1.2.8 오른쪽 칸 숫자
    static func makeRight(records: [Record], settings: Settings, now: Date, bestRec: Record?) -> Right {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func on(_ d: Date) -> [Record] { records.filter { cal.isDate($0.date, inSameDayAs: d) } }
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today) ?? today }
        var r = Right()
        r.day = today
        let todays = on(today)
        r.todayHyroxSec = todays.filter { !isRunOnly($0) }.map(\.total).reduce(0, +)
        r.todayRunKm = todays.map { runKm($0) }.reduce(0, +)
        r.todayKcal = todays.map(\.kcal).reduce(0, +)
        // 지난 28일 (오늘 빼고) 운동한 날 평균
        let past: [[Record]] = (1...28).map { on(day(-$0)) }.filter { !$0.isEmpty }
        if past.count >= 7 {
            func avg(_ f: ([Record]) -> Double) -> Double { past.map(f).reduce(0, +) / Double(past.count) }
            let h = avg { d in Double(d.filter { !isRunOnly($0) }.map(\.total).reduce(0, +)) }
            let k = avg { d in d.map { runKm($0) }.reduce(0, +) }
            let c = avg { d in Double(d.map(\.kcal).reduce(0, +)) }
            if h > 0 { r.avgHyroxSec = Int(h) }
            if k > 0 { r.avgRunKm = k }
            if c > 0 { r.avgKcal = Int(c) }
        }
        // 지난 4주 칸 (3주 전 월요일부터, 앞으로 올 날은 "")
        let mon = monday.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let start = cal.date(byAdding: .day, value: -21, to: cal.startOfDay(for: mon)) ?? today
        r.last28 = (0..<28).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start) ?? start
            return d > today ? "" : dayKind(on(d))
        }
        r.count28 = records.filter { $0.date >= start && $0.date < (cal.date(byAdding: .day, value: 1, to: today) ?? now) }.count
        var st = 0
        var d = on(today).isEmpty ? day(-1) : today
        while !on(d).isEmpty { st += 1; d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        r.streak = st
        // 최근 운동
        if let last = records.max(by: { $0.date < $1.date }) {
            r.lastName = last.title
            r.lastKind = isRunOnly(last) ? "run" : "hyrox"
            r.lastDate = last.date
            r.lastSec = last.total
            if last.mode == .race || last.mode == .sim, let g = last.goal ?? (settings.goalTime > 0 ? settings.goalTime : nil) {
                r.lastVsGoal = last.total - g
            }
        }
        // 최고 기록에서 목표보다 가장 늦은 구간 (러닝 8 · 스테이션 8)
        if let sp = bestRec?.splits16, settings.goals.count == 16 {
            for i in 0..<16 {
                let diff: Int = sp[i] - settings.goals[i]
                if diff > r.weakDiff {
                    r.weakDiff = diff
                    if i % 2 == 0 { r.weakName = "Run \(i / 2 + 1)"; r.weakKind = "run" } else { r.weakName = shortSt[i / 2]; r.weakKind = "hyrox" }
                }
            }
        }
        return r
    }

    /// 이번 주가 지났으면 이번 주 숫자는 0 으로 봄
    func fresh(_ now: Date) -> WidgetSnap {
        guard let wk = Self.monday.dateInterval(of: .weekOfYear, for: now), wk.start != weekStart else { return self }
        var s = self
        s.weekStart = wk.start
        s.weekCount = 0; s.weekSec = 0; s.weekKcal = 0; s.weekRunKm = 0
        s.dayMode = Array(repeating: "", count: 7); s.dayMin = Array(repeating: 0, count: 7)
        return s
    }

    /// 남은 날 (오늘 = 0). 대회가 없으면 nil
    func daysLeft(_ now: Date) -> Int? {
        guard let d = raceDate else { return nil }
        let cal = Calendar.current
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? -1
        return n >= 0 ? n : nil
    }

    /// 화면 확인 · 위젯 갤러리용 예시
    static func demo(days: Int = 10, now: Date = Date()) -> WidgetSnap {
        var s = WidgetSnap()
        s.raceName = "Incheon"
        s.raceDate = Calendar.current.date(byAdding: .day, value: days, to: now)
        s.division = "Open Men"
        s.goal = 4320
        s.best = 4565
        s.weekStart = monday.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        s.weekCount = 3
        s.weekSec = 9660
        s.weekKcal = 1840
        s.weekRunKm = 12.4
        s.dayMode = ["hyrox", "run", "", "hyrox", "", "", ""]
        s.dayMin = [42, 78, 0, 34, 0, 0, 0]
        var r = Right()
        r.day = now
        r.todayHyroxSec = 2880; r.todayRunKm = 5.2; r.todayKcal = 520
        r.avgHyroxSec = 3600; r.avgRunKm = 7; r.avgKcal = 600
        r.last28 = ["run", "", "run", "", "hyrox", "", "", "run", "run", "", "hyrox", "", "run", "",
                    "", "run", "", "run", "hyrox", "", "", "run", "", "hyrox", "", "", "", ""]
        r.count28 = 12; r.streak = 3
        r.lastName = "Full Simulation"; r.lastKind = "hyrox"
        r.lastDate = Calendar.current.date(byAdding: .day, value: -2, to: now); r.lastSec = 4360; r.lastVsGoal = -140
        r.weakName = "Wall Balls"; r.weakKind = "hyrox"; r.weakDiff = 48
        s.right = r
        return s
    }
}
