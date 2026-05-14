import AppKit

extension BlockInputView {
    /// Handles Shift+Left/Right while preserving the illusion of one continuous Markdown document.
    ///
    /// `NSTextView` can adjust selections inside one block, but once the active edge crosses block chrome, this view
    /// owns the anchor/focus bookkeeping and rebuilds the canonical editor selection on each key press.
    func handleHorizontalSelectionAdjustmentKeyEvent(_ event: NSEvent) -> Bool {
        guard let direction = event.horizontalSelectionAdjustmentDirection else {
            return false
        }
        if let textView = window?.firstResponder as? BlockInputTextView,
           textView.requestHorizontalSelectionAdjustmentFromOwningBlock(direction) {
            return true
        }
        return adjustSelectionHorizontally(direction)
    }

    func handleHorizontalSelectionAdjustmentCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveLeftAndModifySelection(_:)):
            return adjustSelectionHorizontally(.leftward)
        case #selector(moveRightAndModifySelection(_:)):
            return adjustSelectionHorizontally(.rightward)
        default:
            return false
        }
    }

    func adjustSelectionHorizontally(
        from blockID: BlockInputBlockID,
        selectedRange: NSRange,
        direction: BlockInputHorizontalMovementDirection
    ) -> Bool {
        if case .blocks = selection {
            return adjustSelectionHorizontally(direction)
        }
        if case .mixed = selection {
            return adjustSelectionHorizontally(direction)
        }
        guard let block = block(withID: blockID),
              block.kind != .horizontalRule else {
            return false
        }
        let clampedRange = selectedRange.clamped(to: block.utf16Length)
        if clampedRange.length == 0 {
            let anchor = BlockInputDocumentTextBoundary(blockID: blockID, utf16Offset: clampedRange.location)
            return adjustSelectionHorizontally(from: anchor, direction: direction)
        }
        let start = BlockInputDocumentTextBoundary(blockID: blockID, utf16Offset: clampedRange.location)
        let end = BlockInputDocumentTextBoundary(blockID: blockID, utf16Offset: NSMaxRange(clampedRange))
        guard let seededSelection = selection(from: start, to: end) else {
            return false
        }
        applySelection(seededSelection, notify: false)
        return adjustSelectionHorizontally(direction)
    }

    func adjustSelectionHorizontally(_ direction: BlockInputHorizontalMovementDirection) -> Bool {
        guard let span = horizontalSelectionSpan(preferredDirection: direction),
              let nextActiveBoundary = horizontalBoundary(from: span.active, moving: direction),
              nextActiveBoundary != span.active,
              let adjustedSelection = selection(from: span.anchor, to: nextActiveBoundary) else {
            return false
        }
        applyHorizontalSelection(adjustedSelection, anchor: span.anchor, active: nextActiveBoundary)
        scrollHorizontalSelectionBoundaryToVisible(nextActiveBoundary)
        return true
    }

    func expandHorizontalSelectionVerticallyIfNeeded(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard horizontalSelectionExpansion != nil,
              let span = horizontalSelectionSpan(preferredDirection: .rightward),
              let activeIndex = index(of: span.active.blockID),
              let target = verticalBoundary(from: span.active, activeIndex: activeIndex, direction: direction),
              target != span.active,
              let adjustedSelection = selection(from: span.anchor, to: target) else {
            return false
        }
        applyHorizontalSelection(adjustedSelection, anchor: span.anchor, active: target)
        scrollBlockSelectionBoundaryToVisible(index(of: target.blockID) ?? activeIndex)
        return true
    }

    private func adjustSelectionHorizontally(
        from anchor: BlockInputDocumentTextBoundary,
        direction: BlockInputHorizontalMovementDirection
    ) -> Bool {
        guard let active = horizontalBoundary(from: anchor, moving: direction),
              let adjustedSelection = selection(from: anchor, to: active) else {
            return false
        }
        applyHorizontalSelection(adjustedSelection, anchor: anchor, active: active)
        scrollHorizontalSelectionBoundaryToVisible(active)
        return true
    }

    private func verticalBoundary(
        from boundary: BlockInputDocumentTextBoundary,
        activeIndex: Int,
        direction: BlockInputVerticalMovementDirection
    ) -> BlockInputDocumentTextBoundary? {
        switch direction {
        case .upward:
            guard activeIndex > 0, let targetBlock = block(at: activeIndex - 1) else {
                return nil
            }
            let targetRange = partialTargetRange(
                for: targetBlock.id,
                at: activeIndex - 1,
                direction: direction,
                preferredTextContainerX: preferredNavigationX
            )
            let offset = targetRange?.range.location ?? 0
            return BlockInputDocumentTextBoundary(blockID: targetBlock.id, utf16Offset: offset)
        case .downward:
            guard activeIndex + 1 < blockCount, let targetBlock = block(at: activeIndex + 1) else {
                return nil
            }
            let targetRange = partialTargetRange(
                for: targetBlock.id,
                at: activeIndex + 1,
                direction: direction,
                preferredTextContainerX: preferredNavigationX
            )
            let offset = targetRange.map { NSMaxRange($0.range) } ?? targetBlock.utf16Length
            return BlockInputDocumentTextBoundary(blockID: targetBlock.id, utf16Offset: offset)
        }
    }

    private func applyHorizontalSelection(
        _ selection: BlockInputSelection,
        anchor: BlockInputDocumentTextBoundary,
        active: BlockInputDocumentTextBoundary
    ) {
        applySelection(selection, notify: true)
        horizontalSelectionExpansion = selection.isCollapsed ? nil : BlockInputHorizontalSelectionExpansion(anchor: anchor)
        preferredNavigationX = textContainerX(for: active)
        blockSelectionExpansion = nil
        switch selection {
        case let .cursor(cursor):
            focusVisibleItem(for: cursor)
        case let .text(textRange):
            restoreVisibleTextSelection(textRange)
        case .blocks, .mixed:
            window?.makeFirstResponder(self)
            publishFocusChange(true)
        }
    }

    private func textContainerX(for boundary: BlockInputDocumentTextBoundary) -> CGFloat? {
        guard let item = visibleItem(for: boundary.blockID, refreshConfiguration: false) else {
            return nil
        }
        return item.textContainerX(forUTF16Offset: boundary.utf16Offset)
    }

    private func horizontalSelectionSpan(
        preferredDirection: BlockInputHorizontalMovementDirection
    ) -> (anchor: BlockInputDocumentTextBoundary, active: BlockInputDocumentTextBoundary)? {
        guard let selectedBounds = selectionBounds() else {
            return nil
        }
        // Keep the original fixed edge whenever Shift+Left/Right continues from an editor-owned selection. Without
        // this, opposite-direction movement would flip the anchor and expand instead of first contracting.
        if let anchor = horizontalSelectionExpansion?.anchor,
           let span = anchoredHorizontalSelectionSpan(anchor: anchor, selectedBounds: selectedBounds) {
            return span
        }
        if let expansion = blockSelectionExpansion {
            switch expansion.direction {
            case .upward:
                return (anchor: selectedBounds.end, active: selectedBounds.start)
            case .downward:
                return (anchor: selectedBounds.start, active: selectedBounds.end)
            }
        }
        switch preferredDirection {
        case .leftward:
            return (anchor: selectedBounds.end, active: selectedBounds.start)
        case .rightward:
            return (anchor: selectedBounds.start, active: selectedBounds.end)
        }
    }

    private func selectionBounds() -> (start: BlockInputDocumentTextBoundary, end: BlockInputDocumentTextBoundary)? {
        switch selection {
        case let .cursor(cursor):
            let boundary = BlockInputDocumentTextBoundary(blockID: cursor.blockID, utf16Offset: cursor.utf16Offset)
            return (start: boundary, end: boundary)
        case let .text(textRange):
            return (
                start: BlockInputDocumentTextBoundary(blockID: textRange.blockID, utf16Offset: textRange.range.location),
                end: BlockInputDocumentTextBoundary(blockID: textRange.blockID, utf16Offset: NSMaxRange(textRange.range))
            )
        case let .blocks(blockIDs):
            return wholeBlockSelectionBounds(blockIDs)
        case let .mixed(selection):
            return mixedSelectionBounds(selection)
        case nil:
            return nil
        }
    }

    private func wholeBlockSelectionBounds(
        _ blockIDs: [BlockInputBlockID]
    ) -> (start: BlockInputDocumentTextBoundary, end: BlockInputDocumentTextBoundary)? {
        let indexes = blockIDs.compactMap { index(of: $0) }.sorted()
        guard let firstIndex = indexes.first,
              let lastIndex = indexes.last,
              let firstBlock = block(at: firstIndex),
              let lastBlock = block(at: lastIndex) else {
            return nil
        }
        return (
            start: BlockInputDocumentTextBoundary(blockID: firstBlock.id, utf16Offset: 0),
            end: BlockInputDocumentTextBoundary(blockID: lastBlock.id, utf16Offset: lastBlock.utf16Length)
        )
    }

    private func mixedSelectionBounds(
        _ selection: BlockInputMixedSelection
    ) -> (start: BlockInputDocumentTextBoundary, end: BlockInputDocumentTextBoundary)? {
        let sortedWholeIndexes = selection.blockIDs.compactMap { index(of: $0) }.sorted()
        let leadingIndex = selection.leadingTextRange.flatMap { index(of: $0.blockID) }
        let trailingIndex = selection.trailingTextRange.flatMap { index(of: $0.blockID) }
        let firstIndex = [leadingIndex, sortedWholeIndexes.first, trailingIndex].compactMap { $0 }.min()
        let lastIndex = [leadingIndex, sortedWholeIndexes.last, trailingIndex].compactMap { $0 }.max()
        guard let firstIndex, let lastIndex,
              let firstBlock = block(at: firstIndex),
              let lastBlock = block(at: lastIndex) else {
            return nil
        }
        if let singleBlockBounds = singleBlockMixedSelectionBounds(
            selection,
            firstBlock: firstBlock,
            firstIndex: firstIndex,
            lastIndex: lastIndex
        ) {
            return singleBlockBounds
        }
        let startOffset = selection.leadingTextRange?.blockID == firstBlock.id
            ? selection.leadingTextRange?.range.location ?? 0
            : 0
        let endOffset = selection.trailingTextRange?.blockID == lastBlock.id
            ? selection.trailingTextRange.map { NSMaxRange($0.range) } ?? lastBlock.utf16Length
            : lastBlock.utf16Length
        return (
            start: BlockInputDocumentTextBoundary(blockID: firstBlock.id, utf16Offset: startOffset),
            end: BlockInputDocumentTextBoundary(blockID: lastBlock.id, utf16Offset: endOffset)
        )
    }

    private func singleBlockMixedSelectionBounds(
        _ selection: BlockInputMixedSelection,
        firstBlock: BlockInputBlock,
        firstIndex: Int,
        lastIndex: Int
    ) -> (start: BlockInputDocumentTextBoundary, end: BlockInputDocumentTextBoundary)? {
        // A one-block editor-owned partial selection stores its exact range in `BlockInputMixedSelection`; do not widen
        // it to the whole block or the saved horizontal anchor will be lost before Shift+Up/Down can reuse its X.
        guard firstIndex == lastIndex,
              let textRange = [selection.leadingTextRange, selection.trailingTextRange]
            .compactMap({ $0 })
            .first(where: { $0.blockID == firstBlock.id }) else {
            return nil
        }
        return (
            start: BlockInputDocumentTextBoundary(blockID: firstBlock.id, utf16Offset: textRange.range.location),
            end: BlockInputDocumentTextBoundary(blockID: firstBlock.id, utf16Offset: NSMaxRange(textRange.range))
        )
    }

    private func horizontalBoundary(
        from boundary: BlockInputDocumentTextBoundary,
        moving direction: BlockInputHorizontalMovementDirection
    ) -> BlockInputDocumentTextBoundary? {
        switch direction {
        case .leftward:
            return boundaryBefore(boundary)
        case .rightward:
            return boundaryAfter(boundary)
        }
    }

    private func boundaryBefore(_ boundary: BlockInputDocumentTextBoundary) -> BlockInputDocumentTextBoundary? {
        guard let index = index(of: boundary.blockID),
              let block = block(at: index) else {
            return nil
        }
        let offset = min(max(boundary.utf16Offset, 0), block.utf16Length)
        if block.kind != .horizontalRule, offset > 0 {
            return BlockInputDocumentTextBoundary(blockID: block.id, utf16Offset: offset - 1)
        }
        // Crossing left from a fully selected block lands on the previous block's final character, matching the
        // flattened-Markdown behavior the editor models.
        guard index > 0, let previousBlock = self.block(at: index - 1) else {
            return nil
        }
        let previousOffset = previousBlock.kind == .horizontalRule ? 0 : max(previousBlock.utf16Length - 1, 0)
        return BlockInputDocumentTextBoundary(blockID: previousBlock.id, utf16Offset: previousOffset)
    }

    private func boundaryAfter(_ boundary: BlockInputDocumentTextBoundary) -> BlockInputDocumentTextBoundary? {
        guard let index = index(of: boundary.blockID),
              let block = block(at: index) else {
            return nil
        }
        let offset = min(max(boundary.utf16Offset, 0), block.utf16Length)
        if block.kind != .horizontalRule, offset < block.utf16Length {
            return BlockInputDocumentTextBoundary(blockID: block.id, utf16Offset: offset + 1)
        }
        // Crossing right from a fully selected block lands on the next block's first character.
        guard index + 1 < blockCount, let nextBlock = self.block(at: index + 1) else {
            return nil
        }
        let nextOffset = nextBlock.kind == .horizontalRule ? 0 : min(1, nextBlock.utf16Length)
        return BlockInputDocumentTextBoundary(blockID: nextBlock.id, utf16Offset: nextOffset)
    }

    private func selection(
        from anchor: BlockInputDocumentTextBoundary,
        to active: BlockInputDocumentTextBoundary
    ) -> BlockInputSelection? {
        guard let anchorIndex = index(of: anchor.blockID),
              let activeIndex = index(of: active.blockID) else {
            return nil
        }
        let ordered = orderedBoundaries(anchor, anchorIndex: anchorIndex, active, activeIndex: activeIndex)
        if ordered.start == ordered.end {
            return collapsedSelection(at: ordered.start)
        }
        if ordered.startIndex == ordered.endIndex {
            return singleBlockSelection(from: ordered.start, to: ordered.end)
        }
        return multiBlockSelection(
            start: ordered.start,
            startIndex: ordered.startIndex,
            end: ordered.end,
            endIndex: ordered.endIndex
        )
    }

    private func orderedBoundaries(
        _ lhs: BlockInputDocumentTextBoundary,
        anchorIndex lhsIndex: Int,
        _ rhs: BlockInputDocumentTextBoundary,
        activeIndex rhsIndex: Int
    ) -> BlockInputOrderedTextBoundarySpan {
        if lhsIndex < rhsIndex || (lhsIndex == rhsIndex && lhs.utf16Offset <= rhs.utf16Offset) {
            return BlockInputOrderedTextBoundarySpan(start: lhs, startIndex: lhsIndex, end: rhs, endIndex: rhsIndex)
        }
        return BlockInputOrderedTextBoundarySpan(start: rhs, startIndex: rhsIndex, end: lhs, endIndex: lhsIndex)
    }

    private func collapsedSelection(at boundary: BlockInputDocumentTextBoundary) -> BlockInputSelection? {
        guard let block = block(withID: boundary.blockID), block.kind != .horizontalRule else {
            return .blocks([boundary.blockID])
        }
        return .cursor(BlockInputCursor(
            blockID: boundary.blockID,
            utf16Offset: min(max(boundary.utf16Offset, 0), block.utf16Length)
        ))
    }

    private func singleBlockSelection(
        from start: BlockInputDocumentTextBoundary,
        to end: BlockInputDocumentTextBoundary
    ) -> BlockInputSelection? {
        guard let block = block(withID: start.blockID) else {
            return nil
        }
        let startOffset = min(max(start.utf16Offset, 0), block.utf16Length)
        let endOffset = min(max(end.utf16Offset, startOffset), block.utf16Length)
        guard block.kind != .horizontalRule, endOffset > startOffset else {
            return .blocks([block.id])
        }
        if startOffset == 0, endOffset == block.utf16Length {
            return .blocks([block.id])
        }
        return .mixed(BlockInputMixedSelection(blockIDs: [], leadingTextRange: BlockInputTextRange(
            blockID: block.id,
            range: NSRange(location: startOffset, length: endOffset - startOffset)
        )))
    }

    private func multiBlockSelection(
        start: BlockInputDocumentTextBoundary,
        startIndex: Int,
        end: BlockInputDocumentTextBoundary,
        endIndex: Int
    ) -> BlockInputSelection? {
        // Rebuild the narrowest canonical selection for the flattened span: fully covered blocks become `.blocks`,
        // and partial edges around whole middle blocks become `.mixed`.
        var blockIDs: [BlockInputBlockID] = []
        var leadingTextRange: BlockInputTextRange?
        var trailingTextRange: BlockInputTextRange?

        for index in startIndex...endIndex {
            guard let block = block(at: index) else {
                return nil
            }
            let blockStart = index == startIndex ? min(max(start.utf16Offset, 0), block.utf16Length) : 0
            let blockEnd = index == endIndex ? min(max(end.utf16Offset, 0), block.utf16Length) : block.utf16Length
            let coversWholeBlock = blockStart == 0 && blockEnd == block.utf16Length
            if block.kind == .horizontalRule || block.utf16Length == 0 || coversWholeBlock {
                if coversWholeBlock || startIndex != endIndex {
                    blockIDs.append(block.id)
                }
            } else if blockEnd > blockStart {
                let textRange = BlockInputTextRange(
                    blockID: block.id,
                    range: NSRange(location: blockStart, length: blockEnd - blockStart)
                )
                if index == startIndex {
                    leadingTextRange = textRange
                } else if index == endIndex {
                    trailingTextRange = textRange
                } else {
                    blockIDs.append(block.id)
                }
            }
        }

        if leadingTextRange == nil, trailingTextRange == nil {
            return blockIDs.isEmpty ? nil : .blocks(blockIDs)
        }
        return .mixed(BlockInputMixedSelection(
            blockIDs: blockIDs,
            leadingTextRange: leadingTextRange,
            trailingTextRange: trailingTextRange
        ))
    }

    private func scrollHorizontalSelectionBoundaryToVisible(_ boundary: BlockInputDocumentTextBoundary) {
        guard let index = index(of: boundary.blockID) else {
            return
        }
        collectionView.scrollToItems(at: [IndexPath(item: index, section: 0)], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
    }
}

private struct BlockInputOrderedTextBoundarySpan {
    var start: BlockInputDocumentTextBoundary
    var startIndex: Int
    var end: BlockInputDocumentTextBoundary
    var endIndex: Int
}

private extension BlockInputSelection {
    var isCollapsed: Bool {
        if case .cursor = self {
            return true
        }
        return false
    }
}

private extension NSRange {
    func clamped(to textLength: Int) -> NSRange {
        let location = min(max(location, 0), textLength)
        let length = min(max(length, 0), max(textLength - location, 0))
        return NSRange(location: location, length: length)
    }
}
