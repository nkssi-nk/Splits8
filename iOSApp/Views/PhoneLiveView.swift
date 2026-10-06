import SwiftUI
import UIKit
import CoreLocation
import Observation

// MARK: - 워치 없이 아이폰으로 기록 (시안 ⑤)
// 큰 Next 버튼으로 구간을 넘김. 화면은 꺼지지 않음. 심박 없음.
// 구간 순서는 워치(WatchStore.seq)와 같은 규칙: SeqBuilder 를 그대로 씀.

/// 아이폰 운동 진행 (워치 WorkoutEngine 의 HealthKit 없는 축소판)
@Observable
final class PhoneRunEngine: NSObject, CLLocationManagerDelegate {
    private(set) var active = false
    private(set) var finished = false
    private(set) var mode: Mode = .sim
    private(set) var title = ""
    private(set) var sets = 1
    private(set) var seq: [Seg] = []
    private(set) var idx = 0
    private(set) var splits: [Int] = []
    private(set) var running = true

    // 시간 (일시정지 제외). Date 로 계산하므로 백그라운드에 다녀와도 맞음
    private(set) var startDate = Date()
    @ObservationIgnored private var segStart = Date()
    @ObservationIgnored private var pauseAt: Date?
    @ObservationIgnored private var segPaused: Double = 0

    // 야외 러닝 GPS 거리 (Settings.runMode == outdoor, 레이스 제외 — 워치와 같음)
    @ObservationIgnored private var location: CLLocationManager?
    @ObservationIgnored private var lastLoc: CLLocation?
    private(set) var useGPS = false
    private(set) var segDist: Double = 0
    @ObservationIgnored private var segDists: [Double?] = []

    @ObservationIgnored private var settings = Settings()
    @ObservationIgnored private var friend: Friend?
    /// PFT: 시작할 때 이미 최고 기록이 있었는지 (있으면 그 구간 시간이 목표)
    @ObservationIgnored private var hasPFTBest = false

    // HIIT · 러닝 카드
    private(set) var kind: String? = nil
    @ObservationIgnored private var runKm = 0
    var isHIIT: Bool { kind == "hiit" }
    var isRunKind: Bool { kind == "run" }
    /// 끝 없이 늘어나는 운동 (HIIT · 자유 러닝)
    var growsOpen: Bool { isHIIT || (isRunKind && runKm == 0) }
    /// GPS 러닝이 총거리를 다 뛰어서 저절로 끝났을 때 (화면이 받아서 저장)
    private(set) var autoDone: Record? = nil
    // 동네 이름 · 경로
    @ObservationIgnored private var place: String?
    @ObservationIgnored private var placeLookup: PlaceLookup?
    @ObservationIgnored private var routePts: [RoutePt] = []
    @ObservationIgnored private var lastRouteLoc: CLLocation?

    // 잘못 넘김 되돌리기 (방금 넘긴 것 한 번만) — 워치와 같음
    private struct UndoPoint {
        let idx: Int
        let segStart: Date
        let segPaused: Double
        let segDist: Double
        let grew: Bool
    }
    @ObservationIgnored private var undoPoint: UndoPoint?
    private(set) var canUndo = false

    // MARK: 값

    var cur: Seg {
        if seq.indices.contains(idx) { return seq[idx] }
        return seq.last ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 270)
    }
    var hasNext: Bool { seq.indices.contains(idx + 1) }
    var next: Seg? { hasNext ? seq[idx + 1] : nil }

    func segEl(_ now: Date) -> Int {
        let p: Double = pauseAt.map { now.timeIntervalSince($0) } ?? 0
        let v: Double = now.timeIntervalSince(segStart) - segPaused - p
        return max(0, Int(v))
    }
    func doneT() -> Int { splits.prefix(idx).reduce(0, +) }
    func total(_ now: Date) -> Int { doneT() + segEl(now) }

    /// Roxzone 을 뺀 구간 수 (시안: 4 / 16)
    var countTotal: Int { seq.filter { $0.kind != .rox }.count }
    /// 현재 구간이 Roxzone 을 뺀 몇 번째인지
    var countNow: Int {
        let upTo: ArraySlice<Seg> = seq.prefix(idx + 1)
        return upTo.filter { $0.kind != .rox }.count
    }

    // MARK: 구간 순서 (워치 WatchStore.seq 와 같은 규칙)

    static func buildSeq(mode: Mode, program: Program?, store: Store) -> [Seg] {
        let s: Settings = store.settings
        switch mode {
        case .race:
            let g: [Int] = s.goals.count == 16 ? s.goals : Defaults.goals
            return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: g)
        case .sim:
            return SeqBuilder.full(div: s.div, rox: s.roxAuto, targets16: simTargets(store))
        case .pft:
            return PFT.seq(div: s.div, targets: store.pftBest?.pftSplits)
        case .training:
            let p: Program = program ?? Program.presets()[0]
            return SeqBuilder.training(p, div: s.div, bests: store.segBests)
        }
    }

    /// Full Simulation 목표 16개: 선택한 친구 → 내 최고 → 기본값
    static func simTargets(_ store: Store) -> [Int] {
        if let f = store.friend, f.hasSplits { return f.splits }
        if let b = store.simBest?.splits16, b.count == 16 { return b }
        return SeqBuilder.defaultTargets16
    }

    static func title(mode: Mode, program: Program?, store: Store) -> String {
        switch mode {
        case .training: return (program ?? Program.presets()[0]).name
        case .sim: return "Full Simulation"
        case .pft: return PFT.title
        case .race:
            let n: String = store.settings.event.name.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? "Race" : n
        }
    }

    // MARK: 시작

    func start(_ req: PhoneRunRequest) {
        guard !active else { return }
        let store = Store.shared
        settings = store.settings
        friend = store.friend?.hasSplits == true ? store.friend : nil
        hasPFTBest = store.pftBest != nil
        mode = req.mode
        title = PhoneRunEngine.title(mode: req.mode, program: req.program, store: store)
        sets = req.mode == .training ? max(1, (req.program ?? Program.presets()[0]).sets) : 1
        seq = PhoneRunEngine.buildSeq(mode: req.mode, program: req.program, store: store)
        idx = 0; splits = []; running = true; finished = false
        segDists = Array(repeating: nil, count: seq.count)
        segDist = 0; lastLoc = nil
        segPaused = 0; pauseAt = nil
        undoPoint = nil; canUndo = false
        let now = Date()
        startDate = now; segStart = now
        active = true
        kind = req.mode == .training ? req.program?.kind : nil
        runKm = req.program?.runKm ?? 0
        autoDone = nil; place = nil; routePts = []; lastRouteLoc = nil

        if isRunKind {
            useGPS = !(req.program?.indoor ?? true)
        } else {
            useGPS = req.mode != .race && settings.runMode == "outdoor"
        }
        if useGPS {
            startGPS()
        } else {
            let p = PlaceLookup()
            placeLookup = p
            p.fetch { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
    }

    /// HIIT 다음 라운드 / 자유 러닝 다음 km 를 순서 끝에 붙임
    private func growSeq() {
        let n: Int = seq.count + 1
        seq.append(isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n))
        segDists.append(nil)
    }

    /// 다음 구간 (HIIT·자유 러닝은 아직 순서에 없는 다음 라운드/km)
    var nextSeg: Seg? {
        if growsOpen && !hasNext {
            let n: Int = seq.count + 1
            return isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
        }
        return next
    }

    // MARK: 진행

    /// 다음 구간. 마지막 구간이면 끝내고 기록을 돌려줌
    func advance() -> Record? {
        guard active, !finished, running else { return nil }
        if isRunKind && useGPS { return nil }            // GPS 러닝은 1km마다 저절로 넘어감
        let now = Date()
        let up = UndoPoint(idx: idx, segStart: segStart, segPaused: segPaused, segDist: segDist,
                           grew: growsOpen && splits.count + 1 >= seq.count)
        closeSeg(now)
        if growsOpen && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            return finish(complete: true)
        }
        undoPoint = up
        canUndo = true
        idx = splits.count
        segStart = now; segPaused = 0
        segDist = 0
        return nil
    }

    /// 잘못 넘겼을 때: 방금 넘긴 것을 한 번 되돌림 (앞 구간 시간이 끊기지 않고 이어짐)
    func undo() {
        guard active, !finished, canUndo, let u = undoPoint else { return }
        guard idx == u.idx + 1, splits.count == u.idx + 1 else { undoPoint = nil; canUndo = false; return }
        let newIdx: Int = idx
        splits.removeLast()
        if segDists.indices.contains(u.idx) { segDists[u.idx] = nil }
        if u.grew, seq.count == newIdx + 1 {
            seq.removeLast()
            if segDists.count > seq.count { segDists.removeLast() }
        }
        idx = u.idx
        segStart = u.segStart
        segPaused = u.segPaused + segPaused
        segDist = u.segDist + segDist
        undoPoint = nil
        canUndo = false
    }

    func togglePause() {
        guard active, !finished else { return }
        if running {
            pauseAt = Date(); running = false
        } else {
            if let p = pauseAt { segPaused += Date().timeIntervalSince(p) }
            pauseAt = nil; running = true
            lastLoc = nil
        }
    }

    /// End → Save: 현재 구간까지 기록하고 끝냄
    func endNow() -> Record? {
        guard active, !finished else { return nil }
        if !running { togglePause() }
        closeSeg(Date())
        return finish(complete: growsOpen || splits.count >= seq.count)
    }

    /// End → Discard
    func discard() {
        stopGPS()
        active = false; finished = true
    }

    private func closeSeg(_ now: Date) {
        splits.append(segEl(now))
        if useGPS, cur.kind == .run, segDists.indices.contains(idx), segDist > 0 {
            segDists[idx] = segDist
        }
    }

    private func finish(complete: Bool) -> Record {
        stopGPS()
        undoPoint = nil; canUndo = false
        finished = true
        return makeRecord(complete: complete)
    }

    /// 워치 WorkoutEngine.makeRecord 와 같은 모양 (심박·칼로리 없음)
    private func makeRecord(complete: Bool) -> Record {
        var results: [SegResult] = []
        for (i, t) in splits.enumerated() where seq.indices.contains(i) {
            let s: Seg = seq[i]
            let d: Double? = segDists.indices.contains(i) ? segDists[i] : nil
            results.append(SegResult(icon: s.icon, name: s.name, detail: s.detail, kind: s.kind, time: t, target: s.target,
                                     hr: nil, dist: d))
        }
        let total: Int = splits.reduce(0, +)
        let tg: Int = seq.prefix(splits.count).map(\.target).reduce(0, +)
        var r = Record(mode: mode, title: title, sets: sets, date: startDate, total: total, segs: results, hr: [],
                       kcal: 0, avgHR: 0, maxHR: 0, division: settings.div.name,
                       goal: mode == .race ? settings.goalTime : nil,
                       vsWord: deltaWord, vsTarget: (kind == nil && (mode != .pft || hasPFTBest)) ? tg : nil, complete: complete)
        r.endDate = startDate.addingTimeInterval(Double(total))
        r.place = place
        r.kind = kind
        if isRunKind && useGPS && routePts.count >= 2 { r.route = routePts }
        return r
    }

    /// VS GOAL / VS JIHO / VS BEST (워치와 같음)
    var deltaWord: String {
        if mode == .race { return "VS GOAL" }
        if mode == .sim, let f = friend { return "VS " + f.first.uppercased() }
        return "VS BEST"
    }

    // MARK: GPS

    private func startGPS() {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyBest
        m.activityType = .fitness
        m.distanceFilter = 5
        location = m
        if m.authorizationStatus == .notDetermined {
            m.requestWhenInUseAuthorization()
        } else {
            m.startUpdatingLocation()
        }
    }

    private func stopGPS() {
        location?.stopUpdatingLocation()
        location?.delegate = nil
        location = nil
        lastLoc = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let st = manager.authorizationStatus
        if st == .authorizedWhenInUse || st == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            DispatchQueue.main.async { self.gotLocation(loc) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func gotLocation(_ loc: CLLocation) {
        guard active, !finished else { return }
        guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 30 else { return }
        if place == nil, placeLookup == nil {
            let p = PlaceLookup()
            placeLookup = p
            p.name(for: loc) { [weak self] name in self?.place = name; self?.placeLookup = nil }
        }
        guard running, cur.kind == .run else { lastLoc = nil; return }
        if let prev = lastLoc {
            let d: Double = loc.distance(from: prev)
            if d < 100 { segDist += d }       // 튀는 값은 버림
        }
        lastLoc = loc
        if isRunKind {
            if lastRouteLoc == nil || loc.distance(from: lastRouteLoc!) >= 8 {
                lastRouteLoc = loc
                routePts.append(RoutePt(a: loc.coordinate.latitude, o: loc.coordinate.longitude))
            }
            autoSplitIfNeeded()
        }
    }

    /// GPS 러닝: 1km 넘으면 저절로 다음 km (총거리 다 뛰면 끝 → autoDone)
    private func autoSplitIfNeeded() {
        guard isRunKind, useGPS, active, !finished, running, segDist >= 1000 else { return }
        let now = Date()
        undoPoint = nil; canUndo = false
        closeSeg(now)
        if runKm == 0 && splits.count >= seq.count { growSeq() }
        if splits.count >= seq.count {
            autoDone = finish(complete: true)
            return
        }
        idx = splits.count
        segStart = now; segPaused = 0
        segDist = 0
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - 화면 높이별 크기 (6.1" 기준 1.0, SE 는 줄이고 Pro Max 는 키움)

struct PhoneLiveMetrics {
    let k: CGFloat

    init(height h: CGFloat) {
        let v: CGFloat = h / 760
        k = max(0.8, min(1.14, v))
    }

    var totalFont: CGFloat { 76 * k }
    var segFont: CGFloat { 64 * k }
    var icon: CGFloat { 52 * k }
    var nameFont: CGFloat { 24 * min(k, 1.08) }
    var detailFont: CGFloat { 15 * min(k, 1.08) }
    var nextFont: CGFloat { 18 * min(k, 1.06) }
    var nextIcon: CGFloat { 24 * min(k, 1.06) }
    var top: CGFloat { 24 * k }
    var segTop: CGFloat { 30 * k }
    var dividerTop: CGFloat { 26 * k }
    var buttonH: CGFloat { max(80, min(104, 96 * k)) }
    var buttonFont: CGFloat { 26 * min(k, 1.08) }
    var pillH: CGFloat { max(54, min(68, 64 * k)) }
    var bottom: CGFloat { 16 * k }
}

// MARK: - 화면

struct PhoneLiveView: View {
    let r = Router.shared
    @State private var eng = PhoneRunEngine()
    @State private var askEnd = false
    @State private var flash: Double = 0
    /// 시작 전 3 · 2 · 1 (nil = 세는 중 아님)
    @State private var count: Int? = nil
    @State private var countTimer: Timer? = nil

    private var req: PhoneRunRequest { r.phoneRun ?? PhoneRunRequest(mode: .sim) }

    var body: some View {
        GeometryReader { g in
            let m = PhoneLiveMetrics(height: g.size.height)
            content(m)
                .frame(width: g.size.width, height: g.size.height)
        }
        .overlay {
            C.accent.opacity(flash * 0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .overlay { if let n = count { countdownView(n) } }
        .onAppear(perform: begin)
        .onDisappear(perform: leave)
        .onChange(of: eng.autoDone) { _, rec in
            if let rec {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                done(rec)
            }
        }
        .alert("End workout?", isPresented: $askEnd) {
            Button("Save") { save() }
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the segments you've done so far?")
        }
    }

    private func content(_ m: PhoneLiveMetrics) -> some View {
        VStack(spacing: 0) {
            header
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                live(m, now: ctx.date)
            }
            .padding(.top, m.top)
            nextRow(m)
            Spacer(minLength: 16)
            nextButton(m)
            HStack(spacing: 10) {
                endPill(m)
                undoPill(m)
                pausePill(m)
            }
            .padding(.top, 16 * m.k)
            .padding(.bottom, m.bottom)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 위

    /// Full Simulation (15/600 노랑) · iPhone · No HR (13 회색)
    private var header: some View {
        HStack {
            Text((eng.mode == .training ? eng.title : eng.mode.name).l10n)
                .font(F.t(15, .semibold)).foregroundStyle(C.accent).lineLimit(1)
            Spacer(minLength: 12)
            Text("iPhone · No HR").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).fixedSize()
        }
        .frame(height: 44)
    }

    /// TOTAL · 큰 전체 시간 · [아이콘 구간 시간] · 이름 · 설명
    private func live(_ m: PhoneLiveMetrics, now: Date) -> some View {
        let cur: Seg = eng.cur
        let el: Int = eng.segEl(now)
        let tint: IconTint = cur.kind == .rox ? .mute : .yellow
        let timeColor: Color = eng.running ? .white : C.text2
        return VStack(spacing: 0) {
            Text("TOTAL").font(F.t(12, .semibold)).tracking(0.12 * 12).foregroundStyle(C.text2)
            Text(Fm.t(eng.total(now)))
                .font(F.num(m.totalFont)).tracking(-0.02 * m.totalFont)
                .foregroundStyle(timeColor)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("phone.total")
            HStack(spacing: 14 * m.k) {
                Icon8(cur.icon, m.icon, tint: tint)
                Text(Fm.t(el))
                    .font(F.num(m.segFont)).tracking(-0.01 * m.segFont)
                    .foregroundStyle(timeColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.top, m.segTop)
            Text(cur.name)
                .font(F.t(m.nameFont, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 8 * m.k)
            Text(detailLine)
                .font(F.num(m.detailFont, .regular)).foregroundStyle(C.aeb)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// 50M · 152KG · 4 / 16  /  러닝: 1KM (GPS면 0.38 KM / 1KM) · 3 / 16  /  Roxzone: TRANSITION
    private var detailLine: String {
        let cur: Seg = eng.cur
        if cur.kind == .rox { return cur.detail }
        var head: String = cur.detail
        if cur.kind == .run && eng.useGPS {
            let km: Double = eng.segDist / 1000
            head = String(format: "%.2f KM / ", km) + cur.detail
        }
        return head + " · \(eng.countNow) / \(eng.countTotal)"
    }

    /// 선 · NEXT [아이콘] 이름
    private func nextRow(_ m: PhoneLiveMetrics) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.top, m.dividerTop)
                .padding(.bottom, 14 * m.k)
            HStack(spacing: 10) {
                Text("NEXT").font(F.t(13)).tracking(0.1 * 13).foregroundStyle(C.text2)
                if let nx = eng.nextSeg {
                    Icon8(nx.icon, m.nextIcon, tint: nx.kind == .rox ? .mute : .yellow)
                    Text(nx.name).font(F.t(m.nextFont, .semibold)).lineLimit(1)
                } else {
                    Text("Finish").font(F.t(m.nextFont, .semibold)).foregroundStyle(C.accent).lineLimit(1)
                }
            }
        }
    }

    // MARK: 아래 버튼

    private func nextButton(_ m: PhoneLiveMetrics) -> some View {
        YellowButton(height: m.buttonH, radius: m.buttonH / 2, enabled: eng.running && !(eng.isRunKind && eng.useGPS),
                     action: { next() }) {
            HStack(spacing: 10) {
                Text((eng.isRunKind && eng.useGPS ? "Auto split every 1 km" : ((eng.hasNext || eng.growsOpen) ? "Next" : "Finish")).l10n)
                Text("›")
            }
            .font(F.t(m.buttonFont, .semibold))
        }
        .accessibilityIdentifier("phone.next")
    }

    /// ■ End (빨강 글자, 빨강 22% 바탕)
    private func endPill(_ m: PhoneLiveMetrics) -> some View {
        Button { askEnd = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill").font(.system(size: 14, weight: .semibold))
                Text("End").font(F.t(16, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(C.bad)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color(hex: 0xFF453A, alpha: 0.22), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("phone.end")
    }

    /// ❚❚ Pause / ▶ Resume (회색 12%)
    private func pausePill(_ m: PhoneLiveMetrics) -> some View {
        Button { eng.togglePause() } label: {
            HStack(spacing: 7) {
                Image(systemName: eng.running ? "pause.fill" : "play.fill").font(.system(size: 14, weight: .semibold))
                Text(eng.running ? "Pause" : "Resume").font(F.t(16, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(eng.running ? Color.white : C.accent)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color.white.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("phone.pause")
    }

    /// ↩ Undo (회색 12%, 되돌릴 것이 없으면 흐리게): 방금 넘긴 것을 한 번 되돌림
    private func undoPill(_ m: PhoneLiveMetrics) -> some View {
        let on: Bool = eng.canUndo
        return Button { undo() } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 14, weight: .semibold))
                Text("Undo").font(F.t(16, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.white : C.text3)
            .frame(maxWidth: .infinity).frame(height: m.pillH)
            .background(Color.white.opacity(on ? 0.12 : 0.05), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .disabled(!on)
        .accessibilityIdentifier("phone.undo")
    }

    // MARK: 시작 전 3 · 2 · 1

    /// 화면 전체를 덮는 큰 숫자. 숫자마다 가벼운 진동, 시작 순간은 세게. 누르면 취소하고 돌아감
    private func countdownView(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(verbatim: "\(n)")
                    .font(F.num(160, .bold)).foregroundStyle(C.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.25), value: n)
                    .accessibilityIdentifier("phone.count")
                Text("Tap to cancel").font(F.t(15)).foregroundStyle(C.text2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { cancelCount() }
        .transition(.opacity)
    }

    private func startCount() {
        count = 3
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async { countTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        countTimer = t
    }

    private func countTick() {
        guard let c = count else { return }
        if c > 1 {
            count = c - 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } else {
            stopCountTimer()
            withAnimation(.easeOut(duration: 0.15)) { count = nil }
            if !eng.active { eng.start(req) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            flashNow()
        }
    }

    private func stopCountTimer() {
        countTimer?.invalidate()
        countTimer = nil
    }

    private func cancelCount() {
        stopCountTimer()
        count = nil
        UIApplication.shared.isIdleTimerDisabled = false
        r.go(req.from)
    }

    // MARK: 동작

    private func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        // 3 · 2 · 1 을 센 뒤 시작 (화면 확인용 --nocount 는 바로 시작)
        if !eng.active && count == nil {
            if CommandLine.arguments.contains("--nocount") { eng.start(req) } else { startCount() }
        }
        // 왼쪽 끝에서 밀기 = End 확인 (실수로 나가지 않게). 세는 중이면 취소
        r.backAction = { if count != nil { cancelCount() } else { askEnd = true } }
    }

    private func leave() {
        stopCountTimer()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func undo() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        eng.undo()
    }

    private func next() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        flashNow()
        if let rec = eng.advance() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            done(rec)
        }
    }

    private func flashNow() {
        withAnimation(.linear(duration: 0.06)) { flash = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.26)) { flash = 0 }
        }
    }

    private func save() {
        if let rec = eng.endNow() { done(rec) }
    }

    private func done(_ rec: Record) {
        let from: Scr = req.from
        UIApplication.shared.isIdleTimerDisabled = false
        Store.shared.addPhoneRecord(rec)
        // addPhoneRecord 가 source = "phone" 을 붙여 저장 → 저장된 것으로 상세 열기
        var shown = rec
        shown.source = "phone"
        r.open(shown, from: from)
    }

    private func discard() {
        let from: Scr = req.from
        eng.discard()
        UIApplication.shared.isIdleTimerDisabled = false
        r.go(from)
    }
}

// MARK: - Start on iPhone (탭 화면에 놓는 작은 회색 버튼)

struct StartOnPhoneButton: View {
    let mode: Mode
    var program: Program? = nil
    /// 시작 직전에 할 일 (예: 시트 닫기). 있으면 닫힌 뒤 조금 있다가 시작
    var before: (() -> Void)? = nil
    /// true = 가로로 꽉 찬 큰 노란 버튼 (PFT 첫 화면)
    var big: Bool = false
    @State private var confirm = false

    @ViewBuilder
    private var label: some View {
        if big {
            YellowButton(height: 50, radius: 16, action: { confirm = true }) {
                Text("Start on iPhone")
            }
        } else {
            Button { confirm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone").font(.system(size: 14, weight: .semibold))
                    Text("Start on iPhone").font(F.t(14, .semibold)).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 36)
                .background(Color.white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(Press(scale: 0.96))
            .fixedSize()
        }
    }

    var body: some View {
        label
        .accessibilityIdentifier("startOnPhone." + mode.rawValue)
        // 시작 전 확인: 아이폰 기록은 워치 기능(심박 등)을 못 씀
        .alert("Start on iPhone?", isPresented: $confirm) {
            Button("Start") {
                if let before {
                    before()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Router.shared.startOnPhone(mode, program: program) }
                } else {
                    Router.shared.startOnPhone(mode, program: program)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Recording on iPhone can't measure heart rate, calories or HR zones, and there are no watch vibration alerts. Only split times are recorded (plus GPS distance for outdoor runs).")
        }
    }
}
