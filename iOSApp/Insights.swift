import SwiftUI

// MARK: - 55번 · 기록 화면 "Insights" (기록 숫자로 계산한 분석 2~4줄, AI 아님)
//
// 고르는 규칙 (시안7):
//  ① 최대 4줄, 같은 묶음에서는 하나만
//  ② 점수가 큰 것부터: 새 최고 기록(400) > 큰 차이 30초 이상(300) > 흐름 3번 연속(200) > 참고(100)
//  ③ 5초 미만 차이는 안 보여 줌
//  ④ 같은 기록은 열 때마다 같은 4줄 (계산만 하고 무작위 없음)
//  ⑤ 회색 조언 한마디는 4줄 중 1개에만
//  ⑥ 아이폰으로만 기록한 것은 심박 · 횟수 줄 빠짐
//
// 문장 안의 [y]…[/y] 노랑, [r]…[/r] 빨강, [g]…[/g] 초록 (번역 문장에도 같은 표시를 넣음)

struct Insight: Identifiable {
    enum Mark { case up, down, star, time, pct, heart, even, info }
    let id: Int            // 규칙 번호 1…42
    let group: String
    let score: Int
    let mark: Mark
    let text: String
    var tip: String? = nil
}

enum Insights {
    static let newBest = 400, big = 300, trend = 200, info = 100
    static let minDiff = 5

    /// 이 기록의 분석 줄 (최대 4)
    static func make(_ r: Record, store: Store) -> [Insight] {
        let all: [Insight] = candidates(r, store: store)
        let phone: Bool = r.source == "phone" || r.hr.isEmpty
        let sorted = all
            .filter { !(phone && ($0.group == "hr" || $0.group == "reps")) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }
        var used: Set<String> = []
        var out: [Insight] = []
        for x in sorted where !used.contains(x.group) {
            used.insert(x.group)
            out.append(x)
            if out.count == 4 { break }
        }
        // 조언은 맨 위에서 처음 나오는 하나만
        var tipShown = false
        for i in out.indices {
            if out[i].tip != nil {
                if tipShown { out[i].tip = nil } else { tipShown = true }
            }
        }
        return out
    }

    // MARK: 계산

    private static func sec(_ v: Int) -> String { Fm.t(abs(v)) }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func candidates(_ r: Record, store: Store) -> [Insight] {
        guard r.isComplete || r.mode == .training else { return [] }
        var o: [Insight] = []
        let main: [SegResult] = r.mainSegs
        let runs: [SegResult] = r.runs
        let stations: [SegResult] = main.filter { $0.kind == .st }
        let before: [Record] = store.records.filter { $0.id != r.id && $0.date < r.date && $0.counts }
        let fullRace: Bool = (r.mode == .sim || r.mode == .race) && r.splits16 != nil
        let st = store.settings

        // ── 러닝 ─────────────────────────────
        if fullRace, let s = r.splits16 {
            let rs: [Int] = stride(from: 0, to: 16, by: 2).map { s[$0] }
            let avg: Int = rs.reduce(0, +) / 8
            // 1 어디서 처졌나 (스테이션 i 다음 러닝)
            var worstI = -1, worstD = 0
            for i in 0..<7 where rs[i + 1] - avg > worstD { worstD = rs[i + 1] - avg; worstI = i }
            if worstI >= 0 && worstD >= minDiff {
                o.append(Insight(id: 1, group: "run", score: worstD >= 30 ? big : info, mark: .down,
                                 text: String(localized: "Your runs slowed most after [y]\(Fatigue.names[worstI])[/y] — [r]+\(worstD)s[/r] on your average run.")))
            }
            // 18 초반이 너무 빠름
            let rest: [Int] = Array(rs.dropFirst())
            let restAvg: Int = rest.reduce(0, +) / max(1, rest.count)
            let late: Int = rs.suffix(4).reduce(0, +) / 4, early: Int = rs.prefix(4).reduce(0, +) / 4
            if restAvg - rs[0] >= 20 && late > early {
                o.append(Insight(id: 18, group: "run", score: big, mark: .down,
                                 text: String(localized: "You started fast — Run 1 was [y]\(restAvg - rs[0])s[/y] quicker than your average run."),
                                 tip: String(localized: "A steadier first km usually pays back later.")))
            }
            // 19 썰매 다음 러닝 (Sled Push → Run 3, Sled Pull → Run 4)
            let sled: Int = (rs[2] + rs[3]) / 2
            let others: [Int] = [rs[1], rs[4], rs[5], rs[6], rs[7]]
            let oAvg: Int = others.reduce(0, +) / others.count
            if sled - oAvg >= 20 {
                o.append(Insight(id: 19, group: "run", score: trend, mark: .down,
                                 text: String(localized: "Runs after the sleds were [r]\(sled - oAvg)s[/r] slower than your other runs.")))
            }
            // 2 고른가
            let spread: Int = (rs.max() ?? 0) - (rs.min() ?? 0)
            if spread <= 15 {
                o.append(Insight(id: 2, group: "run", score: info, mark: .even,
                                 text: String(localized: "Your 8 runs were within [g]\(spread)s[/g]. Very even.")))
            } else if rs[7] - rs[0] >= 45 {
                o.append(Insight(id: 2, group: "run", score: big, mark: .down,
                                 text: String(localized: "Run 8 was [r]\(sec(rs[7] - rs[0]))[/r] slower than Run 1.")))
            }
        }
        if runs.count >= 3 {
            // 20 가장 빠른 · 느린 러닝
            let paces: [Int] = runs.map { r.pace($0) }
            if let fi = paces.indices.min(by: { paces[$0] < paces[$1] }), let si = paces.indices.max(by: { paces[$0] < paces[$1] }),
               paces[si] - paces[fi] >= minDiff {
                let label: (Int) -> String = { r.isRunKind ? "km \($0 + 1)" : "Run \($0 + 1)" }
                if r.isRunKind {
                    // 22 가장 빠른 km
                    o.append(Insight(id: 22, group: "run", score: info, mark: .up,
                                     text: String(localized: "Fastest km: [y]\(label(fi))[/y] (\(Fm.t(paces[fi])))."))
                    )
                } else {
                    o.append(Insight(id: 20, group: "run", score: info, mark: .info,
                                     text: String(localized: "Fastest: [g]\(label(fi))[/g] (\(Fm.t(paces[fi]))). Slowest: [r]\(label(si))[/r] (\(Fm.t(paces[si]))).")))
                }
            }
            // 3 갈수록 빨라짐 (러닝 운동)
            if r.isRunKind, let last = paces.last, paces.dropLast().allSatisfy({ $0 > last }) {
                o.append(Insight(id: 3, group: "run2", score: trend, mark: .up,
                                 text: String(localized: "[g]Negative split[/g] — your last km was your fastest.")))
            }
        }
        // 21 목표 페이스 (레이스 · 풀 시뮬)
        if fullRace, let pace = r.runPace {
            let tg: [Int] = runs.map(\.target).filter { $0 > 0 }
            if tg.count == runs.count, !tg.isEmpty {
                let goalPace: Int = tg.reduce(0, +) / tg.count
                let d: Int = pace - goalPace
                if abs(d) >= minDiff {
                    o.append(Insight(id: 21, group: "run2", score: abs(d) >= 30 ? big : info, mark: d < 0 ? .up : .down,
                                     text: d < 0
                                        ? String(localized: "Runs averaged [y]\(Fm.t(pace))/km[/y] — [g]\(-d)s faster[/g] than goal pace.")
                                        : String(localized: "Runs averaged [y]\(Fm.t(pace))/km[/y] — [r]\(d)s slower[/r] than goal pace.")))
                }
            }
        }

        // ── 구간 (목표 · 지난번 · 최고) ───────────
        let hasTargets: Bool = r.mode != .training && r.mode != .pft && main.contains { $0.target > 0 }
        if hasTargets {
            let ds: [(SegResult, Int)] = main.filter { $0.target > 0 }.map { ($0, $0.time - $0.target) }
            if let w = ds.max(by: { $0.1 < $1.1 }), w.1 >= minDiff {
                o.append(Insight(id: 4, group: "seg", score: w.1 >= 30 ? big : info, mark: .time,
                                 text: String(localized: "Most time lost vs target: [y]\(w.0.name)[/y], [r]+\(sec(w.1))[/r].")))
            }
            let sd: [(SegResult, Int)] = ds.filter { $0.0.kind == .st }
            if let b = sd.min(by: { $0.1 < $1.1 }), let w = sd.max(by: { $0.1 < $1.1 }), b.1 <= -minDiff, w.1 >= minDiff {
                o.append(Insight(id: 23, group: "seg", score: info, mark: .info,
                                 text: String(localized: "Strongest: [g]\(b.0.name)[/g] (−\(-b.1)s). Weakest: [r]\(w.0.name)[/r] (+\(w.1)s).")))
            }
        }
        // 5 레이스: 어디까지 앞섰나
        if r.mode == .race, hasTargets {
            var cum = 0
            var aheadUntil: String? = nil
            var wasAhead = false
            for s in main where s.target > 0 {
                cum += s.time - s.target
                if cum <= 0 { wasAhead = true } else if wasAhead && aheadUntil == nil && s.kind == .st { aheadUntil = s.name }
            }
            if let a = aheadUntil, cum >= minDiff {
                o.append(Insight(id: 5, group: "goal", score: big, mark: .time,
                                 text: String(localized: "Ahead of goal until [y]\(a)[/y], then [r]+\(sec(cum))[/r] by the finish.")))
            }
        }
        // 6 지난번과 (풀 시뮬 · 레이스)
        if fullRace, let s = r.splits16,
           let last = before.filter({ $0.mode == r.mode && $0.splits16 != nil }).max(by: { $0.date < $1.date }), let l = last.splits16 {
            let names: [String] = main.map(\.name)
            let d: [Int] = (0..<16).map { s[$0] - l[$0] }
            if let gi = d.indices.min(by: { d[$0] < d[$1] }), d[gi] <= -minDiff {
                o.append(Insight(id: 6, group: "last", score: d[gi] <= -30 ? big : info, mark: .up,
                                 text: String(localized: "Biggest gain since last time: [y]\(names[gi])[/y], [g]−\(-d[gi])s[/g].")))
            } else if let wi = d.indices.max(by: { d[$0] < d[$1] }), d[wi] >= minDiff {
                o.append(Insight(id: 6, group: "last", score: d[wi] >= 30 ? big : info, mark: .down,
                                 text: String(localized: "Biggest drop since last time: [y]\(names[wi])[/y], [r]+\(d[wi])s[/r].")))
            }
        }
        // 7 구간 최고 기록 (트레이닝: 같은 무게 · 거리 / 풀 시뮬: 같은 자리 스테이션)
        if r.counts {
            var bestName: String? = nil, bestTime = 0, gain = 0
            if r.mode == .training {
                var prev: [String: Int] = [:]
                for b in before where b.mode == .training {
                    for s in b.segs where s.kind != .rox && SegKey.plausible(icon: s.icon, detail: s.detail, time: s.time) {
                        let k = SegKey.of(icon: s.icon, detail: s.detail)
                        prev[k] = min(prev[k] ?? .max, s.time)
                    }
                }
                for s in main where s.kind == .st && SegKey.plausible(icon: s.icon, detail: s.detail, time: s.time) {
                    if let p = prev[SegKey.of(icon: s.icon, detail: s.detail)], p - s.time > gain {
                        gain = p - s.time; bestName = s.name; bestTime = s.time
                    }
                }
            } else if r.mode == .sim, let s = r.splits16 {
                let prev: [[Int]] = before.filter { $0.mode == .sim }.compactMap(\.splits16)
                if !prev.isEmpty {
                    for i in stride(from: 1, to: 16, by: 2) {
                        let p: Int = prev.map { $0[i] }.min() ?? .max
                        if p - s[i] > gain && s[i] >= Record.minStation { gain = p - s[i]; bestName = main[i].name; bestTime = s[i] }
                    }
                }
            }
            if let n = bestName, gain >= 1 {
                o.append(Insight(id: 7, group: "best", score: newBest, mark: .star,
                                 text: String(localized: "New best: [y]\(n) \(Fm.t(bestTime))[/y].")))
            }
        }

        // ── 시간 비중 · 스테이션 ─────────────────
        if fullRace {
            let tot: Double = Double(max(1, r.total))
            let sp = Int((Double(r.stationTotal) / tot * 100).rounded())
            let rp = Int((Double(r.runTotal) / tot * 100).rounded())
            let xp = max(0, 100 - sp - rp)
            o.append(Insight(id: 8, group: "share", score: info, mark: .pct,
                             text: String(localized: "Stations [y]\(sp)%[/y] · Runs \(rp)% · Roxzone \(xp)%"),
                             tip: sp > rp ? String(localized: "Stations are your bigger lever.") : String(localized: "Runs are your bigger lever.")))
            if let lg = stations.max(by: { $0.time < $1.time }) {
                let pc = Int((Double(lg.time) / tot * 100).rounded())
                o.append(Insight(id: 24, group: "share", score: info, mark: .time,
                                 text: String(localized: "[y]\(lg.name)[/y] was your longest station (\(Fm.t(lg.time))) — \(pc)% of your total.")))
            }
        }
        if r.mode == .sim, let s = r.splits16 {
            let hist: [[Int]] = before.filter { $0.mode == .sim }.sorted { $0.date < $1.date }.compactMap(\.splits16)
            // 25 3번 연속 좋아짐
            if hist.count >= 3 {
                let last3: [[Int]] = Array(hist.suffix(3)) + [s]
                for i in stride(from: 1, to: 16, by: 2) {
                    let v: [Int] = last3.map { $0[i] }
                    if v[1] < v[0] && v[2] < v[1] && v[3] < v[2] {
                        o.append(Insight(id: 25, group: "streak", score: trend, mark: .up,
                                         text: String(localized: "Your [y]\(main[i].name)[/y] has improved [g]3 times in a row[/g].")))
                        break
                    }
                }
            }
            // 26 들쭉날쭉한 스테이션 (최근 5번)
            let last5: [[Int]] = Array(hist.suffix(4)) + [s]
            if last5.count >= 4 {
                var wi = -1, wv = 0
                for i in stride(from: 1, to: 16, by: 2) {
                    let v: [Int] = last5.map { $0[i] }
                    let half: Int = ((v.max() ?? 0) - (v.min() ?? 0)) / 2
                    if half > wv { wv = half; wi = i }
                }
                if wi >= 0 && wv >= 20 {
                    o.append(Insight(id: 26, group: "streak", score: info, mark: .info,
                                     text: String(localized: "[y]\(main[wi].name)[/y] varies the most between your sims (±\(wv)s)."),
                                     tip: String(localized: "Steady pacing there is easy time.")))
                }
            }
        }
        // 28 횟수 속도 (워치 기록, 참고값)
        if let rep = r.mainSegs.first(where: { $0.reps != nil && $0.time > 0 }), let n = rep.reps, n > 0 {
            if rep.icon == "wallBalls" {
                let per: Double = Double(rep.time) / Double(n)
                o.append(Insight(id: 28, group: "reps", score: info, mark: .info,
                                 text: String(localized: "[y]\(rep.name)[/y]: about one rep every \(String(format: "%.1f", per))s.")))
            } else {
                let spm = Int((Double(n) * 60 / Double(rep.time)).rounded())
                o.append(Insight(id: 28, group: "reps", score: info, mark: .info,
                                 text: String(localized: "[y]\(rep.name)[/y]: about \(spm) strokes a minute.")))
            }
        }

        // ── Roxzone ───────────────────────
        let rox: [SegResult] = r.segs.filter { $0.kind == .rox }
        if !rox.isEmpty {
            let share: Double = Double(r.roxTotal) / Double(max(1, r.total))
            if share >= 0.08 {
                o.append(Insight(id: 9, group: "rox", score: big, mark: .time,
                                 text: String(localized: "Roxzone took [r]\(Fm.t(r.roxTotal))[/r]. Faster transitions are free time.")))
            } else {
                let avg: Int = r.roxTotal / rox.count
                o.append(Insight(id: 29, group: "rox", score: info, mark: .info,
                                 text: String(localized: "Average Roxzone: [y]\(avg)s[/y]."),
                                 tip: avg > 30 ? String(localized: "Under 30s is a good target.") : nil))
            }
        } else if r.mode == .sim && r.splits16 != nil {
            o.append(Insight(id: 30, group: "rox", score: info, mark: .info,
                             text: String(localized: "Add ~4 min of Roxzone and a race would be about [y]\(Fm.t(r.total + 240))[/y].")))
        }

        // ── 심박 ─────────────────────────
        if r.hr.count > 1 {
            if let hi = CheerPicker.hiShare(r.hr, settings: st) {
                let p = Int((hi * 100).rounded())
                if p >= 40 {
                    o.append(Insight(id: 10, group: "hr", score: info, mark: .heart,
                                     text: String(localized: "[y]\(p)%[/y] of the time in Z4–Z5.")))
                }
            }
            if r.maxHR > 0 {
                let pc = Int((Double(r.maxHR) / Double(max(1, st.maxHR)) * 100).rounded())
                if pc >= 95 {
                    o.append(Insight(id: 33, group: "hr", score: trend, mark: .heart,
                                     text: String(localized: "You touched [r]\(pc)%[/r] of your max heart rate.")))
                }
            }
            // 31 후반 심박 상승 (페이스는 비슷)
            let pts: [HRPoint] = r.hr.sorted { $0.t < $1.t }
            let half: Int = r.total / 2
            let a: [Int] = pts.filter { $0.t < half }.map(\.b), b: [Int] = pts.filter { $0.t >= half }.map(\.b)
            if a.count >= 3 && b.count >= 3 && runs.count >= 4 {
                let rise: Int = b.reduce(0, +) / b.count - a.reduce(0, +) / a.count
                let ps: [Int] = runs.map { r.pace($0) }
                let h: Int = ps.count / 2
                let pd: Int = ps.suffix(ps.count - h).reduce(0, +) / max(1, ps.count - h) - ps.prefix(h).reduce(0, +) / max(1, h)
                if rise >= 10 && abs(pd) <= 10 {
                    o.append(Insight(id: 31, group: "hr", score: trend, mark: .heart,
                                     text: String(localized: "Heart rate rose [r]\(rise) bpm[/r] in the second half while your pace held.")))
                }
            }
            let withHR: [SegResult] = main.filter { ($0.hr ?? 0) > 0 }
            if let pk = withHR.max(by: { ($0.hr ?? 0) < ($1.hr ?? 0) }) {
                o.append(Insight(id: 11, group: "hr", score: info, mark: .heart,
                                 text: String(localized: "Heart rate peaked on [y]\(pk.name)[/y] (\(pk.hr ?? 0)).")))
            }
            let stHR: [SegResult] = withHR.filter { $0.kind == .st }
            if stHR.count >= 4, let lo = stHR.min(by: { ($0.hr ?? 0) < ($1.hr ?? 0) }) {
                o.append(Insight(id: 32, group: "hr", score: info - 1, mark: .heart,
                                 text: String(localized: "Your heart rate was lowest on [y]\(lo.name)[/y] (\(lo.hr ?? 0)) — room to push there.")))
            }
        }

        // ── PFT ─────────────────────────
        if r.mode == .pft, let s = r.pftSplits {
            let g: PFTGrade = PFT.grade(r.total)
            if g != .gold {
                let gap: Int = r.total - (PFT.goldLimit - 1)
                let each: Int = Int((Double(gap) / Double(PFT.items.count)).rounded(.up))
                o.append(Insight(id: 12, group: "pft", score: gap <= 30 ? big : trend, mark: .star,
                                 text: String(localized: "[y]\(sec(gap))[/y] from Gold."),
                                 tip: String(localized: "About \(each) seconds faster on each movement gets you there.")))
            } else if PFT.goldLimit - r.total >= 30 {
                o.append(Insight(id: 39, group: "pft", score: big, mark: .star,
                                 text: String(localized: "Gold with [g]\(sec(PFT.goldLimit - r.total))[/g] to spare.")))
            }
            let d: [Int] = s.indices.map { s[$0] - PFT.items[$0].target }
            if let wi = d.indices.max(by: { d[$0] < d[$1] }), d[wi] >= minDiff {
                o.append(Insight(id: 13, group: "pft2", score: info, mark: .down,
                                 text: String(localized: "Most room: [y]\(PFT.items[wi].name)[/y], [r]+\(d[wi])s[/r] on Gold pace.")))
            }
            if let bi = d.indices.min(by: { d[$0] < d[$1] }), d[bi] <= -minDiff {
                o.append(Insight(id: 14, group: "pft3", score: info, mark: .up,
                                 text: String(localized: "Strongest: [y]\(PFT.items[bi].name)[/y], [g]\(-d[bi])s under[/g] Gold pace.")))
            }
            if let last = before.filter({ $0.mode == .pft }).max(by: { $0.date < $1.date }), let l = last.pftSplits {
                let dd: [Int] = s.indices.map { s[$0] - l[$0] }
                if let gi = dd.indices.min(by: { dd[$0] < dd[$1] }), dd[gi] <= -minDiff {
                    o.append(Insight(id: 38, group: "last", score: dd[gi] <= -30 ? big : info, mark: .up,
                                     text: String(localized: "Biggest gain since last PFT: [y]\(PFT.items[gi].name)[/y], [g]−\(-dd[gi])s[/g].")))
                }
            }
        }

        // ── 트레이닝 ──────────────────────
        if r.mode == .training && !r.isHIIT && !r.isRunKind {
            let sets: Int = max(1, r.sets)
            if sets >= 2 && main.count % sets == 0 {
                let per: Int = main.count / sets
                let tots: [Int] = (0..<sets).map { k in main[(k * per)..<((k + 1) * per)].map(\.time).reduce(0, +) }
                let joined: String = tots.map { Fm.t($0) }.joined(separator: " · ")
                if let last = tots.last, let first = tots.first, last - first >= 60 {
                    o.append(Insight(id: 15, group: "sets", score: big, mark: .down,
                                     text: String(localized: "Set \(sets) was [r]\(sec(last - first))[/r] slower than set 1.")))
                } else if (tots.max() ?? 0) - (tots.min() ?? 0) <= 30 {
                    o.append(Insight(id: 15, group: "sets", score: info, mark: .even,
                                     text: String(localized: "\(sets) sets, very even: [y]\(joined)[/y]")))
                }
                // 27 세트마다 느려진 종목
                if sets >= 3 {
                    for j in 0..<per where main[j].kind == .st {
                        let v: [Int] = (0..<sets).map { main[$0 * per + j].time }
                        if zip(v, v.dropFirst()).allSatisfy({ $1 > $0 }) && (v.last ?? 0) - (v.first ?? 0) >= minDiff {
                            o.append(Insight(id: 27, group: "streak", score: trend, mark: .down,
                                             text: String(localized: "[y]\(main[j].name)[/y] got slower each set: [r]\(v.map { Fm.t($0) }.joined(separator: " → "))[/r].")))
                            break
                        }
                    }
                }
            }
            if let last = before.filter({ $0.mode == .training && $0.title == r.title && $0.sets == r.sets }).max(by: { $0.date < $1.date }) {
                let d: Int = r.total - last.total
                if abs(d) >= minDiff {
                    o.append(Insight(id: 16, group: "last", score: abs(d) >= 30 ? big : info, mark: d < 0 ? .up : .down,
                                     text: d < 0
                                        ? String(localized: "[g]\(sec(d)) faster[/g] than last time on this training.")
                                        : String(localized: "[r]\(sec(d)) slower[/r] than last time on this training.")))
                }
            }
        }

        // ── 목표 · 흐름 ────────────────────
        if fullRace && r.counts {
            let goal: Int = r.mode == .race ? (r.goal ?? st.goalTime) : st.goalTime
            let d: Int = r.total - goal
            if d >= minDiff && goal > 0 {
                let each: Int = Int((Double(d) / 16).rounded(.up))
                o.append(Insight(id: 34, group: "goal", score: info, mark: .time,
                                 text: String(localized: "To hit [y]\(Fm.t(goal))[/y]: about \(each)s faster on each split.")))
            }
        }
        if r.counts && r.mode != .training {
            let same: [Record] = before.filter { $0.mode == r.mode && (r.mode != .sim || $0.splits16 != nil) }.sorted { $0.date < $1.date }
            let last3: [Int] = same.suffix(2).map(\.total) + [r.total]
            if last3.count == 3 && last3[1] < last3[0] && last3[2] < last3[1] {
                let word: String = r.mode == .sim ? String(localized: "sims") : r.mode == .race ? String(localized: "races") : "PFTs"
                o.append(Insight(id: 35, group: "trend", score: trend, mark: .up,
                                 text: String(localized: "Your last 3 \(word): \(last3.map { Fm.t($0) }.joined(separator: " → ")). [g]Trending down.[/g]")))
            }
            if let best = same.map(\.total).min(), r.total - best >= minDiff {
                o.append(Insight(id: 36, group: "trend", score: info, mark: .info,
                                 text: String(localized: "[y]\(sec(r.total - best))[/y] off your best.")))
            }
        }
        if r.mode == .sim && st.event.isSet {
            let cal = Calendar.current
            let days: Int = cal.dateComponents([.day], from: cal.startOfDay(for: r.date), to: cal.startOfDay(for: st.event.date)).day ?? -1
            if (1...30).contains(days) {
                let month: Int = (before + [r]).filter { $0.mode == .sim && cal.isDate($0.date, equalTo: r.date, toGranularity: .month) }.count
                o.append(Insight(id: 37, group: "race", score: info, mark: .time,
                                 text: String(localized: "[y]\(days) days[/y] to race. Your full sim #\(month) this month.")))
            }
        }

        // ── 친구 · 파트너 · 시간대 ──────────────
        if r.mode == .sim, let s = r.splits16, let f = store.friend, f.hasSplits {
            let won: Int = stride(from: 1, to: 16, by: 2).filter { s[$0] < f.splits[$0] }.count
            let behind: Int = r.total - f.total
            if behind >= minDiff {
                let gaps: [Int] = (0..<16).map { s[$0] - f.splits[$0] }
                if let wi = gaps.indices.max(by: { gaps[$0] < gaps[$1] }), gaps[wi] >= minDiff {
                    o.append(Insight(id: 40, group: "friend", score: trend, mark: .info,
                                     text: String(localized: "You're [r]\(sec(behind))[/r] behind @\(f.name) — most of it on [y]\(main[wi].name)[/y] (\(gaps[wi])s).")))
                }
            } else {
                o.append(Insight(id: 17, group: "friend", score: info, mark: .up,
                                 text: String(localized: "You beat @\(f.name) on [g]\(won) of 8[/g] stations.")))
            }
        }
        if let p = r.partner, !p.isEmpty {
            let n: Int = (before + [r]).filter { $0.partner == p }.count
            if n >= 2 {
                o.append(Insight(id: 41, group: "friend", score: info - 1, mark: .info,
                                 text: String(localized: "With @\(p): your session #\(n) together.")))
            }
        }
        if r.mode == .sim || r.mode == .pft {
            let all: [Record] = (before + [r]).filter { $0.mode == r.mode }
            let cal = Calendar.current
            let am: [Int] = all.filter { cal.component(.hour, from: $0.date) < 12 }.map(\.total)
            let pm: [Int] = all.filter { cal.component(.hour, from: $0.date) >= 12 }.map(\.total)
            if am.count >= 3 && pm.count >= 3 {
                let d: Int = am.reduce(0, +) / am.count - pm.reduce(0, +) / pm.count
                if abs(d) >= minDiff {
                    o.append(Insight(id: 42, group: "time", score: info - 2, mark: .time,
                                     text: d < 0
                                        ? String(localized: "You're faster in the morning — [g]−\(sec(d))[/g] on average.")
                                        : String(localized: "You're faster in the afternoon — [g]−\(sec(d))[/g] on average.")))
                }
            }
        }
        return o
    }

    // MARK: 글자 꾸미기 ([y] [r] [g])

    static func styled(_ s: String) -> AttributedString {
        var out = AttributedString()
        var rest = Substring(s)
        let tags: [(String, Color)] = [("y", C.accent), ("r", C.bad), ("g", C.good)]
        while !rest.isEmpty {
            // 가장 먼저 나오는 여는 표시
            var first: (range: Range<Substring.Index>, tag: String, color: Color)? = nil
            for (t, c) in tags {
                if let rg = rest.range(of: "[\(t)]"), first == nil || rg.lowerBound < first!.range.lowerBound {
                    first = (rg, t, c)
                }
            }
            guard let f = first, let close = rest[f.range.upperBound...].range(of: "[/\(f.tag)]") else {
                out += AttributedString(String(rest))
                break
            }
            out += AttributedString(String(rest[..<f.range.lowerBound]))
            var mid = AttributedString(String(rest[f.range.upperBound..<close.lowerBound]))
            mid.foregroundColor = f.color
            out += mid
            rest = rest[close.upperBound...]
        }
        return out
    }
}

// MARK: - 카드 (기록 상세 · 숫자 타일 바로 아래)

struct InsightsCard: View {
    let items: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Insights").font(F.t(F.sub, .semibold))
                Text("From this record").font(F.t(F.foot)).foregroundStyle(C.text3)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)
            ForEach(Array(items.enumerated()), id: \.element.id) { i, x in
                HStack(alignment: .top, spacing: 12) {
                    badge(x.mark)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Insights.styled(x.text)).font(F.t(15)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let t = x.tip {
                            Text(t).font(F.t(13)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 40) }
                }
                .accessibilityIdentifier("insight.\(x.id)")
            }
        }
        .padding(.top, 16).padding(.bottom, 6).padding(.horizontal, 18)
        .card8()
    }

    /// 28 정사각 기호 칸: ↓ 빨강 · ↑ 초록 · 그 밖 노랑
    private func badge(_ m: Insight.Mark) -> some View {
        let sym: String
        let color: Color
        switch m {
        case .down: sym = "arrow.down"; color = C.bad
        case .up: sym = "arrow.up"; color = C.good
        case .star: sym = "star.fill"; color = C.accent
        case .time: sym = "stopwatch"; color = C.accent
        case .pct: sym = "percent"; color = C.accent
        case .heart: sym = "heart.fill"; color = C.hr
        case .even: sym = "equal"; color = C.accent
        case .info: sym = "sparkles"; color = C.accent
        }
        return Image(systemName: sym).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
