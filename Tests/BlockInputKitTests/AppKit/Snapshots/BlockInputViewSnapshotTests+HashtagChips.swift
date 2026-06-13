import AppKit
import SnapshotTesting
import XCTest
@testable import BlockInputKit

extension BlockInputViewSnapshotTests {
    func makeHashtagChipChecklistSnapshotView(for snapshotCase: HashtagChipSnapshotCase) -> NSView {
        let view = BlockInputView(frame: NSRect(origin: .zero, size: snapshotCase.size))
        view.appearance = NSAppearance(named: snapshotCase.appearance)
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: "checklist",
                    kind: .checklistItem(isChecked: false),
                    text: "buy milk #groceries"
                ),
                BlockInputBlock(
                    id: "checklist2",
                    kind: .checklistItem(isChecked: true),
                    text: "done #work"
                )
            ]),
            allowsBlockReordering: false
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        return view
    }

    func makeHashtagChipMultipleSnapshotView(for snapshotCase: HashtagChipSnapshotCase) -> NSView {
        let view = BlockInputView(frame: NSRect(origin: .zero, size: snapshotCase.size))
        view.appearance = NSAppearance(named: snapshotCase.appearance)
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: "checklist",
                    kind: .checklistItem(isChecked: false),
                    text: "multiple #tags #here today"
                )
            ]),
            allowsBlockReordering: false
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        return view
    }

    func testHashtagChipChecklistSnapshots() {
        for snapshotCase in HashtagChipSnapshotCase.matrix {
            assertSnapshot(
                of: makeHashtagChipChecklistSnapshotView(for: snapshotCase),
                as: appKitSnapshotImage(),
                named: "hashtag-checklist-\(snapshotCase.name)"
            )
        }
    }

    func testHashtagChipMultipleSnapshots() {
        for snapshotCase in HashtagChipSnapshotCase.matrix {
            assertSnapshot(
                of: makeHashtagChipMultipleSnapshotView(for: snapshotCase),
                as: appKitSnapshotImage(),
                named: "hashtag-multiple-\(snapshotCase.name)"
            )
        }
    }
}

struct HashtagChipSnapshotCase {
    var name: String
    var appearance: NSAppearance.Name
    var size: CGSize

    static let matrix: [Self] = [
        Self(name: "light", appearance: .aqua, size: CGSize(width: 620, height: 120)),
        Self(name: "dark", appearance: .darkAqua, size: CGSize(width: 620, height: 120))
    ]
}
