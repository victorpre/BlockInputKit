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

    func testStoreBackedTypingDoesNotReadFullDocumentSnapshot() throws {
        let (blockID, document) = largeDocument(targetText: "Editable")
        let store = DocumentReadCountingStore(document: document)
        let view = BlockInputView()
        var publishedDocument: BlockInputDocument?
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { publishedDocument = $0 }
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: try XCTUnwrap(store.block(withID: blockID)),
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        store.resetCounts()

        textView.string = "Editable text"
        textView.setSelectedRange(NSRange(location: 13, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        view.blockItem(item, didChangeSelectionIn: blockID)

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [blockID])
        XCTAssertEqual(store.block(withID: blockID)?.text, "Editable text")
        XCTAssertEqual(publishedDocument?.block(withID: blockID)?.text, "Editable text")
    }

    func testStoreBackedTypingRefreshesStaleCacheBeforePublishingDocument() throws {
        let blockID = BlockInputBlockID(rawValue: "target")
        let insertedID = BlockInputBlockID(rawValue: "inserted")
        let store = DocumentReadCountingStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Editable")
        ]))
        let view = BlockInputView()
        var publishedDocument: BlockInputDocument?
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { publishedDocument = $0 }
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: try XCTUnwrap(store.block(withID: blockID)),
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: insertedID, text: "Inserted"),
            BlockInputBlock(id: blockID, text: "Editable")
        ]))
        store.resetCounts()

        textView.string = "Editable text"
        textView.setSelectedRange(NSRange(location: 13, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.documentReadCount, 1)
        XCTAssertEqual(store.replacedBlockIDs, [blockID])
        XCTAssertEqual(publishedDocument?.blocks.map(\.id), [insertedID, blockID])
        XCTAssertEqual(publishedDocument?.block(withID: blockID)?.text, "Editable text")
    }

    func testStoreBackedFocusAndSelectionDoNotReadFullDocumentSnapshot() throws {
        let (blockID, document) = largeDocument(targetText: "Selectable")
        let store = DocumentReadCountingStore(document: document)
        let view = BlockInputView()
        var publishedSelections: [BlockInputSelection?] = []
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onSelectionChange: { publishedSelections.append($0) }
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: try XCTUnwrap(store.block(withID: blockID)),
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        store.resetCounts()

        textView.setSelectedRange(NSRange(location: 2, length: 4))
        view.blockItemDidBeginEditing(item, blockID: blockID)
        view.blockItem(item, didChangeSelectionIn: blockID)

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [])
        XCTAssertEqual(
            publishedSelections.last ?? nil,
            .text(BlockInputTextRange(blockID: blockID, range: NSRange(location: 2, length: 4)))
        )
    }

    func testStoreBackedSingleLineTypingDoesNotInvalidateLayout() throws {
        let context = try typingLayoutTestContext()
        let textView = try XCTUnwrap(context.item.testingTextView)

        textView.string = "Second edited"
        textView.setSelectedRange(NSRange(location: 13, length: 0))
        context.item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(context.store.block(withID: context.blockID)?.text, "Second edited")
        XCTAssertEqual(context.layout.invalidatedItemIndexPaths, [])
        XCTAssertFalse(context.layout.didInvalidateDelegateMetrics)
        XCTAssertFalse(context.layout.didInvalidateEverything)
    }

    func testStoreBackedIndentDoesNotReadFullDocumentSnapshotOrInvalidateLayout() throws {
        let targetIndex = 50_000
        let blockID = BlockInputBlockID(rawValue: "block-\(targetIndex)")
        let document = BlockInputDocument(blocks: (0..<100_000).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "block-\(index)"),
                kind: .bulletedListItem,
                text: index == targetIndex ? "Editable" : "Block \(index)"
            )
        })
        let store = DocumentReadCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        let layout = TrackingCollectionViewFlowLayout()
        view.collectionView.collectionViewLayout = layout
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: try XCTUnwrap(store.block(withID: blockID)),
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        store.resetCounts()
        layout.reset()

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [blockID])
        XCTAssertEqual(store.block(withID: blockID)?.indentationLevel, 1)
        XCTAssertEqual(view.document.block(withID: blockID)?.indentationLevel, 1)
        XCTAssertFalse(layout.didInvalidateDelegateMetrics)
        XCTAssertFalse(layout.didInvalidateEverything)
    }

    func testStoreBackedIndentInvalidatesLayoutWhenWrappingHeightChanges() throws {
        let blockID = BlockInputBlockID(rawValue: "second")
        let text = "This is a long list item that should wrap after indentation reduces the available text width."
        let block = BlockInputBlock(id: blockID, kind: .bulletedListItem, text: text)
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: "first", text: "First"),
            block,
            BlockInputBlock(id: "third", text: "Third")
        ]))
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 260, height: 480))
        let layout = TrackingCollectionViewFlowLayout()
        view.collectionView.collectionViewLayout = layout
        view.configure(BlockInputConfiguration(documentStore: store))
        layout.reset()
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: view
        )
        let itemWidth: CGFloat = 260
        let textWidth = itemWidth - BlockInputBlockItem.horizontalChromeWidth(allowsReordering: true)
        let startingHeight = BlockInputBlockItem.height(for: block, textWidth: textWidth)
        item.view.frame = NSRect(x: 0, y: 0, width: itemWidth, height: startingHeight)
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))

        let updatedBlock = try XCTUnwrap(store.block(withID: blockID))
        let expectedHeight = BlockInputBlockItem.height(for: updatedBlock, textWidth: textWidth)
        XCTAssertGreaterThan(expectedHeight, startingHeight)
        XCTAssertEqual(item.view.frame.height, expectedHeight, accuracy: 0.5)
        XCTAssertTrue(layout.didInvalidateDelegateMetrics)
        XCTAssertFalse(layout.didInvalidateEverything)
    }

    func testStoreBackedTypingInvalidatesEditedItemWhenHeightChanges() throws {
        let context = try typingLayoutTestContext()
        let textView = try XCTUnwrap(context.item.testingTextView)

        textView.string = "Second\nedited"
        textView.setSelectedRange(NSRange(location: 13, length: 0))
        context.item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(context.store.block(withID: context.blockID)?.text, "Second\nedited")
        XCTAssertEqual(context.layout.invalidatedItemIndexPaths, [])
        XCTAssertTrue(context.layout.didInvalidateEverything)
    }

    func testStoreBackedListInlineReturnInvalidatesFullLayout() throws {
        let context = try typingLayoutTestContext(block: BlockInputBlock(
            id: "second",
            kind: .bulletedListItem,
            text: "Second"
        ))
        let textView = try XCTUnwrap(context.item.testingTextView)

        textView.string = "Second\nitem"
        textView.setSelectedRange(NSRange(location: 11, length: 0))
        context.item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(context.store.block(withID: context.blockID)?.text, "Second\nitem")
        XCTAssertEqual(context.layout.invalidatedItemIndexPaths, [])
        XCTAssertTrue(context.layout.didInvalidateEverything)
    }
}

private func largeDocument(targetText: String) -> (BlockInputBlockID, BlockInputDocument) {
    let targetIndex = 50_000
    let blockID = BlockInputBlockID(rawValue: "block-\(targetIndex)")
    let document = BlockInputDocument(blocks: (0..<100_000).map { index in
        BlockInputBlock(
            id: BlockInputBlockID(rawValue: "block-\(index)"),
            text: index == targetIndex ? targetText : "Block \(index)"
        )
    })
    return (blockID, document)
}

@MainActor
private func typingLayoutTestContext(
    block: BlockInputBlock = BlockInputBlock(id: "second", text: "Second"),
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> TypingLayoutTestContext {
    let blockID = block.id
    let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
        BlockInputBlock(id: "first", text: "First"),
        block,
        BlockInputBlock(id: "third", text: "Third")
    ]))
    let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
    let layout = TrackingCollectionViewFlowLayout()
    view.collectionView.collectionViewLayout = layout
    view.configure(BlockInputConfiguration(documentStore: store))
    layout.reset()
    let item = BlockInputBlockItem.configuredForTesting(
        block: try XCTUnwrap(store.block(withID: blockID), file: file, line: line),
        allowsReordering: true,
        delegate: view
    )
    item.view.frame = NSRect(x: 0, y: 0, width: 720, height: 44)
    return TypingLayoutTestContext(blockID: blockID, store: store, view: view, layout: layout, item: item)
}

private struct TypingLayoutTestContext {
    let blockID: BlockInputBlockID
    let store: BlockInputMemoryDocumentStore
    let view: BlockInputView
    let layout: TrackingCollectionViewFlowLayout
    let item: BlockInputBlockItem
}

private final class TrackingCollectionViewFlowLayout: NSCollectionViewFlowLayout {
    private(set) var invalidatedItemIndexPaths: [IndexPath] = []
    private(set) var didInvalidateEverything = false
    private(set) var didInvalidateDelegateMetrics = false

    func reset() {
        invalidatedItemIndexPaths = []
        didInvalidateEverything = false
        didInvalidateDelegateMetrics = false
    }

    override func invalidateLayout() {
        didInvalidateEverything = true
        super.invalidateLayout()
    }

    override func invalidateLayout(with context: NSCollectionViewLayoutInvalidationContext) {
        invalidatedItemIndexPaths.append(contentsOf: context.invalidatedItemIndexPaths ?? [])
        didInvalidateDelegateMetrics =
            didInvalidateDelegateMetrics
            || (context as? NSCollectionViewFlowLayoutInvalidationContext)?.invalidateFlowLayoutDelegateMetrics == true
        super.invalidateLayout(with: context)
    }
}

private final class DocumentReadCountingStore: BlockInputDocumentStore {
    private var storedDocument: BlockInputDocument
    private(set) var documentReadCount = 0
    private(set) var replacedBlockIDs: [BlockInputBlockID] = []

    var document: BlockInputDocument {
        documentReadCount += 1
        return storedDocument
    }

    var blockCount: Int {
        storedDocument.blocks.count
    }

    init(document: BlockInputDocument) {
        storedDocument = document
    }

    func resetCounts() {
        documentReadCount = 0
        replacedBlockIDs = []
    }

    func block(at index: Int) -> BlockInputBlock? {
        guard storedDocument.blocks.indices.contains(index) else {
            return nil
        }
        return storedDocument.blocks[index]
    }

    func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        storedDocument.block(withID: id)
    }

    func index(of id: BlockInputBlockID) -> Int? {
        storedDocument.index(of: id)
    }

    func replaceDocument(_ document: BlockInputDocument) {
        storedDocument = document
    }

    func replaceBlock(_ block: BlockInputBlock) {
        replacedBlockIDs.append(block.id)
        guard let index = storedDocument.index(of: block.id) else {
            return
        }
        storedDocument.blocks[index] = block
    }
}
