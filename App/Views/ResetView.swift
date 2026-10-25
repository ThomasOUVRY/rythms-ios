import SwiftUI

/// The moment a period runs empty: first the empty ring and a kind word about the last period, then the fresh one.
struct ResetView: View {
    @Bindable var rhythm: Rhythm
    @Environment(\.dismiss) private var dismiss
    @State private var started = false

    var body: some View {
        let snapshot = rhythm.snapshot
        let now = Date.now
        let current = snapshot.periodState(at: now)
        let previousIndex = max(current.index - 1, 0)
        let previous = snapshot.periodBounds(previousIndex)
        let previousDone = snapshot.doneAt(period: previousIndex)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(started ? "\(rhythm.kind.title) · \(Formatting.cadence(snapshot).lowercased())" : Formatting.shortDate(current.start))
                        .font(.rhythm(13, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text(started ? "Period \(current.number) has begun" : "Period \(previousIndex + 1) ran out")
                        .font(.rhythm(30, .heavy))
                        .tracking(-0.5)
                    Text(rhythm.name)
                        .font(.rhythm(15, .semibold))
                        .foregroundStyle(Theme.muted)
                }

                Card(padding: 20) {
                    ZStack {
                        Ring(fill: started ? 1 : 0, color: snapshot.color.color, tint: snapshot.color.tint)
                            .frame(width: 196, height: 196)
                        VStack(spacing: 2) {
                            Text(started ? Formatting.duration(current.end.timeIntervalSince(now)) : "0m")
                                .font(.rhythm(34, .heavy))
                                .monospacedDigit()
                            Text("left in period \(started ? current.number : previousIndex + 1)")
                                .font(.rhythm(13))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if started {
                        Text("\(Formatting.range(current.start, current.end.addingTimeInterval(-1))) · a clean slate")
                            .font(.rhythm(13))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                        IdeaField(rhythm: rhythm, period: current.index, placeholder: "Something new for this period…")
                        Button("Back to Rhythms") { finish() }
                            .buttonStyle(WideButtonStyle())
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(previousDone == nil ? "This one slipped by." : "You did it this period.")
                                .font(.rhythm(15, .bold))
                            Text(previousDone.map { "Logged on \(Formatting.shortDate($0)). Nothing to keep up — the next stretch is simply new." }
                                 ?? "That's okay. Nothing carries over, and the next stretch starts fresh.")
                                .font(.rhythm(14))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.ground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button("Start period \(current.number)") {
                            withAnimation(.easeOut(duration: 0.6)) { started = true }
                        }
                        .buttonStyle(WideButtonStyle())
                        Text("It already started on its own — this just marks the turn.")
                            .font(.rhythm(12))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                GroupedRows {
                    ValueRow(
                        label: "Period \(previousIndex + 1) · \(Formatting.range(previous.start, previous.end.addingTimeInterval(-1)))",
                        value: previousDone == nil ? "Passed" : "Done",
                        valueColor: previousDone == nil ? Theme.muted : Theme.done,
                        valueWeight: previousDone == nil ? .regular : .bold
                    )
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 24)
        }
        .background(Theme.ground.ignoresSafeArea())
        .interactiveDismissDisabled(!started)
        .onDisappear(perform: acknowledge)
    }

    private func finish() {
        acknowledge()
        dismiss()
    }

    private func acknowledge() {
        rhythm.acknowledgedPeriod = rhythm.snapshot.periodIndex(at: .now)
        try? Store.container.mainContext.save()
    }
}
