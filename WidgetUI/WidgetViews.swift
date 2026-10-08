import SwiftUI

// MARK: - 위젯 · 잠금 화면 실시간 표시의 모양 (53번 · 52번)
// 아이폰 위젯 확장과 앱(화면 확인용 미리보기)이 같이 씀. 위젯 바탕(containerBackground)은 위젯 쪽에서 붙임.

/// D-day 단계: 30일 넘게 0 · 30일 안 1 · 10일 안 2 · 대회 날 3 (앱 홈의 대회 카드와 같은 단계)
func ddayStage(_ d: Int?) -> Int {
    guard let d else { return 0 }
    return d == 0 ? 3 : d <= 10 ? 2 : d <= 30 ? 1 : 0
}

/// 대회가 가까울수록 진해지는 노란 기운 (오른쪽 아래) + 테두리
struct DdayGlow: View {
    let stage: Int
    var body: some View {
        let a: Double = [0.0, 0.14, 0.26, 0.48][min(3, max(0, stage))]
        GeometryReader { g in
            RadialGradient(colors: [C.accent.opacity(a), C.accent.opacity(0)], center: .bottomTrailing,
                           startRadius: 0, endRadius: max(g.size.width, g.size.height) * 0.9)
        }
    }
}

struct WidgetFlagLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.checkered").font(.system(size: 10, weight: .bold)).foregroundStyle(C.accent)
            Text(text.l10n).font(F.t(11, .semibold)).tracking(0.08 * 11).foregroundStyle(C.text2).lineLimit(1)
        }
    }
}

private func ddayText(_ d: Int) -> String { d == 0 ? "D-DAY" : "D-\(d)" }

/// "Sun 18 Oct" / 대회 날 "Today"
private func raceDay(_ s: WidgetSnap, _ d: Int) -> String {
    d == 0 ? "Today".l10n : (s.raceDate.map { Fm.wdm.string(from: $0) } ?? "")
}

// MARK: D-day 작게

struct DdaySmallView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        if let d = snap.daysLeft(now), let name = snap.raceName {
            VStack(alignment: .leading, spacing: 0) {
                WidgetFlagLabel(text: d == 0 ? "RACE DAY" : "NEXT RACE")
                Text(name).font(F.t(19, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.top, 6)
                Text(raceDay(snap, d)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                Spacer(minLength: 0)
                Text(ddayText(d)).font(F.num(d == 0 ? 34 : 44, .bold)).tracking(-0.03 * 44).foregroundStyle(C.accent)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.bottom, 9)           // 가안 고친 것: 9pt 올림
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            NoRaceView()
        }
    }
}

/// 대회가 없을 때: "Add a race"
struct NoRaceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetFlagLabel(text: "NEXT RACE")
            Spacer(minLength: 0)
            Text("Add a race").font(F.t(17, .semibold)).foregroundStyle(.white)
            Text("Count down to race day.").font(F.t(12)).foregroundStyle(C.text2).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: D-day 가로형 (목표 · 최고 기록 막대)

struct DdayMediumView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        if let d = snap.daysLeft(now), let name = snap.raceName {
            VStack(alignment: .leading, spacing: 0) {
                WidgetFlagLabel(text: d == 0 ? "RACE DAY" : "NEXT RACE")
                Text(name).font(F.t(19, .semibold)).foregroundStyle(.white).lineLimit(1).padding(.top, 6)
                Text(raceDay(snap, d) + (snap.division.isEmpty ? "" : " · " + snap.division))
                    .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                Spacer(minLength: 0)
                // D-day 와 GOAL · BEST 막대 묶음을 한 줄에, 세로 가운데 맞춤 (D-day 가운데 = GOAL 과 BEST 사이)
                HStack(alignment: .center, spacing: 16) {
                    Text(ddayText(d)).font(F.num(d == 0 ? 34 : 42, .bold)).tracking(-0.03 * 42).foregroundStyle(C.accent)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    bars.frame(width: 140)
                }
                .padding(.bottom, 9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            NoRaceView()
        }
    }

    private var bars: some View {
        let g: Int = snap.goal ?? 0, b: Int = snap.best ?? 0
        let mx: Double = Double(max(g, b, 1)) * 1.04
        return VStack(spacing: 9) {
            bar("GOAL", g, mx, C.accent)
            bar("BEST", b, mx, Color(hex: 0x8E8E93))
        }
    }

    private func bar(_ label: String, _ v: Int, _ mx: Double, _ c: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.l10n).font(F.t(10, .semibold)).tracking(0.8).foregroundStyle(C.text2)
                Spacer(minLength: 4)
                Text(v > 0 ? Fm.t(v) : "--:--").font(F.num(13)).foregroundStyle(.white).lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(c).frame(width: geo.size.width * CGFloat(Double(v) / mx))
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: 이번 주

/// 요일 막대 (막대 색 = 그날 한 운동 종류)
struct WeekBars: View {
    let snap: WidgetSnap
    var height: CGFloat = 46
    var labels = true
    var body: some View {
        let mx: Int = max(30, snap.dayMin.max() ?? 0)
        let days: [String] = ["M", "T", "W", "T", "F", "S", "S"]
        let today: Int = (WidgetSnap.monday.component(.weekday, from: Date()) + 5) % 7
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 3) {
                    let m: Int = snap.dayMin[i]
                    let c: Color = Mode(rawValue: snap.dayMode[i]).map { Color(hex: $0.calendarHex) } ?? Color.white.opacity(0.14)
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(c)
                        .frame(height: m > 0 ? max(8, height * CGFloat(m) / CGFloat(mx)) : 3)
                    if labels {
                        Text(days[i]).font(F.t(8, .semibold)).foregroundStyle(i == today ? .white : C.text3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: height + (labels ? 13 : 0), alignment: .bottom)
    }
}

private func hours(_ s: Int) -> String { String(format: "%d:%02d", s / 3600, (s % 3600) / 60) }

struct WeekSmallView: View {
    let snap: WidgetSnap
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK".l10n).font(F.t(11, .semibold)).tracking(0.9).foregroundStyle(C.text2)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(snap.weekCount)").font(F.num(40, .bold)).foregroundStyle(snap.weekCount > 0 ? .white : C.text2)
                Text("workouts".l10n).font(F.t(14)).foregroundStyle(C.text2)
            }
            .padding(.top, 4)
            Text(snap.weekCount > 0 ? "\(hours(snap.weekSec)) h · \(grouped0(snap.weekKcal)) kcal" : "Start your first one".l10n)
                .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            WeekBars(snap: snap, height: 26, labels: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WeekMediumView: View {
    let snap: WidgetSnap
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("THIS WEEK".l10n).font(F.t(11, .semibold)).tracking(0.9).foregroundStyle(C.text2)
                    Text(range).font(F.t(11)).foregroundStyle(C.text3)
                }
                Spacer(minLength: 6)
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        stat("WORKOUTS", "\(snap.weekCount)", "")
                        stat("CALORIES", grouped0(snap.weekKcal), "")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        stat("TIME", hours(snap.weekSec), "H")
                        stat("RUN", String(format: "%.1f", snap.weekRunKm), "KM")
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            WeekBars(snap: snap, height: 70)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var range: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: snap.weekStart) ?? snap.weekStart
        return Fm.dm.string(from: snap.weekStart) + " – " + Fm.dm.string(from: end)
    }

    private func stat(_ l: String, _ v: String, _ u: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l.l10n).font(F.t(9, .semibold)).tracking(0.7).foregroundStyle(C.text2).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(v).font(F.num(19)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if !u.isEmpty { Text(u.l10n).font(F.t(9, .semibold)).foregroundStyle(C.text2) }
            }
        }
    }
}

private func grouped0(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: 잠금 화면 (흰색만)

struct DdayInlineView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        if let d = snap.daysLeft(now), let n = snap.raceName {
            Text("\(Image(systemName: "flag.checkered")) \(n) · \(ddayText(d))")
        } else {
            Text("Add a race".l10n)
        }
    }
}

struct DdayRectView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        if let d = snap.daysLeft(now), let n = snap.raceName {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("NEXT RACE".l10n).font(.system(size: 10, weight: .semibold)).opacity(0.7)
                    Text(n).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(raceDay(snap, d)).font(.system(size: 12)).opacity(0.7).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(ddayText(d)).font(.system(size: 22, weight: .bold).monospacedDigit()).minimumScaleFactor(0.6)
            }
        } else {
            VStack(alignment: .leading) {
                Text("NEXT RACE".l10n).font(.system(size: 10, weight: .semibold)).opacity(0.7)
                Text("Add a race".l10n).font(.system(size: 15, weight: .semibold))
            }
        }
    }
}

struct DdayCircleView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        let d: Int? = snap.daysLeft(now)
        VStack(spacing: -1) {
            Text(d.map { $0 == 0 ? "GO" : "\($0)" } ?? "–").font(.system(size: 20, weight: .bold).monospacedDigit())
                .minimumScaleFactor(0.6)
            Text(d == 0 ? "RACE".l10n : "DAYS".l10n).font(.system(size: 8, weight: .semibold))
        }
    }
}

// MARK: - 잠금 화면 실시간 표시 (52번)

/// Live Activity 상태 (ActivityKit 없이도 쓰도록 따로 둠 — 앱 화면 확인용 미리보기)
struct LiveCardState: Codable, Hashable {
    var segName: String
    var segIcon: String
    var segDetail: String
    var nextName: String?
    var nextIcon: String?
    var idx: Int
    var count: Int
    /// 시계가 흐르는 기준: 지금 구간 · 전체가 시작된 시각 (일시정지 시간은 빼서 당겨 둠)
    var segStart: Date
    var totalStart: Date
    var paused: Bool
    var segSec: Int
    var totalSec: Int
    var hr: Int
    var zone: Int
    var kcal: Int
    var reconnecting: Bool = false
    var finished: Bool = false
}

/// 한 줄 막대 + 지금 자리에 빛나는 점 (A안 · 52번 진행 표시)
struct LiveProgress: View {
    let idx: Int
    let count: Int
    var height: CGFloat = 3
    var body: some View {
        GeometryReader { g in
            let f: CGFloat = count > 1 ? CGFloat(idx) / CGFloat(count - 1) : (count == 1 ? 0 : 0.5)
            let x: CGFloat = g.size.width * min(1, max(0, f))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16)).frame(height: height)
                Capsule().fill(C.accent).frame(width: max(height, x), height: height)
                Circle().fill(C.accent).frame(width: height * 3, height: height * 3)
                    .shadow(color: C.accent.opacity(0.9), radius: height * 2)
                    .offset(x: x - height * 1.5)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height * 3)
    }
}

/// 흐르는 시간 (멈췄으면 고정 숫자)
struct LiveClock: View {
    let start: Date
    let paused: Bool
    let fixed: Int
    var body: some View {
        if paused {
            Text(Fm.t(fixed))
        } else {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        }
    }
}

/// 잠금 화면 카드 (다이내믹 아일랜드를 길게 눌렀을 때도 같은 내용)
struct LiveLockView: View {
    let title: String
    let s: LiveCardState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Wordmark(size: 13)
                Spacer(minLength: 8)
                Text(title.l10n + (s.count > 0 ? " · \(min(s.idx + 1, s.count)) / \(s.count)" : ""))
                    .font(F.t(11, .medium)).foregroundStyle(C.text2).lineLimit(1)
            }
            HStack(alignment: .center, spacing: 10) {
                Icon8(s.segIcon, 26, tint: .yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.reconnecting ? "Reconnecting…".l10n : s.segName).font(F.t(16, .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(s.segDetail).font(F.t(11)).foregroundStyle(C.text2).lineLimit(1)
                }
                Spacer(minLength: 4)
                LiveClock(start: s.segStart, paused: s.paused, fixed: s.segSec)
                    .font(F.num(32)).foregroundStyle(s.paused ? C.text2 : C.accent)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 120, alignment: .trailing)
            }
            if s.count > 0 { LiveProgress(idx: s.idx, count: s.count) }
            HStack(spacing: 6) {
                Text("TOTAL".l10n).font(F.t(10, .semibold)).foregroundStyle(C.text2)
                LiveClock(start: s.totalStart, paused: s.paused, fixed: s.totalSec)
                    .font(F.num(14)).foregroundStyle(.white).frame(maxWidth: 70, alignment: .leading)
                if s.hr > 0 {
                    Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(C.hr)
                    Text("\(s.hr)").font(F.num(14)).foregroundStyle(.white)
                }
                Spacer(minLength: 4)
                if let n = s.nextName {
                    Text("NEXT".l10n).font(F.t(10, .semibold)).foregroundStyle(C.text2)
                    if let i = s.nextIcon { Icon8(i, 13, tint: .white) }
                    Text(n).font(F.t(13, .semibold)).foregroundStyle(.white).lineLimit(1)
                }
            }
        }
        .padding(16)
    }
}
