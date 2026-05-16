import AppKit

extension BlockInputBlockItem {
    static func horizontalContentTrailingInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        horizontalChromeWidth(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
    }

    static func measuredTextWidth(
        for itemWidth: CGFloat,
        block: BlockInputBlock,
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        max(
            textScrollViewWidth(
                for: itemWidth,
                block: block,
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            )
                - 2 * textContainerLineFragmentPadding,
            120
        )
    }

    static func codeBackgroundLeadingInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        horizontalChromeWidth(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) + textContainerContentLeading
    }

    static func codeBackgroundTrailingInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        codeBackgroundLeadingInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
    }

    static func horizontalRuleTrailingInset(allowsReordering _: Bool) -> CGFloat {
        horizontalRuleInnerInset
    }

    static func textScrollViewWidth(
        for itemWidth: CGFloat,
        block: BlockInputBlock,
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        max(
            itemWidth
                - textScrollViewLeadingInset(
                    for: block,
                    allowsReordering: allowsReordering,
                    editorHorizontalInset: editorHorizontalInset
                )
                - horizontalContentTrailingInset(
                    allowsReordering: allowsReordering,
                    editorHorizontalInset: editorHorizontalInset
                ),
            120
        )
    }

    private static func textScrollViewLeadingInset(
        for block: BlockInputBlock,
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        handleTrailingX(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
            + kindLabelLeadingConstant(
                for: block,
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            )
            + kindLabelWidthConstant(for: block)
            + textLeadingConstant(
                for: block,
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            )
    }

    private static func kindLabelLeadingConstant(
        for block: BlockInputBlock,
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        let contentIndent = contentIndent(for: block)
        switch block.kind {
        case .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return markerAlignmentLeadingConstant(
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            ) + contentIndent
        case .paragraph, .heading, .code, .horizontalRule, .rawMarkdown:
            return contentIndent
        }
    }

    private static func kindLabelWidthConstant(for block: BlockInputBlock) -> CGFloat {
        guard block.kind.needsMeasuredMarkerLane else {
            return 0
        }
        if block.kind == .quote {
            return 0
        }
        return markerGutterWidth(for: block) + perLineContentIndent(for: block)
    }

    private static func textLeadingConstant(
        for block: BlockInputBlock,
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        if block.kind == .quote {
            return quoteTextLeading
        }
        if block.kind.supportsIndentation {
            return listTextLeading - perLineContentIndent(for: block)
        }
        return textScrollViewEdgeInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) - handleTrailingX(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) - contentIndent(for: block)
    }

    static func horizontalChromeWidth(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset
    ) -> CGFloat {
        textScrollViewEdgeInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        )
    }

    static func textScrollViewEdgeInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        max(
            visualContentInset(
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            ) - textContainerContentLeading,
            0
        )
    }

    static func handleLeadingInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        guard allowsReordering else {
            return 0
        }
        return max(
            (visualContentInset(
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            ) - handleWidth) / 2,
            0
        )
    }

    static func handleTrailingX(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        guard allowsReordering else {
            return 0
        }
        return handleLeadingInset(
            allowsReordering: allowsReordering,
            editorHorizontalInset: editorHorizontalInset
        ) + handleWidth
    }

    static func visualContentInset(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        // The configured inset describes the visual glyph/chrome column, not the scroll-view frame edge.
        // Reordering centers its handle inside that gutter when possible, then grows only to the handle minimum.
        let configuredInset = max(editorHorizontalInset, textContainerContentLeading)
        guard allowsReordering else {
            return configuredInset
        }
        return max(configuredInset, horizontalChromeWidthWithHandle)
    }

    private static func markerAlignmentLeadingConstant(
        allowsReordering: Bool,
        editorHorizontalInset: CGFloat
    ) -> CGFloat {
        visualContentInset(allowsReordering: allowsReordering, editorHorizontalInset: editorHorizontalInset)
            - handleTrailingX(
                allowsReordering: allowsReordering,
                editorHorizontalInset: editorHorizontalInset
            )
    }
}

private extension BlockInputBlockKind {
    var needsMeasuredMarkerLane: Bool {
        switch self {
        case .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule, .rawMarkdown:
            return false
        }
    }
}
