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
            // 빌드 24: 머리는 아이폰 직접 기록 화면과 같은 부품 (n / 16 은 Roxzone 뺌)
            LiveHeader(f: frame(st, now: Date()), status: mirror.reconnecting ? "Apple Watch · Reconnecting…" : "Apple Watch · Live",
                       live: !mirror.reconnecting, idPrefix: "watchLive")
            if mirror.discarded {
                // 워치에서 버림: 기록이 안 오니 '저장 중…'을 보여 주지 않고 잠시 뒤 홈으로 감
                Spacer()
            } else if st.finished || mirror.ended {
                saving
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                    LiveBody(f: frame(st, now: ctx.date), m: m, idPrefix: "watchLive")
                }
                .padding(.top, m.top * 0.6)
                chips(st).padding(.top, 14 * m.k)
                LiveNextRow(next: nextSeg(st), m: m, dividerTop: m.dividerTop * 0.7)
                Spacer(minLength: 16)
                buttons(st, m)
            }
        }
        .padding(.horizontal, 20)
    }

    /// 워치에서 받은 상태 → 화면 한 장면
    private func frame(_ st: LiveState, now: Date) -> LiveFrame {
        LiveFrame(mode: st.mode, title: st.title, seq: st.seq, idx: st.idx,
                  segEl: st.segEl(now, received: mirror.received), total: st.total(now, received: mirror.received),
                  running: st.running, open: st.open, segDist: st.segDist, totalDist: st.dist,
                  runKind: st.mode == .training && st.cur?.icon == "run",
                  speed: st.running ? st.spd : nil)
    }

    /// 다음 구간 (HIIT · 자유 러닝은 아직 순서에 없는 다음 라운드/km)
    private func nextSeg(_ st: LiveState) -> Seg? {
        if let nx = st.nextSeg { return nx }
        guard st.open else { return nil }
        let n: Int = st.seq.count + 1
        return st.cur?.icon == "hiit" ? SeqBuilder.hiitRound(n) : SeqBuilder.runKm(n)
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

/// 64번: 작은 이름표 + 큰 숫자 한 칸 (실시간 화면의 '구간 시간 | 페이스' 두 칸이 같은 크기)
struct LiveCol: View {
    let label: String
    let value: String
    let color: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(label.l10n).font(F.t(12, .semibold)).tracking(1).foregroundStyle(C.text3)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: 16)
            Text(value).font(F.num(size)).tracking(-0.01 * size)
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}
