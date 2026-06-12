import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputDocumentMetadataTokenTests: XCTestCase {
    private func resolvedDate(from text: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        guard let date = BlockInputDateResolver.resolveDate(from: text) else {
            XCTFail("Could not resolve date from \"\(text)\"", file: file, line: line)
            return ""
        }
        return BlockInputDateResolver.isoDateString(from: date)
    }
    // MARK: - @ (whenDate) Extraction

    func testExtractWhenDateTokenWithTrailingSpace() {
        let text = "Buy groceries @today "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Buy groceries ")
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "today"))
        XCTAssertNil(extraction.deadline)
        XCTAssertTrue(extraction.tags.isEmpty)
    }

    func testExtractWhenDateFromEndOfLine() {
        let text = "Buy @today "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Buy ")
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "today"))
    }

    // MARK: - ! (deadline) Extraction

    func testExtractDeadlineToken() {
        let text = "Submit report !tomorrow "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Submit report ")
        XCTAssertNil(extraction.whenDate)
        XCTAssertEqual(extraction.deadline, resolvedDate(from: "tomorrow"))
    }

    // MARK: - # (tags) Extraction

    func testExtractSingleTag() {
        let text = "Write docs #documentation "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Write docs ")
        XCTAssertEqual(extraction.tags, ["documentation"])
    }

    func testExtractMultipleTags() {
        let text = "Plan vacation #travel #summer #2025 "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Plan vacation ")
        XCTAssertEqual(extraction.tags, ["travel", "summer", "2025"])
    }

    // MARK: - Mixed Token Extraction

    func testExtractWhenDateDeadlineAndTags() {
        let text = "Finish project @friday !monday #work #urgent "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Finish project ")
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "friday"))
        XCTAssertEqual(extraction.deadline, resolvedDate(from: "monday"))
        XCTAssertEqual(extraction.tags, ["work", "urgent"])
    }

    // MARK: - Multiple Same-Type Tokens

    func testFirstWhenDateWins() {
        let text = "Plan @today @tomorrow "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "today"))
        XCTAssertEqual(extraction.cleanText, "Plan ")
    }

    func testFirstDeadlineWins() {
        let text = "Work !monday !friday "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.deadline, resolvedDate(from: "monday"))
        XCTAssertEqual(extraction.cleanText, "Work ")
    }

    func testMultipleTagsAccumulate() {
        let text = "Code #swift #ios #macos "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.tags, ["swift", "ios", "macos"])
        XCTAssertEqual(extraction.cleanText, "Code ")
    }

    // MARK: - Cursor Offset Adjustment

    func testCursorStaysAtEndAfterExtraction() {
        let text = "Buy milk @today "
        let fullLength = (text as NSString).length
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: fullLength
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cursorOffset, ("Buy milk " as NSString).length)
    }

    func testCursorAdjustsWhenTokenIsBeforeCursor() {
        let text = "Buy @today milk"
        let cursorAtEnd = (text as NSString).length
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: cursorAtEnd
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Buy milk")
        XCTAssertEqual(extraction.cursorOffset, ("Buy milk" as NSString).length)
    }

    // MARK: - No Extraction Cases

    func testNoTokenReturnsNil() {
        let text = "Plain text without any tokens "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction)
    }

    func testEmailNotExtracted() {
        let text = "Contact me at user@example.com "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction)
    }

    func testTokenWithoutTrailingSpaceNotExtracted() {
        let text = "Todo @today"
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction)
    }

    // MARK: - Non-resolving tokens (corner case: @t that doesn't resolve)

    func testNonResolvingDateTriggerNotExtracted() {
        let text = "Todo @t "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction, "Non-resolving @t should not trigger extraction")
    }

    func testNonResolvingDeadlineTriggerNotExtracted() {
        let text = "Todo !xyz "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction, "Non-resolving !xyz should not trigger extraction")
    }

    func testMixedResolvingAndNonResolvingTokens() {
        let text = "Todo @today @xyz "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction when at least one token resolves")
            return
        }
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "today"))
        XCTAssertEqual(extraction.cleanText, "Todo @xyz ")
        XCTAssertTrue(extraction.tags.isEmpty)
    }

    func testNonResolvingTokenAtEndPreserved() {
        let text = "Todo @t "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction, "@t is not a valid date and should not be stripped")
    }

    func testResolvingAndNonResolvingDeadline() {
        let text = "Todo !monday !badbeat "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction when deadline resolves")
            return
        }
        XCTAssertEqual(extraction.deadline, resolvedDate(from: "monday"))
        XCTAssertEqual(extraction.cleanText, "Todo !badbeat ")
    }

    func testNonResolvingDoesNotStripText() {
        let text = "Todo @t "
        let extraction = BlockInputDocument.extractMetadataTokens(
            from: text,
            cursorUTF16Offset: (text as NSString).length
        )
        XCTAssertNil(extraction, "Text should remain unchanged when no token resolves")
    }

    // MARK: - Import-mode Extraction (end of string without space)

    func testExtractWhenDateFromEndOfString() {
        let text = "Buy @today"
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text + " ",
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Buy ")
        XCTAssertEqual(extraction.whenDate, resolvedDate(from: "today"))
    }

    func testExtractTagsFromEndOfString() {
        let text = "Code #swift #ios"
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: text + " ",
            cursorUTF16Offset: (text as NSString).length
        ) else {
            XCTFail("Expected extraction")
            return
        }
        XCTAssertEqual(extraction.cleanText, "Code ")
        XCTAssertEqual(extraction.tags, ["swift", "ios"])
    }

    // MARK: - Model-level gating

    func testMetadataTokenExtractionOnlyWorksForChecklistItems() {
        let blockID = BlockInputBlockID(rawValue: "test")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .paragraph, text: "")
        ])

        let extraction = document.metadataTokenExtraction(
            for: document.blocks[0],
            proposedText: "Todo @today ",
            proposedUTF16Offset: 12
        )
        XCTAssertNil(extraction)
    }

    func testMetadataTokenExtractionWorksForChecklistItems() {
        let blockID = BlockInputBlockID(rawValue: "test")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "")
        ])

        let extraction = document.metadataTokenExtraction(
            for: document.blocks[0],
            proposedText: "Todo @today ",
            proposedUTF16Offset: 12
        )
        XCTAssertNotNil(extraction)
        XCTAssertEqual(extraction?.whenDate, resolvedDate(from: "today"))
    }

    // MARK: - Apply Extraction to Document

    func testApplyMetadataTokenExtractionToDocument() {
        let blockID = BlockInputBlockID(rawValue: "test")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Buy @today ")
        ])

        guard let extraction = document.metadataTokenExtraction(
            for: document.blocks[0],
            proposedText: "Buy @today ",
            proposedUTF16Offset: 12
        ) else {
            XCTFail("Expected extraction")
            return
        }

        let selection = document.applyMetadataTokenExtraction(
            blockID: blockID,
            extraction: extraction
        )

        XCTAssertEqual(document.blocks[0].text, "Buy ")
        XCTAssertEqual(document.blocks[0].whenDate, resolvedDate(from: "today"))
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 5)))
    }

    // MARK: - Metadata is cleared for non-checklist blocks

    func testMetadataClearedWhenKindChanges() {
        var block = BlockInputBlock(
            kind: .checklistItem(isChecked: false),
            text: "Todo",
            whenDate: "today",
            deadline: "friday",
            tags: ["work"]
        )

        block.kind = .paragraph

        XCTAssertNil(block.whenDate)
        XCTAssertNil(block.deadline)
        XCTAssertTrue(block.tags.isEmpty)
    }
}
