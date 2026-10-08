import SwiftUI
import UIKit

// MARK: - 51번 · 운동이 끝났을 때 아래에서 올라오는 카드 (B안)
//
// 기록 상세 화면 위로 카드가 올라오고, 내리면 바로 그 기록 화면.
// 축하할 일(PB · 골드 · 목표 달성 · 대회 완주 · 첫 기록)이면 카드 위쪽 금색 빛 + 표시,
// 이상한 기록(Check)이면 축하 대신 "확인이 필요한 구간이 있어요" + Check splits.

extension Store {
    /// 같은 종류 (PB 를 겨루는 묶음)
    private func sameKind(_ a: Record, _ r: Record) -> Bool {
        guard a.mode == r.mode, a.counts else { return false }
        switch r.mode {
        case .training: return a.title == r.title && a.sets == r.sets && !a.isHIIT
        case .sim: return a.splits16 != nil
        case .race: return true
        case .pft: return a.pftSplits != nil
        }
    }

    /// 이 기록의 멘트 (저장된 뒤 불러도 됨: 이 기록보다 앞선 기록들과 비교)
    func cheer(for r: Record) -> Cheer { CheerPicker.pick(cheerInput(r)) }

    func cheerInput(_ r: Record) -> CheerInput {
        let before: [Record] = records.filter { $0.id != r.id && $0.date < r.date }
        var x = CheerInput(mode: r.mode, title: r.title, total: r.total, complete: r.isComplete,
                           check: r.flag == .check, start: r.date, end: r.end, seed: CheerPicker.seed(r.id))
        x.isHIIT = r.isHIIT
        x.isRun = r.isRunKind
        x.hiitRounds = r.isHIIT ? r.segs.count : 0
        x.runKm = r.runs.map { $0.dist ?? runMeters($0.detail) }.reduce(0, +) / 1000
        x.hiShare = r.source == "phone" ? nil : CheerPicker.hiShare(r.hr, settings: settings)
        x.firstEver = before.isEmpty
        if r.mode == .sim {
            x.firstFullSim = r.splits16 != nil && !before.contains { $0.mode == .sim && $0.splits16 != nil && $0.isComplete }
            if let last = before.filter({ $0.mode == .sim && $0.counts }).max(by: { $0.date < $1.date }) {
                x.lastDelta = r.total - last.total
            }
        }
        if r.mode == .race, let g = r.goal ?? r.vsTarget { x.goalDelta = r.total - g }
        if r.counts && !r.isHIIT {
            let same: [Int] = before.filter { sameKind($0, r) }.map(\.total)
            if let best = same.min(), r.total < best { x.pbDelta = r.total - best }
        }
        // 트레이닝: 이번에 최고 기록이 된 스테이션 (이전 최고가 있을 때만)
        if r.mode == .training && r.counts {
            var prev: [String: Int] = [:]
            for b in before where b.mode == .training && b.counts {
                for s in b.segs where s.kind == .st && SegKey.plausible(icon: s.icon, detail: s.detail, time: s.time) {
                    let k = SegKey.of(icon: s.icon, detail: s.detail)
                    prev[k] = min(prev[k] ?? .max, s.time)
                }
            }
            var gain = 0
            for s in r.segs where s.kind == .st && SegKey.plausible(icon: s.icon, detail: s.detail, time: s.time) {
                if let p = prev[SegKey.of(icon: s.icon, detail: s.detail)], s.time < p, p - s.time > gain {
                    gain = p - s.time
                    x.segBest = s.name
                }
            }
        }
        let cal = Calendar.current
        let day: Date = cal.startOfDay(for: r.date)
        if settings.event.isSet {
            let d = cal.dateComponents([.day], from: day, to: cal.startOfDay(for: settings.event.date)).day ?? -1
            if d >= 0 { x.daysToRace = d }
        }
        if let last = before.max(by: { $0.date < $1.date }) {
            x.daysSinceLast = cal.dateComponents([.day], from: cal.startOfDay(for: last.date), to: day).day
        }
        // 며칠 연속 (이 기록 날 포함)
        let days: Set<Date> = Set((before + [r]).map { cal.startOfDay(for: $0.date) })
        var streak = 0
        var cur = day
        while days.contains(cur) {
            streak += 1
            guard let p = cal.date(byAdding: .day, value: -1, to: cur) else { break }
            cur = p
        }
        x.streak = streak
        // 이번 주 (월요일 시작) 몇 번째
        var mon = Calendar(identifier: .gregorian)
        mon.firstWeekday = 2
        if let wk = mon.dateInterval(of: .weekOfYear, for: r.date) {
            x.weekCount = (before + [r]).filter { wk.contains($0.date) }.count
        }
        if r.mode == .pft {
            let prev: [Record] = before.filter { $0.mode == .pft && $0.counts && $0.pftSplits != nil }
            x.pftPrevBest = prev.map(\.total).min()
            x.pftEverGold = prev.contains { PFT.grade($0.total) == .gold }
        }
        return x
    }
}

/// 카드 띄우기 (아이폰으로 기록을 끝냈을 때 · 워치 기록이 도착했을 때)
extension Router {
    /// 기록 상세를 열고 그 위에 카드를 올림
    func showFinish(_ rec: Record, from: Scr) {
        open(rec, from: from)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.finish = rec }
    }

    /// 워치 기록이 도착함: 앱이 앞에 있고 다른 일을 하고 있지 않으면 바로, 아니면 다음에 앱을 열 때
    func queueFinish(_ rec: Record) {
        // 오래된 기록(백업 · 늦게 온 것)은 카드 없이
        guard Date().timeIntervalSince(rec.end) < 6 * 3600 else { return }
        pendingFinish = rec
        flushFinish()
    }

    func flushFinish() {
        guard let rec = pendingFinish else { return }
        guard UIApplication.shared.applicationState == .active, finish == nil,
              scr.showsTabs || scr == .detail || scr == .watchLive else { return }
        pendingFinish = nil
        let from: Scr
        switch rec.mode {
        case .training: from = .training
        case .pft, .sim: from = .sim
        case .race: from = .race
        }
        if rec.mode == .pft || rec.mode == .sim { testTab = rec.mode == .pft ? "pft" : "sim" }
        showFinish(rec, from: from)
    }
}

struct FinishSheet: View {
    let rec: Record
    let store = Store.shared
    let r = Router.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let c: Cheer = store.cheer(for: rec)
        let gold: Bool = c.tone == .celebrate
        return VStack(alignment: .leading, spacing: 0) {
            if let tag = c.tag { tagView(tag, tone: c.tone).padding(.bottom, 12) }
            Text(c.line).font(F.t(F.title2, .semibold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("finish.line")
            Text(sub).font(F.t(F.foot)).foregroundStyle(C.text2).lineLimit(1).padding(.top, 4)
            Text(Fm.t(rec.total)).font(F.num(46)).tracking(-0.02 * 46).foregroundStyle(gold ? Color(hex: 0xFFD54A) : .white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 14)
            HStack(spacing: 8) {
                ForEach(tiles, id: \.0) { t in tile(t.0, t.1, t.2) }
            }
            .padding(.top, 14)
            Spacer(minLength: 16)
            HStack(spacing: 10) {
                Button {
                    dismiss()
                    if c.tone != .check {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { r.go(.share) }
                    }
                } label: {
                    Text(c.tone == .check ? "Check splits" : "Share").font(F.t(17, .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(Press())
                .accessibilityIdentifier("finish.primary")
                Button { dismiss() } label: {
                    Text("Done").font(F.t(17, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(Press())
                .accessibilityIdentifier("finish.done")
            }
        }
        .padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .top) {
            if gold {
                RadialGradient(colors: [Color(hex: 0xFFD54A).opacity(0.38), Color(hex: 0xFFD54A).opacity(0)],
                               center: .top, startRadius: 0, endRadius: 320)
                    .frame(height: 300)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(c.tone == .check ? .warning : .success)
        }
    }

    /// "Full Simulation · Thu 8 Oct"
    private var sub: String {
        let name: String = rec.mode == .training ? rec.title : rec.mode.name.l10n
        return name + " · " + Fm.wdm.string(from: rec.date)
    }

    /// 타일 3개: 칼로리 · 평균 심박 · 러닝 페이스(없으면 최대 심박). 심박이 없으면(아이폰 기록) 구간 수
    private var tiles: [(String, String, String)] {
        var o: [(String, String, String)] = []
        if rec.kcal > 0 { o.append(("CALORIES", grouped(rec.kcal), "KCAL")) }
        if rec.avgHR > 0 { o.append(("AVG HR", "\(rec.avgHR)", "BPM")) }
        if let p = rec.runPace, rec.mode != .pft { o.append(("RUN PACE", Fm.t(p), "/KM")) }
        else if rec.maxHR > 0 { o.append(("MAX HR", "\(rec.maxHR)", "BPM")) }
        if o.count < 3 { o.append(("SPLITS", "\(rec.mainSegs.count)", "")) }
        return Array(o.prefix(3))
    }

    private func tile(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label8(label, size: F.cap2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(F.num(20)).lineLimit(1).minimumScaleFactor(0.7)
                if !unit.isEmpty { Text(unit).font(F.t(F.cap2, .semibold)).foregroundStyle(C.text2) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 12)
        .card8(14)
    }

    private func tagView(_ tag: String, tone: Cheer.Tone) -> some View {
        let fill: Color = tone == .check ? C.bad.opacity(0.18) : tone == .celebrate ? Color(hex: 0xFFD54A) : Color.white.opacity(0.12)
        let ink: Color = tone == .check ? C.bad : tone == .celebrate ? .black : .white
        let text: String = tag == "CHECK" ? "Check".l10n : tag.l10n
        return Text(text).font(F.t(F.cap1, .bold)).tracking(0.06 * 12).foregroundStyle(ink)
            .padding(.horizontal, 10).frame(height: 24)
            .background(fill, in: Capsule())
    }
}
