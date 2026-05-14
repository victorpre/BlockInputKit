import AppKit

extension BlockInputBlockItem {
    func configureBlockKindChrome(block: BlockInputBlock) {
        let kind = block.kind
        let isHorizontalRule = kind == .horizontalRule
        let contentIndent = Self.contentIndent(for: block)
        let perLineContentIndent = Self.perLineContentIndent(for: block)
        let verticalMetrics = Self.verticalMetrics(for: block)
        textView.textContainerInset = verticalMetrics.textContainerInset
        textView.isEditable = !isHorizontalRule
        textView.isSelectable = !isHorizontalRule
        configureTextScrolling(for: block)
        applyTextAttributes(for: block)
        scrollView.isHidden = isHorizontalRule
        configureCodeBackground(for: block)
        scrollViewTopConstraint?.constant = 0
        scrollViewBottomConstraint?.constant = 0
        handleTopConstraint?.constant = Self.dragHandleTopConstant(for: block.kind, metrics: verticalMetrics)
        kindLabelTopConstraint?.constant = 0
        checklistButtonTopConstraint?.constant = verticalMetrics.checklistButtonTopConstant(
            font: Self.font(for: block.kind),
            checkboxHeight: Self.checklistButtonHeight
        )
        kindLabelLeadingConstraint?.constant = kindLabelLeadingConstant(for: block, contentIndent: contentIndent)
        kindLabelWidthConstraint?.constant = kindLabelWidthConstant(for: block, perLineContentIndent: perLineContentIndent)
        scrollViewLeadingConstraint?.constant = textLeadingConstant(
            for: kind,
            perLineContentIndent: perLineContentIndent
        )
        horizontalRuleLeadingConstraint?.constant = Self.defaultTextLeading + 4
        quoteBarView.isHidden = kind != .quote || isHorizontalRule
        quoteBarView.alphaValue = quoteBarView.isHidden ? 0 : 1
        horizontalRuleView.setVisible(isHorizontalRule)
        applyKindLabelAttributes(for: block)
        updateQuoteBarVerticalExtent()
        switch kind {
        case let .checklistItem(isChecked):
            checklistButton.isHidden = false
            checklistButton.isEnabled = true
            checklistButton.state = isChecked ? .on : .off
            checklistButtonLeadingConstraint?.constant = Self.checklistButtonLeadingConstant(
                indentationLevel: block.indentationLevel(forLine: 0),
                rowContentIndent: contentIndent
            )
        default:
            checklistButton.isHidden = true
            checklistButton.isEnabled = false
            checklistButton.state = .off
            checklistButtonLeadingConstraint?.constant = Self.checklistButtonBaseLeading
        }
    }

    func kindLabelLeadingConstant(for block: BlockInputBlock, contentIndent: CGFloat) -> CGFloat {
        switch block.kind {
        case .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return Self.markerAlignmentLeading + contentIndent
        case .paragraph, .heading, .code, .horizontalRule:
            return contentIndent
        }
    }

    func kindLabelWidthConstant(
        for block: BlockInputBlock,
        perLineContentIndent: CGFloat
    ) -> CGFloat {
        guard block.kind.needsVisibleMarkerLane else {
            return 0
        }
        if block.kind == .quote {
            return 0
        }
        return Self.markerGutterWidth(for: block) + perLineContentIndent
    }

    func textLeadingConstant(
        for kind: BlockInputBlockKind,
        perLineContentIndent: CGFloat
    ) -> CGFloat {
        if kind == .quote {
            return Self.quoteTextLeading
        }
        if kind.supportsIndentation {
            return Self.listTextLeading - perLineContentIndent
        }
        return Self.defaultTextLeading
    }

    static func checklistButtonLeadingConstant(
        indentationLevel: Int,
        rowContentIndent: CGFloat
    ) -> CGFloat {
        checklistButtonBaseLeading + contentIndent(forIndentationLevel: indentationLevel) - rowContentIndent
    }

    static func markerGutterWidth(for block: BlockInputBlock) -> CGFloat {
        guard block.kind.needsVisibleMarkerLane else {
            return 0
        }
        guard block.kind.supportsIndentation else {
            return markerGutterWidth
        }
        let markerLines = markerLines(for: block)
        let markerTexts = markerLines.isEmpty ? [prefix(for: block.kind, indentationLevel: block.indentationLevel)] : markerLines.map(\.text)
        let widestMarker = markerTexts.reduce(CGFloat.zero) { widest, marker in
            guard !marker.isEmpty else {
                return widest
            }
            let width = (marker as NSString).size(withAttributes: [.font: font(for: block.kind)]).width
            return max(widest, width)
        }
        return max(markerGutterWidth, widestMarker + minimumMarkerTextGap)
    }

    func draggingPreviewImage() -> NSImage {
        let image = NSImage(size: view.bounds.size)
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return image
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        image.addRepresentation(representation)
        return image
    }
}

private extension BlockInputBlockKind {
    var needsVisibleMarkerLane: Bool {
        switch self {
        case .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule:
            return false
        }
    }
}
