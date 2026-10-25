import Foundation
import SwiftData

enum AppGroup {
    /// Set from the `APP_GROUP` build setting through Info.plist, so app and widgets agree.
    static let id: String = Bundle.main.object(forInfoDictionaryKey: "RhythmsAppGroup") as? String ?? "group.com.thomasouvry.rhythms"

    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

enum Store {
    /// One container shared by the app, the widgets and app intents, kept in the App Group.
    static let container: ModelContainer = {
        let schema = Schema([Rhythm.self])
        // SwiftData's `groupContainer:` option crashes (rather than throws) when the App Group
        // entitlement is missing, e.g. in unsigned CI simulator builds. Resolve the folder ourselves
        // and fall back to the app's own storage, where widgets won't see the data.
        let configuration: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) {
            configuration = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("Rhythms.store"))
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the Rhythms store: \(error)")
        }
    }()

    @MainActor
    static func rhythms(in context: ModelContext? = nil) -> [Rhythm] {
        let context = context ?? container.mainContext
        let descriptor = FetchDescriptor<Rhythm>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func snapshots() -> [RhythmSnapshot] {
        rhythms().map(\.snapshot)
    }

    @MainActor
    static func rhythm(id: UUID, in context: ModelContext? = nil) -> Rhythm? {
        let context = context ?? container.mainContext
        var descriptor = FetchDescriptor<Rhythm>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
