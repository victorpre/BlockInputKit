import AppKit

extension BlockInputView {
    func copyActiveSelection() -> Bool {
        guard let copiedText = selectedPlainText(), !copiedText.isEmpty else {
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        return true
    }

    func cutActiveSelection() -> Bool {
        if case .text = selection {
            return performTextViewEditAction(#selector(NSText.cut(_:)))
        }
        guard selection?.wholeSelectedBlockIDs.isEmpty == false || isMixedSelection,
              copyActiveSelection() else {
            return false
        }
        return deleteSelectedBlocksForBackspaceOrDelete() != nil
    }

    func pasteIntoActiveSelection() -> Bool {
        switch selection {
        case .cursor, .text:
            return performTextViewEditAction(#selector(NSText.paste(_:)))
        case .blocks, .mixed, nil:
            return false
        }
    }

    private func performTextViewEditAction(_ action: Selector) -> Bool {
        switch selection {
        case let .cursor(cursor):
            guard let item = visibleItem(for: cursor.blockID) else {
                return false
            }
            item.focusText(atUTF16Offset: cursor.utf16Offset)
        case let .text(textRange):
            guard let item = visibleItem(for: textRange.blockID) else {
                return false
            }
            item.focusText(inUTF16Range: textRange.range)
        case .blocks, .mixed, nil:
            return false
        }
        guard let textView = window?.firstResponder as? BlockInputTextView else {
            return false
        }
        return NSApp.sendAction(action, to: textView, from: self)
    }

    private func selectedPlainText() -> String? {
        switch selection {
        case let .text(textRange):
            guard let block = block(withID: textRange.blockID) else {
                return nil
            }
            return block.markdownAwareCopiedText(in: textRange.range)
        case let .blocks(blockIDs):
            let copiedBlocks = blocksForMarkdownCopy(blockIDs: blockIDs)
            guard !copiedBlocks.isEmpty else {
                return nil
            }
            return BlockInputDocument(blocks: copiedBlocks).markdown
        case let .mixed(mixedSelection):
            let copiedBlocks = blocksForMixedMarkdownCopy(mixedSelection)
            guard !copiedBlocks.isEmpty else {
                return nil
            }
            return BlockInputDocument(blocks: copiedBlocks).markdown
        case .cursor, nil:
            return nil
        }
    }

    private var isMixedSelection: Bool {
        if case .mixed = selection {
            return true
        }
        return false
    }

    private func blocksForMarkdownCopy(blockIDs: [BlockInputBlockID]) -> [BlockInputBlock] {
        let indexedBlocks = blockIDs.compactMap { blockID -> (index: Int, block: BlockInputBlock)? in
            guard let index = index(of: blockID),
                  let block = block(at: index) else {
                return nil
            }
            return (index, block)
        }
        return indexedBlocks
            .sorted { $0.index < $1.index }
            .map(\.block)
    }

    private func blocksForMixedMarkdownCopy(_ selection: BlockInputMixedSelection) -> [BlockInputBlock] {
        let edgeBlockIDs = [
            selection.leadingTextRange?.blockID,
            selection.trailingTextRange?.blockID
        ].compactMap { $0 }
        let blockIDs = selection.blockIDs + edgeBlockIDs
        return blockIDs.compactMap { blockID -> (index: Int, block: BlockInputBlock)? in
            guard let index = index(of: blockID), var block = block(at: index) else {
                return nil
            }
            if let textRange = selection.leadingTextRange, textRange.blockID == blockID {
                block.applyPartialMarkdownCopyRange(textRange.range)
            }
            if let textRange = selection.trailingTextRange, textRange.blockID == blockID {
                block.applyPartialMarkdownCopyRange(textRange.range)
            }
            return (index, block)
        }
        .sorted { $0.index < $1.index }
        .map(\.block)
    }
}

extension BlockInputBlock {
    func markdownAwareCopiedText(in range: NSRange) -> String? {
        guard kind != .horizontalRule else {
            return nil
        }
        let clampedRange = text.clampedRange(range)
        guard clampedRange.length > 0 else {
            return nil
        }
        if kind == .quote,
           clampedRange.location == 0,
           NSMaxRange(clampedRange) == utf16Length {
            return BlockInputDocument(blocks: [self]).markdown
        }
        return (text as NSString).substring(with: clampedRange)
    }

    mutating func applyPartialMarkdownCopyRange(_ range: NSRange) {
        let originalTextLength = utf16Length
        let clampedRange = text.clampedRange(range)
        text = (text as NSString).substring(with: clampedRange)
        stripMarkdownChromeIfPartialCopyNeedsPlainText(clampedRange, originalTextLength: originalTextLength)
    }

    mutating func stripMarkdownChromeIfPartialCopyNeedsPlainText(_ range: NSRange, originalTextLength: Int) {
        let coversWholeBlock = range.location <= 0 && NSMaxRange(range) >= originalTextLength
        guard !coversWholeBlock,
              range.location > 0 || hasInvisibleMarkdownFence else {
            return
        }
        kind = .paragraph
        indentationLevel = 0
        lineIndentationLevels = []
    }

    var hasInvisibleMarkdownFence: Bool {
        if case .code = kind {
            return true
        }
        return false
    }
}

private extension String {
    func clampedRange(_ range: NSRange) -> NSRange {
        let text = self as NSString
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(text.length - location, 0))
        return NSRange(location: location, length: length)
    }
}
