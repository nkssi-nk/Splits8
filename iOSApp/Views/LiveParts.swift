import SwiftUI

// MARK: - 빌드 24: 운동 중 화면 공용 부품
// 아이폰으로 기록(PhoneLiveView) · 워치 운동 같이 보기(WatchLiveView) 두 화면이 같은 모양.
//  머리: 제목 / ● 상태 줄 / "n / 16" / 진행 막대 (끝 없는 운동은 막대 · 숫자 숨김)
//  가운데: TOTAL · 큰 전체 시간 · [아이콘 이름] · SPLIT | 오른쪽 칸 · 아래 줄
//  오른쪽 칸: 러닝 = PACE /KM, 목표가 있는 구간 = GOAL(트레이닝은 BEST) + 목표 시간 그대로 (Roxzone 도 GOAL).
//  목표를 넘기면 SPLIT 숫자가 빨강.

/// 화면 한 장면에 필요한 값 (엔진 · 워치에서 받은 상태 어느 쪽이든 여기로 바꿔 그림)
struct LiveFrame {
    var mode: Mode
    var title: String
    var seq: [Seg]
    var idx: Int
    var segEl: Int
    var total: Int
    var running: Bool
    /// HIIT · 자유 러닝 (막대 · n/16 숨김)
    var open: Bool
    /// 러닝 페이스용 지금 구간 거리(m) — 못 재면 nil
    var segDist: Double?
    /// 운동 전체 거리(m) — 러닝 카드 "총 x km" 줄
    var totalDist: Double?
    /// 러닝 카드(트레이닝 러닝)인지
    var runKind: Bool
    /// 빌드 27: 지금 속도(m/s) — 실시간 페이스. nil · 0 = 모름
    var speed: Double? = nil

    var cur: Seg { seq.indices.contains(idx) ? seq[idx] : (seq.last ?? Seg(icon: "run", name: "Run", detail: "1KM", kind: .run, target: 0)) }
    var countTotal: Int { seq.liveCountTotal }
    var countNow: Int { seq.liveCountNow(idx) }
    var progress: Double { seq.liveProgress(idx) }
    /// 목표 이름: 트레이닝은 최고 기록(BEST), 나머지는 GOAL
    var goalWord: String { mode == .training ? "BEST" : "GOAL" }
    /// 목표를 넘겼는지 (SPLIT 빨강)
    var over: Bool { cur.target > 0 && segEl > cur.target }

    /// 빌드 27: lb · mi 로 보여 주는지 (설정 > Units)
    var imperial: Bool { Store.shared.settings.imperial }

    /// 아래 줄: 러닝 = "0.62 / 1.00 KM (· 총 x km)", 스테이션 = 세부(50M · 152KG), Roxzone · 목표 없는 구간 = 빈 줄
    var detailLine: String {
        let c: Seg = cur
        let imp: Bool = imperial
        if c.kind == .rox { return "" }
        if c.kind == .run {
            guard let sd = segDist else { return Units.detail(c.detail, imp) }
            let segM: Double = runMeters(c.detail)
            var s: String = Units.dist(min(segM, sd), imp) + " / " + Units.dist(segM, imp) + " " + Units.distUnit(imp)
            if open || runKind, let td = totalDist, td >= 10 {
                s += " · " + (imp ? String(localized: "Total \(Units.dist(td, true)) mi")
                                  : String(localized: "Total \(String(format: "%.2f", td / 1000)) km"))
            }
            return s
        }
        return c.target > 0 ? Units.detail(c.detail, imp) : ""
    }
}

/// 머리: 제목 · ● 상태 줄 · n / 16 · 진행 막대
struct LiveHeader: View {
    let f: LiveFrame
    let status: String
    let live: Bool
    let idPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((f.mode == .training ? f.title : f.mode.name).l10n)
                        .font(F.t(17, .semibold)).foregroundStyle(.white).lineLimit(1)
                    HStack(spacing: 6) {
                        Circle().fill(live ? C.good : C.text3).frame(width: 6, height: 6)
                        Text(status.l10n).font(F.t(12)).foregroundStyle(C.text2).lineLimit(1)
                            .accessibilityIdentifier("\(idPrefix).status")
                    }
                }
                Spacer(minLength: 12)
                if !f.open {
                    Text("\(f.countNow) / \(f.countTotal)")
                        .font(F.num(12)).foregroundStyle(C.accent)
                        .padding(.horizontal, 8).frame(height: 22)
                        .overlay(Capsule().strokeBorder(C.accent.opacity(0.5), lineWidth: 1))
                        .accessibilityIdentifier("\(idPrefix).of")
                }
            }
            if !f.open { LiveProgress(idx: f.idx, count: f.countTotal, fraction: f.progress) }
        }
        .padding(.top, 8)
    }
}

/// TOTAL · 큰 전체 시간 · [아이콘 이름] · SPLIT | 오른쪽 칸 · 아래 줄
struct LiveBody: View {
    let f: LiveFrame
    let m: PhoneLiveMetrics
    let idPrefix: String

    var body: some View {
        let cur: Seg = f.cur
        let timeColor: Color = f.running ? .white : C.text2
        // 지금 하는 구간의 시간은 노랑 (전체 시간은 흰색), 목표를 넘기면 빨강
        let segColor: Color = !f.running ? C.text2 : (f.over ? C.bad : C.accent)
        // 빌드 24: 두 숫자를 조금 크게 (빈 공간이 많았음)
        let size: CGFloat = m.segFont * 0.88
        return VStack(spacing: 0) {
            Text("TOTAL").font(F.t(12, .semibold)).tracking(0.12 * 12).foregroundStyle(C.text2)
            Text(Fm.t(f.total))
                .font(F.num(m.totalFont)).tracking(-0.02 * m.totalFont)
                .foregroundStyle(timeColor).lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("\(idPrefix).total")
            HStack(spacing: 10) {
                Icon8(cur.icon, m.icon * 0.7, tint: cur.kind == .rox ? .mute : .yellow)
                Text(cur.name).font(F.t(m.nameFont, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.top, m.segTop * 0.6)
            HStack(alignment: .top, spacing: 0) {
                LiveCol(label: "SPLIT", value: Fm.t(f.segEl), color: segColor, size: size)
                    .accessibilityIdentifier("\(idPrefix).seg")
                // 가운데 세로선: 숫자 높이에 맞춤 (예전엔 숫자보다 아래로 길게 내려왔음)
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: size * 0.82).padding(.top, 18 + size * 0.14)
                if cur.kind == .run {
                    LiveCol(label: f.imperial ? "PACE /MI" : "PACE /KM", value: LivePace.text(el: f.segEl, dist: f.segDist, imperial: f.imperial, speed: f.speed), color: timeColor, size: size)
                } else if cur.target > 0 {
                    LiveCol(label: f.goalWord, value: Fm.t(cur.target), color: timeColor, size: size)
                        .accessibilityIdentifier("\(idPrefix).goal")
                } else {
                    LiveCol(label: "", value: Units.detail(cur.detail, f.imperial), color: C.text2, size: m.nameFont)
                }
            }
            .padding(.top, m.nameTop)
            Text(f.detailLine)
                .font(F.num(m.detailFont, .regular)).foregroundStyle(C.aeb)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: m.detailFont * 1.4)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 선 · NEXT [아이콘] 이름 (마지막이면 Finish)
struct LiveNextRow: View {
    let next: Seg?
    let m: PhoneLiveMetrics
    var dividerTop: CGFloat? = nil

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.top, dividerTop ?? m.dividerTop)
                .padding(.bottom, 14 * m.k)
            HStack(spacing: 12) {
                Text("NEXT").font(F.t(m.nextLabel)).tracking(0.1 * m.nextLabel).foregroundStyle(C.text2)
                if let nx = next {
                    Icon8(nx.icon, m.nextIcon, tint: nx.kind == .rox ? .mute : .yellow)
                    Text(nx.name).font(F.t(m.nextFont, .semibold)).lineLimit(1)
                        .accessibilityIdentifier("live.nextName")
                } else {
                    Text("Finish").font(F.t(m.nextFont, .semibold)).foregroundStyle(C.accent).lineLimit(1)
                }
            }
        }
    }
}
