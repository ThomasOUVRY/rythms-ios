import ActivityKit
import Foundation

/// A Lock Screen countdown for a rhythm that's due. Started by the app for rhythms using the "Live countdown" nudge style.
struct RhythmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        var headline: String
        var window: String
    }

    var rhythmID: String
    var name: String
    var colorKey: String
    var symbol: String
    var actionLabel: String
}
