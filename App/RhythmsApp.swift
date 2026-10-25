import SwiftData
import SwiftUI

@main
struct RhythmsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Store.container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\Rhythm.sortOrder), SortDescriptor(\Rhythm.createdAt)]) private var rhythms: [Rhythm]
    @State private var resetRhythm: Rhythm?

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(Theme.ink)
        .sheet(item: $resetRhythm, onDismiss: showNextReset) { rhythm in
            ResetView(rhythm: rhythm)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .task { refresh() }
    }

    private func refresh() {
        Task { await RhythmActions.changed() }
        showNextReset()
    }

    /// Shows the reset moment for the first rhythm whose period ran out since it was last opened.
    private func showNextReset() {
        guard resetRhythm == nil else { return }
        resetRhythm = rhythms.first { r in
            r.kind == .period && r.snapshot.periodIndex(at: .now) > r.acknowledgedPeriod
        }
    }
}
