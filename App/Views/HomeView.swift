import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Rhythm.sortOrder), SortDescriptor(\Rhythm.createdAt)]) private var rhythms: [Rhythm]
    @State private var showingNew = false
    @State private var showingSettings = false
    @State private var editing: Rhythm?
    @State private var opened: UUID?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(now: timeline.date)
                    if rhythms.isEmpty {
                        EmptyHome(add: addTemplate)
                    } else {
                        ForEach(rhythms) { rhythm in
                            // A tap gesture rather than a NavigationLink, so the card's own button stays tappable.
                            RhythmCard(rhythm: rhythm, now: timeline.date)
                                .contentShape(Rectangle())
                                .onTapGesture { opened = rhythm.id }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction(named: "Open") { opened = rhythm.id }
                                .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = rhythm }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(rhythm) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .background(Theme.ground.ignoresSafeArea())
        }
        .onChange(of: rhythms.map(\.id)) { _, ids in
            // Pop back if the open rhythm was deleted.
            if let opened, !ids.contains(opened) { self.opened = nil }
        }
        .navigationDestination(item: $opened) { id in
            if let rhythm = rhythms.first(where: { $0.id == id }) {
                RhythmDetailView(rhythm: rhythm)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingNew) {
            NavigationStack { EditRhythmView(rhythm: nil) }
        }
        .sheet(item: $editing) { rhythm in
            NavigationStack { EditRhythmView(rhythm: rhythm) }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.rhythm(13, .semibold))
                    .foregroundStyle(Theme.muted)
                Text("Rhythms")
                    .font(.rhythm(34, .heavy))
                    .tracking(-0.6)
            }
            Spacer()
            Button { showingNew = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.onInk)
                    .frame(width: 44, height: 44)
                    .background(Theme.inkButton, in: Circle())
            }
            .accessibilityLabel("New countdown")
        }
        .padding(.top, 8)
    }

    private func addTemplate(_ template: RhythmTemplate) {
        let rhythm = template.make(sortOrder: (rhythms.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(rhythm)
        Task { await RhythmActions.changed() }
    }

    private func delete(_ rhythm: Rhythm) {
        NotificationScheduler.shared.clearSnoozes(for: rhythm.id)
        context.delete(rhythm)
        Task { await RhythmActions.changed() }
    }
}

private struct EmptyHome: View {
    var add: (RhythmTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing counting down yet. Start from one of these, or tap + to make your own.")
                .font(.rhythm(15))
                .foregroundStyle(Theme.muted)
            ForEach(RhythmTemplate.allCases) { template in
                Button { add(template) } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: template.symbol, color: template.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(.rhythm(17, .bold))
                            Text(template.subtitle).font(.rhythm(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(template.color.color)
                    }
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
