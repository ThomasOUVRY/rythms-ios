import SwiftUI

/// Per-rhythm reminders: nudge style, the moment it's tied to, and checkpoints for long periods.
struct ReminderSettingsView: View {
    @Binding var draft: RhythmDraft
    @State private var newCheckpointDay = 1
    @State private var newCheckpointText = ""
    @State private var settings = ReminderSettings.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GroupedRows {
                    Toggle("Reminders", isOn: $draft.remindersOn)
                        .font(.rhythm(15, .semibold))
                        .tint(RhythmColor.teal.color)
                        .padding(.vertical, 10)
                }

                if draft.remindersOn {
                    styleSection
                    anchorSection
                    if draft.kind == .period { checkpointSection }
                    Text("Quiet hours, routine times, your home location and pausing are in Settings on the Home screen.")
                        .font(.rhythm(12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Nudge style")
            ForEach(NudgeStyle.allCases) { style in
                let selected = draft.style == style
                Button { draft.style = style } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selected ? RhythmColor.teal.color : Theme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.title).font(.rhythm(15, .bold)).foregroundStyle(Theme.ink)
                            Text(style.help).font(.rhythm(13)).foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? RhythmColor.teal.color : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var anchorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Nudge me at a moment I can act")
            FlowChips(options: NudgeAnchor.options(for: draft.kind), selected: draft.anchor, title: chipTitle) {
                draft.anchor = $0
            }
            if draft.anchor == .atTime || (draft.anchor == .home && draft.kind == .period) {
                GroupedRows {
                    DatePicker(
                        draft.anchor == .home ? "Fallback time" : "Time",
                        selection: Binding(
                            get: { minutesToDate(draft.anchorMinutes) },
                            set: { draft.anchorMinutes = ReminderPlanner.minutesOfDay($0, calendar: .current) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(.rhythm(15, .semibold))
                    .padding(.vertical, 6)
                }
            }
            Text(anchorHelp)
                .font(.rhythm(12))
                .foregroundStyle(Theme.muted)
        }
    }

    private var checkpointSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Checkpoints · small steps through the period")
            GroupedRows {
                ForEach(Array(draft.checkpoints.sorted { $0.day < $1.day }.enumerated()), id: \.element.id) { index, cp in
                    if index > 0 { RowDivider() }
                    HStack(spacing: 12) {
                        Text("Day \(cp.day)")
                            .font(.rhythm(13, .heavy))
                            .foregroundStyle(RhythmColor.amber.color)
                            .frame(width: 56, alignment: .leading)
                        Text(cp.text).font(.rhythm(15, .semibold))
                        Spacer()
                        Button {
                            draft.checkpoints.removeAll { $0.id == cp.id }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.muted)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Remove checkpoint")
                    }
                }
                if !draft.checkpoints.isEmpty { RowDivider() }
                HStack(spacing: 10) {
                    Stepper("Day \(newCheckpointDay)", value: $newCheckpointDay, in: 1...max(draft.periodDays, 1))
                        .font(.rhythm(13, .heavy))
                        .fixedSize()
                    TextField("e.g. Pick an idea", text: $newCheckpointText)
                        .font(.rhythm(15))
                    Button("Add") {
                        let text = newCheckpointText.trimmingCharacters(in: .whitespaces)
                        guard !text.isEmpty else { return }
                        draft.checkpoints.append(Checkpoint(day: newCheckpointDay, text: text))
                        newCheckpointText = ""
                    }
                    .font(.rhythm(15, .bold))
                    .disabled(newCheckpointText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 8)
            }
            Text("Without checkpoints you get one nudge near the end of each period.")
                .font(.rhythm(12))
                .foregroundStyle(Theme.muted)
        }
    }

    private func chipTitle(_ anchor: NudgeAnchor) -> String {
        if let m = settings.minutes(for: anchor) {
            return "\(anchor.title) (\(Formatting.clock(minutes: m)))"
        }
        if anchor == .atTime { return Formatting.clock(minutes: draft.anchorMinutes) }
        return anchor.title
    }

    private var anchorHelp: String {
        switch draft.anchor {
        case .home:
            settings.hasHome
                ? "Fires when you arrive home while it's due. Arming happens when the app or a widget refreshes."
                : "Set your home in Settings first. Until then this uses the time instead."
        case .windowOpens:
            "Nudges right when the good window opens."
        default:
            "Routine times are set in Settings."
        }
    }

    private func minutesToDate(_ minutes: Int) -> Date {
        ReminderPlanner.clock(minutes: minutes, on: .now, calendar: .current)
    }
}

/// Wrapping row of selectable chips.
struct FlowChips<Option: Hashable>: View {
    var options: [Option]
    var selected: Option
    var title: (Option) -> String
    var pick: (Option) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button(title(option)) { pick(option) }
                    .font(.rhythm(13, .bold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .foregroundStyle(isSelected ? Theme.onInk : Theme.ink)
                    .background(isSelected ? Theme.inkButton : Theme.card, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let gap: CGFloat = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + gap
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
