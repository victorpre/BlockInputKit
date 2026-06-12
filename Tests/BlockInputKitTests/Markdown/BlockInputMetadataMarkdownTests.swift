import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputMetadataMarkdownTests: XCTestCase {
    private func resolvedDate(from text: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        guard let date = BlockInputDateResolver.resolveDate(from: text) else {
            XCTFail("Could not resolve date from \"\(text)\"", file: file, line: line)
            return ""
        }
        return BlockInputDateResolver.isoDateString(from: date)
    }

    // MARK: - Markdown Export

    func testExportMetadataTokens() {
        let todayIso = resolvedDate(from: "today")
        let fridayIso = resolvedDate(from: "friday")
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "Buy groceries",
            whenDate: todayIso,
            deadline: fridayIso,
            tags: ["food", "urgent"]
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [ ] Buy groceries @\(todayIso) !\(fridayIso) #food #urgent")
    }

    func testExportWhenDateOnly() {
        let todayIso = resolvedDate(from: "today")
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: true),
            text: "Done task",
            whenDate: todayIso
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [x] Done task @\(todayIso)")
    }

    func testExportDeadlineOnly() {
        let nextWeekIso = resolvedDate(from: "next-week")
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "Task",
            deadline: nextWeekIso
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [ ] Task !\(nextWeekIso)")
    }

    func testExportTagsOnly() {
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "Code",
            tags: ["swift", "ios"]
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [ ] Code #swift #ios")
    }

    func testExportNoMetadataDoesNotAddSuffix() {
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "Simple task"
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [ ] Simple task")
    }

    func testExportMultilineChecklistOnlyFirstLineGetsMetadata() {
        let todayIso = resolvedDate(from: "today")
        let block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "First line\nSecond line",
            whenDate: todayIso
        )
        let document = BlockInputDocument(blocks: [block])
        let markdown = document.markdown

        XCTAssertEqual(markdown, "- [ ] First line @\(todayIso)\n  Second line")
    }

    // MARK: - Markdown Import

    func testImportMetadataFromMarkdown() {
        let markdown = "- [ ] Buy groceries @today !friday #food #urgent"
        let document = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0].text, "Buy groceries")
        XCTAssertEqual(document.blocks[0].kind, .checklistItem(isChecked: false))
        XCTAssertEqual(document.blocks[0].whenDate, resolvedDate(from: "today"))
        XCTAssertEqual(document.blocks[0].deadline, resolvedDate(from: "friday"))
        XCTAssertEqual(document.blocks[0].tags, ["food", "urgent"])
    }

    func testImportWhenDateOnly() {
        let markdown = "- [ ] Buy @today"
        let document = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(document.blocks[0].text, "Buy")
        XCTAssertEqual(document.blocks[0].whenDate, resolvedDate(from: "today"))
    }

    func testImportTagsOnly() {
        let markdown = "- [ ] Code #swift #ios"
        let document = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(document.blocks[0].text, "Code")
        XCTAssertEqual(document.blocks[0].tags, ["swift", "ios"])
    }

    func testImportNoMetadata() {
        let markdown = "- [ ] Simple task"
        let document = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(document.blocks[0].text, "Simple task")
        XCTAssertNil(document.blocks[0].whenDate)
        XCTAssertNil(document.blocks[0].deadline)
        XCTAssertTrue(document.blocks[0].tags.isEmpty)
    }

    func testImportCheckedChecklistWithMetadata() {
        let markdown = "- [x] Done @yesterday #completed"
        let document = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(document.blocks[0].kind, .checklistItem(isChecked: true))
        XCTAssertEqual(document.blocks[0].text, "Done")
        XCTAssertEqual(document.blocks[0].whenDate, resolvedDate(from: "yesterday"))
        XCTAssertEqual(document.blocks[0].tags, ["completed"])
    }

    // MARK: - Round Trip

    func testRoundTripPreservesMetadata() {
        let todayIso = resolvedDate(from: "today")
        let fridayIso = resolvedDate(from: "friday")
        let original = BlockInputDocument(blocks: [
            BlockInputBlock(
                kind: .checklistItem(isChecked: false),
                text: "Buy groceries",
                whenDate: todayIso,
                deadline: fridayIso,
                tags: ["food", "urgent"]
            )
        ])

        let markdown = original.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(parsed.blocks[0].text, original.blocks[0].text)
        XCTAssertEqual(parsed.blocks[0].whenDate, original.blocks[0].whenDate)
        XCTAssertEqual(parsed.blocks[0].deadline, original.blocks[0].deadline)
        XCTAssertEqual(parsed.blocks[0].tags, original.blocks[0].tags)
    }

    func testRoundTripPreservesMultipleChecklistItemsWithMixedMetadata() {
        let todayIso = resolvedDate(from: "today")
        let tomorrowIso = resolvedDate(from: "tomorrow")
        let nextWeekIso = resolvedDate(from: "next-week")
        let original = BlockInputDocument(blocks: [
            BlockInputBlock(kind: .checklistItem(isChecked: false), text: "No metadata"),
            BlockInputBlock(
                kind: .checklistItem(isChecked: true),
                text: "With when",
                whenDate: todayIso
            ),
            BlockInputBlock(
                kind: .checklistItem(isChecked: false),
                text: "With all",
                whenDate: tomorrowIso,
                deadline: nextWeekIso,
                tags: ["work", "important"]
            )
        ])

        let markdown = original.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(parsed.blocks.count, original.blocks.count)
        for blockIndex in 0..<original.blocks.count {
            XCTAssertEqual(parsed.blocks[blockIndex].text, original.blocks[blockIndex].text)
            XCTAssertEqual(parsed.blocks[blockIndex].whenDate, original.blocks[blockIndex].whenDate)
            XCTAssertEqual(parsed.blocks[blockIndex].deadline, original.blocks[blockIndex].deadline)
            XCTAssertEqual(parsed.blocks[blockIndex].tags, original.blocks[blockIndex].tags)
        }
    }

    func testNonChecklistBlocksAreNotAffected() {
        let original = BlockInputDocument(blocks: [
            BlockInputBlock(kind: .paragraph, text: "Ordinary paragraph"),
            BlockInputBlock(kind: .bulletedListItem, text: "List item"),
            BlockInputBlock(kind: .heading(level: 2), text: "Heading")
        ])

        let markdown = original.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(parsed.blocks.map(\.kind), original.blocks.map(\.kind))
        XCTAssertEqual(parsed.blocks.map(\.text), original.blocks.map(\.text))
    }
}
