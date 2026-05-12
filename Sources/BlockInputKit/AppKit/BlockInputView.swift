import AppKit

/// Primary AppKit editor surface for a structured block document.
@MainActor
public final class BlockInputView: NSView {
    /// Current document snapshot cached by the view.
    ///
    /// Store-backed large-document edits may leave this snapshot stale until the
    /// next full refresh; use `BlockInputDocumentStore` callbacks as the source
    /// of truth for large documents.
    public internal(set) var document = BlockInputDocument()
    /// Current block, text, or multi-block selection.
    public internal(set) var selection: BlockInputSelection?
    /// Whether drag reordering is enabled for block items.
    public internal(set) var allowsBlockReordering = true
    /// Color used for the drag insertion indicator line.
    public internal(set) var dropIndicatorColor = NSColor.controlAccentColor

    private let scrollView = NSScrollView()
    let collectionView = BlockInputCollectionView()
    let dropIndicatorView = NSView()
    private let layout = BlockInputCollectionViewFlowLayout()
    var documentStore: (any BlockInputDocumentStore)?
    var undoController: BlockInputUndoController?
    var completionProvider: (any BlockInputCompletionProvider)?
    var onDocumentMutation: ((BlockInputDocumentChange) -> Void)?
    var onDocumentChange: ((BlockInputDocument) -> Void)?
    var documentChangeSnapshotDelay: TimeInterval = 0.25
    var onSelectionChange: ((BlockInputSelection?) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    // Large store-backed granular inserts skip updating this duplicate snapshot
    // so repeated Return in 100k-block documents stays on the indexed store path.
    var isDocumentCacheSynchronized = true
    var publishedFocusState = false
    var pendingFocus: BlockInputCursor?
    var lastFocusedBlockID: BlockInputBlockID?
    var selectedHorizontalRuleIndex: Int?
    var preferredNavigationX: CGFloat?
    let itemHeightCache = BlockInputItemHeightCache()
    // Invalidates deferred selection restoration when a later reload should not restore focus.
    var focusRestoreGeneration = 0
    // Avoid re-entering NSWindow first-responder assignment while AppKit is already promoting this view.
    var isBecomingFirstResponder = false
    var documentSnapshotGeneration = 0
    var pendingDocumentSnapshotWorkItem: DispatchWorkItem?

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
        configure(configuration, restoresFocus: true)
    }

    func configure(_ configuration: BlockInputConfiguration, restoresFocus: Bool) {
        documentStore = configuration.documentStore
        document = configuration.document.detachedStorage()
        isDocumentCacheSynchronized = true
        allowsBlockReordering = configuration.allowsBlockReordering
        dropIndicatorColor = configuration.dropIndicatorColor
        undoController = configuration.undoController
        completionProvider = configuration.completionProvider
        onDocumentMutation = configuration.onDocumentMutation
        onDocumentChange = configuration.onDocumentChange
        documentChangeSnapshotDelay = configuration.documentChangeSnapshotDelay
        onSelectionChange = configuration.onSelectionChange
        onFocusChange = configuration.onFocusChange
        cancelPendingDocumentSnapshot()
        updateDropIndicatorColor()
        hideDropIndicator()
        clearStaleFocusState()
        if restoresFocus {
            reloadDataKeepingFocus()
        } else {
            reloadDataWithoutRestoringFocus()
        }
    }

    /// Focuses the editor like a single text field, preserving valid current selections.
    public func focusEditor() {
        refreshDocumentFromStore()
        if let selection, containsValidSelection(selection) {
            restoreVisibleSelection()
            if isEditorFirstResponder {
                publishFocusChange(true)
            }
            return
        }
        let cursor = pendingFocus ?? cursorForRestoredFocus()
        focus(blockID: cursor.blockID, utf16Offset: cursor.utf16Offset)
    }

    public override func becomeFirstResponder() -> Bool {
        isBecomingFirstResponder = true
        defer { isBecomingFirstResponder = false }
        focusEditor()
        publishFocusChange(true)
        return true
    }

    public override func resignFirstResponder() -> Bool {
        if !isBecomingFirstResponder {
            publishFocusLossIfNeeded()
        }
        return true
    }

    public override func keyDown(with event: NSEvent) {
        if let direction = event.verticalMovementDirection,
           moveSelectedBlockVertically(direction) {
            return
        }
        if event.isBackspaceOrDelete {
            if selectedBlockCount == 1,
               deleteSelectedHorizontalRuleForBackspaceOrDelete() != nil {
                return
            }
            if deleteSelectedBlocksForBackspaceOrDelete() != nil {
                return
            }
        }
        super.keyDown(with: event)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.blockInputIsSelectAllShortcut,
           selectAllFromActiveSelection() {
            return true
        }
        if let undoShortcut = event.blockInputUndoShortcut,
           performUndoShortcut(undoShortcut) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func selectAll(_ sender: Any?) {
        if selectAllFromActiveSelection() {
            return
        }
        super.selectAll(sender)
    }

    @objc(undo:)
    func blockInputUndo(_ sender: Any?) {
        _ = performUndoShortcut(.undo)
    }

    @objc(redo:)
    func blockInputRedo(_ sender: Any?) {
        _ = performUndoShortcut(.redo)
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
        if isEditorFirstResponder {
            publishFocusChange(true)
        }
    }

    /// Deletes the active block if it is empty, preserving the required focus semantics.
    @discardableResult
    public func deleteCurrentEmptyBlockForBackspaceOrDelete() -> BlockInputSelection? {
        guard let blockID = activeBlockID else {
            return nil
        }
        if let selection = deleteCurrentEmptyBlockGranularly(blockID: blockID) {
            return selection
        }
        refreshDocumentFromStore()
        return performStructuralEdit(
            named: "Delete Block",
            storeSyncAction: { beforeDocument, afterDocument, _ in
                if beforeDocument.blocks.count == 1,
                   let replacementBlock = afterDocument.block(withID: blockID) {
                    return .replaceBlock(replacementBlock)
                }
                return .deleteBlocks([blockID])
            },
            edit: { document in
                document.deleteEmptyBlockForBackspaceOrDelete(blockID: blockID)
            }
        )
    }

    private func deleteCurrentEmptyBlockGranularly(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard blockCount > 1,
              let deletionIndex = index(of: blockID),
              let deletedBlock = block(at: deletionIndex),
              deletedBlock.isEmpty else {
            return nil
        }
        let beforeSelection = selection
        let afterSelection: BlockInputSelection?
        if deletionIndex > 0, let previousBlock = block(at: deletionIndex - 1) {
            afterSelection = .cursor(BlockInputCursor(
                blockID: previousBlock.id,
                utf16Offset: previousBlock.utf16Length
            ))
        } else if let nextBlock = block(at: deletionIndex + 1) {
            afterSelection = .cursor(BlockInputCursor(blockID: nextBlock.id, utf16Offset: 0))
        } else {
            afterSelection = nil
        }

        if canSynchronizeCacheForGranularDeletion(deletedBlockCount: 1) {
            guard document.blocks.indices.contains(deletionIndex),
                  document.blocks[deletionIndex].id == blockID else {
                return nil
            }
            document.blocks.remove(at: deletionIndex)
        } else {
            markDocumentCacheUnsynchronized()
        }
        syncDocumentStore(.deleteBlocks([blockID]))
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockDeletionStructuralEdit(
            actionName: "Delete Block",
            deletedBlocks: [deletedBlock],
            deletionIndex: deletionIndex,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        deleteVisibleBlock(at: deletionIndex, deletedBlockIDs: [blockID])
        publishDocumentChange()
        return afterSelection
    }

    /// Deletes a selected horizontal rule block after the rule itself has focus-like selection.
    @discardableResult
    public func deleteSelectedHorizontalRuleForBackspaceOrDelete() -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard case let .blocks(blockIDs) = selection,
              blockIDs.count == 1,
              let blockID = blockIDs.first,
              block(withID: blockID)?.kind == .horizontalRule else {
            return nil
        }
        let deletionIndex = selectedHorizontalRuleIndex.flatMap { index -> Int? in
            guard block(at: index)?.id == blockID,
                  block(at: index)?.kind == .horizontalRule else {
                return nil
            }
            return index
        }
        return performStructuralEdit(
            named: "Delete Block",
            storeSyncAction: { beforeDocument, afterDocument, _ in
                if beforeDocument.blocks.count == 1,
                   let replacementBlock = afterDocument.block(withID: blockID) {
                    return .replaceBlock(replacementBlock)
                }
                return .replaceDocument
            },
            edit: { document in
                if let deletionIndex {
                    return document.deleteBlock(at: deletionIndex)
                }
                return document.deleteBlock(blockID: blockID)
            }
        )
    }

    /// Deletes the selected whole blocks after Cmd+A escalates to document-level selection.
    @discardableResult
    public func deleteSelectedBlocksForBackspaceOrDelete() -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard case let .blocks(blockIDs) = selection,
              !blockIDs.isEmpty else {
            return nil
        }
        return performStructuralEdit(
            named: blockIDs.count == 1 ? "Delete Block" : "Delete Blocks",
            storeSyncAction: { beforeDocument, afterDocument, _ in
                if beforeDocument.blocks.count == 1,
                   let replacementBlock = afterDocument.blocks.first {
                    return .replaceBlock(replacementBlock)
                }
                if beforeDocument.blocks.count == blockIDs.count,
                   afterDocument.blocks.count == 1 {
                    return .replaceDocument
                }
                return .deleteBlocks(blockIDs)
            },
            edit: { document in
                document.deleteBlocks(blockIDs: blockIDs)
            }
        )
    }

    /// Moves a block when reordering is enabled.
    @discardableResult
    public func moveBlock(blockID: BlockInputBlockID, to targetIndex: Int) -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard allowsBlockReordering else {
            return nil
        }
        return performStructuralEdit(
            named: "Move Block",
            storeSyncAction: { _, afterDocument, _ in
                guard let finalIndex = afterDocument.index(of: blockID) else {
                    return .replaceDocument
                }
                return .moveBlock(blockID, targetIndex: finalIndex)
            },
            edit: { document in
                document.moveBlock(blockID: blockID, to: targetIndex)
            }
        )
    }

    /// Undoes the most recent text edit in the active block.
    @discardableResult
    public func undoTextEditInActiveBlock() -> BlockInputUndoResult? {
        guard let blockID = activeBlockID else {
            return nil
        }
        return undoTextEdit(in: blockID)
    }

    /// Redoes the most recent undone text edit in the active block.
    @discardableResult
    public func redoTextEditInActiveBlock() -> BlockInputUndoResult? {
        guard let blockID = activeBlockID else {
            return nil
        }
        return redoTextEdit(in: blockID)
    }

    /// Undoes the most recent structural edit.
    @discardableResult
    public func undoStructuralEdit() -> BlockInputUndoResult? {
        if let result = undoController?.nextGranularStructuralUndoResult(),
           applyGranularUndoResult(result) {
            undoController?.commitGranularStructuralUndo()
            return result
        }
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
        if let result = undoController?.nextGranularStructuralRedoResult(),
           applyGranularUndoResult(result) {
            undoController?.commitGranularStructuralRedo()
            return result
        }
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

        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.blockInputView = self
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.textBackgroundColor]
        collectionView.register(
            BlockInputBlockItem.self,
            forItemWithIdentifier: BlockInputBlockItem.reuseIdentifier
        )
        collectionView.registerForDraggedTypes([.blockInputBlockID, .fileURL])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)

        dropIndicatorView.wantsLayer = true
        dropIndicatorView.layer?.cornerRadius = 1
        dropIndicatorView.layer?.zPosition = 10
        updateDropIndicatorColor()
        dropIndicatorView.isHidden = true
        dropIndicatorView.setAccessibilityElement(false)
        collectionView.addSubview(dropIndicatorView, positioned: .above, relativeTo: nil)

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

private extension NSEvent {
    var verticalMovementDirection: BlockInputVerticalMovementDirection? {
        if keyCode == 126 || charactersIgnoringModifiers == "\u{F700}" {
            return .upward
        }
        if keyCode == 125 || charactersIgnoringModifiers == "\u{F701}" {
            return .downward
        }
        return nil
    }

    var isBackspaceOrDelete: Bool {
        keyCode == 51
            || keyCode == 117
            || charactersIgnoringModifiers == "\u{7F}"
            || charactersIgnoringModifiers == "\u{F728}"
    }
}
