import AppKit
import BlockInputKit

@MainActor
final class DemoWindowController: NSWindowController {
    var sidebarItems = DemoNote.all.map { DemoSidebarItem(id: .builtIn($0.id)) }
    private let splitViewController = NSSplitViewController()
    let sidebarTableView = NSTableView()
    private let noteTitleLabel = NSTextField(labelWithString: "")
    let saveStatusLabel = NSTextField(labelWithString: "")
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
    let rawTextView = NSTextView()
    private let loadingProgress = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "")

    var sessions: [DemoSidebarItemID: DemoNoteSession] = [:]
    private var warmTasks: [DemoNoteID: Task<Void, Never>] = [:]
    var currentItemID: DemoSidebarItemID = .builtIn(.mixed)
    var editorMode: DemoEditorMode = .rendered
    private var allowsReordering = true
    var rawTextItemID: DemoSidebarItemID?
    private var editorConfiguredItemID: DemoSidebarItemID?
    var isApplyingRawText = false

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

        sessions[.builtIn(.mixed)] = DemoNoteSession(note: DemoNote(id: .mixed), document: DemoNoteID.mixed.makeDocument())
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

    var currentSession: DemoNoteSession? {
        sessions[currentItemID]
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

        saveStatusLabel.font = .systemFont(ofSize: 12)
        saveStatusLabel.textColor = .secondaryLabelColor
        saveStatusLabel.lineBreakMode = .byTruncatingTail
        saveStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        reorderCheckbox.state = allowsReordering ? .on : .off
        reorderCheckbox.target = self
        reorderCheckbox.action = #selector(toggleReordering)

        modeControl.segmentStyle = .rounded
        modeControl.selectedSegment = editorMode.segment
        modeControl.target = self
        modeControl.action = #selector(changeEditorMode)
    }

    private func configureContentContainer() {
        [editorView, rawScrollView, loadingProgress, loadingLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview($0)
        }
        loadingProgress.style = .spinning
        loadingProgress.controlSize = .regular
        loadingProgress.isIndeterminate = true
        loadingProgress.isDisplayedWhenStopped = false
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
            loadingLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor, constant: 22),

            loadingProgress.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            loadingProgress.bottomAnchor.constraint(equalTo: loadingLabel.topAnchor, constant: -10)
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

        let strip = NSStackView(views: [noteTitleLabel, saveStatusLabel, spacer, reorderCheckbox, modeControl])
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
        for note in DemoNote.all where sessions[.builtIn(note.id)] == nil {
            startWarmTask(for: note.id)
        }
    }

    private func startWarmTask(for noteID: DemoNoteID) {
        let itemID = DemoSidebarItemID.builtIn(noteID)
        guard sessions[itemID] == nil,
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
        let itemID = DemoSidebarItemID.builtIn(warmState.id)
        guard sessions[itemID] == nil else {
            return
        }
        let session = DemoNoteSession(note: DemoNote(id: warmState.id), warmState: warmState)
        sessions[itemID] = session
        if currentItemID == itemID {
            applySelectedNote(preloadBothViews: false)
        }
    }

    func applySelectedNote(preloadBothViews: Bool) {
        noteTitleLabel.stringValue = currentItemID.title
        guard let session = currentSession else {
            showLoadingState(title: currentItemID.title)
            if case .builtIn(let noteID) = currentItemID {
                startWarmTask(for: noteID)
            }
            return
        }

        switch session.loadingState {
        case .idle:
            loadingLabel.stringValue = ""
            updateSaveStatus(for: session)
        case .loading:
            saveStatusLabel.stringValue = ""
            showLoadingState(title: session.title)
            return
        case .failed(let message):
            saveStatusLabel.stringValue = ""
            showErrorState(message)
            return
        }

        prepareRenderedView(for: session, preload: preloadBothViews)
        if preloadBothViews || editorMode == .raw || rawTextItemID == currentItemID {
            applyRawMarkdown(session.rawMarkdown, to: session)
        }
        if editorMode == .raw {
            prepareRawView(for: session)
        }
        updateVisibleContent(isLoading: false)
    }

    private func showLoadingState(title: String) {
        loadingLabel.stringValue = "Loading \(title)..."
        updateVisibleContent(isLoading: true)
    }

    private func showErrorState(_ message: String) {
        loadingLabel.stringValue = message
        updateVisibleContent(isLoading: true, showsProgress: false)
    }

    private func prepareRenderedView(for session: DemoNoteSession, preload: Bool = false) {
        let hasPendingRawParse = session.pendingRawParseTask != nil
        if preload || editorConfiguredItemID != session.id || session.renderedViewNeedsReload || hasPendingRawParse {
            configureEditor(for: session, markRenderedViewFresh: !hasPendingRawParse)
        }
        if hasPendingRawParse {
            scheduleRawParse(for: session, delay: 0)
        }
    }

    private func prepareRawView(for session: DemoNoteSession) {
        let needsRefresh = session.rawViewNeedsReload
        if rawTextItemID != session.id || needsRefresh {
            applyRawMarkdown(session.rawMarkdown, to: session, markRawViewFresh: !needsRefresh)
        }
        if needsRefresh {
            refreshRawMarkdownFromStore(for: session)
        }
    }

    private func updateVisibleContent(isLoading: Bool, showsProgress: Bool = true) {
        loadingLabel.isHidden = !isLoading
        loadingProgress.isHidden = !isLoading || !showsProgress
        if isLoading && showsProgress {
            loadingProgress.startAnimation(nil)
        } else {
            loadingProgress.stopAnimation(nil)
        }
        editorView.isHidden = isLoading || editorMode != .rendered
        rawScrollView.isHidden = isLoading || editorMode != .raw
        modeControl.selectedSegment = editorMode.segment
        reorderCheckbox.state = allowsReordering ? .on : .off
    }

    func configureEditor(for session: DemoNoteSession, markRenderedViewFresh: Bool = true) {
        editorView.configure(BlockInputConfiguration(
            documentStore: session.store,
            allowsBlockReordering: allowsReordering,
            undoController: session.undoController,
            onDocumentMutation: { [weak self, itemID = session.id] change in
                self?.handleRenderedMutation(change, itemID: itemID)
            },
            onDocumentChange: { [weak self, itemID = session.id] document in
                self?.handleRenderedDocumentChange(document, itemID: itemID)
            }
        ))
        editorConfiguredItemID = session.id
        if markRenderedViewFresh {
            session.renderedViewNeedsReload = false
        }
    }

    private func handleRenderedMutation(_: BlockInputDocumentChange, itemID: DemoSidebarItemID) {
        guard let session = sessions[itemID] else {
            return
        }
        session.documentRevision += 1
        markSessionDirty(session, rawEdit: false)
        session.rawViewNeedsReload = true
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = nil
    }

    private func handleRenderedDocumentChange(_ document: BlockInputDocument, itemID: DemoSidebarItemID) {
        guard let session = sessions[itemID] else {
            return
        }
        let revision = session.documentRevision
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = Task { [weak self, document, itemID, revision] in
            let markdown = await Task.detached(priority: .utility) {
                document.markdown
            }.value
            self?.applyRenderedMarkdown(markdown, itemID: itemID, revision: revision)
        }
    }

    private func applyRenderedMarkdown(_ markdown: String, itemID: DemoSidebarItemID, revision: Int) {
        guard let session = sessions[itemID],
              session.documentRevision == revision else {
            return
        }
        session.rawMarkdown = markdown
        session.rawViewNeedsReload = rawTextItemID != itemID || rawTextView.string != markdown
        session.pendingMarkdownTask = nil
        if currentItemID == itemID,
           editorMode == .raw {
            applyRawMarkdown(markdown, to: session)
        }
    }

    private func refreshRawMarkdownFromStore(for session: DemoNoteSession) {
        let itemID = session.id
        let revision = session.documentRevision
        let store = session.store
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = Task { [weak self, itemID, revision, store] in
            let markdown = await Task.detached(priority: .utility) {
                store.backgroundDocumentSnapshot().markdown
            }.value
            self?.applyRenderedMarkdown(markdown, itemID: itemID, revision: revision)
        }
    }

    private func applyRawMarkdown(_ markdown: String, to session: DemoNoteSession, markRawViewFresh: Bool = true) {
        isApplyingRawText = true
        rawTextView.string = markdown
        isApplyingRawText = false
        rawTextItemID = session.id
        session.rawMarkdown = markdown
        if markRawViewFresh {
            session.rawViewNeedsReload = false
        }
    }

    @objc private func changeEditorMode() {
        guard let mode = DemoEditorMode(segment: modeControl.selectedSegment),
              mode != editorMode else {
            return
        }
        editorMode = mode
        guard let session = currentSession else {
            showLoadingState(title: currentItemID.title)
            return
        }
        switch session.loadingState {
        case .idle:
            break
        case .loading:
            showLoadingState(title: session.title)
            return
        case .failed(let message):
            showErrorState(message)
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
        guard let session = currentSession,
              case .idle = session.loadingState else {
            return
        }
        configureEditor(for: session)
    }
}
