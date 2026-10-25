import SwiftUI

/// The Home card. Also used as the live preview in the editor (`interactive: false`).
struct RhythmCard: View {
    var snapshot: RhythmSnapshot
    var now: Date
    var interactive = true

    init(rhythm: Rhythm, now: Date) {
        self.snapshot = rhythm.snapshot
        self.now = now
    }

    init(snapshot: RhythmSnapshot, now: Date, interactive: Bool) {
        self.snapshot = snapshot
        self.now = now
        self.interactive = interactive
    }

    var body: some View {
        let display = CardDisplay(snapshot, now: now)
        Card {
            HStack(spacing: 12) {
                IconTile(symbol: snapshot.symbol, color: snapshot.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name.isEmpty ? "Untitled rhythm" : snapshot.name)
                        .font(.rhythm(17, .bold))
                    Text(display.subtitle)
                        .font(.rhythm(13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                if display.isDone {
                    Label("Done", systemImage: "checkmark")
                        .font(.rhythm(13, .bold))
                        .foregroundStyle(Theme.done)
                } else if interactive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }

            if !display.isDone {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(display.value)
                        .font(.rhythm(30, .heavy))
                        .monospacedDigit()
                        .tracking(-0.5)
                    Text(display.valueLabel)
                        .font(.rhythm(14))
                        .foregroundStyle(Theme.muted)
                }
            }

            ProgressBar(
                fill: display.fill,
                color: display.isDone ? snapshot.color.color.opacity(0.35) : snapshot.color.color,
                floorMark: snapshot.kind == .sinceLast ? sinceLastFloor : nil
            )

            HStack {
                Text(display.hint)
                    .font(.rhythm(12))
                    .foregroundStyle(Theme.muted)
                Spacer()
                if !display.isDone {
                    Button(snapshot.actionLabel) {
                        guard interactive else { return }
                        Task { await RhythmActions.log(id: snapshot.id) }
                    }
                    .buttonStyle(PillButtonStyle())
                    .allowsHitTesting(interactive)
                }
            }
        }
    }
}
