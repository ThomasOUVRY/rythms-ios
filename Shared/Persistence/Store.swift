import Foundation
import SwiftData

enum AppGroup {
    /// Set from the `APP_GROUP` build setting through Info.plist, so app and widgets agree.
    static let id: String = Bundle.main.object(forInfoDictionaryKey: "RhythmsAppGroup") as? String ?? "group.com.example.rhythms"

    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

enum Store {
    /// One container shared by the app, the widgets and app intents, kept in the App Group.
    static let container: ModelContainer = {
        let schema = Schema([Rhythm.self])
        do {
            let shared = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.id))
            return try ModelContainer(for: schema, configurations: shared)
        } catch {
            // No App Group (e.g. unsigned simulator build): fall back to the app's own storage.
            // Widgets won't see data in this mode.
            let local = ModelConfiguration(schema: schema)
            do {
                return try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Could not open the Rhythms store: \(error)")
            }
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
