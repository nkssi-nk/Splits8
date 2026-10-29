import SwiftUI
import WatchKit

// MARK: - 18번 · 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 — 운동 중 첫 화면
// 큰 남은 시간(또는 남은 거리 · 세트 시간) + 지금 단계 이름 + 몇 번째 + 다음 안내 + 버튼 하나.
// 운동 = 노랑, 휴식 · 천천히 = 회색. 왼쪽 스와이프 = 가운데 버튼과 같음, 오른쪽 스와이프 = 조작 화면.
// 무게 · 횟수 고치기는 아이폰에서 (워치는 세트 끝 · 휴식 · 다음만).

struct WTimerLive: View {
    let engine = WorkoutEngine.shared
    let onControls: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    private let m = WLiveMetrics.current

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            screen(now: ctx.date)
        }
        .ignoresSafeArea()
    }

    private var kind: String { engine.kind ?? "" }

    private func face(_ now: Date) -> TimerFace {
        TimerFaces.make(kind: kind, seq: engine.seq, idx: engine.idx, segEl: engine.segEl(now), total: engine.total(now),
                        cap: engine.amrapCap, segDist: engine.runLike && engine.distance > 0 ? engine.segDist : nil,
                        done: engine.doneAt, task: engine.program?.task)
    }

    private func screen(now: Date) -> some View {
        let f: TimerFace = face(now)
        let tint: Color = aod ? C.text2 : (f.rest ? C.text2 : C.accent)
        return ZStack {
            if !aod {
                AmbientLayer(a: Ambient(hex: f.rest ? 0xFFFFFF : 0xFFE600, alpha: f.rest ? 0.08 : 0.24,
                                        rx: 1.2, ry: 0.6, cx: 0.5, cy: -0.1))
                    .animation(.easeInOut(duration: 0.4), value: f.rest)
            }
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(f.label.l10n).font(F.t(14, .bold)).tracking(1).foregroundStyle(tint)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if !f.count.isEmpty {
                        Text(verbatim: f.count).font(F.num(14, .medium)).foregroundStyle(.white).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, WClock.reserve)
                .frame(height: 20)
                Text(verbatim: f.main)
                    .font(F.num(m.totalFont * 1.75)).tracking(-0.03 * m.totalFont * 1.75)
                    .foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("w.timerMain")
                if !f.line.isEmpty {
                    Text(verbatim: f.line).font(F.t(12, .medium)).foregroundStyle(C.text2)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.75)
                }
                infoRow(now: now)
                    .padding(.top, 3)
                Spacer(minLength: 2)
                if !aod {
                    if !f.next.isEmpty {
                        Text(verbatim: f.next).font(F.t(12, .semibold)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.bottom, 4)
                    }
                    controls
                }
            }
            .padding(.top, 10).padding(.horizontal, 14).padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            let dx = v.translation.width
            guard abs(dx) >= 40, abs(dx) > abs(v.translation.height) else { return }
            if dx < 0 { main() } else { onControls() }
        })
    }

    /// TOTAL · 심박 · (인터벌 러닝) 페이스
    private func infoRow(now: Date) -> some View {
        HStack(spacing: 8) {
            Text(Fm.t(engine.total(now))).font(F.num(13, .medium)).foregroundStyle(.white)
            if engine.hr > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(C.hr)
                    Text("\(Int(engine.hr.rounded()))").font(F.num(13, .medium)).foregroundStyle(.white)
                }
            }
            if engine.runLike {
                Text(engine.paceText(el: engine.segEl(now), dist: engine.segDist, imperial: false) ?? "Measuring".l10n)
                    .font(F.num(13, .medium)).foregroundStyle(paceColor(now))
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    /// 인터벌 러닝: 목표 페이스보다 빠르면 초록, 느리면 빨강
    private func paceColor(_ now: Date) -> Color {
        guard let tp = engine.cur.tp, let p = engine.livePaceSec else { return C.text2 }
        return p <= tp ? C.good : C.bad
    }

    // MARK: 버튼

    /// 가운데 버튼 글자
    private var mainLabel: String {
        let c: Seg = engine.cur
        switch kind {
        case WKind.emom: return engine.doneAt == nil ? "Done" : "Resting"
        case WKind.amrap: return "Round done"
        case WKind.strength: return c.tag == "rest" ? "Skip rest" : "Set done"
        case WKind.interval: return "Next step"
        default: return "Skip"
        }
    }

    private var mainOn: Bool {
        engine.running && !(kind == WKind.emom && engine.doneAt != nil)
    }

    private func main() {
        guard mainOn else { return }
        withAnimation(WLive.slideCurve) { engine.advance() }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button(action: main) {
                Text(mainLabel.l10n).font(F.t(15, .semibold)).foregroundStyle(.black)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity).frame(height: m.main * 0.82)
                    .background(mainOn ? C.accent : C.text3, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!mainOn)
            .accessibilityIdentifier("w.timerMainButton")
            Button { engine.togglePause() } label: {
                Image(systemName: engine.running ? "pause.fill" : "play.fill")
                    .font(.system(size: m.side * 0.42, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: m.main * 0.82, height: m.main * 0.82)
                    .background(Circle().fill(Color.white.opacity(0.16)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("w.timerPause")
        }
    }
}
