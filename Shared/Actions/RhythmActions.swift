import Foundation
import SwiftData
import WidgetKit

/// Every change that should ripple out to widgets, notifications and the Live Activity goes through here.
@MainActor
enum RhythmActions {
    /// Set by the app to keep its Live Activities in step. Widgets and intents leave it nil.
    static var onChange: (([RhythmSnapshot]) async -> Void)?

    /// Logs the rhythm's action ("Brushed", "Ran"…). Refills a since-last rhythm or marks the period done.
    static func log(id: UUID, at date: Date = .now) async {
        guard let rhythm = Store.rhythm(id: id) else { return }
        rhythm.logs.append(date)
        if rhythm.logs.count > 500 {
            rhythm.logs = Array(rhythm.logs.sorted().suffix(500))
        }
        save()
        NotificationScheduler.shared.clearSnoozes(for: id)
        await changed()
    }

    /// Removes the most recent log.
    static func undoLast(id: UUID) async {
        guard let rhythm = Store.rhythm(id: id), let last = rhythm.logs.max(),
              let index = rhythm.logs.firstIndex(of: last) else { return }
        rhythm.logs.remove(at: index)
        save()
        await changed()
    }

    static func snooze(id: UUID, minutes: Int) async {
        guard let rhythm = Store.rhythm(id: id) else { return }
        await NotificationScheduler.shared.snooze(rhythm.snapshot, minutes: minutes)
    }

    static func snoozeUntilHome(id: UUID) async {
        guard let rhythm = Store.rhythm(id: id) else { return }
        await NotificationScheduler.shared.snoozeUntilHome(rhythm.snapshot)
    }

    /// Call after any edit: reloads widgets, re-plans notifications, syncs the Live Activity.
    static func changed() async {
        save()
        WidgetCenter.shared.reloadAllTimelines()
        let snapshots = Store.snapshots()
        await NotificationScheduler.shared.reschedule(snapshots)
        await onChange?(snapshots)
    }

    private static func save() {
        try? Store.container.mainContext.save()
    }
}
