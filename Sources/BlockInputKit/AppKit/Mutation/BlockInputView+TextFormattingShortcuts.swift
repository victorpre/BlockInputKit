import AppKit

extension BlockInputView {
    @discardableResult
    func performTextFormattingShortcut(_ shortcut: BlockInputTextFormattingShortcut) -> Bool {
        refreshDocumentFromStore()
        guard let selection,
              containsValidSelection(selection) else {
            return false
        }
        let segments = formattingSegments(in: selection)
        guard !segments.isEmpty else {
            return false
        }
        let style = TextFormattingStyle(shortcut)
        let shouldRemove = segments.allSatisfy { style.formattedRange(in: $0.block.text, selectedRange: $0.range) != nil }
        let result = formattedBlocks(from: segments, style: style, removesFormatting: shouldRemove, originalSelection: selection)
        guard !result.changedBlocks.isEmpty else {
            return false
        }
        applyTextFormattingResult(result, actionName: shouldRemove ? "Unformat Text" : "Format Text")
        return true
    }

    private func applyTextFormattingResult(
        _ result: TextFormattingResult,
        actionName: String
    ) {
        if result.changedBlocks.count == 1,
           let afterBlock = result.changedBlocks.first,
           let beforeBlock = result.beforeBlocks.first(where: { $0.id == afterBlock.id }),
           let index = index(of: afterBlock.id) {
            _ = applyGranularBlockReplacement(afterBlock, at: index, selection: result.selectionAfter)
            undoController?.registerBlockReplacementStructuralEdit(
                actionName: actionName,
                beforeBlock: beforeBlock,
                afterBlock: afterBlock,
                selectionBefore: result.selectionBefore,
                selectionAfter: result.selectionAfter
            )
            return
        }

        let changedBeforeBlocks = result.changedBlocks.compactMap { afterBlock in
            result.beforeBlocks.first { $0.id == afterBlock.id }
        }
        _ = applyGranularBlockReplacements(result.changedBlocks, selection: result.selectionAfter)
        undoController?.registerMultiBlockReplacementStructuralEdit(BlockInputMultiBlockReplacementEdit(
            actionName: actionName,
            beforeBlocks: changedBeforeBlocks,
            afterBlocks: result.changedBlocks,
            selectionBefore: result.selectionBefore,
            selectionAfter: result.selectionAfter
        ))
    }

    private func formattingSegments(in selection: BlockInputSelection) -> [TextFormattingSegment] {
        switch selection {
        case let .text(textRange):
            return formattingSegment(for: textRange, trimsHiddenDelimiters: true).map { [$0] } ?? []
        case let .blocks(blockIDs):
            return blockIDs.compactMap { blockID in
                guard let block = block(withID: blockID) else {
                    return nil
                }
                return formattingSegment(
                    for: block,
                    range: NSRange(location: 0, length: block.utf16Length),
                    trimsHiddenDelimiters: false
                )
            }
        case let .mixed(mixedSelection):
            return formattingSegments(in: mixedSelection)
        case .cursor:
            return []
        }
    }

    private func formattingSegments(in selection: BlockInputMixedSelection) -> [TextFormattingSegment] {
        var segments: [TextFormattingSegment] = []
        if let leadingRange = selection.leadingTextRange,
           let segment = formattingSegment(for: leadingRange, trimsHiddenDelimiters: true) {
            segments.append(segment)
        }
        for blockID in selection.blockIDs {
            guard let block = block(withID: blockID),
                  let segment = formattingSegment(
                    for: block,
                    range: NSRange(location: 0, length: block.utf16Length),
                    trimsHiddenDelimiters: false
                  ) else {
                continue
            }
            segments.append(segment)
        }
        if let trailingRange = selection.trailingTextRange,
           let segment = formattingSegment(for: trailingRange, trimsHiddenDelimiters: true) {
            segments.append(segment)
        }
        return segments.sorted { lhs, rhs in
            (index(of: lhs.block.id) ?? Int.max) < (index(of: rhs.block.id) ?? Int.max)
        }
    }

    private func formattingSegment(
        for textRange: BlockInputTextRange,
        trimsHiddenDelimiters: Bool
    ) -> TextFormattingSegment? {
        guard let block = block(withID: textRange.blockID) else {
            return nil
        }
        return formattingSegment(for: block, range: textRange.range, trimsHiddenDelimiters: trimsHiddenDelimiters)
    }

    private func formattingSegment(
        for block: BlockInputBlock,
        range: NSRange,
        trimsHiddenDelimiters: Bool
    ) -> TextFormattingSegment? {
        guard BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind) else {
            return nil
        }
        let clampedRange = block.text.blockInputFormattingClampedRange(
            range,
            trimsHiddenDelimiters: trimsHiddenDelimiters
        )
        guard clampedRange.length > 0 else {
            return nil
        }
        return TextFormattingSegment(block: block, range: clampedRange)
    }

    private func formattedBlocks(
        from segments: [TextFormattingSegment],
        style: TextFormattingStyle,
        removesFormatting: Bool,
        originalSelection: BlockInputSelection
    ) -> TextFormattingResult {
        let segmentsByBlockID = Dictionary(grouping: segments, by: { $0.block.id })
        var beforeBlocks: [BlockInputBlock] = []
        var afterBlocks: [BlockInputBlock] = []
        var changedBlocks: [BlockInputBlock] = []
        var originalRanges: [BlockInputBlockID: NSRange] = [:]
        var adjustedRanges: [BlockInputBlockID: NSRange] = [:]

        for blockID in orderedBlockIDs(from: segments) {
            guard let blockSegments = segmentsByBlockID[blockID],
                  let beforeBlock = blockSegments.first?.block else {
                continue
            }
            for segment in blockSegments {
                originalRanges[segment.block.id] = segment.range
            }
            let formatted = formattedBlock(
                beforeBlock,
                segments: blockSegments,
                style: style,
                removesFormatting: removesFormatting
            )
            beforeBlocks.append(beforeBlock)
            afterBlocks.append(formatted.block)
            if beforeBlock != formatted.block {
                changedBlocks.append(formatted.block)
            }
            for (blockID, range) in formatted.adjustedRanges {
                adjustedRanges[blockID] = range
            }
        }

        return TextFormattingResult(
            beforeBlocks: beforeBlocks,
            afterBlocks: afterBlocks,
            changedBlocks: changedBlocks,
            selectionBefore: adjustedSelection(from: originalSelection, adjustedRanges: originalRanges),
            selectionAfter: adjustedSelection(from: originalSelection, adjustedRanges: adjustedRanges)
        )
    }

    private func orderedBlockIDs(from segments: [TextFormattingSegment]) -> [BlockInputBlockID] {
        var seen: Set<BlockInputBlockID> = []
        return segments.compactMap { segment in
            guard !seen.contains(segment.block.id) else {
                return nil
            }
            seen.insert(segment.block.id)
            return segment.block.id
        }
    }

    private func formattedBlock(
        _ block: BlockInputBlock,
        segments: [TextFormattingSegment],
        style: TextFormattingStyle,
        removesFormatting: Bool
    ) -> FormattedBlock {
        var text = block.text
        var adjustedRanges: [BlockInputBlockID: NSRange] = [:]
        for segment in segments.sorted(by: { $0.range.location > $1.range.location }) {
            let edit = removesFormatting
                ? style.removingFormatting(in: text, selectedRange: segment.range)
                : style.addingFormatting(in: text, selectedRange: segment.range)
            guard let edit else {
                adjustedRanges[segment.block.id] = segment.range
                continue
            }
            text = edit.text
            adjustedRanges[segment.block.id] = edit.selectedRange
        }
        var afterBlock = block
        afterBlock.text = text
        return FormattedBlock(block: afterBlock, adjustedRanges: adjustedRanges)
    }

    private func adjustedSelection(
        from selection: BlockInputSelection,
        adjustedRanges: [BlockInputBlockID: NSRange]
    ) -> BlockInputSelection {
        switch selection {
        case let .text(textRange):
            return .text(BlockInputTextRange(
                blockID: textRange.blockID,
                range: adjustedRanges[textRange.blockID] ?? textRange.range
            ))
        case .blocks, .cursor:
            return selection
        case let .mixed(mixedSelection):
            return .mixed(BlockInputMixedSelection(
                blockIDs: mixedSelection.blockIDs,
                leadingTextRange: adjustedTextRange(mixedSelection.leadingTextRange, adjustedRanges: adjustedRanges),
                trailingTextRange: adjustedTextRange(mixedSelection.trailingTextRange, adjustedRanges: adjustedRanges)
            ))
        }
    }

    private func adjustedTextRange(
        _ textRange: BlockInputTextRange?,
        adjustedRanges: [BlockInputBlockID: NSRange]
    ) -> BlockInputTextRange? {
        guard let textRange else {
            return nil
        }
        return BlockInputTextRange(
            blockID: textRange.blockID,
            range: adjustedRanges[textRange.blockID] ?? textRange.range
        )
    }
}

/// One eligible source range to format inside a block.
private struct TextFormattingSegment {
    var block: BlockInputBlock
    var range: NSRange
}

/// Batched formatting output used to apply edits and register one undo operation.
private struct TextFormattingResult {
    var beforeBlocks: [BlockInputBlock]
    var afterBlocks: [BlockInputBlock]
    var changedBlocks: [BlockInputBlock]
    var selectionBefore: BlockInputSelection
    var selectionAfter: BlockInputSelection
}
