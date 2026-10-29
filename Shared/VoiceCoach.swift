import Foundation
import AVFoundation

// MARK: - 19번: 운동 중 음성 안내 (아나운서 목소리 조각 이어 붙이기)
// 소리 조각: Resources/Voice/ko/<id>.m4a (앱 묶음 안 "Voice/ko" 폴더 — project.yml 에서 폴더째 넣음)
// 워치로 운동하면 워치(WorkoutEngine)가, 아이폰만으로 운동하면 아이폰(PhoneRunEngine)이 말함.
// 아이폰이 워치 운동을 같이 보여 주기만 할 때(Mirror)는 말하지 않음 (소리 두 번 안 나게).
// 모두 메인 스레드에서 부름.

final class VoiceCoach: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceCoach()

    /// 우선순위: 구간 바뀜 · 시작/멈춤/끝 > 러닝 거리 안내 > 응원
    enum Pri: Int {
        case cheer = 0, info = 1, segment = 2
    }

    private struct Line {
        let ids: [String]
        let pri: Pri
    }

    /// 앱 묶음 안 폴더 (project.yml: Resources/Voice 를 폴더째 → "Voice/ko/…")
    static let folder = "Voice/ko"
    /// 한 문장 안 조각 사이
    static let clipGap: Double = 0.12
    /// 문장과 문장 사이
    static let lineGap: Double = 0.35
    /// 응원은 바로 앞 안내 뒤 이 시간(초) 안에는 안 함
    static let cheerQuiet: Double = 15
    static let cheerCount = 15

    /// 이번 운동에서 말할지 (설정 켜짐 + 한국어)
    private(set) var enabled = false

    private var pending: [Line] = []
    /// 지금 문장에서 아직 안 나온 조각
    private var playingIds: [String] = []
    /// 지금 말하는 문장의 우선순위 (nil = 조용함)
    private var playingPri: Pri? = nil
    private var player: AVAudioPlayer?
    private var stepWork: DispatchWorkItem?
    private var offWork: DispatchWorkItem?
    private var sessionOn = false
    /// 마지막으로 문장을 시작하거나 끝낸 때 (응원 15초 규칙)
    private var lastLineAt: Date = .distantPast
    private var lastCheer: Int = 0

    // 운동 하나 동안의 상태
    private var runCard = false
    private var open = false
    private var every: Double = 1000
    private var sayDist = true
    private var sayTime = true
    private var sayPace = true
    private var sayHr = true
    /// 다음에 말할 러닝 거리(m). 0 = 아직 안 정함 (처음 거리값을 받을 때 정함 — 이어 받기에도 맞음)
    private var nextMark: Double = 0
    private var halfSaid = false
    private var cheerPlanIdx = -1
    private var cheerAt: Int? = nil
    private var cheeredIdx = -1
    /// 18번: 새 종류 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성). nil = 예전 종류
    private var kind: String? = nil
    /// "10초 남았어요" 를 이미 말한 구간
    private var warnedIdx = -1
    /// AMRAP 남은 시간 안내를 이미 한 것 (60 · 30 · 10)
    private var capSaid: Set<Int> = []

    // MARK: 운동 안내 (엔진이 부름)

    /// 운동 시작. announce = false 면 말없이 상태만 (아이폰 운동 이어 받기)
    func begin(_ s: Settings, seq: [Seg], runCard: Bool, open: Bool, announce: Bool = true, kind: String? = nil) {
        cutAll()
        enabled = s.voiceActive
        self.kind = WKind.isNew(kind) ? kind : nil
        warnedIdx = -1
        capSaid = []
        self.runCard = runCard
        self.open = open
        every = Double(s.voiceEvery)
        sayDist = s.voiceDist
        sayTime = s.voiceTime
        sayPace = s.voicePace
        sayHr = s.voiceHr
        nextMark = 0
        halfSaid = false
        cheerPlanIdx = -1; cheerAt = nil; cheeredIdx = -1
        guard enabled, announce else { return }
        if let k = self.kind {
            // 타이머 운동은 3 · 2 · 1 다음 "시작!", 나머지는 "운동을 시작합니다" + 첫 단계
            var ids: [String] = WKind.isTimer(k) ? ["cd_go"] : ["go_start"]
            ids += phaseClips(seq, 0, k)
            say(ids, .segment, interrupt: true)
            return
        }
        var ids: [String] = ["go_start"]
        if !runCard, seq.count > 1 { ids += segClips(seq, 0) }
        say(ids, .segment)
    }

    /// 다음 구간으로 넘어감 (러닝 카드는 거리 안내로 대신하므로 부르지 않음)
    func segment(_ seq: [Seg], idx: Int) {
        guard enabled, !runCard, seq.indices.contains(idx) else { return }
        var ids: [String] = segClips(seq, idx)
        // 반 지났을 때 (Roxzone 뺀 구간 수 기준, 후반 첫 구간에서 한 번)
        let s: Seg = seq[idx]
        let total: Int = seq.filter { $0.kind != .rox }.count
        if !open, !halfSaid, s.kind != .rox, total >= 4 {
            let n: Int = seq.prefix(idx + 1).filter { $0.kind != .rox }.count
            if n == total / 2 + 1 {
                halfSaid = true
                if !ids.contains("sim_wb") && !ids.contains("sim_last") { ids.append("t_half") }
            }
        }
        say(ids, .segment)
    }

    // MARK: 18번 · 새 종류 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성)

    /// 시작 전 3 · 2 · 1 (타이머 운동). begin 전에 불리므로 설정을 여기서 읽음
    func count(_ s: Settings, _ n: Int) {
        enabled = s.voiceActive
        guard enabled, (1...3).contains(n) else { return }
        say(["cd_\(n)"], .segment, interrupt: true)
    }

    /// 다음 단계로 넘어감 (새 종류). idx = 새로 시작한 구간
    func phase(_ seq: [Seg], idx: Int) {
        guard enabled, let k = kind, seq.indices.contains(idx) else { return }
        var ids: [String] = []
        // 기능성: 휴식이 끝나고 다음 세트
        if k == WKind.strength, idx > 0, seq[idx - 1].tag == "rest", seq[idx].tag == "set" { ids.append("tabata_set") }
        ids += phaseClips(seq, idx, k)
        say(ids, .segment)
    }

    /// 단계 시작 때 말할 조각
    private func phaseClips(_ seq: [Seg], _ i: Int, _ k: String) -> [String] {
        guard seq.indices.contains(i) else { return [] }
        let s: Seg = seq[i]
        switch k {
        case WKind.tabata:
            if s.tag == "rest" { return ["iv_rest"] }
            let lastWork: Bool = !seq[(i + 1)...].contains { $0.tag == "work" }
            let works: Int = seq.filter { $0.tag == "work" }.count
            return lastWork && works > 1 ? ["iv_last_set", "iv_work"] : ["iv_work"]
        case WKind.emom:
            guard i > 0 else { return [] }
            return i == seq.count - 1 && seq.count > 2 ? ["emom_next", "iv_last_set"] : ["emom_next"]
        case WKind.interval:
            var o: [String] = []
            // 마지막 반복의 첫 단계
            let maxNo: Int = seq.compactMap(\.no).max() ?? 0
            if let n = s.no, n == maxNo, maxNo > 1, i > 0, seq[i - 1].no != n { o.append("iv_last_set") }
            if let m = s.autoM, let d = VoiceCoach.dist(Double(m)) { o.append(d) } else if let t = s.auto { o += VoiceCoach.dur(t) }
            switch s.tag ?? "" {
            case "fast": o.append("iv_fast")
            case "easy": o.append("iv_easy")
            default: o.append("iv_rest")
            }
            return o
        case WKind.strength:
            return s.tag == "rest" ? ["iv_rest"] : []
        default:
            return []
        }
    }

    /// 1초마다 (새 종류): 단계 끝 10초 전 (30초 이상 단계) · AMRAP 남은 1분 · 30초 · 10초
    func timerTick(seq: [Seg], idx: Int, segEl: Int, total: Int, cap: Int?) {
        guard enabled, let k = kind, seq.indices.contains(idx) else { return }
        if k == WKind.amrap, let c = cap, c > 0 {
            let left: Int = c - total
            for mark in [60, 30, 10] where left <= mark && left > mark - 3 && c > mark && !capSaid.contains(mark) {
                capSaid.insert(mark)
                say([mark == 60 ? "t_1m" : (mark == 30 ? "t_30s" : "t_10s")], .info)
            }
            return
        }
        guard let a = seq[idx].auto, a >= 30, warnedIdx != idx else { return }
        let left: Int = a - segEl
        if left <= 10 && left > 3 {
            warnedIdx = idx
            say(["t_10s"], .info)
        }
    }

    /// 운동 끝: AMRAP 이 시간이 다 돼 끝나면 "시간 끝! 몇 라운드 하셨는지 적어 주세요."
    func endedKind(_ k: String?, timeUp: Bool) {
        guard enabled else { return }
        say([k == WKind.amrap && timeUp ? "amrap_end" : "go_end"], .segment, interrupt: true)
    }

    func paused() { if enabled { say(["go_pause"], .segment, interrupt: true) } }
    func resumed() { if enabled { say(["go_resume"], .segment, interrupt: true) } }
    /// 운동 끝 (저장). 말하는 중인 것은 끊고 "운동 끝"
    func ended() { if enabled { say(["go_end"], .segment, interrupt: true) } }
    /// 버리기 · 화면 닫힘: 조용히 멈춤
    func stop() {
        cutAll()
        scheduleOff()
    }

    /// 1초마다 (러닝 카드가 아닐 때): 스테이션 구간 중간쯤 응원 한 번
    func tick(seq: [Seg], idx: Int, segEl: Int) {
        guard enabled, !runCard, seq.indices.contains(idx) else { return }
        let s: Seg = seq[idx]
        guard s.kind == .st, cheeredIdx != idx else { return }
        if cheerPlanIdx != idx {
            cheerPlanIdx = idx
            let expect: Int = s.target > 0 ? s.target : (Station.of(s.icon)?.target ?? 0)
            cheerAt = expect > 60 ? Int(Double(expect) * Double.random(in: 0.4...0.6)) : nil
        }
        guard let at = cheerAt, segEl >= at else { return }
        if cheer() { cheeredIdx = idx }
    }

    /// 러닝 카드: 지금까지 거리(m) · 시간(초) · 평균 심박. 알림 간격을 넘으면 한 번 말함
    func runMark(meters: Double, totalSec: Int, avgHR: Int?) {
        guard enabled, runCard, every > 0, meters > 0 else { return }
        if nextMark <= 0 {
            // 처음 받은 값: 손으로 넘긴 1 km (딱 떨어짐)는 바로 말하고,
            // GPS · 워치 거리는 다음 간격부터 (이어 받기 때 이미 지난 지점을 다시 말하지 않게)
            let exact: Bool = meters.truncatingRemainder(dividingBy: every) == 0
            nextMark = exact ? meters : (floor(meters / every) + 1) * every
        }
        guard meters >= nextMark else { return }
        let mark: Double = floor(meters / every) * every
        nextMark = mark + every
        var ids: [String] = []
        if sayDist, let d = VoiceCoach.dist(mark) { ids.append(d) }
        if sayTime {
            let t: [String] = VoiceCoach.dur(totalSec)
            if !t.isEmpty { ids += ["pre_time"] + t }
        }
        if sayPace {
            let p: [String] = VoiceCoach.pace(Int((Double(totalSec) / (meters / 1000)).rounded()))
            if !p.isEmpty { ids += ["pre_avg"] + p }
        }
        if sayHr, let h = avgHR, let c = VoiceCoach.hr(h) { ids.append(c) }
        say(ids, .info)
    }

    // MARK: 문장 만들기

    /// 구간 시작 때 말할 조각
    private func segClips(_ seq: [Seg], _ i: Int) -> [String] {
        let s: Seg = seq[i]
        switch s.kind {
        case .run:
            let n: Int = seq.prefix(i + 1).filter { $0.kind == .run }.count
            let runs: Int = seq.filter { $0.kind == .run }.count
            var o: [String] = [(1...8).contains(n) ? "run_\(n)" : "st_run"]
            if !open, runs > 1, n == runs { o.append("sim_lastrun") }
            return o
        case .rox:
            var o: [String] = ["st_rox"]
            if i + 1 < seq.count, let nx = seq[(i + 1)...].firstIndex(where: { $0.kind != .rox }) {
                let c: [String] = nameClip(seq, nx)
                if !c.isEmpty { o += ["pre_next"] + c }
            }
            return o
        case .st:
            if s.icon == "hiit" { return i > 0 ? ["emom_next"] : [] }
            guard let c = VoiceCoach.station(s.icon) else { return [] }
            let last: Bool = !open && i == seq.count - 1
            if last && s.icon == "wallBalls" { return ["sim_wb"] }
            if last { return [c, "sim_last"] }
            return [c]
        }
    }

    /// 구간 이름 한 조각 ("두 번째 러닝" / "스키 에르그")
    private func nameClip(_ seq: [Seg], _ i: Int) -> [String] {
        let s: Seg = seq[i]
        if s.kind == .run {
            let n: Int = seq.prefix(i + 1).filter { $0.kind == .run }.count
            return [(1...8).contains(n) ? "run_\(n)" : "st_run"]
        }
        if let c = VoiceCoach.station(s.icon) { return [c] }
        return []
    }

    /// 스테이션 아이콘 키 → 조각 id
    static func station(_ icon: String) -> String? {
        let m: [String: String] = ["run": "st_run", "skiErg": "st_ski", "sledPush": "st_push", "sledPull": "st_pull",
                                   "burpeeBroadJump": "st_bbj", "row": "st_row", "farmersCarry": "st_farm",
                                   "sandbagLunges": "st_lunge", "wallBalls": "st_wb", "roxzone": "st_rox"]
        return m[icon]
    }

    /// 시간 → 조각. 5:12 → [min_5, sec_12], 1:05:30 → [hour_1, min_5], 0초는 뺌
    static func dur(_ sec: Int) -> [String] {
        guard sec > 0 else { return [] }
        let h: Int = sec / 3600, m: Int = (sec % 3600) / 60, s: Int = sec % 60
        if h > 0 {
            guard h <= 3 else { return [] }
            return ["hour_\(h)"] + (m > 0 ? ["min_\(m)"] : [])
        }
        var o: [String] = []
        if m > 0 { o.append("min_\(m)") }
        if s > 0 { o.append("sec_\(s)") }
        return o
    }

    /// 1 km 페이스(초) → 조각 (1분 ~ 59분 59초만)
    static func pace(_ secPerKm: Int) -> [String] {
        guard secPerKm >= 60, secPerKm < 3600 else { return [] }
        return dur(secPerKm)
    }

    /// 페이스 문장: [pre_pace, min_N, sec_N]
    static func paceLine(_ secPerKm: Int) -> [String] {
        let p: [String] = pace(secPerKm)
        return p.isEmpty ? [] : ["pre_pace"] + p
    }

    /// 심박: 5 단위로 반올림, 60 ~ 200
    static func hr(_ bpm: Int) -> String? {
        guard bpm > 0 else { return nil }
        let r: Int = Int((Double(bpm) / 5).rounded()) * 5
        return "hr_\(max(60, min(200, r)))"
    }

    /// 거리(m) → 가장 가까운 조각 (250 m 넘게 차이 나면 없음)
    static func dist(_ m: Double) -> String? {
        var table: [(Double, String)] = [(100, "m_100"), (200, "m_200"), (300, "m_300"), (400, "m_400"),
                                         (500, "m_500"), (600, "m_600"), (800, "m_800"), (1000, "km_1")]
        for k in 3...20 {                       // 1.5 ~ 10 km (0.5 단위)
            let v: Double = Double(k) * 0.5
            let id: String = k % 2 == 0 ? "km_\(k / 2)" : "km_\(k / 2)_5"
            table.append((v * 1000, id))
        }
        for k in 11...21 { table.append((Double(k) * 1000, "km_\(k)")) }
        table.append((21097.5, "half"))
        table.append((42195, "full"))
        // 21 km 지점은 km_21 이 더 가까워서 그대로, 하프 · 풀 완주 문장은 그 거리에 더 가까울 때만
        guard let best = table.min(by: { abs($0.0 - m) < abs($1.0 - m) }), abs(best.0 - m) <= 250 else { return nil }
        return best.1
    }

    // MARK: 재생

    /// 응원 한 마디 (조용할 때만, 같은 문장 연속 안 나오게). 말했으면 true
    @discardableResult
    func cheer() -> Bool {
        guard enabled, playingPri == nil, pending.isEmpty,
              Date().timeIntervalSince(lastLineAt) >= VoiceCoach.cheerQuiet else { return false }
        var n: Int = Int.random(in: 1...VoiceCoach.cheerCount)
        if n == lastCheer { n = n % VoiceCoach.cheerCount + 1 }
        lastCheer = n
        say([String(format: "cheer_%02d", n)], .cheer)
        return true
    }

    /// 조각 id 들을 이어서 말함
    func say(_ ids: [String], _ pri: Pri = .info, interrupt: Bool = false) {
        guard enabled else { return }
        let list: [String] = ids.filter { !$0.isEmpty }
        guard !list.isEmpty else { return }
        if interrupt {
            cutAll()
        } else if pri.rawValue >= Pri.segment.rawValue {
            // 새 구간 안내가 기다리던 낮은 것(응원 · 거리)을 밀어냄, 말하던 응원은 끊음
            pending.removeAll { $0.pri.rawValue < pri.rawValue }
            if let cur = playingPri, cur == .cheer { cutCurrent() }
        }
        if pri == .cheer {
            guard playingPri == nil, pending.isEmpty else { return }
        }
        pending.append(Line(ids: list, pri: pri))
        if playingPri == nil && stepWork == nil { step() }
    }

    /// 지금 문장만 끊음 (기다리는 것은 둠)
    private func cutCurrent() {
        stepWork?.cancel(); stepWork = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        playingIds = []
        if playingPri != nil { lastLineAt = Date() }
        playingPri = nil
    }

    private func cutAll() {
        pending.removeAll()
        cutCurrent()
    }

    /// 다음 조각 (문장이 끝났으면 다음 문장)
    private func step() {
        stepWork = nil
        if playingIds.isEmpty {
            if playingPri != nil { playingPri = nil; lastLineAt = Date() }
            guard !pending.isEmpty else { scheduleOff(); return }
            let l: Line = pending.removeFirst()
            playingIds = l.ids
            playingPri = l.pri
            lastLineAt = Date()
            activate()
        }
        let id: String = playingIds.removeFirst()
        guard let url = VoiceCoach.url(id), let p = try? AVAudioPlayer(contentsOf: url) else { step(); return }
        p.delegate = self
        p.prepareToPlay()
        player = p
        if !p.play() {
            player = nil
            step()
        }
    }

    private func after(_ sec: Double) {
        stepWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.step() }
        stepWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + sec, execute: w)
    }

    private func clipDone(_ p: AVAudioPlayer) {
        guard p === player else { return }
        player = nil
        after(playingIds.isEmpty ? VoiceCoach.lineGap : VoiceCoach.clipGap)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in self?.clipDone(player) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in self?.clipDone(player) }
    }

    static func url(_ id: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: "m4a", subdirectory: folder)
    }

    // MARK: 오디오 세션 (다른 음악은 잠깐 작게 → 다 말하면 원래대로)

    private func activate() {
        offWork?.cancel(); offWork = nil
        guard !sessionOn else { return }
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try s.setActive(true)
            sessionOn = true
        } catch {
            sessionOn = false
        }
    }

    private func scheduleOff() {
        offWork?.cancel()
        guard sessionOn else { return }
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.playingPri == nil, self.pending.isEmpty, self.sessionOn else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.sessionOn = false
        }
        offWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }
}
