import AppKit

extension BlockInputTableView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        updateAppendControlVisibility(for: convert(event.locationInWindow, from: nil))
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredAppendTarget = nil
        updateAppendControlFrames()
        super.mouseExited(with: event)
    }

    func configureAppendButton(_ button: NSButton, action: Selector, label: String) {
        button.title = "+"
        button.bezelStyle = .circular
        button.isBordered = true
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.target = self
        button.action = action
        button.isHidden = true
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(label)
    }

    func updateAppendControlVisibility(for localPoint: NSPoint) {
        guard !chromeView.frame.isEmpty,
              !documentView.frame.isEmpty else {
            hoveredAppendTarget = nil
            updateAppendControlFrames()
            return
        }
        let bottomY = chromeView.frame.minY + documentView.frame.height
        let rightX = rightTableEdgeXInBounds
        let isOverBottom = localPoint.x >= chromeView.frame.minX
            && localPoint.x <= chromeView.frame.maxX
            && abs(localPoint.y - bottomY) <= appendHoverTolerance
        let isOverRight = rightTableEdgeIsVisible
            && abs(localPoint.x - rightX) <= appendHoverTolerance
            && localPoint.y >= chromeView.frame.minY
            && localPoint.y <= bottomY
        hoveredAppendTarget = isOverRight ? .column : (isOverBottom ? .row : nil)
        updateAppendControlFrames()
    }

    func updateAppendControlFrames() {
        let buttonSize = NSSize(width: appendControlSize, height: appendControlSize)
        let bottomY = chromeView.frame.minY + documentView.frame.height
        appendRowButton.frame = NSRect(
            x: chromeView.frame.midX - buttonSize.width / 2,
            y: bottomY - buttonSize.height / 2,
            width: buttonSize.width,
            height: buttonSize.height
        )
        appendColumnButton.frame = NSRect(
            x: rightTableEdgeXInBounds - buttonSize.width / 2,
            y: chromeView.frame.minY + max(documentView.frame.height - buttonSize.height, 0) / 2,
            width: buttonSize.width,
            height: buttonSize.height
        )
        appendRowButton.isHidden = hoveredAppendTarget != .row
        appendColumnButton.isHidden = hoveredAppendTarget != .column || !rightTableEdgeIsVisible
    }

    @objc func appendRowButtonClicked(_ sender: Any?) {
        delegate?.tableViewDidRequestAppendBodyRow(self, from: activeCellPosition)
    }

    @objc func appendColumnButtonClicked(_ sender: Any?) {
        delegate?.tableViewDidRequestAppendColumn(self, from: activeCellPosition)
    }

    var rightTableEdgeXInBounds: CGFloat {
        chromeView.frame.minX + documentView.frame.width - scrollView.contentView.bounds.origin.x
    }

    var rightTableEdgeIsVisible: Bool {
        rightTableEdgeXInBounds >= chromeView.frame.minX - 0.5
            && rightTableEdgeXInBounds <= chromeView.frame.maxX + 0.5
    }
}
