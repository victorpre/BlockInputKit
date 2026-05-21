import AppKit

extension BlockInputBlockItem {
    func configureBlockKindChrome(block: BlockInputBlock) {
        let kind = block.kind
        let isHorizontalRule = kind == .horizontalRule
        let isFrontMatter = kind == .frontMatter
        let contentIndent = Self.contentIndent(for: block)
        let perLineContentIndent = Self.perLineContentIndent(for: block)
        let verticalMetrics = Self.verticalMetrics(for: block)
        textView.textContainerInset = textContainerInset(for: kind, metrics: verticalMetrics)
        textView.isEditable = !isHorizontalRule
        textView.isSelectable = !isHorizontalRule
        configureTextScrolling(for: block)
        applyTextAttributes(for: block)
        scrollView.isHidden = isHorizontalRule
        configureCodeBackground(for: block)
        scrollViewTopConstraint?.constant = 0
        configureFrontMatterDivider(isVisible: isFrontMatter)
        handleTopConstraint?.constant = Self.dragHandleTopConstant(for: block.kind, metrics: verticalMetrics, style: style)
        kindLabelTopConstraint?.constant = 0
        checklistButtonTopConstraint?.constant = verticalMetrics.checklistButtonTopConstant(
            font: Self.font(for: block.kind, style: style),
            checkboxHeight: Self.checklistButtonHeight
        )
        kindLabelLeadingConstraint?.constant = kindLabelLeadingConstant(for: block, contentIndent: contentIndent)
        kindLabelWidthConstraint?.constant = kindLabelWidthConstant(for: block, perLineContentIndent: perLineContentIndent)
        scrollViewLeadingConstraint?.constant = textLeadingConstant(
            for: kind,
            perLineContentIndent: perLineContentIndent
        )
        horizontalRuleLeadingConstraint?.constant = Self.horizontalRuleInnerInset
        quoteBarView.isHidden = kind != .quote || isHorizontalRule
        quoteBarView.alphaValue = quoteBarView.isHidden ? 0 : 1
        horizontalRuleView.setVisible(isHorizontalRule)
        applyKindLabelAttributes(for: block)
        updateQuoteBarVerticalExtent()
        configureChecklistButton(for: block, contentIndent: contentIndent)
    }

    private func configureFrontMatterDivider(isVisible: Bool) {
        scrollViewBottomConstraint?.constant = isVisible
            ? -((Self.frontMatterDividerVerticalInset * 2) + Self.frontMatterDividerHeight)
            : 0
        frontMatterDividerView.isHidden = !isVisible
        frontMatterDividerView.alphaValue = isVisible ? 1 : 0
    }

    private func configureChecklistButton(for block: BlockInputBlock, contentIndent: CGFloat) {
        switch block.kind {
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
            return markerAlignmentLeading() + contentIndent
        case .paragraph, .heading, .code, .horizontalRule, .frontMatter, .table, .rawMarkdown:
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
        return Self.markerGutterWidth(for: block, style: style) + perLineContentIndent
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
        return Self.textScrollViewEdgeInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) - Self.handleTrailingX(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
    }

    private func markerAlignmentLeading() -> CGFloat {
        Self.visualContentInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) - Self.handleTrailingX(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
    }

    func textContainerInset(
        for kind: BlockInputBlockKind,
        metrics: BlockInputBlockItemVerticalMetrics
    ) -> NSSize {
        guard case .code = kind else {
            return metrics.textContainerInset
        }
        return NSSize(
            width: metrics.textContainerInset.width + Self.codeTextHorizontalPadding,
            height: metrics.textContainerInset.height
        )
    }

    static func checklistButtonLeadingConstant(
        indentationLevel: Int,
        rowContentIndent: CGFloat
    ) -> CGFloat {
        checklistButtonBaseLeading + contentIndent(forIndentationLevel: indentationLevel) - rowContentIndent
    }

    static func markerGutterWidth(for block: BlockInputBlock, style: BlockInputStyle = .default) -> CGFloat {
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
            let width = (marker as NSString).size(withAttributes: [.font: font(for: block.kind, style: style)]).width
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
        case .paragraph, .heading, .code, .horizontalRule, .frontMatter, .table, .rawMarkdown:
            return false
        }
    }
}
