import AppKit

extension BlockInputView {
    func setupCollectionView() {
        wantsLayer = true
        applyEditorSurfaceStyle()

        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        editorVerticalInset = BlockInputConfiguration.defaultEditorVerticalInset

        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.blockInputView = self
        collectionView.isSelectable = false
        collectionView.register(
            BlockInputBlockItem.self,
            forItemWithIdentifier: BlockInputBlockItem.reuseIdentifier
        )
        collectionView.register(
            BlockInputLoadingItem.self,
            forItemWithIdentifier: BlockInputLoadingItem.reuseIdentifier
        )
        collectionView.registerForDraggedTypes([.blockInputBlockID, .fileURL])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        installSelectionExpansionKeyMonitor()

        setupDropIndicator()
        setupScrollView()
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let imagePreviewConstraints = setupImagePreviewStrip()
        NSLayoutConstraint.activate([
            imagePreviewStripView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imagePreviewStripView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imagePreviewStripView.topAnchor.constraint(equalTo: topAnchor),
            imagePreviewConstraints.height,
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imagePreviewConstraints.scrollTop,
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setupEditorChromeView()
    }

    private func setupDropIndicator() {
        dropIndicatorView.wantsLayer = true
        dropIndicatorView.layer?.cornerRadius = 1
        dropIndicatorView.layer?.zPosition = 10
        updateDropIndicatorColor()
        dropIndicatorView.isHidden = true
        dropIndicatorView.setAccessibilityElement(false)
        collectionView.addSubview(dropIndicatorView, positioned: .above, relativeTo: nil)
        configurePlaceholderLabel()
        collectionView.addSubview(placeholderLabel, positioned: .above, relativeTo: nil)
    }

    private func setupScrollView() {
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.blockInputView = self
        scrollView.documentView = collectionView
        scrollView.onContentBoundsDidChange = { [weak self] in
            self?.handleDocumentScrollContentBoundsChange()
        }
    }

    private func handleDocumentScrollContentBoundsChange() {
        updateCollectionViewWidthForVisibleBounds()
        scheduleProgressivePreloadCheck()
        dismissCompletionPopup()
    }

    private func setupEditorChromeView() {
        editorChromeView.drawsStroke = false
        editorChromeView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(editorChromeView, positioned: .below, relativeTo: imagePreviewStripView)

        editorChromeStrokeOverlayView.drawsFill = false
        // Preserve the previous stroke density while keeping every edge in one overlay layer.
        editorChromeStrokeOverlayView.strokePassCount = 2
        editorChromeStrokeOverlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(editorChromeStrokeOverlayView, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate(chromeConstraints(for: editorChromeView) + chromeConstraints(for: editorChromeStrokeOverlayView))
    }

    private func chromeConstraints(for view: NSView) -> [NSLayoutConstraint] {
        [
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
    }
}
