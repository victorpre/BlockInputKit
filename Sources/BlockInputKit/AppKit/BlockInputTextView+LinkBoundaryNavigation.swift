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
              let target = hiddenLinkBoundaryTarget(
                from: selectedRange.location,
                direction: direction,
                text: string
              ) else {
            return false
        }
        setSelectedRanges([NSValue(range: target.range)], affinity: target.affinity, stillSelecting: false)
        scrollRangeToVisible(target.range)
        return true
    }

    private func hiddenLinkBoundaryTarget(
        from offset: Int,
        direction: BlockInputHorizontalMovementDirection,
        text: String
    ) -> HiddenLinkBoundaryTarget? {
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let linkRanges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: text,
            excluding: inlineCodeRanges,
            fileBaseURL: blockItem?.fileBaseURL
        )
            .filter { $0.style == .link }
        let source = text as NSString
        let textLength = source.length
        switch direction {
        case .leftward:
            if let range = linkRanges.last(where: { range in
                range.contentRange.location == offset && range.fullRange.location < offset
            }) {
                return HiddenLinkBoundaryTarget(
                    range: range.visibleLeadingExitRange(in: source),
                    affinity: .upstream
                )
            }
            return linkRanges.last { range in
                range.fullRange.location == offset && range.fullRange.location < NSMaxRange(range.fullRange)
            }.map { range in
                HiddenLinkBoundaryTarget(
                    range: range.visibleLeadingExitRange(in: source),
                    affinity: .upstream
                )
            }
        case .rightward:
            if let range = linkRanges.first(where: { range in
                NSMaxRange(range.contentRange) == offset && NSMaxRange(range.fullRange) > offset
            }) {
                return HiddenLinkBoundaryTarget(
                    range: range.visibleTrailingExitRange(in: source, textLength: textLength),
                    affinity: .downstream
                )
            }
            return linkRanges.first { range in
                NSMaxRange(range.fullRange) == offset && range.fullRange.location < NSMaxRange(range.fullRange)
            }.map { range in
                HiddenLinkBoundaryTarget(
                    range: range.visibleTrailingExitRange(in: source, textLength: textLength),
                    affinity: .downstream
                )
            }
        }
    }
}

private extension BlockInputInlineMarkdownRange {
    func visibleLeadingExitRange(in text: NSString) -> NSRange {
        guard fullRange.location > 0 else {
            return NSRange(location: 0, length: 0)
        }
        let previousCharacterRange = text.rangeOfComposedCharacterSequence(at: fullRange.location - 1)
        return NSRange(location: previousCharacterRange.location, length: 0)
    }

    func visibleTrailingExitRange(in text: NSString, textLength: Int) -> NSRange {
        let endOffset = NSMaxRange(fullRange)
        guard endOffset < textLength else {
            return NSRange(location: textLength, length: 0)
        }
        let nextCharacterRange = text.rangeOfComposedCharacterSequence(at: endOffset)
        return NSRange(location: NSMaxRange(nextCharacterRange), length: 0)
    }
}

private struct HiddenLinkBoundaryTarget {
    let range: NSRange
    let affinity: NSSelectionAffinity
}
