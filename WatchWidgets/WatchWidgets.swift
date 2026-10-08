import WidgetKit
import SwiftUI

// MARK: - 워치 컴플리케이션 (53번): 다음 대회 D-day — 동그란 칸 · 긴 칸
// 워치 앱이 아이폰에서 설정을 받을 때 공용 폴더에 써 둔 요약(WidgetSnap)을 읽음. 누르면 워치 앱이 열림.

@main
struct Splits8WatchWidgetBundle: WidgetBundle {
    var body: some Widget { WatchDdayWidget() }
}

struct WSnapEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnap
}

struct WSnapProvider: TimelineProvider {
    func placeholder(in context: Context) -> WSnapEntry { WSnapEntry(date: Date(), snap: .demo()) }

    func getSnapshot(in context: Context, completion: @escaping (WSnapEntry) -> Void) {
        completion(WSnapEntry(date: Date(), snap: context.isPreview ? .demo() : (WidgetSnap.load() ?? .demo())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WSnapEntry>) -> Void) {
        let now = Date()
        let s: WidgetSnap = WidgetSnap.load() ?? WidgetSnap()
        let cal = Calendar.current
        var entries: [WSnapEntry] = [WSnapEntry(date: now, snap: s)]
        var day: Date = cal.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            entries.append(WSnapEntry(date: next, snap: s))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WatchDdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "splits8.watch.dday", provider: WSnapProvider()) { e in
            WatchDdayView(e: e)
        }
        .configurationDisplayName("Next race")
        .description("Days to your next race.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchDdayView: View {
    let e: WSnapEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let d: Int? = e.snap.daysLeft(e.date)
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: -2) {
                        Text(d.map { $0 == 0 ? "GO" : "\($0)" } ?? "–")
                            .font(.system(size: 20, weight: .bold).monospacedDigit()).minimumScaleFactor(0.6)
                            .foregroundStyle(Color(hex: 0xFFE600))
                        Text("D-DAY").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            case .accessoryInline:
                if let d, let n = e.snap.raceName {
                    Text("\(n) · \(d == 0 ? "D-DAY" : "D-\(d)")")
                } else {
                    Text("Add a race".l10n)
                }
            default:
                if let d, let n = e.snap.raceName {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered").foregroundStyle(Color(hex: 0xFFE600))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("NEXT RACE".l10n).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                            Text(n).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text(e.snap.raceDate.map { Fm.wdm.string(from: $0) } ?? "").font(.system(size: 12))
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        Text(d == 0 ? "D-DAY" : "D-\(d)").font(.system(size: 20, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color(hex: 0xFFE600)).minimumScaleFactor(0.6)
                    }
                } else {
                    VStack(alignment: .leading) {
                        Text("NEXT RACE".l10n).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text("Add a race".l10n).font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
