import SwiftUI
import WidgetKit

/// Medium Home Screen widget: up to three rhythms side by side.
struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RhythmsOverview", provider: RhythmProvider()) { entry in
            OverviewView(entry: entry)
                .containerBackground(for: .widget) { Theme.card }
        }
        .configurationDisplayName("All rhythms")
        .description("Your first three countdowns at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct OverviewView: View {
    var entry: RhythmEntry

    var body: some View {
        let rhythms = Array(entry.rhythms.sorted { $0.sortOrder < $1.sortOrder }.prefix(3))
        if rhythms.isEmpty {
            EmptyWidget()
        } else {
            HStack(alignment: .top, spacing: 12) {
                ForEach(rhythms) { r in
                    let d = CardDisplay(r, now: entry.date)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: r.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(r.color.color)
                            Text(r.name).font(.rhythm(12, .bold)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        if d.isDone {
                            Text("Done").font(.rhythm(20, .heavy)).foregroundStyle(Theme.done)
                        } else {
                            Text(d.value).font(.rhythm(20, .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        }
                        Text(d.isDone ? "new period soon" : d.valueLabel)
                            .font(.rhythm(11))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        WidgetBar(fill: d.fill, color: d.isDone ? r.color.color.opacity(0.35) : r.color.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
