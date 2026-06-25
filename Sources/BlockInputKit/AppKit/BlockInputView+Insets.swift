import AppKit

extension BlockInputView {
    /// Visual vertical inset used above and below editor content.
    public internal(set) var editorVerticalInset: CGFloat {
        get {
            (collectionView.collectionViewLayout as? NSCollectionViewFlowLayout)?.sectionInset.bottom
                ?? layout.sectionInset.bottom
        }
        set {
            updateEditorSectionInset(newValue)
        }
    }

    var editorContentTopInset: CGFloat {
        editorContentTopInset(for: editorVerticalInset)
    }

    private func editorContentTopInset(for verticalInset: CGFloat) -> CGFloat {
        (imagePreviewStripHeightConstraint?.constant ?? 0) > 0
            ? 0
            : verticalInset
    }

    func updateEditorSectionInset(_ verticalInset: CGFloat) {
        applyEditorSectionInset(verticalInset)
    }

    func applyEditorSectionInset() {
        applyEditorSectionInset(editorVerticalInset)
    }

    private func applyEditorSectionInset(_ verticalInset: CGFloat) {
        let sectionInset = NSEdgeInsets(
            top: editorContentTopInset(for: verticalInset),
            left: 0,
            bottom: verticalInset,
            right: 0
        )
        layout.sectionInset = sectionInset
        (collectionView.collectionViewLayout as? NSCollectionViewFlowLayout)?.sectionInset = sectionInset
    }
}
