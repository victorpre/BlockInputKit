extension BlockInputView {
    func configureBlockItem(_ item: BlockInputBlockItem, block: BlockInputBlock) {
        item.configure(
            block: block,
            allowsReordering: allowsBlockReordering,
            editorHorizontalInset: editorHorizontalInset,
            accentColor: dropIndicatorColor,
            style: style,
            isSelected: isBlockSelected(block.id),
            delegate: self
        )
    }
}
