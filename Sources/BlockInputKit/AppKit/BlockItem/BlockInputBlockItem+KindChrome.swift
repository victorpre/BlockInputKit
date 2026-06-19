import AppKit

extension BlockInputBlockItem {
    func configureBlockKindChrome(block: BlockInputBlock) {
        let kind = block.kind
        let isHorizontalRule = kind == .horizontalRule
        let isFrontMatter = kind == .frontMatter
        let usesTableSurface = kind == .table && BlockInputTable(markdown: block.text) != nil
        let usesImageSurface: Bool
        if case .image = kind {
            usesImageSurface = true
        } else {
            usesImageSurface = false
        }
        let hasMetadata = block.whenDate != nil || block.deadline != nil || !block.tags.isEmpty
        let contentIndent = Self.contentIndent(for: block)
        let verticalMetrics = Self.verticalMetrics(for: block, blockVerticalInsetMultiplier: blockVerticalInsetMultiplier)
        textView.textContainerInset = textContainerInset(for: kind, metrics: verticalMetrics)
        textView.isEditable = isEditable && !isHorizontalRule && !usesTableSurface
        textView.isSelectable = !isHorizontalRule && !usesTableSurface
        configureTextScrolling(for: block)
        applyTextAttributes(for: block)
        scrollView.isHidden = isHorizontalRule || usesTableSurface || usesImageSurface
        if usesTableSurface {
            tableView.configure(
                block: block,
                style: style,
                blockVerticalInsetMultiplier: blockVerticalInsetMultiplier
            )
        } else {
            tableView.resetForReuse()
        }
        configureImageSurfaceVisibility(usesImageSurface)
        configureImageBlockIfNeeded(for: block)
        configureCodeBackground(for: block)
        scrollViewTopConstraint?.constant = 0
        applyScaledSurfaceInsets()
        configureFrontMatterDivider(isVisible: isFrontMatter)
        handleTopConstraint?.constant = Self.dragHandleTopConstant(for: block.kind, metrics: verticalMetrics, style: style)
        kindLabelTopConstraint?.constant = 0
        checklistButtonTopConstraint?.constant = verticalMetrics.checklistButtonTopConstant(
            font: Self.font(for: block.kind, style: style),
            checkboxHeight: Self.checklistButtonHeight
        )
        horizontalRuleLeadingConstraint?.constant = Self.horizontalRuleInnerInset
        quoteBarView.isHidden = kind != .quote || isHorizontalRule
        quoteBarView.alphaValue = quoteBarView.isHidden ? 0 : 1
        horizontalRuleView.setVisible(isHorizontalRule)
        applyKindLabelAttributes(for: block)
        updateHorizontalConstraints(for: block)
        updateQuoteBarVerticalExtent()
        configureChecklistButton(for: block, contentIndent: contentIndent)
        configureMetadataRow(for: block, hasMetadata: hasMetadata, isMounted: isMountedForLayout)
        configureDetailButton(for: block, hasMetadata: hasMetadata, isMounted: isMountedForLayout)
        updateOptionalSurfaceConstraints(
            usesTableSurface: usesTableSurface,
            usesImageSurface: usesImageSurface,
            isMounted: isMountedForLayout,
            block: block
        )
        updateImageBlockLayout(for: block)
    }

    private func applyScaledSurfaceInsets() {
        tableViewTopConstraint?.constant = Self.scaledTableExternalVerticalInset(for: blockVerticalInsetMultiplier)
        tableViewBottomConstraint?.constant = -Self.scaledTableExternalVerticalInset(for: blockVerticalInsetMultiplier)
        imageBlockTopConstraint?.constant = Self.scaledImageExternalVerticalInset(for: blockVerticalInsetMultiplier)
        imageBlockBottomConstraint?.constant = -Self.scaledImageExternalVerticalInset(for: blockVerticalInsetMultiplier)
    }

    private func configureImageSurfaceVisibility(_ usesImageSurface: Bool) {
        imageBlockView.isHidden = !usesImageSurface
        if !usesImageSurface {
            setImageCaretOffset(nil)
        }
    }

    private func configureFrontMatterDivider(isVisible: Bool) {
        scrollViewBottomConstraint?.constant = isVisible
            ? -((Self.scaledFrontMatterDividerVerticalInset(for: blockVerticalInsetMultiplier) * 2) + Self.frontMatterDividerHeight)
            : 0
        frontMatterDividerBottomConstraint?.constant = -Self.scaledFrontMatterDividerVerticalInset(for: blockVerticalInsetMultiplier)
        frontMatterDividerView.isHidden = !isVisible
        frontMatterDividerView.alphaValue = isVisible
            ? BlockInputReadOnlyStyle.alpha(isEditable: isEditable, readOnly: BlockInputReadOnlyStyle.chromeAlpha)
            : 0
    }

    private func configureChecklistButton(for block: BlockInputBlock, contentIndent: CGFloat) {
        switch block.kind {
        case let .checklistItem(isChecked):
            checklistButton.isHidden = false
            checklistButton.isEnabled = isEditable
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

    private func configureMetadataRow(for block: BlockInputBlock, hasMetadata: Bool, isMounted: Bool) {
        let isChecklist: Bool
        if case .checklistItem = block.kind { isChecklist = true } else { isChecklist = false }
        let shouldShow = isChecklist && hasMetadata && isMounted

        if isChecklist && hasMetadata {
            metadataRowView.configure(with: block.whenDate, deadline: block.deadline, tags: block.tags, dateStyle: style.metadataDate)
        } else {
            metadataRowView.clearChips()
        }
        metadataRowView.isHidden = !shouldShow

        let metadataReserve = Self.metadataRowTopInset + Self.metadataRowMinimumHeight + Self.metadataRowBottomInset
        scrollViewBottomConstraint?.constant = shouldShow ? -metadataReserve : 0
        metadataRowHeightConstraint?.constant = shouldShow ? Self.metadataRowMinimumHeight : 0
        let metadataConstraints = [
            metadataRowLeadingConstraint,
            metadataRowTrailingConstraint,
            metadataRowTopConstraint,
            metadataRowHeightConstraint
        ].compactMap { $0 }
        if shouldShow {
            NSLayoutConstraint.activate(metadataConstraints)
        } else {
            NSLayoutConstraint.deactivate(metadataConstraints)
        }
    }

    private func configureDetailButton(for block: BlockInputBlock, hasMetadata: Bool, isMounted: Bool) {
        let isChecklist: Bool
        if case .checklistItem = block.kind { isChecklist = true } else { isChecklist = false }
        let shouldShow = isChecklist && isEditable && isMounted && hasMetadata
        detailButton.isHidden = !shouldShow
        let detailButtonConstraints = [
            detailButtonLeadingConstraint,
            detailButtonTopConstraint,
            detailButtonWidthConstraint,
            detailButtonHeightConstraint,
            detailButtonTrailingConstraint
        ].compactMap { $0 }
        if shouldShow {
            NSLayoutConstraint.activate(detailButtonConstraints)
            detailButton.alphaValue = 0
            let firstLine = block.text.components(separatedBy: .newlines).first ?? ""
            let font = Self.font(for: block.kind, style: style)
            let firstLineWidth = (firstLine as NSString).size(withAttributes: [.font: font]).width
            let newOffset = Self.textContainerContentLeading + ceil(firstLineWidth) + 6
            guard abs(newOffset - lastComputedDetailButtonOffset) > 0.5 else { return }
            lastComputedDetailButtonOffset = newOffset
            detailButtonLeadingConstraint?.constant = newOffset
            view.window?.invalidateCursorRects(for: view)
            return
        }
        NSLayoutConstraint.deactivate(detailButtonConstraints)
    }

    private func updateOptionalSurfaceConstraints(
        usesTableSurface: Bool,
        usesImageSurface: Bool,
        isMounted: Bool,
        block: BlockInputBlock
    ) {
        let tableConstraints = [
            tableViewLeadingConstraint,
            tableViewTrailingConstraint,
            tableViewTopConstraint,
            tableViewBottomConstraint
        ].compactMap { $0 }
        if usesTableSurface && isMounted {
            NSLayoutConstraint.activate(tableConstraints)
        } else {
            NSLayoutConstraint.deactivate(tableConstraints)
        }

        let imageConstraints = [
            imageBlockLeadingConstraint,
            imageBlockTrailingConstraint,
            imageBlockWidthConstraint,
            imageBlockTopConstraint,
            imageBlockBottomConstraint
        ].compactMap { $0 }
        if usesImageSurface && isMounted {
            NSLayoutConstraint.activate(imageConstraints)
        } else {
            NSLayoutConstraint.deactivate(imageConstraints)
        }

        if isMounted {
            metadataRowView.setAccessibilityElement(true)
        }
        if usesTableSurface {
            tableView.isHidden = false
        }
        if usesImageSurface {
            imageBlockView.isHidden = false
        }
        if block.kind == .table {
            tableView.needsLayout = true
        }
        if case .image = block.kind {
            imageBlockView.needsLayout = true
        }
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
        case .paragraph, .heading, .code, .horizontalRule, .frontMatter, .table, .image, .rawMarkdown:
            return false
        }
    }
}
