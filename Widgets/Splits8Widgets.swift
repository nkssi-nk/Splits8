import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - 아이폰 위젯 확장 (53번 위젯 + 52번 잠금 화면 실시간 표시)

@main
struct Splits8WidgetBundle: WidgetBundle {
    var body: some Widget {
        DdayWidget()
        WeekWidget()
        Splits8LiveActivity()
    }
}

// MARK: 시간표 (자정마다 새로 그림 — D-day 와 이번 주가 바뀌므로)

struct SnapEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnap
}

struct SnapProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapEntry { SnapEntry(date: Date(), snap: .demo()) }

    func getSnapshot(in context: Context, completion: @escaping (SnapEntry) -> Void) {
        let s: WidgetSnap = context.isPreview ? .demo() : (WidgetSnap.load() ?? .demo())
        completion(SnapEntry(date: Date(), snap: s.fresh(Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapEntry>) -> Void) {
        let now = Date()
        let s: WidgetSnap = WidgetSnap.load() ?? WidgetSnap()
        let cal = Calendar.current
        var entries: [SnapEntry] = [SnapEntry(date: now, snap: s.fresh(now))]
        var day: Date = cal.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            entries.append(SnapEntry(date: next, snap: s.fresh(next)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// 위젯 바탕: 거의 검정 + 대회가 가까울수록 노란 기운
private struct WidgetBG: View {
    let stage: Int
    var body: some View {
        ZStack {
            Color(hex: 0x0C0C0C)
            DdayGlow(stage: stage)
        }
    }
}

// MARK: D-day

struct DdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "splits8.dday", provider: SnapProvider()) { e in
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
        Group {
            switch family {
            case .systemMedium: DdayMediumView(snap: e.snap, now: e.date)
            case .accessoryInline: DdayInlineView(snap: e.snap, now: e.date)
            case .accessoryRectangular: DdayRectView(snap: e.snap, now: e.date)
            case .accessoryCircular: DdayCircleView(snap: e.snap, now: e.date)
            default: DdaySmallView(snap: e.snap, now: e.date)
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium { WidgetBG(stage: stage) } else { Color.clear }
        }
        .widgetURL(URL(string: "splits8://race"))
    }
}

// MARK: 이번 주

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "splits8.week", provider: SnapProvider()) { e in
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
        Group {
            if family == .systemMedium { WeekMediumView(snap: e.snap) } else { WeekSmallView(snap: e.snap) }
        }
        .containerBackground(for: .widget) { WidgetBG(stage: 0) }
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
                        if s.count > 0 { LiveProgress(idx: s.idx, count: s.count) }
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
