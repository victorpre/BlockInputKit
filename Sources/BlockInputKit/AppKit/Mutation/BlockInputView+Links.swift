import AppKit

/// Captures the source location a link popover or paste operation is allowed to mutate.
struct BlockInputLinkContext: Equatable {
    enum Mode: Equatable {
        /// Wrap or replace this source range with new Markdown link source.
        case create(NSRange)
        /// Replace this already-parsed Markdown link, after confirming the same link is still present.
        case edit(BlockInputInlineMarkdownRange)
    }

    let blockID: BlockInputBlockID
    let mode: Mode
    let sourceRange: NSRange
    /// Snapshot of the block text when the context was created, used to fail closed if a modal action becomes stale.
    let sourceText: String
    let anchorWindowRect: NSRect
}

extension BlockInputView {
    /// Hook used by link interactions so URL opening can be replaced in tests.
    typealias BlockInputURLOpener = (URL) -> Bool

    /// Builds the immutable source context for link UI and paste actions.
    func linkContext(
        blockID: BlockInputBlockID,
        selectedRange: NSRange,
        event: NSEvent?,
        prefersClickedOffset: Bool
    ) -> BlockInputLinkContext? {
        guard let block = block(withID: blockID),
              BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind) else {
            return nil
        }
        let item = visibleItem(for: blockID, refreshConfiguration: false)
        let clickedOffset: Int?
        if let event,
           let item {
            clickedOffset = item.utf16Offset(atWindowLocation: event.locationInWindow)
        } else {
            clickedOffset = nil
        }

        let range = linkInsertionRange(
            selectedRange: selectedRange,
            clickedOffset: clickedOffset,
            prefersClickedOffset: prefersClickedOffset
        )
        let linkLookupRange = prefersClickedOffset && clickedOffset != nil
            ? NSRange(location: clickedOffset ?? range.location, length: 0)
            : range
        if let linkRange = linkRange(in: block.text, containing: linkLookupRange) {
            let anchorRect = item?.anchorWindowRect(forUTF16Range: linkRange.contentRange) ?? .zero
            return BlockInputLinkContext(
                blockID: blockID,
                mode: .edit(linkRange),
                sourceRange: range,
                sourceText: block.text,
                anchorWindowRect: anchorRect
            )
        }
        let anchorRect = item?.anchorWindowRect(forUTF16Range: range) ?? .zero
        return BlockInputLinkContext(
            blockID: blockID,
            mode: .create(range),
            sourceRange: range,
            sourceText: block.text,
            anchorWindowRect: anchorRect
        )
    }

    func linkContextForActiveSelection(urlPasteSelectedRangeOverride: NSRange? = nil) -> BlockInputLinkContext? {
        switch selection {
        case let .cursor(cursor):
            let range = urlPasteSelectedRangeOverride ?? NSRange(location: cursor.utf16Offset, length: 0)
            return linkContext(blockID: cursor.blockID, selectedRange: range, event: nil, prefersClickedOffset: false)
        case let .text(textRange):
            let range = urlPasteSelectedRangeOverride ?? textRange.range
            return linkContext(blockID: textRange.blockID, selectedRange: range, event: nil, prefersClickedOffset: false)
        case .blocks, .mixed, nil:
            return nil
        }
    }

    func linkContextMenuItems(for event: NSEvent) -> [NSMenuItem] {
        let collectionLocation = collectionView.convert(event.locationInWindow, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: collectionLocation),
              let item = collectionView.item(at: indexPath) as? BlockInputBlockItem else {
            return []
        }
        return item.linkContextMenuItems(for: event, selectedRange: item.currentSelectedRange)
    }

    func linkContextMenuItems(blockID: BlockInputBlockID, selectedRange: NSRange, event: NSEvent) -> [NSMenuItem] {
        guard let context = linkContext(
            blockID: blockID,
            selectedRange: selectedRange,
            event: event,
            prefersClickedOffset: true
        ) else {
            return []
        }
        let insertItem = NSMenuItem(title: "Insert Link", action: #selector(blockInputInsertLinkFromMenu(_:)), keyEquivalent: "")
        insertItem.target = self
        insertItem.representedObject = context
        guard case .edit = context.mode,
              context.sourceRange.length == 0 else {
            return [insertItem]
        }
        let removeItem = NSMenuItem(title: "Remove Link", action: #selector(blockInputRemoveLinkFromMenu(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = context
        return [insertItem, removeItem]
    }

    @objc(blockInputInsertLinkFromMenu:)
    func blockInputInsertLinkFromMenu(_ sender: Any?) {
        guard let context = (sender as? NSMenuItem)?.representedObject as? BlockInputLinkContext else {
            return
        }
        showLinkModal(context: context)
    }

    @objc(blockInputRemoveLinkFromMenu:)
    func blockInputRemoveLinkFromMenu(_ sender: Any?) {
        guard let context = (sender as? NSMenuItem)?.representedObject as? BlockInputLinkContext else {
            return
        }
        _ = removeLink(context: context)
        dismissLinkModal(restoreFocus: false)
    }

    func handleLinkClick(blockID: BlockInputBlockID, selectedRange: NSRange, event: NSEvent) -> Bool {
        guard let context = linkContext(
            blockID: blockID,
            selectedRange: selectedRange,
            event: event,
            prefersClickedOffset: true
        ),
              case let .edit(linkRange) = context.mode,
              let destination = linkRange.linkDestination else {
            return false
        }
        if event.modifierFlags.contains(.command) {
            return linkURLOpener(destination)
        }
        showLinkModal(context: context)
        return true
    }

    /// Presents the single editor-owned link modal and binds its actions to the captured source context.
    func showLinkModal(context: BlockInputLinkContext) {
        guard let block = block(withID: context.blockID) else {
            return
        }
        dismissLinkModal(restoreFocus: false)
        let modal = BlockInputLinkModalView()
        let mode: BlockInputLinkModalMode
        let text: String
        let urlString: String
        switch context.mode {
        case .create(let range):
            mode = .create
            text = range.length > 0 ? (block.text as NSString).substring(with: block.text.blockInputLinkClampedRange(range)) : ""
            urlString = ""
        case .edit(let linkRange):
            mode = .edit
            text = linkText(in: block.text, range: linkRange)
            urlString = linkRange.linkDestination?.absoluteString ?? ""
        }
        modal.configure(mode: mode, text: text, urlString: urlString)
        configureLinkModalActions(modal, context: context, mode: mode)
        linkModalView = modal
        linkModalContext = context
        addSubview(modal)
        positionLinkModal(modal, anchoredTo: context.anchorWindowRect)
        installLinkModalDismissalMonitors()
        modal.focusInitialField()
    }

    private func configureLinkModalActions(
        _ modal: BlockInputLinkModalView,
        context: BlockInputLinkContext,
        mode: BlockInputLinkModalMode
    ) {
        modal.onSave = { [weak self] text, urlString in
            guard let self else { return }
            guard applyLinkEdit(
                context: context,
                text: text,
                urlString: urlString,
                actionName: mode == .create ? "Insert Link" : "Edit Link"
            ) else {
                dismissLinkModal(restoreFocus: false)
                return
            }
            dismissLinkModal(restoreFocus: false)
        }
        modal.onRemove = { [weak self] in
            guard let self else { return }
            _ = removeLink(context: context)
            dismissLinkModal(restoreFocus: false)
        }
        modal.onOpen = { [weak self] urlString in
            guard let self, let url = BlockInputLinkURL.supportedURL(from: urlString) else { return }
            _ = linkURLOpener(url)
        }
        modal.onCancel = { [weak self] in
            self?.dismissLinkModal(restoreFocus: true)
        }
        modal.onFocusCheck = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.dismissLinkModalIfFocusMovedOutside()
            }
        }
    }

    func dismissLinkModal(restoreFocus: Bool) {
        let context = linkModalContext
        removeLinkModalDismissalMonitors()
        linkModalView?.removeFromSuperview()
        linkModalView = nil
        linkModalContext = nil
        guard restoreFocus,
              let context,
              let block = block(withID: context.blockID) else {
            return
        }
        switch context.mode {
        case .create(let range):
            if range.length > 0 {
                let clampedRange = block.text.blockInputLinkClampedRange(range)
                applySelection(.text(BlockInputTextRange(blockID: context.blockID, range: clampedRange)), notify: true)
                restoreVisibleSelection()
            } else {
                focus(blockID: context.blockID, utf16Offset: min(NSMaxRange(range), block.utf16Length))
            }
        case .edit(let linkRange):
            let clampedRange = block.text.blockInputLinkClampedRange(linkRange.contentRange)
            applySelection(.text(BlockInputTextRange(blockID: context.blockID, range: clampedRange)), notify: true)
            restoreVisibleSelection()
        }
    }

    func dismissLinkModalIfSelectionMovedOutside(_ newSelection: BlockInputSelection?) {
        guard let context = linkModalContext,
              !context.contains(selection: newSelection) else {
            return
        }
        dismissLinkModal(restoreFocus: false)
    }

    func dismissLinkModalIfFocusMovedOutside() {
        guard let modal = linkModalView else {
            return
        }
        guard let firstResponder = window?.firstResponder else {
            dismissLinkModal(restoreFocus: false)
            return
        }
        guard !modal.containsResponder(firstResponder) else {
            return
        }
        dismissLinkModal(restoreFocus: false)
    }

    /// Closes the editor-owned link modal when a mouse interaction would move focus outside it.
    func dismissLinkModalIfMouseDownMovedFocusOutside(_ event: NSEvent) {
        guard let modal = linkModalView,
              event.windowNumber == window?.windowNumber else {
            return
        }
        let locationInModal = modal.convert(event.locationInWindow, from: nil)
        guard !modal.bounds.contains(locationInModal) else {
            return
        }
        dismissLinkModal(restoreFocus: false)
    }

    func installLinkModalDismissalMonitors() {
        removeLinkModalDismissalMonitors()
        linkModalMouseDownMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.dismissLinkModalIfMouseDownMovedFocusOutside(event)
            return event
        }
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(blockInputLinkModalWindowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
    }

    func removeLinkModalDismissalMonitors() {
        if let linkModalMouseDownMonitor {
            NSEvent.removeMonitor(linkModalMouseDownMonitor)
            self.linkModalMouseDownMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
    }

    @objc(blockInputLinkModalWindowDidResignKey:)
    func blockInputLinkModalWindowDidResignKey(_ notification: Notification) {
        dismissLinkModal(restoreFocus: false)
    }

    /// Positions the modal near the clicked link or caret while keeping it inside the editor bounds.
    private func positionLinkModal(_ modal: BlockInputLinkModalView, anchoredTo windowRect: NSRect) {
        let anchor = convert(windowRect.origin, from: nil)
        let modalSize = modal.fittingSize == .zero ? modal.frame.size : modal.fittingSize
        let width = max(modalSize.width, 300)
        let height = max(modalSize.height, 148)
        let modalOriginX = min(max(anchor.x - 12, bounds.minX + 12), max(bounds.minX + 12, bounds.maxX - width - 12))
        let preferredY = anchor.y - height - 8
        let modalOriginY = preferredY >= bounds.minY + 12
            ? preferredY
            : min(max(anchor.y + 18, bounds.minY + 12), max(bounds.minY + 12, bounds.maxY - height - 12))
        modal.frame = NSRect(x: modalOriginX, y: modalOriginY, width: width, height: height)
    }

    /// Handles supported URL paste by editing an existing link or inserting Markdown without selecting the result.
    @discardableResult
    func pasteURLString(_ urlString: String, selectedRange: NSRange? = nil) -> Bool {
        guard BlockInputLinkURL.supportedURL(from: urlString) != nil,
              let context = linkContextForActiveSelection(urlPasteSelectedRangeOverride: selectedRange),
              let block = block(withID: context.blockID) else {
            return false
        }
        switch context.mode {
        case .edit(let linkRange):
            return applyLinkEdit(
                context: context,
                text: linkText(in: block.text, range: linkRange),
                urlString: urlString,
                actionName: "Edit Link",
                selectsResultingText: false
            )
        case .create(let range):
            let label: String
            if range.length > 0 {
                label = (block.text as NSString).substring(with: block.text.blockInputLinkClampedRange(range))
            } else {
                label = urlString
            }
            return applyLinkEdit(
                context: context,
                text: label,
                urlString: urlString,
                actionName: "Insert Link",
                selectsResultingText: false
            )
        }
    }

    @discardableResult
    func applyLinkEdit(
        context: BlockInputLinkContext,
        text: String,
        urlString: String,
        actionName: String,
        selectsResultingText: Bool = true
    ) -> Bool {
        guard let destination = BlockInputLinkURL.supportedURL(from: urlString),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = index(of: context.blockID),
              var block = block(at: index) else {
            return false
        }
        let escapedLabel = BlockInputLinkURL.escapedLabel(text)
        let replacement = BlockInputLinkReplacement(
            text: BlockInputLinkURL.markdownLink(escapedLabel: escapedLabel, destination: destination.absoluteString),
            selectedUTF16Length: (escapedLabel as NSString).length,
            selectsResultingText: selectsResultingText,
            actionName: actionName
        )
        return replaceLinkSource(context: context, block: &block, index: index, replacement: replacement)
    }

    @discardableResult
    func removeLink(context: BlockInputLinkContext) -> Bool {
        guard case .edit(let linkRange) = context.mode,
              let index = index(of: context.blockID),
              var block = block(at: index) else {
            return false
        }
        let text = linkText(in: block.text, range: linkRange)
        let replacement = BlockInputLinkReplacement(
            text: text,
            selectedUTF16Length: (text as NSString).length,
            selectsResultingText: true,
            actionName: "Remove Link"
        )
        return replaceLinkSource(context: context, block: &block, index: index, replacement: replacement)
    }

    func linkRange(in text: String, containing range: NSRange) -> BlockInputInlineMarkdownRange? {
        let clampedRange = text.blockInputLinkClampedRange(range)
        return BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: text,
            excluding: BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        )
        .filter { $0.style == .link }
        .first { linkRange in
            if clampedRange.length == 0 {
                if linkRange.linkDestination?.isFileURL == true {
                    return linkRange.fullRange.location <= clampedRange.location &&
                        clampedRange.location < NSMaxRange(linkRange.fullRange)
                }
                return linkRange.contentRange.containsOrTouches(clampedRange.location)
            }
            return linkRange.contentRange.intersectionLength(with: clampedRange) > 0 ||
                linkRange.fullRange.intersectionLength(with: clampedRange) == clampedRange.length
        }
    }

    func linkText(in text: String, range: BlockInputInlineMarkdownRange) -> String {
        (text as NSString).substring(with: text.blockInputLinkClampedRange(range.contentRange)).blockInputUnescapedLinkLabel
    }

    private func replaceLinkSource(
        context: BlockInputLinkContext,
        block: inout BlockInputBlock,
        index: Int,
        replacement: BlockInputLinkReplacement
    ) -> Bool {
        let beforeBlock = block
        let beforeSelection = selection
        // Modal actions fail closed if typing, undo, or another edit changed the backing text while the modal was open.
        guard block.text == context.sourceText else {
            return false
        }
        let replacementRange: NSRange
        switch context.mode {
        case .create(let range):
            replacementRange = block.text.blockInputLinkClampedRange(range)
        case .edit(let existingLinkRange):
            guard existingLinkRange == linkRange(in: block.text, containing: existingLinkRange.contentRange) else {
                return false
            }
            replacementRange = block.text.blockInputLinkClampedRange(existingLinkRange.fullRange)
        }
        let mutableText = NSMutableString(string: block.text)
        mutableText.replaceCharacters(in: replacementRange, with: replacement.text)
        block.text = mutableText as String
        let contentOffset: Int
        if replacement.actionName == "Remove Link" {
            contentOffset = replacementRange.location
        } else {
            contentOffset = replacementRange.location + 1
        }
        let afterSelection: BlockInputSelection
        if replacement.selectsResultingText {
            afterSelection = .text(BlockInputTextRange(
                blockID: block.id,
                range: NSRange(location: contentOffset, length: replacement.selectedUTF16Length)
            ))
        } else {
            // Pasted URL links should behave like normal paste: the caret lands after the inserted Markdown.
            let cursorOffset = replacementRange.location + (replacement.text as NSString).length
            afterSelection = .cursor(BlockInputCursor(blockID: block.id, utf16Offset: cursorOffset))
        }
        _ = applyGranularBlockReplacement(block, at: index, selection: afterSelection)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: replacement.actionName,
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        return true
    }

    private func linkInsertionRange(
        selectedRange: NSRange,
        clickedOffset: Int?,
        prefersClickedOffset: Bool
    ) -> NSRange {
        guard prefersClickedOffset,
              let clickedOffset,
              !selectedRange.containsOrTouches(clickedOffset) else {
            return selectedRange
        }
        return NSRange(location: clickedOffset, length: 0)
    }
}

/// Replacement payload used by link mutations to keep source text and resulting selection decisions together.
private struct BlockInputLinkReplacement {
    var text: String
    var selectedUTF16Length: Int
    var selectsResultingText: Bool
    var actionName: String
}
