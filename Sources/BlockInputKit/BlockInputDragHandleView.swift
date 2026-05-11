import AppKit

/// Leading gutter handle that starts block reordering drags after the pointer moves.
final class BlockInputDragHandleView: NSTextField, NSDraggingSource {
    weak var blockItem: BlockInputBlockItem?
    private var mouseDownEvent: NSEvent?

    init() {
        super.init(frame: .zero)
        stringValue = "::"
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        lineBreakMode = .byClipping
        setAccessibilityLabel("Drag to reorder block")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled,
              let mouseDownEvent else {
            return
        }
        blockItem?.beginDraggingHandle(with: mouseDownEvent)
        self.mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}
