import Foundation
import SwiftData

/// How a rhythm counts down.
enum RhythmKind: String, Codable, CaseIterable, Identifiable {
    /// Refills when logged, drains to a soft floor and waits. Never runs dry.
    case sinceLast
    /// Fixed calendar periods. Runs empty, then a fresh period starts on its own.
    case period

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sinceLast: "Since last time"
        case .period: "Repeating period"
        }
    }

    var help: String {
        switch self {
        case .sinceLast: "Refills when you tap the button. Drains to a soft floor and waits — never runs dry."
        case .period: "Fixed windows on the calendar. Runs empty, then a fresh period starts on its own."
        }
    }
}

enum NudgeStyle: String, Codable, CaseIterable, Identifiable {
    case quiet
    case followUp
    case live

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: "One quiet nudge"
        case .followUp: "Nudge + one follow-up"
        case .live: "Live countdown"
        }
    }

    var help: String {
        switch self {
        case .quiet: "A single notification. Good for things you rarely forget."
        case .followUp: "If you haven't tapped it within an hour, one more reminder. Then it stops."
        case .live: "A countdown stays on your Lock Screen while it's due, plus the nudge and follow-up."
        }
    }
}

/// The moment a nudge is tied to.
enum NudgeAnchor: String, Codable, CaseIterable, Identifiable {
    case windowOpens
    case atTime
    case wake
    case home
    case dinner
    case bed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowOpens: "When the window opens"
        case .atTime: "At a set time"
        case .wake: "After I wake up"
        case .home: "When I get home"
        case .dinner: "After dinner"
        case .bed: "Before bed"
        }
    }

    static func options(for kind: RhythmKind) -> [NudgeAnchor] {
        switch kind {
        case .sinceLast: [.windowOpens, .wake, .home, .dinner, .bed]
        case .period: [.atTime, .wake, .home, .dinner, .bed]
        }
    }
}

struct Checkpoint: Codable, Hashable, Identifiable {
    var id = UUID()
    /// 1-based day inside the period.
    var day: Int
    var text: String
}

struct PeriodIdea: Codable, Hashable {
    /// 0-based period index.
    var period: Int
    var text: String
}

@Model
final class Rhythm {
    var id: UUID = UUID()
    var name: String = ""
    var actionLabel: String = "Done"
    var symbol: String = "checkmark.circle"
    var colorKey: String = RhythmColor.teal.rawValue
    var kindRaw: String = RhythmKind.sinceLast.rawValue

    // Since-last settings
    var intervalHours: Double = 8
    var flexHours: Double = 1

    // Period settings
    var periodDays: Int = 14
    var periodStart: Date = Date()

    var logs: [Date] = []
    var ideas: [PeriodIdea] = []

    // Reminders
    var remindersOn: Bool = true
    var nudgeStyleRaw: String = NudgeStyle.followUp.rawValue
    var anchorRaw: String = NudgeAnchor.windowOpens.rawValue
    /// Minutes after midnight, used by `.atTime`.
    var anchorMinutes: Int = 9 * 60
    var checkpoints: [Checkpoint] = []

    /// Highest period index whose reset moment the user has seen.
    var acknowledgedPeriod: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, kind: RhythmKind) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.createdAt = .now
        self.periodStart = Calendar.current.startOfDay(for: .now)
    }

    var kind: RhythmKind {
        get { RhythmKind(rawValue: kindRaw) ?? .sinceLast }
        set { kindRaw = newValue.rawValue }
    }

    var nudgeStyle: NudgeStyle {
        get { NudgeStyle(rawValue: nudgeStyleRaw) ?? .followUp }
        set { nudgeStyleRaw = newValue.rawValue }
    }

    var anchor: NudgeAnchor {
        get { NudgeAnchor(rawValue: anchorRaw) ?? .windowOpens }
        set { anchorRaw = newValue.rawValue }
    }

    var snapshot: RhythmSnapshot {
        RhythmSnapshot(
            id: id,
            name: name,
            actionLabel: actionLabel,
            symbol: symbol,
            colorKey: colorKey,
            kind: kind,
            intervalHours: intervalHours,
            flexHours: flexHours,
            periodDays: periodDays,
            periodStart: periodStart,
            logs: logs,
            ideas: ideas,
            remindersOn: remindersOn,
            nudgeStyle: nudgeStyle,
            anchor: anchor,
            anchorMinutes: anchorMinutes,
            checkpoints: checkpoints,
            acknowledgedPeriod: acknowledgedPeriod,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }

    func idea(for period: Int) -> String {
        ideas.first { $0.period == period }?.text ?? ""
    }

    func setIdea(_ text: String, for period: Int) {
        if let i = ideas.firstIndex(where: { $0.period == period }) {
            ideas[i].text = text
        } else {
            ideas.append(PeriodIdea(period: period, text: text))
        }
    }
}

/// An immutable copy of a rhythm, safe to pass to widgets, the planner and tests.
struct RhythmSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var actionLabel: String
    var symbol: String
    var colorKey: String
    var kind: RhythmKind
    var intervalHours: Double = 8
    var flexHours: Double = 1
    var periodDays: Int = 14
    var periodStart: Date = .now
    var logs: [Date] = []
    var ideas: [PeriodIdea] = []
    var remindersOn: Bool = true
    var nudgeStyle: NudgeStyle = .followUp
    var anchor: NudgeAnchor = .windowOpens
    var anchorMinutes: Int = 9 * 60
    var checkpoints: [Checkpoint] = []
    var acknowledgedPeriod: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = .now

    var color: RhythmColor { RhythmColor(rawValue: colorKey) ?? .teal }
}

extension RhythmKind: Sendable {}
extension NudgeStyle: Sendable {}
extension NudgeAnchor: Sendable {}
extension Checkpoint: Sendable {}
extension PeriodIdea: Sendable {}
