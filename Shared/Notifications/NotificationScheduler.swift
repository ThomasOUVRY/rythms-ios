import CoreLocation
import Foundation
import UserNotifications

/// Turns the planner's output into pending iOS notifications. Safe to call from the app, widgets and intents.
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    /// iOS keeps at most 64 pending notifications per app; leave room for snoozes.
    private let maxPlanned = 56

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces every planned nudge with a fresh plan. Snoozes the user asked for are kept.
    func reschedule(_ rhythms: [RhythmSnapshot], now: Date = .now) async {
        let settings = ReminderSettings.load()
        center.setNotificationCategories(Set(rhythms.map { category(for: $0, settings: settings) }))

        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(NotificationIDs.prefix) && !$0.hasSuffix(".snooze") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let planned = rhythms
            .flatMap { ReminderPlanner.plan(for: $0, now: now, settings: settings) }
            .sorted { $0.date < $1.date }
            .prefix(maxPlanned)
        for nudge in planned {
            try? await center.add(request(for: nudge))
        }

        // "When I get home" only makes sense while the rhythm is due, so it's armed at reschedule time.
        for r in rhythms where r.remindersOn && r.anchor == .home && r.isDue(at: now) && !settings.isPaused(at: now) {
            if let request = homeRequest(for: r, settings: settings, copy: NudgeCopy.home(r), id: NotificationIDs.home(r.id)) {
                try? await center.add(request)
            }
        }
    }

    func snooze(_ r: RhythmSnapshot, minutes: Int) async {
        let content = self.content(r.id, NudgeCopy.snooze(r), emphasized: true)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: NotificationIDs.snooze(r.id), content: content, trigger: trigger))
    }

    /// Falls back to an hour when no home is set.
    func snoozeUntilHome(_ r: RhythmSnapshot) async {
        let settings = ReminderSettings.load()
        if let request = homeRequest(for: r, settings: settings, copy: NudgeCopy.home(r), id: NotificationIDs.snooze(r.id)) {
            try? await center.add(request)
        } else {
            await snooze(r, minutes: 60)
        }
    }

    func clearSnoozes(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.snooze(id), NotificationIDs.home(id)])
        center.removeDeliveredNotifications(withIdentifiers: [NotificationIDs.snooze(id), NotificationIDs.home(id)])
    }

    // MARK: Building requests

    private func category(for r: RhythmSnapshot, settings: ReminderSettings) -> UNNotificationCategory {
        let log = UNNotificationAction(
            identifier: NotificationIDs.Action.log,
            title: r.actionLabel,
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark")
        )
        let soon = UNNotificationAction(identifier: NotificationIDs.Action.snooze20, title: "In 20 minutes", options: [])
        let later = settings.hasHome
            ? UNNotificationAction(identifier: NotificationIDs.Action.snoozeHome, title: "When I get home", options: [])
            : UNNotificationAction(identifier: NotificationIDs.Action.snoozeHour, title: "In an hour", options: [])
        return UNNotificationCategory(identifier: NotificationIDs.category(r.id), actions: [log, soon, later], intentIdentifiers: [], options: [])
    }

    private func content(_ rhythmID: UUID, _ copy: NudgeCopy.Copy, emphasized: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.category(rhythmID)
        content.threadIdentifier = rhythmID.uuidString
        content.userInfo = ["rhythmID": rhythmID.uuidString]
        // Free Apple IDs can't sign the Time Sensitive entitlement, so everything is `.active`.
        // Follow-ups and snoozes instead rank first in notification summaries and stacks.
        content.interruptionLevel = .active
        content.relevanceScore = emphasized ? 1.0 : 0.5
        return content
    }

    private func request(for nudge: PlannedNudge) -> UNNotificationRequest {
        let content = self.content(nudge.rhythmID, (nudge.title, nudge.body), emphasized: nudge.emphasized)
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nudge.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: nudge.id, content: content, trigger: trigger)
    }

    private func homeRequest(for r: RhythmSnapshot, settings: ReminderSettings, copy: NudgeCopy.Copy, id: String) -> UNNotificationRequest? {
        guard let lat = settings.homeLatitude, let lon = settings.homeLongitude else { return nil }
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: 150, identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        return UNNotificationRequest(identifier: id, content: content(r.id, copy, emphasized: true), trigger: trigger)
    }
}
