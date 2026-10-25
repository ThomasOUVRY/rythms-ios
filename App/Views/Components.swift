import SwiftUI

/// Rounded progress bar. `floorMark` draws the white tick a since-last bar rests on.
struct ProgressBar: View {
    var fill: Double
    var color: Color
    var height: CGFloat = 10
    var floorMark: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(max(fill, 0), 1)))
                if let floorMark {
                    Rectangle()
                        .fill(Theme.card)
                        .frame(width: 2, height: height + 6)
                        .offset(x: geo.size.width * floorMark)
                }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: fill)
        .accessibilityElement()
        .accessibilityLabel("\(Int((fill * 100).rounded())) percent left")
    }
}

struct Ring: View {
    var fill: Double
    var color: Color
    var tint: Color
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().stroke(tint, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fill, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.6), value: fill)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct PillButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rhythm(15, .bold))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(filled ? Theme.onInk : Theme.ink)
            .background(filled ? Theme.inkButton : Theme.ground, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct WideButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rhythm(16, .bold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(filled ? Theme.onInk : Theme.done)
            .background(filled ? Theme.inkButton : RhythmColor.teal.tint, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct SectionTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.rhythm(13, .bold))
            .foregroundStyle(Theme.muted)
    }
}

/// A white rounded list. Separate rows with `RowDivider`.
struct GroupedRows<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// A two-sided row: label on the left, value on the right.
struct ValueRow: View {
    var label: String
    var value: String
    var valueColor: Color = Theme.muted
    var valueWeight: Font.Weight = .regular

    var body: some View {
        HStack {
            Text(label).font(.rhythm(15, .semibold))
            Spacer()
            Text(value)
                .font(.rhythm(15, valueWeight))
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}
