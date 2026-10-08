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
    /// 요일 7칸(월…일): 그날 가장 오래 한 운동 종류(Mode rawValue), 없으면 ""
    var dayMode: [String] = Array(repeating: "", count: 7)
    /// 요일 7칸: 운동한 분
    var dayMin: [Int] = Array(repeating: 0, count: 7)

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
    static func make(records: [Record], settings: Settings, best: Int?, now: Date = Date()) -> WidgetSnap {
        var s = WidgetSnap()
        let ev = settings.event
        let cal = Calendar.current
        if ev.isSet, cal.startOfDay(for: ev.date) >= cal.startOfDay(for: now) {
            s.raceName = ev.name
            s.raceDate = ev.date
        }
        s.division = settings.div.name
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
            s.dayMode[i] = day.max(by: { $0.total < $1.total })?.mode.rawValue ?? ""
        }
        return s
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
        s.dayMode = ["training", "sim", "", "training", "", "", ""]
        s.dayMin = [42, 78, 0, 34, 0, 0, 0]
        return s
    }
}
