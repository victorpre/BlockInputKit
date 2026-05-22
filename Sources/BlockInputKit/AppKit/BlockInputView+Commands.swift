import AppKit

extension BlockInputEditorCommand {
    init(_ shortcut: BlockInputUndoShortcut) {
        switch shortcut {
        case .undo:
            self = .undo
        case .redo:
            self = .redo
        }
    }

    init(_ shortcut: BlockInputTextFormattingShortcut) {
        switch shortcut {
        case .bold:
            self = .bold
        case .italic:
            self = .italic
        case .underline:
            self = .underline
        case .strikethrough:
            self = .strikethrough
        }
    }
}

public extension BlockInputView {
    /// Performs a semantic editor command using the current selection or caret as the target.
    @discardableResult
    func performCommand(_ command: BlockInputEditorCommand) -> Bool {
        performCommand(command, context: BlockInputResolvedCommandContext())
    }

    // Returns whether a semantic editor command can currently run.
    // swiftlint:disable:next cyclomatic_complexity
    func canPerformCommand(_ command: BlockInputEditorCommand) -> Bool {
        switch command {
        case .undo:
            return undoController?.canUndo() == true
        case .redo:
            return undoController?.canRedo() == true
        case .selectAll:
            return activeBlockID != nil
        case .copy:
            return canCopyActiveSelection()
        case .cut:
            return canCopyActiveSelection()
        case .paste:
            return canPasteIntoActiveSelection
        case .bold, .italic, .underline, .strikethrough:
            return state(for: command) != .unavailable
        case .insertLink(let payload):
            guard let linkContext = resolvedLinkContext(for: command, context: BlockInputResolvedCommandContext()) else {
                return false
            }
            return canPerformInsertLink(payload, context: linkContext)
        case .removeLink:
            return resolvedLinkContext(for: command, context: BlockInputResolvedCommandContext()) != nil
        case .insertImage(let payload):
            return imageContextForActiveSelection() != nil && canPerformInsertImage(payload)
        case .deleteImage:
            return activeImageDeletionBlockID(context: BlockInputResolvedCommandContext()) != nil
        case .insertTable:
            return activeTableInsertionBlockID(context: BlockInputResolvedCommandContext()) != nil
        case .insertRow, .insertColumn, .deleteRow, .deleteColumn:
            return activeTableCommandTarget(context: BlockInputResolvedCommandContext(), command: command) != nil
        case .deleteTable:
            return activeTableDeletionBlockID(context: BlockInputResolvedCommandContext()) != nil
        }
    }

    /// Returns toggle state for formatting commands and availability for non-toggle commands.
    func state(for command: BlockInputEditorCommand) -> BlockInputEditorCommandState {
        switch command {
        case .bold:
            return textFormattingCommandState(.bold)
        case .italic:
            return textFormattingCommandState(.italic)
        case .underline:
            return textFormattingCommandState(.underline)
        case .strikethrough:
            return textFormattingCommandState(.strikethrough)
        default:
            return canPerformCommand(command) ? .off : .unavailable
        }
    }
}

extension BlockInputView {
    func performKeyboardShortcutCommand(for event: NSEvent) -> Bool {
        guard let command = event.blockInputEditorCommandShortcut else {
            return false
        }
        let performed = performCommand(command)
        return performed || command.consumesKeyboardShortcutWhenUnavailable
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity
    func performCommand(
        _ command: BlockInputEditorCommand,
        context: BlockInputResolvedCommandContext
    ) -> Bool {
        if commandShouldFailForFocusedModal(command) {
            return false
        }
        switch command {
        case .undo:
            return performUndoShortcut(.undo, preferredBlockID: context.preferredBlockID)
        case .redo:
            return performUndoShortcut(.redo, preferredBlockID: context.preferredBlockID)
        case .selectAll:
            return selectAllFromActiveSelection()
        case .copy:
            return copyActiveSelection()
        case .cut:
            return cutActiveSelection()
        case .paste:
            return pasteIntoActiveSelection()
        case .bold:
            return performTextFormattingShortcut(.bold)
        case .italic:
            return performTextFormattingShortcut(.italic)
        case .underline:
            return performTextFormattingShortcut(.underline)
        case .strikethrough:
            return performTextFormattingShortcut(.strikethrough)
        case .insertLink(let payload):
            return performInsertLink(payload, context: context)
        case .removeLink:
            return performRemoveLink(context: context)
        case .insertImage(let payload):
            return performInsertImage(payload, context: context)
        case .deleteImage:
            return performDeleteImage(context: context)
        case .insertTable:
            return activeTableInsertionBlockID(context: context).map { insertTable(after: $0) } ?? false
        case .insertRow:
            guard let target = activeTableCommandTarget(context: context, command: command) else { return false }
            return insertTableBodyRow(blockID: target.blockID, position: target.position)
        case .insertColumn:
            guard let target = activeTableCommandTarget(context: context, command: command) else { return false }
            return insertTableColumn(blockID: target.blockID, position: target.position)
        case .deleteRow:
            guard let target = activeTableCommandTarget(context: context, command: command) else { return false }
            return deleteTableBodyRow(blockID: target.blockID, position: target.position, keepsLastBodyRow: true)
        case .deleteColumn:
            guard let target = activeTableCommandTarget(context: context, command: command) else { return false }
            return deleteTableColumn(blockID: target.blockID, position: target.position)
        case .deleteTable:
            return activeTableDeletionBlockID(context: context).map { deleteTable(blockID: $0) } ?? false
        }
    }
}

private extension BlockInputEditorCommand {
    var consumesKeyboardShortcutWhenUnavailable: Bool {
        switch self {
        case .bold, .italic, .underline, .strikethrough:
            return true
        default:
            return false
        }
    }
}

struct BlockInputResolvedCommandContext {
    var preferredBlockID: BlockInputBlockID?
    var linkContext: BlockInputLinkContext?
    var imageContext: BlockInputImageContext?
    var imageBlockID: BlockInputBlockID?
    var imageIndex: Int?
    var tableContext: BlockInputTableMenuContext?

    init(
        preferredBlockID: BlockInputBlockID? = nil,
        linkContext: BlockInputLinkContext? = nil,
        imageContext: BlockInputImageContext? = nil,
        imageBlockID: BlockInputBlockID? = nil,
        imageIndex: Int? = nil,
        tableContext: BlockInputTableMenuContext? = nil
    ) {
        self.preferredBlockID = preferredBlockID
        self.linkContext = linkContext
        self.imageContext = imageContext
        self.imageBlockID = imageBlockID
        self.imageIndex = imageIndex
        self.tableContext = tableContext
    }
}

private extension BlockInputView {
    var canPasteIntoActiveSelection: Bool {
        switch selection {
        case .cursor, .text:
            return true
        case .blocks, .mixed, nil:
            return false
        }
    }

    func commandShouldFailForFocusedModal(_ command: BlockInputEditorCommand) -> Bool {
        switch command {
        case .insertLink, .insertImage:
            return false
        default:
            return linkModalContainsCurrentResponder() || imageModalContainsCurrentResponder()
        }
    }

    func performInsertLink(
        _ payload: BlockInputInsertLinkCommand,
        context: BlockInputResolvedCommandContext
    ) -> Bool {
        guard let linkContext = resolvedLinkContext(for: .insertLink(payload), context: context) else {
            return false
        }
        if payload.presentation == .modal || payload.urlString == nil {
            showLinkModal(context: linkContext, text: payload.text, urlString: payload.urlString)
            return true
        }
        guard let urlString = payload.urlString,
              let text = resolvedLinkText(payload.text, urlString: urlString, context: linkContext) else {
            return false
        }
        let actionName: String
        if case .edit = linkContext.mode {
            actionName = "Edit Link"
        } else {
            actionName = "Insert Link"
        }
        return applyLinkEdit(context: linkContext, text: text, urlString: urlString, actionName: actionName)
    }

    func canPerformInsertLink(_ payload: BlockInputInsertLinkCommand, context: BlockInputLinkContext) -> Bool {
        guard payload.presentation == .automatic, let urlString = payload.urlString else {
            return true
        }
        guard let text = resolvedLinkText(payload.text, urlString: urlString, context: context),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return BlockInputLinkURL.supportedURL(
            from: urlString,
            allowsCustomSchemes: text.hasPrefix("/"),
            fileBaseURL: fileBaseURL
        ) != nil
    }

    func performRemoveLink(context: BlockInputResolvedCommandContext) -> Bool {
        guard let linkContext = resolvedLinkContext(for: .removeLink, context: context),
              case .edit = linkContext.mode else {
            return false
        }
        return removeLink(context: linkContext)
    }

    func performInsertImage(
        _ payload: BlockInputInsertImageCommand,
        context: BlockInputResolvedCommandContext
    ) -> Bool {
        guard let imageContext = context.imageContext ?? imageContextForActiveSelection() else {
            return false
        }
        if payload.presentation == .modal || payload.source == nil {
            showImageModal(context: imageContext, source: payload.source, altText: payload.altText)
            return true
        }
        guard let source = payload.source.flatMap(BlockInputImageModalView.validImageURLString) else {
            return false
        }
        return insertImage(BlockInputImage(source: source, altText: payload.altText ?? ""), context: imageContext) != nil
    }

    func canPerformInsertImage(_ payload: BlockInputInsertImageCommand) -> Bool {
        payload.presentation != .automatic ||
            payload.source == nil ||
            payload.source.flatMap(BlockInputImageModalView.validImageURLString) != nil
    }

    func performDeleteImage(context: BlockInputResolvedCommandContext) -> Bool {
        guard let blockID = activeImageDeletionBlockID(context: context) else {
            return false
        }
        selectedHorizontalRuleIndex = context.imageIndex ?? index(of: blockID)
        applySelection(.blocks([blockID]), notify: false)
        return deleteSelectedHorizontalRuleForBackspaceOrDelete() != nil
    }

    func resolvedLinkContext(
        for command: BlockInputEditorCommand,
        context: BlockInputResolvedCommandContext
    ) -> BlockInputLinkContext? {
        if let linkContext = context.linkContext {
            return linkContext
        }
        guard let target = activeSourceTarget() else {
            return nil
        }
        let linkContext = linkContext(
            blockID: target.blockID,
            selectedRange: target.range,
            event: nil,
            prefersClickedOffset: false
        )
        guard case .removeLink = command else {
            return linkContext
        }
        guard case .edit = linkContext?.mode else {
            return nil
        }
        return linkContext
    }

    func resolvedLinkText(
        _ providedText: String?,
        urlString: String,
        context: BlockInputLinkContext
    ) -> String? {
        if let providedText {
            return providedText
        }
        guard let block = block(withID: context.blockID) else {
            return nil
        }
        switch context.mode {
        case .create(let range):
            guard range.length > 0 else {
                return urlString
            }
            return linkText(in: block, sourceRange: range)
        case .edit(let linkRange):
            return linkText(in: block, range: linkRange)
        }
    }

    func activeSourceTarget() -> (blockID: BlockInputBlockID, range: NSRange)? {
        guard let blockID = activeBlockID,
              let block = block(withID: blockID) else {
            return nil
        }
        switch selection {
        case let .text(textRange) where textRange.blockID == blockID:
            return (blockID, textRange.range)
        case let .cursor(cursor) where cursor.blockID == blockID:
            return (blockID, NSRange(location: min(cursor.utf16Offset, block.utf16Length), length: 0))
        default:
            guard let item = visibleItem(for: blockID, refreshConfiguration: false) else {
                return (blockID, NSRange(location: block.utf16Length, length: 0))
            }
            return (blockID, item.currentSelectedRange)
        }
    }

    func activeImageDeletionBlockID(context: BlockInputResolvedCommandContext) -> BlockInputBlockID? {
        if let imageBlockID = context.imageBlockID {
            guard block(withID: imageBlockID)?.kind.isImage == true else {
                return nil
            }
            return imageBlockID
        }
        if case .blocks(let blockIDs) = selection,
           blockIDs.count == 1,
           let blockID = blockIDs.first,
           block(withID: blockID)?.kind.isImage == true {
            return blockID
        }
        guard let blockID = activeBlockID,
              block(withID: blockID)?.kind.isImage == true else {
            return nil
        }
        return blockID
    }

    func activeTableInsertionBlockID(context: BlockInputResolvedCommandContext) -> BlockInputBlockID? {
        if let tableContext = context.tableContext {
            guard block(withID: tableContext.blockID)?.kind.allowsTableContextInsertion == true else {
                return nil
            }
            return tableContext.blockID
        }
        guard let blockID = activeBlockID,
              block(withID: blockID)?.kind.allowsTableContextInsertion == true else {
            return nil
        }
        return blockID
    }

    func activeTableDeletionBlockID(context: BlockInputResolvedCommandContext) -> BlockInputBlockID? {
        if let tableContext = context.tableContext {
            guard block(withID: tableContext.blockID)?.kind == .table else {
                return nil
            }
            return tableContext.blockID
        }
        if case .blocks(let blockIDs) = selection,
           blockIDs.count == 1,
           let blockID = blockIDs.first,
           block(withID: blockID)?.kind == .table {
            return blockID
        }
        return activeTableCommandTarget(context: context, command: .deleteTable)?.blockID
    }

    func activeTableCommandTarget(
        context: BlockInputResolvedCommandContext,
        command: BlockInputEditorCommand
    ) -> (blockID: BlockInputBlockID, position: BlockInputTable.CellPosition)? {
        if let tableContext = context.tableContext {
            guard let position = tableContext.position else {
                return nil
            }
            return validatedTableTarget(blockID: tableContext.blockID, position: position, command: command)
        }
        guard let target = activeSourceTarget(),
              let block = block(withID: target.blockID),
              block.kind == .table,
              let table = BlockInputTable(markdown: block.text),
              let position = table.cellPosition(containingSourceRange: target.range) else {
            return nil
        }
        return validatedTableTarget(blockID: target.blockID, position: position, command: command)
    }

    func validatedTableTarget(
        blockID: BlockInputBlockID,
        position: BlockInputTable.CellPosition,
        command: BlockInputEditorCommand
    ) -> (blockID: BlockInputBlockID, position: BlockInputTable.CellPosition)? {
        guard let block = block(withID: blockID),
              block.kind == .table,
              let table = BlockInputTable(markdown: block.text) else {
            return nil
        }
        switch command {
        case .deleteRow:
            guard case .body = position.row, table.bodyRows.count > 1 else { return nil }
        case .deleteColumn:
            guard table.columnCount > 1 else { return nil }
        default:
            break
        }
        return (blockID, position)
    }
}
