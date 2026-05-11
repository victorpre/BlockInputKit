import AppKit

extension BlockInputView {
    /// Requests host-provided suggestions for the active block, or an explicit block.
    public func completionSuggestions(
        trigger: BlockInputCompletionTrigger,
        query: String,
        blockID: BlockInputBlockID? = nil
    ) async -> [BlockInputCompletionSuggestion] {
        guard let provider = completionProvider,
              let resolvedBlockID = blockID ?? activeBlockID,
              document.index(of: resolvedBlockID) != nil else {
            return []
        }
        let context = BlockInputCompletionContext(
            trigger: trigger,
            query: query,
            document: document,
            blockID: resolvedBlockID,
            selectedRange: completionSelectedRange(in: resolvedBlockID)
        )
        return await provider.suggestions(for: context)
    }

    /// Applies a host-provided completion suggestion to the active block.
    @discardableResult
    public func acceptCompletionSuggestion(
        _ suggestion: BlockInputCompletionSuggestion,
        in blockID: BlockInputBlockID? = nil,
        replacing replacementRange: NSRange? = nil
    ) -> BlockInputSelection? {
        guard let resolvedBlockID = blockID ?? activeBlockID,
              let block = document.block(withID: resolvedBlockID) else {
            return nil
        }
        let beforeText = block.text
        let range = clampedCompletionRange(
            replacementRange ?? completionReplacementRange(in: resolvedBlockID, block: block),
            in: block
        )
        let beforeSelection = completionSelectionBefore(in: resolvedBlockID, replacementRange: range)
        guard let afterSelection = document.replaceText(
            in: resolvedBlockID,
            range: range,
            replacement: suggestion.insertionText
        ),
            let updatedBlock = document.block(withID: resolvedBlockID),
            updatedBlock.text != beforeText else {
            return nil
        }
        applySelection(afterSelection, notify: true)
        undoController?.registerTextEdit(
            blockID: resolvedBlockID,
            beforeText: beforeText,
            afterText: updatedBlock.text,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadDataKeepingFocus()
        publishDocumentChange()
        return afterSelection
    }
}

private extension BlockInputView {
    func completionSelectedRange(in blockID: BlockInputBlockID) -> NSRange? {
        switch selection {
        case let .cursor(cursor) where cursor.blockID == blockID:
            return NSRange(location: cursor.utf16Offset, length: 0)
        case let .text(textRange) where textRange.blockID == blockID:
            return textRange.range
        default:
            return nil
        }
    }

    func completionReplacementRange(in blockID: BlockInputBlockID, block: BlockInputBlock) -> NSRange {
        switch selection {
        case let .cursor(cursor) where cursor.blockID == blockID:
            return NSRange(location: cursor.utf16Offset, length: 0)
        case let .text(textRange) where textRange.blockID == blockID:
            return textRange.range
        default:
            return NSRange(location: block.utf16Length, length: 0)
        }
    }

    func clampedCompletionRange(_ range: NSRange, in block: BlockInputBlock) -> NSRange {
        let utf16Length = block.utf16Length
        let location = min(max(range.location, 0), utf16Length)
        let length = min(max(range.length, 0), utf16Length - location)
        return NSRange(location: location, length: length)
    }

    func completionSelectionBefore(
        in blockID: BlockInputBlockID,
        replacementRange: NSRange
    ) -> BlockInputSelection {
        if replacementRange.length == 0 {
            return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: replacementRange.location))
        }
        return .text(BlockInputTextRange(blockID: blockID, range: replacementRange))
    }
}
