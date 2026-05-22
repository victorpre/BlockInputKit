extension BlockInputView {
    func configureBlockItem(_ item: BlockInputBlockItem, block: BlockInputBlock) {
        item.configure(
            block: block,
            allowsReordering: allowsBlockReordering,
            editorHorizontalInset: editorHorizontalInset,
            accentColor: dropIndicatorColor,
            style: style,
            imageLoadingContext: imageLoadingContext,
            fileBaseURL: fileBaseURL,
            isSelected: isBlockSelected(block.id),
            delegate: self
        )
    }

    var imageLoadingContext: BlockInputImageBlockLoadingContext {
        BlockInputImageBlockLoadingContext(
            loader: imageLoader,
            diskCache: imageDiskCache,
            baseURL: imageBaseURL,
            allowsRemoteLoading: allowsRemoteImageLoading,
            maximumSourceBytes: maximumImageSourceBytes,
            maximumPixelDimension: maximumImagePixelDimension
        )
    }
}
