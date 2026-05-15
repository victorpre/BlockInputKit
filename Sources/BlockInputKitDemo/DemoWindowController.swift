import AppKit
import BlockInputKit

@MainActor
final class DemoWindowController: NSWindowController {
    private let notes = DemoNote.all
    private let splitViewController = NSSplitViewController()
    private let sidebarTableView = NSTableView()
    private let noteTitleLabel = NSTextField(labelWithString: "")
    private let reorderCheckbox = NSButton(checkboxWithTitle: "Reordering", target: nil, action: nil)
    private let modeControl = NSSegmentedControl(
        labels: DemoEditorMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let contentContainer = NSView()
    private let editorView = BlockInputView()
    private let rawScrollView = NSScrollView()
    private let rawTextView = NSTextView()
    private let loadingLabel = NSTextField(labelWithString: "")

    private var sessions: [DemoNoteID: DemoNoteSession] = [:]
    private var warmTasks: [DemoNoteID: Task<Void, Never>] = [:]
    private var currentNoteID: DemoNoteID = .mixed
    private var editorMode: DemoEditorMode = .rendered
    private var allowsReordering = true
    private var rawTextNoteID: DemoNoteID?
    private var editorConfiguredNoteID: DemoNoteID?
    private var isApplyingRawText = false

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

        sessions[.mixed] = DemoNoteSession(note: DemoNote(id: .mixed), document: DemoNoteID.mixed.makeDocument())
        configureSidebar()
        configureRawTextView()
        configureControls()
        configureContentContainer()
        installSplitView()
        window.contentViewController = splitViewController
        window.minSize = NSSize(width: 860, height: 560)
        window.setContentSize(NSSize(width: 1120, height: 760))
        sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        applySelectedNote(preloadBothViews: true)
        warmRemainingNotesAfterLaunch()
    }

    deinit {
        warmTasks.values.forEach { $0.cancel() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private var currentSession: DemoNoteSession? {
        sessions[currentNoteID]
    }

    private func configureSidebar() {
        let column = NSTableColumn(identifier: sidebarColumnIdentifier)
        column.resizingMask = .autoresizingMask
        sidebarTableView.addTableColumn(column)
        sidebarTableView.headerView = nil
        sidebarTableView.style = .sourceList
        sidebarTableView.rowHeight = 28
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 4)
        sidebarTableView.dataSource = self
        sidebarTableView.delegate = self
        sidebarTableView.allowsEmptySelection = false
    }

    private func configureRawTextView() {
        rawTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        rawTextView.isRichText = false
        rawTextView.isAutomaticQuoteSubstitutionEnabled = false
        rawTextView.isAutomaticDashSubstitutionEnabled = false
        rawTextView.isAutomaticTextReplacementEnabled = false
        rawTextView.isVerticallyResizable = true
        rawTextView.isHorizontallyResizable = false
        rawTextView.autoresizingMask = [.width]
        rawTextView.minSize = NSSize(width: 0, height: 0)
        rawTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        rawTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        rawTextView.textContainer?.widthTracksTextView = true
        rawTextView.delegate = self

        rawScrollView.borderType = .noBorder
        rawScrollView.hasVerticalScroller = true
        rawScrollView.hasHorizontalScroller = false
        rawScrollView.autohidesScrollers = true
        rawScrollView.documentView = rawTextView
    }

    private func configureControls() {
        noteTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        noteTitleLabel.lineBreakMode = .byTruncatingTail

        reorderCheckbox.state = allowsReordering ? .on : .off
        reorderCheckbox.target = self
        reorderCheckbox.action = #selector(toggleReordering)

        modeControl.segmentStyle = .rounded
        modeControl.selectedSegment = editorMode.segment
        modeControl.target = self
        modeControl.action = #selector(changeEditorMode)
    }

    private func configureContentContainer() {
        [editorView, rawScrollView, loadingLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview($0)
        }
        loadingLabel.alignment = .center
        loadingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        loadingLabel.textColor = .secondaryLabelColor

        NSLayoutConstraint.activate([
            editorView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            editorView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            editorView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            rawScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            rawScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rawScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rawScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            loadingLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor)
        ])
        contentContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        contentContainer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 460).isActive = true
    }

    private func installSplitView() {
        let sidebarScrollView = NSScrollView()
        sidebarScrollView.borderType = .noBorder
        sidebarScrollView.drawsBackground = false
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.documentView = sidebarTableView

        let sidebarViewController = NSViewController()
        sidebarViewController.view = sidebarScrollView
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 176
        sidebarItem.maximumThickness = 260
        sidebarItem.canCollapse = false

        let contentViewController = NSViewController()
        contentViewController.view = makeMainContentView()
        contentViewController.preferredContentSize = NSSize(width: 920, height: 760)
        let contentItem = NSSplitViewItem(viewController: contentViewController)
        contentItem.minimumThickness = 560

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
    }

    private func makeMainContentView() -> NSView {
        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.spacing = 0

        rootStack.addArrangedSubview(makeControlStrip())
        rootStack.addArrangedSubview(makeSeparator())
        rootStack.addArrangedSubview(contentContainer)
        return rootStack
    }

    private func makeControlStrip() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let strip = NSStackView(views: [noteTitleLabel, spacer, reorderCheckbox, modeControl])
        strip.orientation = .horizontal
        strip.alignment = .centerY
        strip.spacing = 12
        strip.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        return strip
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func warmRemainingNotesAfterLaunch() {
        for note in notes where sessions[note.id] == nil {
            startWarmTask(for: note.id)
        }
    }

    private func startWarmTask(for noteID: DemoNoteID) {
        guard sessions[noteID] == nil,
              warmTasks[noteID] == nil else {
            return
        }
        warmTasks[noteID] = Task { [weak self] in
            let warmState = await Task.detached(priority: .utility) {
                DemoNoteWarmState.make(for: noteID)
            }.value
            guard !Task.isCancelled else {
                return
            }
            self?.installWarmedSession(warmState)
        }
    }

    private func installWarmedSession(_ warmState: DemoNoteWarmState) {
        warmTasks[warmState.id] = nil
        guard sessions[warmState.id] == nil else {
            return
        }
        let session = DemoNoteSession(note: DemoNote(id: warmState.id), warmState: warmState)
        sessions[warmState.id] = session
        if currentNoteID == warmState.id {
            applySelectedNote(preloadBothViews: false)
        }
    }

    private func applySelectedNote(preloadBothViews: Bool) {
        noteTitleLabel.stringValue = currentNoteID.title
        guard let session = currentSession else {
            showLoadingState(for: currentNoteID)
            startWarmTask(for: currentNoteID)
            return
        }

        loadingLabel.stringValue = ""
        prepareRenderedView(for: session, preload: preloadBothViews)
        if preloadBothViews || editorMode == .raw || rawTextNoteID == currentNoteID {
            applyRawMarkdown(session.rawMarkdown, to: session)
        }
        if editorMode == .raw {
            prepareRawView(for: session)
        }
        updateVisibleContent(isLoading: false)
    }

    private func showLoadingState(for noteID: DemoNoteID) {
        loadingLabel.stringValue = "Loading \(noteID.title)..."
        updateVisibleContent(isLoading: true)
    }

    private func prepareRenderedView(for session: DemoNoteSession, preload: Bool = false) {
        let hasPendingRawParse = session.pendingRawParseTask != nil
        if preload || editorConfiguredNoteID != session.note.id || session.renderedViewNeedsReload || hasPendingRawParse {
            configureEditor(for: session, markRenderedViewFresh: !hasPendingRawParse)
        }
        if hasPendingRawParse {
            scheduleRawParse(for: session, delay: 0)
        }
    }

    private func prepareRawView(for session: DemoNoteSession) {
        let needsRefresh = session.rawViewNeedsReload
        if rawTextNoteID != session.note.id || needsRefresh {
            applyRawMarkdown(session.rawMarkdown, to: session, markRawViewFresh: !needsRefresh)
        }
        if needsRefresh {
            refreshRawMarkdownFromStore(for: session)
        }
    }

    private func updateVisibleContent(isLoading: Bool) {
        loadingLabel.isHidden = !isLoading
        editorView.isHidden = isLoading || editorMode != .rendered
        rawScrollView.isHidden = isLoading || editorMode != .raw
        modeControl.selectedSegment = editorMode.segment
        reorderCheckbox.state = allowsReordering ? .on : .off
    }

    private func configureEditor(for session: DemoNoteSession, markRenderedViewFresh: Bool = true) {
        editorView.configure(BlockInputConfiguration(
            documentStore: session.store,
            allowsBlockReordering: allowsReordering,
            undoController: session.undoController,
            onDocumentMutation: { [weak self, noteID = session.note.id] change in
                self?.handleRenderedMutation(change, noteID: noteID)
            },
            onDocumentChange: { [weak self, noteID = session.note.id] document in
                self?.handleRenderedDocumentChange(document, noteID: noteID)
            }
        ))
        editorConfiguredNoteID = session.note.id
        if markRenderedViewFresh {
            session.renderedViewNeedsReload = false
        }
    }

    private func handleRenderedMutation(_: BlockInputDocumentChange, noteID: DemoNoteID) {
        guard let session = sessions[noteID] else {
            return
        }
        session.documentRevision += 1
        session.rawViewNeedsReload = true
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = nil
    }

    private func handleRenderedDocumentChange(_ document: BlockInputDocument, noteID: DemoNoteID) {
        guard let session = sessions[noteID] else {
            return
        }
        let revision = session.documentRevision
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = Task { [weak self, document, noteID, revision] in
            let markdown = await Task.detached(priority: .utility) {
                document.markdown
            }.value
            self?.applyRenderedMarkdown(markdown, noteID: noteID, revision: revision)
        }
    }

    private func applyRenderedMarkdown(_ markdown: String, noteID: DemoNoteID, revision: Int) {
        guard let session = sessions[noteID],
              session.documentRevision == revision else {
            return
        }
        session.rawMarkdown = markdown
        session.rawViewNeedsReload = rawTextNoteID != noteID || rawTextView.string != markdown
        session.pendingMarkdownTask = nil
        if currentNoteID == noteID,
           editorMode == .raw {
            applyRawMarkdown(markdown, to: session)
        }
    }

    private func refreshRawMarkdownFromStore(for session: DemoNoteSession) {
        let noteID = session.note.id
        let revision = session.documentRevision
        let store = session.store
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = Task { [weak self, noteID, revision, store] in
            let markdown = await Task.detached(priority: .utility) {
                store.backgroundDocumentSnapshot().markdown
            }.value
            self?.applyRenderedMarkdown(markdown, noteID: noteID, revision: revision)
        }
    }

    private func applyRawMarkdown(_ markdown: String, to session: DemoNoteSession, markRawViewFresh: Bool = true) {
        isApplyingRawText = true
        rawTextView.string = markdown
        isApplyingRawText = false
        rawTextNoteID = session.note.id
        session.rawMarkdown = markdown
        if markRawViewFresh {
            session.rawViewNeedsReload = false
        }
    }

    private func handleRawTextDidChange() {
        guard !isApplyingRawText,
              let session = currentSession,
              rawTextNoteID == session.note.id else {
            return
        }
        session.rawMarkdown = rawTextView.string
        session.rawViewNeedsReload = false
        session.renderedViewNeedsReload = true
        session.documentRevision += 1
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = nil
        scheduleRawParse(for: session, delay: 0.35)
    }

    private func scheduleRawParse(for session: DemoNoteSession, delay: TimeInterval) {
        let markdown = session.rawMarkdown
        let noteID = session.note.id
        session.rawParseGeneration += 1
        let generation = session.rawParseGeneration
        session.pendingRawParseTask?.cancel()
        session.pendingRawParseTask = Task { [weak self, markdown, noteID, generation] in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            if nanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else {
                return
            }
            let document = await Task.detached(priority: .userInitiated) {
                BlockInputDocument(markdown: markdown)
            }.value
            self?.applyRawDocument(document, noteID: noteID, generation: generation)
        }
    }

    private func applyRawDocument(_ document: BlockInputDocument, noteID: DemoNoteID, generation: Int) {
        guard let session = sessions[noteID],
              session.rawParseGeneration == generation else {
            return
        }
        session.pendingRawParseTask = nil
        session.store.replaceDocument(document)
        session.undoController = BlockInputUndoController()
        session.renderedViewNeedsReload = true
        if currentNoteID == noteID {
            if editorMode == .rendered {
                configureEditor(for: session)
            }
        }
    }

    @objc private func changeEditorMode() {
        guard let mode = DemoEditorMode(segment: modeControl.selectedSegment),
              mode != editorMode else {
            return
        }
        editorMode = mode
        guard let session = currentSession else {
            showLoadingState(for: currentNoteID)
            return
        }
        switch mode {
        case .raw:
            prepareRawView(for: session)
        case .rendered:
            prepareRenderedView(for: session)
        }
        updateVisibleContent(isLoading: false)
    }

    @objc private func toggleReordering() {
        allowsReordering = reorderCheckbox.state == .on
        guard let session = currentSession else {
            return
        }
        configureEditor(for: session)
    }
}

extension DemoWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        notes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard notes.indices.contains(row) else {
            return nil
        }
        let cell = tableView.makeView(withIdentifier: sidebarCellIdentifier, owner: self) as? NSTableCellView ?? makeSidebarCell()
        cell.textField?.stringValue = notes[row].title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard notes.indices.contains(row) else {
            return
        }
        currentNoteID = notes[row].id
        applySelectedNote(preloadBothViews: false)
    }

    private func makeSidebarCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = sidebarCellIdentifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}

extension DemoWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === rawTextView else {
            return
        }
        handleRawTextDidChange()
    }
}
