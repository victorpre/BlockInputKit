import AppKit

final class BlockInputMetadataChipView: NSView {
    enum ChipKind: Equatable {
        case whenDate
        case deadline
        case tag
    }

    private let stackView = NSStackView()
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    var chipKind: ChipKind {
        didSet {
            updateAppearance()
        }
    }

    var chipText: String {
        didSet {
            label.stringValue = chipText
            invalidateIntrinsicContentSize()
        }
    }

    override var isFlipped: Bool { true }

    init(kind: ChipKind, text: String) {
        self.chipKind = kind
        self.chipText = text
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.masksToBounds = true

        stackView.orientation = .horizontal
        stackView.spacing = 3
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 8)
        addSubview(stackView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        stackView.addArrangedSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        switch chipKind {
        case .whenDate:
            iconView.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "When")
        case .deadline:
            iconView.image = NSImage(systemSymbolName: "flag", accessibilityDescription: "Deadline")
        case .tag:
            iconView.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "Tag")
        }
        label.stringValue = chipText
        layer?.backgroundColor = NSColor.controlBackgroundColor.withSystemEffect(.pressed).cgColor
    }

    override var intrinsicContentSize: NSSize {
        let stackSize = stackView.intrinsicContentSize
        return NSSize(width: stackSize.width + 14, height: 18)
    }
}
