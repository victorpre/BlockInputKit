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
    // Avoid re-entering NSWindow first-responder assignment while AppKit is already promoting this view.
    private var isBecomingFirstResponder = false

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

    /// Focuses the editor like a single text field, preserving valid current selections.
    public func focusEditor() {
        if let selection, document.containsValidSelection(selection) {
            restoreVisibleSelection()
            return
        }
        let cursor = pendingFocus ?? cursorForRestoredFocus()
        focus(blockID: cursor.blockID, utf16Offset: cursor.utf16Offset)
    }

    public override func becomeFirstResponder() -> Bool {
        isBecomingFirstResponder = true
        defer { isBecomingFirstResponder = false }
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

    /// Undoes the most recent text edit in the active block.
    @discardableResult
    public func undoTextEditInActiveBlock() -> BlockInputUndoResult? {
        guard let blockID = activeBlockID,
              let result = undoController?.undoTextEdit(in: &document, blockID: blockID) else {
            return nil
        }
        applyUndoResult(result)
        return result
    }

    /// Redoes the most recent undone text edit in the active block.
    @discardableResult
    public func redoTextEditInActiveBlock() -> BlockInputUndoResult? {
        guard let blockID = activeBlockID,
              let result = undoController?.redoTextEdit(in: &document, blockID: blockID) else {
            return nil
        }
        applyUndoResult(result)
        return result
    }

    /// Undoes the most recent structural edit.
    @discardableResult
    public func undoStructuralEdit() -> BlockInputUndoResult? {
        guard let result = undoController?.undoStructuralEdit(in: &document) else {
            return nil
        }
        applyUndoResult(result)
        return result
    }

    /// Redoes the most recent undone structural edit.
    @discardableResult
    public func redoStructuralEdit() -> BlockInputUndoResult? {
        guard let result = undoController?.redoStructuralEdit(in: &document) else {
            return nil
        }
        applyUndoResult(result)
        return result
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

    private func visibleItem(for blockID: BlockInputBlockID) -> BlockInputBlockItem? {
        guard let index = document.index(of: blockID) else {
            return nil
        }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
        return collectionView.item(at: indexPath) as? BlockInputBlockItem
    }

    private func focusVisibleItem(for cursor: BlockInputCursor) {
        guard let item = visibleItem(for: cursor.blockID) else {
            pendingFocus = cursor
            return
        }
        item.focusText(atUTF16Offset: cursor.utf16Offset)
        pendingFocus = nil
    }

    private func restoreVisibleTextSelection(_ textRange: BlockInputTextRange) {
        guard let item = visibleItem(for: textRange.blockID) else {
            return
        }
        item.focusText(inUTF16Range: textRange.range)
    }

    private func restoreVisibleBlockSelection(_ blockIDs: [BlockInputBlockID]) {
        if let firstBlockID = blockIDs.first {
            _ = visibleItem(for: firstBlockID)
        }
        if !isBecomingFirstResponder, window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
    }

    private func restoreVisibleSelection() {
        switch selection {
        case let .cursor(cursor):
            focusVisibleItem(for: cursor)
        case let .text(textRange):
            restoreVisibleTextSelection(textRange)
        case let .blocks(blockIDs):
            restoreVisibleBlockSelection(blockIDs)
        case nil:
            break
        }
    }

    private func reloadDataKeepingFocus() {
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        if selection != nil {
            // AppKit may recreate items either immediately or on the next pass;
            // restoring in both places keeps cursor/text selection stable.
            restoreVisibleSelection()
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.layoutSubtreeIfNeeded()
                self?.restoreVisibleSelection()
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
        switch selection {
        case let .cursor(cursor):
            lastFocusedBlockID = cursor.blockID
            pendingFocus = cursor
        case let .text(range):
            lastFocusedBlockID = range.blockID
            pendingFocus = nil
        case let .blocks(blockIDs):
            lastFocusedBlockID = blockIDs.first
            pendingFocus = nil
        case nil:
            pendingFocus = nil
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

    private func applyUndoResult(_ result: BlockInputUndoResult) {
        let restoredSelection = result.selection.flatMap { selection -> BlockInputSelection? in
            document.containsValidSelection(selection) ? selection : nil
        }
        applySelection(restoredSelection, notify: true)
        reloadDataKeepingFocus()
        publishDocumentChange()
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
