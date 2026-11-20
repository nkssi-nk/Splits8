import SwiftUI

// MARK: - 1.2.7 운동 중 화면 공용 부품 (대표님 11-20 확정 — 프로젝트 문서 splits8-1.2.7-폰-운동중화면.md)
// 아이폰으로 기록(PhoneLiveView) · 워치 운동 같이 보기(WatchLiveView) 두 화면이 같은 모양.
// 3장 (왼쪽으로 밀기): 운동 · 목표 대비 · 구간 목록. 맨 위(상태 · TOTAL)와 아래 버튼은 세 장 모두 같은 자리.
// 배경 = 워치와 같은 뜻의 색 (스테이션 노랑 · 러닝 파랑 · Roxzone/휴식 회색) + C안 (크게 흐린 덩어리 + 위쪽 밝은 빛).
// 393×852 기준 pt. 위치는 화면 높이 비율, 크기는 min(가로, 세로) 비율.

/// 화면 한 장면에 필요한 값 (엔진 · 워치에서 받은 상태 어느 쪽이든 여기로 바꿔 그림)
struct LiveFrame {
    var mode: Mode
    var title: String
    var seq: [Seg]
    var idx: Int
    var segEl: Int
    var total: Int
    var running: Bool
    /// HIIT · 자유 러닝 (점 숨김)
    var open: Bool
    /// 러닝 페이스용 지금 구간 거리(m) — 못 재면 nil
    var segDist: Double?
    /// 운동 전체 거리(m) — 러닝 카드
    var totalDist: Double?
    /// 러닝 카드(트레이닝 러닝)인지
    var runKind: Bool
    /// 지금 속도(m/s) — 실시간 페이스. nil · 0 = 모름
    var speed: Double? = nil
    /// 1.2.2: 러닝 카드 · 목표 거리(km, 0 = 자유 러닝)
    var runCard: Bool = false
    var runGoalKm: Int = 0
    /// 1.2.7: 끝난 구간 시간 (목표 대비 · 구간 목록)
    var splits: [Int] = []
    /// 1.2.7: 심박 (폰만이면 nil) · 존 · 칼로리
    var hr: Int? = nil
    var zone: Int = 0
    var kcal: Int? = nil

    var cur: Seg { seq.indices.contains(idx) ? seq[idx] : (seq.last ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 0)) }
    /// 목표 이름: 트레이닝은 최고 기록(BEST), 나머지는 GOAL
    var goalWord: String { mode == .training ? "BEST" : "GOAL" }

    /// 빌드 27: lb · mi 로 보여 주는지 (설정 > Units)
    var imperial: Bool { Store.shared.settings.imperial }

    /// 구간 색 (러닝 카드는 파랑)
    var tone: W8Tone { runCard ? .run : W8Tone.of(cur) }

    /// 귀퉁이 표시 안 둘째 줄: 러닝 = "0.62 / 1.00 km", 스테이션 = 세부(50M · 152KG), Roxzone = Transition, 휴식 = to 다음
    var detailLine: String {
        let c: Seg = cur
        let imp: Bool = imperial
        if c.icon == "rest" {
            guard let nx = seq.indices.contains(idx + 1) ? seq[idx + 1] : nil else { return "" }
            return String(format: "to %@".l10n, nx.name)
        }
        if c.kind == .rox { return "Transition".l10n }
        if c.kind == .run {
            guard let sd = segDist else { return Units.detail(c.detail, imp) }
            let segM: Double = runMeters(c.detail)
            return Units.dist(min(segM, sd), imp) + " / " + Units.dist(segM, imp) + " " + Units.distUnit(imp)
        }
        return c.detail.isEmpty || c.icon == "hiit" ? "" : Units.detail(c.detail, imp)
    }

    /// 1.2.2 러닝 카드: 지금까지 거리(m). 잰 거리가 없으면(실내 손으로 넘김) 지난 km 수
    var runDist: Double { (totalDist ?? 0) > 0 ? (totalDist ?? 0) : Double(idx) * 1000 }

    /// 러닝 카드 아래 줄: "Goal 10 km · Avg 5:12"
    var runSummary: String {
        let imp: Bool = imperial
        var parts: [String] = []
        if runGoalKm > 0 {
            parts.append(String(format: (imp ? "Goal %@ mi" : "Goal %@ km").l10n,
                                imp ? Units.dist(Double(runGoalKm) * 1000, true) : String(runGoalKm)))
        }
        let d: Double = runDist
        if d >= 200 {
            let avg: Int = Units.pace(Int((Double(total) / d * 1000).rounded()), imp)
            if avg > 0 && avg < 3600 { parts.append(String(format: "Avg %@".l10n, Fm.t(avg))) }
        }
        return parts.joined(separator: " · ")
    }

    /// 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km). 마지막이면 nil
    var nextSeg: Seg? {
        if seq.indices.contains(idx + 1) { return seq[idx + 1] }
        guard open else { return nil }
        let n: Int = seq.count + 1
        return cur.icon == "hiit" ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
    }

    // 목표 대비
    var targetTotal: Int { seq.map(\.target).reduce(0, +) }
    var hasGoal: Bool { !open && !runCard && targetTotal > 0 && seq.allSatisfy { $0.target > 0 || $0.kind == .rox } }
    var delta: Int {
        let done: Int = splits.prefix(idx).reduce(0, +)
        let tg: Int = seq.prefix(idx).map(\.target).reduce(0, +)
        return done - tg + max(0, segEl - cur.target)
    }
}

/// 폰 화면 크기 맞춤 (393×852 기준)
struct PL {
    let w: CGFloat, h: CGFloat
    var s: CGFloat { min(w / 393, h / 852) }
    /// 세로 자리 (화면 높이 비율)
    func y(_ v: CGFloat) -> CGFloat { v * h / 852 }
    /// 크기
    func v(_ v: CGFloat) -> CGFloat { v * s }
}

// MARK: 배경 (C안)

/// 구간 색 그라데이션 + 심박 Z4 · Z5 + 크게 흐린 덩어리 + 위쪽 밝은 빛
struct LiveBackground: View {
    let tone: W8Tone
    var zone: Int = 0
    var seed: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: tone.stops, startPoint: .top, endPoint: .bottom)
            ForEach([4, 5], id: \.self) { z in
                if let zs = tone.zoneStops(z) {
                    LinearGradient(stops: [.init(color: zs.colors[0], location: 0),
                                           .init(color: zs.colors[1], location: zs.mid),
                                           .init(color: zs.colors[2], location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .opacity(zone == z ? 1 : 0)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: zone)
            W8Blobs(seed: seed &+ 101, color: tone.blob, alpha: tone == .station ? 0.38 : 0.22, blurPt: 46)
                .id(seed)
                .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            // 위쪽 밝은 빛
            RadialGradient(colors: [Color.white.opacity(tone == .station ? 0.30 : 0.16), Color.white.opacity(0)],
                           center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 360)
        }
        .compositingGroup()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// 심박 존 배경: 경계에서 오락가락하면 깜빡이지 않게 3초 머문 뒤 바꿈 (워치와 같은 규칙)
@Observable
final class LiveZoneHold {
    private(set) var shown: Int = 0
    @ObservationIgnored private var pending: Int = 0
    @ObservationIgnored private var since: Int = 0

    func update(raw: Int) {
        let z: Int = raw >= 5 ? 5 : (raw == 4 ? 4 : 0)
        if z == shown { pending = z; since = 0; return }
        if z != pending { pending = z; since = 0 }
        since += 1
        if since >= 3 { shown = z; since = 0 }
    }
}

// MARK: 맨 위: "Race · ● Watch · 168 BPM" → TOTAL 23:41

struct LiveTop: View {
    let f: LiveFrame
    let L: PL
    let status: String
    let live: Bool
    let idPrefix: String

    var body: some View {
        let t: W8Tone = f.tone
        // 시안: 상태 줄 13 (대문자 가운데 70) · TOTAL 13 + 값 30 (104)
        ZStack {
            HStack(spacing: 6) {
                Text((f.mode == .training ? f.title : f.mode.name).l10n).font(F.t(L.v(13), .semibold))
                Text(verbatim: "·")
                Circle().fill(live ? Color(hex: 0x34C759) : t.sub).frame(width: 7, height: 7)
                Text(status.l10n).font(F.t(L.v(13), .semibold))
                    .accessibilityIdentifier("\(idPrefix).status")
            }
            .foregroundStyle(t.label)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 24)
            .position(x: L.w / 2, y: L.y(70))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(f.runCard ? "TIME" : "TOTAL").font(F.t(L.v(13), .bold)).tracking(1).foregroundStyle(t.label)
                Text(Fm.t(f.total)).font(F.num(L.v(30), .semibold)).foregroundStyle(f.running ? t.ink : t.sub)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("\(idPrefix).total")
            }
            .lineLimit(1)
            .position(x: L.w / 2, y: L.y(104))
        }
        .shadow(color: t.shadow, radius: 7, y: 2)
    }
}

// MARK: 칸

struct LiveCell: View {
    let L: PL
    let label: String
    let value: String
    let tone: W8Tone
    var strong: Bool = false
    var size: CGFloat = 40

    var body: some View {
        // 시안: 이름표 14 (대문자 가운데) 와 값 40 사이 40 → 줄 가운데에서 위아래 20
        ZStack {
            Text(verbatim: label).font(F.t(L.v(14), .bold)).tracking(0.8)
                .foregroundStyle(strong ? tone.ink : tone.label)
                .lineLimit(1).minimumScaleFactor(0.6)
                .offset(y: -L.y(20))
            Text(verbatim: value).font(F.num(L.v(size), .semibold)).foregroundStyle(tone.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .offset(y: L.y(20))
        }
        .frame(maxWidth: .infinity)
    }
}

/// 귀퉁이 표시 블록 (148 ~ 340, 좌우 24)
struct LiveBrackets: View {
    let L: PL
    let tone: W8Tone
    var top: CGFloat = 148
    var bottom: CGFloat = 340

    var body: some View {
        W8Brackets(arm: L.v(18))
            .stroke(tone.mark, style: StrokeStyle(lineWidth: L.v(4), lineCap: .round, lineJoin: .round))
            .frame(width: L.w - 48, height: L.y(bottom - top))
            .position(x: L.w / 2, y: L.y((top + bottom) / 2))
    }
}

/// 진행 점: 지금 막대 24 · 점 6.8 · 간격 13 (10개 이하 18)
struct LiveDots: View {
    let L: PL
    let total: Int
    let current: Int
    var currentDim: Bool = false
    let tone: W8Tone

    var body: some View {
        let d: CGFloat = L.v(6.8)
        let base: CGFloat = total <= 10 ? 18 : 13
        let fit: CGFloat = total > 1 ? (L.w - 80) / CGFloat(total - 1) : base
        let gap: CGFloat = min(L.v(base), fit)
        HStack(spacing: max(1, gap - d)) {
            ForEach(0..<max(0, total), id: \.self) { i in
                if i == current {
                    Capsule().fill(tone.ink).opacity(currentDim ? 0.5 : 1).frame(width: L.v(24), height: d)
                } else {
                    Circle().fill(i < current ? tone.ink : tone.dotOff).frame(width: d, height: d)
                }
            }
        }
    }
}

/// 세 장 넘김 점 (598)
struct LivePageDots: View {
    let L: PL
    let count: Int
    let page: Int
    let tone: W8Tone

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(i == page ? tone.ink : tone.dotOff).frame(width: 7, height: 7)
            }
        }
        .position(x: L.w / 2, y: L.y(598))
        .allowsHitTesting(false)
    }
}

/// 큰 숫자 블록 (시안: 이름표 17 · 16 · 숫자 84 · 16 · 단위 15 — 대문자 높이로 재서 148~340 가운데)
struct LiveBigBlock: View {
    let L: PL
    let label: String
    let main: String
    var unit: String = ""
    let tone: W8Tone
    var labelColor: Color? = nil

    var body: some View {
        let hasUnit: Bool = !unit.isEmpty
        ZStack {
            Text(verbatim: label).font(F.t(L.v(17), .bold)).tracking(1).foregroundStyle(labelColor ?? tone.sub)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: L.w - 80)
                .position(x: L.w / 2, y: L.y(hasUnit ? 192.9 : 206.2))
            Text(verbatim: main).font(F.num(L.v(84), .bold)).foregroundStyle(tone.ink)
                .lineLimit(1).minimumScaleFactor(0.45).frame(width: L.w - 80)
                .contentTransition(.numericText())
                .position(x: L.w / 2, y: L.y(hasUnit ? 244.7 : 258))
            if hasUnit {
                Text(verbatim: unit).font(F.t(L.v(15), .bold)).tracking(1).foregroundStyle(tone.label)
                    .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center).frame(width: L.w - 80)
                    .position(x: L.w / 2, y: L.y(295.9))
            }
        }
        .shadow(color: tone.shadow, radius: 7, y: 2)
    }
}

// MARK: 1장: 운동 (구간 · 러닝 카드)

struct LiveMain: View {
    let f: LiveFrame
    let L: PL
    let idPrefix: String

    var body: some View {
        let t: W8Tone = f.tone
        ZStack {
            LiveBrackets(L: L, tone: t)
            if f.runCard { runBlock(t) } else { segBlock(t) }
            cells(t)
                .frame(width: L.w - 48)
                .shadow(color: t.shadow, radius: 7, y: 2)
                .position(x: L.w / 2, y: L.y(398))
            if f.runCard {
                runBar(t).position(x: L.w / 2, y: L.y(482))
            } else if !f.open {
                dots(t).position(x: L.w / 2, y: L.y(482))
            } else if f.cur.icon == "hiit" {
                Text(String(format: "%lld rounds done".l10n, f.idx)).font(F.t(L.v(15), .bold)).foregroundStyle(t.sub)
                    .position(x: L.w / 2, y: L.y(482))
            }
            nextRow(t)
                .shadow(color: t.shadow, radius: 7, y: 2)
                .position(x: L.w / 2, y: L.y(534))
        }
    }

    /// 시안: 이름 52 (폭 300 넘으면 30 까지) · 18 · 무게/거리 22 — 대문자 높이로 재서 귀퉁이 표시(148~340) 가운데
    private func segBlock(_ t: W8Tone) -> some View {
        let one: Bool = f.detailLine.isEmpty
        return ZStack {
            Text(verbatim: f.cur.name).font(F.t(L.v(52), .bold)).foregroundStyle(t.ink)
                .lineLimit(1).minimumScaleFactor(30 / 52)
                .frame(width: min(L.w - 80, L.v(300)))
                .position(x: L.w / 2, y: L.y(one ? 244 : 227.2))
            if !one {
                Text(verbatim: f.detailLine).font(F.t(L.v(22), .semibold)).foregroundStyle(t.sub)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: L.w - 80)
                    .position(x: L.w / 2, y: L.y(271.4))
            }
        }
        .shadow(color: t.shadow, radius: 7, y: 2)
        .accessibilityIdentifier("\(idPrefix).name")
    }

    private func runBlock(_ t: W8Tone) -> some View {
        LiveBigBlock(L: L, label: f.title.isEmpty ? "Run".l10n : f.title.l10n, main: Units.dist(f.runDist, f.imperial),
                     unit: f.imperial ? "MI" : "KM", tone: t)
            .accessibilityIdentifier("\(idPrefix).dist")
    }

    private struct Cell { let label: String; let value: String; var strong: Bool = false; var id: String? = nil }

    private var cellList: [Cell] {
        let c: Seg = f.cur
        var out: [Cell] = []
        let paceLabel: String = (f.imperial ? "PACE /MI" : "PACE").l10n
        if f.runCard {
            out.append(Cell(label: paceLabel, value: LivePace.text(el: f.total, dist: f.runDist, imperial: f.imperial, speed: f.speed)))
        } else {
            let over: Int = c.target > 0 && c.kind != .rox ? f.segEl - c.target : 0
            if over > 0 {
                out.append(Cell(label: "OVER".l10n + " +" + Fm.t(over), value: Fm.t(f.segEl), strong: true, id: "seg"))
            } else {
                out.append(Cell(label: (c.icon == "hiit" ? "ROUND" : "SPLIT").l10n, value: Fm.t(f.segEl), id: "seg"))
            }
            if c.kind == .run {
                out.append(Cell(label: paceLabel, value: LivePace.text(el: f.segEl, dist: f.segDist, imperial: f.imperial, speed: f.speed)))
            } else if c.target > 0 && c.icon != "rest" {
                out.append(Cell(label: f.goalWord.l10n, value: Fm.t(c.target), id: "goal"))
            }
        }
        if let hr = f.hr {
            out.append(Cell(label: "♥ " + "BPM".l10n, value: hr > 0 ? "\(hr)" : "--"))
        }
        return out
    }

    private func cells(_ t: W8Tone) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cellList.enumerated()), id: \.offset) { _, c in
                LiveCell(L: L, label: c.label, value: c.value, tone: t, strong: c.strong)
                    .accessibilityIdentifier(c.id.map { "\(idPrefix).\($0)" } ?? "\(idPrefix).cell")
            }
        }
    }

    /// 점: Roxzone 은 빼고 셈 (Roxzone 중에는 다음 것을 흐린 막대로)
    private func dots(_ t: W8Tone) -> some View {
        let units: [Int] = f.seq.indices.filter { f.seq[$0].kind != .rox || f.seq[$0].icon == "rest" }
        let before: Int = units.filter { $0 < f.idx }.count
        let onRox: Bool = f.cur.kind == .rox && f.cur.icon != "rest"
        return LiveDots(L: L, total: units.count, current: before, currentDim: onRox, tone: t)
    }

    private func runBar(_ t: W8Tone) -> some View {
        let frac: Double? = f.runGoalKm > 0 ? min(1, f.runDist / (Double(f.runGoalKm) * 1000)) : nil
        return VStack(spacing: L.v(10)) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.3))
                if let frac {
                    Capsule().fill(Color.white).frame(width: max(L.v(7), (L.w - 80) * frac))
                }
            }
            .frame(width: L.w - 80, height: L.v(7))
            Text(verbatim: f.runSummary).font(F.num(L.v(15), .semibold)).foregroundStyle(t.sub).lineLimit(1)
        }
    }

    private func nextRow(_ t: W8Tone) -> some View {
        let nx: Seg? = f.nextSeg
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            if !f.runCard {
                Text("Next").font(F.t(L.v(26), .semibold)).foregroundStyle(t.sub)
                Text(verbatim: nx.map { $0.name } ?? "Finish".l10n).font(F.t(L.v(26), .bold)).foregroundStyle(t.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityIdentifier("live.nextName")
            }
        }
        .frame(maxWidth: L.w - 48)
    }
}

// MARK: 2장: 목표 대비

struct LiveGoalPage: View {
    let f: LiveFrame
    let L: PL
    /// 워치 같이 보기: 최고 · 평균 심박 (폰만이면 nil)
    var maxHR: Int? = nil
    var avgHR: Int? = nil

    var body: some View {
        let t: W8Tone = f.tone
        let d: Int = f.delta
        let vsBest: Bool = f.mode == .training || f.mode == .pft
        ZStack {
            LiveBrackets(L: L, tone: t)
            if f.hasGoal {
                LiveBigBlock(L: L, label: vsBest ? "VS BEST".l10n : "VS GOAL".l10n, main: Fm.d(d),
                             unit: (d < 0 ? "AHEAD" : (d > 0 ? "BEHIND" : "ON PACE")).l10n, tone: t)
                HStack(spacing: 0) {
                    LiveCell(L: L, label: "FINISH".l10n, value: Fm.t(f.targetTotal + d), tone: t)
                    LiveCell(L: L, label: (vsBest ? "BEST" : "GOAL").l10n, value: Fm.t(f.targetTotal), tone: t)
                }
                .frame(width: L.w - 48)
                .shadow(color: t.shadow, radius: 7, y: 2)
                .position(x: L.w / 2, y: L.y(398))
            } else {
                LiveBigBlock(L: L, label: (f.runCard ? "TIME" : "TOTAL").l10n, main: Fm.t(f.total), tone: t)
            }
            if f.hr != nil {
                HStack(spacing: 0) {
                    LiveCell(L: L, label: "MAX HR".l10n, value: (maxHR ?? 0) > 0 ? "\(maxHR ?? 0)" : "--", tone: t)
                    LiveCell(L: L, label: "AVG BPM".l10n, value: (avgHR ?? 0) > 0 ? "\(avgHR ?? 0)" : "--", tone: t)
                    LiveCell(L: L, label: "KCAL".l10n, value: f.kcal.map { "\($0)" } ?? "--", tone: t)
                }
                .frame(width: L.w - 48)
                .shadow(color: t.shadow, radius: 7, y: 2)
                .position(x: L.w / 2, y: L.y(f.hasGoal ? 498 : 398))
            }
        }
        .accessibilityIdentifier("live.goalPage")
    }
}

// MARK: 아래 버튼 (세 장 모두 같은 자리)

/// 큰 Next (626~700) + 알약 4개 End · Undo · Skip · Pause (714~768)
struct LiveButtons: View {
    let L: PL
    let tone: W8Tone
    let idPrefix: String
    /// nil = 큰 버튼 없음 (러닝 카드 GPS)
    var nextTitle: String?
    var nextOn: Bool = true
    var showUndo: Bool = true
    var undoOn: Bool = false
    var showSkip: Bool = false
    var skipOn: Bool = false
    var running: Bool = true
    var enabled: Bool = true
    let onNext: () -> Void
    let onEnd: () -> Void
    let onUndo: () -> Void
    var onSkip: () -> Void = {}
    let onPause: () -> Void

    var body: some View {
        let mainFill: Color = tone.dark ? Color.black.opacity(0.69) : Color.white.opacity(0.8)
        let mainInk: Color = tone.dark ? C.accent : Color(hex: 0x1E78FA)
        ZStack {
            if let nextTitle {
                Button(action: onNext) {
                    HStack(spacing: 12) {
                        W8NextArrow().frame(width: L.v(26), height: L.v(22))
                        Text(nextTitle.l10n).font(F.t(L.v(24), .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(mainInk)
                    .opacity(nextOn ? 1 : 0.45)
                    .frame(maxWidth: .infinity).frame(height: L.y(74))
                    .background(W8Glass(shape: Capsule(), fill: mainFill, rim: 0.22))
                    .contentShape(Capsule())
                }
                .buttonStyle(W8Press())
                .disabled(!nextOn || !enabled)
                .padding(.horizontal, 20)
                .position(x: L.w / 2, y: L.y(663))
                .accessibilityIdentifier("\(idPrefix).next")
            }
            HStack(spacing: 8) {
                pill("End", fill: Color(hex: 0xFF3B30).opacity(0.59), rim: 0.22, fg: .white, on: enabled, id: "end", action: onEnd) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: L.v(15), weight: .semibold))
                }
                if showUndo {
                    pill("Undo", on: undoOn && enabled, id: "undo", action: onUndo) {
                        W8UndoIcon(size: L.v(15), color: tone.ink)
                    }
                }
                if showSkip {
                    pill("Skip", on: skipOn && enabled, id: "skip", action: onSkip) {
                        Image(systemName: "forward.end.fill").font(.system(size: L.v(12), weight: .bold))
                    }
                }
                pill(running ? "Pause" : "Resume", on: enabled, id: "pause", action: onPause) {
                    W8PauseIcon(size: L.v(12), color: tone.ink, paused: !running)
                }
            }
            .padding(.horizontal, 20)
            .position(x: L.w / 2, y: L.y(741))
        }
    }

    private func pill<I: View>(_ t: String, fill: Color? = nil, rim: Double = 0.59, fg: Color? = nil, on: Bool, id: String,
                               action: @escaping () -> Void, @ViewBuilder icon: () -> I) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon()
                Text(t.l10n).font(F.t(L.v(15), .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(fg ?? tone.ink)
            .opacity(on ? 1 : 0.4)
            .frame(maxWidth: .infinity).frame(height: L.y(54))
            .background(W8Glass(shape: Capsule(), fill: fill ?? Color.white.opacity(tone.glass), rim: rim))
            .contentShape(Capsule())
        }
        .buttonStyle(W8Press())
        .disabled(!on)
        .accessibilityIdentifier("\(idPrefix).\(id)")
    }
}

// MARK: 3장: 구간 목록

/// 끝난 구간: 내 시간 + 비교 기준과 차이. 지금 구간: 유리 띠 + 흐르는 시간. 남은 구간: 기준 시간 흐리게. 아이콘 없음.
struct LiveSegmentList: View {
    let L: PL
    let tone: W8Tone
    let seq: [Seg]
    let idx: Int
    let splits: [Int]
    let skipped: Set<Int>
    let segEl: Int
    /// "VS GOAL" · "VS LAST" · "VS JIHO" · "VS BEST"
    let word: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("SEGMENTS").font(F.t(L.v(14), .bold)).tracking(1).foregroundStyle(tone.ink)
                Text("\(min(idx + 1, seq.count))/\(seq.count)").font(F.num(L.v(14), .semibold)).foregroundStyle(tone.sub)
                Spacer(minLength: 0)
                Text(word.l10n).font(F.t(L.v(13), .bold)).tracking(0.8).foregroundStyle(tone.label)
            }
            .padding(.horizontal, 30)
            .frame(height: L.y(24))
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(seq.enumerated()), id: \.offset) { i, s in
                            row(i, s).id(i)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onAppear { proxy.scrollTo(idx, anchor: .center) }
                .onChange(of: idx) { _, n in withAnimation { proxy.scrollTo(n, anchor: .center) } }
            }
            .frame(height: L.y(574 - 158))
        }
        .frame(width: L.w)
        .position(x: L.w / 2, y: L.y((134 + 574) / 2))
        .accessibilityIdentifier("phone.segments")
    }

    private func mySplit(_ i: Int) -> Int { splits.indices.contains(i) ? splits[i] : 0 }

    private var good: Color { tone.dark ? Color(hex: 0x007832) : Color(hex: 0x5BE584) }
    private var bad: Color { tone.dark ? Color(hex: 0xBE190F) : Color(hex: 0xFF8A80) }

    private func row(_ i: Int, _ s: Seg) -> some View {
        let d: Bool = i < idx
        let c: Bool = i == idx
        let sk: Bool = d && skipped.contains(i)
        let diff: Int? = (d && !sk && s.target > 0) ? mySplit(i) - s.target : nil
        let time: String = sk ? "Skipped".l10n : d ? Fm.t(mySplit(i)) : c ? Fm.t(segEl) : (s.target > 0 ? Fm.t(s.target) : "–")
        let curInk: Color = tone.dark ? C.accent : Color(hex: 0x1E78FA)
        let nameColor: Color = c ? curInk : d ? tone.sub : tone.ink
        let timeColor: Color = c ? curInk : d ? tone.ink : tone.sub
        return HStack(spacing: 10) {
            Text(s.name).font(F.t(L.v(16), c ? .bold : .semibold))
                .foregroundStyle(nameColor).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if let diff {
                Text(Fm.d(diff)).font(F.num(L.v(14), .semibold)).foregroundStyle(diff <= 0 ? good : bad)
            }
            Text(time).font(sk ? F.t(L.v(14), .medium) : F.num(L.v(16), .semibold))
                .foregroundStyle(sk ? tone.sub : timeColor).lineLimit(1).minimumScaleFactor(0.8)
                .frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: L.y(26))
        .background {
            if c {
                W8Glass(shape: Capsule(), fill: tone.dark ? Color.black.opacity(0.69) : Color.white.opacity(0.8), rim: 0.22)
            }
        }
    }
}
