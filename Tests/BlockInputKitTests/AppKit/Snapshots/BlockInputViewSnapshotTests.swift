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

    func testListMarkerAlignmentSnapshots() {
        for snapshotCase in ListMarkerSnapshotCase.matrix {
            assertSnapshot(
                of: ListMarkerAlignmentSnapshotView(snapshotCase: snapshotCase),
                as: .image(precision: 0.995, perceptualPrecision: 0.995),
                named: snapshotCase.name
            )
        }
    }

    func testLinkEditModalSnapshots() {
        for snapshotCase in LinkModalSnapshotCase.matrix {
            assertSnapshot(
                of: makeLinkModalSnapshotView(for: snapshotCase),
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

    private func makeLinkModalSnapshotView(for snapshotCase: LinkModalSnapshotCase) -> NSView {
        let view = BlockInputView(frame: NSRect(origin: .zero, size: snapshotCase.size))
        view.appearance = NSAppearance(named: snapshotCase.appearance)
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "paragraph", text: "Open [Documentation](https://example.com/docs)")
            ]),
            allowsBlockReordering: false,
            dropIndicatorColor: .systemBlue
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        guard let linkRange = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: view.document.blocks[0].text
        ).first(where: { $0.style == .link }) else {
            XCTFail("Expected a snapshot link range.")
            return view
        }
        let anchorWindowRect = view.visibleBlockItemForTesting(at: 0)?.anchorWindowRect(forUTF16Range: linkRange.contentRange) ?? .zero
        let context = BlockInputLinkContext(
            blockID: "paragraph",
            mode: .edit(linkRange),
            sourceRange: NSRange(location: 6, length: 0),
            sourceText: view.document.blocks[0].text,
            anchorWindowRect: anchorWindowRect
        )
        view.showLinkModal(context: context)
        view.linkModalView?.window?.makeFirstResponder(view.linkModalView)
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

private struct LinkModalSnapshotCase {
    var name: String
    var appearance: NSAppearance.Name
    var size: CGSize

    static let matrix: [Self] = [
        Self(name: "link-modal-light", appearance: .aqua, size: CGSize(width: 620, height: 280)),
        Self(name: "link-modal-dark", appearance: .darkAqua, size: CGSize(width: 620, height: 280))
    ]
}

@MainActor
private struct ListMarkerSnapshotCase {
    var name: String
    var appearance: NSAppearance.Name
    var size: CGSize
    var font: NSFont
    var itemHeight: CGFloat

    static let matrix: [Self] = [
        Self(
            name: "list-marker-alignment-light",
            appearance: .aqua,
            size: CGSize(width: 520, height: 96),
            font: .preferredFont(forTextStyle: .body),
            itemHeight: 40
        ),
        Self(
            name: "list-marker-alignment-dark",
            appearance: .darkAqua,
            size: CGSize(width: 520, height: 96),
            font: .preferredFont(forTextStyle: .body),
            itemHeight: 40
        ),
        Self(
            name: "list-marker-alignment-light-large",
            appearance: .aqua,
            size: CGSize(width: 760, height: 140),
            font: .systemFont(ofSize: 24),
            itemHeight: 58
        ),
        Self(
            name: "list-marker-alignment-dark-large",
            appearance: .darkAqua,
            size: CGSize(width: 760, height: 140),
            font: .systemFont(ofSize: 24),
            itemHeight: 58
        )
    ]
}

private final class ListMarkerAlignmentSnapshotView: NSView {
    private let delegate = BlockInputView()
    private let stackView = NSStackView()
    private let items: [BlockInputBlockItem]
    private let backgroundColor: NSColor
    private let snapshotCase: ListMarkerSnapshotCase

    init(snapshotCase: ListMarkerSnapshotCase) {
        self.snapshotCase = snapshotCase
        backgroundColor = snapshotCase.appearance == .darkAqua
            ? NSColor(calibratedWhite: 0.11, alpha: 1)
            : NSColor.white
        items = [
            Self.makeItem(
                block: BlockInputBlock(
                    id: "bullet",
                    kind: .bulletedListItem,
                    text: "Hover rows to reveal reorder handles",
                    lineIndentationLevels: [0]
                ),
                delegate: delegate
            ),
            Self.makeItem(
                block: BlockInputBlock(
                    id: "number",
                    kind: .numberedListItem(start: 1),
                    text: "Toggle reordering from the toolbar",
                    lineIndentationLevels: [0]
                ),
                delegate: delegate
            )
        ]
        super.init(frame: NSRect(origin: .zero, size: snapshotCase.size))
        appearance = NSAppearance(named: snapshotCase.appearance)
        configureStackView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    override func layout() {
        super.layout()
        items.forEach { item in
            Self.applyFont(snapshotCase.font, to: item)
            item.view.layoutSubtreeIfNeeded()
            item.updateMarkerLineYOffsets()
        }
    }

    private static func makeItem(
        block: BlockInputBlock,
        delegate: BlockInputBlockItemDelegate
    ) -> BlockInputBlockItem {
        BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: false,
            delegate: delegate
        )
    }

    private static func applyFont(_ font: NSFont, to item: BlockInputBlockItem) {
        guard let textView = item.testingTextView,
              let markerView = item.testingMarkerView else {
            return
        }
        textView.font = font
        textView.textStorage?.addAttribute(
            .font,
            value: font,
            range: NSRange(location: 0, length: (textView.string as NSString).length)
        )
        markerView.font = font
    }

    private func configureStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        addSubview(stackView)
        items.forEach { item in
            item.view.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(item.view)
            NSLayoutConstraint.activate([
                item.view.widthAnchor.constraint(equalTo: stackView.widthAnchor),
                item.view.heightAnchor.constraint(equalToConstant: snapshotCase.itemHeight)
            ])
        }
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private extension BlockInputDocument {
    // One document intentionally covers all built-in block renderers so the
    // appearance/size matrix stays small and stable.
    static let snapshotRepresentative = BlockInputDocument(blocks: [
        BlockInputBlock(id: "frontmatter", kind: .frontMatter, text: "title: Demo\npublished: true\nbad line"),
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
        BlockInputBlock(id: "tail", kind: .paragraph, text: "Try inline code: `@av`")
    ])
}
