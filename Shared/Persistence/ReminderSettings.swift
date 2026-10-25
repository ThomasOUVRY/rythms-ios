import Foundation

/// App-wide reminder preferences, stored in the App Group so widgets and intents can read them.
struct ReminderSettings: Equatable, Sendable {
    var wakeMinutes = 7 * 60 + 30
    var dinnerMinutes = 19 * 60 + 30
    var bedMinutes = 22 * 60 + 30
    var quietStartMinutes = 22 * 60
    var quietEndMinutes = 8 * 60
    var quietHoursOn = true
    var varyWording = true
    var pausedUntil: Date?
    var homeLatitude: Double?
    var homeLongitude: Double?

    var hasHome: Bool { homeLatitude != nil && homeLongitude != nil }

    func isPaused(at date: Date) -> Bool {
        guard let pausedUntil else { return false }
        return date < pausedUntil
    }

    func minutes(for anchor: NudgeAnchor) -> Int? {
        switch anchor {
        case .wake: wakeMinutes
        case .dinner: dinnerMinutes
        case .bed: bedMinutes
        case .windowOpens, .atTime, .home: nil
        }
    }

    // MARK: Persistence

    private enum Key {
        static let wake = "wakeMinutes", dinner = "dinnerMinutes", bed = "bedMinutes"
        static let quietStart = "quietStartMinutes", quietEnd = "quietEndMinutes", quietOn = "quietHoursOn"
        static let vary = "varyWording", paused = "pausedUntil", lat = "homeLatitude", lon = "homeLongitude"
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> ReminderSettings {
        var s = ReminderSettings()
        if defaults.object(forKey: Key.wake) != nil { s.wakeMinutes = defaults.integer(forKey: Key.wake) }
        if defaults.object(forKey: Key.dinner) != nil { s.dinnerMinutes = defaults.integer(forKey: Key.dinner) }
        if defaults.object(forKey: Key.bed) != nil { s.bedMinutes = defaults.integer(forKey: Key.bed) }
        if defaults.object(forKey: Key.quietStart) != nil { s.quietStartMinutes = defaults.integer(forKey: Key.quietStart) }
        if defaults.object(forKey: Key.quietEnd) != nil { s.quietEndMinutes = defaults.integer(forKey: Key.quietEnd) }
        if defaults.object(forKey: Key.quietOn) != nil { s.quietHoursOn = defaults.bool(forKey: Key.quietOn) }
        if defaults.object(forKey: Key.vary) != nil { s.varyWording = defaults.bool(forKey: Key.vary) }
        s.pausedUntil = defaults.object(forKey: Key.paused) as? Date
        s.homeLatitude = defaults.object(forKey: Key.lat) as? Double
        s.homeLongitude = defaults.object(forKey: Key.lon) as? Double
        return s
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(wakeMinutes, forKey: Key.wake)
        defaults.set(dinnerMinutes, forKey: Key.dinner)
        defaults.set(bedMinutes, forKey: Key.bed)
        defaults.set(quietStartMinutes, forKey: Key.quietStart)
        defaults.set(quietEndMinutes, forKey: Key.quietEnd)
        defaults.set(quietHoursOn, forKey: Key.quietOn)
        defaults.set(varyWording, forKey: Key.vary)
        defaults.set(pausedUntil, forKey: Key.paused)
        defaults.set(homeLatitude, forKey: Key.lat)
        defaults.set(homeLongitude, forKey: Key.lon)
    }
}
