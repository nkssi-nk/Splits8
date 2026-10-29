import SwiftUI
import WatchKit

/// 운동 중: 세로 페이지 (크라운) = Live · Controls · Segments
/// Live 에서 왼쪽 스와이프·더블탭·NEXT = 다음 구간, 오른쪽 스와이프 = Controls, Controls 에서 왼쪽 스와이프 = Live
struct WWorkoutPager: View {
    let engine = WorkoutEngine.shared
    @State private var page = WatchDemo.page
    @State private var endSheet = WatchDemo.shot == "end"

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                Group {
                    // 18번: 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성은 큰 타이머 화면
                    if engine.isNewKind {
                        WTimerLive(onControls: { withAnimation { page = 1 } })
                    } else {
                        WLive(onControls: { withAnimation { page = 1 } })
                    }
                }
                .tag(0)
                WControls(onBack: { withAnimation { page = 0 } },
                          onEnd: { endSheet = true },
                          onNext: {
                              withAnimation(WLive.slideCurve) { engine.advance() }
                              withAnimation { page = 0 }
                          }).tag(1)
                WSegmentList().tag(2)
            }
            .tabViewStyle(.verticalPage)

            if endSheet {
                WEndSheet(onEnd: { endSheet = false; engine.endNow() },
                          onDiscard: { endSheet = false; engine.discardNow(); WNav.shared.screen = .home },
                          onResume: { endSheet = false })
                    .transition(.opacity)
            }

            // 구간 전환 플래시: 화면 전체 노랑 rgba(255,236,80,0.42), 60ms 켜짐 → 260ms 사라짐 (터치 막지 않음)
            if !aod {
                WSegmentFlash.color
                    .opacity(flash)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        // 오른쪽 위 시스템 시계는 앱에서 숨길 수 없음 → 각 화면이 시계 자리를 비워 둠 (WClock)
        .onChange(of: engine.advanceCount) { _, _ in
            flashNow()
        }
    }

    @Environment(\.isLuminanceReduced) private var aod
    @State private var flash: Double = 0

    private func flashNow() {
        guard !aod else { return }
        withAnimation(.linear(duration: 0.06)) { flash = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.26)) { flash = 0 }
        }
    }
}

enum WSegmentFlash {
    static let color: Color = Color(red: 1.0, green: 236.0 / 255.0, blue: 80.0 / 255.0, opacity: 0.42)
}

// MARK: - W3–W6 Live

/// 화면 높이별 크기 (45mm 기준 디자인, 41mm 이하에서는 줄임)
struct WLiveMetrics {
    let top: CGFloat        // 위쪽 여백 (TOTAL 이름표 위)
    let totalFont: CGFloat  // 전체 시간 글자
    let icon: CGFloat       // 지금 구간 아이콘
    let name: CGFloat       // 지금 구간 이름 글자
    let seg: CGFloat        // SPLIT · PACE 숫자
    let nextName: CGFloat   // NEXT 아래 다음 구간 이름
    let main: CGFloat       // 가운데 노란 버튼 지름
    let side: CGFloat       // 양옆 작은 버튼 지름

    /// 빌드 27 (68 · 71번 확정안): 위 정보는 그대로, 아래에 NEXT 이름 + 컨트롤 줄 → 전체 글자를 조금 줄이고 간격을 고르게
    static var current: WLiveMetrics {
        let h: CGFloat = WKInterfaceDevice.current().screenBounds.height
        if h >= 240 { return WLiveMetrics(top: 16, totalFont: 30, icon: 18, name: 15, seg: 28, nextName: 17, main: 48, side: 34) }
        if h >= 220 { return WLiveMetrics(top: 14, totalFont: 28, icon: 17, name: 14, seg: 26, nextName: 16, main: 44, side: 32) }
        return WLiveMetrics(top: 12, totalFont: 24, icon: 15, name: 13, seg: 22, nextName: 14, main: 40, side: 28)
    }
}

/// 삼각형 머리 화살표 (3-A) — 가운데 노란 버튼 안
struct TriArrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w: CGFloat = r.width, h: CGFloat = r.height
        let bar: CGFloat = h * 0.18
        let headW: CGFloat = w * 0.42
        // 막대
        p.addRoundedRect(in: CGRect(x: r.minX + w * 0.06, y: r.midY - bar / 2, width: w - headW - w * 0.02, height: bar),
                         cornerSize: CGSize(width: bar * 0.35, height: bar * 0.35))
        // 머리 (삼각형)
        p.move(to: CGPoint(x: r.maxX - headW - w * 0.02, y: r.minY + h * 0.14))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.02, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - headW - w * 0.02, y: r.maxY - h * 0.14))
        p.closeSubpath()
        return p
    }
}

struct WLive: View {
    let engine = WorkoutEngine.shared
    let onControls: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    /// 220ms, cubic-bezier(0.32, 0.72, 0, 1)
    static let slideCurve: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.22)

    private let m = WLiveMetrics.current

    /// 아래 블록만 밀림: 나가는 쪽은 왼쪽(−110%), 들어오는 쪽은 오른쪽(+40%)에서
    private var slide: AnyTransition {
        .asymmetric(insertion: .offset(x: 66).combined(with: .opacity),
                    removal: .offset(x: -180).combined(with: .opacity))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            screen(now: ctx.date)
        }
        .ignoresSafeArea()
        .onChange(of: liveZone) { old, new in
            zoneChanged(from: old, to: new)
        }
    }

    /// 심박이 들어오기 전(0)은 존 없음 → 첫 측정값에서는 번쩍이지 않음
    private var liveZone: Int {
        guard engine.hr > 0 else { return 0 }
        return max(1, min(5, engine.zone))
    }

    @State private var pulse: Double = 0

    /// 존이 바뀌면: 위쪽 빛이 새 존 색 0.75 로 켜졌다가 900ms 동안 평소(0.28)로 돌아감
    private func zoneChanged(from old: Int, to new: Int) {
        guard !aod, old > 0, new > 0, old != new else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { pulse = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.9)) { pulse = 0 }
        }
    }

    private func screen(now: Date) -> some View {
        ZStack {
            glow
            zonePulse
            VStack(spacing: 0) {
                totalBlock(now: now)
                lower(now: now)
                    .id(engine.idx)
                    .transition(slide)
            }
            .padding(.top, m.top).padding(.horizontal, 14).padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .gesture(swipe)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20).onEnded { v in
            let dx = v.translation.width
            guard abs(dx) >= 40, abs(dx) > abs(v.translation.height) else { return }
            if dx < 0 { next() } else { onControls() }
        }
    }

    private func next() {
        withAnimation(WLive.slideCurve) { engine.advance() }
    }

    /// 심박 존은 위쪽 빛 색으로만: radial-gradient(120% 55% at 50% −14%, zone 0.28)
    @ViewBuilder
    private var glow: some View {
        if !aod {
            let z: Int = engine.zone
            AmbientLayer(a: Ambient(hex: C.zoneHex[max(1, min(5, z)) - 1], alpha: 0.28, rx: 1.2, ry: 0.55, cx: 0.5, cy: -0.14))
                .animation(.easeInOut(duration: 0.6), value: z)
        }
    }

    /// radial-gradient(120% 60% at 50% −10%, zone 0.75, transparent 72%) — 존 바뀔 때만 잠깐
    @ViewBuilder
    private var zonePulse: some View {
        if !aod {
            let z: Int = max(1, min(5, engine.zone))
            AmbientLayer(a: Ambient(hex: C.zoneHex[z - 1], alpha: 0.75, rx: 1.2, ry: 0.6, cx: 0.5, cy: -0.1))
                .opacity(pulse)
        }
    }

    // MARK: TOTAL (고정, 움직이지 않음)

    private func totalBlock(now: Date) -> some View {
        VStack(spacing: 0) {
            Text("TOTAL")
                .font(F.t(10, .semibold)).tracking(1.0)
                .foregroundStyle(C.text2)
            Text(Fm.t(engine.total(now)))
                .font(F.num(m.totalFont)).tracking(-0.02 * m.totalFont)
                .foregroundStyle(aod ? C.text2 : (isRox ? C.d1 : Color.white))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 지금 구간 + NEXT + 컨트롤 줄 (빌드 27 확정안: 위아래 간격을 고르게)

    private func lower(now: Date) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)
            current(now: now)
            Spacer(minLength: 4)
            if !aod {
                nextLabel
                Spacer(minLength: 4)
                controls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isRox: Bool { engine.cur.kind == .rox }
    private var fg: Color { aod ? C.text3 : (isRox ? C.d1 : Color.white) }

    private var curTint: IconTint {
        if aod { return .dim }
        return isRox ? .mute : .yellow
    }

    /// 구간 이름 · SPLIT | PACE(러닝) / GOAL·BEST(스테이션) · 아래 줄
    /// Roxzone 은 같은 모양인데 이름 · 숫자가 회색 (점선 테두리 안 씀 — 대표님 결정)
    private func current(now: Date) -> some View {
        let cur: Seg = engine.cur
        let el: Int = engine.segEl(now)
        let isRun: Bool = cur.icon == "run"
        let splitColor: Color = aod ? C.text3 : (isRox ? C.d1 : (cur.target > 0 && el > cur.target ? C.bad : C.accent))
        let rightColor: Color = isRox ? C.text2 : fg
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                Icon8(cur.icon, m.icon, tint: curTint)
                Text(cur.name)
                    .font(F.t(m.name, .semibold))
                    .foregroundStyle(isRox ? C.text2 : fg)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(height: m.name + 6)
            HStack(alignment: .top, spacing: 0) {
                col("SPLIT", Fm.t(el), splitColor)
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: m.seg * 1.05)
                    .padding(.top, 12)
                if isRun {
                    col(engine.settings.imperial ? (curvedRun ? "PACE/MI ≈" : "PACE /MI") : (curvedRun ? "PACE ≈" : "PACE"),
                        pace(el: el, dist: engine.segDist), rightColor)
                } else if cur.target > 0 {
                    col(engine.mode == .training ? "BEST" : "GOAL", Fm.t(cur.target), rightColor)
                } else {
                    col("", cur.detail, C.text2, small: true)
                }
            }
            .padding(.top, 2)
            Text(detailLine(cur))
                .font(isRun ? F.num(11, .medium) : F.t(11, .medium))
                .foregroundStyle(C.text2)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(height: 14)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity)
    }

    /// 아래 줄: 러닝 = 거리, 스테이션 = 무게 · 거리 (더블이고 계획이 있으면 "나 150 → 파트너 150 · 7번 교대")
    private func detailLine(_ cur: Seg) -> String {
        if cur.icon == "run" { return runLine(cur: cur) }
        if cur.kind == .rox { return "" }
        if let d = doublesLine(for: cur, plan: WatchStore.shared.ctx.doublesPlan, division: engine.settings.division) { return d }
        return cur.target > 0 ? Units.detail(cur.detail, engine.settings.imperial) : ""
    }

    /// 작은 이름표 + 큰 숫자 (두 칸이 같은 크기)
    private func col(_ label: String, _ value: String, _ color: Color, small: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(label.l10n).font(F.t(10, .semibold)).tracking(0.8).foregroundStyle(C.text3)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: 12)
            Text(value)
                .font(small ? F.t(13, .semibold) : F.num(m.seg)).tracking(small ? 0 : -0.01 * m.seg)
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.55)
                .frame(height: m.seg * 1.12)
        }
        .frame(maxWidth: .infinity)
    }

    private var curvedRun: Bool { engine.settings.runMode == "curved" && engine.mode != .race }

    /// 러닝 아래 줄: "0.62 / 1.00 km · 총 7.62 km" (러닝 모드에서 몇 km 뛰었는지가 바로 보이게)
    private func runLine(cur: Seg) -> String {
        // 빌드 27: 설정 > Units 가 lb · mi 면 마일로
        let imp: Bool = engine.settings.imperial
        let segM: Double = runMeters(cur.detail)
        let unit: String = imp ? "mi" : "km"
        let seg: String = Units.dist(min(segM, engine.segDist), imp) + " / " + Units.dist(segM, imp) + " " + unit
        guard engine.isRunKind, engine.distance >= 10 else { return seg }
        var line: String = seg + " · " + String(format: (imp ? "Total %@ mi" : "Total %@ km").l10n, Units.dist(engine.distance, imp))
        // 84번(빌드 28): 운동 전체 평균 페이스 (1 km 마다 끊지 않고 처음부터 계속) — 200 m 뛴 뒤부터
        if engine.distance >= 200 {
            let t: Double = Double(engine.total(Date()))
            let avg: Int = Units.pace(Int((t / engine.distance * 1000).rounded()), imp)
            if avg > 0 && avg < 3600 { line += " · " + String(format: "Avg %@".l10n, Fm.t(avg)) }
        }
        return line
    }

    /// 빌드 27: 지금 속도(애플 운동 앱과 같은 실시간 러닝 속도)로 페이스. 아직 모르면 "측정 중"
    private func pace(el: Int, dist: Double) -> String {
        engine.paceText(el: el, dist: dist, imperial: engine.settings.imperial) ?? "Measuring".l10n
    }

    private var isLast: Bool { engine.idx >= engine.seq.count - 1 && !engine.growsOpen }

    /// 러닝 모드(GPS · 거리 있음)는 1 km 마다 자동으로 넘어감 → 가운데 버튼 대신 안내
    private var autoSplit: Bool { engine.isRunKind && engine.distance > 0 }

    /// 다음 구간 (HIIT·자유 러닝은 아직 순서에 없는 다음 라운드/km)
    private var nextSeg: Seg {
        if engine.growsOpen && engine.idx >= engine.seq.count - 1 {
            let n: Int = engine.seq.count + 1
            return engine.isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
        }
        return engine.next
    }

    /// NEXT (작게) + 다음 구간 그림 · 이름 (크게) + 그 목표 (회색). 마지막이면 FINISH 운동 끝내기
    private var nextLabel: some View {
        let nx: Seg = nextSeg
        return VStack(spacing: 1) {
            Text(isLast ? "FINISH" : "NEXT")
                .font(F.t(9, .semibold)).tracking(1.0)
                .foregroundStyle(C.text3)
            HStack(spacing: 5) {
                if isLast {
                    Image(systemName: "checkmark").font(.system(size: m.nextName * 0.8, weight: .bold)).foregroundStyle(C.good)
                    Text("End workout").font(F.t(m.nextName, .bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Icon8(nx.icon, m.nextName, tint: nx.kind == .rox ? .mute : .yellow)
                    Text(nx.name).font(F.t(m.nextName, .bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if nx.target > 0 && !autoSplit {
                        Text(Fm.t(nx.target)).font(F.num(m.nextName * 0.72, .medium)).foregroundStyle(C.text2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("w.nextName")
    }

    /// 컨트롤 줄: 되돌리기 (작은 회색) · 다음 (큰 노란, 삼각형 머리 화살표) · 일시정지 (작은 회색)
    private var controls: some View {
        HStack(spacing: 0) {
            sideButton(symbol: "arrow.uturn.backward", on: engine.canUndo, id: "w.undoLive") {
                withAnimation(WLive.slideCurve) { engine.undo() }
            }
            Spacer(minLength: 0)
            mainButton
            Spacer(minLength: 0)
            sideButton(symbol: engine.running ? "pause.fill" : "play.fill", on: true, id: "w.pauseLive") {
                engine.togglePause()
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder private var mainButton: some View {
        if autoSplit {
            // 러닝은 1 km 마다 자동 → 누를 수 없음, 안내만
            Text("Auto split every 1 km".l10n)
                .font(F.t(10, .semibold)).foregroundStyle(C.text2)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                .frame(width: m.main * 1.6, height: m.main)
        } else {
            Button(action: next) {
                ZStack {
                    Circle().fill(isLast ? C.good : C.accent)
                    if isLast {
                        Image(systemName: "checkmark").font(.system(size: m.main * 0.42, weight: .heavy)).foregroundStyle(.black)
                    } else {
                        TriArrow().fill(Color.black).frame(width: m.main * 0.5, height: m.main * 0.42)
                    }
                }
                .frame(width: m.main, height: m.main)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isLast ? "Finish" : "Next"))
            .accessibilityIdentifier("w.next")
        }
    }

    private func sideButton(symbol: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: m.side * 0.42, weight: .semibold))
                .foregroundStyle(on ? Color.white : C.text3)
                .frame(width: m.side, height: m.side)
                .background(Circle().fill(Color.white.opacity(on ? 0.16 : 0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!on)
        .accessibilityIdentifier(id)
    }
}

// MARK: - W7 Controls

struct WControls: View {
    let engine = WorkoutEngine.shared
    let onBack: () -> Void
    let onEnd: () -> Void
    let onNext: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            screen(now: ctx.date)
        }
        .ignoresSafeArea()
    }

    private func screen(now: Date) -> some View {
        ZStack {
            AmbientLayer(a: Ambient(hex: 0xFFFFFF, alpha: 0.07, rx: 0.8, ry: 0.5, cx: 0.5, cy: 0.5))
            VStack(spacing: 0) {
                header(now: now)
                VStack(spacing: 5) {
                    endPill
                    pausePill
                    undoPill
                    nextPill
                }
                .padding(.vertical, 8)
                .frame(maxHeight: .infinity)
                Text("‹ Swipe left to go back")
                    .font(F.t(13)).foregroundStyle(C.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.top, 24).padding(.horizontal, 18).padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            if v.translation.width <= -40 && abs(v.translation.width) > abs(v.translation.height) { onBack() }
        })
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(engine.mode.name.l10n).font(F.t(13, .semibold)).foregroundStyle(C.accent).lineLimit(1).minimumScaleFactor(0.85)
            Text(Fm.t(engine.total(now))).font(F.num(15)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
        .padding(.trailing, WClock.reserve)     // 오른쪽 위 시스템 시계 자리
    }

    private var endPill: some View {
        pill("End", glyph: "i_x", fg: C.bad, bg: Color(hex: 0xFF453A, alpha: 0.22),
             dot: C.bad, glyphColor: .white, action: onEnd)
            .accessibilityIdentifier("w.end")
    }

    private var pausePill: some View {
        pill(engine.running ? "Pause" : "Resume", glyph: engine.running ? "i_pause" : "i_play",
             fg: .white, bg: Color.white.opacity(0.12),
             dot: Color.white.opacity(0.20), glyphColor: .white, action: { engine.togglePause() })
            .accessibilityIdentifier("w.pause")
    }

    private var nextPill: some View {
        pill("Next", glyph: "i_dblChev", fg: .black, bg: C.accent,
             dot: .black, glyphColor: C.accent, action: onNext)
            .accessibilityIdentifier("w.controlsNext")
    }

    /// 잘못 넘겼을 때 방금 넘긴 것을 한 번 되돌림. 되돌릴 것이 없으면 흐리게
    private var undoPill: some View {
        let on: Bool = engine.canUndo
        return pill("Undo", glyph: "", symbol: "arrow.uturn.backward", fg: on ? .white : C.text3,
                    bg: Color.white.opacity(on ? 0.12 : 0.05),
                    dot: Color.white.opacity(on ? 0.20 : 0.07), glyphColor: on ? .white : C.text3,
                    action: {
                        withAnimation(WLive.slideCurve) { engine.undo() }
                        onBack()
                    })
            .disabled(!on)
            .accessibilityIdentifier("w.undo")
    }

    /// 가로로 긴 알약: 왼쪽 동그라미 안에 아이콘(세 버튼이 같은 자리), 글자는 버튼 가운데에서 살짝 오른쪽.
    /// 세 개가 같은 높이로 공간을 채움
    private func pill(_ label: String, glyph: String, symbol: String? = nil, fg: Color, bg: Color, dot: Color, glyphColor: Color,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.l10n).font(F.t(16, .semibold)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.8)
                .offset(x: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bg, in: Capsule())
                .overlay(alignment: .leading) {
                    Circle().fill(dot)
                        .overlay {
                            GeometryReader { g in
                                Group {
                                    if let symbol {
                                        Image(systemName: symbol)
                                            .font(.system(size: g.size.height * 0.46, weight: .bold))
                                            .foregroundStyle(glyphColor)
                                    } else {
                                        Icon8(glyph, g.size.height * 0.56, glyphColor)
                                    }
                                }
                                .frame(width: g.size.width, height: g.size.height)
                            }
                        }
                        .padding(4)
                        .aspectRatio(1, contentMode: .fit)
                        .allowsHitTesting(false)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 오른쪽 위 시스템 시계가 차지하는 자리 (제목 줄에서 비워 둘 폭)
enum WClock {
    static let reserve: CGFloat = 58
}

// MARK: - W8 Segments

struct WSegmentList: View {
    let engine = WorkoutEngine.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            ZStack {
                AmbientLayer(a: Ambient(hex: 0xFFE600, alpha: 0.10, rx: 1, ry: 1, cx: 0.5, cy: 0, linear: true))
                list(now: ctx.date)
            }
        }
        .ignoresSafeArea()
    }

    /// 제목 줄은 시계 줄에 고정, 목록은 그 아래에서만 움직임 (구간 줄이 시계 밑으로 지나가지 않게)
    private func list(now: Date) -> some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 22).padding(.horizontal, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(engine.seq.enumerated()), id: \.offset) { i, s in
                            row(i, s, now: now).id(i)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
                .clipped()      // 워치 스크롤은 기본으로 안 잘림 → 줄이 제목·시계 뒤로 지나가지 않게 자름
                .onAppear { proxy.scrollTo(engine.idx, anchor: .center) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SEGMENTS").font(F.t(13, .semibold)).tracking(1).foregroundStyle(C.accent)
            Text("\(min(engine.idx + 1, engine.seq.count))/\(engine.seq.count)")
                .font(F.num(13, .regular)).foregroundStyle(C.text2)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8).padding(.trailing, WClock.reserve).padding(.bottom, 6)
    }

    private func rowTime(_ i: Int, _ s: Seg, now: Date) -> String {
        if i < engine.idx { return Fm.t(engine.splits.indices.contains(i) ? engine.splits[i] : 0) }
        if i == engine.idx { return Fm.t(engine.segEl(now)) }
        return s.target > 0 ? Fm.t(s.target) : "–"
    }

    private func row(_ i: Int, _ s: Seg, now: Date) -> some View {
        let d: Bool = i < engine.idx
        let c: Bool = i == engine.idx
        let r: Bool = s.kind == .rox
        let tint: IconTint = c ? .black : d ? .dim : r ? .mute : .white
        let nameColor: Color = c ? Color.black : d ? C.text2 : Color.white
        let timeColor: Color = c ? Color.black : d ? Color.white : C.text3
        return HStack(spacing: 7) {
            Icon8(s.icon, 13, tint: tint)
            Text(s.name).font(F.t(13, c ? .semibold : .regular))
                .foregroundStyle(nameColor).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if d {
                Icon8("i_check", 10, C.good)
            }
            Text(rowTime(i, s, now: now)).font(F.num(13, .medium))
                .foregroundStyle(timeColor).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(c ? C.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - End 확인

struct WEndSheet: View {
    let engine = WorkoutEngine.shared
    let onEnd: () -> Void
    let onDiscard: () -> Void
    let onResume: () -> Void
    /// 버리기를 한 번 눌렀음 → 한 번 더 묻는 화면
    @State private var askDiscard = false

    var body: some View {
        Group {
            if askDiscard { discardAsk } else { main }
        }
        .padding(.top, 30).padding(.horizontal, 18).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .ignoresSafeArea()
    }

    /// 저장하고 끝내기 · 버리기 · 계속 (아이폰과 같은 이름)
    private var main: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("End workout?").font(F.t(16, .semibold))
            Text(engine.growsOpen ? "Everything so far will be saved.".l10n
                                  : String(format: "%lld/%lld segments done. The rest won't be recorded.".l10n,
                                           engine.seq.prefix(engine.idx).filter { $0.kind != .rox }.count,
                                           engine.seq.filter { $0.kind != .rox }.count))
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            sheetButton("Save & end", fg: .black, bg: C.accent, action: onEnd)
                .accessibilityIdentifier("w.endConfirm")
            HStack(spacing: 6) {
                sheetButton("Discard", fg: C.bad, bg: Color(hex: 0x2A1412)) {
                    WKInterfaceDevice.current().play(.click)
                    withAnimation(.easeOut(duration: 0.15)) { askDiscard = true }
                }
                .accessibilityIdentifier("w.discard")
                sheetButton("Resume", fg: .white, bg: Color(hex: 0x1F1F1F), action: onResume)
                    .accessibilityIdentifier("w.resume")
            }
        }
    }

    /// 실수 방지: 한 번 더 묻기
    private var discardAsk: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Discard this workout?").font(F.t(16, .semibold))
            Text("It won't be saved here, on iPhone or in Health.")
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            sheetButton("Discard", fg: .white, bg: C.bad, action: onDiscard)
                .accessibilityIdentifier("w.discardConfirm")
            sheetButton("Cancel", fg: .white, bg: Color(hex: 0x1F1F1F)) {
                withAnimation(.easeOut(duration: 0.15)) { askDiscard = false }
            }
        }
    }

    private func sheetButton(_ t: String, fg: Color, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t.l10n).font(F.t(14, .semibold)).foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - W9 Summary

struct WSummary: View {
    let engine = WorkoutEngine.shared

    var body: some View {
        ZStack {
            AmbientLayer(a: Ambient(hex: 0x30D158, alpha: 0.18, rx: 1.2, ry: 0.6, cx: 0.5, cy: -0.1))
            // 위 34 는 시계 줄: 내용은 그 아래에서만 움직임 (위로 밀어도 시계와 겹치지 않게)
            VStack(spacing: 0) {
                // 시계 줄 왼쪽에 모드 이름 (51번: 멘트는 그 아래 노랑)
                Text(engine.lastRecord.map { $0.mode == .training ? $0.title.l10n : $0.mode.name.l10n } ?? "")
                    .font(F.t(13, .semibold)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16).padding(.trailing, WClock.reserve)
                    .frame(height: 34, alignment: .bottom)
                ScrollView {
                    if let r = engine.lastRecord {
                        VStack(spacing: 10) {
                            head(r)
                            stats(r)
                            rows(r)
                            doneButton
                        }
                        .padding(.top, 4).padding(.horizontal, 16).padding(.bottom, 16)
                    }
                }
                .clipped()
            }
        }
        .ignoresSafeArea()
    }

    private func head(_ r: Record) -> some View {
        let tg: Int = r.vsTarget ?? r.total
        let showVs: Bool = r.vsTarget != nil
        return VStack(spacing: 0) {
            // 51번: "수고했어요" 류 한 줄 (워치가 아는 것만으로 고름)
            Text(cheer(r).line).font(F.t(14, .semibold)).foregroundStyle(C.accent)
                .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("w.cheer")
            Text(Fm.t(r.total)).font(F.num(32)).tracking(-0.96)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 4)
            if let g = r.pftGrade {
                PFTBadge(grade: g, width: 84, height: 24, fontSize: 13)
                    .padding(.top, 5)
            }
            // 18번: "8 rounds" · "12 sets · 4,200 kg" 등
            if let k = r.kindSummary {
                Text(verbatim: k).font(F.t(13, .semibold)).foregroundStyle(C.accent)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.top, 3)
            }
            if showVs {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(Fm.d(r.total - tg)).font(F.num(15))
                        .foregroundStyle(r.total > tg ? C.bad : C.good)
                    Text(r.vsWord.l10n).font(F.t(12, .semibold)).tracking(0.8).foregroundStyle(C.text2)
                }
                .padding(.top, r.pftGrade != nil ? 5 : 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
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
            stat("AVG", r.avgHR > 0 ? "\(r.avgHR)" : "--", C.hr)
            stat("MAX", r.maxHR > 0 ? "\(r.maxHR)" : "--", C.hr)
            stat("KCAL", r.kcal.formatted(.number.grouping(.automatic)), .white)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(C.wCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .background(C.wCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var doneButton: some View {
        Button {
            engine.reset()
            WNav.shared.screen = .home
        } label: {
            Text("Done").font(F.t(14, .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("w.done")
    }

    private func stat(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l.l10n).font(F.t(12, .semibold)).tracking(0.64).foregroundStyle(C.text2)
            Text(v).font(F.num(15)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
