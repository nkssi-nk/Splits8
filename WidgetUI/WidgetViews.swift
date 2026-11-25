import SwiftUI
import WidgetKit        // 빌드 24: .widgetAccentable() (앱 · 위젯 확장 둘 다 이 파일을 씀)

// MARK: - 위젯 · 잠금 화면 실시간 표시의 모양 (53번 · 52번)
// 아이폰 위젯 확장과 앱(화면 확인용 미리보기)이 같이 씀. 위젯 바탕(containerBackground)은 위젯 쪽에서 붙임.

// MARK: - 빌드 24 · 위젯 바탕 고르기 (자동 / 검정 / 흰색 / 테마 색)
// 흰 바탕에서는 노란 글자가 안 보이므로 D-day 숫자 · GOAL 막대는 진한 황토(#8A7400), 글자는 검정, 빛은 연한 노랑.

struct WPal {
    var fg: Color
    var sub: Color
    var dim: Color
    var accent: Color
    var glow: Color
    var track: Color
    var bg: Color
    var light: Bool

    static let dark = WPal(fg: .white, sub: C.text2, dim: C.text3, accent: C.accent, glow: C.accent,
                           track: Color.white.opacity(0.12), bg: Color(hex: 0x0C0C0C), light: false)
    static let light = WPal(fg: .black, sub: Color(hex: 0x6E6E73), dim: Color(hex: 0xAEAEB2), accent: Color(hex: 0x8A7400),
                            glow: Color(hex: 0xFFE600), track: Color.black.opacity(0.10), bg: .white, light: true)
    /// 테마 색 바탕: 그 색을 진하게 깐 어두운 바탕 (글자는 흰색, 강조는 테마 색 밝게)
    static func theme(_ hex: UInt32) -> WPal {
        var p = WPal.dark
        p.bg = Color(hex: blendHex(hex, 0x000000, 0.72))
        p.accent = hex == 0xFFE600 ? C.accent : Color(hex: blendHex(hex, 0xFFFFFF, 0.25))
        p.glow = Color(hex: hex)
        p.track = Color.white.opacity(0.16)
        p.sub = Color.white.opacity(0.68)
        p.dim = Color.white.opacity(0.42)
        return p
    }

    /// look: auto / black / white / theme
    static func of(_ look: String, scheme: ColorScheme, themeHex: UInt32?) -> WPal {
        switch look {
        case "black": return .dark
        case "white": return .light
        case "theme": return .theme(themeHex ?? 0xFFE600)
        default: return scheme == .light ? .light : .dark
        }
    }
}

/// 두 색 섞기 (iOS 17 에는 Color.mix 가 없음). t = b 쪽 비율
func blendHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    func ch(_ v: UInt32, _ sh: UInt32) -> Double { Double((v >> sh) & 0xFF) }
    func mixc(_ sh: UInt32) -> UInt32 { UInt32((ch(a, sh) * (1 - t) + ch(b, sh) * t).rounded()) << sh }
    return mixc(16) | mixc(8) | mixc(0)
}

private struct WPalKey: EnvironmentKey { static let defaultValue: WPal = .dark }
extension EnvironmentValues {
    var wpal: WPal {
        get { self[WPalKey.self] }
        set { self[WPalKey.self] = newValue }
    }
}

/// 위젯 바탕 (고른 색 + 대회가 가까울수록 빛)
struct WidgetBackdrop: View {
    let stage: Int
    @Environment(\.wpal) private var pal
    var body: some View {
        ZStack {
            pal.bg
            DdayGlow(stage: stage)
        }
    }
}

/// D-day 단계: 30일 넘게 0 · 30일 안 1 · 10일 안 2 · 대회 날 3 (앱 홈의 대회 카드와 같은 단계)
func ddayStage(_ d: Int?) -> Int {
    guard let d else { return 0 }
    return d == 0 ? 3 : d <= 10 ? 2 : d <= 30 ? 1 : 0
}

/// 대회가 가까울수록 진해지는 노란 기운 (오른쪽 아래) + 테두리
struct DdayGlow: View {
    @Environment(\.wpal) private var pal
    let stage: Int
    var body: some View {
        let a: Double = [0.0, 0.14, 0.26, 0.48][min(3, max(0, stage))]
        GeometryReader { g in
            RadialGradient(colors: [pal.glow.opacity(pal.light ? a * 0.9 : a), pal.glow.opacity(0)], center: .bottomTrailing,
                           startRadius: 0, endRadius: max(g.size.width, g.size.height) * 0.9)
        }
    }
}

struct WidgetFlagLabel: View {
    @Environment(\.wpal) private var pal
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.checkered").font(.system(size: 10, weight: .bold)).foregroundStyle(pal.accent)
            Text(text.l10n).font(F.t(11, .semibold)).tracking(0.08 * 11).foregroundStyle(pal.sub).lineLimit(1)
        }
    }
}

private func ddayText(_ d: Int) -> String { d == 0 ? "D-DAY" : "D-\(d)" }

/// "Sun 18 Oct" / 대회 날 "Today"
private func raceDay(_ s: WidgetSnap, _ d: Int) -> String {
    d == 0 ? "Today".l10n : (s.raceDate.map { Fm.wdm.string(from: $0) } ?? "")
}

// MARK: D-day 작게 · 가로 (1.2.8 새 디자인 — 대표님 11-24 · 25)
// 대회 정보는 작게 만큼만: 깃발 HYROX RACE · 대회 이름 · 날짜 · Division · D-170. 위젯 글자는 모두 영어.
// 내용 묶음을 위아래 가운데 (위 여백 = 아래 여백). 가로형은 세로 선 오른쪽에 고른 칸 (폭 134).

/// "HYROX RACE" 앞 깃발 = 앱 Race 아이콘 (modeRace, 노랑)
struct WidgetRaceFlag: View {
    @Environment(\.wpal) private var pal
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image("modeRace").resizable().renderingMode(.template).scaledToFit()
                .frame(width: 12, height: 12).foregroundStyle(pal.accent).widgetAccentable()
            Text(text).font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(pal.sub).lineLimit(1)
        }
    }
}

/// "Thu, May 13" (위젯은 영어)
private let enDay: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.dateFormat = "EEE, MMM d"
    return f
}()

/// 대회 정보 묶음 (작게 · 가로 왼쪽 같음)
struct DdayInfoBlock: View {
    @Environment(\.wpal) private var pal
    let snap: WidgetSnap
    let d: Int
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetRaceFlag(text: d == 0 ? "RACE DAY" : "HYROX RACE")
            Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(pal.fg)
                .lineLimit(1).minimumScaleFactor(0.8).padding(.top, 4)
            Text(d == 0 ? "Today" : (snap.raceDate.map { enDay.string(from: $0) } ?? ""))
                .font(.system(size: 11.5)).foregroundStyle(pal.sub).lineLimit(1)
            if !snap.division.isEmpty {
                Text(snap.division).font(.system(size: 11.5)).foregroundStyle(pal.sub).lineLimit(1).minimumScaleFactor(0.85)
            }
            DdayText.text(ddayText(d), size: 48, weight: .bold)
                .tracking(-1.6).foregroundStyle(pal.accent).widgetAccentable()
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 8)
        }
    }
}

struct DdaySmallView: View {
    let snap: WidgetSnap
    let now: Date
    var body: some View {
        if let d = snap.daysLeft(now), let name = snap.raceName {
            DdayInfoBlock(snap: snap, d: d, name: name)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            NoRaceView()
        }
    }
}

/// 대회가 없을 때: "Add a race"
struct NoRaceView: View {
    @Environment(\.wpal) private var pal
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetFlagLabel(text: "HYROX RACE")
            Spacer(minLength: 0)
            Text("Add a race").font(F.t(17, .semibold)).foregroundStyle(pal.fg)
            Text("Count down to race day.").font(F.t(12)).foregroundStyle(pal.sub).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: D-day 가로형 — 왼쪽 대회 정보 + 세로 선 + 오른쪽 고른 칸 (today / weeks / week / last / best)

struct DdayMediumView: View {
    @Environment(\.wpal) private var pal
    let snap: WidgetSnap
    let now: Date
    var side: String = "today"

    var body: some View {
        if let d = snap.daysLeft(now), let name = snap.raceName {
            HStack(alignment: .center, spacing: 12) {
                DdayInfoBlock(snap: snap, d: d, name: name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                Rectangle().fill(pal.light ? Color.black.opacity(0.12) : Color(hex: 0x262626)).frame(width: 1)
                    .padding(.vertical, -2)
                // 오른쪽 칸: 이름표는 "HYROX RACE" 와 같은 줄, 아래끝은 D-170 아래끝과 같게 (왼쪽 묶음 높이에 맞춤)
                DdayInfoBlock(snap: snap, d: d, name: name).hidden()
                    .frame(width: 134, alignment: .leading)
                    .overlay(alignment: .topLeading) { WidgetSidePanel(snap: snap, now: now, side: side) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NoRaceView()
        }
    }
}

/// 가로형 오른쪽 칸
struct WidgetSidePanel: View {
    @Environment(\.wpal) private var pal
    let snap: WidgetSnap
    let now: Date
    let side: String

    private var r: WidgetSnap.Right { snap.right ?? WidgetSnap.Right() }
    private var blue: Color { Color(hex: 0x1E78FA) }
    private var kcalCol: Color { pal.light ? Color(hex: 0xAEAEB2) : Color(hex: 0xE5E5EA) }
    private func kindCol(_ k: String) -> Color { k == "run" ? blue : pal.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(pal.sub).lineLimit(1)
                .frame(height: 14, alignment: .center)
            Spacer(minLength: 6)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var title: String {
        switch side {
        case "weeks": return "LAST 4 WEEKS"
        case "week": return "THIS WEEK"
        case "last": return "LAST WORKOUT"
        case "best": return "BEST vs GOAL"
        default: return "TODAY"
        }
    }

    private func mix(_ parts: [(String, Bool)]) -> Text {
        parts.reduce(Text("")) { t, p in
            t + Text(p.0).font(.system(size: 11.5, weight: p.1 ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(p.1 ? pal.fg : pal.sub)
        }
    }

    @ViewBuilder private var content: some View {
        switch side {
        case "weeks": weeks
        case "week": week
        case "last": last
        case "best": best
        default: today
        }
    }

    // TODAY 링 3개: 바깥 노랑 = 하이록스 연습 시간 · 가운데 파랑 = 러닝 km · 안쪽 연회색 = 칼로리. 꽉 참 = 지난 28일 운동한 날 평균
    private var today: some View {
        HStack(spacing: 8) {
            ZStack {
                ring(Double(r.todayHyroxSec) / Double(max(1, r.avgHyroxSec)), pal.accent, inset: 0)
                ring(r.todayRunKm / max(0.1, r.avgRunKm), blue, inset: 9.5)
                ring(Double(r.todayKcal) / Double(max(1, r.avgKcal)), kcalCol, inset: 19)
            }
            .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 6) {
                mix([("\(r.todayHyroxSec / 60)", true), (" min", false)])
                mix([(String(format: "%.1f", r.todayRunKm), true), (" km", false)])
                mix([(grouped0(r.todayKcal), true), (" kcal", false)])
            }
            .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func ring(_ f: Double, _ c: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(c.opacity(0.2), lineWidth: 7)
            Circle().trim(from: 0, to: min(1, max(0, f)))
                .stroke(c, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if f > 1 {
                Circle().trim(from: 0, to: min(1, f - 1))
                    .stroke(c, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
        }
        .padding(inset + 3.5)
        .widgetAccentable()
    }

    // 지난 4주 점 달력 (월요일 시작): 노랑 = 하이록스 연습 · 파랑 = 러닝만 · 빈칸 = 쉰 날 · 오늘 = 흰 테두리
    private var weeks: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let mon: Date = WidgetSnap.monday.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let start: Date = cal.date(byAdding: .day, value: -21, to: cal.startOfDay(for: mon)) ?? today
        return VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let i: Int = row * 7 + col
                            let day: Date = cal.date(byAdding: .day, value: i, to: start) ?? start
                            let k: String = r.last28.indices.contains(i) ? r.last28[i] : ""
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(day > today ? Color.clear : (k == "" ? pal.track : kindCol(k)))
                                .overlay {
                                    if cal.isDate(day, inSameDayAs: today) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(pal.fg, lineWidth: 1.5)
                                    }
                                }
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            mix([("\(r.count28)", true), (" workouts · ", false), ("\(r.streak)", true), (" streak", false)])
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // 이번 주 요일 막대 (지금 이번 주 위젯 막대와 같음)
    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            mix([("\(snap.weekCount)", true), (" workouts · ", false), (hours(snap.weekSec), true), (" h", false)])
                .lineLimit(1).minimumScaleFactor(0.8)
            WeekBars(snap: snap, height: 44)
        }
    }

    // 최근 운동
    @ViewBuilder private var last: some View {
        if let n = r.lastName {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(kindCol(r.lastKind)).frame(width: 6, height: 6)
                    Text(n).font(.system(size: 14, weight: .semibold)).foregroundStyle(pal.fg).lineLimit(1).minimumScaleFactor(0.85)
                }
                Text(ago(r.lastDate)).font(.system(size: 11.5)).foregroundStyle(pal.sub).lineLimit(1)
                Spacer(minLength: 4)
                Text(Fm.t(r.lastSec)).font(.system(size: 26, weight: .bold).monospacedDigit()).tracking(-0.8)
                    .foregroundStyle(pal.fg).lineLimit(1).minimumScaleFactor(0.7)
                if let v = r.lastVsGoal {
                    (Text((v <= 0 ? "−" : "+") + Fm.t(abs(v))).font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(v <= 0 ? pal.accent : pal.sub)
                     + Text(" vs goal").font(.system(size: 11.5)).foregroundStyle(pal.sub))
                        .lineLimit(1).padding(.top, 3)
                }
            }
        } else {
            Text("No workout yet").font(.system(size: 11.5)).foregroundStyle(pal.sub)
        }
    }

    private func ago(_ d: Date?) -> String {
        guard let d else { return "" }
        let cal = Calendar.current
        let n: Int = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day ?? 0
        return n <= 0 ? "Today" : n == 1 ? "Yesterday" : "\(n) days ago"
    }

    // 최고 기록 vs 목표 + 가장 늦은 구간
    @ViewBuilder private var best: some View {
        if let g = snap.goal, let b = snap.best, g > 0, b > 0 {
            VStack(alignment: .leading, spacing: 4) {
                row("Best", Fm.t(b), pal.fg)
                row("Goal", Fm.t(g), pal.accent)
                Spacer(minLength: 2)
                if let wn = r.weakName, r.weakDiff > 0 {
                    Text("Weakest").font(.system(size: 11.5)).foregroundStyle(pal.sub)
                    HStack(alignment: .firstTextBaseline) {
                        Text(wn).font(.system(size: 13, weight: .semibold)).foregroundStyle(kindCol(r.weakKind)).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text("+" + Fm.t(r.weakDiff)).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(pal.sub)
                    }
                }
            }
        } else {
            Text("Set a goal in Race").font(.system(size: 11.5)).foregroundStyle(pal.sub)
        }
    }

    private func row(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(l).font(.system(size: 11.5)).foregroundStyle(pal.sub)
            Spacer(minLength: 4)
            Text(v).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(c)
        }
    }
}

// MARK: 이번 주

/// 요일 막대 (막대 색 = 그날 한 운동 종류)
struct WeekBars: View {
    @Environment(\.wpal) private var pal
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
                    // 1.2.8: 하이록스 연습 = 노랑 · 러닝만 = 파랑 (예전 값(Mode)은 노랑)
                    let k: String = snap.dayMode[i]
                    let c: Color = k.isEmpty ? pal.track : (k == "run" ? Color(hex: 0x1E78FA) : pal.accent)
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(c)
                        .frame(height: m > 0 ? max(8, height * CGFloat(m) / CGFloat(mx)) : 3)
                    if labels {
                        Text(days[i]).font(F.t(8, .semibold)).foregroundStyle(i == today ? pal.fg : pal.dim)
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
    @Environment(\.wpal) private var pal
    let snap: WidgetSnap
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK".l10n).font(F.t(11, .semibold)).tracking(0.9).foregroundStyle(pal.sub)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(snap.weekCount)").font(F.num(40, .bold)).foregroundStyle(snap.weekCount > 0 ? pal.fg : pal.sub)
                Text("workouts".l10n).font(F.t(14)).foregroundStyle(pal.sub)
            }
            .padding(.top, 4)
            Text(snap.weekCount > 0 ? "\(hours(snap.weekSec)) h · \(grouped0(snap.weekKcal)) kcal" : "Start your first one".l10n)
                .font(F.t(13)).foregroundStyle(pal.sub).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            WeekBars(snap: snap, height: 26, labels: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WeekMediumView: View {
    @Environment(\.wpal) private var pal
    let snap: WidgetSnap
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("THIS WEEK".l10n).font(F.t(11, .semibold)).tracking(0.9).foregroundStyle(pal.sub)
                        .lineLimit(1).fixedSize()
                    Text(range).font(F.t(11)).foregroundStyle(pal.dim).lineLimit(1).minimumScaleFactor(0.8)
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
            Text(l.l10n).font(F.t(9, .semibold)).tracking(0.7).foregroundStyle(pal.sub).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(v).font(F.num(19)).foregroundStyle(pal.fg).lineLimit(1).minimumScaleFactor(0.7)
                if !u.isEmpty { Text(u.l10n).font(F.t(9, .semibold)).foregroundStyle(pal.sub) }
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
        // 1.2.8 (대표님 11-24): "D-170" 은 늘 한 줄 (자리를 먼저 차지), 위 "HYROX 대회" 이름표는 뺌
        if let d = snap.daysLeft(now), let n = snap.raceName {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(n).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(raceDay(snap, d)).font(.system(size: 12)).opacity(0.7).lineLimit(1).minimumScaleFactor(0.8)
                    if !snap.division.isEmpty {
                        Text(snap.division).font(.system(size: 12)).opacity(0.7).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                DdayText.text(ddayText(d), size: 22, weight: .bold)
                    .lineLimit(1).fixedSize()
                    .layoutPriority(1)
            }
        } else {
            VStack(alignment: .leading) {
                Text("HYROX RACE".l10n).font(.system(size: 10, weight: .semibold)).opacity(0.7)
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
    /// 빌드 24: 막대 자리 (Roxzone 동안 반 칸). nil 이면 idx 로
    var progress: Double? = nil
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
    /// 1.2.7: 지금 구간 목표 (GOAL · BEST 칸, 0 · nil = 없음) · 이름표 ("GOAL" / "BEST")
    var segTarget: Int? = nil
    var goalWord: String? = nil

    /// 1.2.7: 구간 색 (워치 · 폰 운동 중 화면과 같은 뜻) — Roxzone · 휴식 회색, 러닝 파랑, 그 외 노랑
    var tone: W8Tone {
        if segIcon == "roxzone" || segIcon == "rest" { return .gray }
        return segIcon == "run" ? .run : .station
    }
}

/// 한 줄 막대 + 지금 자리에 빛나는 점 (A안 · 52번 진행 표시)
struct LiveProgress: View {
    let idx: Int
    let count: Int
    var height: CGFloat = 3
    /// 빌드 24: 자리를 직접 줌 (0~1, Roxzone 동안 반 칸 등). nil 이면 idx / (count − 1)
    var fraction: Double? = nil
    var body: some View {
        GeometryReader { g in
            let f: CGFloat = fraction.map { CGFloat($0) } ?? (count > 1 ? CGFloat(idx) / CGFloat(count - 1) : (count == 1 ? 0 : 0.5))
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

/// 1.2.7 잠금 화면 카드 (B안, 대표님 11-20): 바탕 = 지금 구간 색 + 흐린 덩어리, 종목 아이콘 없음.
/// 위 줄: 왼쪽 [이름 18 Bold / 무게 · 거리 12] · 오른쪽 [TOTAL 값 18 / "TOTAL" 11] — 좌우 두 줄 대칭.
/// 가운데: SPLIT · GOAL · ♥ BPM (러닝은 GOAL 대신 없음) 값 32. 아래: 진행 점 (왼쪽) · Next 이름 (오른쪽).
struct LiveLockView: View {
    let title: String
    let s: LiveCardState

    var body: some View {
        let t: W8Tone = s.tone
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.reconnecting ? "Reconnecting…".l10n : s.segName).font(F.t(18, .bold)).foregroundStyle(t.ink).lineLimit(1)
                    Text(s.segDetail.isEmpty ? title.l10n : s.segDetail).font(F.t(12, .semibold)).foregroundStyle(t.sub).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    LiveClock(start: s.totalStart, paused: s.paused, fixed: s.totalSec)
                        .font(F.num(18, .semibold)).foregroundStyle(t.ink)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 110, alignment: .trailing)
                    Text("TOTAL".l10n).font(F.t(11, .bold)).tracking(0.8).foregroundStyle(t.label)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 0) {
                cell("SPLIT".l10n, t) {
                    LiveClock(start: s.segStart, paused: s.paused, fixed: s.segSec)
                }
                if let g = s.segTarget, g > 0, s.segIcon != "run", s.segIcon != "rest" {
                    cell((s.goalWord ?? "GOAL").l10n, t) { Text(Fm.t(g)) }
                }
                if s.hr > 0 {
                    cell("♥ " + "BPM".l10n, t) { Text("\(s.hr)") }
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                if s.count > 1 { dots(t) }
                Spacer(minLength: 4)
                if let n = s.nextName {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("Next".l10n).font(F.t(12, .semibold)).foregroundStyle(t.label)
                        Text(n).font(F.t(14, .bold)).foregroundStyle(t.ink).lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background {
            ZStack {
                LinearGradient(colors: t.stops, startPoint: .top, endPoint: .bottom)
                W8Blobs(seed: s.idx &+ 7, color: t.blob, alpha: t == .station ? 0.38 : 0.22, blurPt: 22)
            }
        }
    }

    private func cell<V: View>(_ label: String, _ t: W8Tone, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 2) {
            Text(label).font(F.t(11, .bold)).tracking(0.6).foregroundStyle(t.label).lineLimit(1)
            value()
                .font(F.num(32, .semibold)).foregroundStyle(t.ink)
                .multilineTextAlignment(.center)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func dots(_ t: W8Tone) -> some View {
        let n: Int = min(s.count, 24)
        let cur: Int = min(max(0, s.idx), n - 1)
        return HStack(spacing: n > 10 ? 3.5 : 6) {
            ForEach(0..<n, id: \.self) { i in
                if i == cur {
                    Capsule().fill(t.ink).frame(width: 11, height: 4)
                } else {
                    Circle().fill(i < cur ? t.ink : t.dotOff).frame(width: 4, height: 4)
                }
            }
        }
    }
}
