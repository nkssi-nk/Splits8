import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - 아이폰 위젯 확장 (53번 위젯 + 52번 잠금 화면 실시간 표시)

@main
struct Splits8WidgetBundle: WidgetBundle {
    var body: some Widget {
        DdayWidget()
        WeekWidget()
        Splits8LiveActivity()
    }
}

// MARK: 빌드 24 · 위젯 바탕 고르기 (위젯 길게 누르기 → 위젯 편집)

enum WidgetLook: String, AppEnum {
    case auto, black, white, theme
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Background" }
    static var caseDisplayRepresentations: [WidgetLook: DisplayRepresentation] {
        [.auto: "Automatic", .black: "Black", .white: "White", .theme: "Theme color"]
    }
}

struct WidgetLookIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Background" }
    static var description: IntentDescription { "Choose the widget background." }
    @Parameter(title: "Background", default: .auto)
    var look: WidgetLook
}

// MARK: 시간표 (자정마다 새로 그림 — D-day 와 이번 주가 바뀌므로)

struct SnapEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnap
    var look: WidgetLook = .auto
}

struct SnapProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SnapEntry { SnapEntry(date: Date(), snap: .demo()) }

    func snapshot(for configuration: WidgetLookIntent, in context: Context) async -> SnapEntry {
        let s: WidgetSnap = context.isPreview ? .demo() : (WidgetSnap.load() ?? .demo())
        return SnapEntry(date: Date(), snap: s.fresh(Date()), look: configuration.look)
    }

    func timeline(for configuration: WidgetLookIntent, in context: Context) async -> Timeline<SnapEntry> {
        let now = Date()
        let s: WidgetSnap = WidgetSnap.load() ?? WidgetSnap()
        let cal = Calendar.current
        var entries: [SnapEntry] = [SnapEntry(date: now, snap: s.fresh(now), look: configuration.look)]
        var day: Date = cal.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            entries.append(SnapEntry(date: next, snap: s.fresh(next), look: configuration.look))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

/// 고른 바탕 → 글자 색 묶음 (자동은 아이폰 라이트/다크 모드를 따라감)
private struct LookWrap<V: View>: View {
    let e: SnapEntry
    let stage: Int
    let full: Bool
    @ViewBuilder let content: () -> V
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var mode
    var body: some View {
        // 색조(tinted) · 흑백 모드에서는 시스템이 색을 바꾸므로 어두운 기본 묶음으로
        let pal: WPal = mode == .fullColor ? WPal.of(e.look.rawValue, scheme: scheme, themeHex: e.snap.themeHex) : .dark
        content()
            .environment(\.wpal, pal)
            .containerBackground(for: .widget) {
                if full { WidgetBackdrop(stage: stage).environment(\.wpal, pal) } else { Color.clear }
            }
    }
}

// MARK: D-day

struct DdayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "splits8.dday", intent: WidgetLookIntent.self, provider: SnapProvider()) { e in
            DdayEntryView(e: e)
        }
        .configurationDisplayName("Next race")
        .description("Days to your next race.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}

struct DdayEntryView: View {
    let e: SnapEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let stage: Int = ddayStage(e.snap.daysLeft(e.date))
        LookWrap(e: e, stage: stage, full: family == .systemSmall || family == .systemMedium) {
            switch family {
            case .systemMedium: DdayMediumView(snap: e.snap, now: e.date)
            case .accessoryInline: DdayInlineView(snap: e.snap, now: e.date)
            case .accessoryRectangular: DdayRectView(snap: e.snap, now: e.date)
            case .accessoryCircular: DdayCircleView(snap: e.snap, now: e.date)
            default: DdaySmallView(snap: e.snap, now: e.date)
            }
        }
        .widgetURL(URL(string: "splits8://race"))
    }
}

// MARK: 이번 주

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "splits8.week", intent: WidgetLookIntent.self, provider: SnapProvider()) { e in
            WeekEntryView(e: e)
        }
        .configurationDisplayName("This week")
        .description("Workouts, time and calories this week.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeekEntryView: View {
    let e: SnapEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        LookWrap(e: e, stage: 0, full: true) {
            if family == .systemMedium { WeekMediumView(snap: e.snap) } else { WeekSmallView(snap: e.snap) }
        }
        .widgetURL(URL(string: "splits8://home"))
    }
}

// MARK: 잠금 화면 · 다이내믹 아일랜드 (워치 운동 중)

struct Splits8LiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Splits8Activity.self) { ctx in
            LiveLockView(title: ctx.attributes.title, s: ctx.state)
                .activityBackgroundTint(Color(hex: 0x111111))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let s = ctx.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Icon8(s.segIcon, 24, tint: .yellow)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(s.segName).font(F.t(15, .semibold)).lineLimit(1)
                            Text(s.segDetail).font(F.t(11)).foregroundStyle(C.text2).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveClock(start: s.segStart, paused: s.paused, fixed: s.segSec)
                        .font(F.num(28)).foregroundStyle(C.accent)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 100, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if s.count > 0 { LiveProgress(idx: s.idx, count: s.count, fraction: s.progress) }
                        HStack(spacing: 6) {
                            Text("TOTAL").font(F.t(10, .semibold)).foregroundStyle(C.text2)
                            LiveClock(start: s.totalStart, paused: s.paused, fixed: s.totalSec)
                                .font(F.num(14)).frame(maxWidth: 70, alignment: .leading)
                            if s.hr > 0 {
                                Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(C.hr)
                                Text("\(s.hr)").font(F.num(14))
                            }
                            Spacer(minLength: 4)
                            if let n = s.nextName {
                                Text("NEXT").font(F.t(10, .semibold)).foregroundStyle(C.text2)
                                if let i = s.nextIcon { Icon8(i, 13, tint: .white) }
                                Text(n).font(F.t(13, .semibold)).lineLimit(1)
                            }
                        }
                    }
                }
            } compactLeading: {
                Icon8(s.segIcon, 18, tint: .yellow)
            } compactTrailing: {
                LiveClock(start: s.segStart, paused: s.paused, fixed: s.segSec)
                    .font(F.num(14)).foregroundStyle(C.accent)
                    .frame(maxWidth: 52)
            } minimal: {
                Icon8(s.segIcon, 16, tint: .yellow)
            }
            .keylineTint(C.accent)
        }
    }
}
