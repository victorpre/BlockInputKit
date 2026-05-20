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
    }

    func resetLayoutForReuse() {
        allowsReordering = true
        editorHorizontalInset = BlockInputConfiguration.defaultEditorHorizontalInset
        scrollView.isHidden = false
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
