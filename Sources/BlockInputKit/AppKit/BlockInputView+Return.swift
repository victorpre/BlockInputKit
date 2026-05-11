import AppKit

extension BlockInputView {
    private struct ReturnSelection {
        var offset: Int
        var length: Int
    }

    /// Applies Return key semantics to the active block.
    @discardableResult
    public func insertBlockBelowCurrentBlock() -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard let blockID = activeBlockID else {
            return nil
        }
        let focusedBlock = block(withID: blockID)
        let returnSelection = currentReturnSelection(for: blockID)
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
}
