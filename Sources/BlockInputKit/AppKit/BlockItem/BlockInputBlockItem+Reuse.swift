import AppKit

extension BlockInputBlockItem {
    func resetTextForReuse() {
        textView.string = ""
        textView.isEditable = true
        textView.textContainerInset = Self.standardTextContainerInset
        configureWrappingTextScrolling()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.font = Self.font(for: .paragraph)
        textView.hideFileDropCaret()
        style = .default
        fileBaseURL = nil
        imageLoadTask?.cancel()
        imageLoadTask = nil
    }

    func resetLayoutForReuse() {
        allowsReordering = true
        editorHorizontalInset = BlockInputConfiguration.defaultEditorHorizontalInset
        scrollView.isHidden = false
        tableView.resetForReuse()
        imageBlockView.resetForReuse()
        codeBackgroundView.isHidden = true
        codeBackgroundView.alphaValue = 0
        scrollViewLeadingConstraint?.constant = Self.defaultTextLeading
        scrollViewTrailingConstraint?.constant = -Self.horizontalContentTrailingInset(allowsReordering: true)
        scrollViewTopConstraint?.constant = 0
        scrollViewBottomConstraint?.constant = 0
        handleTopConstraint?.constant = Self.dragHandleTopConstant(for: .paragraph, metrics: .standard)
        kindLabelTopConstraint?.constant = 0
        checklistButtonTopConstraint?.constant = BlockInputBlockItemVerticalMetrics.standard.checklistButtonTopConstant(
            font: Self.font(for: .paragraph),
            checkboxHeight: Self.checklistButtonHeight
        )
        quoteBarLeadingConstraint?.constant = Self.chromeFrameAlignmentOffset
        quoteBarTopConstraint?.constant = Self.quoteBarVerticalInset
        quoteBarBottomConstraint?.constant = -Self.quoteBarVerticalInset
        horizontalRuleLeadingConstraint?.constant = Self.horizontalRuleInnerInset
        horizontalRuleTrailingConstraint?.constant = -Self.horizontalRuleTrailingInset(allowsReordering: true)
        frontMatterDividerLeadingConstraint?.constant = Self.horizontalRuleInnerInset
        frontMatterDividerTrailingConstraint?.constant = -Self.horizontalRuleTrailingInset(allowsReordering: true)
        frontMatterDividerBottomConstraint?.constant = -Self.frontMatterDividerVerticalInset
        imageBlockLeadingConstraint?.constant = Self.imageSurfaceHorizontalInset
        imageBlockTrailingConstraint?.constant = -Self.imageSurfaceHorizontalInset
        imageBlockTopConstraint?.constant = Self.imageExternalVerticalInset
        imageBlockBottomConstraint?.constant = -Self.imageExternalVerticalInset
        imageBlockWidthConstraint?.constant = 120
        imageBlockView.maximumResizeWidth = Int.max
    }

    func resetChromeForReuse() {
        quoteBarView.isHidden = true
        quoteBarView.alphaValue = 0
        kindLabel.setMarkerLines([])
        kindLabelLeadingConstraint?.constant = 0
        kindLabelWidthConstraint?.constant = 0
        checklistButton.state = .off
        checklistButton.isHidden = true
        checklistButton.isEnabled = false
        checklistButtonLeadingConstraint?.constant = Self.checklistButtonBaseLeading
        frontMatterDividerView.isHidden = true
        frontMatterDividerView.alphaValue = 0
        handleView.isEnabled = false
        handleView.isHidden = true
        handleView.alphaValue = 0
        handleView.toolTip = nil
        handleLeadingConstraint?.constant = 0
        handleWidthConstraint?.constant = 0
    }
}
