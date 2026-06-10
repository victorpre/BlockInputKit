import AppKit
import SnapshotTesting
import XCTest
@testable import BlockInputKit

extension BlockInputViewSnapshotTests {
    func makeDueDateChipChecklistSnapshotView(for snapshotCase: DueDateChipSnapshotCase) -> NSView {
        let view = BlockInputView(frame: NSRect(origin: .zero, size: snapshotCase.size))
        view.appearance = NSAppearance(named: snapshotCase.appearance)
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: "checklist1",
                    kind: .checklistItem(isChecked: false),
                    text: "finish report !2030-12-31"
                ),
                BlockInputBlock(
                    id: "checklist2",
                    kind: .checklistItem(isChecked: true),
                    text: "old task !2020-01-01"
                )
            ]),
            allowsBlockReordering: false
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        return view
    }

    func testDueDateChipChecklistSnapshots() {
        for snapshotCase in DueDateChipSnapshotCase.matrix {
            assertSnapshot(
                of: makeDueDateChipChecklistSnapshotView(for: snapshotCase),
                as: appKitSnapshotImage(),
                named: "due-date-checklist-\(snapshotCase.name)"
            )
        }
    }
}

struct DueDateChipSnapshotCase {
    var name: String
    var appearance: NSAppearance.Name
    var size: CGSize

    static let matrix: [Self] = [
        Self(name: "light", appearance: .aqua, size: CGSize(width: 620, height: 140)),
        Self(name: "dark", appearance: .darkAqua, size: CGSize(width: 620, height: 140))
    ]
}
