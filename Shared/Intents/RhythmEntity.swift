import AppIntents
import Foundation
import WidgetKit

/// A rhythm as Shortcuts and widget configuration see it, so a widget can be pinned to one habit.
struct RhythmEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Rhythm"
    static let defaultQuery = RhythmEntityQuery()

    var id: UUID
    var name: String
    var symbol: String

    init(_ snapshot: RhythmSnapshot) {
        id = snapshot.id
        name = snapshot.name
        symbol = snapshot.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct RhythmEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [RhythmEntity] {
        await MainActor.run {
            Store.snapshots().filter { identifiers.contains($0.id) }.map(RhythmEntity.init)
        }
    }

    func suggestedEntities() async throws -> [RhythmEntity] {
        await MainActor.run {
            Store.snapshots().map(RhythmEntity.init)
        }
    }
}

/// The widget's "Edit Widget" screen: which habits it shows, in order.
struct PickRhythmsIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose habits"
    static let description = IntentDescription("Pick the habits this widget shows. Leave empty to show whichever need you soonest.")

    /// Up to four rings on the Home Screen, one in the round Lock Screen spot.
    @Parameter(title: "Habits", size: [.systemSmall: 4, .accessoryCircular: 1])
    var rhythms: [RhythmEntity]?

    init() {}
}
