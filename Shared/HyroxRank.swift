import Foundation

// MARK: - 상위 몇 % (80번 빌드 28 · 1.2.4 에 더블 추가 · 워치도 쓰게 Shared 로 옮김)

// 홈페이지 splits8/hyrox.html 과 같은 숫자
/// Open: HyroxDataLab(2026.3, 전 세계 Open 기록 70만 건+) 상위 10 / 25 / 50 / 75% 경계, 사이는 곧게 이음.
/// Pro: Rox Lyfe 단계(Elite 15 · 세계 수준 · 경쟁 수준 · Pro 평균).
/// 1.2.4 더블: Rox Lyfe 단계(상위권 · 경쟁 수준 · 더블 평균). 백분위 자료가 없어 % 없음. 릴레이는 자료가 없어 안 보임
struct HyroxRank {
    let level: String           // "Advanced" 등 (번역 키)
    let pct: Int?               // 상위 약 x% (Open 만)
    let group: String           // "Open Men"
    let next: (name: String, time: Int)?   // 다음 단계와 그 기준 시간
    let total: Int

    static let open: [String: [Int]] = ["M": [75 * 60, 85 * 60, 100 * 60, 114 * 60], "W": [86 * 60, 98 * 60, 114 * 60, 130 * 60]]
    static let pro: [String: [Int]] = ["M": [54 * 60, 58 * 60, 65 * 60, 81 * 60 + 1], "W": [57 * 60, 62 * 60, 70 * 60, 86 * 60 + 36]]

    /// 1.2.4 더블 (Rox Lyfe "What is a good HYROX time" — Pro 와 같은 출처): 상위권 · 경쟁 수준 · 평균 (초). Pro 더블은 평균만 (0 = 없음)
    static let doubles: [String: [Int]] = [
        "dblM": [52 * 60, 65 * 60, 77 * 60 + 49],
        "dblW": [58 * 60, 70 * 60, 89 * 60 + 24],
        "dblX": [55 * 60, 68 * 60, 84 * 60 + 4],
        "dblMP": [0, 0, 69 * 60 + 53],
        "dblWP": [0, 0, 79 * 60 + 49],
    ]

    static func of(division: String, total: Int) -> HyroxRank? {
        // 이름이나 키가 정확히 맞는 디비전만 (릴레이 등 모르는 값이 Open Men 으로 잡히지 않게)
        guard let d = Division.all.first(where: { $0.key == division || $0.name.caseInsensitiveCompare(division) == .orderedSame }) else { return nil }
        guard total >= 40 * 60, total <= 4 * 3600 else { return nil }
        let g: String = d.key.hasSuffix("W") ? "W" : "M"
        if d.key == "openM" || d.key == "openW", let b = open[g] {
            let names: [String] = ["Elite", "Advanced", "Intermediate", "Beginner"]
            let i: Int? = b.firstIndex { total < $0 }
            let level: String = i.map { names[$0] } ?? "First finish"
            let next: (name: String, time: Int)? = HyroxRank.nextStep(i, names: names, b: b)
            return HyroxRank(level: level, pct: max(1, Int(openPct(total, b).rounded())), group: d.name, next: next, total: total)
        }
        if d.key == "proM" || d.key == "proW", let b = pro[g] {
            let names: [String] = ["Elite 15 level", "World level", "Competitive level", "Faster than Pro average"]
            let i: Int? = b.firstIndex { total < $0 }
            let level: String = i.map { names[$0] } ?? "Slower than Pro average"
            let next: (name: String, time: Int)? = HyroxRank.nextStep(i, names: names, b: b)
            return HyroxRank(level: level, pct: nil, group: d.name, next: next, total: total)
        }
        if let b = doubles[d.key] {
            let tiers: [(name: String, time: Int)] = zip(["Top-end level", "Competitive level", "Faster than Doubles average"], b)
                .filter { $0.1 > 0 }.map { (name: $0.0, time: $0.1) }
            let i: Int? = tiers.firstIndex { total < $0.time }
            let level: String = i.map { tiers[$0].name } ?? "Slower than Doubles average"
            let next: (name: String, time: Int)?
            if let i { next = i > 0 ? tiers[i - 1] : nil } else { next = tiers.last }
            return HyroxRank(level: level, pct: nil, group: d.name, next: next, total: total)
        }
        return nil
    }

    /// 다음 단계 (i = 지금 단계 번호, nil = 마지막 경계보다 느림 → 맨 끝 단계가 다음)
    static func nextStep(_ i: Int?, names: [String], b: [Int]) -> (name: String, time: Int)? {
        guard let i else { return (name: names[3], time: b[3]) }
        if i == 0 { return nil }
        return (name: names[i - 1], time: b[i - 1])
    }

    /// 홈페이지 openPct 와 같음: (경계×0.85 → 1%), 10, 25, 50, 75, (경계×1.25 → 97%)
    static func openPct(_ t: Int, _ b: [Int]) -> Double {
        let pts: [(Double, Double)] = [(Double(b[0]) * 0.85, 1), (Double(b[0]), 10), (Double(b[1]), 25),
                                       (Double(b[2]), 50), (Double(b[3]), 75), (Double(b[3]) * 1.25, 97)]
        let x: Double = Double(t)
        if x <= pts[0].0 { return 1 }
        if x >= pts[5].0 { return 97 }
        for i in 1..<pts.count where x <= pts[i].0 {
            let a = pts[i - 1], c = pts[i]
            return a.1 + (c.1 - a.1) * (x - a.0) / (c.0 - a.0)
        }
        return 97
    }
}


extension Record {
    /// 1.2.4: 대회 공식 결과로 넣은 기록
    var isOfficial: Bool { official != nil }
}

// MARK: - 1.2.4 · 공식 기록 (대회 공식 결과 캡처에서 읽은 값, 사용자가 확인 · 고친 것)

struct OfficialResult: Codable, Hashable {
    /// Rank (M/W) — 같은 디비전 · 성별 안 순위
    var rank: Int? = nil
    /// Rank (AG) — 나이대 순위
    var ageRank: Int? = nil
    /// 참가 인원 (선택, 사용자가 넣음) → 상위 %
    var field: Int? = nil
    /// 공식 완주 시간(초)
    var time: Int
    var event: String
    var division: String

    var topPct: Double? {
        guard let r = rank, let f = field, f > 0, r > 0, r <= f else { return nil }
        return Double(r) / Double(f) * 100
    }
}

/// 공식 결과 캡처의 글자 → 값. 홈페이지 ocr.js 와 같은 규칙 + 순위 (Rank (M/W) · Rank (AG))
/// results.hyrox.com: "Running 1 00:03:09" · "1000m SkiErg 00:04:07 45" · "Roxzone Time" · "Overall Time 01:06:47" · "Rank (M/W) 90" · "Rank (AG) 18"
enum OfficialParse {
    struct Draft: Equatable {
        var total: Int? = nil
        var rank: Int? = nil
        var ageRank: Int? = nil
        var runs: [Int?] = Array(repeating: nil, count: 8)
        var st: [Int?] = Array(repeating: nil, count: 8)
        var rox: Int? = nil
        /// 읽은 칸 수 (0 이면 못 읽음)
        var found: Int {
            [total, rank, ageRank, rox].compactMap { $0 }.count + runs.compactMap { $0 }.count + st.compactMap { $0 }.count
        }
    }

    /// 시간 글자 → 초. 0:04:35 · 04:35 · 4:35.2
    static func sec(_ t: String) -> Int? {
        let p: [Double] = t.split(separator: ":").compactMap { Double($0) }
        guard p.count == t.split(separator: ":").count, p.count >= 2 else { return nil }
        let s: Double = p.count == 3 ? p[0] * 3600 + p[1] * 60 + p[2] : p[0] * 60 + p[1]
        return Int(s.rounded())
    }

    /// 한 줄의 시간들 (10초 미만 버림). 숫자 사이의 O→0, l·I·|→1
    static func times(_ line: String) -> [Int] {
        var l: String = line.replacingOccurrences(of: #"\s*:\s*"#, with: ":", options: .regularExpression)
        if let re = try? NSRegularExpression(pattern: #"[\dOolI|:]{3,}"#) {
            let ns = l as NSString
            var out = ""
            var last = 0
            for m in re.matches(in: l, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                var w: String = ns.substring(with: m.range)
                if w.rangeOfCharacter(from: .decimalDigits) != nil && w.contains(":") {
                    w = w.replacingOccurrences(of: "[Oo]", with: "0", options: .regularExpression)
                        .replacingOccurrences(of: "[lI|]", with: "1", options: .regularExpression)
                }
                out += w
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            l = out
        }
        guard let re = try? NSRegularExpression(pattern: #"(?:\d{1,2}:)?\d{1,2}:\d{2}(?:\.\d+)?"#) else { return [] }
        let ns = l as NSString
        return re.matches(in: l, range: NSRange(location: 0, length: ns.length))
            .compactMap { sec(ns.substring(with: $0.range)) }
            .filter { $0 >= 10 }
    }

    /// 줄 안의 순위 숫자 (시간 글자를 뺀 뒤 첫 정수)
    static func rankNum(_ line: String) -> Int? {
        let noTime: String = line.replacingOccurrences(of: #"(?:\d{1,2}:)?\d{1,2}:\d{2}(?:\.\d+)?"#, with: " ", options: .regularExpression)
        let afterLabel: String = noTime.replacingOccurrences(of: #"(?i)rank\s*\((?:m/?w|ag)\)|rank|순위|\(m/?w\)|\(ag\)"#, with: " ", options: .regularExpression)
        guard let r = afterLabel.range(of: #"\d{1,6}"#, options: .regularExpression), let n = Int(afterLabel[r]), n > 0 else { return nil }
        return n
    }

    private static func has(_ l: String, _ p: String) -> Bool { l.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil }

    /// 스테이션 이름 → Station.all 순서 (0~7). 결과 페이지 이름: 1000m SkiErg · 50m Sled Push · 50m Sled Pull ·
    /// 80m Burpee Broad Jump · 1000m Row · 200m Farmers Carry · 100m Sandbag Lunges · Wall Balls
    static let stKeys: [(Int, String)] = [
        (1, #"sled\s*push"#), (2, #"sled\s*pull"#), (0, #"ski\s*-?\s*erg"#), (3, #"burpee"#),
        (4, #"\brow(ing)?\b"#), (5, #"farmer"#), (6, #"lunge"#), (7, #"wall\s*-?\s*ball"#),
    ]

    static func parse(_ text: String) -> Draft {
        var d = Draft()
        let lines: [String] = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var all: [Int] = []
        for (i, l) in lines.enumerated() {
            var ts: [Int] = times(l)
            if ts.isEmpty, i + 1 < lines.count { ts = times(lines[i + 1]) }     // 이름과 시간이 다른 줄로 읽힌 경우
            all += times(l)
            // 순위: "Rank (AG) 18" / "Rank (M/W) 90" (숫자가 다음 줄이면 다음 줄)
            if has(l, #"rank|순위"#) {
                let n: Int? = rankNum(l) ?? (i + 1 < lines.count && times(lines[i + 1]).isEmpty ? rankNum(lines[i + 1]) : nil)
                if has(l, #"\(\s*ag\s*\)|age\s*group|나이"#) { if d.ageRank == nil { d.ageRank = n } }
                else if d.rank == nil { d.rank = n }
                continue
            }
            if let m = l.range(of: #"(?i)\brun(?:ning)?\s*([1-8])\b|러닝\s*([1-8])"#, options: .regularExpression), !ts.isEmpty {
                let digits = l[m].filter(\.isNumber)
                if let k = Int(String(digits.last ?? "0")), (1...8).contains(k), d.runs[k - 1] == nil { d.runs[k - 1] = ts[0] }
                continue
            }
            if has(l, #"\brun(ning)?\b|러닝"#) && !has(l, "rox") { continue }      // Run Total · Best Run Lap
            if has(l, #"rox\s*zone|록스존"#) { if d.rox == nil, let t = ts.first { d.rox = t }; continue }
            if let k = stKeys.first(where: { has(l, $0.1) }) {
                if d.st[k.0] == nil, let t = ts.first { d.st[k.0] = t }
                continue
            }
            if has(l, #"(overall|finish|final|total)\s*time|^total\b|^time\b|완주"#) && !has(l, "rox|run"), let mx = ts.max() {
                d.total = max(d.total ?? 0, mx)
            }
        }
        if d.total == nil { d.total = all.filter { $0 >= 40 * 60 && $0 <= 4 * 3600 }.max() }
        // 말이 안 되는 값 빼기 (러닝 2~20분, 스테이션 30초~20분, Roxzone 1~25분)
        for i in 0..<8 {
            if let v = d.runs[i], v < 120 || v > 1200 { d.runs[i] = nil }
            if let v = d.st[i], v < 30 || v > 1200 { d.st[i] = nil }
        }
        if let v = d.rox, v < 60 || v > 1500 { d.rox = nil }
        return d
    }

    /// 확인 · 고친 값 → 기록 (레이스 · 공식). 러닝 8 · 스테이션 8 을 하이록스 순서로, 록스존은 맨 뒤에 합 하나
    static func record(runs: [Int], st: [Int], rox: Int, official: OfficialResult, date: Date) -> Record {
        let d: Division = Division.of(official.division)
        var segs: [SegResult] = []
        for i in 0..<8 {
            segs.append(SegResult(icon: "run", name: "Run \(i + 1)", detail: "1KM", kind: .run, time: runs[i], target: 0))
            let s: Station = Station.all[i]
            segs.append(SegResult(icon: s.key, name: s.name, detail: s.detail(d), kind: .st, time: st[i], target: 0))
        }
        if rox > 0 { segs.append(SegResult(icon: "roxzone", name: "Roxzone", detail: "Transition", kind: .rox, time: rox, target: 0)) }
        var r = Record(mode: .race, title: official.event, date: date, total: official.time, segs: segs, hr: [],
                       kcal: 0, avgHR: 0, maxHR: 0, division: official.division, goal: nil, vsWord: "VS GOAL", vsTarget: nil)
        r.complete = true
        r.source = "official"
        r.official = official
        return r
    }
}
