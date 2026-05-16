import AppKit

extension BlockInputBlockItem {
    static func horizontalContentTrailingInset(allowsReordering: Bool) -> CGFloat {
        horizontalChromeWidth(allowsReordering: allowsReordering)
    }

    static func measuredTextWidth(for itemWidth: CGFloat, allowsReordering: Bool) -> CGFloat {
        let horizontalInsets = horizontalChromeWidth(allowsReordering: allowsReordering)
            + horizontalContentTrailingInset(allowsReordering: allowsReordering)
        return max(itemWidth - horizontalInsets, 120)
    }

    static func codeBackgroundLeadingInset(allowsReordering: Bool) -> CGFloat {
        horizontalChromeWidth(allowsReordering: allowsReordering) + textContainerContentLeading
    }

    static func codeBackgroundTrailingInset(allowsReordering: Bool) -> CGFloat {
        codeBackgroundLeadingInset(allowsReordering: allowsReordering)
    }

    static func horizontalRuleTrailingInset(allowsReordering _: Bool) -> CGFloat {
        horizontalRuleInnerInset
    }
}
