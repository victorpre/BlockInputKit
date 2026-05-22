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
    static func imageHeight(
        for image: BlockInputImage,
        textWidth: CGFloat,
        defaultAspectRatio: CGFloat
    ) -> CGFloat {
        let availableWidth = max(textWidth, 120)
        let aspectRatio = max(defaultAspectRatio, 0.01)
        let contentHeight: CGFloat
        if let width = image.width, let height = image.height {
            contentHeight = min(availableWidth, CGFloat(width)) * CGFloat(height) / max(CGFloat(width), 1)
        } else if let height = image.height {
            contentHeight = CGFloat(height)
        } else {
            contentHeight = availableWidth / aspectRatio
        }
        return max(44, ceil(contentHeight)) + (imageExternalVerticalInset * 2)
    }

    func configureImageBlockIfNeeded(for block: BlockInputBlock) {
        imageLoadTask?.cancel()
        guard case let .image(image) = block.kind else {
            imageBlockView.resetForReuse()
            return
        }
        imageBlockView.configurePlaceholder(style: style)
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
        startImageLoad(for: image, resolvedURL: resolvedURL, blockID: block.id)
    }

    private func startImageLoad(
        for image: BlockInputImage,
        resolvedURL: URL,
        blockID: BlockInputBlockID
    ) {
        let cacheKey = image.cacheKey(
            resolvedURL: resolvedURL,
            maximumPixelDimension: imageLoadingContext.maximumPixelDimension
        )
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
                    guard self?.renderedBlock?.id == blockID else {
                        return
                    }
                    guard let nsImage = NSImage(data: loaded.data) else {
                        self?.imageBlockView.configureFailure(style: self?.style ?? .default)
                        return
                    }
                    self?.imageBlockView.configureLoadedImage(
                        nsImage,
                        style: self?.style ?? .default,
                        resizeDimensions: request.image.resizeDimensions
                    )
                }
            } catch {
                await MainActor.run {
                    guard self?.renderedBlock?.id == blockID else {
                        return
                    }
                    self?.imageBlockView.configureFailure(style: self?.style ?? .default)
                }
            }
        }
    }

    private func allowsLoading(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return true
        }
        return imageLoadingContext.allowsRemoteLoading
    }
}

private extension BlockInputImage {
    var resizeDimensions: BlockInputImageDimensions? {
        guard let width, let height else {
            return nil
        }
        return BlockInputImageDimensions(width: width, height: height)
    }
}
