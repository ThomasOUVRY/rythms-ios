import AppIntents
import SwiftUI
import WidgetKit

/// Rings for the habits you pick, like the Lock Screen gauge.
/// Home Screen small (up to four rings) and the round Lock Screen spot (one ring).
struct HabitRingsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HabitRings", intent: PickRhythmsIntent.self, provider: HabitRingsProvider()) { entry in
            HabitRingsView(entry: entry)
                .containerBackground(for: .widget) { Theme.card }
        }
        .configurationDisplayName("Habit rings")
        .description("One to four habits as rings. Touch and hold, then Edit Widget to choose which.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct HabitRingsEntry: TimelineEntry {
    let date: Date
    let rhythms: [RhythmSnapshot]
}

struct HabitRingsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitRingsEntry {
        HabitRingsEntry(date: .now, rhythms: Array(RhythmEntry.samples.prefix(limit(context.family))))
    }

    func snapshot(for configuration: PickRhythmsIntent, in context: Context) async -> HabitRingsEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return HabitRingsEntry(date: .now, rhythms: await pick(configuration, limit: limit(context.family)))
    }

    func timeline(for configuration: PickRhythmsIntent, in context: Context) async -> Timeline<HabitRingsEntry> {
        let rhythms = await pick(configuration, limit: limit(context.family))
        let now = Date.now
        let entries = (0..<36).map { i in
            HabitRingsEntry(date: now.addingTimeInterval(Double(i) * 600), rhythms: rhythms)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func limit(_ family: WidgetFamily) -> Int {
        family == .accessoryCircular ? 1 : 4
    }

    /// The chosen habits in the order picked, skipping deleted ones.
    /// With nothing chosen, the ones that need you soonest.
    @MainActor
    private func pick(_ configuration: PickRhythmsIntent, limit: Int) -> [RhythmSnapshot] {
        let all = Store.snapshots()
        let chosen = (configuration.rhythms ?? []).compactMap { entity in all.first { $0.id == entity.id } }
        let list = chosen.isEmpty ? all.byUrgency() : chosen
        return Array(list.prefix(limit))
    }
}

struct HabitRingsView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HabitRingsEntry

    var body: some View {
        if family == .accessoryCircular {
            circular
        } else {
            switch entry.rhythms.count {
            case 0: EmptyWidget()
            case 1: single(entry.rhythms[0])
            case 2: pair
            default: grid
            }
        }
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let r = entry.rhythms.first {
            let d = CardDisplay(r, now: entry.date)
            Gauge(value: d.fill) {
                Image(systemName: r.symbol)
            } currentValueLabel: {
                Image(systemName: d.isDone ? "checkmark" : r.symbol)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
            .accessibilityLabel(label(r, d))
        } else {
            Image(systemName: "circle.dashed")
        }
    }

    // MARK: Home Screen

    /// One habit: a big ring with the time left and name.
    private func single(_ r: RhythmSnapshot) -> some View {
        let d = CardDisplay(r, now: entry.date)
        return VStack(spacing: 8) {
            HabitRing(rhythm: r, display: d, lineWidth: 10, iconSize: 26)
                .padding(4)
            VStack(spacing: 1) {
                Text(d.isDone ? "Done" : d.value)
                    .font(.rhythm(15, .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(r.name)
                    .font(.rhythm(11, .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label(r, d))
    }

    /// Two habits side by side.
    private var pair: some View {
        HStack(spacing: 10) {
            ForEach(entry.rhythms) { r in
                cell(r, ringSize: 60, lineWidth: 7, iconSize: 18, showName: true)
            }
        }
    }

    /// Three or four habits in a 2×2 grid.
    private var grid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(entry.rhythms) { r in
                cell(r, ringSize: 48, lineWidth: 6, iconSize: 15, showName: false)
            }
        }
    }

    private func cell(_ r: RhythmSnapshot, ringSize: CGFloat, lineWidth: CGFloat, iconSize: CGFloat, showName: Bool) -> some View {
        let d = CardDisplay(r, now: entry.date)
        return VStack(spacing: 3) {
            HabitRing(rhythm: r, display: d, lineWidth: lineWidth, iconSize: iconSize)
                .frame(width: ringSize, height: ringSize)
            Text(d.isDone ? "Done" : Self.short(r, now: entry.date))
                .font(.rhythm(11, .heavy))
                .monospacedDigit()
                .lineLimit(1)
            if showName {
                Text(r.name)
                    .font(.rhythm(10, .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label(r, d))
    }

    private func label(_ r: RhythmSnapshot, _ d: CardDisplay) -> String {
        d.isDone ? "\(r.name), done" : "\(r.name), \(d.value) \(d.valueLabel)"
    }

    /// Tight wording for small rings: "6d", "2h", "45m", "Now".
    static func short(_ r: RhythmSnapshot, now: Date) -> String {
        let seconds: TimeInterval
        switch r.state(at: now) {
        case .sinceLast(let s):
            switch s.phase {
            case .waiting: seconds = s.windowStart.timeIntervalSince(now)
            case .open, .late: return "Now"
            }
        case .period(let p):
            seconds = p.end.timeIntervalSince(now)
        }
        let minutes = Int(max(0, seconds) / 60)
        if minutes >= 1440 { return "\(minutes / 1440)d" }
        if minutes >= 60 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }
}

/// A ring in the habit's color with its icon in the middle; a checkmark once done.
struct HabitRing: View {
    var rhythm: RhythmSnapshot
    var display: CardDisplay
    var lineWidth: CGFloat
    var iconSize: CGFloat

    var body: some View {
        let color = rhythm.color
        ZStack {
            Circle().stroke(color.tint, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(display.fill, 0), 1))
                .stroke(display.isDone ? color.color.opacity(0.35) : color.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: display.isDone ? "checkmark" : rhythm.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(display.isDone ? Theme.done : color.color)
        }
        .padding(lineWidth / 2)
    }
}
