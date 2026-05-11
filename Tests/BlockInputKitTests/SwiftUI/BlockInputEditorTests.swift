import SwiftUI
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputEditorTests: XCTestCase {
    func testFocusBindingTracksSelectionChangesAndPreservesSelectionHandler() {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = false
        var publishedSelections: [BlockInputSelection?] = []
        var publishedFocusValues: [Bool] = []
        let editor = BlockInputEditor(
            configuration: BlockInputConfiguration(
                onSelectionChange: { publishedSelections.append($0) },
                onFocusChange: { publishedFocusValues.append($0) }
            ),
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            )
        )
        let resolvedConfiguration = editor.resolvedConfiguration()

        resolvedConfiguration.onSelectionChange?(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
        XCTAssertFalse(isFocused)
        resolvedConfiguration.onSelectionChange?(nil)
        resolvedConfiguration.onFocusChange?(true)
        XCTAssertTrue(isFocused)
        resolvedConfiguration.onFocusChange?(false)

        XCTAssertEqual(publishedSelections, [
            .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)),
            nil
        ])
        XCTAssertEqual(publishedFocusValues, [true, false])
        XCTAssertFalse(isFocused)
    }

    func testFocusBindingFocusesAndResignsMountedEditor() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = true
        let editor = BlockInputEditor(isFocused: Binding(
            get: { isFocused },
            set: { isFocused = $0 }
        ))
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])

        editor.updateFocusState(on: mounted.view)

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertTrue(mounted.window.firstResponder === item.testingTextView)
        XCTAssertTrue(mounted.view.isEditorFirstResponder)

        isFocused = false
        editor.updateFocusState(on: mounted.view)

        XCTAssertFalse(mounted.view.isEditorFirstResponder)
    }

    func testMissingFocusBindingLeavesResponderStateUntouched() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let editor = BlockInputEditor()
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.focus(blockID: blockID, utf16Offset: 2)
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertTrue(mounted.window.firstResponder === item.testingTextView)

        editor.updateFocusState(on: mounted.view)

        XCTAssertTrue(mounted.window.firstResponder === item.testingTextView)
    }

    func testFalseFocusBindingDoesNotRestoreExistingSelectionDuringUpdate() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = false
        let editor = BlockInputEditor(isFocused: Binding(
            get: { isFocused },
            set: { isFocused = $0 }
        ))
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 2)), notify: false)
        mounted.window.makeFirstResponder(nil)

        editor.updateView(mounted.view)

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertFalse(mounted.window.firstResponder === item.testingTextView)
        XCTAssertFalse(mounted.view.isEditorFirstResponder)
        XCTAssertFalse(isFocused)
    }

    func testFalseFocusBindingCancelsPendingSelectionRestore() async throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = false
        let editor = BlockInputEditor(isFocused: Binding(
            get: { isFocused },
            set: { isFocused = $0 }
        ))
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 2)), notify: false)
        mounted.view.reloadDataKeepingFocus()

        editor.updateView(mounted.view)
        await Task.yield()
        await Task.yield()

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertFalse(mounted.window.firstResponder === item.testingTextView)
        XCTAssertFalse(mounted.view.isEditorFirstResponder)
        XCTAssertFalse(isFocused)
    }

    func testFalseFocusBindingResignsBeforeReconfiguringFocusedEditor() async throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = true
        var focusValues: [Bool] = []
        let lostFocus = expectation(description: "Publishes focus loss")
        let editor = BlockInputEditor(
            configuration: BlockInputConfiguration(
                document: BlockInputDocument(blocks: [
                    BlockInputBlock(id: blockID, text: "First")
                ]),
                onFocusChange: { focused in
                    focusValues.append(focused)
                    if !focused {
                        lostFocus.fulfill()
                    }
                }
            ),
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            )
        )
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.configure(editor.resolvedConfiguration())
        mounted.view.focus(blockID: blockID, utf16Offset: 1)
        XCTAssertTrue(mounted.view.isEditorFirstResponder)

        isFocused = false
        editor.updateView(mounted.view)

        await fulfillment(of: [lostFocus], timeout: 1)
        XCTAssertEqual(focusValues, [true, false])
        XCTAssertFalse(isFocused)
    }

    func testFalseFocusBindingPublishesLossThroughCurrentConfiguration() async {
        let blockID = BlockInputBlockID(rawValue: "first")
        var isFocused = true
        var staleFocusValues: [Bool] = []
        var currentFocusValues: [Bool] = []
        let lostFocus = expectation(description: "Publishes focus loss")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        let staleEditor = BlockInputEditor(
            configuration: BlockInputConfiguration(
                document: BlockInputDocument(blocks: [
                    BlockInputBlock(id: blockID, text: "First")
                ]),
                onFocusChange: { staleFocusValues.append($0) }
            ),
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            )
        )
        staleEditor.updateView(mounted.view)
        mounted.view.focus(blockID: blockID, utf16Offset: 0)
        XCTAssertTrue(isFocused)

        isFocused = false
        let currentEditor = BlockInputEditor(
            configuration: BlockInputConfiguration(
                document: BlockInputDocument(blocks: [
                    BlockInputBlock(id: blockID, text: "First")
                ]),
                onFocusChange: { focused in
                    currentFocusValues.append(focused)
                    if !focused {
                        lostFocus.fulfill()
                    }
                }
            ),
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            )
        )

        currentEditor.updateView(mounted.view)

        await fulfillment(of: [lostFocus], timeout: 1)
        XCTAssertEqual(staleFocusValues, [true])
        XCTAssertEqual(currentFocusValues, [false])
    }
}
