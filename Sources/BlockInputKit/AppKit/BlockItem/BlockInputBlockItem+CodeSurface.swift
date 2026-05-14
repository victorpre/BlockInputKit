import AppKit

extension BlockInputBlockItem {
    func applyCodeBlockAttributes(for block: BlockInputBlock, textStorage: NSTextStorage) {
        guard case let .code(language) = block.kind else {
            return
        }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let highlighted = BlockInputSyntaxHighlighter.highlighted(
            textStorage.string,
            language: language,
            colorScheme: BlockInputSyntaxColorScheme(appearance: textView.effectiveAppearance),
            font: Self.font(for: block.kind)
        )
        highlighted.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            textStorage.addAttributes(attributes, range: range)
        }
    }

    func configureCodeBackground(for block: BlockInputBlock) {
        guard case .code = block.kind else {
            codeBackgroundView.isHidden = true
            codeBackgroundView.alphaValue = 0
            renderedCodeColorScheme = nil
            return
        }
        codeBackgroundView.isHidden = false
        codeBackgroundView.alphaValue = 1
        codeBackgroundView.layer?.backgroundColor = Self.codeBackgroundColor(for: effectiveCodeColorScheme).cgColor
        codeBackgroundView.layer?.borderColor = Self.codeBorderColor(for: effectiveCodeColorScheme).cgColor
        renderedCodeColorScheme = effectiveCodeColorScheme
        updateCodeBackgroundFrame()
    }

    func refreshCodeAppearanceIfNeeded() {
        guard let renderedBlock,
              case .code = renderedBlock.kind,
              renderedCodeColorScheme != effectiveCodeColorScheme else {
            return
        }
        configureCodeBackground(for: renderedBlock)
        applyTextAttributes(for: renderedBlock)
    }

    func updateCodeBackgroundFrame() {
        guard !codeBackgroundView.isHidden else {
            return
        }
        let verticalInset: CGFloat = 2
        let leadingInset: CGFloat = 0
        let trailingInset: CGFloat = 0
        codeBackgroundView.frame = NSRect(
            x: scrollView.frame.minX - leadingInset,
            y: max(0, scrollView.frame.minY + verticalInset),
            width: max(0, scrollView.frame.width + leadingInset + trailingInset),
            height: max(0, scrollView.frame.height - verticalInset * 2)
        ).integral
    }

    private var effectiveCodeColorScheme: BlockInputSyntaxColorScheme {
        BlockInputSyntaxColorScheme(appearance: view.effectiveAppearance)
    }

    private static func codeBackgroundColor(for colorScheme: BlockInputSyntaxColorScheme) -> NSColor {
        switch colorScheme {
        case .dark:
            return NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        case .light:
            return NSColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1)
        }
    }

    private static func codeBorderColor(for colorScheme: BlockInputSyntaxColorScheme) -> NSColor {
        switch colorScheme {
        case .dark:
            return NSColor(srgbRed: 0.23, green: 0.25, blue: 0.28, alpha: 1)
        case .light:
            return NSColor(srgbRed: 0.84, green: 0.86, blue: 0.89, alpha: 1)
        }
    }
}
