import AppKit
import BlockInputKit
import SwiftUI

@MainActor
final class DemoWindowController: NSWindowController {
    private let editorView = BlockInputView()
    private let completionProvider = DemoCompletionProvider()
    private let statusLabel = NSTextField(labelWithString: "")
    private let selectionLabel = NSTextField(labelWithString: "")
    private let completionQueryField = NSTextField(string: "")
    private let completionResultsLabel = NSTextField(wrappingLabelWithString: "")
    private let markdownTextView = NSTextView()
    private let reorderCheckbox = NSButton(checkboxWithTitle: "Reordering", target: nil, action: nil)

    private var store = BlockInputMemoryDocumentStore(document: DemoData.mixedDocument())
    private var undoController = BlockInputUndoController()
    private var latestCompletionSuggestions: [BlockInputCompletionSuggestion] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BlockInputKit Demo"
        window.center()
        super.init(window: window)
        window.contentView = makeContentView()
        configureEditor()
        updateStatus(for: store.document)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func makeContentView() -> NSView {
        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.spacing = 8
        rootStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let bodyStack = NSStackView()
        bodyStack.orientation = .horizontal
        bodyStack.spacing = 12

        editorView.translatesAutoresizingMaskIntoConstraints = false
        editorView.widthAnchor.constraint(greaterThanOrEqualToConstant: 620).isActive = true

        let sidePanel = makeSidePanel()
        sidePanel.widthAnchor.constraint(equalToConstant: 360).isActive = true

        bodyStack.addArrangedSubview(editorView)
        bodyStack.addArrangedSubview(sidePanel)

        rootStack.addArrangedSubview(makeToolbar())
        rootStack.addArrangedSubview(bodyStack)
        rootStack.addArrangedSubview(makeStatusBar())
        return rootStack
    }

    private func makeToolbar() -> NSView {
        reorderCheckbox.state = .on
        reorderCheckbox.target = self
        reorderCheckbox.action = #selector(toggleReordering)

        let toolbar: NSStackView = NSStackView(views: [
            makeButton("Mixed", action: #selector(loadMixedDocument)),
            makeButton("100k", action: #selector(loadLargeDocument)),
            makeButton("Import", action: #selector(importMarkdown)),
            makeButton("Insert Markdown", action: #selector(insertMarkdown)),
            makeButton("Export", action: #selector(exportMarkdown)),
            makeSeparator(),
            makeButton("Undo Text", action: #selector(undoText)),
            makeButton("Redo Text", action: #selector(redoText)),
            makeButton("Undo Structure", action: #selector(undoStructure)),
            makeButton("Redo Structure", action: #selector(redoStructure)),
            makeSeparator(),
            makeButton("Focus First", action: #selector(focusFirstBlock)),
            reorderCheckbox
        ])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.alignment = .centerY
        return toolbar
    }

    private func makeSidePanel() -> NSView {
        let sideStack = NSStackView()
        sideStack.orientation = .vertical
        sideStack.spacing = 10

        completionQueryField.placeholderString = "Completion query"
        completionResultsLabel.maximumNumberOfLines = 8

        let completionButtons = NSStackView(views: [
            makeButton("Mentions", action: #selector(showMentionCompletions)),
            makeButton("Slash", action: #selector(showSlashCompletions)),
            makeButton("Insert First", action: #selector(insertFirstCompletion))
        ])
        completionButtons.orientation = .horizontal
        completionButtons.spacing = 8

        markdownTextView.string = DemoData.markdownSample
        markdownTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        markdownTextView.isRichText = false
        let markdownScrollView = NSScrollView()
        markdownScrollView.borderType = .bezelBorder
        markdownScrollView.hasVerticalScroller = true
        markdownScrollView.documentView = markdownTextView
        markdownScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let swiftUIPreview = NSHostingView(rootView: BlockInputEditor(configuration: BlockInputConfiguration(
            document: DemoData.swiftUIDocument(),
            allowsBlockReordering: false
        )))
        swiftUIPreview.heightAnchor.constraint(equalToConstant: 180).isActive = true

        sideStack.addArrangedSubview(sectionLabel("Completion Provider"))
        sideStack.addArrangedSubview(completionQueryField)
        sideStack.addArrangedSubview(completionButtons)
        sideStack.addArrangedSubview(completionResultsLabel)
        sideStack.addArrangedSubview(sectionLabel("Markdown Import / Export"))
        sideStack.addArrangedSubview(markdownScrollView)
        sideStack.addArrangedSubview(sectionLabel("SwiftUI Wrapper"))
        sideStack.addArrangedSubview(swiftUIPreview)
        return sideStack
    }

    private func makeStatusBar() -> NSView {
        let stack = NSStackView(views: [statusLabel, selectionLabel])
        stack.orientation = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        return stack
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func configureEditor() {
        editorView.configure(BlockInputConfiguration(
            documentStore: store,
            allowsBlockReordering: reorderCheckbox.state == .on,
            undoController: undoController,
            completionProvider: completionProvider,
            onDocumentChange: { [weak self] document in
                self?.updateStatus(for: document)
            },
            onSelectionChange: { [weak self] selection in
                self?.updateSelection(selection)
            }
        ))
    }

    private func replaceDocument(_ document: BlockInputDocument, status: String) {
        store = BlockInputMemoryDocumentStore(document: document)
        undoController = BlockInputUndoController()
        latestCompletionSuggestions = []
        completionResultsLabel.stringValue = ""
        configureEditor()
        updateStatus(for: document, prefix: status)
    }

    private func updateStatus(for document: BlockInputDocument, prefix: String? = nil) {
        let base = "\(document.blocks.count) blocks"
        statusLabel.stringValue = [prefix, base].compactMap { $0 }.joined(separator: " - ")
    }

    private func updateSelection(_ selection: BlockInputSelection?) {
        switch selection {
        case .cursor(let cursor):
            selectionLabel.stringValue = "Cursor: \(cursor.blockID.rawValue) @ \(cursor.utf16Offset)"
        case .text(let range):
            selectionLabel.stringValue = "Text: \(range.blockID.rawValue) \(range.range)"
        case .blocks(let blockIDs):
            selectionLabel.stringValue = "Blocks: \(blockIDs.count)"
        case nil:
            selectionLabel.stringValue = "No selection"
        }
    }

    @objc private func loadMixedDocument() {
        replaceDocument(DemoData.mixedDocument(), status: "Loaded mixed document")
    }

    @objc private func loadLargeDocument() {
        replaceDocument(DemoData.largeDocument(), status: "Loaded 100k document")
    }

    @objc private func importMarkdown() {
        replaceDocument(BlockInputDocument(markdown: markdownTextView.string), status: "Imported Markdown")
    }

    @objc private func insertMarkdown() {
        let selection = editorView.insertMarkdown(markdownTextView.string)
        updateStatus(for: editorView.document, prefix: selection == nil ? "Markdown insert ignored" : "Inserted Markdown")
    }

    @objc private func exportMarkdown() {
        markdownTextView.string = editorView.document.markdown
        updateStatus(for: editorView.document, prefix: "Exported Markdown")
    }

    @objc private func undoText() {
        let result = editorView.undoTextEditInActiveBlock()
        updateStatus(for: editorView.document, prefix: result?.actionName ?? "No text undo")
    }

    @objc private func redoText() {
        let result = editorView.redoTextEditInActiveBlock()
        updateStatus(for: editorView.document, prefix: result?.actionName ?? "No text redo")
    }

    @objc private func undoStructure() {
        let result = editorView.undoStructuralEdit()
        updateStatus(for: editorView.document, prefix: result?.actionName ?? "No structural undo")
    }

    @objc private func redoStructure() {
        let result = editorView.redoStructuralEdit()
        updateStatus(for: editorView.document, prefix: result?.actionName ?? "No structural redo")
    }

    @objc private func focusFirstBlock() {
        guard let firstBlock = editorView.document.blocks.first else {
            return
        }
        editorView.focus(blockID: firstBlock.id, utf16Offset: 0)
    }

    @objc private func toggleReordering() {
        configureEditor()
        updateStatus(for: editorView.document, prefix: reorderCheckbox.state == .on ? "Reordering enabled" : "Reordering disabled")
    }

    @objc private func showMentionCompletions() {
        showCompletions(trigger: .mention)
    }

    @objc private func showSlashCompletions() {
        showCompletions(trigger: .slashCommand)
    }

    private func showCompletions(trigger: BlockInputCompletionTrigger) {
        guard let blockID = editorView.selection?.firstBlockID ?? editorView.document.blocks.first?.id else {
            return
        }
        let context = BlockInputCompletionContext(
            trigger: trigger,
            query: completionQueryField.stringValue,
            document: editorView.document,
            blockID: blockID
        )
        Task { [completionProvider, weak self] in
            let suggestions = await completionProvider.suggestions(for: context)
            await MainActor.run {
                self?.latestCompletionSuggestions = suggestions
                self?.completionResultsLabel.stringValue = suggestions.isEmpty
                    ? "No suggestions"
                    : suggestions.map { "\($0.title) -> \($0.insertionText)" }.joined(separator: "\n")
            }
        }
    }

    @objc private func insertFirstCompletion() {
        guard let suggestion = latestCompletionSuggestions.first else {
            updateStatus(for: editorView.document, prefix: "No completion selected")
            return
        }
        let selection = editorView.acceptCompletionSuggestion(suggestion)
        updateStatus(for: editorView.document, prefix: selection == nil ? "Completion ignored" : "Inserted completion")
    }
}

private extension BlockInputSelection {
    var firstBlockID: BlockInputBlockID? {
        switch self {
        case .cursor(let cursor):
            cursor.blockID
        case .text(let range):
            range.blockID
        case .blocks(let blockIDs):
            blockIDs.first
        }
    }
}
