import SwiftData
import SwiftUI

/// Editable copy of a rhythm's settings, so Cancel throws changes away.
struct RhythmDraft {
    var name = ""
    var label = ""
    var symbol = "figure.run"
    var color: RhythmColor = .blue
    var kind: RhythmKind = .period
    var intervalHours: Double = 8
    var flexHours: Double = 1
    var periodDays = 3
    var periodStart = Calendar.current.startOfDay(for: .now)
    var remindersOn = true
    var style: NudgeStyle = .followUp
    var anchor: NudgeAnchor = .atTime
    var anchorMinutes = 9 * 60
    var checkpoints: [Checkpoint] = []

    init() {}

    init(_ r: Rhythm) {
        name = r.name
        label = r.actionLabel == LabelSuggester.suggest(for: r.name) ? "" : r.actionLabel
        symbol = r.symbol
        color = RhythmColor(rawValue: r.colorKey) ?? .teal
        kind = r.kind
        intervalHours = r.intervalHours
        flexHours = r.flexHours
        periodDays = r.periodDays
        periodStart = r.periodStart
        remindersOn = r.remindersOn
        style = r.nudgeStyle
        anchor = r.anchor
        anchorMinutes = r.anchorMinutes
        checkpoints = r.checkpoints
    }

    var suggestedLabel: String { LabelSuggester.suggest(for: name) }

    var resolvedLabel: String {
        let typed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? suggestedLabel : typed
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Switching kinds resets the interval to a sensible default and keeps the anchor valid.
    mutating func setKind(_ newKind: RhythmKind) {
        guard newKind != kind else { return }
        kind = newKind
        if !NudgeAnchor.options(for: newKind).contains(anchor) {
            anchor = newKind == .sinceLast ? .windowOpens : .atTime
        }
    }

    func apply(to r: Rhythm) {
        let periodChanged = r.kind != kind || r.periodDays != periodDays
            || !Calendar.current.isDate(r.periodStart, inSameDayAs: periodStart)
        r.name = trimmedName
        r.actionLabel = resolvedLabel
        r.symbol = symbol
        r.colorKey = color.rawValue
        r.kind = kind
        r.intervalHours = intervalHours
        r.flexHours = flexHours
        r.periodDays = periodDays
        r.periodStart = Calendar.current.startOfDay(for: periodStart)
        r.remindersOn = remindersOn
        r.nudgeStyle = style
        r.anchor = anchor
        r.anchorMinutes = anchorMinutes
        r.checkpoints = checkpoints
        if periodChanged {
            // Don't greet a changed schedule with a reset moment.
            r.acknowledgedPeriod = r.snapshot.periodIndex(at: .now)
        }
    }

    func preview(id: UUID = UUID()) -> RhythmSnapshot {
        RhythmSnapshot(
            id: id,
            name: trimmedName,
            actionLabel: resolvedLabel,
            symbol: symbol,
            colorKey: color.rawValue,
            kind: kind,
            intervalHours: intervalHours,
            flexHours: flexHours,
            periodDays: periodDays,
            periodStart: periodStart,
            logs: [.now],
            createdAt: .now
        )
    }
}

struct EditRhythmView: View {
    var rhythm: Rhythm?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var all: [Rhythm]
    @State private var draft = RhythmDraft()
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "Preview")
                    // Previewed as just-logged, so the bar shows full.
                    RhythmCard(snapshot: draft.preview(), now: .now, interactive: false)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .strokeBorder(Theme.muted.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                        .accessibilityLabel("Preview of the card")
                }

                field("Name") {
                    TextField("e.g. Go for a run", text: $draft.name)
                        .textInputAutocapitalization(.sentences)
                }

                VStack(alignment: .leading, spacing: 6) {
                    field("Button label — what you tap when it's done") {
                        TextField(draft.suggestedLabel, text: $draft.label)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LabelSuggester.choices(for: draft.name), id: \.self) { choice in
                                let selected = draft.resolvedLabel == choice
                                Button(choice) { draft.label = choice == draft.suggestedLabel ? "" : choice }
                                    .font(.rhythm(13, .bold))
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .foregroundStyle(selected ? Theme.onInk : Theme.ink)
                                    .background(selected ? Theme.inkButton : Theme.card, in: Capsule())
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Shown on the card, the widget and the notification button.")
                        .font(.rhythm(12))
                        .foregroundStyle(Theme.muted)
                }

                iconAndColor

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "How it counts")
                    Picker("How it counts", selection: Binding(get: { draft.kind }, set: { draft.setKind($0) })) {
                        ForEach(RhythmKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(draft.kind.help)
                        .font(.rhythm(13))
                        .foregroundStyle(Theme.muted)
                }

                schedule
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(rhythm == nil ? "New countdown" : "Edit countdown")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(rhythm == nil ? "Add" : "Save") { save() }
                    .fontWeight(.heavy)
                    .disabled(draft.trimmedName.isEmpty)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let rhythm { draft = RhythmDraft(rhythm) }
        }
        .confirmationDialog("Delete \(rhythm?.name ?? "this rhythm")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("Its history goes with it.")
        }
    }

    private var iconAndColor: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Icon & color")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(RhythmSymbols.all, id: \.self) { symbol in
                    let selected = draft.symbol == symbol
                    Button { draft.symbol = symbol } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(selected ? draft.color.color : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            HStack(spacing: 14) {
                ForEach(RhythmColor.allCases) { color in
                    let selected = draft.color == color
                    Button { draft.color = color } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(Theme.card, lineWidth: selected ? 3 : 0))
                            .overlay(Circle().strokeBorder(color.color, lineWidth: selected ? 1 : 0).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupedRows {
                if draft.kind == .sinceLast {
                    Stepper(value: $draft.intervalHours, in: 1...72, step: 1) {
                        stepperLabel("Every", "\(Formatting.hours(draft.intervalHours)) h")
                    }
                    .padding(.vertical, 10)
                    RowDivider()
                    Stepper(value: $draft.flexHours, in: 0...12, step: 0.5) {
                        stepperLabel("Flexible window", "+\(Formatting.hours(draft.flexHours)) h")
                    }
                    .padding(.vertical, 10)
                } else {
                    Stepper(value: $draft.periodDays, in: 1...90) {
                        stepperLabel("Every", periodLength(draft.periodDays))
                    }
                    .padding(.vertical, 10)
                    RowDivider()
                    DatePicker("First period starts", selection: $draft.periodStart, displayedComponents: .date)
                        .font(.rhythm(15, .semibold))
                        .padding(.vertical, 8)
                }
                RowDivider()
                NavigationLink {
                    ReminderSettingsView(draft: $draft)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminders").font(.rhythm(15, .semibold)).foregroundStyle(Theme.ink)
                            Text(reminderSummary).font(.rhythm(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 12)
                }
            }

            if rhythm != nil {
                Button("Delete rhythm", role: .destructive) { confirmDelete = true }
                    .font(.rhythm(15, .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var reminderSummary: String {
        guard draft.remindersOn else { return "Off" }
        var parts = [draft.style.title, draft.anchor == .atTime ? Formatting.clock(minutes: draft.anchorMinutes) : draft.anchor.title.lowercased()]
        if draft.kind == .period, !draft.checkpoints.isEmpty {
            parts.append("\(draft.checkpoints.count) checkpoint\(draft.checkpoints.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// "1 day", "3 days", "1 week", "2 weeks".
    private func periodLength(_ days: Int) -> String {
        let text = Formatting.days(days)
        return text == "week" || text == "day" ? "1 \(text)" : text
    }

    private func stepperLabel(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.rhythm(15, .semibold))
            Spacer()
            Text(value).font(.rhythm(16, .bold)).monospacedDigit()
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: title)
            content()
                .font(.rhythm(17, .semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func save() {
        if let rhythm {
            draft.apply(to: rhythm)
        } else {
            let new = Rhythm(name: draft.trimmedName, kind: draft.kind)
            new.sortOrder = (all.map(\.sortOrder).max() ?? -1) + 1
            draft.apply(to: new)
            context.insert(new)
        }
        Task {
            if draft.remindersOn { _ = await NotificationScheduler.shared.requestAuthorization() }
            await RhythmActions.changed()
        }
        dismiss()
    }

    private func delete() {
        guard let rhythm else { return }
        NotificationScheduler.shared.clearSnoozes(for: rhythm.id)
        context.delete(rhythm)
        Task { await RhythmActions.changed() }
        dismiss()
    }
}
