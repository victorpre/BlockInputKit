import AppKit

struct BlockInputImageBlockLoadingContext {
    var loader: any BlockInputImageLoading
    var diskCache: (any BlockInputImageDiskCaching)?
    var baseURL: URL?
    var allowsRemoteLoading: Bool
    var maximumSourceBytes: Int
    var maximumPixelDimension: Int

    init(
        loader: any BlockInputImageLoading = BlockInputDefaultImageLoader(),
        diskCache: (any BlockInputImageDiskCaching)? = nil,
        baseURL: URL? = nil,
        allowsRemoteLoading: Bool = true,
        maximumSourceBytes: Int = 20 * 1024 * 1024,
        maximumPixelDimension: Int = 8_192
    ) {
        self.loader = loader
        self.diskCache = diskCache
        self.baseURL = baseURL
        self.allowsRemoteLoading = allowsRemoteLoading
        self.maximumSourceBytes = maximumSourceBytes
        self.maximumPixelDimension = maximumPixelDimension
    }
}

extension BlockInputBlockItem {
    static let minimumImageDisplayDimension: CGFloat = 24

    static func imageHeight(
        for image: BlockInputImage,
        textWidth: CGFloat,
        defaultAspectRatio: CGFloat
    ) -> CGFloat {
        let contentHeight = imageDisplaySize(
            for: image,
            textWidth: textWidth,
            defaultAspectRatio: defaultAspectRatio
        ).height
        return max(44, ceil(contentHeight)) + (imageExternalVerticalInset * 2)
    }

    static func imageDisplaySize(
        for image: BlockInputImage,
        textWidth: CGFloat,
        defaultAspectRatio: CGFloat
    ) -> NSSize {
        let availableWidth = max(textWidth, 120)
        let aspectRatio = max(defaultAspectRatio, 0.01)
        let sourceWidth: CGFloat
        let sourceHeight: CGFloat
        switch (image.width, image.height) {
        case let (width?, height?):
            sourceWidth = CGFloat(width)
            sourceHeight = CGFloat(height)
        case let (width?, nil):
            sourceWidth = CGFloat(width)
            sourceHeight = sourceWidth / aspectRatio
        case let (nil, height?):
            sourceHeight = CGFloat(height)
            sourceWidth = sourceHeight * aspectRatio
        case (nil, nil):
            sourceWidth = availableWidth
            sourceHeight = availableWidth / aspectRatio
        }
        return constrainedImageDisplaySize(
            width: sourceWidth,
            height: sourceHeight,
            availableWidth: availableWidth
        )
    }

    func configureImageBlockIfNeeded(for block: BlockInputBlock) {
        imageLoadTask?.cancel()
        guard case let .image(image) = block.kind else {
            imageBlockView.resetForReuse()
            return
        }
        imageBlockView.toolTip = image.altText.isEmpty ? image.source : image.altText
        imageBlockView.setAccessibilityLabel(image.altText.isEmpty ? image.source : image.altText)
        imageBlockView.resizeDimensions = image.resizeDimensions
        imageBlockView.onResize = { [weak self] width, height in
            guard let self else {
                return
            }
            self.delegate?.blockItem(self, blockID: block.id, didResizeImageToWidth: width, height: height)
        }
        guard let resolvedURL = image.resolvedURL(relativeTo: imageLoadingContext.baseURL),
              allowsLoading(resolvedURL) else {
            imageBlockView.configureFailure(style: style)
            return
        }
        let cacheKey = image.cacheKey(
            resolvedURL: resolvedURL,
            maximumPixelDimension: imageLoadingContext.maximumPixelDimension
        )
        if imageBlockView.reuseLoadedImage(cacheKey: cacheKey, style: style, resizeDimensions: image.resizeDimensions) {
            return
        }
        imageBlockView.configurePlaceholder(style: style)
        startImageLoad(for: image, resolvedURL: resolvedURL, cacheKey: cacheKey, blockID: block.id)
    }

    private func startImageLoad(
        for image: BlockInputImage,
        resolvedURL: URL,
        cacheKey: String,
        blockID: BlockInputBlockID
    ) {
        let request = BlockInputImageLoadRequest(
            image: image,
            resolvedURL: resolvedURL,
            cacheKey: cacheKey,
            maxSourceBytes: imageLoadingContext.maximumSourceBytes,
            maxPixelDimension: imageLoadingContext.maximumPixelDimension,
            diskCache: imageLoadingContext.diskCache
        )
        let loader = imageLoadingContext.loader
        imageLoadTask = Task { [weak self] in
            do {
                let loaded = try await loader.loadImage(request)
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self?.finishImageLoad(loaded, request: request, blockID: blockID)
                }
            } catch {
                await MainActor.run {
                    self?.finishImageLoadFailure(blockID: blockID)
                }
            }
        }
    }

    private func finishImageLoad(
        _ loaded: BlockInputLoadedImage,
        request: BlockInputImageLoadRequest,
        blockID: BlockInputBlockID
    ) {
        guard renderedBlock?.id == blockID else {
            return
        }
        guard let nsImage = NSImage(data: loaded.data) else {
            imageBlockView.configureFailure(style: style)
            return
        }
        let resolvedDimensions = request.image.resolvedResizeDimensions(using: loaded.dimensions)
        imageBlockView.configureLoadedImage(
            nsImage,
            cacheKey: request.cacheKey,
            style: style,
            resizeDimensions: resolvedDimensions
        )
        if request.image.resizeDimensions != resolvedDimensions {
            delegate?.blockItem(
                self,
                blockID: blockID,
                didResolveImageDimensions: resolvedDimensions
            )
        }
    }

    private func finishImageLoadFailure(blockID: BlockInputBlockID) {
        guard renderedBlock?.id == blockID else {
            return
        }
        imageBlockView.configureFailure(style: style)
    }

    private func allowsLoading(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return true
        }
        return imageLoadingContext.allowsRemoteLoading
    }

    func updateImageBlockLayout(for block: BlockInputBlock) {
        guard case let .image(image) = block.kind else {
            return
        }
        let itemWidth = view.bounds.width > 0 ? view.bounds.width : 0
        let scrollViewWidth = Self.textScrollViewWidth(
            for: itemWidth,
            block: block,
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset,
            style: style
        )
        let textWidth = Self.measuredTextWidth(
            for: itemWidth,
            block: block,
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset,
            style: style
        )
        let displaySize = Self.imageDisplaySize(
            for: image,
            textWidth: textWidth,
            defaultAspectRatio: style.imageBlock.placeholderAspectRatio ?? 16.0 / 9.0
        )
        imageBlockWidthConstraint?.constant = displaySize.width
        imageBlockView.maximumResizeWidth = max(24, Int(max(textWidth, 120).rounded()))
        imageBlockLeadingConstraint?.constant = imageHorizontalOffset(
            displayWidth: displaySize.width,
            contentWidth: textWidth,
            containerWidth: scrollViewWidth
        )
    }

    private func imageHorizontalOffset(displayWidth: CGFloat, contentWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let startInset = Self.imageSurfaceHorizontalInset
        guard view.userInterfaceLayoutDirection == .rightToLeft else {
            return startInset
        }
        let boundedContentWidth = min(contentWidth, max(containerWidth - (2 * startInset), 0))
        return startInset + max(boundedContentWidth - displayWidth, 0)
    }

    private static func constrainedImageDisplaySize(
        width: CGFloat,
        height: CGFloat,
        availableWidth: CGFloat
    ) -> NSSize {
        let safeWidth = max(width, minimumImageDisplayDimension)
        let safeHeight = max(height, minimumImageDisplayDimension)
        let scale = min(availableWidth / safeWidth, 1)
        return NSSize(
            width: ceil(safeWidth * scale),
            height: ceil(safeHeight * scale)
        )
    }
}

private extension BlockInputImage {
    var resizeDimensions: BlockInputImageDimensions? {
        guard let width, let height else {
            return nil
        }
        return BlockInputImageDimensions(width: width, height: height)
    }

    func resolvedResizeDimensions(using naturalDimensions: BlockInputImageDimensions) -> BlockInputImageDimensions {
        switch (width, height) {
        case let (width?, height?):
            return BlockInputImageDimensions(width: width, height: height)
        case let (width?, nil):
            let resolvedHeight = CGFloat(width) * CGFloat(naturalDimensions.height) / CGFloat(naturalDimensions.width)
            return BlockInputImageDimensions(width: width, height: Int(resolvedHeight.rounded()))
        case let (nil, height?):
            let resolvedWidth = CGFloat(height) * CGFloat(naturalDimensions.width) / CGFloat(naturalDimensions.height)
            return BlockInputImageDimensions(width: Int(resolvedWidth.rounded()), height: height)
        case (nil, nil):
            return naturalDimensions
        }
    }
}
