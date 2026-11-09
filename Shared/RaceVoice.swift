import Foundation

// MARK: - 1.2.2 · 레이스 · 풀 시뮬 코치 음성 규칙 (코치 음성 v8)
// 무엇을 언제 말할지만 정함 (재생은 VoiceCoach). 안드로이드 shared Voice.kt 의 RaceVoice 와 같은 규칙.
//
// 하이록스 순서: 러닝1 → 스키 → 러닝2 → 슬레드 푸쉬 → … → 러닝8 → 월볼 (n = 1~8)
//  러닝 n 시작 → rr_n / 러닝 끝 · 록스존 IN → ri_n / 스테이션 n 시작 → rs_n (+ 응원 보통 · 많이면 tip_n)
//  스테이션 끝 · 록스존 OUT → ro_n (n = 1~7) / 결승 → rf_1
//  응원: 적게 = 구간당 1번 · 전환 뒤 30초, 보통 = 2번 · 15초, 많이 = 3번 · 10초. 구간 끝 예상 10초 전까지만.
//  거의 끝 (목표 85 %): 러닝 1 · 2 = near_run / near_run_rox, 월볼 = near_st / near_st2
//  흐름 응원 (보통 · 많이): 러닝2 ph_q1 · 러닝6 ph_q3 · 러닝7 ph_two · 러닝8 ph_lastrun · 월볼 ph_wb (그 구간 첫 응원 자리)
//  초반 과속 (러닝 1 · 2, 목표 60 % 지점, 잰 거리가 목표보다 10 % 넘게 앞서면, 레이스당 1번) → pace_fast_1 / 2
//  목표 비교 (구간 끝, 누적): 3초 안 = goal_on, 아니면 goal_pre + 시간 + goal_fast / goal_slow

enum RaceVoice {
    /// 스테이션 아이콘 → 응원 조각 이름 (cs_<종목>_*)
    static let stKey: [String: String] = ["skiErg": "ski", "sledPush": "push", "sledPull": "pull", "burpeeBroadJump": "bbj",
                                          "row": "row", "farmersCarry": "farm", "sandbagLunges": "lunge", "wallBalls": "wb"]
    /// 종목별 응원 수 (clips.json 과 같음)
    static let stCount: [String: Int] = ["ski": 2, "push": 3, "pull": 3, "bbj": 2, "row": 2, "farm": 2, "lunge": 2, "wb": 3]

    /// 하이록스 순서 그대로인지 (러닝 8 · 스테이션 8 이 번갈아, 스테이션은 Station.all 순서, 록스존은 있어도 없어도 됨)
    static func isRace(_ seq: [Seg]) -> Bool {
        let main: [Seg] = seq.filter { $0.kind != .rox }
        guard main.count == 16 else { return false }
        for (i, s) in main.enumerated() {
            if i % 2 == 0 {
                if s.kind != .run { return false }
            } else if s.kind != .st || s.icon != Station.all[i / 2].key {
                return false
            }
        }
        return true
    }

    /// 이 구간까지 러닝 몇 번째 · 스테이션 몇 번째
    static func runNo(_ seq: [Seg], _ i: Int) -> Int { seq.prefix(i + 1).filter { $0.kind == .run }.count }
    static func stNo(_ seq: [Seg], _ i: Int) -> Int { seq.prefix(i + 1).filter { $0.kind == .st }.count }

    /// 구간 i 를 시작할 때 말할 통문장
    static func transition(_ seq: [Seg], _ i: Int, level: String) -> [String] {
        guard seq.indices.contains(i) else { return [] }
        let s: Seg = seq[i]
        switch s.kind {
        case .run:
            return ["rr_\(min(8, max(1, runNo(seq, i))))"]
        case .st:
            let n: Int = min(8, max(1, stNo(seq, i)))
            return level == "low" ? ["rs_\(n)"] : ["rs_\(n)", "tip_\(n)"]
        case .rox:
            guard i > 0 else { return [] }
            let prev: Seg = seq[i - 1]
            if prev.kind == .run { return ["ri_\(min(8, max(1, runNo(seq, i))))"] }
            if prev.kind == .st {
                let n: Int = stNo(seq, i)
                return (1...7).contains(n) ? ["ro_\(n)"] : []
            }
            return []
        }
    }

    /// 구간 i 에 막 들어왔을 때, 앞에서 끝난 러닝 · 스테이션까지 누적으로 목표와 비교.
    /// 적게 = 스테이션이 끝났을 때만, 보통 · 많이 = 러닝 · 스테이션 끝날 때마다. 건너뛴 구간(0초) · 목표 없는 구간이 있으면 안 함
    static func goalLine(_ seq: [Seg], _ i: Int, splits: [Int], level: String) -> [String] {
        guard i > 0, seq.indices.contains(i), splits.count >= i else { return [] }
        let prev: Seg = seq[i - 1]
        guard prev.kind != .rox else { return [] }
        if level == "low" && prev.kind != .st { return [] }
        var mine: Int = 0, goal: Int = 0
        for k in 0..<i {
            guard seq[k].target > 0, splits[k] > 0 else { return [] }
            mine += splits[k]; goal += seq[k].target
        }
        return compare(mine - goal)
    }

    /// 차이(초, + = 늦음) → 조각. 3초 안 = goal_on, 1시간 넘으면 숫자 없이
    static func compare(_ diff: Int) -> [String] {
        let a: Int = abs(diff)
        if a <= 3 { return ["goal_on"] }
        if a >= 3600 { return [diff < 0 ? "goal_ahead" : "goal_behind"] }
        return ["goal_pre"] + VoiceCoach.dur(a) + [diff < 0 ? "goal_fast" : "goal_slow"]
    }

    /// 이 구간 예상 시간(초): 목표, 없으면 기본 목표
    static func expected(_ s: Seg) -> Int {
        if s.target > 0 { return s.target }
        if s.kind == .run { return 270 }
        if s.kind == .rox { return Defaults.roxTarget }
        return Station.all.first { $0.key == s.icon }?.target ?? 240
    }

    /// 전환 안내 뒤 응원까지 조용히 있을 시간(초)
    static func quiet(_ level: String) -> Double { level == "high" ? 10 : (level == "mid" ? 15 : 30) }
    /// 구간당 응원 수
    static func perSeg(_ level: String) -> Int { level == "high" ? 3 : (level == "mid" ? 2 : 1) }

    /// 응원을 말해도 되는 마지막 때(초): 구간 끝 예상 10초 전, 거의 끝을 말하는 구간이면 그 5초 전까지
    static func cheerEnd(_ seq: [Seg], _ i: Int) -> Int {
        let T: Int = expected(seq[i])
        var e: Int = T - 10
        if !nearOptions(seq, i).isEmpty { e = min(e, Int(Double(T) * 0.85) - 5) }
        return e
    }

    /// 응원할 때들 (구간 시작부터 초). 창 = [전환 뒤 quiet, cheerEnd], 칸을 고르게 나누고 ±10 % 흔들기. 창이 너무 짧으면 줄임
    static func cheerTimes(_ seq: [Seg], _ i: Int, level: String, jitter: () -> Double) -> [Int] {
        guard seq.indices.contains(i), seq[i].kind != .rox else { return [] }
        // 전환 문장을 말하는 시간(약 6초) + 조용히 있을 시간
        let start: Double = 6 + quiet(level)
        let end: Double = Double(cheerEnd(seq, i))
        let len: Double = end - start
        guard len >= 0 else { return [] }
        // 응원 사이도 quiet 만큼은 띄움
        let fit: Int = Int(len / max(quiet(level), 8)) + 1
        let n: Int = min(perSeg(level), fit)
        return (0..<n).map { k in
            let t: Double = start + len * (Double(k) + 0.5) / Double(n) + len / Double(n) * jitter()
            return Int(max(start, min(end, t)))
        }
    }

    /// 응원 후보. nth = 이 구간에서 몇 번째 응원 (0부터). 보통 · 많이면 정해진 구간의 첫 응원은 흐름 문장(ph_*)
    static func cheerOptions(_ seq: [Seg], _ i: Int, nth: Int, level: String) -> [String] {
        let s: Seg = seq[i]
        if nth == 0 && level != "low", let ph = phase(seq, i) { return [ph] }
        let general: [String] = (1...VoiceCoach.cheerCount).map { String(format: "cheer_%02d", $0) }
        if s.kind == .run { return general + (1...6).map { String(format: "cr_%02d", $0) } }
        guard let k = stKey[s.icon], let c = stCount[k] else { return general }
        return general + (1...c).map { "cs_\(k)_\($0)" }
    }

    /// 흐름 응원: 러닝2 ph_q1 · 러닝6 ph_q3 · 러닝7 ph_two · 러닝8 ph_lastrun · 월볼 ph_wb
    static func phase(_ seq: [Seg], _ i: Int) -> String? {
        let s: Seg = seq[i]
        if s.kind == .run {
            switch runNo(seq, i) {
            case 2: return "ph_q1"
            case 6: return "ph_q3"
            case 7: return "ph_two"
            case 8: return "ph_lastrun"
            default: return nil
            }
        }
        if s.kind == .st && s.icon == "wallBalls" { return "ph_wb" }
        return nil
    }

    /// 거의 끝 후보: 러닝 1 · 2 (다음이 록스존이면 "이제 록스존으로" 도), 마지막 월볼
    static func nearOptions(_ seq: [Seg], _ i: Int) -> [String] {
        let s: Seg = seq[i]
        if s.kind == .run && runNo(seq, i) <= 2 {
            let roxNext: Bool = i + 1 < seq.count && seq[i + 1].kind == .rox
            return roxNext ? ["near_run", "near_run_rox"] : ["near_run"]
        }
        if s.kind == .st && s.icon == "wallBalls" { return ["near_st", "near_st2"] }
        return []
    }

    /// 초반 과속을 볼 구간 (러닝 1 · 2)
    static func paceCheckSeg(_ seq: [Seg], _ i: Int) -> Bool {
        seq[i].kind == .run && runNo(seq, i) <= 2
    }

    /// 목표 시간의 60 % 지점에서, 잰 거리가 그때 있어야 할 거리보다 10 % 넘게 앞서는지 (거리를 모르면 false)
    static func tooFast(_ s: Seg, segEl: Int, segDist: Double?) -> Bool {
        guard let d = segDist, d > 0, segEl > 0 else { return false }
        let T: Double = Double(expected(s))
        let should: Double = runMeters(s.detail) * min(1, Double(segEl) / T)
        return d > should * 1.1
    }
}
