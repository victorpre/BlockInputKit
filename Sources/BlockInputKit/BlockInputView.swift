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
    /// Color used for the drag insertion indicator line.
    public internal(set) var dropIndicatorColor = NSColor.controlAccentColor

    private let scrollView = NSScrollView()
    let collectionView = BlockInputCollectionView()
    let dropIndicatorView = NSView()
    private let layout = NSCollectionViewFlowLayout()
    var documentStore: (any BlockInputDocumentStore)?
    var undoController: BlockInputUndoController?
    var completionProvider: (any BlockInputCompletionProvider)?
    var onDocumentChange: ((BlockInputDocument) -> Void)?
    var onSelectionChange: ((BlockInputSelection?) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var publishedFocusState = false
    var pendingFocus: BlockInputCursor?
    var lastFocusedBlockID: BlockInputBlockID?
    var selectedHorizontalRuleIndex: Int?
    var preferredNavigationX: CGFloat?
    // Invalidates deferred selection restoration when a later reload should not restore focus.
    var focusRestoreGeneration = 0
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
        configure(configuration, restoresFocus: true)
    }

    func configure(_ configuration: BlockInputConfiguration, restoresFocus: Bool) {
        documentStore = configuration.documentStore
        document = configuration.document
        allowsBlockReordering = configuration.allowsBlockReordering
        dropIndicatorColor = configuration.dropIndicatorColor
        undoController = configuration.undoController
        completionProvider = configuration.completionProvider
        onDocumentChange = configuration.onDocumentChange
        onSelectionChange = configuration.onSelectionChange
        onFocusChange = configuration.onFocusChange
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
        if event.isBackspaceOrDelete,
           deleteSelectedHorizontalRuleForBackspaceOrDelete() != nil {
            return
        }
        super.keyDown(with: event)
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

    /// Inserts a paragraph below the active block.
    @discardableResult
    public func insertBlockBelowCurrentBlock() -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard let blockID = activeBlockID else {
            return nil
        }
        return performStructuralEdit(
            named: "Insert Block",
            storeSyncAction: { _, afterDocument, afterSelection in
                guard case let .cursor(cursor) = afterSelection,
                      let insertedIndex = afterDocument.index(of: cursor.blockID),
                      let insertedBlock = afterDocument.block(withID: cursor.blockID) else {
                    return .replaceDocument
                }
                return .insertBlocks([insertedBlock], insertionIndex: insertedIndex)
            },
            edit: { document in
                document.handleReturn(in: blockID)
            }
        )
    }

    /// Deletes the active block if it is empty, preserving the required focus semantics.
    @discardableResult
    public func deleteCurrentEmptyBlockForBackspaceOrDelete() -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard let blockID = activeBlockID else {
            return nil
        }
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
        refreshDocumentFromStore()
        guard let blockID = activeBlockID,
              let result = undoController?.undoTextEdit(in: &document, blockID: blockID) else {
            return nil
        }
        if let block = document.block(withID: blockID) {
            applyUndoResult(result, storeSyncAction: .replaceBlock(block))
        } else {
            applyUndoResult(result)
        }
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
        if let block = document.block(withID: blockID) {
            applyUndoResult(result, storeSyncAction: .replaceBlock(block))
        } else {
            applyUndoResult(result)
        }
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
