import Foundation

/// One notification the app intends to deliver. Pure data, so the plan can be unit tested.
struct PlannedNudge: Equatable, Sendable {
    enum Kind: String, Sendable {
        case nudge, followUp, checkpoint, reset
    }

    var id: String
    var rhythmID: UUID
    var date: Date
    var title: String
    var body: String
    var kind: Kind
    /// Follow-ups and snoozes: ranked above other notifications.
    var emphasized: Bool
}

/// Works out which nudges a rhythm should get from now on. Re-run whenever anything changes.
enum ReminderPlanner {
    static func plan(
        for r: RhythmSnapshot,
        now: Date,
        settings: ReminderSettings,
        calendar: Calendar = .current
    ) -> [PlannedNudge] {
        guard r.remindersOn else { return [] }
        let raw: [PlannedNudge]
        switch r.kind {
        case .sinceLast: raw = planSinceLast(r, now: now, settings: settings, calendar: calendar)
        case .period: raw = planPeriod(r, now: now, settings: settings, calendar: calendar)
        }
        return raw
            .compactMap { adjust($0, settings: settings, calendar: calendar) }
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
    }

    // MARK: Since last time

    private static func planSinceLast(_ r: RhythmSnapshot, now: Date, settings: ReminderSettings, calendar: Calendar) -> [PlannedNudge] {
        let s = r.sinceLastState(at: now)
        var nudgeDate = s.windowStart
        if let minutes = settings.minutes(for: r.anchor) {
            // Tie the nudge to the routine moment if it falls in or just after the window.
            let routine = nextOccurrence(minutes: minutes, onOrAfter: s.windowStart, calendar: calendar)
            if routine <= s.windowEnd.addingTimeInterval(2 * 3600) {
                nudgeDate = routine
            }
        }

        let seed = seed(for: nudgeDate)
        var out = [
            make(r, .nudge, nudgeDate, NudgeCopy.sinceLastNudge(r, seed: seed, vary: settings.varyWording)),
        ]
        if r.nudgeStyle != .quiet {
            let follow = nudgeDate.addingTimeInterval(3600)
            out.append(make(r, .followUp, follow, NudgeCopy.sinceLastFollowUp(r, seed: seed, vary: settings.varyWording), emphasized: true))
        }
        return out
    }

    // MARK: Repeating period

    private static func planPeriod(_ r: RhythmSnapshot, now: Date, settings: ReminderSettings, calendar: Calendar) -> [PlannedNudge] {
        let current = r.periodIndex(at: now, calendar: calendar)
        let minutes = settings.minutes(for: r.anchor) ?? r.anchorMinutes
        let length = max(r.periodDays, 1)
        let checkpoints = r.checkpoints
            .filter { $0.day >= 1 && $0.day <= length }
            .sorted { $0.day < $1.day }

        var out: [PlannedNudge] = []
        // Plan this period and the next, so nudges keep coming even if the app isn't opened.
        for index in [current, current + 1] {
            let (start, end) = r.periodBounds(index, calendar: calendar)
            let done = index == current && r.doneAt(period: index, calendar: calendar) != nil

            if !done {
                var lastNudge: Date?
                if checkpoints.isEmpty {
                    let daysIn = max(0, length - (length >= 4 ? 2 : 1))
                    let day = calendar.date(byAdding: .day, value: daysIn, to: start) ?? start
                    let date = clock(minutes: minutes, on: day, calendar: calendar)
                    out.append(make(r, .nudge, date, NudgeCopy.periodNudge(r, seed: seed(for: date), vary: settings.varyWording), index: index))
                    lastNudge = date
                } else {
                    for cp in checkpoints {
                        let day = calendar.date(byAdding: .day, value: cp.day - 1, to: start) ?? start
                        let date = clock(minutes: minutes, on: day, calendar: calendar)
                        out.append(make(r, .checkpoint, date, (r.name, cp.text), index: index))
                        lastNudge = date
                    }
                }
                if r.nudgeStyle != .quiet, let last = lastNudge {
                    let follow = last.addingTimeInterval(3600)
                    out.append(make(r, .followUp, follow, NudgeCopy.periodFollowUp(r, seed: seed(for: follow), vary: settings.varyWording), emphasized: true, index: index))
                }
            }

            if index == current {
                let resetDate = clock(minutes: minutes, on: end, calendar: calendar)
                let nextEnd = r.periodBounds(index + 1, calendar: calendar).end
                out.append(make(r, .reset, resetDate, NudgeCopy.reset(r, until: nextEnd), index: index))
            }
        }
        return out
    }

    // MARK: Adjustments

    /// Applies pause and quiet hours. Reset notices survive a pause; everything else is dropped.
    static func adjust(_ n: PlannedNudge, settings: ReminderSettings, calendar: Calendar) -> PlannedNudge? {
        if settings.isPaused(at: n.date), n.kind != .reset { return nil }
        guard settings.quietHoursOn, isQuiet(n.date, settings: settings, calendar: calendar) else { return n }
        var moved = n
        moved.date = quietEnd(after: n.date, settings: settings, calendar: calendar)
        return moved
    }

    static func isQuiet(_ date: Date, settings: ReminderSettings, calendar: Calendar) -> Bool {
        let m = minutesOfDay(date, calendar: calendar)
        let start = settings.quietStartMinutes, end = settings.quietEndMinutes
        if start == end { return false }
        return start > end ? (m >= start || m < end) : (m >= start && m < end)
    }

    static func quietEnd(after date: Date, settings: ReminderSettings, calendar: Calendar) -> Date {
        let sameDay = clock(minutes: settings.quietEndMinutes, on: date, calendar: calendar)
        if sameDay > date { return sameDay }
        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    // MARK: Helpers

    static func clock(minutes: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func nextOccurrence(minutes: Int, onOrAfter date: Date, calendar: Calendar) -> Date {
        let candidate = clock(minutes: minutes, on: date, calendar: calendar)
        if candidate >= date { return candidate }
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }

    static func minutesOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func seed(for date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 3600)
    }

    private static func make(
        _ r: RhythmSnapshot,
        _ kind: PlannedNudge.Kind,
        _ date: Date,
        _ copy: (title: String, body: String),
        emphasized: Bool = false,
        index: Int? = nil
    ) -> PlannedNudge {
        let stamp = Int(date.timeIntervalSince1970)
        let suffix = index.map { ".p\($0)" } ?? ""
        return PlannedNudge(
            id: "\(NotificationIDs.prefix)\(r.id.uuidString).\(kind.rawValue)\(suffix).\(stamp)",
            rhythmID: r.id,
            date: date,
            title: copy.title,
            body: copy.body,
            kind: kind,
            emphasized: emphasized
        )
    }
}

enum NotificationIDs {
    static let prefix = "rhythm."

    static func category(_ id: UUID) -> String { "\(prefix)\(id.uuidString)" }
    static func snooze(_ id: UUID) -> String { "\(prefix)\(id.uuidString).snooze" }
    static func home(_ id: UUID) -> String { "\(prefix)\(id.uuidString).home" }

    enum Action {
        static let log = "log"
        static let snooze20 = "snooze20"
        static let snoozeHour = "snoozeHour"
        static let snoozeHome = "snoozeHome"
    }
}
