import Foundation

// MARK: - 52번 · 워치 운동을 아이폰에 실시간으로 (HealthKit 운동 미러링으로 주고받는 내용)
//
// 워치 → 아이폰: LiveState (구간이 바뀔 때마다 + 5초마다 심박 · 칼로리)
// 아이폰 → 워치: LiveCommand (Next · Undo · Pause · Resume · End)
// 기록의 기준은 워치. 아이폰은 받은 상태를 그대로 보여 주기만 함.

struct LiveState: Codable, Equatable {
    var mode: Mode
    var title: String
    var seq: [Seg]
    var idx: Int
    var splits: [Int]
    /// 보낸 순간의 지금 구간 시간(초). 아이폰은 받은 시각부터 이어서 셈 (두 기기 시계가 달라도 맞게)
    var segElapsed: Int
    var running: Bool
    var hr: Int
    var kcal: Int
    var zone: Int
    var canUndo: Bool
    var finished: Bool
    var vsWord: String
    /// 목표 대비 (보낸 순간). 목표가 없으면 nil
    var delta: Int?
    /// HIIT · 자유 러닝처럼 끝없이 늘어나는 운동
    var open: Bool = false
    /// 실내/실외 러닝 1km 자동 넘김 (Next 버튼 대신 "Auto split")
    var autoSplit: Bool = false
    /// 64번: 지금 구간에서 달린 거리(m) · 운동 전체 거리(m). 아이폰 화면의 페이스 계산용 (예전 워치 앱은 안 보냄 → nil)
    var segDist: Double? = nil
    var dist: Double? = nil
    /// 빌드 27: 지금 속도(m/s, 실시간 페이스용). 0 · nil = 아직 모름 (예전 워치 앱은 안 보냄 → nil)
    var spd: Double? = nil

    var cur: Seg? { seq.indices.contains(idx) ? seq[idx] : seq.last }
    var nextSeg: Seg? { seq.indices.contains(idx + 1) ? seq[idx + 1] : nil }
    var doneT: Int { splits.prefix(idx).reduce(0, +) }

    /// received = 아이폰이 받은 시각
    func segEl(_ now: Date, received: Date) -> Int {
        running ? segElapsed + max(0, Int(now.timeIntervalSince(received))) : segElapsed
    }
    func total(_ now: Date, received: Date) -> Int { doneT + segEl(now, received: received) }
}

enum LiveCommand: String, Codable {
    case next, undo, pause, resume, end
}

struct LivePacket: Codable {
    var state: LiveState? = nil
    var command: LiveCommand? = nil

    func data() -> Data? { try? JSONEncoder().encode(self) }
    static func read(_ d: Data) -> LivePacket? { try? JSONDecoder().decode(LivePacket.self, from: d) }
}

extension Settings {
    /// 설정 › Device › Show on iPhone (워치 운동을 아이폰에 같이 보여 주기). 기본 켬
    var mirror: Bool {
        get { mirrorOpt ?? true }
        set { mirrorOpt = newValue ? nil : false }
    }
}

/// 64번: "5:12" 처럼 1 km 페이스 글자
/// 빌드 27: 실시간 페이스 (애플 운동 앱 · 나이키처럼 지금 속도로 계산)
///  1) 지금 속도가 0.5 m/s 넘으면 → 그 속도로 페이스
///  2) 아니면 구간 거리가 50 m 미만 → "Measuring" (측정 중)
///  3) 아니면 → 이 구간 평균 페이스 (예전 방식)
///  거리를 아예 못 재면(nil) "–:––"
enum LivePace {
    enum Reading: Equatable {
        case pace(Int)        // 초 (1 km 또는 1 mi 당)
        case measuring
        case unknown
    }

    static func reading(el: Int, dist: Double?, imperial: Bool = false, speed: Double? = nil) -> Reading {
        let unitM: Double = imperial ? Units.mPerMile : 1000
        if let sp = speed, sp > 0.5 {
            let p: Double = unitM / sp
            if p < 3600 { return .pace(Int(p.rounded())) }
        }
        guard let d = dist else { return .unknown }
        if d < 50 { return .measuring }
        guard el > 0 else { return .unknown }
        let p: Int = Int((Double(el) / (d / unitM)).rounded())
        guard p < 3600 else { return .unknown }
        return .pace(p)
    }

    /// 초 → "5:12"
    static func fmt(_ p: Int) -> String {
        "\(p / 60):" + String(format: "%02d", p % 60)
    }

    /// imperial = true 면 1 mi 당 페이스 (빌드 27 단위 설정) · speed = 지금 속도(m/s)
    static func text(el: Int, dist: Double?, imperial: Bool = false, speed: Double? = nil) -> String {
        switch reading(el: el, dist: dist, imperial: imperial, speed: speed) {
        case .pace(let p): return fmt(p)
        case .measuring: return String(localized: "Measuring")
        case .unknown: return "–:––"
        }
    }
}

// MARK: - 빌드 24: 운동 중 "n / 16" 세는 법 하나로 (워치 · 아이폰 직접 기록 · 같이 보기 · 잠금 화면)
// Roxzone 은 세지 않음. Roxzone 동안은 앞 구간 번호 그대로, 막대만 반 칸 더 참.

extension Array where Element == Seg {
    /// Roxzone 을 뺀 전체 구간 수
    var liveCountTotal: Int { filter { $0.kind != .rox }.count }

    /// idx 번째 구간이 Roxzone 을 뺀 몇 번째인지 (Roxzone 이면 바로 앞 구간 번호)
    func liveCountNow(_ idx: Int) -> Int {
        Swift.max(1, prefix(idx + 1).filter { $0.kind != .rox }.count)
    }

    /// 막대 자리 0~1
    func liveProgress(_ idx: Int) -> Double {
        let n: Int = liveCountTotal
        guard n > 1 else { return 0 }
        let isRox: Bool = indices.contains(idx) && self[idx].kind == .rox
        let pos: Double = Double(liveCountNow(idx) - 1) + (isRox ? 0.5 : 0)
        return Swift.min(1, Swift.max(0, pos / Double(n - 1)))
    }
}
