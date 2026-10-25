import Foundation

/// Guesses a past-tense button label from a rhythm's name: "Brush teeth" → "Brushed", "Surprise her" → "Surprised her".
enum LabelSuggester {
    private static let phrases: [String: String] = [
        "go for a run": "Ran",
        "go for a walk": "Walked",
        "go to bed": "Went to bed",
        "go to the gym": "Went",
        "take meds": "Took them",
        "take vitamins": "Took them",
    ]

    private static let verbs: [String: String] = [
        "brush": "Brushed", "floss": "Flossed", "run": "Ran", "walk": "Walked", "drink": "Drank",
        "read": "Read", "call": "Called", "text": "Texted", "stretch": "Stretched", "meditate": "Meditated",
        "clean": "Cleaned", "water": "Watered", "take": "Took", "write": "Wrote", "cook": "Cooked",
        "surprise": "Surprised", "plan": "Planned", "journal": "Journaled", "practice": "Practiced",
        "study": "Studied", "tidy": "Tidied", "wash": "Washed", "visit": "Visited", "swim": "Swam",
        "lift": "Lifted", "cycle": "Cycled", "ride": "Rode", "pray": "Prayed", "eat": "Ate",
        "check": "Checked", "pay": "Paid", "send": "Sent", "shave": "Shaved", "vacuum": "Vacuumed",
        "feed": "Fed", "back": "Backed up", "do": "Did it", "make": "Made it", "go": "Went",
    ]

    /// Short objects worth keeping in the label ("Surprised her", "Called mom").
    private static let keptObjects: Set<String> = ["her", "him", "them", "mom", "dad", "mum", "grandma", "grandpa"]

    static func suggest(for name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return "Done" }
        if let phrase = phrases[cleaned] { return phrase }

        let words = cleaned.split(separator: " ").map(String.init)
        guard let first = words.first, let past = verbs[first] else { return "Done" }
        if words.count == 2, keptObjects.contains(words[1]) {
            return "\(past) \(words[1])"
        }
        return past
    }

    /// Up to three distinct label choices to offer as chips.
    static func choices(for name: String) -> [String] {
        var out: [String] = []
        for option in [suggest(for: name), "Did it", "Done"] where !out.contains(option) {
            out.append(option)
        }
        return out
    }
}
