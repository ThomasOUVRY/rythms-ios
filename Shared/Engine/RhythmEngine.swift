import Foundation

/// The share of a since-last bar that never drains away.
let sinceLastFloor = 0.12

enum SinceLastPhase: Equatable, Sendable {
    /// Before the good window opens.
    case waiting
    /// Inside the good window.
    case open
    /// Past the window; the bar rests at its floor until the next log.
    case late
}

struct SinceLastState: Equatable, Sendable {
    var last: Date
    var windowStart: Date
    var windowEnd: Date
    var fill: Double
    var phase: SinceLastPhase
}

struct PeriodState: Equatable, Sendable {
    /// 0-based index; shown to people as `index + 1`.
    var index: Int
    var start: Date
    var end: Date
    var fill: Double
    var doneAt: Date?

    var number: Int { index + 1 }
    var isDone: Bool { doneAt != nil }
}

struct PastPeriod: Identifiable, Equatable, Sendable {
    var index: Int
    var start: Date
    var end: Date
    var doneAt: Date?

    var id: Int { index }
    var number: Int { index + 1 }
}

enum RhythmState: Equatable, Sendable {
    case sinceLast(SinceLastState)
    case period(PeriodState)
}

extension RhythmSnapshot {
    func state(at now: Date = .now, calendar: Calendar = .current) -> RhythmState {
        switch kind {
        case .sinceLast: .sinceLast(sinceLastState(at: now))
        case .period: .period(periodState(at: now, calendar: calendar))
        }
    }

    // MARK: Since last time

    var lastLog: Date? { logs.max() }

    func sinceLastState(at now: Date) -> SinceLastState {
        let last = lastLog ?? createdAt
        let interval = max(intervalHours, 0.1) * 3600
        let windowStart = last.addingTimeInterval(interval)
        let windowEnd = windowStart.addingTimeInterval(max(flexHours, 0) * 3600)
        let elapsed = now.timeIntervalSince(last)
        let remaining = min(max(1 - elapsed / interval, 0), 1)
        let fill = sinceLastFloor + (1 - sinceLastFloor) * remaining

        let phase: SinceLastPhase
        if now < windowStart {
            phase = .waiting
        } else if now < windowEnd {
            phase = .open
        } else {
            phase = .late
        }
        return SinceLastState(last: last, windowStart: windowStart, windowEnd: windowEnd, fill: fill, phase: phase)
    }

    // MARK: Repeating period

    func periodIndex(at now: Date, calendar: Calendar = .current) -> Int {
        let origin = calendar.startOfDay(for: periodStart)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: origin, to: today).day ?? 0
        return max(0, days) / max(periodDays, 1)
    }

    func periodBounds(_ index: Int, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let origin = calendar.startOfDay(for: periodStart)
        let length = max(periodDays, 1)
        let start = calendar.date(byAdding: .day, value: index * length, to: origin) ?? origin
        let end = calendar.date(byAdding: .day, value: length, to: start) ?? start
        return (start, end)
    }

    func doneAt(period index: Int, calendar: Calendar = .current) -> Date? {
        let (start, end) = periodBounds(index, calendar: calendar)
        return logs.filter { $0 >= start && $0 < end }.max()
    }

    func periodState(at now: Date, calendar: Calendar = .current) -> PeriodState {
        let index = periodIndex(at: now, calendar: calendar)
        let (start, end) = periodBounds(index, calendar: calendar)
        let total = end.timeIntervalSince(start)
        let fill: Double
        if now < start {
            fill = 1
        } else {
            fill = min(max(end.timeIntervalSince(now) / total, 0), 1)
        }
        return PeriodState(index: index, start: start, end: end, fill: fill, doneAt: doneAt(period: index, calendar: calendar))
    }

    func pastPeriods(at now: Date = .now, limit: Int = 8, calendar: Calendar = .current) -> [PastPeriod] {
        let current = periodIndex(at: now, calendar: calendar)
        guard current > 0 else { return [] }
        let lowest = max(0, current - limit)
        return (lowest..<current).reversed().map { i in
            let (start, end) = periodBounds(i, calendar: calendar)
            return PastPeriod(index: i, start: start, end: end, doneAt: doneAt(period: i, calendar: calendar))
        }
    }

    // MARK: Shared

    /// Fraction of the bar or ring that is full.
    func fill(at now: Date = .now) -> Double {
        switch state(at: now) {
        case .sinceLast(let s): s.fill
        case .period(let p): p.fill
        }
    }

    /// Seconds until this needs attention; lower is more urgent. Used to sort and to pick a widget's rhythm.
    func urgency(at now: Date = .now) -> TimeInterval {
        switch state(at: now) {
        case .sinceLast(let s):
            return s.windowStart.timeIntervalSince(now)
        case .period(let p):
            return p.isDone ? .greatestFiniteMagnitude / 2 : p.end.timeIntervalSince(now)
        }
    }

    /// Whether the rhythm currently wants attention — the window is open or late, or the period's last stretch is undone.
    func isDue(at now: Date = .now) -> Bool {
        switch state(at: now) {
        case .sinceLast(let s):
            return s.phase != .waiting
        case .period(let p):
            return !p.isDone && p.end.timeIntervalSince(now) <= dueStretch(for: p)
        }
    }

    /// The last part of a period that counts as "due": two days, or half a short period.
    func dueStretch(for p: PeriodState) -> TimeInterval {
        min(2 * 86_400, p.end.timeIntervalSince(p.start) / 2)
    }
}
