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
