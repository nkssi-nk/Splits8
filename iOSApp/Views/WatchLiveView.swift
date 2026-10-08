import SwiftUI
import UIKit

// MARK: - 52번 · 워치 운동을 아이폰에서 같이 보기 (아이폰으로 기록 화면과 같은 모양 + 심박 · 칼로리)

struct WatchLiveView: View {
    let mirror = WatchMirror.shared
    let r = Router.shared
    @State private var askEnd = false

    var body: some View {
        GeometryReader { g in
            let m = PhoneLiveMetrics(height: g.size.height)
            ZStack(alignment: .top) {
                glow.frame(height: g.size.height * 0.5)
                if let st = mirror.state {
                    content(st, m)
                } else {
                    waiting
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            r.backAction = { r.go(.home) }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert("End workout?", isPresented: $askEnd) {
            Button("End", role: .destructive) { mirror.send(.end) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The workout ends on Apple Watch and is saved there.")
        }
    }

    /// 위쪽 빛 = 지금 심박 구간 색 (심박이 없으면 테마색)
    private var glow: some View {
        let z: Int = mirror.state?.zone ?? 0
        let hex: UInt32 = z >= 1 && z <= 5 ? C.zoneHex[z - 1] : GlowTheme.current.hex
        return RadialGradient(colors: [Color(hex: hex, alpha: 0.30), Color(hex: hex, alpha: 0)],
                              center: .top, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: z)
            .allowsHitTesting(false)
    }

    private var waiting: some View {
        VStack(spacing: 12) {
            ProgressView().tint(C.accent)
            Text("Connecting to Apple Watch…").font(F.t(15)).foregroundStyle(C.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ st: LiveState, _ m: PhoneLiveMetrics) -> some View {
        VStack(spacing: 0) {
            header(st)
            if st.finished || mirror.ended {
                saving
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                    live(st, m, now: ctx.date)
                }
                .padding(.top, m.top * 0.6)
                chips(st).padding(.top, 14 * m.k)
                nextRow(st, m)
                Spacer(minLength: 16)
                buttons(st, m)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: 위

    private func header(_ st: LiveState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((st.mode == .training ? st.title : st.mode.name).l10n)
                        .font(F.t(17, .semibold)).foregroundStyle(.white).lineLimit(1)
                    HStack(spacing: 6) {
                        Circle().fill(mirror.reconnecting ? C.text3 : C.good).frame(width: 6, height: 6)
                        Text(mirror.reconnecting ? "Apple Watch · Reconnecting…" : "Apple Watch · Live")
                            .font(F.t(12)).foregroundStyle(C.text2).lineLimit(1)
                            .accessibilityIdentifier("watchLive.status")
                    }
                }
                Spacer(minLength: 12)
                if !st.open {
                    Text("\(min(st.idx + 1, st.seq.count)) / \(st.seq.count)")
                        .font(F.num(12)).foregroundStyle(C.accent)
                        .padding(.horizontal, 8).frame(height: 22)
                        .overlay(Capsule().strokeBorder(C.accent.opacity(0.5), lineWidth: 1))
                }
            }
            if !st.open { LiveProgress(idx: st.idx, count: st.seq.count) }
        }
        .padding(.top, 8)
    }

    private func live(_ st: LiveState, _ m: PhoneLiveMetrics, now: Date) -> some View {
        let cur: Seg = st.cur ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 0)
        let el: Int = st.segEl(now, received: mirror.received)
        let timeColor: Color = st.running ? .white : C.text2
        return VStack(spacing: 0) {
            Text("TOTAL").font(F.t(12, .semibold)).tracking(0.12 * 12).foregroundStyle(C.text2)
            Text(Fm.t(st.total(now, received: mirror.received)))
                .font(F.num(m.totalFont)).tracking(-0.02 * m.totalFont)
                .foregroundStyle(timeColor).lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("watchLive.total")
            HStack(spacing: 14 * m.k) {
                Icon8(cur.icon, m.icon, tint: cur.kind == .rox ? .mute : .yellow)
                Text(Fm.t(el)).font(F.num(m.segFont)).tracking(-0.01 * m.segFont)
                    .foregroundStyle(st.running ? C.accent : C.text2).lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.top, m.segTop * 0.7)
            Text(cur.name).font(F.t(m.nameFont, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, m.nameTop)
            Text(cur.detail).font(F.num(m.detailFont, .regular)).foregroundStyle(C.aeb).lineLimit(1)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// ♥ 165 BPM [Z4] · 286 KCAL
    private func chips(_ st: LiveState) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill").font(.system(size: 12)).foregroundStyle(C.hr)
                Text(st.hr > 0 ? "\(st.hr)" : "--").font(F.num(15))
                Text("BPM").font(F.t(10, .semibold)).foregroundStyle(C.text2)
                if st.zone > 0 {
                    Text("Z\(st.zone)").font(F.t(10, .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 5).frame(height: 16)
                        .background(C.zones[min(4, st.zone - 1)], in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(Color.white.opacity(0.08), in: Capsule())
            HStack(spacing: 5) {
                Text("\(st.kcal)").font(F.num(15))
                Text("KCAL").font(F.t(10, .semibold)).foregroundStyle(C.text2)
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
    }

    private func nextRow(_ st: LiveState, _ m: PhoneLiveMetrics) -> some View {
        HStack(spacing: 12) {
            Text("NEXT").font(F.t(m.nextLabel)).tracking(0.1 * m.nextLabel).foregroundStyle(C.text2)
            if let nx = st.nextSeg {
                Icon8(nx.icon, m.nextIcon, tint: nx.kind == .rox ? .mute : .yellow)
                Text(nx.name).font(F.t(m.nextFont, .semibold)).lineLimit(1)
            } else {
                Text("Finish").font(F.t(m.nextFont, .semibold)).foregroundStyle(C.accent).lineLimit(1)
            }
        }
        .padding(.top, 22 * m.k)
    }

    // MARK: 아래 버튼 (누르면 워치로 보냄)

    private func buttons(_ st: LiveState, _ m: PhoneLiveMetrics) -> some View {
        let on: Bool = !mirror.reconnecting
        return VStack(spacing: 0) {
            YellowButton(height: m.buttonH, radius: m.buttonH / 2, enabled: on && st.running && !st.autoSplit,
                         action: {
                             UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                             mirror.send(.next)
                         }) {
                HStack(spacing: 10) {
                    Text((st.autoSplit ? "Auto split every 1 km" : (st.nextSeg != nil || st.open ? "Next" : "Finish")).l10n)
                    Text("›")
                }
                .font(F.t(m.buttonFont, .semibold))
            }
            .accessibilityIdentifier("watchLive.next")
            HStack(spacing: 10) {
                pill("End", icon: "stop.fill", color: C.bad, bg: Color(hex: 0xFF453A, alpha: 0.22), enabled: on) { askEnd = true }
                    .accessibilityIdentifier("watchLive.end")
                pill("Undo", icon: "arrow.uturn.backward", color: st.canUndo ? .white : C.text3,
                     bg: Color.white.opacity(st.canUndo ? 0.12 : 0.05), enabled: on && st.canUndo) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    mirror.send(.undo)
                }
                .accessibilityIdentifier("watchLive.undo")
                pill(st.running ? "Pause" : "Resume", icon: st.running ? "pause.fill" : "play.fill",
                     color: st.running ? .white : C.accent, bg: Color.white.opacity(0.12), enabled: on) {
                    mirror.send(st.running ? .pause : .resume)
                }
                .accessibilityIdentifier("watchLive.pause")
            }
            .padding(.top, m.pillGap)
            .padding(.bottom, m.bottom)
        }
        .opacity(on ? 1 : 0.5)
    }

    private func pill(_ t: String, icon: String, color: Color, bg: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(t.l10n).font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(bg, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .disabled(!enabled)
    }

    /// 워치가 끝냄: 기록이 도착하면 기록 화면 + 카드
    private var saving: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "applewatch").font(.system(size: 44)).foregroundStyle(C.accent)
            Text("Saving on Apple Watch…").font(F.t(17, .semibold))
            Text("Your record will appear here in a moment.").font(F.t(14)).foregroundStyle(C.text2)
                .multilineTextAlignment(.center)
            Spacer()
            GrayPill(title: "Home") { r.go(.home) }
                .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity)
    }
}
