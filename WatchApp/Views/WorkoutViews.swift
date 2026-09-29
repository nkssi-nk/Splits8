import SwiftUI
import WatchKit

/// 운동 중: 세로 페이지 (크라운) = Live · Controls · Segments
/// Live 에서 왼쪽 스와이프·더블탭 = 다음 구간, 오른쪽 스와이프 = Controls, Controls 에서 왼쪽 스와이프 = Live
struct WWorkoutPager: View {
    let engine = WorkoutEngine.shared
    @State private var page = WatchDemo.page
    @State private var endSheet = WatchDemo.shot == "end"

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                WLive(onControls: { withAnimation { page = 1 } }).tag(0)
                WControls(onBack: { withAnimation { page = 0 } }, onEnd: { endSheet = true },
                          onNext: { engine.advance(); withAnimation { page = 0 } }).tag(1)
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

// MARK: - W3 Live

struct WLive: View {
    let engine = WorkoutEngine.shared
    let onControls: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = ctx.date
            let cur = engine.cur
            let z = engine.zone
            ZStack {
                if !aod {
                    AmbientLayer(a: Ambient(hex: C.zoneHex[z - 1], alpha: 0.28, rx: 1.2, ry: 0.55, cx: 0.5, cy: -0.14))
                        .animation(.easeInOut(duration: 0.6), value: z)
                }
                content(now: now, cur: cur, z: z)
                    .id(engine.idx)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { v in
                    let dx = v.translation.width
                    guard abs(dx) >= 40, abs(dx) > abs(v.translation.height) else { return }
                    if dx < 0 { next() } else { onControls() }
                }
            )
        }
        .ignoresSafeArea()
    }

    private func next() {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.22)) { engine.advance() }
    }

    @ViewBuilder
    private func content(now: Date, cur: Seg, z: Int) -> some View {
        let el = engine.segEl(now)
        let isR = cur.kind == .rox
        let over = el > cur.target
        let delta = engine.delta(now)
        let curved = engine.settings.runMode == "curved" && engine.mode != .race

        VStack(spacing: 0) {
            // 구간 이름 + 목표
            HStack(spacing: 5) {
                Icon8(cur.icon, 13, tint: aod ? .dim : isR ? .mute : .yellow)
                Text(cur.name).font(F.t(11, .semibold)).foregroundStyle(aod ? C.text3 : isR ? C.text2 : C.accent).lineLimit(1)
                Text((engine.mode == .race ? "Goal " : "Best ") + Fm.t(cur.target))
                    .font(F.round(10, .medium)).foregroundStyle(C.text2).padding(.leading, 2)
            }
            .frame(height: 14)

            // 구간 시간
            Text(Fm.t(el))
                .font(F.round(50)).tracking(-0.5)
                .foregroundStyle(aod ? C.text2 : .white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 6)

            // 진행 막대
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.16))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(aod ? C.g3A : over ? C.bad : C.accent)
                        .frame(width: g.size.width * CGFloat(max(6, min(100, Double(el) / Double(max(1, cur.target)) * 100))) / 100)
                        .animation(.linear(duration: 1), value: el)
                }
            }
            .frame(height: 4)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 158 * 0.18)
            .padding(.top, 8)

            // 러닝: 페이스 + 거리
            if cur.icon == "run" {
                let km = runMeters(cur.detail) / 1000
                let d = engine.segDist
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pace(el: el, dist: d)).font(F.round(17)).tracking(-0.17)
                        .foregroundStyle(aod ? C.text3 : curved ? C.text2 : .white)
                    Text(curved ? "/KM ≈" : "/KM").font(F.t(8, .bold)).tracking(0.64).foregroundStyle(C.text2)
                    Text(String(format: "%.2f km", min(km, d / 1000)))
                        .font(F.round(11, .medium)).foregroundStyle(C.text2).padding(.leading, 6)
                }
                .frame(height: 17)
                .padding(.top, 5)
            } else {
                Color.clear.frame(height: 22)
            }

            // TOTAL · VS
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("TOTAL").font(F.t(8, .semibold)).tracking(0.8).foregroundStyle(C.text2)
                    Text(Fm.t(engine.total(now))).font(F.round(16)).tracking(-0.16).foregroundStyle(aod ? C.text3 : .white)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text(engine.deltaWord).font(F.t(8, .semibold)).tracking(0.8).foregroundStyle(C.text2).lineLimit(1)
                    Text(Fm.d(delta)).font(F.round(16)).tracking(-0.16)
                        .foregroundStyle(aod ? C.text3 : delta > 0 ? C.bad : delta < 0 ? C.good : C.text2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 6)

            // 심박
            HStack(spacing: 4) {
                Icon8("heart", 10, aod ? C.text3 : C.hr)
                Text(engine.hr > 0 ? "\(Int(engine.hr.rounded()))" : "--").font(F.round(16)).foregroundStyle(aod ? C.text3 : C.hr)
                Text("BPM").font(F.t(8, .bold)).tracking(0.48).foregroundStyle(aod ? C.text3 : C.hr).padding(.top, 3)
                Text("Z\(z)").font(F.t(9, .bold)).foregroundStyle(.black)
                    .padding(.vertical, 1).padding(.horizontal, 5)
                    .background(aod ? C.g3A : C.zone(z), in: RoundedRectangle(cornerRadius: 4))
                    .padding(.leading, 6)
            }
            .padding(.top, 6)

            Text(cur.detail).font(F.t(9, .semibold)).tracking(0.54).foregroundStyle(C.text2).lineLimit(1)
                .padding(.top, 4)

            Spacer(minLength: 0)

            if !aod {
                Button(action: next) {
                    HStack(spacing: 4) {
                        Text("Next · \(engine.next.name)").font(F.t(9))
                        Icon8("dblChevron", 8, C.text3)
                    }
                    .foregroundStyle(C.text3)
                    .padding(.vertical, 6).padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .modifier(DoubleTapNext())
                .padding(.bottom, -6)
            }
        }
        .padding(.top, 24).padding(.horizontal, 20).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pace(el: Int, dist: Double) -> String {
        guard dist >= 10, el > 0 else { return "–:––" }
        let p = Double(el) / (dist / 1000)
        let m = Int(p) / 60, s = Int(p.rounded()) % 60
        return "\(m):" + String(format: "%02d", s)
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
            ZStack {
                AmbientLayer(a: Ambient(hex: 0xFFFFFF, alpha: 0.07, rx: 0.8, ry: 0.5, cx: 0.5, cy: 0.5))
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(engine.mode.name).font(F.t(11, .semibold)).foregroundStyle(C.accent)
                        Spacer()
                        Text(Fm.t(engine.total(ctx.date))).font(F.round(13))
                    }
                    .padding(.horizontal, 2)
                    Spacer()
                    HStack(spacing: 4) {
                        ctrl("End", bg: C.bad.opacity(0.2), action: onEnd) {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(C.bad)
                        }
                        ctrl(engine.running ? "Pause" : "Resume", bg: Color(hex: 0x1F1F1F), action: { engine.togglePause() }) {
                            if engine.running {
                                HStack(spacing: 2.7) {
                                    RoundedRectangle(cornerRadius: 1).frame(width: 2.7, height: 8.7)
                                    RoundedRectangle(cornerRadius: 1).frame(width: 2.7, height: 8.7)
                                }
                                .foregroundStyle(.white)
                            } else {
                                Icon8("play", 13, .white)
                            }
                        }
                        ctrl("Next", bg: C.accent, action: onNext) {
                            Icon8("dblChevron", 15, .black)
                        }
                    }
                    Spacer()
                    Text("‹ 왼쪽으로 밀어 돌아가기").font(F.t(9)).foregroundStyle(C.text3)
                }
                .padding(.top, 24).padding(.horizontal, 18).padding(.bottom, 16)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                if v.translation.width <= -40 && abs(v.translation.width) > abs(v.translation.height) { onBack() }
            })
        }
        .ignoresSafeArea()
    }

    private func ctrl<Glyph: View>(_ label: String, bg: Color, action: @escaping () -> Void,
                                   @ViewBuilder glyph: () -> Glyph) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack { Circle().fill(bg); glyph() }.frame(width: 40, height: 40)
                Text(label).font(F.t(9, .medium)).foregroundStyle(C.aeb)
            }
            .frame(maxWidth: .infinity)
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("SEGMENTS").font(F.t(10, .bold)).tracking(1).foregroundStyle(C.accent)
                                Spacer()
                            }
                            .padding(.horizontal, 8).padding(.bottom, 6)
                            ForEach(Array(engine.seq.enumerated()), id: \.offset) { i, s in
                                row(i, s, now: ctx.date).id(i)
                            }
                        }
                        .padding(.top, 22).padding(.horizontal, 12).padding(.bottom, 14)
                    }
                    .onAppear { proxy.scrollTo(engine.idx, anchor: .center) }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func row(_ i: Int, _ s: Seg, now: Date) -> some View {
        let d = i < engine.idx, c = i == engine.idx, r = s.kind == .rox
        let tint: IconTint = c ? .black : d ? .dim : r ? .mute : .white
        let time = d ? Fm.t(engine.splits.indices.contains(i) ? engine.splits[i] : 0) : c ? Fm.t(engine.segEl(now)) : Fm.t(s.target)
        return HStack(spacing: 7) {
            Icon8(s.icon, 13, tint: tint)
            Text(s.name).font(F.t(11, c ? .semibold : .regular))
                .foregroundStyle(c ? Color.black : d ? C.text2 : Color.white).lineLimit(1)
            Spacer(minLength: 0)
            if d {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(C.good)
            }
            Text(time).font(F.round(11, .medium))
                .foregroundStyle(c ? Color.black : d ? Color.white : C.text3)
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
            Spacer(minLength: 0)
            Button(action: onEnd) {
                Text("End").font(F.t(12, .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 34)
                    .background(C.bad, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            Button(action: onResume) {
                Text("Resume").font(F.t(12, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 34)
                    .background(Color(hex: 0x1F1F1F), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 30).padding(.horizontal, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .ignoresSafeArea()
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
                    let tg = r.vsTarget ?? r.total
                    VStack(spacing: 10) {
                        VStack(spacing: 0) {
                            Text("\(r.mode.name) complete").font(F.t(11, .semibold)).foregroundStyle(C.accent)
                            Text(Fm.t(r.total)).font(F.round(32)).tracking(-0.96).padding(.top, 4)
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(Fm.d(r.total - tg)).font(F.round(13))
                                    .foregroundStyle(r.total > tg ? C.bad : C.good)
                                Text(r.vsWord).font(F.t(8, .semibold)).tracking(0.8).foregroundStyle(C.text2)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 4)

                        HStack(spacing: 4) {
                            stat("AVG", r.avgHR > 0 ? "\(r.avgHR)" : "--", C.hr)
                            stat("MAX", r.maxHR > 0 ? "\(r.maxHR)" : "--", C.hr)
                            stat("KCAL", r.kcal.formatted(.number.grouping(.automatic)), .white)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(C.wCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(spacing: 0) {
                            ForEach(Array(r.segs.filter { $0.kind != .rox }.enumerated()), id: \.offset) { _, s in
                                HStack(spacing: 7) {
                                    Icon8(s.icon, 12, tint: .yellow)
                                    Text(s.name).font(F.t(11)).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(Fm.t(s.time)).font(F.round(11, .medium))
                                }
                                .padding(.vertical, 4).padding(.horizontal, 10)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(C.wCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            engine.reset()
                            WNav.shared.screen = .home
                        } label: {
                            Text("Done").font(F.t(12, .semibold)).foregroundStyle(.black)
                                .frame(maxWidth: .infinity).frame(height: 34)
                                .background(C.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 24).padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func stat(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(F.t(8, .semibold)).tracking(0.64).foregroundStyle(C.text2)
            Text(v).font(F.round(13)).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
