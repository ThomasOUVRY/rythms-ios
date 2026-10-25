import AppIntents
import SwiftUI
import WidgetKit

/// The most urgent rhythm: Home Screen small widget with its button, plus the wide and inline Lock Screen spots.
/// The round Lock Screen spot is `HabitRingsWidget`, which follows habits you choose.
struct FocusRhythmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusRhythm", provider: RhythmProvider()) { entry in
            FocusRhythmView(entry: entry)
                .containerBackground(for: .widget) { Theme.card }
        }
        .configurationDisplayName("Next up")
        .description("The rhythm that needs you soonest, with its button.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct FocusRhythmView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RhythmEntry

    var body: some View {
        if let rhythm = entry.mostUrgent {
            let display = CardDisplay(rhythm, now: entry.date)
            switch family {
            case .accessoryRectangular: rectangular(rhythm, display)
            case .accessoryInline: Label(display.inline, systemImage: rhythm.symbol)
            default: small(rhythm, display)
            }
        } else if family == .systemSmall {
            EmptyWidget()
        } else {
            Text("Rhythms")
        }
    }

    private func small(_ r: RhythmSnapshot, _ d: CardDisplay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IconTile(symbol: r.symbol, color: r.color, size: 32)
                Spacer()
                Text(r.name).font(.rhythm(12, .bold)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            if d.isDone {
                Label("Done", systemImage: "checkmark").font(.rhythm(22, .heavy)).foregroundStyle(Theme.done)
                Text(d.hint).font(.rhythm(11)).foregroundStyle(Theme.muted).lineLimit(2)
            } else {
                Text(d.value).font(.rhythm(24, .heavy)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                Text(d.valueLabel).font(.rhythm(11)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            WidgetBar(fill: d.fill, color: r.color.color)
            if !d.isDone {
                Button(intent: LogRhythmIntent(rhythmID: r.id)) {
                    Text(r.actionLabel)
                        .font(.rhythm(13, .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(Theme.onInk)
                        .background(Theme.inkButton, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    private func rectangular(_ r: RhythmSnapshot, _ d: CardDisplay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(r.name, systemImage: r.symbol)
                .font(.rhythm(13, .bold))
                .widgetAccentable()
            Text(d.isDone ? "Done this period" : "\(d.value) \(d.kindWord)")
                .font(.rhythm(16, .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ProgressView(value: d.fill)
                .tint(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension CardDisplay {
    /// Short tail for the rectangular widget: "6d 14h left", "2h 50m to go".
    var kindWord: String {
        valueLabel.hasPrefix("until") ? "to go" : "left"
    }
}
