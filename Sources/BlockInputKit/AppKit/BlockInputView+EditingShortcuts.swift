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
        guard case .blocks = selection,
              copyActiveSelection() else {
            return false
        }
        return deleteSelectedBlocksForBackspaceOrDelete() != nil
    }

    func pasteIntoActiveSelection() -> Bool {
        switch selection {
        case .cursor, .text:
            return performTextViewEditAction(#selector(NSText.paste(_:)))
        case .blocks, nil:
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
        case .blocks, nil:
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
            guard let block = block(withID: textRange.blockID),
                  block.kind != .horizontalRule else {
                return nil
            }
            return (block.text as NSString).substring(with: block.text.clampedRange(textRange.range))
        case let .blocks(blockIDs):
            let copiedBlocks = blockIDs.compactMap { block(withID: $0) }
            guard !copiedBlocks.isEmpty else {
                return nil
            }
            return BlockInputDocument(blocks: copiedBlocks).markdown
        case .cursor, nil:
            return nil
        }
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
