import Foundation

/// Notification wording. Several variants per moment, so the brain doesn't learn to tune them out.
/// Tone rules: no guilt, no "missed", always an easy next step.
enum NudgeCopy {
    typealias Copy = (title: String, body: String)

    static func sinceLastNudge(_ r: RhythmSnapshot, seed: Int, vary: Bool) -> Copy {
        (r.name, pick([
            "Your window's open. Two minutes, then it's off your mind.",
            "Good moment for it — the window just opened.",
            "Whenever you're ready. Tap \(r.actionLabel) when it's done.",
            "It's that time again. Quick one, then you're free.",
        ], seed, vary))
    }

    static func sinceLastFollowUp(_ r: RhythmSnapshot, seed: Int, vary: Bool) -> Copy {
        (r.name, pick([
            "Still a good moment. Want to knock it out now?",
            "Gentle second nudge — the window's still open.",
            "Last nudge for this one. Do it now, or snooze to a better moment.",
        ], seed, vary))
    }

    static func periodNudge(_ r: RhythmSnapshot, seed: Int, vary: Bool) -> Copy {
        (r.name, pick([
            "This period is winding down. Is today the day?",
            "A couple of days left in this period. Small counts.",
            "What's the plan for this one? Even something simple works.",
        ], seed, vary))
    }

    static func periodFollowUp(_ r: RhythmSnapshot, seed: Int, vary: Bool) -> Copy {
        (r.name, pick([
            "Following up — even something small counts.",
            "One more nudge, then I'll leave it with you.",
            "Still time this period. Pick the easiest version.",
        ], seed, vary))
    }

    static func reset(_ r: RhythmSnapshot, until end: Date) -> Copy {
        // Formatting.days gives "week", "2 weeks", "3 days" → "A fresh 2 weeks has started."
        let lastDay = Formatting.shortDate(end.addingTimeInterval(-1))
        return (r.name, "A fresh \(Formatting.days(r.periodDays)) has started. You've got until \(lastDay).")
    }

    static func home(_ r: RhythmSnapshot) -> Copy {
        (r.name, "You're home — good moment for it.")
    }

    static func snooze(_ r: RhythmSnapshot) -> Copy {
        (r.name, "Back again, as promised. Tap \(r.actionLabel) when it's done.")
    }

    private static func pick(_ options: [String], _ seed: Int, _ vary: Bool) -> String {
        guard vary, !options.isEmpty else { return options.first ?? "" }
        return options[abs(seed) % options.count]
    }
}
