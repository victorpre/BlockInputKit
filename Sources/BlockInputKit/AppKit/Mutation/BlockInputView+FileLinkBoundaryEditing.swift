import AppKit

extension BlockInputView {
    func resolvedFileLinkBoundaryTextChange(
        item: BlockInputBlockItem,
        beforeBlock: BlockInputBlock,
        proposedText: String,
        selectionBefore: BlockInputSelection?
    ) -> (text: String, proposedOffset: Int) {
        let selectedRange = item.currentSelectedRange
        guard let correction = fileLinkBoundaryInsertionCorrection(
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

    func fileLinkBoundaryAdjustedRange(_ range: NSRange, in block: BlockInputBlock) -> NSRange {
        guard range.length == 0,
              Self.blockKindSupportsFileLinkBoundaryCorrection(block.kind),
              let linkRange = Self.fileLinkRangeEndingAtContentBoundary(range.location, in: block.text) else {
            return range
        }
        return NSRange(location: NSMaxRange(linkRange.fullRange), length: 0)
    }

    private func fileLinkBoundaryInsertionCorrection(
        beforeBlock: BlockInputBlock,
        proposedText: String,
        selectionBefore: BlockInputSelection?
    ) -> FileLinkBoundaryInsertionCorrection? {
        guard Self.blockKindSupportsFileLinkBoundaryCorrection(beforeBlock.kind),
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
              let linkRange = Self.fileLinkRangeEndingAtContentBoundary(cursorOffset, in: beforeBlock.text) else {
            return nil
        }
        let insertionOffset = NSMaxRange(linkRange.fullRange)
        let correctedText = NSMutableString(string: beforeBlock.text)
        correctedText.insert(insertedText, at: insertionOffset)
        return FileLinkBoundaryInsertionCorrection(
            text: correctedText as String,
            cursorOffset: insertionOffset + insertionLength
        )
    }

    private static func blockKindSupportsFileLinkBoundaryCorrection(_ kind: BlockInputBlockKind) -> Bool {
        BlockInputBlockItem.supportsInlineMarkdownStyling(kind)
    }

    private static func fileLinkRangeEndingAtContentBoundary(
        _ offset: Int,
        in text: String
    ) -> BlockInputInlineMarkdownRange? {
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        return BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)
            .first { range in
                range.style == .link &&
                    range.linkDestination?.isFileURL == true &&
                    NSMaxRange(range.contentRange) == offset
            }
    }
}

private struct FileLinkBoundaryInsertionCorrection {
    var text: String
    var cursorOffset: Int
}
