import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputDateResolverTests: XCTestCase {
    private var referenceDate: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 10
        return calendar.startOfDay(for: calendar.date(from: components) ?? Date())
    }

    private func referenceISO(_ date: Date) -> String {
        BlockInputDateResolver.isoDateString(from: date)
    }

    private func resolvedISO(from text: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        guard let date = BlockInputDateResolver.resolveDate(from: text, relativeTo: referenceDate) else {
            XCTFail("Could not resolve date from \"\(text)\"", file: file, line: line)
            return ""
        }
        return BlockInputDateResolver.isoDateString(from: date)
    }

    private func date(byAddingDays days: Int, file: StaticString = #filePath, line: UInt = #line) -> Date {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: referenceDate) else {
            XCTFail("Could not compute date +\(days) days", file: file, line: line)
            return referenceDate
        }
        return date
    }

    // MARK: - friendlyDateString - deadline style

    func testDeadlineStyleAlwaysShortFormat() {
        let date = resolvedISO(from: "2026-06-10")
        let result = BlockInputDateResolver.friendlyDateString(from: date, style: .deadline, relativeTo: referenceDate)
        XCTAssertEqual(result, "Wed, Jun 10")
    }

    func testDeadlineStyleOnFutureDate() {
        let date = resolvedISO(from: "2026-07-04")
        let result = BlockInputDateResolver.friendlyDateString(from: date, style: .deadline, relativeTo: referenceDate)
        XCTAssertEqual(result, "Sat, Jul 4")
    }

    func testDeadlineStyleOnPastDate() {
        let date = resolvedISO(from: "2025-01-15")
        let result = BlockInputDateResolver.friendlyDateString(from: date, style: .deadline, relativeTo: referenceDate)
        XCTAssertEqual(result, "Wed, Jan 15")
    }

    // MARK: - friendlyDateString - whenDate style, today/tomorrow

    func testWhenDateStyleToday() {
        let iso = referenceISO(referenceDate)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Today")
    }

    func testWhenDateStyleTomorrow() {
        let iso = referenceISO(date(byAddingDays: 1))
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Tomorrow")
    }

    // MARK: - whenDate style, same week day names

    func testWhenDateStyleSameWednesday() {
        let iso = referenceISO(referenceDate)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Today")
    }

    func testWhenDateStyleSameWeekThursday() {
        let thursday = date(byAddingDays: 1)
        let iso = referenceISO(thursday)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Tomorrow")
    }

    func testWhenDateStyleSameWeekMonday() {
        let monday = date(byAddingDays: -2)
        let iso = referenceISO(monday)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Mon, Jun 8")
    }

    func testWhenDateStyleSameWeekFriday() {
        let friday = date(byAddingDays: 2)
        let iso = referenceISO(friday)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Friday")
    }

    func testWhenDateStyleSameWeekSunday() {
        let sunday = date(byAddingDays: 4)
        let iso = referenceISO(sunday)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Sun, Jun 14")
    }

    // MARK: - whenDate style, outside current week

    func testWhenDateStyleNextWeekMonday() {
        let nextMonday = date(byAddingDays: 5)
        let iso = referenceISO(nextMonday)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertEqual(result, "Mon, Jun 15")
    }

    func testWhenDateStyleNextMonth() {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: referenceDate) else {
            XCTFail("Could not compute next month")
            return
        }
        let iso = referenceISO(nextMonth)
        let result = BlockInputDateResolver.friendlyDateString(from: iso, style: .whenDate, relativeTo: referenceDate)
        XCTAssertNotEqual(result, "Today")
        XCTAssertNotEqual(result, "Tomorrow")
    }

    // MARK: - Fallback on invalid ISO string

    func testFriendlyDateFallbackOnInvalidString() {
        let result = BlockInputDateResolver.friendlyDateString(from: "not-a-date", style: .whenDate)
        XCTAssertNil(result)
    }

    // MARK: - Past-date validation in setWhenDate

    func testPastISOStringResolvesButIsRejected() {
        let pastISO = "2020-01-01"
        let date = BlockInputDateResolver.resolveDate(from: pastISO, relativeTo: referenceDate)
        XCTAssertNotNil(date)
        let category = BlockInputDateResolver.categorize(dateString: pastISO, relativeTo: referenceDate)
        XCTAssertEqual(category, .past)
    }

    func testFutureISOStringIsFuture() {
        let futureISO = "2027-06-10"
        let category = BlockInputDateResolver.categorize(dateString: futureISO, relativeTo: referenceDate)
        XCTAssertEqual(category, .future)
    }
}
