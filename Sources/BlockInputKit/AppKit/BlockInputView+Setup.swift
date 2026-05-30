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

        dropIndicatorView.wantsLayer = true
        dropIndicatorView.layer?.cornerRadius = 1
        dropIndicatorView.layer?.zPosition = 10
        updateDropIndicatorColor()
        dropIndicatorView.isHidden = true
        dropIndicatorView.setAccessibilityElement(false)
        collectionView.addSubview(dropIndicatorView, positioned: .above, relativeTo: nil)
        configurePlaceholderLabel()
        collectionView.addSubview(placeholderLabel, positioned: .above, relativeTo: nil)

        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.blockInputView = self
        scrollView.documentView = collectionView
        scrollView.onContentBoundsDidChange = { [weak self] in
            self?.handleDocumentScrollContentBoundsChange()
        }

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setupEditorChromeView()
    }

    private func handleDocumentScrollContentBoundsChange() {
        updateCollectionViewWidthForVisibleBounds()
        scheduleProgressivePreloadCheck()
        dismissCompletionPopup()
    }

    private func setupEditorChromeView() {
        editorChromeView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(editorChromeView, positioned: .above, relativeTo: scrollView)
        NSLayoutConstraint.activate([
            editorChromeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorChromeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorChromeView.topAnchor.constraint(equalTo: topAnchor),
            editorChromeView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
