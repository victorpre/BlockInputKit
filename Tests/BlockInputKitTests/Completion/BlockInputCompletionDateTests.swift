import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputCompletionDateTests: XCTestCase {
    private var knownDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar.current.date(from: components) ?? Date()
    }

    func testDateSuggestionInsertsISODateFollowedBySpace() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate
        )

        XCTAssertEqual(suggestion.insertionText, "@2026-06-15 ")
        XCTAssertEqual(suggestion.trigger, .mention)
        XCTAssertEqual(suggestion.iconSystemName, "calendar")
        XCTAssertEqual(suggestion.detailText, "Date")
        XCTAssertEqual(suggestion.id, "2026-06-15")
    }

    func testDateSuggestionTitleDefaultsToMediumStyle() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let expectedTitle = formatter.string(from: knownDate)

        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate,
            style: .medium
        )

        XCTAssertEqual(suggestion.title, expectedTitle)
    }

    func testDateSuggestionRespectsExplicitTitle() {
        let suggestion = BlockInputCompletionSuggestion.date(
            title: "My Date",
            date: knownDate
        )

        XCTAssertEqual(suggestion.title, "My Date")
    }

    func testDateSuggestionRespectsExplicitIDAndSubtitle() {
        let suggestion = BlockInputCompletionSuggestion.date(
            id: "custom-id",
            subtitle: "Next Monday",
            date: knownDate,
            detailText: "Reminder"
        )

        XCTAssertEqual(suggestion.id, "custom-id")
        XCTAssertEqual(suggestion.subtitle, "Next Monday")
        XCTAssertEqual(suggestion.detailText, "Reminder")
    }

    @MainActor
    func testAcceptDateCompletionInsertsAtToken() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Due @fri")
        ])))

        let selection = view.acceptCompletionSuggestion(
            .date(date: knownDate),
            in: blockID,
            replacing: NSRange(location: 4, length: 4)
        )

        XCTAssertEqual(view.document.blocks[0].text, "Due @2026-06-15 ")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: 16
        )))
    }

    @MainActor
    func testAcceptDateCompletionPreservesSurroundingText() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Before @today after")
        ])))

        let selection = view.acceptCompletionSuggestion(
            .date(date: knownDate),
            in: blockID,
            replacing: NSRange(location: 7, length: 6)
        )

        XCTAssertEqual(view.document.blocks[0].text, "Before @2026-06-15  after")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: 19
        )))
    }

    @MainActor
    func testAcceptDateCompletionUndoRestoresOriginalText() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Due @fri")
            ]),
            undoController: undoController
        ))

        view.acceptCompletionSuggestion(
            .date(date: knownDate),
            in: blockID,
            replacing: NSRange(location: 4, length: 4)
        )

        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "Due @fri")
    }

    func testDateSuggestionWithRelativeStyle() {
        let today = Calendar.current.startOfDay(for: Date())
        let suggestion = BlockInputCompletionSuggestion.date(
            date: today,
            style: .relative
        )

        let expected = relativeFormatter.string(from: today)
        XCTAssertEqual(suggestion.title, expected)
    }

    func testDateSuggestionWithShortStyle() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate,
            style: .short
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        XCTAssertEqual(suggestion.title, formatter.string(from: knownDate))
    }

    func testDateSuggestionWithLongStyle() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate,
            style: .long
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        XCTAssertEqual(suggestion.title, formatter.string(from: knownDate))
    }

    func testDateSuggestionWithFullStyle() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate,
            style: .full
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        XCTAssertEqual(suggestion.title, formatter.string(from: knownDate))
    }

    func testDateSuggestionCustomIconAndTrigger() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate,
            trigger: .slashCommand,
            iconSystemName: "clock"
        )

        XCTAssertEqual(suggestion.trigger, .slashCommand)
        XCTAssertEqual(suggestion.iconSystemName, "clock")
    }

    func testDateSuggestionNoExactMatchText() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate
        )

        XCTAssertNil(suggestion.exactMatchText)
    }

    // MARK: - Icon tint by date status

    func testDateSuggestionIconTintIsRedForOverdueDate() {
        let yesterday = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let suggestion = BlockInputCompletionSuggestion.date(
            date: yesterday
        )

        guard let tint = suggestion.iconTint else {
            return XCTFail("Expected iconTint for overdue date")
        }
        XCTAssertEqual(tint.red, 230 / 255, accuracy: 0.001)
        XCTAssertEqual(tint.green, 87 / 255, accuracy: 0.001)
        XCTAssertEqual(tint.blue, 120 / 255, accuracy: 0.001)
    }

    func testDateSuggestionIconTintIsYellowForToday() {
        let today = Calendar.current.startOfDay(for: Date())
        let suggestion = BlockInputCompletionSuggestion.date(
            date: today
        )

        guard let tint = suggestion.iconTint else {
            return XCTFail("Expected iconTint for today")
        }
        XCTAssertEqual(tint.red, 1, accuracy: 0.001)
        XCTAssertEqual(tint.green, 0.8, accuracy: 0.001)
        XCTAssertEqual(tint.blue, 0, accuracy: 0.001)
    }

    func testDateSuggestionIconTintIsNilForUpcomingDate() {
        let suggestion = BlockInputCompletionSuggestion.date(
            date: knownDate
        )

        XCTAssertNil(suggestion.iconTint)
    }

    func testDateSuggestionExplicitIconTintOverride() {
        let customTint = CompletionIconTint(red: 1, green: 0, blue: 0)
        let suggestion = BlockInputCompletionSuggestion(
            id: "test",
            title: "Custom",
            insertionText: "@2026-06-15 ",
            trigger: .mention,
            iconTint: customTint
        )

        XCTAssertEqual(suggestion.iconTint, customTint)
    }

    func testCompletionSuggestionStoresIconTint() {
        let suggestion = BlockInputCompletionSuggestion(
            id: "mention:alice",
            title: "Alice",
            insertionText: "@alice",
            trigger: .mention,
            iconTint: CompletionIconTint(red: 0.5, green: 0.5, blue: 0.5)
        )

        guard let tint = suggestion.iconTint else {
            return XCTFail("Expected iconTint")
        }
        XCTAssertEqual(tint.red, 0.5)
        XCTAssertEqual(tint.green, 0.5)
        XCTAssertEqual(tint.blue, 0.5)
        XCTAssertEqual(tint.alpha, 1)
    }

    private var relativeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
}
