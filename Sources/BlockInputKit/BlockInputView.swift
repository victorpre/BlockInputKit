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
    var documentStore: (any BlockInputDocumentStore)?
    var undoController: BlockInputUndoController?
    var completionProvider: (any BlockInputCompletionProvider)?
    var onDocumentChange: ((BlockInputDocument) -> Void)?
    var onSelectionChange: ((BlockInputSelection?) -> Void)?
    var pendingFocus: BlockInputCursor?
    var lastFocusedBlockID: BlockInputBlockID?
    // Avoid re-entering NSWindow first-responder assignment while AppKit is already promoting this view.
    var isBecomingFirstResponder = false

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
        refreshDocumentFromStore()
        if let selection, containsValidSelection(selection) {
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
        refreshDocumentFromStore()
        guard let block = block(withID: blockID) else {
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
        refreshDocumentFromStore()
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
        refreshDocumentFromStore()
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
        refreshDocumentFromStore()
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
        refreshDocumentFromStore()
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
        refreshDocumentFromStore()
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
        refreshDocumentFromStore()
        guard let result = undoController?.undoStructuralEdit(in: &document) else {
            return nil
        }
        applyUndoResult(result)
        return result
    }

    /// Redoes the most recent undone structural edit.
    @discardableResult
    public func redoStructuralEdit() -> BlockInputUndoResult? {
        refreshDocumentFromStore()
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

}
