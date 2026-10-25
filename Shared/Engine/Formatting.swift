import Foundation

enum Formatting {
    /// "6d 14h", "2h 50m", "45m", "0m".
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
        return "\(minutes)m"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Today", "Yesterday", or "Mon, Oct 19".
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Oct 18 – Nov 1"
    static func range(_ start: Date, _ end: Date) -> String {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Every 8 h", "Every 2 weeks", "Every 3 days".
    static func cadence(_ r: RhythmSnapshot) -> String {
        switch r.kind {
        case .sinceLast:
            let base = hours(r.intervalHours)
            return r.flexHours > 0 ? "Every \(base)–\(hours(r.intervalHours + r.flexHours)) h" : "Every \(base) h"
        case .period:
            return "Every \(days(r.periodDays))"
        }
    }

    static func days(_ n: Int) -> String {
        if n % 7 == 0 {
            let weeks = n / 7
            return weeks == 1 ? "week" : "\(weeks) weeks"
        }
        return n == 1 ? "day" : "\(n) days"
    }

    static func hours(_ h: Double) -> String {
        h.rounded() == h ? String(Int(h)) : String(format: "%.1f", h)
    }

    /// "9:00 AM" for minutes after midnight.
    static func clock(minutes: Int) -> String {
        var c = DateComponents()
        c.hour = minutes / 60
        c.minute = minutes % 60
        let date = Calendar.current.date(from: c) ?? .now
        return time(date)
    }
}
