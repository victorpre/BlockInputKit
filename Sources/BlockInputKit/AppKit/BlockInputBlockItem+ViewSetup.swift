import AppKit

extension BlockInputBlockItem {
    func setupViews() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        setupHandleView()
        setupKindLabel()
        setupChecklistButton()
        setupTextView()
        setupHorizontalRuleView()
        setupQuoteBarView()
        addArrangedSubviews()
        activateLayoutConstraints()
    }

    private func setupHandleView() {
        handleView.font = .systemFont(ofSize: 13, weight: .semibold)
        handleView.alignment = .center
        handleView.textColor = .secondaryLabelColor
        handleView.alphaValue = 0
    }

    private func setupKindLabel() {
        kindLabel.font = .preferredFont(forTextStyle: .body)
        kindLabel.alignment = .right
        kindLabel.textColor = .tertiaryLabelColor
        kindLabel.maximumNumberOfLines = 0
    }

    private func setupChecklistButton() {
        checklistButton.target = self
        checklistButton.action = #selector(requestToggleChecklist)
        checklistButton.isHidden = true
        checklistButton.toolTip = "Toggle checklist item"
        checklistButton.setAccessibilityLabel("Toggle checklist item")
    }

    private func setupTextView() {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = Self.standardTextContainerInset
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = self
    }

    private func setupHorizontalRuleView() {
        horizontalRuleView.blockItem = self
    }

    private func setupQuoteBarView() {
        quoteBarView.wantsLayer = true
        quoteBarView.identifier = Self.quoteBarIdentifier
        quoteBarView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        quoteBarView.layer?.cornerRadius = 1.5
    }

    private func addArrangedSubviews() {
        for subview in [handleView, kindLabel, checklistButton, quoteBarView, scrollView, horizontalRuleView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
    }

    private func activateLayoutConstraints() {
        NSLayoutConstraint.activate(chromeLayoutConstraints() + contentLayoutConstraints())
    }

    private func chromeLayoutConstraints() -> [NSLayoutConstraint] {
        let kindLabelLeadingConstraint = kindLabel.leadingAnchor.constraint(equalTo: handleView.trailingAnchor)
        self.kindLabelLeadingConstraint = kindLabelLeadingConstraint
        let kindLabelWidthConstraint = kindLabel.widthAnchor.constraint(equalToConstant: Self.markerGutterWidth)
        self.kindLabelWidthConstraint = kindLabelWidthConstraint
        let checklistButtonLeadingConstraint = checklistButton.leadingAnchor.constraint(
            equalTo: kindLabel.leadingAnchor,
            constant: Self.checklistButtonBaseLeading
        )
        self.checklistButtonLeadingConstraint = checklistButtonLeadingConstraint
        let handleWidthConstraint = handleView.widthAnchor.constraint(equalToConstant: Self.handleWidth)
        self.handleWidthConstraint = handleWidthConstraint
        let handleTopConstraint = handleView.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: BlockInputBlockItemVerticalMetrics.standard.chromeTopConstant
        )
        self.handleTopConstraint = handleTopConstraint
        let kindLabelTopConstraint = kindLabel.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: BlockInputBlockItemVerticalMetrics.standard.chromeTopConstant
        )
        self.kindLabelTopConstraint = kindLabelTopConstraint
        let checklistButtonTopConstraint = checklistButton.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: BlockInputBlockItemVerticalMetrics.standard.checklistButtonTopConstant(
                font: Self.font(for: .paragraph),
                checkboxHeight: Self.checklistButtonHeight
            )
        )
        self.checklistButtonTopConstraint = checklistButtonTopConstraint
        return [
            handleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            handleTopConstraint,
            handleWidthConstraint,
            kindLabelLeadingConstraint,
            kindLabelTopConstraint,
            kindLabelWidthConstraint,
            checklistButtonLeadingConstraint,
            checklistButtonTopConstraint,
            checklistButton.widthAnchor.constraint(equalToConstant: Self.checklistButtonHeight),
            checklistButton.heightAnchor.constraint(equalToConstant: Self.checklistButtonHeight)
        ]
    }

    private func contentLayoutConstraints() -> [NSLayoutConstraint] {
        let scrollViewLeadingConstraint = scrollView.leadingAnchor.constraint(
            equalTo: kindLabel.trailingAnchor,
            constant: Self.defaultTextLeading
        )
        self.scrollViewLeadingConstraint = scrollViewLeadingConstraint
        let scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: view.topAnchor)
        self.scrollViewTopConstraint = scrollViewTopConstraint
        let scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.scrollViewBottomConstraint = scrollViewBottomConstraint
        let horizontalRuleLeadingConstraint = horizontalRuleView.leadingAnchor.constraint(
            equalTo: scrollView.leadingAnchor,
            constant: Self.defaultTextLeading + 4
        )
        self.horizontalRuleLeadingConstraint = horizontalRuleLeadingConstraint
        let quoteBarLeadingConstraint = quoteBarView.leadingAnchor.constraint(
            equalTo: kindLabel.leadingAnchor,
            constant: Self.chromeFrameAlignmentOffset
        )
        self.quoteBarLeadingConstraint = quoteBarLeadingConstraint
        return [
            quoteBarLeadingConstraint,
            quoteBarView.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            quoteBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -7),
            quoteBarView.widthAnchor.constraint(equalToConstant: 3),
            scrollViewLeadingConstraint,
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollViewTopConstraint,
            scrollViewBottomConstraint,
            horizontalRuleLeadingConstraint,
            horizontalRuleView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -4),
            horizontalRuleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            horizontalRuleView.heightAnchor.constraint(equalToConstant: 8)
        ]
    }
}
