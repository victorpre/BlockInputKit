import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
extension BlockInputViewFileDropTests {
    func testDisabledDropsRejectFileDropWithoutNativeTextInsertion() throws {
        let blockID = BlockInputBlockID(rawValue: "block")
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Open docs")
            ]),
            allowsDrops: false
        ))
        let textView = try disabledDropTextView(in: mounted.view)
        textView.registerForDraggedTypes([.string, .fileURL])
        textView.updateDragTypeRegistration()
        let draggingInfo = BlockInputDraggingInfo(
            fileURLs: [URL(fileURLWithPath: "/tmp/README.md")],
            location: try windowLocation(forUTF16Offset: 5, in: textView)
        )

        XCTAssertTrue(textView.registeredDraggedTypes.isEmpty)
        XCTAssertTrue(textView.draggingEntered(draggingInfo).isEmpty)
        XCTAssertFalse(textView.prepareForDragOperation(draggingInfo))
        XCTAssertFalse(textView.performDragOperation(draggingInfo))
        XCTAssertEqual(mounted.view.document.blocks[0].text, "Open docs")
        XCTAssertEqual(textView.string, "Open docs")
    }

    private func disabledDropTextView(in view: BlockInputView) throws -> BlockInputTextView {
        let item = try XCTUnwrap(view.visibleBlockItemForTesting(at: 0))
        return try XCTUnwrap(item.testingTextView)
    }
}
