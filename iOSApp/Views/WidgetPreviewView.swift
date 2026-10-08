import SwiftUI

// MARK: - 화면 확인용 (--demo --widgets): 위젯 · 잠금 화면 · 다이내믹 아일랜드를 앱 안에서 그려 봄
// 실제 위젯은 시뮬레이터 화면 확인에서 홈 화면에 놓을 수 없어서, 같은 모양(WidgetUI)을 여기에 늘어놓고 찍음.

struct WidgetPreviewView: View {
    private let now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Widgets").font(F.t(28, .bold)).padding(.top, 8)
            label("D-day · small (30 / 10 / race day)")
            HStack(spacing: 12) {
                small(stage: 1) { DdaySmallView(snap: .demo(days: 24, now: now), now: now) }
                small(stage: 2) { DdaySmallView(snap: .demo(days: 10, now: now), now: now) }
            }
            HStack(spacing: 12) {
                small(stage: 3) { DdaySmallView(snap: .demo(days: 0, now: now), now: now) }
                small(stage: 0) { NoRaceView() }
            }
            label("D-day · medium")
            medium(stage: 2) { DdayMediumView(snap: .demo(days: 10, now: now), now: now) }
            label("This week")
            HStack(spacing: 12) {
                small(stage: 0) { WeekSmallView(snap: .demo(now: now)) }
                small(stage: 0) { WeekSmallView(snap: WidgetSnap().fresh(now)) }
            }
            medium(stage: 0) { WeekMediumView(snap: .demo(now: now)) }
            label("Lock Screen")
            HStack(spacing: 10) {
                DdayRectView(snap: .demo(days: 10, now: now), now: now)
                    .foregroundStyle(.white)
                    .padding(10).frame(width: 170, height: 72)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                DdayCircleView(snap: .demo(days: 10, now: now), now: now)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            DdayInlineView(snap: .demo(days: 10, now: now), now: now)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            label("Live Activity · Lock Screen")
            LiveLockView(title: "Full Simulation", s: demoCard)
                .background(Color(hex: 0x111111), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            label("Dynamic Island")
            HStack(spacing: 8) {
                Icon8(demoCard.segIcon, 18, tint: .yellow)
                Spacer()
                Text(Fm.t(demoCard.segSec)).font(F.num(15)).foregroundStyle(C.accent)
            }
            .padding(.horizontal, 16).frame(width: 230, height: 36)
            .background(Color.black, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15)))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }

    private var demoCard: LiveCardState {
        LiveCardState(segName: "Sled Push", segIcon: "sledPush", segDetail: "50M · 152KG", nextName: "Roxzone", nextIcon: "roxzone",
                      idx: 3, count: 31, segStart: now.addingTimeInterval(-80), totalStart: now.addingTimeInterval(-973),
                      paused: true, segSec: 80, totalSec: 973, hr: 165, zone: 4, kcal: 286)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(F.t(13, .semibold)).foregroundStyle(C.text2).padding(.top, 6)
    }

    private func small<V: View>(stage: Int, @ViewBuilder _ v: () -> V) -> some View {
        box(v(), w: 165, stage: stage)
    }
    private func medium<V: View>(stage: Int, @ViewBuilder _ v: () -> V) -> some View {
        box(v(), w: 345, stage: stage)
    }
    private func box<V: View>(_ v: V, w: CGFloat, stage: Int) -> some View {
        v.padding(16)
            .frame(width: w, height: 165)
            .background {
                ZStack {
                    Color(hex: 0x0C0C0C)
                    DdayGlow(stage: stage)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(C.accent.opacity([0.0, 0.25, 0.4, 0.8][stage]), lineWidth: 1.5))
    }
}
