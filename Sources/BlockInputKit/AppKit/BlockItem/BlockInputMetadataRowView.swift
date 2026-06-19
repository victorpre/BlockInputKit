import AppKit

final class BlockInputMetadataRowView: NSView {
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        return stack
    }()
    private var stackViewLeadingConstraint: NSLayoutConstraint?
    private var stackViewTrailingConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    private var stackViewBottomConstraint: NSLayoutConstraint?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        let leading = stackView.leadingAnchor.constraint(equalTo: leadingAnchor)
        let trailing = stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        let top = stackView.topAnchor.constraint(equalTo: topAnchor)
        let bottom = stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        stackViewLeadingConstraint = leading
        stackViewTrailingConstraint = trailing
        stackViewTopConstraint = top
        stackViewBottomConstraint = bottom
        stackView.isHidden = true
    }

    func configure(
        with whenDate: String?,
        deadline: String?,
        tags: [String],
        dateStyle: BlockInputMetadataDateStyle = BlockInputMetadataDateStyle()
    ) {
        if stackView.superview == nil {
            addSubview(stackView)
        }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let whenDate, !whenDate.isEmpty {
            let chip = BlockInputMetadataChipView(kind: .whenDate, text: whenDate)
            chip.dateStyle = dateStyle
            stackView.addArrangedSubview(chip)
        }
        if let deadline, !deadline.isEmpty {
            let chip = BlockInputMetadataChipView(kind: .deadline, text: deadline)
            chip.dateStyle = dateStyle
            stackView.addArrangedSubview(chip)
        }
        for tag in tags where !tag.isEmpty {
            stackView.addArrangedSubview(BlockInputMetadataChipView(kind: .tag, text: tag))
        }

        updateStackViewVisibility(hasContent: !stackView.arrangedSubviews.isEmpty)
        invalidateIntrinsicContentSize()
    }

    private func updateStackViewVisibility(hasContent: Bool) {
        setAccessibilityElement(hasContent)
        stackView.isHidden = !hasContent
        if hasContent {
            if stackView.superview == nil {
                addSubview(stackView)
            }
            NSLayoutConstraint.activate([
                stackViewLeadingConstraint,
                stackViewTrailingConstraint,
                stackViewTopConstraint,
                stackViewBottomConstraint
            ].compactMap { $0 })
        } else {
            NSLayoutConstraint.deactivate([
                stackViewLeadingConstraint,
                stackViewTrailingConstraint,
                stackViewTopConstraint,
                stackViewBottomConstraint
            ].compactMap { $0 })
            stackView.removeFromSuperview()
        }
    }

    var contentMaxX: CGFloat {
        guard !stackView.arrangedSubviews.isEmpty else { return 0 }
        let rightmost = stackView.arrangedSubviews
            .map { $0.convert($0.bounds, to: self).maxX }
            .max() ?? 0
        return rightmost
    }

    func clearChips() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        updateStackViewVisibility(hasContent: false)
    }

    override var intrinsicContentSize: NSSize {
        guard !stackView.arrangedSubviews.isEmpty else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        return NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }
}
