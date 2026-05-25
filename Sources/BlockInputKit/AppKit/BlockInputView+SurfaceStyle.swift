import AppKit

extension BlockInputView {
    func applyEditorSurfaceStyle() {
        wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = style.editorSurface.editorBackgroundColor?.cgColor
            if let scrollBackgroundColor = style.editorSurface.scrollBackgroundColor {
                scrollView.backgroundColor = scrollBackgroundColor
                scrollView.drawsBackground = true
                scrollView.contentView.backgroundColor = scrollBackgroundColor
                scrollView.contentView.drawsBackground = true
            } else {
                scrollView.backgroundColor = .clear
                scrollView.drawsBackground = false
                scrollView.contentView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
            }
            collectionView.backgroundColors = style.editorSurface.collectionBackgroundColor.map { [$0] } ?? []
        }
    }
}
