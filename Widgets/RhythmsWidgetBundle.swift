import SwiftUI
import WidgetKit

@main
struct RhythmsWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusRhythmWidget()
        HabitRingsWidget()
        OverviewWidget()
        RhythmLiveActivityWidget()
    }
}

// MARK: Timeline

struct RhythmEntry: TimelineEntry {
    let date: Date
    let rhythms: [RhythmSnapshot]

    var mostUrgent: RhythmSnapshot? { rhythms.byUrgency(at: date).first }

    static let samples: [RhythmSnapshot] = {
        let now = Date.now
        return [
            RhythmSnapshot(id: UUID(), name: "Brush teeth", actionLabel: "Brushed", symbol: "mouth", colorKey: "teal",
                           kind: .sinceLast, logs: [now.addingTimeInterval(-5 * 3600)]),
            RhythmSnapshot(id: UUID(), name: "Surprise her", actionLabel: "Surprised her", symbol: "heart", colorKey: "amber",
                           kind: .period, periodDays: 14, periodStart: now.addingTimeInterval(-7 * 86_400)),
            RhythmSnapshot(id: UUID(), name: "Go for a run", actionLabel: "Ran", symbol: "figure.run", colorKey: "blue",
                           kind: .period, periodDays: 3, periodStart: now.addingTimeInterval(-86_400), logs: [now]),
        ]
    }()
}

struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: .now, rhythms: RhythmEntry.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            completion(RhythmEntry(date: .now, rhythms: Store.snapshots()))
        }
    }

    /// Bars and countdowns are computed per entry, so one entry every 10 minutes keeps them moving.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        Task { @MainActor in
            let rhythms = Store.snapshots()
            let now = Date.now
            let entries = (0..<36).map { i in
                RhythmEntry(date: now.addingTimeInterval(Double(i) * 600), rhythms: rhythms)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

// MARK: Shared pieces

struct WidgetBar: View {
    var fill: Double
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: max(height, geo.size.width * min(max(fill, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

struct EmptyWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rhythms").font(.rhythm(15, .heavy))
            Text("Add a countdown in the app.").font(.rhythm(12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
