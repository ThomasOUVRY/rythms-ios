import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

/// App-wide reminder settings: routines, quiet hours, pause, home.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ReminderSettings.load()
    @State private var status: UNAuthorizationStatus = .notDetermined
    @StateObject private var location = HomeLocator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if status != .authorized && status != .provisional {
                    notificationsBanner
                }

                section("Rough day") {
                    Toggle(isOn: Binding(
                        get: { settings.isPaused(at: .now) },
                        set: { settings.pausedUntil = $0 ? tomorrowMorning() : nil }
                    )) {
                        rowText("Pause everything", "Until tomorrow morning. Nothing counts as missed.")
                    }
                    .padding(.vertical, 10)
                }

                section("Your routine") {
                    timeRow("Wake up", \.wakeMinutes)
                    RowDivider()
                    timeRow("Dinner", \.dinnerMinutes)
                    RowDivider()
                    timeRow("Bed", \.bedMinutes)
                }

                section("Quiet hours") {
                    Toggle("Hold nudges overnight", isOn: $settings.quietHoursOn)
                        .font(.rhythm(15, .semibold))
                        .padding(.vertical, 10)
                    if settings.quietHoursOn {
                        RowDivider()
                        timeRow("From", \.quietStartMinutes)
                        RowDivider()
                        timeRow("Until", \.quietEndMinutes)
                    }
                }

                section("Wording") {
                    Toggle(isOn: $settings.varyWording) {
                        rowText("Vary the wording", "So your brain doesn't tune it out")
                    }
                    .padding(.vertical, 10)
                }

                section("Home") {
                    VStack(alignment: .leading, spacing: 8) {
                        rowText(
                            settings.hasHome ? "Home is set" : "No home set",
                            "Used only for \u{201C}When I get home\u{201D}. Stays on this phone."
                        )
                        HStack {
                            Button(settings.hasHome ? "Update to where I am" : "Set to where I am now") {
                                location.locate()
                            }
                            .buttonStyle(PillButtonStyle())
                            if settings.hasHome {
                                Button("Clear") {
                                    settings.homeLatitude = nil
                                    settings.homeLongitude = nil
                                }
                                .buttonStyle(PillButtonStyle(filled: false))
                            }
                        }
                        if let error = location.error {
                            Text(error).font(.rhythm(12)).foregroundStyle(RhythmColor.amber.color)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .tint(RhythmColor.teal.color)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.bold)
            }
        }
        .task { status = await NotificationScheduler.shared.authorizationStatus() }
        .onChange(of: settings) { _, new in
            new.save()
            Task { await RhythmActions.changed() }
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            guard let c = location.coordinate else { return }
            settings.homeLatitude = c.latitude
            settings.homeLongitude = c.longitude
        }
    }

    private var notificationsBanner: some View {
        Card {
            Text("Notifications are off").font(.rhythm(15, .bold))
            Text("Rhythms can't nudge you until you allow notifications.")
                .font(.rhythm(13))
                .foregroundStyle(Theme.muted)
            Button(status == .denied ? "Open iPhone Settings" : "Allow notifications") {
                if status == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } else {
                    Task {
                        _ = await NotificationScheduler.shared.requestAuthorization()
                        status = await NotificationScheduler.shared.authorizationStatus()
                        await RhythmActions.changed()
                    }
                }
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: title)
            GroupedRows { content() }
        }
    }

    private func rowText(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.rhythm(15, .semibold))
            Text(detail).font(.rhythm(12)).foregroundStyle(Theme.muted)
        }
    }

    private func timeRow(_ title: String, _ key: WritableKeyPath<ReminderSettings, Int>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { ReminderPlanner.clock(minutes: settings[keyPath: key], on: .now, calendar: .current) },
                set: { settings[keyPath: key] = ReminderPlanner.minutesOfDay($0, calendar: .current) }
            ),
            displayedComponents: .hourAndMinute
        )
        .font(.rhythm(15, .semibold))
        .padding(.vertical, 6)
    }

    private func tomorrowMorning() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return ReminderPlanner.clock(minutes: settings.quietEndMinutes, on: tomorrow, calendar: calendar)
    }
}

/// One-shot "where am I" for setting home.
@MainActor
final class HomeLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var error: String?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func locate() {
        error = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: error = "Location is off for Rhythms. Turn it on in iPhone Settings to use this."
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways { self.manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = c }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.error = "Couldn't find your location. Try again outside or with Wi-Fi on." }
    }
}
