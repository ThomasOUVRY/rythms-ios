import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RhythmActions.onChange = { snapshots in
            await LiveActivityController.sync(snapshots)
        }
        return true
    }

    /// Show nudges as banners even while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Handles the notification buttons without opening the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["rhythmID"] as? String, let id = UUID(uuidString: raw) else { return }

        switch response.actionIdentifier {
        case NotificationIDs.Action.log:
            await RhythmActions.log(id: id)
        case NotificationIDs.Action.snooze20:
            await RhythmActions.snooze(id: id, minutes: 20)
        case NotificationIDs.Action.snoozeHour:
            await RhythmActions.snooze(id: id, minutes: 60)
        case NotificationIDs.Action.snoozeHome:
            await RhythmActions.snoozeUntilHome(id: id)
        default:
            break
        }
    }
}
