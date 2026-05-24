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
        XCTAssertEqual(configuration.editorHorizontalInset, BlockInputConfiguration.defaultEditorHorizontalInset)
        XCTAssertEqual(configuration.editorVerticalInset, BlockInputConfiguration.defaultEditorVerticalInset)
        XCTAssertNil(configuration.placeholder)
        XCTAssertNil(configuration.heightSizing)
        XCTAssertEqual(configuration.slashCommandAvailability, .documentStart)
        XCTAssertNil(configuration.slashCommandChipClickHandler)
    }

    func testHeightSizingInitializerPreservesValues() {
        let sizing = BlockInputEditorHeightSizing(
            defaultVisibleLineCount: 3,
            maximumVisibleLineCount: 8,
            onPreferredHeightChange: { _ in }
        )

        XCTAssertEqual(sizing.defaultVisibleLineCount, 3)
        XCTAssertEqual(sizing.maximumVisibleLineCount, 8)
        XCTAssertNotNil(sizing.onPreferredHeightChange)
    }

    @MainActor
    func testViewAppliesConfiguredIntegrationSurfaces() throws {
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        let onDocumentMutation: (BlockInputDocumentChange) -> Void = { _ in }
        let onDocumentChange: (BlockInputDocument) -> Void = { _ in }
        let onFocusChange: (Bool) -> Void = { _ in }

        view.configure(BlockInputConfiguration(
            allowsBlockReordering: false,
            editorHorizontalInset: 28,
            editorVerticalInset: 14,
            placeholder: "Message",
            dropIndicatorColor: .systemPink,
            heightSizing: BlockInputEditorHeightSizing(defaultVisibleLineCount: 2, maximumVisibleLineCount: 5),
            undoController: undoController,
            onDocumentMutation: onDocumentMutation,
            onDocumentChange: onDocumentChange,
            documentChangeSnapshotDelay: 0.01,
            onFocusChange: onFocusChange
        ))

        XCTAssertFalse(view.allowsBlockReordering)
        XCTAssertEqual(view.editorHorizontalInset, 28)
        XCTAssertEqual(view.editorVerticalInset, 14)
        XCTAssertEqual(view.placeholder, "Message")
        let sectionInset = try XCTUnwrap((view.collectionView.collectionViewLayout as? NSCollectionViewFlowLayout)?.sectionInset)
        XCTAssertEqual(sectionInset.top, 14)
        XCTAssertEqual(sectionInset.bottom, 14)
        XCTAssertEqual(sectionInset.left, 0)
        XCTAssertEqual(sectionInset.right, 0)
        XCTAssertEqual(view.dropIndicatorColor, .systemPink)
        XCTAssertEqual(view.heightSizing?.defaultVisibleLineCount, 2)
        XCTAssertEqual(view.heightSizing?.maximumVisibleLineCount, 5)
        XCTAssertTrue(view.undoController === undoController)
        XCTAssertNotNil(view.onDocumentMutation)
        XCTAssertNotNil(view.onDocumentChange)
        XCTAssertEqual(view.documentChangeSnapshotDelay, 0.01)
        XCTAssertNotNil(view.onFocusChange)
    }

    @MainActor
    func testViewAppliesConfiguredCompletionSurfaces() {
        let provider = ConfigurationCompletionProvider()
        let view = BlockInputView()
        let container = NSView()

        view.configure(BlockInputConfiguration(
            completionProvider: provider,
            slashCommandAvailability: .anywhere,
            slashCommandChipClickHandler: { _ in .hostHandled },
            completionPopupConfiguration: BlockInputCompletionPopupConfiguration(
                placement: .overlay,
                overlayProvider: { context in
                    BlockInputCompletionPopupOverlay(container: container, frame: context.defaultFrame)
                }
            )
        ))

        XCTAssertTrue(view.completionProvider === provider)
        XCTAssertEqual(view.slashCommandAvailability, .anywhere)
        XCTAssertNotNil(view.slashCommandChipClickHandler)
        XCTAssertEqual(view.completionPopupPlacement, .overlay)
        let overlay = view.completionPopupConfiguration.overlayProvider?(BlockInputCompletionPopupOverlayContext(
            editorView: view,
            defaultContainer: view,
            defaultFrame: .zero,
            popupSize: .zero
        ))
        XCTAssertTrue(overlay?.container === container)
    }

    func testCompletionPopupPlacementParameterBuildsPopupConfiguration() {
        var configuration = BlockInputConfiguration(completionPopupPlacement: .overlay)

        XCTAssertEqual(configuration.completionPopupConfiguration.placement, .overlay)
        XCTAssertEqual(configuration.completionPopupPlacement, .overlay)

        configuration.completionPopupPlacement = .caret

        XCTAssertEqual(configuration.completionPopupConfiguration.placement, .caret)
    }

    @MainActor
    func testDefaultUndoControllerResetsWhenViewReconfiguresToNewStore() throws {
        let blockID = BlockInputBlockID(rawValue: "list")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        item.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(item.requestIndent())
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)

        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Second")
        ])))

        XCTAssertNil(view.undoStructuralEdit())
        XCTAssertEqual(view.document.blocks[0].text, "Second")
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
    }

    @MainActor
    func testDefaultUndoControllerSurvivesEquivalentDefaultStoreReconfigure() throws {
        let blockID = BlockInputBlockID(rawValue: "list")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        item.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(item.requestIndent())
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)

        view.configure(BlockInputConfiguration(document: view.document))

        XCTAssertNotNil(view.undoStructuralEdit())
        XCTAssertEqual(view.document.blocks[0].text, "First")
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
    }

    @MainActor
    func testDefaultUndoControllerResetsWhenDefaultConfigurationStoreIsReplaced() throws {
        let blockID = BlockInputBlockID(rawValue: "list")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        item.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(item.requestIndent())
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)

        var configuration = BlockInputConfiguration(document: view.document)
        configuration.documentStore = BlockInputMemoryDocumentStore(document: view.document)
        view.configure(configuration)

        XCTAssertNil(view.undoStructuralEdit())
        XCTAssertEqual(view.document.blocks[0].text, "First")
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)
    }
}

private final class ConfigurationCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        []
    }
}
