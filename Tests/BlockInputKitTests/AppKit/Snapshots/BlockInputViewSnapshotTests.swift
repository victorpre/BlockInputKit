import AppKit
import SnapshotTesting
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewSnapshotTests: XCTestCase {
    func testRepresentativeDocumentSnapshots() {
        for snapshotCase in SnapshotCase.representativeMatrix {
            assertSnapshot(
                of: makeSnapshotView(for: snapshotCase),
                as: .image(precision: 0.995, perceptualPrecision: 0.995),
                named: snapshotCase.name
            )
        }
    }

    private func makeSnapshotView(for snapshotCase: SnapshotCase) -> NSView {
        let view = BlockInputView(frame: NSRect(origin: .zero, size: snapshotCase.size))
        view.appearance = NSAppearance(named: snapshotCase.appearance)
        view.configure(BlockInputConfiguration(
            document: .snapshotRepresentative,
            // Snapshot the steady-state editor surface; hover-only drag chrome is covered by layout tests.
            allowsBlockReordering: false,
            dropIndicatorColor: .systemBlue
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        return view
    }
}

private struct SnapshotCase {
    var name: String
    var appearance: NSAppearance.Name
    var size: CGSize

    static let representativeMatrix: [Self] = [
        Self(name: "light-default", appearance: .aqua, size: CGSize(width: 680, height: 460)),
        Self(name: "dark-default", appearance: .darkAqua, size: CGSize(width: 680, height: 460)),
        Self(name: "light-large", appearance: .aqua, size: CGSize(width: 920, height: 620)),
        Self(name: "dark-large", appearance: .darkAqua, size: CGSize(width: 920, height: 620))
    ]
}

private extension BlockInputDocument {
    // One document intentionally covers all built-in block renderers so the
    // appearance/size matrix stays small and stable.
    static let snapshotRepresentative = BlockInputDocument(blocks: [
        BlockInputBlock(id: "heading", kind: .heading(level: 1), text: "BlockInputKit demo"),
        BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Each visible block owns its own AppKit text input."),
        BlockInputBlock(id: "quote", kind: .quote, text: "Focus, selection, return, delete, and Cmd+A coordinate across blocks."),
        BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let editor = BlockInputView()\neditor.focusEditor()"),
        BlockInputBlock(
            id: "bullets",
            kind: .bulletedListItem,
            text: "Hover rows to reveal reorder handles\nNested bullet\nDeep nested bullet",
            lineIndentationLevels: [0, 1, 2]
        ),
        BlockInputBlock(
            id: "numbers",
            kind: .numberedListItem(start: 1),
            text: "Toggle reordering from the toolbar\nNested ordered item\nDeep nested ordered item",
            lineIndentationLevels: [0, 1, 2]
        ),
        BlockInputBlock(id: "check-open", kind: .checklistItem(isChecked: false), text: "Checklist data round-trips through Markdown"),
        BlockInputBlock(id: "check-done", kind: .checklistItem(isChecked: true), text: "Checked state renders without Markdown text"),
        BlockInputBlock(id: "rule", kind: .horizontalRule),
        BlockInputBlock(id: "tail", kind: .paragraph, text: "Try mention query: @av")
    ])
}
