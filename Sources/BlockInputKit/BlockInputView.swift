import AppKit

/// Primary AppKit editor surface for a structured block document.
@MainActor
public final class BlockInputView: NSView {
    /// Current document snapshot rendered by the view.
    public internal(set) var document = BlockInputDocument()
    /// Current block, text, or multi-block selection.
    public internal(set) var selection: BlockInputSelection?
    /// Whether drag reordering is enabled for block items.
    public internal(set) var allowsBlockReordering = true

    private let scrollView = NSScrollView()
    let collectionView = NSCollectionView()
    private let layout = NSCollectionViewFlowLayout()
    private var documentStore: (any BlockInputDocumentStore)?
    var undoController: BlockInputUndoController?
    var completionProvider: (any BlockInputCompletionProvider)?
    private var onDocumentChange: ((BlockInputDocument) -> Void)?
    private var onSelectionChange: ((BlockInputSelection?) -> Void)?
    private var pendingFocus: BlockInputCursor?
    private var lastFocusedBlockID: BlockInputBlockID?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCollectionView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCollectionView()
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    /// Applies configuration and reloads the editor from its document store.
    public func configure(_ configuration: BlockInputConfiguration) {
        documentStore = configuration.documentStore
        document = configuration.document
        allowsBlockReordering = configuration.allowsBlockReordering
        undoController = configuration.undoController
        completionProvider = configuration.completionProvider
        onDocumentChange = configuration.onDocumentChange
        onSelectionChange = configuration.onSelectionChange
        clearStaleFocusState()
        reloadDataKeepingFocus()
    }

    /// Focuses the editor like a single text field, restoring the best known cursor.
    public func focusEditor() {
        let cursor = pendingFocus ?? cursorForRestoredFocus()
        focus(blockID: cursor.blockID, utf16Offset: cursor.utf16Offset)
    }

    public override func becomeFirstResponder() -> Bool {
        focusEditor()
        return true
    }

    /// Focuses a specific block at a UTF-16 text offset.
    public func focus(blockID: BlockInputBlockID, utf16Offset: Int = 0) {
        guard let block = document.block(withID: blockID) else {
            return
        }
        let cursor = BlockInputCursor(
            blockID: blockID,
            utf16Offset: min(max(utf16Offset, 0), block.utf16Length)
        )
        pendingFocus = cursor
        applySelection(.cursor(cursor), notify: true)
        focusVisibleItem(for: cursor)
    }

    /// Inserts a paragraph below the active block.
    @discardableResult
    public func insertBlockBelowCurrentBlock() -> BlockInputSelection? {
        guard let blockID = activeBlockID else {
            return nil
        }
        return performStructuralEdit(named: "Insert Block") { document in
            document.handleReturn(in: blockID)
        }
    }

    /// Deletes the active block if it is empty, preserving the required focus semantics.
    @discardableResult
    public func deleteCurrentEmptyBlockForBackspaceOrDelete() -> BlockInputSelection? {
        guard let blockID = activeBlockID else {
            return nil
        }
        return performStructuralEdit(named: "Delete Block") { document in
            document.deleteEmptyBlockForBackspaceOrDelete(blockID: blockID)
        }
    }

    /// Moves a block when reordering is enabled.
    @discardableResult
    public func moveBlock(blockID: BlockInputBlockID, to targetIndex: Int) -> BlockInputSelection? {
        guard allowsBlockReordering else {
            return nil
        }
        return performStructuralEdit(named: "Move Block") { document in
            document.moveBlock(blockID: blockID, to: targetIndex)
        }
    }

    private func setupCollectionView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.textBackgroundColor]
        collectionView.register(
            BlockInputBlockItem.self,
            forItemWithIdentifier: BlockInputBlockItem.reuseIdentifier
        )
        collectionView.registerForDraggedTypes([.blockInputBlockID])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = collectionView

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private var activeBlockID: BlockInputBlockID? {
        switch selection {
        case let .cursor(cursor):
            cursor.blockID
        case let .text(range):
            range.blockID
        case let .blocks(ids):
            ids.first
        case nil:
            lastFocusedBlockID ?? document.blocks.first?.id
        }
    }

    private func cursorForRestoredFocus() -> BlockInputCursor {
        if let cursor = pendingFocus, document.index(of: cursor.blockID) != nil {
            return cursor
        }
        if let lastFocusedBlockID, let block = document.block(withID: lastFocusedBlockID) {
            return BlockInputCursor(blockID: lastFocusedBlockID, utf16Offset: block.utf16Length)
        }
        let firstBlock = document.blocks[0]
        return BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0)
    }

    private func focusVisibleItem(for cursor: BlockInputCursor) {
        guard let index = document.index(of: cursor.blockID) else {
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
        guard let item = collectionView.item(at: indexPath) as? BlockInputBlockItem else {
            pendingFocus = cursor
            return
        }
        item.focusText(atUTF16Offset: cursor.utf16Offset)
        pendingFocus = nil
    }

    private func reloadDataKeepingFocus() {
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        if let cursor = pendingFocus {
            DispatchQueue.main.async { [weak self] in
                self?.focusVisibleItem(for: cursor)
            }
        }
    }

    private func clearStaleFocusState() {
        if let selection, !document.containsValidSelection(selection) {
            applySelection(nil, notify: true)
        }
        if let cursor = pendingFocus, !document.containsValidCursor(cursor) {
            pendingFocus = nil
        }
        if let lastFocusedBlockID, document.index(of: lastFocusedBlockID) == nil {
            self.lastFocusedBlockID = nil
        }
    }

    func applySelection(_ selection: BlockInputSelection?, notify: Bool) {
        self.selection = selection
        if case let .cursor(cursor) = selection {
            lastFocusedBlockID = cursor.blockID
            pendingFocus = cursor
        } else if case let .text(range) = selection {
            lastFocusedBlockID = range.blockID
        }
        if notify {
            onSelectionChange?(selection)
        }
    }

    func publishDocumentChange() {
        documentStore?.replaceDocument(document)
        onDocumentChange?(document)
    }

    func performStructuralEdit(
        named actionName: String,
        edit: (inout BlockInputDocument) -> BlockInputSelection?
    ) -> BlockInputSelection? {
        let beforeDocument = document
        let beforeSelection = selection
        guard let afterSelection = edit(&document) else {
            return nil
        }
        guard beforeDocument != document else {
            applySelection(afterSelection, notify: beforeSelection != afterSelection)
            return nil
        }
        applySelection(afterSelection, notify: true)
        undoController?.registerStructuralEdit(
            actionName: actionName,
            beforeDocument: beforeDocument,
            afterDocument: document,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadDataKeepingFocus()
        publishDocumentChange()
        return afterSelection
    }
}

private extension BlockInputDocument {
    func containsValidSelection(_ selection: BlockInputSelection) -> Bool {
        switch selection {
        case let .cursor(cursor):
            return containsValidCursor(cursor)
        case let .text(range):
            return containsValidTextRange(range)
        case let .blocks(blockIDs):
            return !blockIDs.isEmpty
                && Set(blockIDs).count == blockIDs.count
                && blockIDs.allSatisfy { index(of: $0) != nil }
        }
    }

    func containsValidCursor(_ cursor: BlockInputCursor) -> Bool {
        guard let block = block(withID: cursor.blockID) else {
            return false
        }
        return cursor.utf16Offset >= 0 && cursor.utf16Offset <= block.utf16Length
    }

    func containsValidTextRange(_ textRange: BlockInputTextRange) -> Bool {
        guard let block = block(withID: textRange.blockID),
              textRange.range.location >= 0,
              textRange.range.length >= 0 else {
            return false
        }
        return textRange.range.location <= block.utf16Length
            && textRange.range.length <= block.utf16Length - textRange.range.location
    }
}
