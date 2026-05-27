import AppKit

extension BlockInputView {
    func measuredBlockItemHeight(for block: BlockInputBlock, itemWidth: CGFloat) -> CGFloat {
        let textWidth = BlockInputBlockItem.measuredTextWidth(
            for: itemWidth,
            block: block,
            allowsReordering: allowsBlockReordering,
            editorHorizontalInset: editorHorizontalInset,
            style: style
        )
        return BlockInputBlockItem.height(
            for: block,
            textWidth: textWidth,
            style: style,
            fileBaseURL: fileBaseURL,
            blockVerticalInsetMultiplier: blockVerticalInsetMultiplier
        )
    }
}
