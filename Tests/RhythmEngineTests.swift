import XCTest
@testable import Rhythms

final class RhythmEngineTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func sinceLast(lastLog: Date) -> RhythmSnapshot {
        RhythmSnapshot(id: UUID(), name: "Brush teeth", actionLabel: "Brushed", symbol: "mouth", colorKey: "teal",
                       kind: .sinceLast, intervalHours: 8, flexHours: 1, logs: [lastLog], createdAt: lastLog)
    }

    private func period(days: Int, start: Date, logs: [Date] = []) -> RhythmSnapshot {
        RhythmSnapshot(id: UUID(), name: "Surprise her", actionLabel: "Surprised her", symbol: "heart", colorKey: "amber",
                       kind: .period, periodDays: days, periodStart: start, logs: logs, createdAt: start)
    }

    // MARK: Since last time

    func testSinceLastIsFullRightAfterLogging() {
        let r = sinceLast(lastLog: date(25, 7, 40))
        let s = r.sinceLastState(at: date(25, 7, 40))
        XCTAssertEqual(s.fill, 1, accuracy: 0.0001)
        XCTAssertEqual(s.phase, .waiting)
    }

    func testSinceLastNeverDropsBelowFloor() {
        let r = sinceLast(lastLog: date(25, 7, 40))
        let s = r.sinceLastState(at: date(27, 7, 40))
        XCTAssertEqual(s.fill, sinceLastFloor, accuracy: 0.0001)
        XCTAssertEqual(s.phase, .late)
    }

    func testSinceLastWindow() {
        let r = sinceLast(lastLog: date(25, 7, 40))
        XCTAssertEqual(r.sinceLastState(at: date(25, 15, 39)).phase, .waiting)
        XCTAssertEqual(r.sinceLastState(at: date(25, 15, 40)).phase, .open)
        XCTAssertEqual(r.sinceLastState(at: date(25, 16, 40)).phase, .late)
        // 5h10m in: 0.12 + 0.88 × (1 − 5.1667/8) ≈ 0.43, like the design.
        XCTAssertEqual(r.sinceLastState(at: date(25, 12, 50)).fill, 0.43, accuracy: 0.01)
    }

    // MARK: Repeating period

    func testPeriodIndexAndBounds() {
        let r = period(days: 14, start: date(4))
        let p = r.periodState(at: date(25, 12), calendar: calendar)
        XCTAssertEqual(p.index, 1)
        XCTAssertEqual(p.number, 2)
        XCTAssertEqual(p.start, date(18))
        XCTAssertEqual(p.end, date(1, month: 11))
    }

    func testPeriodRunsEmptyThenResets() {
        let r = period(days: 14, start: date(4))
        XCTAssertEqual(r.periodState(at: date(31, 23, 59), calendar: calendar).fill, 0, accuracy: 0.001)
        let fresh = r.periodState(at: date(1, 0, 0, month: 11), calendar: calendar)
        XCTAssertEqual(fresh.index, 2)
        XCTAssertEqual(fresh.fill, 1, accuracy: 0.0001)
    }

    func testDoneOnlyCountsInsideThePeriod() {
        let r = period(days: 14, start: date(4), logs: [date(15)])
        XCTAssertNotNil(r.doneAt(period: 0, calendar: calendar))
        XCTAssertFalse(r.periodState(at: date(25), calendar: calendar).isDone)
        let past = r.pastPeriods(at: date(25), calendar: calendar)
        XCTAssertEqual(past.count, 1)
        XCTAssertNotNil(past.first?.doneAt)
    }

    // MARK: Labels

    func testLabelSuggestions() {
        XCTAssertEqual(LabelSuggester.suggest(for: "Brush teeth"), "Brushed")
        XCTAssertEqual(LabelSuggester.suggest(for: "Go for a run"), "Ran")
        XCTAssertEqual(LabelSuggester.suggest(for: "Surprise her"), "Surprised her")
        XCTAssertEqual(LabelSuggester.suggest(for: "Something unusual"), "Done")
    }

    // MARK: Reminders

    func testQuietHoursMoveNudgesToMorning() {
        var settings = ReminderSettings()
        settings.quietStartMinutes = 22 * 60
        settings.quietEndMinutes = 8 * 60
        let late = PlannedNudge(id: "x", rhythmID: UUID(), date: date(25, 23, 30), title: "", body: "", kind: .nudge, timeSensitive: false)
        let moved = ReminderPlanner.adjust(late, settings: settings, calendar: calendar)
        XCTAssertEqual(moved?.date, date(26, 8))
    }

    func testPauseDropsNudgesButKeepsReset() {
        var settings = ReminderSettings()
        settings.quietHoursOn = false
        settings.pausedUntil = date(26, 8)
        let nudge = PlannedNudge(id: "a", rhythmID: UUID(), date: date(25, 18), title: "", body: "", kind: .nudge, timeSensitive: false)
        let reset = PlannedNudge(id: "b", rhythmID: UUID(), date: date(25, 18), title: "", body: "", kind: .reset, timeSensitive: false)
        XCTAssertNil(ReminderPlanner.adjust(nudge, settings: settings, calendar: calendar))
        XCTAssertNotNil(ReminderPlanner.adjust(reset, settings: settings, calendar: calendar))
    }

    func testSinceLastPlanHasNudgeAndOneFollowUp() {
        var settings = ReminderSettings()
        settings.quietHoursOn = false
        let r = sinceLast(lastLog: date(25, 7, 40))
        let plan = ReminderPlanner.plan(for: r, now: date(25, 8), settings: settings, calendar: calendar)
        XCTAssertEqual(plan.map(\.kind), [.nudge, .followUp])
        XCTAssertEqual(plan.first?.date, date(25, 15, 40))
        XCTAssertEqual(plan.last?.timeSensitive, true)
    }

    func testPeriodPlanUsesCheckpointsAndSkipsWhenDone() {
        var settings = ReminderSettings()
        settings.quietHoursOn = false
        var r = period(days: 14, start: date(18))
        r.anchor = .atTime
        r.anchorMinutes = 9 * 60
        r.checkpoints = [Checkpoint(day: 8, text: "Anything to buy?"), Checkpoint(day: 12, text: "This is the week")]
        let open = ReminderPlanner.plan(for: r, now: date(20), settings: settings, calendar: calendar)
        XCTAssertTrue(open.contains { $0.kind == .checkpoint && $0.date == date(25, 9) })
        XCTAssertTrue(open.contains { $0.kind == .reset && $0.date == date(1, 9, month: 11) })

        r.logs = [date(21)]
        let done = ReminderPlanner.plan(for: r, now: date(22), settings: settings, calendar: calendar)
        // Nothing left for this period except the reset; next period's checkpoints are still planned.
        XCTAssertFalse(done.contains { $0.kind == .checkpoint && $0.date < date(1, month: 11) })
        XCTAssertTrue(done.contains { $0.kind == .reset })
    }

    // MARK: Formatting

    func testDurationFormatting() {
        XCTAssertEqual(Formatting.duration(2 * 3600 + 50 * 60), "2h 50m")
        XCTAssertEqual(Formatting.duration(6 * 86_400 + 14 * 3600), "6d 14h")
        XCTAssertEqual(Formatting.duration(45 * 60), "45m")
        XCTAssertEqual(Formatting.duration(-5), "0m")
    }
}
