import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputDetailButtonCursorTests: XCTestCase {
    func testChecklistDetailButtonClaimsPointingHandWithoutEditableSurfaceIBeamOverlap() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(
                id: "checklist",
                kind: .checklistItem(isChecked: false),
                text: "Task item",
                whenDate: "2026-06-15"
            )
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let detailButton = try XCTUnwrap(item.testingDetailButton)
        let detailButtonPointInItem = detailButton.convert(
            NSPoint(x: detailButton.bounds.midX, y: detailButton.bounds.midY),
            to: item.view
        )
        let detailButtonWindowPoint = item.view.convert(detailButtonPointInItem, to: nil)
        let detailButtonEvent = try mouseMovedEvent(
            location: detailButtonWindowPoint,
            windowNumber: mounted.window.windowNumber
        )

        XCTAssertTrue(item.editableTextSurfaceCursorRects(in: item.view).allSatisfy { !$0.contains(detailButtonPointInItem) })

        NSCursor.arrow.set()
        item.view.cursorUpdate(with: detailButtonEvent)
        XCTAssertEqual(NSCursor.current, .pointingHand)

        NSCursor.arrow.set()
        textView.cursorUpdate(with: detailButtonEvent)
        XCTAssertEqual(NSCursor.current, .pointingHand)

        NSCursor.arrow.set()
        textView.mouseMoved(with: detailButtonEvent)
        XCTAssertEqual(NSCursor.current, .pointingHand)

        if let scrollView = item.testingTextScrollView {
            NSCursor.arrow.set()
            scrollView.cursorUpdate(with: detailButtonEvent)
            XCTAssertNotEqual(NSCursor.current, .iBeam)

            NSCursor.arrow.set()
            scrollView.contentView.cursorUpdate(with: detailButtonEvent)
            XCTAssertNotEqual(NSCursor.current, .iBeam)
        }

        let textPointInItem = NSPoint(x: detailButtonPointInItem.x - 8, y: detailButtonPointInItem.y)
        let textWindowPoint = item.view.convert(textPointInItem, to: nil)
        let textEvent = try mouseMovedEvent(location: textWindowPoint, windowNumber: mounted.window.windowNumber)

        NSCursor.arrow.set()
        item.view.cursorUpdate(with: textEvent)
        XCTAssertEqual(NSCursor.current, .iBeam)

        NSCursor.arrow.set()
        textView.cursorUpdate(with: textEvent)
        XCTAssertEqual(NSCursor.current, .iBeam)
    }
}
