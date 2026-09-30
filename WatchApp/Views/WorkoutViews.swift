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
                WLive(onControls: { withAnimation { page = 1 } }).tag(0)
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
                WEndSheet(onEnd: { endSheet = false; engine.endNow() }, onResume: { endSheet = false })
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - W3–W6 Live

/// 화면 높이별 크기 (45mm 기준 디자인, 41mm 이하에서는 줄임)
struct WLiveMetrics {
    let top: CGFloat        // 위쪽 여백
    let totalH: CGFloat     // TOTAL 블록 높이 (고정)
    let totalFont: CGFloat  // 전체 시간 글자
    let icon: CGFloat       // 현재 구간 아이콘
    let seg: CGFloat        // 현재 구간 시간 글자
    let nameTop: CGFloat    // 구간 이름 위 여백

    static var current: WLiveMetrics {
        let h: CGFloat = WKInterfaceDevice.current().screenBounds.height
        if h >= 230 { return WLiveMetrics(top: 24, totalH: 80, totalFont: 40, icon: 36, seg: 34, nameTop: 8) }
        if h >= 205 { return WLiveMetrics(top: 20, totalH: 64, totalFont: 36, icon: 30, seg: 30, nameTop: 5) }
        return WLiveMetrics(top: 16, totalH: 56, totalFont: 32, icon: 26, seg: 26, nameTop: 4)
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
    }

    private func screen(now: Date) -> some View {
        ZStack {
            glow
            VStack(spacing: 0) {
                totalBlock(now: now)
                lower(now: now)
                    .id(engine.idx)
                    .transition(slide)
            }
            .padding(.top, m.top).padding(.horizontal, 18).padding(.bottom, 10)
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

    // MARK: TOTAL (고정, 움직이지 않음)

    private func totalBlock(now: Date) -> some View {
        VStack(spacing: 4) {
            Text("TOTAL")
                .font(F.t(9, .semibold)).tracking(1.08)
                .foregroundStyle(C.text2)
            Text(Fm.t(engine.total(now)))
                .font(F.num(m.totalFont)).tracking(-0.02 * m.totalFont)
                .foregroundStyle(aod ? C.text2 : Color.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: m.totalH)
    }

    // MARK: 현재 + 다음 (밀리는 부분)

    private func lower(now: Date) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            current(now: now)
            Spacer(minLength: 0)
            if !aod { nextRow }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fg: Color { aod ? C.text3 : Color.white }

    private var curTint: IconTint {
        if aod { return .dim }
        return engine.cur.kind == .rox ? .mute : .yellow
    }

    private func current(now: Date) -> some View {
        let cur: Seg = engine.cur
        let el: Int = engine.segEl(now)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Icon8(cur.icon, m.icon, tint: curTint)
                Text(Fm.t(el))
                    .font(F.num(m.seg)).tracking(-0.01 * m.seg)
                    .foregroundStyle(fg)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(height: m.icon)
            Text(cur.name)
                .font(F.t(14, .semibold))
                .foregroundStyle(fg)
                .lineLimit(1)
                .padding(.top, m.nameTop)
            Text(detailLine(cur: cur, el: el))
                .font(cur.icon == "run" ? F.num(11, .medium) : F.t(11, .medium))
                .foregroundStyle(C.text2)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(height: 15)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
    }

    /// 러닝: "4:42 /KM · 0.62 km" (곡면 트레드밀은 "/KM ≈"), 그 외: 세부 (50M · 152KG)
    private func detailLine(cur: Seg, el: Int) -> String {
        guard cur.icon == "run" else { return cur.detail }
        let curved: Bool = engine.settings.runMode == "curved" && engine.mode != .race
        let km: Double = runMeters(cur.detail) / 1000
        let d: Double = engine.segDist
        let dist: String = String(format: "%.2f", min(km, d / 1000))
        return pace(el: el, dist: d) + " " + (curved ? "/KM ≈" : "/KM") + " · " + dist + " km"
    }

    private func pace(el: Int, dist: Double) -> String {
        guard dist >= 10, el > 0 else { return "–:––" }
        let p: Double = Double(el) / (dist / 1000)
        let total: Int = Int(p.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    private var isLast: Bool { engine.idx >= engine.seq.count - 1 }

    /// NEXT + 다음 아이콘 22 + 이름 14 (탭 = 다음 구간)
    private var nextRow: some View {
        let nx: Seg = engine.next
        return Button(action: next) {
            HStack(spacing: 8) {
                Text("NEXT")
                    .font(F.t(10, .semibold)).tracking(0.8)
                    .foregroundStyle(C.text3)
                if isLast {
                    Icon8("i_check", 22, C.d1)
                    Text("Finish")
                        .font(F.t(14, .semibold)).foregroundStyle(C.d1).lineLimit(1)
                } else {
                    Icon8(nx.icon, 22, tint: nx.kind == .rox ? .mute : .yellow)
                    Text(nx.name)
                        .font(F.t(14, .semibold)).foregroundStyle(C.d1).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(DoubleTapNext())
        .accessibilityIdentifier("w.next")
    }
}

/// 더블탭(손가락 두 번 톡톡) = 다음 구간 (watchOS 11 이상)
struct DoubleTapNext: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
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
                VStack(spacing: 6) {
                    endPill
                    pausePill
                    nextPill
                }
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
                Text("‹ 왼쪽으로 밀어 돌아가기")
                    .font(F.t(10)).foregroundStyle(C.text3)
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
        HStack(alignment: .firstTextBaseline) {
            Text(engine.mode.name).font(F.t(11, .semibold)).foregroundStyle(C.accent).lineLimit(1)
            Spacer(minLength: 4)
            Text(Fm.t(engine.total(now))).font(F.num(13)).lineLimit(1)
        }
        .padding(.horizontal, 2)
    }

    private var endPill: some View {
        pill("End", glyph: "i_x", glyphSize: 22, fg: C.bad, bg: Color(hex: 0xFF453A, alpha: 0.22), action: onEnd)
            .accessibilityIdentifier("w.end")
    }

    private var pausePill: some View {
        pill(engine.running ? "Pause" : "Resume", glyph: engine.running ? "i_pause" : "i_play", glyphSize: 20,
             fg: .white, bg: Color.white.opacity(0.12), action: { engine.togglePause() })
            .accessibilityIdentifier("w.pause")
    }

    private var nextPill: some View {
        pill("Next", glyph: "i_dblChev", glyphSize: 22, fg: .black, bg: C.accent, action: onNext)
            .accessibilityIdentifier("w.controlsNext")
    }

    /// 가로로 긴 알약: 아이콘 + 15/600 라벨, 세 개가 같은 높이로 공간을 채움
    private func pill(_ label: String, glyph: String, glyphSize: CGFloat, fg: Color, bg: Color,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Icon8(glyph, glyphSize, fg)
                Text(label).font(F.t(15, .semibold)).foregroundStyle(fg).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
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

    private func list(now: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    ForEach(Array(engine.seq.enumerated()), id: \.offset) { i, s in
                        row(i, s, now: now).id(i)
                    }
                }
                .padding(.top, 22).padding(.horizontal, 12).padding(.bottom, 14)
            }
            .onAppear { proxy.scrollTo(engine.idx, anchor: .center) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SEGMENTS").font(F.t(10, .semibold)).tracking(1).foregroundStyle(C.accent)
            Spacer(minLength: 0)
            Text("\(min(engine.idx + 1, engine.seq.count))/\(engine.seq.count)")
                .font(F.num(10, .regular)).foregroundStyle(C.text2)
        }
        .padding(.horizontal, 8).padding(.bottom, 6)
    }

    private func rowTime(_ i: Int, _ s: Seg, now: Date) -> String {
        if i < engine.idx { return Fm.t(engine.splits.indices.contains(i) ? engine.splits[i] : 0) }
        if i == engine.idx { return Fm.t(engine.segEl(now)) }
        return Fm.t(s.target)
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
            Text(s.name).font(F.t(11, c ? .semibold : .regular))
                .foregroundStyle(nameColor).lineLimit(1)
            Spacer(minLength: 0)
            if d {
                Icon8("i_check", 10, C.good)
            }
            Text(rowTime(i, s, now: now)).font(F.num(11, .medium))
                .foregroundStyle(timeColor).lineLimit(1)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(c ? C.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - End 확인

struct WEndSheet: View {
    let engine = WorkoutEngine.shared
    let onEnd: () -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("운동을 끝낼까요?").font(F.t(15, .semibold))
            Text("\(engine.idx)/\(engine.seq.count) 구간 완료. 남은 구간은 기록되지 않습니다.")
                .font(F.t(11)).foregroundStyle(C.text2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            sheetButton("End", fg: .black, bg: C.bad, action: onEnd)
                .accessibilityIdentifier("w.endConfirm")
            sheetButton("Resume", fg: .white, bg: Color(hex: 0x1F1F1F), action: onResume)
                .accessibilityIdentifier("w.resume")
        }
        .padding(.top, 30).padding(.horizontal, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .ignoresSafeArea()
    }

    private func sheetButton(_ t: String, fg: Color, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(F.t(12, .semibold)).foregroundStyle(fg)
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
            ScrollView {
                if let r = engine.lastRecord {
                    VStack(spacing: 10) {
                        head(r)
                        stats(r)
                        rows(r)
                        doneButton
                    }
                    .padding(.top, 24).padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func head(_ r: Record) -> some View {
        let tg: Int = r.vsTarget ?? r.total
        return VStack(spacing: 0) {
            Text("\(r.mode.name) complete").font(F.t(11, .semibold)).foregroundStyle(C.accent).lineLimit(1)
            Text(Fm.t(r.total)).font(F.num(32)).tracking(-0.96)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(Fm.d(r.total - tg)).font(F.num(13))
                    .foregroundStyle(r.total > tg ? C.bad : C.good)
                Text(r.vsWord).font(F.t(8, .semibold)).tracking(0.8).foregroundStyle(C.text2)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
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
            ForEach(Array(r.segs.filter { $0.kind != .rox }.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 7) {
                    Icon8(s.icon, 12, tint: .yellow)
                    Text(s.name).font(F.t(11)).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Fm.t(s.time)).font(F.num(11, .medium)).lineLimit(1)
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
            Text("Done").font(F.t(12, .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("w.done")
    }

    private func stat(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(F.t(8, .semibold)).tracking(0.64).foregroundStyle(C.text2)
            Text(v).font(F.num(13)).foregroundStyle(c).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
