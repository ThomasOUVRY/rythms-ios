import Foundation

/// Text and numbers for a rhythm, shared by the Home card and the widgets.
struct CardDisplay {
    var subtitle: String
    var value: String
    var valueLabel: String
    var hint: String
    /// Compact wording for the Lock Screen: "Brush in 2h 50m".
    var inline: String
    var fill: Double
    var isDone: Bool

    init(_ r: RhythmSnapshot, now: Date) {
        switch r.state(at: now) {
        case .sinceLast(let s):
            subtitle = "\(Formatting.cadence(r)) · since last time"
            fill = s.fill
            isDone = false
            hint = "Rests at 12% — never runs dry"
            switch s.phase {
            case .waiting:
                value = Formatting.duration(s.windowStart.timeIntervalSince(now))
                valueLabel = "until your window opens"
                inline = "\(r.name) in \(value)"
            case .open:
                value = Formatting.duration(s.windowEnd.timeIntervalSince(now))
                valueLabel = "left in your window"
                inline = "\(r.name): window open"
            case .late:
                value = "Whenever"
                valueLabel = "you're ready"
                inline = "\(r.name) whenever you're ready"
            }
        case .period(let p):
            subtitle = "\(Formatting.cadence(r)) · period \(p.number)"
            fill = p.fill
            isDone = p.isDone
            value = Formatting.duration(p.end.timeIntervalSince(now))
            valueLabel = "left · resets \(Formatting.shortDate(p.end))"
            hint = p.isDone
                ? "\(Formatting.duration(p.end.timeIntervalSince(now))) until a new period starts"
                : "Not yet this period"
            inline = p.isDone ? "\(r.name): done" : "\(r.name): \(value) left"
        }
    }
}

extension Array where Element == RhythmSnapshot {
    /// Most urgent first; done periods sink to the bottom.
    func byUrgency(at now: Date = .now) -> [RhythmSnapshot] {
        sorted { $0.urgency(at: now) < $1.urgency(at: now) }
    }
}
