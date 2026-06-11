import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputDocumentMetadataTokenTests: XCTestCase {
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
        XCTAssertEqual(extraction.whenDate, "today")
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
        XCTAssertEqual(extraction.whenDate, "today")
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
        XCTAssertEqual(extraction.deadline, "tomorrow")
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
        XCTAssertEqual(extraction.whenDate, "friday")
        XCTAssertEqual(extraction.deadline, "monday")
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
        XCTAssertEqual(extraction.whenDate, "today")
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
        XCTAssertEqual(extraction.deadline, "monday")
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
        XCTAssertEqual(extraction.whenDate, "today")
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
        XCTAssertEqual(extraction?.whenDate, "today")
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
        XCTAssertEqual(document.blocks[0].whenDate, "today")
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
