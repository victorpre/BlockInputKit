import AppKit

extension BlockInputTextView {
    /// Keeps plain left/right movement aligned with the visible link/chip boundary, not hidden Markdown source bytes.
    func handleLinkBoundaryMovementCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveLeft(_:)):
            return moveAcrossHiddenLinkBoundary(.leftward)
        case #selector(moveRight(_:)):
            return moveAcrossHiddenLinkBoundary(.rightward)
        default:
            return false
        }
    }

    func handleLinkBoundaryMovementShortcut(_ event: NSEvent) -> Bool {
        guard let direction = event.plainHorizontalMovementDirection else {
            return false
        }
        return moveAcrossHiddenLinkBoundary(direction)
    }

    private func moveAcrossHiddenLinkBoundary(_ direction: BlockInputHorizontalMovementDirection) -> Bool {
        let selectedRange = selectedRange()
        guard selectedRange.length == 0,
              let renderedBlock = blockItem?.renderedBlock,
              BlockInputBlockItem.supportsInlineMarkdownStyling(renderedBlock.kind),
              let targetOffset = hiddenLinkBoundaryTargetOffset(
                from: selectedRange.location,
                direction: direction,
                text: string
              ) else {
            return false
        }
        let targetRange = NSRange(location: targetOffset, length: 0)
        setSelectedRange(targetRange)
        scrollRangeToVisible(targetRange)
        return true
    }

    private func hiddenLinkBoundaryTargetOffset(
        from offset: Int,
        direction: BlockInputHorizontalMovementDirection,
        text: String
    ) -> Int? {
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let linkRanges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)
            .filter { $0.style == .link }
        switch direction {
        case .leftward:
            return linkRanges.last { range in
                range.contentRange.location == offset && range.fullRange.location < offset
            }?.fullRange.location
        case .rightward:
            return linkRanges.first { range in
                NSMaxRange(range.contentRange) == offset && NSMaxRange(range.fullRange) > offset
            }.map { NSMaxRange($0.fullRange) }
        }
    }
}
