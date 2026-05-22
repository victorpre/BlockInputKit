import AppKit

extension BlockInputView {
    func deleteLinkAtBoundary(
        item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        direction: BlockInputLinkBoundaryDeletionDirection
    ) -> Bool {
        guard let index = index(of: blockID),
              let block = block(at: index),
              block.id == blockID,
              Self.blockKindSupportsLinkBoundaryEditing(block.kind),
              let deletionRange = linkRangeAdjacentToBoundary(
                item.currentSelectedRange,
                direction: direction,
                in: block.text
              ) else {
            return false
        }
        let beforeText = block.text
        let afterText = NSMutableString(string: beforeText)
        afterText.deleteCharacters(in: deletionRange.fullRange)
        var afterBlock = block
        afterBlock.text = afterText as String
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: deletionRange.fullRange.location
        ))
        undoController?.registerTextEdit(
            blockID: blockID,
            beforeText: beforeText,
            afterText: afterBlock.text,
            beforeLineIndentationLevels: block.lineIndentationLevels,
            afterLineIndentationLevels: afterBlock.lineIndentationLevels,
            selectionBefore: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: item.currentSelectedRange.location)),
            selectionAfter: afterSelection
        )
        _ = applyGranularBlockReplacement(afterBlock, at: index, selection: afterSelection)
        return true
    }

    func resolvedInlineChipBoundaryTextChange(
        item: BlockInputBlockItem,
        beforeBlock: BlockInputBlock,
        proposedText: String,
        selectionBefore: BlockInputSelection?
    ) -> (text: String, proposedOffset: Int) {
        let selectedRange = item.currentSelectedRange
        guard let correction = inlineChipBoundaryInsertionCorrection(
            beforeBlock: beforeBlock,
            proposedText: proposedText,
            selectionBefore: selectionBefore
        ) else {
            return (proposedText, selectedRange.location + selectedRange.length)
        }
        let range = NSRange(location: correction.cursorOffset, length: 0)
        item.replaceCurrentTextFromEditorCorrection(correction.text, selectedRange: range)
        return (correction.text, correction.cursorOffset)
    }

    func inlineChipBoundaryAdjustedRange(_ range: NSRange, in block: BlockInputBlock) -> NSRange {
        guard range.length == 0,
              Self.blockKindSupportsLinkBoundaryEditing(block.kind),
              let linkRange = inlineChipRangeEndingAtContentBoundary(range.location, in: block.text) else {
            return range
        }
        return NSRange(location: NSMaxRange(linkRange.fullRange), length: 0)
    }

    private func inlineChipBoundaryInsertionCorrection(
        beforeBlock: BlockInputBlock,
        proposedText: String,
        selectionBefore: BlockInputSelection?
    ) -> InlineChipBoundaryInsertionCorrection? {
        guard Self.blockKindSupportsLinkBoundaryEditing(beforeBlock.kind),
              case let .cursor(cursor) = selectionBefore,
              cursor.blockID == beforeBlock.id else {
            return nil
        }
        let beforeText = beforeBlock.text as NSString
        let proposedText = proposedText as NSString
        let cursorOffset = cursor.utf16Offset
        guard cursorOffset >= 0,
              cursorOffset <= beforeText.length,
              proposedText.length > beforeText.length else {
            return nil
        }
        let insertionLength = proposedText.length - beforeText.length
        guard proposedText.substring(to: cursorOffset) == beforeText.substring(to: cursorOffset),
              proposedText.substring(from: cursorOffset + insertionLength) == beforeText.substring(from: cursorOffset) else {
            return nil
        }
        let insertedText = proposedText.substring(with: NSRange(location: cursorOffset, length: insertionLength))
        guard !insertedText.isEmpty,
              let linkRange = inlineChipRangeEndingAtContentBoundary(cursorOffset, in: beforeBlock.text) else {
            return nil
        }
        let insertionOffset = NSMaxRange(linkRange.fullRange)
        let correctedText = NSMutableString(string: beforeBlock.text)
        correctedText.insert(insertedText, at: insertionOffset)
        return InlineChipBoundaryInsertionCorrection(
            text: correctedText as String,
            cursorOffset: insertionOffset + insertionLength
        )
    }

    private static func blockKindSupportsLinkBoundaryEditing(_ kind: BlockInputBlockKind) -> Bool {
        BlockInputBlockItem.supportsInlineMarkdownStyling(kind)
    }

    private func inlineChipRangeEndingAtContentBoundary(
        _ offset: Int,
        in text: String
    ) -> BlockInputInlineMarkdownRange? {
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        return BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges, fileBaseURL: fileBaseURL)
            .first { range in
                range.inlineChipKind(in: text) != nil &&
                    NSMaxRange(range.contentRange) == offset
            }
    }

    private func linkRangeAdjacentToBoundary(
        _ selectedRange: NSRange,
        direction: BlockInputLinkBoundaryDeletionDirection,
        in text: String
    ) -> BlockInputInlineMarkdownRange? {
        guard selectedRange.length == 0 else {
            return nil
        }
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        return BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges, fileBaseURL: fileBaseURL)
            .first { range in
                range.style == .link && range.isAdjacent(to: selectedRange.location, direction: direction)
            }
    }
}

private struct InlineChipBoundaryInsertionCorrection {
    var text: String
    var cursorOffset: Int
}

private extension BlockInputInlineMarkdownRange {
    func isAdjacent(to offset: Int, direction: BlockInputLinkBoundaryDeletionDirection) -> Bool {
        switch direction {
        case .backward:
            offset == NSMaxRange(contentRange) || offset == NSMaxRange(fullRange)
        case .forward:
            offset == contentRange.location || offset == fullRange.location
        }
    }
}
