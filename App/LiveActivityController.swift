import ActivityKit
import Foundation

/// Starts, updates and ends Lock Screen countdowns so they match which rhythms are due.
/// iOS only lets an app start one while it's running, so this syncs whenever the app becomes active
/// or handles a notification or Lock Screen button.
enum LiveActivityController {
    @MainActor
    static func sync(_ snapshots: [RhythmSnapshot], now: Date = .now) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let wanted = snapshots.filter { $0.remindersOn && $0.nudgeStyle == .live && $0.isDue(at: now) }
        let wantedIDs = Set(wanted.map(\.id.uuidString))

        for activity in Activity<RhythmActivityAttributes>.activities where !wantedIDs.contains(activity.attributes.rhythmID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        for rhythm in wanted {
            let state = contentState(for: rhythm, now: now)
            let content = ActivityContent(state: state, staleDate: state.end)
            if let existing = Activity<RhythmActivityAttributes>.activities.first(where: { $0.attributes.rhythmID == rhythm.id.uuidString }) {
                await existing.update(content)
            } else {
                let attributes = RhythmActivityAttributes(
                    rhythmID: rhythm.id.uuidString,
                    name: rhythm.name,
                    colorKey: rhythm.colorKey,
                    symbol: rhythm.symbol,
                    actionLabel: rhythm.actionLabel
                )
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        }
    }

    static func contentState(for r: RhythmSnapshot, now: Date) -> RhythmActivityAttributes.ContentState {
        switch r.state(at: now) {
        case .sinceLast(let s):
            let window = "Window \(Formatting.time(s.windowStart)) – \(Formatting.time(s.windowEnd))"
            if s.phase == .late {
                // Past the window: keep a short, calm countdown rather than a stale bar.
                return .init(start: now, end: now.addingTimeInterval(3600), headline: "Whenever you're ready", window: window)
            }
            return .init(start: s.windowStart, end: max(s.windowEnd, s.windowStart.addingTimeInterval(60)), headline: "Window open", window: window)
        case .period(let p):
            let start = p.end.addingTimeInterval(-r.dueStretch(for: p))
            return .init(start: start, end: p.end, headline: "Last stretch of period \(p.number)", window: "Resets \(Formatting.shortDate(p.end))")
        }
    }
}
