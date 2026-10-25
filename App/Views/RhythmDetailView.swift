import SwiftUI

struct RhythmDetailView: View {
    @Bindable var rhythm: Rhythm
    @State private var editing = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(rhythm.kind.title) · \(Formatting.cadence(rhythm.snapshot).lowercased())")
                            .font(.rhythm(13, .semibold))
                            .foregroundStyle(Theme.muted)
                        Text(rhythm.name)
                            .font(.rhythm(30, .heavy))
                            .tracking(-0.5)
                    }
                    switch rhythm.kind {
                    case .sinceLast: SinceLastDetail(rhythm: rhythm, now: timeline.date)
                    case .period: PeriodDetail(rhythm: rhythm, now: timeline.date)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .background(Theme.ground.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { EditRhythmView(rhythm: rhythm) }
        }
    }
}

// MARK: Since last time

private struct SinceLastDetail: View {
    var rhythm: Rhythm
    var now: Date

    var body: some View {
        let snapshot = rhythm.snapshot
        let s = snapshot.sinceLastState(at: now)
        let justLogged = snapshot.lastLog.map { now.timeIntervalSince($0) < 15 * 60 } ?? false

        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bigValue(s))
                    .font(.rhythm(44, .heavy))
                    .monospacedDigit()
                    .tracking(-1)
                Text(bigLabel(s, justLogged: justLogged))
                    .font(.rhythm(14))
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 8) {
                ProgressBar(fill: s.fill, color: snapshot.color.color, height: 36, floorMark: sinceLastFloor)
                HStack {
                    Text("Floor 12%")
                    Spacer()
                    Text("Full")
                }
                .font(.rhythm(12))
                .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 12) {
                StatTile(label: "Last time", value: snapshot.lastLog.map(Formatting.time) ?? "Not yet")
                StatTile(label: "Good window", value: "\(Formatting.time(s.windowStart))–\(Formatting.time(s.windowEnd))")
            }

            if justLogged {
                Button("Undo") { Task { await RhythmActions.undoLast(id: rhythm.id) } }
                    .buttonStyle(WideButtonStyle(filled: false))
            } else {
                Button("\(rhythm.actionLabel) just now") { Task { await RhythmActions.log(id: rhythm.id) } }
                    .buttonStyle(WideButtonStyle())
            }
        }

        let recent = rhythm.logs.sorted(by: >).prefix(6)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent").font(.rhythm(15, .bold)).foregroundStyle(Theme.muted)
                GroupedRows {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, date in
                        if index > 0 { RowDivider() }
                        ValueRow(label: Formatting.day(date), value: Formatting.time(date))
                    }
                }
            }
        }

        Text("No streaks, no scores. If you're late the bar just waits at its floor until the next one.")
            .font(.rhythm(12))
            .foregroundStyle(Theme.muted)
    }

    private func bigValue(_ s: SinceLastState) -> String {
        switch s.phase {
        case .waiting: Formatting.duration(s.windowStart.timeIntervalSince(now))
        case .open: Formatting.duration(s.windowEnd.timeIntervalSince(now))
        case .late: "Whenever"
        }
    }

    private func bigLabel(_ s: SinceLastState, justLogged: Bool) -> String {
        switch s.phase {
        case .waiting: justLogged ? "until your window · just refilled" : "until your window opens"
        case .open: "left in your window — good moment"
        case .late: "you're ready. The bar is waiting."
        }
    }
}

private struct StatTile: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.rhythm(12)).foregroundStyle(Theme.muted)
            Text(value).font(.rhythm(16, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: Repeating period

private struct PeriodDetail: View {
    @Bindable var rhythm: Rhythm
    var now: Date

    var body: some View {
        let snapshot = rhythm.snapshot
        let p = snapshot.periodState(at: now)

        Card(padding: 20) {
            ZStack {
                Ring(fill: p.fill, color: snapshot.color.color, tint: snapshot.color.tint)
                    .frame(width: 196, height: 196)
                VStack(spacing: 2) {
                    Text(Formatting.duration(p.end.timeIntervalSince(now)))
                        .font(.rhythm(34, .heavy))
                        .monospacedDigit()
                    Text("left in period \(p.number)")
                        .font(.rhythm(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            Text("\(Formatting.range(p.start, p.end.addingTimeInterval(-1))) · then it empties and a new period starts")
                .font(.rhythm(13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            IdeaField(rhythm: rhythm, period: p.index)

            if p.isDone {
                Button("Done for this period · undo") { Task { await RhythmActions.undoLast(id: rhythm.id) } }
                    .buttonStyle(WideButtonStyle(filled: false))
            } else {
                Button("\(rhythm.actionLabel) — mark this period done") { Task { await RhythmActions.log(id: rhythm.id) } }
                    .buttonStyle(WideButtonStyle())
            }
        }

        let past = snapshot.pastPeriods(at: now)
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Past periods").font(.rhythm(15, .bold)).foregroundStyle(Theme.muted)
                GroupedRows {
                    ForEach(Array(past.enumerated()), id: \.offset) { index, period in
                        if index > 0 { RowDivider() }
                        ValueRow(
                            label: "Period \(period.number) · \(Formatting.range(period.start, period.end.addingTimeInterval(-1)))",
                            value: period.doneAt == nil ? "Passed" : "Done",
                            valueColor: period.doneAt == nil ? Theme.muted : Theme.done,
                            valueWeight: period.doneAt == nil ? .regular : .bold
                        )
                    }
                }
            }
        }
    }
}

struct IdeaField: View {
    @Bindable var rhythm: Rhythm
    var period: Int
    var placeholder = "e.g. breakfast in bed, a handwritten note…"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Idea for this period").font(.rhythm(13, .bold))
            TextField(placeholder, text: Binding(
                get: { rhythm.idea(for: period) },
                set: { rhythm.setIdea($0, for: period) }
            ), axis: .vertical)
            .font(.rhythm(15, .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
