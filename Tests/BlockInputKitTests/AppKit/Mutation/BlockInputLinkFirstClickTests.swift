import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputLinkFirstClickTests: XCTestCase {
    func testTextViewAcceptsFirstMouseForImmediateLinkClicks() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)
        let event = try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)

        XCTAssertTrue(textView.acceptsFirstMouse(for: event))
    }

    func testBlockContainersAcceptFirstMouseForImmediateLinkClicks() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)
        let event = try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)

        XCTAssertTrue(item.view.acceptsFirstMouse(for: event))
        XCTAssertTrue(item.scrollView.acceptsFirstMouse(for: event))
        XCTAssertTrue(item.scrollView.contentView.acceptsFirstMouse(for: event))
        XCTAssertTrue(mounted.view.collectionView.acceptsFirstMouse(for: event))
    }

    func testTextViewDoesNotBroadenFirstMouseAwayFromLinks() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 0, in: textView)
        let event = try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)

        XCTAssertFalse(textView.acceptsFirstMouse(for: event))
    }

    func testBlockContainersDoNotBroadenFirstMouseAwayFromLinks() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let location = try windowLocation(forUTF16Offset: 0, in: textView)
        let event = try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)

        XCTAssertFalse(item.view.acceptsFirstMouse(for: event))
        XCTAssertFalse(item.scrollView.acceptsFirstMouse(for: event))
        XCTAssertFalse(item.scrollView.contentView.acceptsFirstMouse(for: event))
        XCTAssertFalse(mounted.view.collectionView.acceptsFirstMouse(for: event))
    }

    func testClipViewMouseDownOnLinkForwardsToTextViewLinkClickPath() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        item.scrollView.contentView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))

        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertEqual(mounted.view.linkModalView?.textField.stringValue, "docs")
    }

    func testRootViewMouseDownOnLinkForwardsToTextViewLinkClickPath() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        item.view.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))

        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertEqual(mounted.view.linkModalView?.textField.stringValue, "docs")
    }

    func testScrollViewMouseDownOnLinkForwardsToTextViewLinkClickPath() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        item.scrollView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))

        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertEqual(mounted.view.linkModalView?.textField.stringValue, "docs")
    }

    func testCollectionViewMouseDownOnLinkForwardsToTextViewLinkClickPath() throws {
        let text = "Open [docs](https://example.com)"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: text)
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        mounted.view.collectionView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))

        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertEqual(mounted.view.linkModalView?.textField.stringValue, "docs")
    }

    func testPlainClickRegularLinkDoesNotPublishCursorSelectionBeforeMouseUp() throws {
        let text = "Open [docs](https://example.com)"
        var publishedSelections: [BlockInputSelection?] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: text)
            ]),
            onSelectionChange: { publishedSelections.append($0) }
        ))
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))

        XCTAssertTrue(publishedSelections.isEmpty)
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertNotNil(mounted.view.linkModalView)
    }

    func testPendingLinkClickDragJitterDoesNotPublishCursorSelectionBeforeMouseUp() throws {
        let text = "Open [docs](https://example.com)"
        var publishedSelections: [BlockInputSelection?] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: text)
            ]),
            onSelectionChange: { publishedSelections.append($0) }
        ))
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: contentLocation("docs", in: text), in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))
        textView.mouseDragged(with: try mouseDraggedEvent(
            location: NSPoint(x: location.x + 1, y: location.y),
            windowNumber: mounted.window.windowNumber
        ))

        XCTAssertTrue(publishedSelections.isEmpty)
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))
        XCTAssertNotNil(mounted.view.linkModalView)
    }

    private func textView(in view: BlockInputView) throws -> BlockInputTextView {
        let item = try XCTUnwrap(view.visibleBlockItemForTesting(at: 0))
        return try XCTUnwrap(item.testingTextView)
    }

    private func contentLocation(_ content: String, in text: String) -> Int {
        (text as NSString).range(of: content).location
    }
}
