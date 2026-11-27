import SwiftUI
import UIKit

// MARK: - 52번 · 워치 운동을 아이폰에서 같이 보기 (아이폰으로 기록 화면과 같은 모양 + 심박 · 칼로리)

struct WatchLiveView: View {
    let mirror = WatchMirror.shared
    let r = Router.shared
    @State private var askEnd = false

    @State private var page = 0
    @State private var zoneHold = LiveZoneHold()
    /// 받은 심박으로 세는 최고 · 평균 (워치가 보내는 상태에는 없음)
    @State private var maxHR = 0
    @State private var hrSum = 0
    @State private var hrN = 0

    var body: some View {
        GeometryReader { g in
            let L = PL(w: g.size.width, h: g.size.height)
            ZStack {
                if let st = mirror.state {
                    content(st, L)
                } else {
                    Color.black.ignoresSafeArea()
                    waiting
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            r.backAction = { r.go(.home) }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: mirror.state?.hr ?? 0) { _, hr in
            guard hr > 0 else { return }
            maxHR = max(maxHR, hr); hrSum += hr; hrN += 1
        }
        .task {
            while !Task.isCancelled {
                zoneHold.update(raw: mirror.state?.zone ?? 0)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .alert("End workout?", isPresented: $askEnd) {
            Button("End", role: .destructive) { mirror.send(.end) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The workout ends on Apple Watch and is saved there.")
        }
    }

    private var waiting: some View {
        VStack(spacing: 12) {
            ProgressView().tint(C.yellow)
            Text("Connecting to Apple Watch…").font(F.t(15)).foregroundStyle(C.dText2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ st: LiveState, _ L: PL) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let f: LiveFrame = frame(st, now: ctx.date)
            let status: String = mirror.reconnecting ? "Apple Watch · Reconnecting…"
                : (st.hr > 0 ? "Watch".l10n + " · \(st.hr) " + "BPM".l10n : "Apple Watch · Live")
            ZStack {
                LiveBackground(tone: f.tone, zone: zoneHold.shown, seed: isRunCard(st) ? 1 : st.idx)
                if mirror.discarded {
                    // 워치에서 버림: 기록이 안 오니 '저장 중…'을 보여 주지 않고 잠시 뒤 홈으로 감
                    Color.clear
                } else if st.finished || mirror.ended {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    saving.padding(.top, L.y(150))
                } else {
                    TabView(selection: $page) {
                        LiveMain(f: f, L: L, idPrefix: "watchLive")
                            .frame(width: L.w, height: L.h).ignoresSafeArea().tag(0)
                        LiveGoalPage(f: f, L: L, maxHR: maxHR, avgHR: hrN > 0 ? hrSum / hrN : nil)
                            .frame(width: L.w, height: L.h).ignoresSafeArea().tag(1)
                        if !isRunCard(st) {
                            LiveSegmentList(L: L, tone: f.tone, seq: st.seq, idx: st.idx, splits: st.splits, skipped: [],
                                            segEl: f.segEl, word: st.vsWord)
                                .frame(width: L.w, height: L.h).ignoresSafeArea().tag(2)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()     // 1.2.7: 쪽 안 자리를 화면 전체 기준으로
                    LivePageDots(L: L, count: isRunCard(st) ? 2 : 3, page: page, tone: f.tone)
                    buttons(st, f, L)
                }
                LiveTop(f: f, L: L, status: status, live: !mirror.reconnecting, idPrefix: "watchLive")
                    .allowsHitTesting(false)
            }
        }
    }

    /// 워치에서 받은 상태 → 화면 한 장면
    private func frame(_ st: LiveState, now: Date) -> LiveFrame {
        LiveFrame(mode: st.mode, title: st.title, seq: st.seq, idx: st.idx,
                  segEl: st.segEl(now, received: mirror.received), total: st.total(now, received: mirror.received),
                  running: st.running, open: st.open, segDist: st.segDist, totalDist: st.dist,
                  runKind: st.mode == .training && st.cur?.icon == "run",
                  speed: st.running ? st.spd : nil,
                  runCard: isRunCard(st), runGoalKm: isRunCard(st) && !st.open ? st.seq.count : 0,
                  splits: st.splits, hr: st.hr, zone: st.zone, kcal: st.kcal)
    }

    /// 1.2.2: 워치의 러닝 카드인지 (구간이 모두 "KM n" 러닝)
    private func isRunCard(_ st: LiveState) -> Bool {
        st.mode == .training && !st.seq.isEmpty && st.seq.allSatisfy { $0.icon == "run" && $0.name.hasPrefix("KM ") }
    }

    // MARK: 아래 버튼 (누르면 워치로 보냄)

    private func buttons(_ st: LiveState, _ f: LiveFrame, _ L: PL) -> some View {
        let on: Bool = !mirror.reconnecting
        return LiveButtons(L: L, tone: f.tone, idPrefix: "watchLive",
                           nextTitle: st.autoSplit ? nil : (st.nextSeg != nil || st.open ? "Next" : "Finish"),
                           nextOn: on && st.running,
                           showUndo: !isRunCard(st), undoOn: st.canUndo,
                           showSkip: false,
                           running: st.running, enabled: on,
                           onNext: {
                               UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                               mirror.send(.next)
                           },
                           onEnd: { askEnd = true },
                           onUndo: {
                               UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                               mirror.send(.undo)
                           },
                           onPause: { mirror.send(st.running ? .pause : .resume) })
    }

    /// 워치가 끝냄: 기록이 도착하면 기록 화면 + 카드
    private var saving: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "applewatch").font(.system(size: 44)).foregroundStyle(C.yellow)
            Text("Saving on Apple Watch…").font(F.t(17, .semibold))
            Text("Your record will appear here in a moment.").font(F.t(14)).foregroundStyle(C.dText2)
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
            Text(label.l10n).font(F.t(12, .semibold)).tracking(1).foregroundStyle(C.dText3)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: 16)
            Text(value).font(F.num(size)).tracking(-0.01 * size)
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}
