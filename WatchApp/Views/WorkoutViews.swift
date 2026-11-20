import SwiftUI
import WatchKit

// MARK: - 1.2.7 운동 중 (대표님 11-20 확정 — 프로젝트 문서 splits8-1.2.7-수정목록.md 2·5번, -워치-넘김화면.md)
// 세로 페이지 (크라운) = 운동 화면 · 목표 대비 · 최고 심박/칼로리. 구간 목록 페이지는 뺌.
// 운동 화면에서 왼쪽으로 밀기 = 다음 구간, 오른쪽으로 밀기 = 조작 화면 (위에 덮임, 왼쪽으로 밀면 돌아옴).

struct WWorkoutPager: View {
    let engine = WorkoutEngine.shared
    @State private var page = WatchDemo.page
    @State private var controls = WatchDemo.controls
    @State private var endSheet = WatchDemo.shot == "end"
    @StateObject private var zoneHold = W8ZoneHold()

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                Group {
                    if engine.isNewKind {
                        WTimerLive(zone: zoneHold.shown, onControls: openControls)
                    } else {
                        WLive(zone: zoneHold.shown, onControls: openControls)
                    }
                }
                .tag(0)
                if engine.hasGoalTotal {
                    WGoalPage(zone: zoneHold.shown).tag(1)
                }
                WStatsPage(zone: zoneHold.shown).tag(2)
            }
            .tabViewStyle(.verticalPage)

            if controls {
                WControls(zone: zoneHold.shown,
                          onBack: closeControls,
                          onEnd: { endSheet = true },
                          onNext: {
                              withAnimation(WLive.slideCurve) { engine.advance() }
                              closeControls()
                          })
                    .transition(.move(edge: .leading))
                    .zIndex(1)
            }

            if endSheet {
                WEndSheet(onEnd: { endSheet = false; controls = false; engine.endNow() },
                          onDiscard: { endSheet = false; controls = false; engine.discardNow(); WNav.shared.screen = .home },
                          onResume: { endSheet = false })
                    .transition(.opacity)
                    .zIndex(2)
            }

            // 구간 전환: 흰 번쩍임 (약하게, 터치 막지 않음)
            if !aod {
                WSegmentFlash.color
                    .opacity(flash)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .zIndex(3)
            }
        }
        .ignoresSafeArea()
        .onChange(of: engine.advanceCount) { _, _ in
            if !engine.isRunKind { flashNow() }      // 러닝 카드는 1 km 마다 번쩍이지 않음
        }
        .task {
            // 심박 존 배경: 경계에서 오락가락해도 깜빡이지 않게 몇 초 머문 뒤 바꿈
            while !Task.isCancelled {
                zoneHold.update(raw: engine.hr > 0 ? engine.zone : 0)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    @Environment(\.isLuminanceReduced) private var aod
    @State private var flash: Double = 0

    private func openControls() {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { controls = true }
    }

    private func closeControls() {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.3)) { controls = false }
    }

    private func flashNow() {
        guard !aod else { return }
        withAnimation(.linear(duration: 0.06)) { flash = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.26)) { flash = 0 }
        }
    }
}

enum WSegmentFlash {
    /// 1.2.7: 노랑 → 흰 번쩍임 (약하게)
    static let color: Color = Color.white.opacity(0.32)
}

/// 심박 존 배경 색: Z4 · Z5 만 바뀜. 새 존이 3초 넘게 이어져야 바꿈
final class W8ZoneHold: ObservableObject {
    @Published private(set) var shown: Int = 0
    private var pending: Int = 0
    private var since: Int = 0

    func update(raw: Int) {
        let z: Int = raw >= 5 ? 5 : (raw == 4 ? 4 : 0)
        if z == shown { pending = z; since = 0; return }
        if z != pending { pending = z; since = 0 }
        since += 1
        if since >= 3 { shown = z; since = 0 }
    }
}

/// 운동 중 화면에서 같이 쓰는 것
enum W8 {
    /// 지금 구간 색
    static func tone(_ e: WorkoutEngine) -> W8Tone { W8Tone.of(e.cur) }
    /// 손목 내림 색
    static let aodText: Color = Color(hex: 0x96969B)
    static let aodMark: Color = Color(hex: 0x505055)
    static let aodDot: Color = Color(hex: 0x46464B)
}

/// 화면 높이별 크기 — 1.2.7 부터 46mm(208×248) 기준 비율로 모두 줄이고 늘림 (W8Scale). 예전 이름은 남겨 둠
struct WLiveMetrics {
    let s: CGFloat
    static var current: WLiveMetrics {
        let b = WKInterfaceDevice.current().screenBounds
        return WLiveMetrics(s: min(b.width / 208, b.height / 248))
    }
}

/// 오른쪽 위 시스템 시계가 차지하는 자리 (제목 줄에서 비워 둘 폭)
enum WClock {
    static let reserve: CGFloat = 58
}

// MARK: - 공통 조각

/// 맨 위 가운데 "TOTAL 23:41" (이름표 9 + 값 14). 시계와 겹치면 왼쪽으로 밀림
struct W8TotalRow: View {
    let L: W8Scale
    let label: String
    let value: String
    let tone: W8Tone
    let aod: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4 * L.s) {
            Text(label.l10n).font(F.t(9 * L.s, .bold)).tracking(0.8)
                .foregroundStyle(aod ? W8.aodText : tone.label)
            Text(verbatim: value).font(F.num(14 * L.s, .semibold))
                .foregroundStyle(aod ? W8.aodText : tone.ink)
        }
        .lineLimit(1)
        .fixedSize()
        .position(x: min(L.w / 2, L.w - (WClock.reserve + 12) * L.s - totalHalf), y: L.t(20))
    }

    /// 대략 폭의 반 (시계와 띄우기용): 이름표 9pt 글자 ≈ 6.2, 숫자 14pt ≈ 8.6, 사이 4
    private var totalHalf: CGFloat { (CGFloat(label.count) * 6.2 + CGFloat(value.count) * 8.6 + 4) / 2 * L.s }
}

/// 이름표 + 값 한 칸
struct W8Column: View {
    let L: W8Scale
    let label: String
    let value: String
    let tone: W8Tone
    let aod: Bool
    var valueSize: CGFloat = 22
    var strongLabel: Bool = false

    var body: some View {
        VStack(spacing: 3 * L.s) {
            Text(verbatim: label).font(F.t(10 * L.s, .bold)).tracking(0.6)
                .foregroundStyle(aod ? W8.aodText : (strongLabel ? tone.ink : tone.label))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: value).font(F.num(valueSize * L.s, .semibold))
                .foregroundStyle(aod ? W8.aodText : tone.ink)
                .lineLimit(1).minimumScaleFactor(0.55)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

/// 칸 줄 (시안: 칸 폭 = (208 − 28) / 개수, 가운데 x = 14 + 폭 × (i + ½)). 이름표 · 값은 대문자 가운데 y 로 놓음
struct W8ColsRow: View {
    let L: W8Scale
    /// (이름표, 값, 이름표 진하게)
    let cols: [(String, String, Bool)]
    let labelY: CGFloat
    let valueY: CGFloat
    var valueSize: CGFloat = 22
    let tone: W8Tone
    let aod: Bool

    var body: some View {
        let n: Int = max(1, cols.count)
        let cw: CGFloat = 180 * L.s / CGFloat(n)
        ZStack {
            ForEach(cols.indices, id: \.self) { i in
                let cx: CGFloat = L.x(14) + cw * (CGFloat(i) + 0.5)
                Text(verbatim: cols[i].0).font(F.t(10 * L.s, .bold)).tracking(0.6)
                    .foregroundStyle(aod ? W8.aodText : (cols[i].2 ? tone.ink : tone.label))
                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: cw - 2)
                    .position(x: cx, y: L.y(labelY))
                Text(verbatim: cols[i].1).font(F.num(valueSize * L.s, .semibold))
                    .foregroundStyle(aod ? W8.aodText : tone.ink)
                    .lineLimit(1).minimumScaleFactor(0.55).frame(width: cw - 2)
                    .contentTransition(.numericText())
                    .position(x: cx, y: L.y(valueY))
            }
        }
        .w8Shadow(tone, L, aod)
    }
}

/// 진행 점: 지난 것 · 지금 막대(12) · 남은 것
struct W8Dots: View {
    let L: W8Scale
    let total: Int
    let current: Int        // 0부터. total 이면 다 끝남
    var currentDim: Bool = false
    let tone: W8Tone
    let aod: Bool

    var body: some View {
        let d: CGFloat = 3.6 * L.s
        let bar: CGFloat = 12 * L.s
        let gapBase: CGFloat = total <= 10 ? 10 : 7
        let maxGap: CGFloat = total > 1 ? (168 - 12) / CGFloat(total - 1) : gapBase
        let gap: CGFloat = min(gapBase, maxGap) * L.s
        HStack(spacing: max(1, gap - d)) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                if i == current {
                    Capsule().fill(color(i)).opacity(currentDim ? 0.5 : 1)
                        .frame(width: bar, height: d)
                } else {
                    Circle().fill(color(i)).frame(width: d, height: d)
                }
            }
        }
    }

    private func color(_ i: Int) -> Color {
        if aod { return i <= current ? W8.aodText : W8.aodDot }
        return i <= current ? tone.ink : tone.dotOff
    }
}

/// 유리 동그라미 버튼 (되돌리기 · 다음 · 일시정지)
struct W8CircleButton<Label: View>: View {
    let L: W8Scale
    let r: CGFloat
    let tone: W8Tone
    let aod: Bool
    var main: Bool = false
    var on: Bool = true
    let id: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            ZStack {
                if aod {
                    Circle().strokeBorder(W8.aodMark, lineWidth: 1.5)
                } else if main {
                    // 가운데: 노랑 위 = 어두운 유리, 파랑 · 회색 위 = 흰 유리
                    W8Glass(shape: Circle(), fill: tone.dark ? Color.black.opacity(0.69) : Color.white.opacity(0.8), rim: 0.22)
                } else {
                    W8Glass(shape: Circle(), fill: Color.white.opacity(tone.glass), rim: 0.59)
                }
                label().opacity(on ? 1 : 0.35)
            }
            .frame(width: r * 2 * L.s, height: r * 2 * L.s)
            .contentShape(Circle())
        }
        .buttonStyle(W8Press())
        .disabled(!on || aod)
        .accessibilityIdentifier(id)
    }
}

extension View {
    /// 글자 밑 그림자 (7pt 흐림 · 아래 2pt)
    func w8Shadow(_ tone: W8Tone, _ L: W8Scale, _ aod: Bool) -> some View {
        shadow(color: aod ? .clear : tone.shadow, radius: 3.5 * L.s, x: 0, y: 2 * L.s)
    }
}

// MARK: - 운동 화면 (구간 · 러닝 카드)

struct WLive: View {
    let engine = WorkoutEngine.shared
    var zone: Int = 0
    let onControls: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    /// 220ms, cubic-bezier(0.32, 0.72, 0, 1)
    static let slideCurve: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.22)

    /// 아래 블록만 밀림: 나가는 쪽은 왼쪽, 들어오는 쪽은 오른쪽에서
    private var slide: AnyTransition {
        .asymmetric(insertion: .offset(x: 66).combined(with: .opacity),
                    removal: .offset(x: -180).combined(with: .opacity))
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                screen(now: ctx.date, L: W8Scale(w: geo.size.width, h: geo.size.height))
            }
        }
        .ignoresSafeArea()
    }

    private var tone: W8Tone { engine.isRunKind ? .run : W8.tone(engine) }

    private func screen(now: Date, L: W8Scale) -> some View {
        ZStack {
            W8Background(tone: tone, zone: zone, seed: engine.isRunKind ? 1 : engine.idx, dim: aod)
            W8TotalRow(L: L, label: engine.isRunKind ? "TIME" : "TOTAL", value: Fm.t(engine.total(now)), tone: tone, aod: aod)
            Group {
                if engine.isRunKind { runCard(now: now, L: L) } else { segment(now: now, L: L) }
            }
            .id(engine.isRunKind ? 0 : engine.idx)
            .transition(slide)
            buttons(L: L)
        }
        .frame(width: L.w, height: L.h)
        .contentShape(Rectangle())
        .gesture(swipe)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20).onEnded { v in
            let dx = v.translation.width
            guard abs(dx) >= 40, abs(dx) > abs(v.translation.height) else { return }
            if dx < 0 { if !engine.isRunKind { next() } } else { onControls() }
        }
    }

    private func next() {
        withAnimation(WLive.slideCurve) { engine.advance() }
    }

    // MARK: 구간 화면

    private func segment(now: Date, L: W8Scale) -> some View {
        let cur: Seg = engine.cur
        let el: Int = engine.segEl(now)
        let ink: Color = aod ? W8.aodText : tone.ink
        let sub: Color = aod ? W8.aodText : tone.sub
        let info: String = infoLine(cur)
        return ZStack {
            // 귀퉁이 표시 32 ~ 86
            W8Brackets(arm: 9 * L.s)
                .stroke(aod ? W8.aodMark : tone.mark, style: StrokeStyle(lineWidth: 2.6 * L.s, lineCap: .round, lineJoin: .round))
                .frame(width: L.v(176), height: L.v(54))
                .position(x: L.x(104), y: L.y(59))
            // 이름 27 (길면 16 까지) + 무게 · 거리 15 — 대문자 높이로 재서 귀퉁이 표시(32~86) 가운데에, 사이 9.5
            Text(verbatim: cur.name).font(F.t(27 * L.s, .bold)).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(16 / 27)
                .frame(width: L.v(168))
                .w8Shadow(tone, L, aod)
                .position(x: L.x(104), y: L.y(info.isEmpty ? 59 : 49))
            if !info.isEmpty {
                Text(verbatim: info).font(F.t(15 * L.s, .semibold)).foregroundStyle(sub)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: L.v(168))
                    .w8Shadow(tone, L, aod)
                    .position(x: L.x(104), y: L.y(73.3))
            }
            // 칸: 이름표 대문자 가운데 100 · 값 120.3
            W8ColsRow(L: L, cols: columns(cur: cur, el: el).map { ($0.label, $0.value, $0.strong) },
                      labelY: 100, valueY: 120.3, tone: tone, aod: aod)
            // 진행 점 (HIIT 는 "3 rounds done")
            if engine.isHIIT {
                Text(String(format: "%lld rounds done".l10n, engine.idx))
                    .font(F.t(11 * L.s, .bold)).foregroundStyle(sub)
                    .position(x: L.x(104), y: L.y(146))
            } else {
                dots(L: L)
                    .position(x: L.x(104), y: L.y(146))
            }
            // Next
            nextLine(L: L)
                .w8Shadow(tone, L, aod)
                .position(x: L.x(104), y: L.y(169.3))
        }
    }

    private struct Col { let label: String; let value: String; var strong: Bool = false }

    /// SPLIT · GOAL(BEST) · ♥ BPM / 러닝 구간 SPLIT · PACE · ♥ BPM / 휴식 SPLIT · ♥ BPM
    private func columns(cur: Seg, el: Int) -> [Col] {
        var out: [Col] = []
        let over: Int = cur.target > 0 && cur.kind != .rox ? el - cur.target : 0
        if over > 0 {
            out.append(Col(label: "OVER".l10n + " +" + Fm.t(over), value: Fm.t(el), strong: true))
        } else {
            out.append(Col(label: (engine.isHIIT ? "ROUND" : "SPLIT").l10n, value: Fm.t(el)))
        }
        if cur.icon == "run" {
            let imp: Bool = engine.settings.imperial
            out.append(Col(label: (imp ? "PACE /MI" : "PACE").l10n,
                           value: engine.paceText(el: el, dist: engine.segDist, imperial: imp) ?? "--"))
        } else if cur.target > 0 && cur.icon != "rest" {
            out.append(Col(label: (engine.mode == .training || engine.isHIIT ? "BEST" : "GOAL").l10n, value: Fm.t(cur.target)))
        }
        out.append(Col(label: "♥ " + "BPM".l10n, value: engine.hr > 0 ? String(Int(engine.hr.rounded())) : "--"))
        return out
    }

    /// 귀퉁이 표시 안 둘째 줄: 무게 · 거리 / 더블 교대 / 러닝 거리 / 휴식은 "to 다음 종목"
    private func infoLine(_ cur: Seg) -> String {
        if cur.icon == "rest" {
            guard !isLast else { return "" }
            return String(format: "to %@".l10n, nextSeg.name)
        }
        if cur.kind == .rox { return "Transition".l10n }
        if cur.icon == "run" {
            let imp: Bool = engine.settings.imperial
            let segM: Double = runMeters(cur.detail)
            guard segM > 0 else { return "" }
            return Units.dist(min(segM, engine.segDist), imp) + " / " + Units.dist(segM, imp) + (imp ? " mi" : " km")
        }
        if engine.mode != .training,
           let d = doublesLine(for: cur, plan: WatchStore.shared.ctx.doublesPlan, division: engine.settings.division) { return d }
        if engine.isHIIT { return "" }
        return cur.detail.isEmpty ? "" : Units.detail(cur.detail, engine.settings.imperial)
    }

    /// 점: Roxzone 이 있으면 Roxzone 은 빼고 셈 (Roxzone 중에는 다음 것을 흐린 막대로)
    private func dots(L: W8Scale) -> some View {
        let units: [Int] = engine.seq.indices.filter { engine.seq[$0].kind != .rox || engine.seq[$0].icon == "rest" }
        let n: Int = units.count
        let before: Int = units.filter { $0 < engine.idx }.count
        let onRox: Bool = engine.cur.kind == .rox && engine.cur.icon != "rest"
        return W8Dots(L: L, total: n, current: before, currentDim: onRox, tone: tone, aod: aod)
    }

    private var isLast: Bool { engine.idx >= engine.seq.count - 1 && !engine.growsOpen }

    /// 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km)
    private var nextSeg: Seg {
        if engine.growsOpen && engine.idx >= engine.seq.count - 1 {
            let n: Int = engine.seq.count + 1
            return engine.isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
        }
        return engine.next
    }

    private func nextLine(L: W8Scale) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9 * L.s) {
            Text("Next").font(F.t(17 * L.s, .semibold))
                .foregroundStyle(aod ? W8.aodText : tone.sub)
            Text(verbatim: isLast ? "Finish".l10n : nextSeg.name).font(F.t(17 * L.s, .bold))
                .foregroundStyle(aod ? W8.aodText : tone.ink)
                .lineLimit(1).minimumScaleFactor(12 / 17)
        }
        .frame(maxWidth: L.v(172))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("w.nextName")
    }

    // MARK: 러닝 카드 (Run 3K/5K/10K/21K · Free run)

    private func runCard(now: Date, L: W8Scale) -> some View {
        let imp: Bool = engine.settings.imperial
        let d: Double = engine.runDistance
        let total: Int = engine.total(now)
        let ink: Color = aod ? W8.aodText : tone.ink
        let sub: Color = aod ? W8.aodText : tone.sub
        let goalM: Double = Double(engine.runGoalKm) * 1000
        return ZStack {
            W8Brackets(arm: 9 * L.s)
                .stroke(aod ? W8.aodMark : tone.mark, style: StrokeStyle(lineWidth: 2.6 * L.s, lineCap: .round, lineJoin: .round))
                .frame(width: L.v(176), height: L.v(66))
                .position(x: L.x(104), y: L.y(65))
            // 시안: 이름 13 (39.4) · 거리 40 (68.4) · KM 10 (91.6) — 대문자 가운데
            Text(verbatim: engine.title.isEmpty ? "Run".l10n : engine.title).font(F.t(13 * L.s, .bold)).foregroundStyle(sub)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: L.v(160))
                .w8Shadow(tone, L, aod)
                .position(x: L.x(104), y: L.y(39.4))
            Text(verbatim: Units.dist(d, imp)).font(F.num(40 * L.s, .bold)).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .w8Shadow(tone, L, aod)
                .position(x: L.x(104), y: L.y(68.4))
            Text(imp ? "MI" : "KM").font(F.t(10 * L.s, .bold)).tracking(0.8).foregroundStyle(aod ? W8.aodText : tone.label)
                .position(x: L.x(104), y: L.y(91.6))
            W8ColsRow(L: L, cols: [((imp ? "PACE /MI" : "PACE").l10n, engine.paceText(el: total, dist: d, imperial: imp) ?? "--", false),
                                   ("♥ " + "BPM".l10n, engine.hr > 0 ? String(Int(engine.hr.rounded())) : "--", false)],
                      labelY: 109, valueY: 129, tone: tone, aod: aod)
            // 진행 막대 (좌우 40 안쪽, 굵기 4)
            W8RunBar(L: L, frac: goalM > 0 ? min(1, d / goalM) : nil, tone: tone, aod: aod)
                .frame(width: L.v(128), height: 4 * L.s)
                .position(x: L.x(104), y: L.y(150))
            Text(verbatim: runSummary(d: d, total: total)).font(F.num(15 * L.s, .semibold)).foregroundStyle(sub)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: L.v(172))
                .w8Shadow(tone, L, aod)
                .position(x: L.x(104), y: L.y(169))
        }
    }

    /// "Goal 5 km · Avg 5:14" (Free run 은 Avg 만)
    private func runSummary(d: Double, total: Int) -> String {
        let imp: Bool = engine.settings.imperial
        var parts: [String] = []
        if engine.runGoalKm > 0 {
            parts.append(String(format: (imp ? "Goal %@ mi" : "Goal %@ km").l10n,
                                imp ? Units.dist(Double(engine.runGoalKm) * 1000, true) : String(engine.runGoalKm)))
        }
        if d >= 200 {
            let avg: Int = Units.pace(Int((Double(total) / d * 1000).rounded()), imp)
            if avg > 0 && avg < 3600 { parts.append(String(format: "Avg %@".l10n, Fm.t(avg))) }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 버튼 (모든 운동 같은 자리: 옆 r18 ±54, 가운데 r25, 중심 y = 아래에서 32)

    private func buttons(L: W8Scale) -> some View {
        let cy: CGFloat = L.h - 32 * L.s
        let ic: Color = aod ? W8.aodText : tone.ink
        let mainIc: Color = aod ? W8.aodText : (tone.dark ? C.accent : Color(hex: 0x1E78FA))
        return ZStack {
            if engine.isRunKind {
                // 러닝 카드: 가운데 큰 일시정지 하나
                W8CircleButton(L: L, r: 25, tone: tone, aod: aod, main: true, id: "w.pauseLive", action: { engine.togglePause() }) {
                    W8PauseIcon(size: 18 * L.s, color: mainIc, paused: !engine.running)
                }
                .position(x: L.w / 2, y: cy)
            } else {
                W8CircleButton(L: L, r: 18, tone: tone, aod: aod, on: engine.canUndo, id: "w.undoLive",
                               action: { withAnimation(WLive.slideCurve) { engine.undo() } }) {
                    W8UndoIcon(size: 19 * L.s, color: ic)
                }
                .position(x: L.w / 2 - 54 * L.s, y: cy)
                W8CircleButton(L: L, r: 25, tone: tone, aod: aod, main: true, id: "w.next", action: next) {
                    if isLast {
                        Image(systemName: "checkmark").font(.system(size: 20 * L.s, weight: .heavy)).foregroundStyle(mainIc)
                    } else {
                        W8NextArrow().fill(mainIc).frame(width: 20 * L.s, height: 17 * L.s)
                    }
                }
                .accessibilityLabel(Text(isLast ? "Finish" : "Next"))
                .position(x: L.w / 2, y: cy)
                W8CircleButton(L: L, r: 18, tone: tone, aod: aod, id: "w.pauseLive", action: { engine.togglePause() }) {
                    W8PauseIcon(size: 14 * L.s, color: ic, paused: !engine.running)
                }
                .position(x: L.w / 2 + 54 * L.s, y: cy)
            }
        }
    }
}

/// 러닝 카드 진행 막대: 목표 있으면 0 → 목표, Free run 은 흰 둥근 막대가 왔다 갔다
struct W8RunBar: View {
    let L: W8Scale
    let frac: Double?
    let tone: W8Tone
    let aod: Bool
    @State private var swing = false

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(aod ? W8.aodDot : Color.black.opacity(0.35))
                if let f = frac {
                    Capsule().fill(aod ? W8.aodText : Color.white).frame(width: max(g.size.height, g.size.width * f))
                } else if !aod {
                    Capsule().fill(Color.white).frame(width: g.size.width * 0.28)
                        .offset(x: swing ? g.size.width * 0.72 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { swing = true }
                        }
                }
            }
        }
    }
}

// MARK: - 크라운 ↓ 1칸: 목표 대비 (아래 칸 누르면 위 큰 숫자와 자리 바꿈 · 기억)

/// 크라운 칸 공통 틀: 귀퉁이 표시 안 [이름표 · 큰 숫자 · 작은 말] + 아래 두 칸
struct W8InfoFrame: View {
    struct Item: Equatable { let key: String; let label: String; let value: String; let word: String }

    let big: Item
    let left: Item
    let right: Item
    let zone: Int
    let onTap: (String) -> Void
    let onTapBig: () -> Void
    let engine = WorkoutEngine.shared
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        GeometryReader { geo in
            let L = W8Scale(w: geo.size.width, h: geo.size.height)
            let tone: W8Tone = engine.isRunKind ? .run : W8.tone(engine)
            ZStack {
                W8Background(tone: tone, zone: zone, seed: engine.isRunKind ? 1 : engine.idx, dim: aod)
                W8TotalRow(L: L, label: engine.isRunKind ? "TIME" : "TOTAL", value: Fm.t(engine.total(Date())), tone: tone, aod: aod)
                // 시안: [이름표 12 → 9 → 숫자 44 → 9 → 말 11] 안쪽 위아래 11 → 14 → 두 칸 (10 → 6 → 19). 위 줄 아래(30) ~ 아래 16 의 가운데
                W8Stack(L: L, parts: [
                    .block(label: big.label, value: big.value, word: big.word.isEmpty ? nil : big.word,
                           color: aod ? W8.aodText : tone.ink, labelSize: 12, valueSize: 44, wordSize: 11, inner: 9, pad: 11, onTap: onTapBig),
                    .cols([(left.label, left.value), (right.label, right.value)], labelSize: 10, valueSize: 19, inner: 6, gap: 14,
                          onTap: { i in onTap(i == 0 ? left.key : right.key) })
                ], top: L.t(30), bottom: L.b(16),
                ink: aod ? W8.aodText : tone.ink, label: aod ? W8.aodText : tone.label,
                word: aod ? W8.aodText : tone.sub, mark: aod ? W8.aodMark : tone.mark,
                shadow: aod ? .clear : tone.shadow)
            }
            .frame(width: L.w, height: L.h)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: big)
    }

    private func cell(_ it: Item, L: W8Scale, tone: W8Tone) -> some View {
        Button { onTap(it.key) } label: {
            VStack(spacing: 3 * L.s) {
                Text(it.label.l10n).font(F.t(10 * L.s, .bold)).tracking(0.6)
                    .foregroundStyle(aod ? W8.aodText : tone.label)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(verbatim: it.value).font(F.num(19 * L.s, .semibold))
                    .foregroundStyle(aod ? W8.aodText : tone.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WGoalPage: View {
    let engine = WorkoutEngine.shared
    var zone: Int = 0
    @AppStorage("w8.goalBig") private var bigKey: String = "vs"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let items: [W8InfoFrame.Item] = make(ctx.date)
            let big: W8InfoFrame.Item = items.first { $0.key == bigKey } ?? items[0]
            let rest: [W8InfoFrame.Item] = items.filter { $0.key != big.key }
            W8InfoFrame(big: big, left: rest[0], right: rest[1], zone: zone,
                        onTap: { k in WKInterfaceDevice.current().play(.click); bigKey = k },
                        onTapBig: { if bigKey != "vs" { WKInterfaceDevice.current().play(.click); bigKey = "vs" } })
        }
        .accessibilityIdentifier("w.goalPage")
    }

    private func make(_ now: Date) -> [W8InfoFrame.Item] {
        let d: Int = engine.delta(now)
        let vsBest: Bool = engine.mode == .training || engine.mode == .pft
        let word: String = d < 0 ? "AHEAD" : (d > 0 ? "BEHIND" : "ON PACE")
        return [
            .init(key: "vs", label: vsBest ? "VS BEST" : "VS GOAL", value: Fm.d(d), word: word),
            .init(key: "finish", label: "FINISH", value: Fm.t(engine.projectedFinish(now)), word: "EST"),
            .init(key: "goal", label: vsBest ? "BEST" : "GOAL", value: Fm.t(engine.targetTotal), word: ""),
        ]
    }
}

// MARK: - 크라운 ↓ 2칸: 최고 심박 · 칼로리 · (러닝) 케이던스 / (그 외) 평균 심박

struct WStatsPage: View {
    let engine = WorkoutEngine.shared
    var zone: Int = 0
    @AppStorage("w8.statBig") private var bigKey: String = "max"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let items: [W8InfoFrame.Item] = make(ctx.date)
            let big: W8InfoFrame.Item = items.first { $0.key == bigKey } ?? items[0]
            let rest: [W8InfoFrame.Item] = items.filter { $0.key != big.key }
            W8InfoFrame(big: big, left: rest[0], right: rest[1], zone: zone,
                        onTap: { k in WKInterfaceDevice.current().play(.click); bigKey = k },
                        onTapBig: { if bigKey != "max" { WKInterfaceDevice.current().play(.click); bigKey = "max" } })
        }
        .accessibilityIdentifier("w.statsPage")
    }

    private var runs: Bool { engine.isRunKind || engine.runLike || engine.cur.icon == "run" }

    private func make(_ now: Date) -> [W8InfoFrame.Item] {
        let mx: Int = engine.maxHRNow
        let kcal: Int = Int(engine.kcal.rounded())
        var out: [W8InfoFrame.Item] = [
            .init(key: "max", label: "MAX HR", value: mx > 0 ? "\(mx)" : "--", word: "BPM"),
            .init(key: "kcal", label: "ENERGY", value: "\(kcal)", word: "KCAL"),
        ]
        if runs {
            out.append(.init(key: "third", label: "CADENCE", value: engine.cadenceNow(now).map { "\($0)" } ?? "--", word: "SPM"))
        } else {
            let a: Int = engine.avgHRLive
            out.append(.init(key: "third", label: "AVG BPM", value: a > 0 ? "\(a)" : "--", word: "BPM"))
        }
        return out
    }
}

// MARK: - 조작 화면 (오른쪽으로 밀기)

struct WControls: View {
    let engine = WorkoutEngine.shared
    var zone: Int = 0
    let onBack: () -> Void
    let onEnd: () -> Void
    let onNext: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                screen(now: ctx.date, L: W8Scale(w: geo.size.width, h: geo.size.height))
            }
        }
        .ignoresSafeArea()
    }

    private var tone: W8Tone { engine.isRunKind ? .run : W8.tone(engine) }

    private func screen(now: Date, L: W8Scale) -> some View {
        let h: CGFloat = 34 * L.s
        let gap: CGFloat = 7 * L.s
        // 시안: 버튼 4줄은 위 줄 아래(32) ~ 안내 글 위 10 의 가운데, 안내 글 아래 끝은 화면 아래 16
        let top: CGFloat = L.t(32)
        let bottom: CGFloat = L.b(36.5)
        return ZStack {
            W8Background(tone: tone, zone: zone, seed: engine.isRunKind ? 1 : engine.idx, dim: aod, darker: 0.12)
            W8TotalRow(L: L, label: engine.isRunKind ? "TIME" : "TOTAL", value: Fm.t(engine.total(now)), tone: tone, aod: aod)
            VStack(spacing: gap) {
                pill(L: L, h: h, title: "End", fill: Color(hex: 0xFF3B30).opacity(0.59), rim: 0.22, fg: .white, id: "w.end", action: onEnd) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15 * L.s, weight: .semibold))
                }
                pill(L: L, h: h, title: engine.running ? "Pause" : "Resume", fill: Color.white.opacity(tone.glass), rim: 0.59,
                     fg: tone.ink, id: "w.pause", action: { engine.togglePause() }) {
                    W8PauseIcon(size: 12 * L.s, color: tone.ink, paused: !engine.running)
                }
                HStack(spacing: gap) {
                    pill(L: L, h: h, title: "Undo", fill: Color.white.opacity(tone.glass), rim: 0.59, fg: tone.ink,
                         on: engine.canUndo && !engine.isRunKind, id: "w.undo", action: {
                             withAnimation(WLive.slideCurve) { engine.undo() }
                             onBack()
                         }) {
                        W8UndoIcon(size: 14 * L.s, color: tone.ink)
                    }
                    pill(L: L, h: h, title: "Skip", fill: Color.white.opacity(tone.glass), rim: 0.59, fg: tone.ink,
                         on: engine.canSkip, id: "w.skip", action: {
                             withAnimation(WLive.slideCurve) { engine.skip() }
                             onBack()
                         }) {
                        Image(systemName: "forward.end.fill").font(.system(size: 12 * L.s, weight: .bold))
                    }
                }
                pill(L: L, h: h, title: "Next", fill: tone.dark ? Color.black.opacity(0.69) : Color.white.opacity(0.8), rim: 0.22,
                     fg: tone.dark ? C.accent : Color(hex: 0x1E78FA), on: !engine.isRunKind, id: "w.controlsNext", action: onNext) {
                    W8NextArrow().frame(width: 13 * L.s, height: 11 * L.s)
                }
            }
            .padding(.horizontal, 16 * L.s)
            .position(x: L.w / 2, y: (top + bottom) / 2)
            Text("‹ Swipe left to go back")
                .font(F.t(11 * L.s, .semibold)).foregroundStyle(tone.label)
                .lineLimit(1).minimumScaleFactor(0.8)
                .position(x: L.w / 2, y: L.b(23))
        }
        .frame(width: L.w, height: L.h)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            if v.translation.width <= -40 && abs(v.translation.width) > abs(v.translation.height) { onBack() }
        })
    }

    private func pill<I: View>(L: W8Scale, h: CGFloat, title: String, fill: Color, rim: Double, fg: Color, on: Bool = true,
                               id: String, action: @escaping () -> Void, @ViewBuilder icon: () -> I) -> some View {
        Button(action: action) {
            HStack(spacing: 5 * L.s) {
                icon()
                Text(title.l10n).font(F.t(15 * L.s, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(fg)
            .opacity(on ? 1 : 0.4)
            .frame(maxWidth: .infinity).frame(height: h)
            .background(W8Glass(shape: Capsule(), fill: fill, rim: rim))
            .contentShape(Capsule())
        }
        .buttonStyle(W8Press())
        .disabled(!on)
        .accessibilityIdentifier(id)
    }
}

// MARK: - End 확인 (제목 가운데 → 귀퉁이 표시 블록 → Save & end / Discard | Resume)

struct WEndSheet: View {
    let engine = WorkoutEngine.shared
    let onEnd: () -> Void
    let onDiscard: () -> Void
    let onResume: () -> Void
    /// 버리기를 한 번 눌렀음 → 한 번 더 묻는 화면
    @State private var askDiscard = false

    /// 1.2.7 시안: 제목 41 · 블록은 52 ~ 윗 버튼(150) 위 2 의 가운데 · 버튼 40 두 줄 (150 ~ 190 / 196 ~ 236)
    var body: some View {
        W8Canvas { L in
            ZStack {
                W8MenuBackground(seed: 61)
                W8TitleAt(L: L, title: askDiscard ? "Discard this workout?" : "End workout?")
                W8Stack(L: L, parts: [block], top: L.t(52), bottom: L.btnY(1) - L.btnH / 2 - 2 * L.s)
                buttons(L)
            }
        }
    }

    private var doneCount: Int { engine.seq.prefix(engine.idx).filter { $0.kind != .rox }.count }
    private var allCount: Int { engine.seq.filter { $0.kind != .rox }.count }

    private var block: W8Part {
        if askDiscard {
            return .block(label: "TOTAL", value: Fm.t(engine.total(Date())), word: "NOTHING WILL BE SAVED", color: Color(hex: 0xFF6B60))
        }
        if engine.growsOpen || engine.isNewKind {
            return .block(label: "TOTAL", value: Fm.t(engine.total(Date())), word: "EVERYTHING WILL BE SAVED")
        }
        return .block(label: "SEGMENTS DONE", value: "\(doneCount) / \(allCount)",
                      word: doneCount < allCount ? "REST WON'T BE SAVED" : nil)
    }

    @ViewBuilder private func buttons(_ L: W8Scale) -> some View {
        if askDiscard {
            W8GlassButton(title: "Discard", red: true, height: L.btnH, action: onDiscard)
                .frame(width: L.btnW).position(x: L.cx, y: L.btnY(1))
                .accessibilityIdentifier("w.discardConfirm")
            W8GlassButton(title: "Cancel", height: L.btnH) {
                withAnimation(.easeOut(duration: 0.15)) { askDiscard = false }
            }
            .frame(width: L.btnW).position(x: L.cx, y: L.btnY(0))
        } else {
            W8PrimaryButton(title: "Save & end", height: L.btnH, action: onEnd)
                .frame(width: L.btnW).position(x: L.cx, y: L.btnY(1))
                .accessibilityIdentifier("w.endConfirm")
            W8GlassButton(title: "Discard", red: true, height: L.btnH) {
                WKInterfaceDevice.current().play(.click)
                withAnimation(.easeOut(duration: 0.15)) { askDiscard = true }
            }
            .frame(width: L.halfW).position(x: L.cx - (L.halfW + 6 * L.s) / 2, y: L.btnY(0))
            .accessibilityIdentifier("w.discard")
            W8GlassButton(title: "Resume", height: L.btnH, action: onResume)
                .frame(width: L.halfW).position(x: L.cx + (L.halfW + 6 * L.s) / 2, y: L.btnY(0))
                .accessibilityIdentifier("w.resume")
        }
    }
}

// MARK: - 끝난 뒤 결과

struct WSummary: View {
    let engine = WorkoutEngine.shared

    /// 1.2.7 시안: 첫 화면 = 제목(모드, 41) · [응원 → TOTAL 블록 → 등수] 가운데 · Done 은 아래 큰 버튼 자리.
    /// 아래로 내리면 AVG · MAX · KCAL · 구간 기록 (지금처럼)
    var body: some View {
        W8Canvas { L in
            ZStack {
                W8MenuBackground(seed: 62)
                ScrollView {
                    VStack(spacing: 12 * L.s) {
                        first(L)
                            .frame(width: L.w, height: L.h)
                        if let r = engine.lastRecord {
                            stats(r).padding(.horizontal, 12 * L.s)
                            rows(r).padding(.horizontal, 12 * L.s)
                            Color.clear.frame(height: 16 * L.s)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func first(_ L: W8Scale) -> some View {
        ZStack {
            W8TitleAt(L: L, title: engine.lastRecord.map { $0.mode == .training ? $0.title : $0.mode.name } ?? "")
            if let r = engine.lastRecord {
                W8Stack(L: L, parts: parts(r, L), top: L.t(52), bottom: L.btnTop)
            }
            W8PrimaryButton(title: "Done", height: L.btnH) {
                engine.reset()
                WNav.shared.screen = .home
            }
            .frame(width: L.btnW)
            .position(x: L.cx, y: L.btnY())
            .accessibilityIdentifier("w.done")
        }
    }

    private func parts(_ r: Record, _ L: W8Scale) -> [W8Part] {
        let tg: Int = r.vsTarget ?? r.total
        var p: [W8Part] = [
            .view(height: 20, AnyView(
                Text(cheer(r).line).font(F.t(13 * L.s, .semibold)).foregroundStyle(C.accent)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.horizontal, 14 * L.s)
                    .accessibilityIdentifier("w.cheer"))),
            .block(label: "TOTAL", value: Fm.t(r.total),
                   word: r.vsTarget != nil ? Fm.d(r.total - tg) + " " + r.vsWord.l10n : nil, gap: 10)
        ]
        if let g = r.pftGrade {
            p.append(.view(height: 22, gap: 10, AnyView(PFTBadge(grade: g, width: 78 * L.s, height: 22 * L.s, fontSize: 12 * L.s))))
        }
        if let k = r.kindSummary {
            p.append(.text(k, size: 13, weight: .semibold, color: C.accent, gap: 12))
        }
        if r.mode == .race || r.mode == .sim, r.splits16 != nil, let rk = HyroxRank.of(division: r.division, total: r.total) {
            p.append(.text(rk.pct.map { String(format: "About top %d%%".l10n, $0) } ?? rk.level.l10n, size: 13, weight: .semibold,
                           color: C.accent, gap: 12))
        }
        return p
    }

    /// 워치가 아는 것: 내 최고 Full Sim · 최고 PFT · 레이스 목표 · 대회 날짜 · 심박
    private func cheer(_ r: Record) -> Cheer {
        let ctx = WatchStore.shared.ctx
        var x = CheerInput(mode: r.mode, title: r.title, total: r.total, complete: r.isComplete,
                           check: r.flag == .check, start: r.date, end: r.end, seed: CheerPicker.seed(r.id))
        x.isHIIT = r.isHIIT
        x.isRun = r.isRunKind
        x.hiitRounds = r.isHIIT ? r.segs.count : 0
        x.runKm = r.runs.map { $0.dist ?? runMeters($0.detail) }.reduce(0, +) / 1000
        x.hiShare = CheerPicker.hiShare(r.hr, settings: ctx.settings)
        if r.mode == .race, let g = r.goal ?? r.vsTarget { x.goalDelta = r.total - g }
        if r.mode == .sim, let b = ctx.simBestTotal, r.total < b, r.counts { x.pbDelta = r.total - b }
        if r.mode == .sim && ctx.simBestTotal == nil && r.splits16 != nil { x.firstFullSim = true }
        if r.mode == .pft {
            x.pftPrevBest = ctx.pftBestTotal ?? ctx.pftBest.map { $0.reduce(0, +) }
            x.pftEverGold = (x.pftPrevBest ?? .max) < PFT.goldLimit
        }
        let ev = ctx.settings.event
        if ev.isSet {
            let cal = Calendar.current
            let d = cal.dateComponents([.day], from: cal.startOfDay(for: r.date), to: cal.startOfDay(for: ev.date)).day ?? -1
            if d >= 0 { x.daysToRace = d }
        }
        return CheerPicker.pick(x)
    }

    private func stats(_ r: Record) -> some View {
        HStack(spacing: 4) {
            stat("AVG", r.avgHR > 0 ? "\(r.avgHR)" : "--")
            stat("MAX", r.maxHR > 0 ? "\(r.maxHR)" : "--")
            stat("KCAL", r.kcal.formatted(.number.grouping(.automatic)))
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(W8Glass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), fill: Color.white.opacity(0.1), rim: 0.35))
    }

    private func rows(_ r: Record) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(r.segs.filter { $0.kind != .rox && $0.tag != "rest" }.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 7) {
                    Icon8(s.icon, 12, tint: .yellow)
                    Text(s.name).font(F.t(13)).lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Text(Fm.t(s.time)).font(F.num(13, .medium)).lineLimit(1).minimumScaleFactor(0.85)
                }
                .padding(.vertical, 4).padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 4)
        .background(W8Glass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), fill: Color.white.opacity(0.1), rim: 0.35))
    }

    private var doneButton: some View {
        W8PrimaryButton(title: "Done") {
            engine.reset()
            WNav.shared.screen = .home
        }
        .accessibilityIdentifier("w.done")
    }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l.l10n).font(F.t(11, .semibold)).tracking(0.6).foregroundStyle(C.text2)
            Text(v).font(F.num(15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
