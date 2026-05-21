import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputLinkClickJitterTests: XCTestCase {
    func testPlainClickRegularLinkUsesMouseDownHitWhenMouseUpHasNoClickCount() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber,
            clickCount: 0
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    func testPlainClickRegularLinkAllowsTrackedDragJitterInsideMouseDownHit() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)
        let contentRange = (text as NSString).range(of: "docs")

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))
        textView.blockSelectionLocalDragRange = NSRange(location: contentRange.location, length: 1)
        textView.blockSelectionDragSelectedRange = NSRange(location: contentRange.location, length: 1)
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: NSPoint(x: location.x + 5, y: location.y),
            windowNumber: mounted.window.windowNumber
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    func testPlainClickRegularLinkAllowsTinyTrackedDragJitterOutsideMouseDownHit() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)
        let hit = try XCTUnwrap(textView.linkHitResult(atWindowLocation: location))
        let hitRect = try XCTUnwrap(hit.windowRects.first)
        let mouseDownLocation = NSPoint(x: hitRect.maxX - 1, y: hitRect.midY)
        let mouseUpLocation = NSPoint(x: hitRect.maxX + 3, y: hitRect.midY)

        XCTAssertTrue(hit.windowRects.contains { $0.contains(mouseDownLocation) })
        XCTAssertFalse(hit.windowRects.contains { $0.contains(mouseUpLocation) })
        textView.mouseDown(with: try mouseDownEvent(location: mouseDownLocation, windowNumber: mounted.window.windowNumber))
        textView.mouseDragged(with: try mouseDraggedEvent(location: mouseUpLocation, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: mouseUpLocation,
            windowNumber: mounted.window.windowNumber
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    func testPlainClickRegularLinkAllowsTinyTrackedDragJitterInsideMouseDownHit() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)
        let contentRange = (text as NSString).range(of: "docs")

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))
        textView.blockSelectionLocalDragRange = NSRange(location: contentRange.location, length: 1)
        textView.blockSelectionDragSelectedRange = NSRange(location: contentRange.location, length: 1)
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    private func textView(in view: BlockInputView) throws -> BlockInputTextView {
        let item = try XCTUnwrap(view.visibleBlockItemForTesting(at: 0))
        return try XCTUnwrap(item.testingTextView)
    }

    private func contentLocation(_ content: String, in text: String) -> Int {
        (text as NSString).range(of: content).location
    }
}
