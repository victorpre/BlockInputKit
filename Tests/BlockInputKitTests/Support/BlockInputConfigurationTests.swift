import AppKit
import XCTest
@testable import BlockInputKit

final class BlockInputConfigurationTests: XCTestCase {
    func testDocumentUsesConfiguredStoreWhenProvided() {
        let directID = BlockInputBlockID(rawValue: "direct")
        let storeID = BlockInputBlockID(rawValue: "store")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: storeID, text: "Store")
        ]))

        let configuration = BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: directID, text: "Direct")
            ]),
            documentStore: store
        )

        XCTAssertEqual(configuration.document.blocks.map(\.id), [storeID])
    }

    func testDefaultConfigurationCreatesMemoryStoreFromDocument() {
        let blockID = BlockInputBlockID(rawValue: "direct")

        let configuration = BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Direct")
        ]))

        XCTAssertTrue(configuration.documentStore is BlockInputMemoryDocumentStore)
        XCTAssertEqual(configuration.document.blocks.map(\.id), [blockID])
    }

    @MainActor
    func testViewAppliesConfiguredIntegrationSurfaces() {
        let provider = ConfigurationCompletionProvider()
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        let onDocumentMutation: (BlockInputDocumentChange) -> Void = { _ in }
        let onDocumentChange: (BlockInputDocument) -> Void = { _ in }
        let onFocusChange: (Bool) -> Void = { _ in }

        view.configure(BlockInputConfiguration(
            allowsBlockReordering: false,
            dropIndicatorColor: .systemPink,
            undoController: undoController,
            completionProvider: provider,
            onDocumentMutation: onDocumentMutation,
            onDocumentChange: onDocumentChange,
            documentChangeSnapshotDelay: 0.01,
            onFocusChange: onFocusChange
        ))

        XCTAssertFalse(view.allowsBlockReordering)
        XCTAssertEqual(view.dropIndicatorColor, .systemPink)
        XCTAssertTrue(view.undoController === undoController)
        XCTAssertTrue(view.completionProvider === provider)
        XCTAssertNotNil(view.onDocumentMutation)
        XCTAssertNotNil(view.onDocumentChange)
        XCTAssertEqual(view.documentChangeSnapshotDelay, 0.01)
        XCTAssertNotNil(view.onFocusChange)
    }
}

private final class ConfigurationCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        []
    }
}
