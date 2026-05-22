import AppKit

final class BlockInputImageBlockView: NSView {
    private let imageView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configurePlaceholder(style: BlockInputStyle) {
        isHidden = false
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        applySurfaceStyle(style)
    }

    func configureLoadedImage(_ image: NSImage, style: BlockInputStyle) {
        isHidden = false
        imageView.image = image
        imageView.isHidden = false
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        applySurfaceStyle(style)
    }

    func configureFailure(style: BlockInputStyle) {
        isHidden = false
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = "Image failed to load"
        statusLabel.isHidden = false
        applySurfaceStyle(style)
    }

    func resetForReuse() {
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        isHidden = true
        toolTip = nil
        setAccessibilityLabel(nil)
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityRole(.image)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func applySurfaceStyle(_ style: BlockInputStyle) {
        layer?.backgroundColor = (style.imageBlock.placeholderColor ?? NSColor.quaternaryLabelColor.withAlphaComponent(0.28)).cgColor
        layer?.borderColor = (style.imageBlock.borderColor ?? NSColor.separatorColor.withAlphaComponent(0.6)).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = style.imageBlock.cornerRadius ?? 6
    }

    var loadedImageForTesting: NSImage? {
        imageView.image
    }

    var statusTextForTesting: String {
        statusLabel.stringValue
    }
}
