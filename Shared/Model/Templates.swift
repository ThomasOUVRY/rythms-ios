import Foundation

/// Starting points offered on an empty Home screen.
enum RhythmTemplate: String, CaseIterable, Identifiable {
    case brushTeeth, surprise, run

    var id: String { rawValue }

    var name: String {
        switch self {
        case .brushTeeth: "Brush teeth"
        case .surprise: "Surprise her"
        case .run: "Go for a run"
        }
    }

    var subtitle: String {
        switch self {
        case .brushTeeth: "Every 8–9 h · since last time"
        case .surprise: "Every 2 weeks · repeating period"
        case .run: "Every 3 days · repeating period"
        }
    }

    var symbol: String {
        switch self {
        case .brushTeeth: "mouth"
        case .surprise: "heart"
        case .run: "figure.run"
        }
    }

    var color: RhythmColor {
        switch self {
        case .brushTeeth: .teal
        case .surprise: .amber
        case .run: .blue
        }
    }

    func make(sortOrder: Int) -> Rhythm {
        switch self {
        case .brushTeeth:
            let r = Rhythm(name: name, kind: .sinceLast)
            r.actionLabel = "Brushed"
            r.intervalHours = 8
            r.flexHours = 1
            r.anchor = .windowOpens
            r.nudgeStyle = .followUp
            return finish(r, sortOrder)
        case .surprise:
            let r = Rhythm(name: name, kind: .period)
            r.actionLabel = "Surprised her"
            r.periodDays = 14
            r.anchor = .atTime
            r.anchorMinutes = 9 * 60
            r.nudgeStyle = .followUp
            r.checkpoints = [
                Checkpoint(day: 1, text: "Pick an idea"),
                Checkpoint(day: 8, text: "Anything to buy or book?"),
                Checkpoint(day: 12, text: "This is the week"),
            ]
            return finish(r, sortOrder)
        case .run:
            let r = Rhythm(name: name, kind: .period)
            r.actionLabel = "Ran"
            r.periodDays = 3
            r.anchor = .atTime
            r.anchorMinutes = 18 * 60
            r.nudgeStyle = .followUp
            return finish(r, sortOrder)
        }
    }

    private func finish(_ r: Rhythm, _ sortOrder: Int) -> Rhythm {
        r.symbol = symbol
        r.colorKey = color.rawValue
        r.sortOrder = sortOrder
        return r
    }
}
