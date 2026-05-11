import AppKit

extension BlockInputBlockItem {
    func utf16Offset(
        closestToTextContainerX preferredTextContainerX: CGFloat?,
        linePosition: TextLinePosition
    ) -> Int {
        let textLength = (textView.string as NSString).length
        guard let preferredTextContainerX,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let line = textLineFragments().line(at: linePosition) else {
            return linePosition == .first ? 0 : textLength
        }
        var fraction: CGFloat = 0
        let characterIndex = layoutManager.characterIndex(
            for: NSPoint(x: preferredTextContainerX, y: line.usedRect.midY),
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        let roundedCharacterIndex = characterIndex + (fraction > 0.5 ? 1 : 0)
        return min(max(roundedCharacterIndex, line.insertionRange.location), NSMaxRange(line.insertionRange))
    }

    func canMoveVerticallyOutOfBlock(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        let selectedRange = textView.selectedRange()
        guard selectedRange.length == 0 else {
            return false
        }
        let lines = textLineFragments()
        guard let lineIndex = lineIndex(containingUTF16Offset: selectedRange.location, lines: lines) else {
            let textLength = (textView.string as NSString).length
            switch direction {
            case .upward:
                return selectedRange.location == 0
            case .downward:
                return selectedRange.location >= textLength
            }
        }
        switch direction {
        case .upward:
            return lineIndex == 0
        case .downward:
            return lineIndex == lines.count - 1
        }
    }

    func currentCaretTextContainerX() -> CGFloat? {
        guard let window = textView.window else {
            return nil
        }
        // AppKit reports caret rects in screen coordinates; convert back into text-container coordinates.
        let caretRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
        guard caretRect != .zero, !caretRect.isNull, !caretRect.isInfinite else {
            return nil
        }
        let windowPoint = window.convertPoint(fromScreen: caretRect.origin)
        let localPoint = textView.convert(windowPoint, from: nil)
        return localPoint.x - textView.textContainerOrigin.x
    }

    private func lineIndex(containingUTF16Offset offset: Int, lines: [TextLineFragment]) -> Int? {
        let textLength = (textView.string as NSString).length
        let clampedOffset = min(max(offset, 0), textLength)
        guard !lines.isEmpty else {
            return nil
        }
        // At the start of an internal line, let NSTextView handle normal in-block vertical movement.
        if let index = lines.firstIndex(where: { $0.characterRange.location == clampedOffset }) {
            return index
        }
        for (index, line) in lines.enumerated() {
            let isFinalTextOffset = index == lines.count - 1 && clampedOffset == textLength
            if line.containsInterior(utf16Offset: clampedOffset) || isFinalTextOffset {
                return index
            }
        }
        return clampedOffset == textLength ? lines.indices.last : nil
    }

    private func textLineFragments() -> [TextLineFragment] {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return []
        }
        let text = textView.string as NSString
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else {
            let emptyRange = NSRange(location: 0, length: 0)
            return [TextLineFragment(characterRange: emptyRange, insertionRange: emptyRange, usedRect: .zero)]
        }

        var fragments: [TextLineFragment] = []
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let characterRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            fragments.append(TextLineFragment(
                characterRange: characterRange,
                insertionRange: characterRange.insertionRange(in: text),
                usedRect: usedRect
            ))
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
        return fragments
    }
}

private struct TextLineFragment {
    var characterRange: NSRange
    var insertionRange: NSRange
    var usedRect: NSRect

    func containsInterior(utf16Offset: Int) -> Bool {
        utf16Offset > characterRange.location && utf16Offset < NSMaxRange(characterRange)
    }
}

private extension NSRange {
    func insertionRange(in text: NSString) -> NSRange {
        var upperBound = min(NSMaxRange(self), text.length)
        while upperBound > location {
            let character = text.character(at: upperBound - 1)
            guard character == 10 || character == 13 else {
                break
            }
            upperBound -= 1
        }
        return NSRange(location: location, length: upperBound - location)
    }
}

private extension Array where Element == TextLineFragment {
    func line(at position: BlockInputBlockItem.TextLinePosition) -> TextLineFragment? {
        switch position {
        case .first:
            return first
        case .last:
            return last
        }
    }
}
