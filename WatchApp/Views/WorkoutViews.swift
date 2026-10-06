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
        VStack(spacing: 4) {
            Text("TOTAL")
                .font(F.t(12, .semibold)).tracking(1.08)
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
                .font(F.t(16, .semibold))
                .foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.85)
                .padding(.top, m.nameTop)
            Text(detailLine(cur: cur, el: el))
                .font(cur.icon == "run" ? F.num(13, .medium) : F.t(13, .medium))
                .foregroundStyle(C.text2)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(height: 18)
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

    private var isLast: Bool { engine.idx >= engine.seq.count - 1 && !engine.growsOpen }

    /// 다음 구간 (HIIT·자유 러닝은 아직 순서에 없는 다음 라운드/km)
    private var nextSeg: Seg {
        if engine.growsOpen && engine.idx >= engine.seq.count - 1 {
            let n: Int = engine.seq.count + 1
            return engine.isHIIT ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
        }
        return engine.next
    }

    /// NEXT + 다음 아이콘 22 + 이름 14 (탭 = 다음 구간)
    private var nextRow: some View {
        let nx: Seg = nextSeg
        return Button(action: next) {
            HStack(spacing: 8) {
                Text("NEXT")
                    .font(F.t(13, .semibold)).tracking(0.8)
                    .foregroundStyle(C.text3)
                if isLast {
                    Icon8("i_check", 22, C.d1)
                    Text("Finish")
                        .font(F.t(16, .semibold)).foregroundStyle(C.d1).lineLimit(1).minimumScaleFactor(0.85)
                } else {
                    Icon8(nx.icon, 22, tint: nx.kind == .rox ? .mute : .yellow)
                    Text(nx.name)
                        .font(F.t(16, .semibold)).foregroundStyle(C.d1).lineLimit(1).minimumScaleFactor(0.85)
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

    /// 가로로 긴 알약: 왼쪽 동그라미 안에 아이콘(세 버튼이 같은 자리), 글자는 버튼 가운데에서 살짝 오른쪽.
    /// 세 개가 같은 높이로 공간을 채움
    private func pill(_ label: String, glyph: String, fg: Color, bg: Color, dot: Color, glyphColor: Color,
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
                                Icon8(glyph, g.size.height * 0.56, glyphColor)
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
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("End workout?").font(F.t(16, .semibold))
            Text(engine.growsOpen ? String(localized: "Everything so far will be saved.")
                                  : String(localized: "\(engine.idx)/\(engine.seq.count) segments done. The rest won't be recorded."))
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(3)
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
            Text(t.l10n).font(F.t(14, .semibold)).foregroundStyle(fg)
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
                Color.clear.frame(height: 34)
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
            Text(String(localized: "\(r.mode.name.l10n) complete")).font(F.t(13, .semibold)).foregroundStyle(C.accent).lineLimit(1).minimumScaleFactor(0.85)
            Text(Fm.t(r.total)).font(F.num(32)).tracking(-0.96)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 4)
            if let g = r.pftGrade {
                PFTBadge(grade: g, width: 84, height: 24, fontSize: 13)
                    .padding(.top, 5)
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
