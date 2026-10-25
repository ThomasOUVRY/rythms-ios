import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen countdown while a rhythm is due.
struct RhythmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RhythmActivityAttributes.self) { context in
            LiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // ActivityKit requires a Dynamic Island layout. Kept minimal on purpose: the design targets the Lock Screen.
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.name).font(.rhythm(14, .bold))
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol)
            } compactTrailing: {
                Text(timerInterval: context.state.start...max(context.state.end, context.state.start), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: context.attributes.symbol)
            }
        }
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<RhythmActivityAttributes>

    var body: some View {
        let color = (RhythmColor(rawValue: context.attributes.colorKey) ?? .teal).color
        let range = context.state.start...max(context.state.end, context.state.start)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.name, systemImage: context.attributes.symbol)
                    .font(.rhythm(14, .heavy))
                Spacer()
                Text(context.state.headline)
                    .font(.rhythm(13))
                    .foregroundStyle(.white.opacity(0.75))
            }
            ProgressView(timerInterval: range, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(color)
            HStack {
                Text(context.state.window)
                    .font(.rhythm(12))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(timerInterval: range, countsDown: true)
                    .font(.rhythm(12, .bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            if let id = UUID(uuidString: context.attributes.rhythmID) {
                Button(intent: LogFromLiveActivityIntent(rhythmID: id)) {
                    Text(context.attributes.actionLabel)
                        .font(.rhythm(14, .bold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(.black)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
