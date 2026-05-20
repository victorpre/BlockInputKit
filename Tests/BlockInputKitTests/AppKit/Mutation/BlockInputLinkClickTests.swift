import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputLinkClickTests: XCTestCase {
    func testPlainClickOpensModalAndCommandClickOpensURL() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        var openedURL: URL?
        mounted.view.linkURLOpener = {
            openedURL = $0
            return true
        }
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 7, in: textView)

        XCTAssertTrue(mounted.view.handleLinkClick(
            blockID: "block",
            selectedRange: NSRange(location: 7, length: 0),
            event: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)
        ))
        XCTAssertNotNil(mounted.view.linkModalView)

        mounted.view.dismissLinkModal(restoreFocus: false)
        XCTAssertTrue(mounted.view.handleLinkClick(
            blockID: "block",
            selectedRange: NSRange(location: 7, length: 0),
            event: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber, modifierFlags: .command)
        ))
        XCTAssertEqual(openedURL?.absoluteString, "https://example.com")
    }

    func testPlainClickOpensModalWhenTrackedMouseUpCompletesThroughMonitorPath() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 7, in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    func testPlainClickOpensModalWhenMouseUpLandsOnNeighboringLinkOffsetWithoutDragEvent() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        let textView = try textView(in: mounted.view)
        let mouseDownLocation = try windowLocation(forUTF16Offset: 7, in: textView)
        let mouseUpLocation = try windowLocation(forUTF16Offset: 8, in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: mouseDownLocation, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: mouseUpLocation,
            windowNumber: mounted.window.windowNumber
        )))

        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "docs")
        XCTAssertEqual(modal.urlField.stringValue, "https://example.com")
    }

    func testPlainClickDoesNotOpenModalWhenUnreportedMouseMoveCrossesMultipleOffsets() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        let textView = try textView(in: mounted.view)
        let mouseDownLocation = try windowLocation(forUTF16Offset: 5, in: textView)
        let mouseUpLocation = try windowLocation(forUTF16Offset: 9, in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: mouseDownLocation, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: mouseUpLocation,
            windowNumber: mounted.window.windowNumber
        )))

        XCTAssertNil(mounted.view.linkModalView)
        XCTAssertGreaterThan(textView.selectedRange().length, 1)
    }

    func testCommandClickThroughTextViewMouseDownOpensURL() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        var openedURL: URL?
        mounted.view.linkURLOpener = {
            openedURL = $0
            return true
        }
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 7, in: textView)

        textView.mouseDown(with: try mouseDownEvent(
            location: location,
            windowNumber: mounted.window.windowNumber,
            modifierFlags: .command
        ))

        XCTAssertEqual(openedURL?.absoluteString, "https://example.com")
    }

    func testCommandClickFileLinkThroughTextViewMouseDownAndMouseUpOpensURLOnce() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [file](file:///tmp/demo.md)")
        ])
        var openedURLs: [URL] = []
        mounted.view.linkURLOpener = {
            openedURLs.append($0)
            return true
        }
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 7, in: textView)

        textView.mouseDown(with: try mouseDownEvent(
            location: location,
            windowNumber: mounted.window.windowNumber,
            modifierFlags: .command
        ))
        textView.mouseUp(with: try mouseUpEvent(
            location: location,
            windowNumber: mounted.window.windowNumber,
            modifierFlags: .command
        ))

        XCTAssertEqual(openedURLs.map(\.absoluteString), ["file:///tmp/demo.md"])
        XCTAssertNil(mounted.view.linkModalView)
    }

    func testCommandClickOpensSupportedLinkSchemes() throws {
        let urls = [
            "http://example.com",
            "https://example.com",
            "file:///tmp/demo.md"
        ]

        for urlString in urls {
            let mounted = makeMountedBlockInputView(blocks: [
                BlockInputBlock(id: "block", text: "Open [docs](\(urlString))")
            ])
            var openedURL: URL?
            mounted.view.linkURLOpener = {
                openedURL = $0
                return true
            }
            let textView = try textView(in: mounted.view)
            let location = try windowLocation(forUTF16Offset: 7, in: textView)

            XCTAssertTrue(mounted.view.handleLinkClick(
                blockID: "block",
                selectedRange: NSRange(location: 7, length: 0),
                event: try mouseDownEvent(
                    location: location,
                    windowNumber: mounted.window.windowNumber,
                    modifierFlags: .command
                )
            ))
            XCTAssertEqual(openedURL?.absoluteString, urlString)
        }
    }

    func testPlainClickFileURLOpensModalLikeRegularLinks() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [file](<file:///tmp/demo.md>)")
        ])
        var openedURL: URL?
        mounted.view.linkURLOpener = {
            openedURL = $0
            return true
        }
        let textView = try textView(in: mounted.view)
        let location = try windowLocation(forUTF16Offset: 7, in: textView)

        XCTAssertTrue(mounted.view.handleLinkClick(
            blockID: "block",
            selectedRange: NSRange(location: 7, length: 0),
            event: try mouseDownEvent(location: location, windowNumber: mounted.window.windowNumber)
        ))

        XCTAssertNil(openedURL)
        let modal = try XCTUnwrap(mounted.view.linkModalView)
        XCTAssertEqual(modal.textField.stringValue, "file")
        XCTAssertEqual(modal.urlField.stringValue, "file:///tmp/demo.md")
    }

    func testFileLinkFullSourceResolvesForChipClickButRegularLinkDoesNot() throws {
        let fileText = "Open [file](file:///tmp/demo.md) now"
        let regularText = "Open [docs](https://example.com) now"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: fileText)
        ])
        let fileOpeningBracket = (fileText as NSString).range(of: "[").location
        let filePostBoundary = NSMaxRange((fileText as NSString).range(of: "[file](file:///tmp/demo.md)"))
        let regularOpeningBracket = (regularText as NSString).range(of: "[").location

        XCTAssertNotNil(mounted.view.linkRange(
            in: fileText,
            containing: NSRange(location: fileOpeningBracket, length: 0)
        ))
        XCTAssertNil(mounted.view.linkRange(
            in: fileText,
            containing: NSRange(location: filePostBoundary, length: 0)
        ))
        XCTAssertNil(mounted.view.linkRange(
            in: regularText,
            containing: NSRange(location: regularOpeningBracket, length: 0)
        ))
    }

    func testDraggingFromLinkTextDoesNotOpenModalOnMouseUp() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "block", text: "Open [docs](https://example.com)")
        ])
        let textView = try textView(in: mounted.view)
        let startLocation = try windowLocation(forUTF16Offset: 7, in: textView)
        let endLocation = try windowLocation(forUTF16Offset: 9, in: textView)

        textView.mouseDown(with: try mouseDownEvent(location: startLocation, windowNumber: mounted.window.windowNumber))
        textView.mouseDragged(with: try mouseDraggedEvent(location: endLocation, windowNumber: mounted.window.windowNumber))
        XCTAssertTrue(textView.completeTrackedMouseUp(with: try mouseUpEvent(
            location: endLocation,
            windowNumber: mounted.window.windowNumber
        )))

        XCTAssertNil(mounted.view.linkModalView)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 2))
    }

    private func textView(in view: BlockInputView) throws -> BlockInputTextView {
        let item = try XCTUnwrap(view.visibleBlockItemForTesting(at: 0))
        return try XCTUnwrap(item.testingTextView)
    }
}
