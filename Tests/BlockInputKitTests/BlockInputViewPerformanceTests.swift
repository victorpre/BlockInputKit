import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewPerformanceTests: XCTestCase {
    func testLargeDocumentKeepsMountedCollectionItemsBounded() {
        let document = BlockInputDocument(blocks: (0..<100_000).map { index in
            BlockInputBlock(text: "Block \(index)")
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let view = BlockInputView(frame: window.contentView?.bounds ?? window.frame)
        window.contentView = view

        view.configure(BlockInputConfiguration(document: document))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()

        let mountedItemCount = view.collectionView.visibleItems().count
        XCTAssertEqual(view.collectionView(view.collectionView, numberOfItemsInSection: 0), 100_000)
        XCTAssertGreaterThan(mountedItemCount, 0)
        XCTAssertLessThan(mountedItemCount, 100)
    }
}
