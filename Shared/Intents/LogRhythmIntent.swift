import AppIntents
import Foundation

/// The widget's action button ("Brushed", "Ran"…). Runs without opening the app.
struct LogRhythmIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a rhythm"

    @Parameter(title: "Rhythm ID")
    var rhythmID: String

    init() {}

    init(rhythmID: UUID) {
        self.rhythmID = rhythmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: rhythmID) {
            await RhythmActions.log(id: id)
        }
        return .result()
    }
}

/// Same action from the Lock Screen Live Activity. As a LiveActivityIntent it runs in the app's process,
/// so the app can end the Live Activity once it's logged.
struct LogFromLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log a rhythm from the Lock Screen"

    @Parameter(title: "Rhythm ID")
    var rhythmID: String

    init() {}

    init(rhythmID: UUID) {
        self.rhythmID = rhythmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: rhythmID) {
            await RhythmActions.log(id: id)
        }
        return .result()
    }
}
