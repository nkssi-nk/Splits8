import Foundation

// MARK: - 18번 · 트레이닝 새 종류: 인터벌 러닝 · 타바타 · EMOM · AMRAP · 기능성 운동(웨이트)
// HIIT · 러닝 카드처럼 Program.kind 하나로 구분하고, 구간(Seg) 순서로 펼쳐서 워치 · 아이폰 엔진이 그대로 진행.
//  - 시간으로 넘어가는 구간: Seg.auto (초)  → 엔진이 1초마다 보고 저절로 다음 구간 (경계 시각을 정확히 맞춤)
//  - 거리로 넘어가는 구간:  Seg.autoM (m)  → GPS · 워치 거리로 저절로 다음 단계 (인터벌 러닝)
//  - 기록: SegResult.tag · no · work · kg · tp 에 종류별 값. 하이록스 PB · 순위 · 시뮬 통계에는 안 들어감.

enum WKind {
    static let hiit = "hiit"
    static let run = "run"
    static let interval = "interval"
    static let tabata = "tabata"
    static let emom = "emom"
    static let amrap = "amrap"
    static let strength = "strength"

    /// 트레이닝 만들기 카드 순서 (하이록스 트레이닝 = nil 이 맨 앞)
    static let menu: [String?] = [nil, run, interval, hiit, tabata, emom, amrap, strength]
    /// 18번에서 새로 생긴 종류
    static let fresh: Set<String> = [interval, tabata, emom, amrap, strength]
    /// "타이머 + 라운드" 종류 (시작 전 음성 3 · 2 · 1)
    static let timers: Set<String> = [tabata, emom, amrap]

    static func isNew(_ k: String?) -> Bool { fresh.contains(k ?? "") }
    static func isTimer(_ k: String?) -> Bool { timers.contains(k ?? "") }

    /// 기능성 운동 구간 아이콘 (스테이션 아이콘과 겹치지 않게 — 스테이션 최고 기록에 섞이지 않음)
    static let strengthIcon = "modeTraining"
    /// 휴식 구간 아이콘
    static let restIcon = "roxzone"

    static func icon(_ k: String?) -> String {
        switch k ?? "" {
        case run, interval: return "run"
        case strength: return strengthIcon
        case "": return "modeTraining"
        default: return "hiit"
        }
    }

    /// 메뉴 카드 이름 (번역 키)
    static func label(_ k: String?) -> String {
        switch k ?? "" {
        case "": return "HYROX training"
        case run: return "Running"
        case interval: return "Interval run"
        case hiit: return "HIIT"
        case tabata: return "Tabata"
        case emom: return "EMOM"
        case amrap: return "AMRAP"
        case strength: return "Strength"
        default: return k ?? ""
        }
    }

    /// 메뉴 카드 설명 (번역 키)
    static func sub(_ k: String?) -> String {
        switch k ?? "" {
        case "": return "Runs · stations · sets"
        case run: return "Distance · 1 km splits"
        case interval: return "Fast / easy steps × repeats"
        case hiit: return "High-intensity intervals"
        case tabata: return "20s work / 10s rest × 8"
        case emom: return "Every minute on the minute"
        case amrap: return "As many rounds as possible"
        case strength: return "Sets · reps · weight"
        default: return ""
        }
    }
}

// MARK: - 인터벌 러닝 단계

struct IntervalStep: Codable, Hashable {
    /// fast / easy / walk / rest
    var type: String
    /// 거리 단계(m) — secs 와 둘 중 하나
    var meters: Int? = nil
    /// 시간 단계(초)
    var secs: Int? = nil
    /// 목표 페이스 (초/km, 선택)
    var pace: Int? = nil

    static let types: [String] = ["fast", "easy", "walk", "rest"]

    /// "Fast" / "Easy" / "Walk" / "Rest" (번역 키)
    static func typeName(_ t: String) -> String {
        switch t {
        case "fast": return "Fast"
        case "easy": return "Easy"
        case "walk": return "Walk"
        default: return "Rest"
        }
    }

    /// "500 m" / "1 km" / "1:00"
    var amount: String {
        if let m = meters {
            if m >= 1000 && m % 100 == 0 {
                let km: Double = Double(m) / 1000
                return (m % 1000 == 0 ? "\(m / 1000)" : String(format: "%.1f", km)) + " km"
            }
            return "\(m) m"
        }
        return Fm.t(secs ?? 60)
    }

    /// "500 m Fast" (번역됨)
    var text: String { amount + " " + IntervalStep.typeName(type).l10n.lowercased() }

    /// 이 단계가 기록에서 달린 거리로 쓸 계획 거리 (시간 단계 = 0)
    var planMeters: Double { Double(meters ?? 0) }

    /// Seg.detail (runMeters 가 읽을 수 있는 모양: "500M", 시간 단계는 "0M")
    var detail: String { meters.map { "\($0)M" } ?? "0M" }
}

/// 인터벌 러닝 예시 (바로 고르기)
struct IntervalPreset: Identifiable {
    let id: String
    let name: String
    let steps: [IntervalStep]
    let repeats: Int

    static let all: [IntervalPreset] = [
        IntervalPreset(id: "400x8", name: "400 m × 8",
                       steps: [IntervalStep(type: "fast", meters: 400), IntervalStep(type: "easy", meters: 200)], repeats: 8),
        IntervalPreset(id: "500-300x6", name: "500 m / 300 m × 6",
                       steps: [IntervalStep(type: "fast", meters: 500), IntervalStep(type: "easy", meters: 300)], repeats: 6),
        IntervalPreset(id: "1kx5", name: "1 km × 5",
                       steps: [IntervalStep(type: "fast", meters: 1000), IntervalStep(type: "rest", secs: 120)], repeats: 5),
        IntervalPreset(id: "1m1mx10", name: "1 min / 1 min × 10",
                       steps: [IntervalStep(type: "fast", secs: 60), IntervalStep(type: "easy", secs: 60)], repeats: 10),
    ]
}

// MARK: - 기능성 운동 (웨이트) 종목

struct StrengthMove: Codable, Hashable {
    var name: String
    var sets: Int
    var reps: Int
    var kg: Double

    /// 고르기 목록 (번역 키). 직접 입력도 됨
    static let catalog: [String] = ["Squat", "Deadlift", "Bench press", "Overhead press", "Kettlebell swing",
                                    "Goblet squat", "Lunge", "Pull-up", "Push-up", "Barbell row"]

    /// "60 kg" / "22.5 kg" / 맨몸 "BW"
    static func kgText(_ kg: Double) -> String {
        if kg <= 0 { return "BW" }
        return (kg == kg.rounded() ? "\(Int(kg))" : String(format: "%.1f", kg)) + " kg"
    }
}

// MARK: - 카드 만들기 (기본값)

extension Program {
    static let tabataDefault: (work: Int, rest: Int, rounds: Int) = (20, 10, 8)
    static let emomChoices: [Int] = [30, 45, 60, 90, 120, 180, 240, 300]
    static let restChoices: [Int] = [30, 45, 60, 90, 120, 180]

    /// 타바타 기본 이름 "Tabata", 직접 설정하면 "Interval timer 40/20"
    static func tabataName(work: Int, rest: Int) -> String {
        (work == tabataDefault.work && rest == tabataDefault.rest) ? "Tabata" : "Interval timer \(work)/\(rest)"
    }
    /// EMOM 간격 이름: 1분 = EMOM, 2분 = E2MOM, 30초 = E30sMOM
    static func emomLabel(_ every: Int) -> String {
        if every % 60 == 0 { return every == 60 ? "EMOM" : "E\(every / 60)MOM" }
        return "E\(every)sMOM"
    }
    /// "EMOM 12 min" · "AMRAP 15 min" (분이 딱 떨어지지 않으면 "EMOM 7:30")
    static func timedName(_ head: String, _ sec: Int) -> String {
        sec % 60 == 0 ? "\(head) \(sec / 60) min" : "\(head) \(Fm.t(sec))"
    }

    static func tabata(work: Int = 20, rest: Int = 10, rounds: Int = 8, id: String? = nil) -> Program {
        Program(id: id ?? ("tabata." + UUID().uuidString.prefix(6)), name: tabataName(work: work, rest: rest), sets: 1,
                seq: [ProgItem(icon: "hiit")], meta: nil, kind: WKind.tabata, work: work, rest: rest, rounds: rounds)
    }
    static func emom(every: Int = 60, rounds: Int = 12, task: String? = nil, id: String? = nil) -> Program {
        Program(id: id ?? ("emom." + UUID().uuidString.prefix(6)), name: timedName(emomLabel(every), every * rounds), sets: 1,
                seq: [ProgItem(icon: "hiit")], meta: nil, kind: WKind.emom, rounds: rounds, every: every, task: task)
    }
    static func amrap(cap: Int = 15 * 60, task: String? = nil, id: String? = nil) -> Program {
        Program(id: id ?? ("amrap." + UUID().uuidString.prefix(6)), name: timedName("AMRAP", cap), sets: 1,
                seq: [ProgItem(icon: "hiit")], meta: nil, kind: WKind.amrap, cap: cap, task: task)
    }
    static func interval(_ preset: IntervalPreset = IntervalPreset.all[1], indoor: Bool = false, id: String? = nil) -> Program {
        Program(id: id ?? ("interval." + UUID().uuidString.prefix(6)), name: preset.name, sets: 1,
                seq: [ProgItem(icon: "run", run: "1KM")], meta: nil, kind: WKind.interval, runKm: nil, indoor: indoor,
                steps: preset.steps, repeats: preset.repeats)
    }
    static func strength(moves: [StrengthMove] = [StrengthMove(name: "Squat", sets: 3, reps: 10, kg: 40)], rest: Int = 90,
                         id: String? = nil) -> Program {
        Program(id: id ?? ("strength." + UUID().uuidString.prefix(6)), name: "Strength", sets: 1,
                seq: [ProgItem(icon: WKind.strengthIcon)], meta: nil, kind: WKind.strength, rest: rest, moves: moves)
    }

    /// 같은 설정인지 (id 는 빼고 비교 — "이미 워치 목록에 있음")
    func sameSetup(_ o: Program) -> Bool {
        var a: Program = self, b: Program = o
        a.id = ""; b.id = ""
        a.quick = false; b.quick = false
        return a == b
    }

    /// 18번 새 종류 카드 설명 한 줄 (번역됨). 다른 종류는 nil
    var kindLine: String? {
        switch kind ?? "" {
        case WKind.tabata:
            let w: Int = work ?? 20, r: Int = rest ?? 10, n: Int = rounds ?? 8
            return String(format: "%lld s work / %lld s rest × %lld".l10n, w, r, n)
        case WKind.emom:
            let e: Int = every ?? 60, n: Int = rounds ?? 12
            return String(format: "Every %@ × %lld rounds".l10n, Fm.t(e), n)
        case WKind.amrap:
            let firstTask: String = (task ?? "").split(separator: "\n").first.map(String.init) ?? ""
            return firstTask.isEmpty ? String(format: "%@ · as many rounds as possible".l10n, Fm.t(cap ?? 900))
                                     : Fm.t(cap ?? 900) + " · " + firstTask
        case WKind.interval:
            let st: [IntervalStep] = steps ?? []
            let body: String = st.map(\.text).joined(separator: " / ")
            let place: String = ((indoor ?? false) ? "Indoor" : "Outdoor").l10n
            return "\(body) × \(repeats ?? 1) · " + place
        case WKind.strength:
            let m: [StrengthMove] = moves ?? []
            let names: String = m.prefix(3).map { $0.name.l10n }.joined(separator: " · ")
            let sets: Int = m.map(\.sets).reduce(0, +)
            return names + (m.count > 3 ? " …" : "") + " · " + String(format: "%lld sets".l10n, sets)
        default:
            return nil
        }
    }

    /// 인터벌 러닝 단계 전체 (워밍업 + 묶음 × N + 쿨다운)
    var intervalPlan: [(step: IntervalStep, no: Int?)] {
        var o: [(step: IntervalStep, no: Int?)] = []
        if let w = warm { o.append((w, nil)) }
        let st: [IntervalStep] = steps ?? []
        if !st.isEmpty {
            for k in 1...max(1, repeats ?? 1) {
                for s in st { o.append((s, k)) }
            }
        }
        if let c = cool { o.append((c, nil)) }
        return o
    }
}

// MARK: - 구간 순서

extension SeqBuilder {
    /// AMRAP 라운드 (끝 없이 늘어남 — 총 시간이 되면 끝)
    static func amrapRound(_ n: Int) -> Seg {
        Seg(icon: "hiit", name: "Round \(n)", detail: "AMRAP", kind: .st, target: 0, tag: "round", no: n)
    }

    static func newKind(_ p: Program) -> [Seg] {
        switch p.kind ?? "" {
        case WKind.tabata:
            let w: Int = max(5, p.work ?? 20), r: Int = max(0, p.rest ?? 10), n: Int = max(1, p.rounds ?? 8)
            var o: [Seg] = []
            for i in 1...n {
                o.append(Seg(icon: "hiit", name: "Round \(i)", detail: "Work", kind: .st, target: w, auto: w, tag: "work", no: i))
                if i < n && r > 0 {
                    o.append(Seg(icon: WKind.restIcon, name: "Rest", detail: "Rest", kind: .st, target: r, auto: r, tag: "rest", no: i))
                }
            }
            return o
        case WKind.emom:
            let e: Int = max(10, p.every ?? 60), n: Int = max(1, p.rounds ?? 12)
            return (1...n).map { i in
                Seg(icon: "hiit", name: "Round \(i)", detail: "EMOM", kind: .st, target: e, auto: e, tag: "round", no: i)
            }
        case WKind.amrap:
            return [amrapRound(1)]
        case WKind.interval:
            let plan = p.intervalPlan
            if plan.isEmpty { return [runKm(1)] }
            let last: Int = plan.count - 1
            return plan.enumerated().map { i, x in
                let s: IntervalStep = x.step
                let name: String
                if x.no == nil { name = i == 0 && p.warm != nil ? "Warm-up" : (i == last && p.cool != nil ? "Cool-down" : IntervalStep.typeName(s.type)) }
                else { name = IntervalStep.typeName(s.type) }
                return Seg(icon: "run", name: name, detail: s.detail, kind: .run, target: s.secs ?? 0,
                           auto: s.secs, autoM: s.meters, tag: s.type, tp: s.pace, no: x.no)
            }
        case WKind.strength:
            let moves: [StrengthMove] = (p.moves ?? []).filter { $0.sets > 0 }
            if moves.isEmpty { return [hiitRound(1)] }
            let rest: Int = max(0, p.rest ?? 90)
            var o: [Seg] = []
            for (mi, m) in moves.enumerated() {
                for k in 1...m.sets {
                    o.append(Seg(icon: WKind.strengthIcon, name: m.name, detail: "\(m.reps) × " + StrengthMove.kgText(m.kg),
                                 kind: .st, target: 0, tag: "set", no: k, reps: m.reps, kg: m.kg))
                    let lastAll: Bool = mi == moves.count - 1 && k == m.sets
                    if !lastAll && rest > 0 {
                        o.append(Seg(icon: WKind.restIcon, name: "Rest", detail: "Rest", kind: .st, target: rest, auto: rest, tag: "rest"))
                    }
                }
            }
            return o
        default:
            return [hiitRound(1)]
        }
    }
}

// MARK: - 운동 중 화면 한 장 (워치 · 아이폰 같이 씀)

struct TimerFace {
    /// 큰 이름표 (번역 키): WORK · REST · ROUND · FAST · SET …
    var label: String
    /// 큰 숫자 ("0:17" · "320 m")
    var main: String
    /// 휴식 · 천천히 화면 (회색). false = 노랑
    var rest: Bool
    /// "3 / 8" 같은 몇 번째 (없으면 "")
    var count: String
    /// 아래 작은 줄 (할 일 · 무게 · 목표 페이스)
    var line: String
    /// 다음 안내 (번역됨, 없으면 "")
    var next: String
    /// 이번 단계 남은 초 (3 · 2 · 1 진동용). 시간으로 안 넘어가면 nil
    var remain: Int?
}

enum TimerFaces {
    /// kind: 운동 종류 · done: EMOM 이번 라운드를 "끝" 낸 초 · task: EMOM · AMRAP 할 일
    static func make(kind: String, seq: [Seg], idx: Int, segEl: Int, total: Int, cap: Int?,
                     segDist: Double?, done: Int?, task: String?) -> TimerFace {
        let cur: Seg = seq.indices.contains(idx) ? seq[idx] : (seq.last ?? SeqBuilder.hiitRound(1))
        let remain: Int? = cur.auto.map { max(0, $0 - segEl) }
        let nx: String = nextText(kind: kind, seq: seq, idx: idx)
        let tasks: String = (task ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
        switch kind {
        case WKind.tabata:
            let works: Int = seq.filter { $0.tag == "work" }.count
            let isRest: Bool = cur.tag == "rest"
            return TimerFace(label: isRest ? "REST" : "WORK", main: Fm.t(remain ?? 0), rest: isRest,
                             count: "\(cur.no ?? 1) / \(works)", line: "", next: nx, remain: remain)
        case WKind.emom:
            let line: String = done.map { String(format: "Done in %@ · rest".l10n, Fm.t($0)) } ?? tasks
            return TimerFace(label: done == nil ? "ROUND" : "REST", main: Fm.t(remain ?? 0), rest: done != nil,
                             count: "\(idx + 1) / \(seq.count)", line: line, next: nx, remain: remain)
        case WKind.amrap:
            let left: Int = max(0, (cap ?? 0) - total)
            let line: String = String(format: "Round %lld · %@".l10n, idx + 1, Fm.t(segEl)) + (tasks.isEmpty ? "" : " · " + tasks)
            return TimerFace(label: "ROUNDS", main: Fm.t(left), rest: false, count: "\(idx)", line: line, next: "", remain: nil)
        case WKind.interval:
            let reps: Int = seq.compactMap(\.no).max() ?? 1
            let label: String
            if cur.no == nil { label = cur.name == "Cool-down" ? "COOL-DOWN" : (cur.name == "Warm-up" ? "WARM-UP" : cur.name.uppercased()) }
            else { label = IntervalStep.typeName(cur.tag ?? "fast").uppercased() }
            var main: String = Fm.t(remain ?? segEl)
            if let m = cur.autoM {
                let left: Int = max(0, m - Int((segDist ?? 0).rounded()))
                main = segDist == nil ? "\(m) m" : "\(left) m"
            }
            let line: String = cur.tp.map { String(format: "Target %@ /km".l10n, Fm.t($0)) } ?? ""
            return TimerFace(label: label, main: main, rest: cur.tag != "fast", count: cur.no.map { "\($0) / \(reps)" } ?? "",
                             line: line, next: nx, remain: remain)
        case WKind.strength:
            if cur.tag == "rest" {
                return TimerFace(label: "REST", main: Fm.t(remain ?? 0), rest: true, count: "", line: "", next: nx, remain: remain)
            }
            let sets: Int = seq.filter { $0.tag == "set" && $0.name == cur.name }.count
            let line: String = String(format: "%lld reps × %@".l10n, cur.reps ?? 0, StrengthMove.kgText(cur.kg ?? 0))
            return TimerFace(label: "SET", main: Fm.t(segEl), rest: false, count: "\(cur.no ?? 1) / \(sets)",
                             line: line, next: nx, remain: nil)
        default:
            return TimerFace(label: "ROUND", main: Fm.t(segEl), rest: false, count: "\(idx + 1)", line: "", next: nx, remain: nil)
        }
    }

    /// "Next: 300 m easy" / "Next: Rest" / "Next: Squat · set 2" (번역됨). 마지막이면 "Last one" 계열
    static func nextText(kind: String, seq: [Seg], idx: Int) -> String {
        guard seq.indices.contains(idx + 1) else {
            return kind == WKind.amrap ? "" : "Last one".l10n
        }
        let n: Seg = seq[idx + 1]
        let what: String
        switch kind {
        case WKind.interval:
            let amount: String = n.autoM.map { m in IntervalStep(type: n.tag ?? "easy", meters: m).amount } ?? Fm.t(n.auto ?? 0)
            what = amount + " " + IntervalStep.typeName(n.tag ?? "easy").l10n.lowercased()
        case WKind.strength:
            what = n.tag == "rest" ? "Rest".l10n + " " + Fm.t(n.auto ?? 0)
                                    : n.name.l10n + " · " + String(format: "set %lld".l10n, n.no ?? 1)
        default:
            if n.tag == "rest" { what = "Rest".l10n }
            else if n.tag == "work" { what = "Work".l10n }
            else if let k = n.no { what = String(format: "Round %lld".l10n, k) }
            else { what = n.name.l10n }
        }
        return String(format: "Next: %@".l10n, what)
    }
}

// MARK: - 기록 값

extension SegResult {
    /// 18번: 새 종류 구간 기록 값 (워치 WorkoutEngine · 아이폰 PhoneRunEngine 같은 규칙)
    mutating func fillKind(_ s: Seg, kind: String?, work: Int?, partial: Bool) {
        tag = s.tag
        no = s.no
        tp = s.tp
        self.work = work
        if kind == WKind.strength && s.tag == "set" {
            reps = s.reps
            kg = s.kg
        }
        // 인터벌 러닝: 거리를 못 쟀으면 계획 거리 (시간 단계는 0) — 주간 거리에 1 km 로 잘못 들어가지 않게
        if kind == WKind.interval && s.kind == .run && (dist ?? 0) <= 0 { dist = Double(s.autoM ?? 0) }
        if kind == WKind.amrap && partial { tag = "part" }
    }
}

// MARK: - 기록 요약

extension Record {
    /// AMRAP: 다 한 라운드 수 (마지막 덜 한 라운드는 뺌)
    var fullRounds: Int { segs.filter { $0.tag == "round" }.count }
    /// 타바타: 운동 라운드 수
    var workRounds: Int { segs.filter { $0.tag == "work" }.count }
    /// 기능성: 총 들어 올린 무게 (횟수 × kg)
    var volume: Double {
        segs.filter { $0.tag == "set" }.reduce(0) { $0 + Double($1.reps ?? 0) * ($1.kg ?? 0) }
    }
    /// 인터벌 러닝: 빠른 단계만 모은 평균 페이스 (초/km)
    var fastPace: Int? {
        let f: [SegResult] = segs.filter { $0.tag == "fast" && ($0.dist ?? 0) > 50 }
        let m: Double = f.reduce(0) { $0 + ($1.dist ?? 0) }
        guard m > 0 else { return nil }
        return Int((Double(f.map(\.time).reduce(0, +)) / m * 1000).rounded())
    }

    /// 한 줄 요약 (번역됨) — 워치 끝 화면 · 아이폰 끝 카드 · 기록 화면. 새 종류가 아니면 nil
    var kindSummary: String? {
        switch kind ?? "" {
        case WKind.tabata:
            return String(format: "%lld rounds".l10n, workRounds) + (complete == false ? " · " + "Ended early".l10n : "")
        case WKind.emom:
            let done: Int = segs.filter { $0.work != nil }.count
            return String(format: "%lld rounds · %lld done in time".l10n, segs.count, done)
        case WKind.amrap:
            let e: Int = extra ?? 0
            return e > 0 ? String(format: "%lld rounds + %lld reps".l10n, fullRounds, e)
                         : String(format: "%lld rounds".l10n, fullRounds)
        case WKind.interval:
            let d: Double = segs.filter { $0.kind == .run }.reduce(0) { $0 + ($1.dist ?? 0) }
            var s: String = String(format: "%.2f km", d / 1000)
            if let p = fastPace { s += " · " + String(format: "Fast avg %@ /km".l10n, Fm.t(p)) }
            return s
        case WKind.strength:
            let sets: Int = segs.filter { $0.tag == "set" }.count
            return String(format: "%lld sets · %@ kg".l10n, sets, Int(volume.rounded()).formatted(.number.grouping(.automatic)))
        default:
            return nil
        }
    }
}

// MARK: - 이름 번역 ("EMOM 12 min" → "EMOM 12분", "Interval timer 40/20" → "인터벌 타이머 40/20")

enum KindTitle {
    /// String.l10n 이 번역을 못 찾았을 때 부름. 모양이 맞지 않으면 nil
    static func localize(_ s: String) -> String? {
        guard s.count <= 40 else { return nil }
        if s.hasPrefix("Interval timer ") {
            let rest: [Substring] = s.dropFirst("Interval timer ".count).split(separator: "/")
            if rest.count == 2, let a = Int(rest[0]), let b = Int(rest[1]) {
                return String(format: "Interval timer %lld/%lld".l10n, a, b)
            }
            return nil
        }
        guard s.hasSuffix(" min"), s.hasPrefix("AMRAP ") || (s.hasPrefix("E") && s.contains("MOM ")) else { return nil }
        let parts: [Substring] = s.dropLast(4).split(separator: " ")
        guard parts.count == 2, let n = Int(parts[1]) else { return nil }
        return String(format: "%@ %lld min".l10n, String(parts[0]), n)
    }
}
