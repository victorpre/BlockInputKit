import AppKit

extension BlockInputView {
    var disabledCursorForReadOnly: NSCursor? {
        isEditable ? nil : disabledCursor
    }

    func dismissMutationUIIfNeeded(wasEditable: Bool) {
        guard wasEditable, !isEditable else {
            return
        }
        dismissCompletionPopup()
        dismissLinkModal(restoreFocus: false)
        dismissImageModal(restoreFocus: false)
        cancelFileDropTasks()
        hideDropIndicator()
    }

    func invalidateReadOnlyCursorRects() {
        guard let window else {
            collectionView.needsDisplay = true
            return
        }
        for view in [self, scrollView, collectionView] {
            window.invalidateCursorRects(for: view)
        }
        for item in collectionView.visibleItems().compactMap({ $0 as? BlockInputBlockItem }) {
            item.invalidateCursorRects()
        }
    }

    func addDisabledCursorRectIfNeeded(to view: NSView) {
        guard let cursor = disabledCursorForReadOnly else {
            return
        }
        view.addCursorRect(view.bounds, cursor: cursor)
    }

    func addEditableSurfaceCursorRectIfNeeded(to view: NSView) {
        guard isEditable else {
            return
        }
        view.addCursorRect(view.bounds, cursor: .iBeam)
    }

    @discardableResult
    func focusEditorFromEditableSurfaceClick() -> Bool {
        guard isEditable else {
            return false
        }
        focusEditor()
        return true
    }

    func discardReadOnlyTextChangeIfNeeded(item: BlockInputBlockItem, block: BlockInputBlock) -> Bool {
        guard !isEditable else {
            return false
        }
        configureBlockItem(item, block: block)
        return true
    }
}

extension BlockInputEditorCommand {
    var isMutatingDocument: Bool {
        switch self {
        case .copy, .selectAll:
            return false
        case .undo, .redo, .cut, .paste,
             .bold, .italic, .underline, .strikethrough,
             .insertLink, .removeLink,
             .insertImage, .deleteImage,
             .insertTable, .insertRow, .insertColumn, .deleteRow, .deleteColumn, .deleteTable:
            return true
        }
    }
}
