import AppKit

extension BlockInputView {
    struct ReturnSelection {
        var offset: Int
        var length: Int
    }

    private struct InlineExit {
        var afterBlock: BlockInputBlock
        var insertedBlocks: [BlockInputBlock]
        var insertionOffset: Int
    }

    /// Applies Return key semantics to the active block.
    @discardableResult
    public func insertBlockBelowCurrentBlock() -> BlockInputSelection? {
        guard let blockID = activeBlockID else {
            return nil
        }
        let returnSelection = currentReturnSelection(for: blockID)
        if let granularSelection = performGranularReturnIfPossible(
            blockID: blockID,
            returnSelection: returnSelection
        ) {
            return granularSelection
        }

        refreshDocumentFromStore()
        let focusedBlock = block(withID: blockID)
        let actionName = returnActionName(for: focusedBlock, selection: returnSelection)
        return performStructuralEdit(
            named: actionName,
            storeSyncAction: { beforeDocument, afterDocument, afterSelection in
                self.returnStoreSyncAction(
                    for: blockID,
                    beforeDocument: beforeDocument,
                    afterDocument: afterDocument,
                    afterSelection: afterSelection
                )
            },
            edit: { document in
                document.handleReturn(
                    in: blockID,
                    utf16Offset: returnSelection?.offset,
                    selectedUTF16Length: returnSelection?.length ?? 0
                )
            }
        )
    }

    private func performGranularReturnIfPossible(
        blockID: BlockInputBlockID,
        returnSelection: ReturnSelection?
    ) -> BlockInputSelection? {
        guard let index = activeStandaloneBlockIndex(for: blockID),
              let block = block(at: index),
              cachedBlockMatches(block, at: index) else {
            return nil
        }
        if let leadingReturnMove = leadingReturnMove(from: block, selection: returnSelection) {
            return performGranularLeadingReturnMove(
                actionName: "Insert Block",
                beforeBlock: block,
                leadingReturnMove: leadingReturnMove,
                replacementIndex: index
            )
        }
        if let replacement = block.codeFenceBlockForReturn(
            utf16Offset: returnSelection?.offset,
            selectedUTF16Length: returnSelection?.length ?? 0
        ) {
            return performGranularReturnBlockReplacement(
                actionName: "Format Block",
                beforeBlock: block,
                afterBlock: replacement,
                index: index
            )
        }
        if let replacement = replacementBlockForGranularReturn(from: block, at: index, selection: returnSelection) {
            return performGranularReturnBlockReplacement(
                actionName: returnActionName(for: block, selection: returnSelection),
                beforeBlock: block,
                afterBlock: replacement,
                index: index
            )
        }
        if let inlineExit = inlineExitForGranularReturn(from: block, selection: returnSelection) {
            return performGranularReturnInlineExit(
                actionName: returnActionName(for: block, selection: returnSelection),
                beforeBlock: block,
                inlineExit: inlineExit,
                replacementIndex: index
            )
        }
        guard let insertedBlock = insertedBlockForGranularReturn(from: block, selection: returnSelection) else {
            return nil
        }
        return performGranularReturnBlockInsertion(
            actionName: "Insert Block",
            insertedBlock: insertedBlock,
            insertionIndex: index + 1
        )
    }

    private func cachedBlockMatches(_ block: BlockInputBlock, at index: Int) -> Bool {
        guard isDocumentCacheSynchronized else {
            return documentStore != nil
        }
        return document.blocks.indices.contains(index) && document.blocks[index] == block
    }

    private func replacementBlockForGranularReturn(
        from block: BlockInputBlock,
        at index: Int,
        selection: ReturnSelection?
    ) -> BlockInputBlock? {
        if block.isEmpty,
           returnOutdentsListItem(block: block, selection: selection) {
            var replacement = block
            let lineIndentation = replacement.indentationLevel(forLine: 0)
            if replacement.lineIndentationLevels.isEmpty {
                replacement.indentationLevel = max(0, lineIndentation - 1)
            } else {
                replacement.setIndentationLevel(lineIndentation - 1, forLine: 0)
            }
            normalizeNumberedListStartIfNeeded(for: &replacement, at: index)
            return replacement
        }
        guard block.isEmpty,
              block.kind.exitsToParagraphOnEmptyReturn,
              !returnOutdentsListItem(block: block, selection: selection) else {
            return nil
        }
        return BlockInputBlock(id: block.id, kind: .paragraph)
    }

    private func inlineExitForGranularReturn(
        from block: BlockInputBlock,
        selection: ReturnSelection?
    ) -> InlineExit? {
        guard block.kind.acceptsInlineReturn,
              !block.isEmpty,
              (selection?.length ?? 0) == 0,
              let offset = selection?.offset,
              let removalRange = block.emptyInlineLineRemovalRangeForReturn(utf16Offset: offset) else {
            return nil
        }
        let textStorage = block.text as NSString
        let prefix = Self.removingOneTrailingLineEnding(textStorage.substring(to: removalRange.location))
        guard !prefix.isEmpty else {
            return nil
        }
        let suffix = textStorage.substring(from: NSMaxRange(removalRange))
        var afterBlock = block
        afterBlock.text = prefix
        // Empty inline exits are composite edits: trim the current block and
        // insert the plain paragraph that receives focus.
        var insertedBlocks = [BlockInputBlock()]
        if !suffix.isEmpty {
            var continuationBlock = block
            continuationBlock.id = .unique()
            continuationBlock.kind = inlineExitContinuationKind(for: block.kind)
            continuationBlock.text = suffix
            insertedBlocks.append(continuationBlock)
        }
        return InlineExit(afterBlock: afterBlock, insertedBlocks: insertedBlocks, insertionOffset: 1)
    }

    private func insertedBlockForGranularReturn(
        from block: BlockInputBlock,
        selection: ReturnSelection?
    ) -> BlockInputBlock? {
        if block.kind.insertsSiblingListItemOnReturn {
            guard block.lineIndentationLevels.isEmpty,
                  block.text.rangeOfCharacter(from: .newlines) == nil,
                  (selection?.length ?? 0) == 0,
                  (selection?.offset ?? block.utf16Length) == block.utf16Length else {
                return nil
            }
            return BlockInputBlock(
                kind: nextListKind(after: block.kind),
                indentationLevel: block.indentationLevel
            )
        }
        guard !block.kind.acceptsInlineReturn,
              !(block.isEmpty && block.kind.exitsToParagraphOnEmptyReturn) else {
            return nil
        }
        return BlockInputBlock()
    }

    private func performGranularReturnBlockReplacement(
        actionName: String,
        beforeBlock: BlockInputBlock,
        afterBlock: BlockInputBlock,
        index: Int
    ) -> BlockInputSelection {
        let beforeSelection = selection
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: afterBlock.id,
            utf16Offset: 0
        ))
        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: index)
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: actionName,
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadVisibleBlock(at: index)
        publishDocumentChange()
        return afterSelection
    }

    private func performGranularReturnBlockInsertion(
        actionName: String,
        insertedBlock: BlockInputBlock,
        insertionIndex: Int
    ) -> BlockInputSelection? {
        let beforeSelection = selection
        let insertedBlocks = [insertedBlock]
        let resolvedInsertionIndex = frontMatterPreservingInsertionIndex(insertionIndex)
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: insertedBlocks.count) {
            guard document.insertBlocks(insertedBlocks, at: resolvedInsertionIndex) != nil else {
                return nil
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: insertedBlock.id,
            utf16Offset: 0
        ))
        syncDocumentStore(.insertBlocks(insertedBlocks, insertionIndex: resolvedInsertionIndex))
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockInsertionStructuralEdit(
            actionName: actionName,
            insertedBlocks: insertedBlocks,
            insertionIndex: resolvedInsertionIndex,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        insertVisibleBlock(at: resolvedInsertionIndex)
        publishDocumentChange()
        return afterSelection
    }

    private func performGranularReturnInlineExit(
        actionName: String,
        beforeBlock: BlockInputBlock,
        inlineExit: InlineExit,
        replacementIndex: Int
    ) -> BlockInputSelection? {
        let afterBlock = inlineExit.afterBlock
        let insertedBlocks = inlineExit.insertedBlocks
        let insertionIndex = replacementIndex + inlineExit.insertionOffset
        guard let insertedBlock = insertedBlocks.first else {
            return nil
        }
        let resolvedInsertionIndex = frontMatterPreservingInsertionIndex(
            insertionIndex,
            afterReplacing: afterBlock,
            at: replacementIndex
        )
        let beforeSelection = selection
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: insertedBlocks.count) {
            guard replaceCachedBlock(afterBlock, at: replacementIndex),
                  document.insertBlocks(insertedBlocks, at: resolvedInsertionIndex) != nil else {
                return nil
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: insertedBlock.id,
            utf16Offset: 0
        ))
        syncDocumentStore(.replaceBlock(afterBlock))
        syncDocumentStore(.insertBlocks(insertedBlocks, insertionIndex: resolvedInsertionIndex))
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementInsertionStructuralEdit(BlockInputReplaceInsertEdit(
            actionName: actionName,
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            insertedBlocks: insertedBlocks,
            insertionIndex: resolvedInsertionIndex,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        ))
        if shouldDeferGranularCountLayout {
            reloadVisibleBlock(at: replacementIndex)
            if insertedBlocks.count == 1 {
                insertVisibleBlock(at: resolvedInsertionIndex)
            } else {
                reloadDataKeepingFocus()
            }
        } else {
            // The document count has already changed; a reload-item plus insert-item
            // sequence is invalid for AppKit here, so rebuild the visible layout once.
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return afterSelection
    }

    func reloadVisibleBlock(at index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        if shouldDeferGranularCountLayout,
           let block = block(at: index),
           reconfigureVisibleReplacement(block, at: index) {
            // Same-row replacements, such as empty quote -> paragraph, should
            // stay mounted in large documents instead of reloading the row.
            return
        }
        collectionView.reloadItems(at: [indexPath])
        collectionView.layoutSubtreeIfNeeded()
        restoreVisibleSelection()
    }

    private static func removingOneTrailingLineEnding(_ text: String) -> String {
        if text.hasSuffix("\r\n") {
            return String(text.dropLast(2))
        }
        guard text.last == "\n" || text.last == "\r" else {
            return text
        }
        return String(text.dropLast())
    }

    func insertVisibleBlock(at index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        if shouldDeferGranularCountLayout {
            reconfigureMountedBlocksAfterGranularCountChange(startingAt: index)
            return
        }
        collectionView.insertItems(at: [indexPath])
        collectionView.layoutSubtreeIfNeeded()
        restoreMountedSelection()
    }

    private func currentReturnSelection(for blockID: BlockInputBlockID) -> ReturnSelection? {
        switch selection {
        case let .cursor(cursor) where cursor.blockID == blockID:
            return ReturnSelection(offset: cursor.utf16Offset, length: 0)
        case let .text(range) where range.blockID == blockID:
            return ReturnSelection(offset: range.range.location, length: range.range.length)
        default:
            return nil
        }
    }

    private func returnActionName(for block: BlockInputBlock?, selection: ReturnSelection?) -> String {
        guard let block else {
            return "Insert Block"
        }
        if returnOutdentsListItem(block: block, selection: selection) {
            return "Outdent Block"
        }
        if block.isEmpty && block.kind.exitsToParagraphOnEmptyReturn {
            return "Unformat Block"
        }
        if block.codeFenceBlockForReturn(
            utf16Offset: selection?.offset,
            selectedUTF16Length: selection?.length ?? 0
        ) != nil {
            return "Format Block"
        }
        guard !block.isEmpty && block.kind.acceptsInlineReturn else {
            return "Insert Block"
        }
        let requiresStructuralReturn = block.requiresStructuralReturnHandling(
            utf16Offset: selection?.offset ?? block.utf16Length,
            selectedUTF16Length: selection?.length ?? 0
        )
        return requiresStructuralReturn ? "Insert Block" : "Insert Line"
    }

    private func returnOutdentsListItem(block: BlockInputBlock, selection: ReturnSelection?) -> Bool {
        guard block.kind.supportsIndentation,
              (selection?.length ?? 0) == 0 else {
            return false
        }
        if block.isEmpty {
            return block.indentationLevel(forLine: 0) > 0
        }
        guard block.kind.acceptsInlineReturn else {
            return false
        }
        let offset = selection?.offset ?? block.utf16Length
        guard block.emptyInlineLineRemovalRangeForReturn(utf16Offset: offset) != nil else {
            return false
        }
        let lineIndex = block.lineIndex(containingUTF16Offset: offset)
        return block.indentationLevel(forLine: lineIndex) > 0
    }

    private func returnStoreSyncAction(
        for blockID: BlockInputBlockID,
        beforeDocument: BlockInputDocument,
        afterDocument: BlockInputDocument,
        afterSelection: BlockInputSelection
    ) -> StoreSyncAction {
        guard case let .cursor(cursor) = afterSelection,
              let focusedBlock = afterDocument.block(withID: cursor.blockID) else {
            return .replaceDocument
        }
        if beforeDocument.blocks.count == afterDocument.blocks.count {
            return .replaceBlock(focusedBlock)
        }
        if let beforeSourceBlock = beforeDocument.block(withID: blockID),
           let afterSourceBlock = afterDocument.block(withID: blockID),
           beforeSourceBlock != afterSourceBlock {
            return .replaceDocument
        }
        guard let insertedIndex = afterDocument.index(of: cursor.blockID) else {
            return .replaceDocument
        }
        return .insertBlocks([focusedBlock], insertionIndex: insertedIndex)
    }

    private func normalizeNumberedListStartIfNeeded(
        for block: inout BlockInputBlock,
        at index: Int
    ) {
        guard case .numberedListItem = block.kind else {
            return
        }
        let indentationLevel = block.indentationLevel(forLine: 0)
        if let previousStart = previousNumberedListStart(before: index, indentationLevel: indentationLevel) {
            block.kind = .numberedListItem(start: previousStart + 1)
        } else if indentationLevel > 0 {
            block.kind = .numberedListItem(start: 1)
        }
    }

    private func previousNumberedListStart(before index: Int, indentationLevel: Int) -> Int? {
        guard index > 0 else {
            return nil
        }
        var visitedCount = 0
        for previousIndex in stride(from: index - 1, through: 0, by: -1) {
            guard visitedCount < 128 else {
                return nil
            }
            visitedCount += 1
            guard let previousBlock = block(at: previousIndex),
                  previousBlock.kind.isReturnListItem else {
                return nil
            }
            let previousIndentationLevel = previousBlock.indentationLevel(forLine: 0)
            if case let .numberedListItem(start) = previousBlock.kind,
               previousIndentationLevel == indentationLevel {
                return start
            }
            if previousIndentationLevel < indentationLevel {
                return nil
            }
        }
        return nil
    }

    private func nextListKind(after kind: BlockInputBlockKind) -> BlockInputBlockKind {
        switch kind {
        case .bulletedListItem:
            return .bulletedListItem
        case let .numberedListItem(start):
            return .numberedListItem(start: start + 1)
        case .checklistItem:
            return .checklistItem(isChecked: false)
        case .paragraph, .heading, .code, .horizontalRule, .frontMatter, .quote, .table, .image, .rawMarkdown:
            return kind
        }
    }

    private func inlineExitContinuationKind(for kind: BlockInputBlockKind) -> BlockInputBlockKind {
        // Frontmatter is only meaningful at index 0, so any trailing body text
        // split after an inserted paragraph remains raw Markdown.
        kind == .frontMatter ? .rawMarkdown : kind
    }
}

private extension BlockInputBlockKind {
    var isReturnListItem: Bool {
        switch self {
        case .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule, .frontMatter, .quote, .table, .image, .rawMarkdown:
            return false
        }
    }
}
