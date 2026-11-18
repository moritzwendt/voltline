import Foundation
import Testing
@testable import Voltline

struct RecordedDayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    @Test
    func firstMeasurementCreatesItsDay() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let days = RecordedDay.recording(timestamp, in: [], calendar: calendar)

        #expect(days.count == 1)
        #expect(days[0].date == calendar.startOfDay(for: timestamp))
        #expect(days[0].measurementCount == 1)
    }

    @Test
    func measurementsOnTheSameDayAreCounted() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var days = RecordedDay.recording(start, in: [], calendar: calendar)
        days = RecordedDay.recording(start.addingTimeInterval(45), in: days, calendar: calendar)
        days = RecordedDay.recording(start.addingTimeInterval(90), in: days, calendar: calendar)

        #expect(days.count == 1)
        #expect(days[0].measurementCount == 3)
    }

    @Test
    func newerDaysSortFirst() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var days = RecordedDay.recording(start, in: [], calendar: calendar)
        days = RecordedDay.recording(start.addingTimeInterval(2 * 86_400), in: days, calendar: calendar)
        days = RecordedDay.recording(start.addingTimeInterval(86_400), in: days, calendar: calendar)

        #expect(days.map(\.date) == days.map(\.date).sorted(by: >))
        #expect(days.count == 3)
        #expect(days.allSatisfy { $0.measurementCount == 1 })
    }

    @Test
    func existingCountsArePreserved() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let day = calendar.startOfDay(for: timestamp)
        let existing = [RecordedDay(date: day, measurementCount: 1_900)]
        let days = RecordedDay.recording(timestamp, in: existing, calendar: calendar)

        #expect(days[0].measurementCount == 1_901)
    }
}
