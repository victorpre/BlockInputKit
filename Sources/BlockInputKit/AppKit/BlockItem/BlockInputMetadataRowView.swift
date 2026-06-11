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
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(with whenDate: String?, deadline: String?, tags: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let whenDate, !whenDate.isEmpty {
            stackView.addArrangedSubview(BlockInputMetadataChipView(kind: .whenDate, text: whenDate))
        }
        if let deadline, !deadline.isEmpty {
            stackView.addArrangedSubview(BlockInputMetadataChipView(kind: .deadline, text: deadline))
        }
        for tag in tags where !tag.isEmpty {
            stackView.addArrangedSubview(BlockInputMetadataChipView(kind: .tag, text: tag))
        }

        setAccessibilityElement(!stackView.arrangedSubviews.isEmpty)
        invalidateIntrinsicContentSize()
    }

    func clearChips() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        setAccessibilityElement(false)
    }

    override var intrinsicContentSize: NSSize {
        guard !stackView.arrangedSubviews.isEmpty else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        return NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }
}
