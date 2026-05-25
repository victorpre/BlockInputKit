import AppKit

/// Layout-manager delegate that collapses attributed Markdown source delimiters into zero-width glyphs.
final class BlockInputDelimiterGlyphs: NSObject, NSLayoutManagerDelegate {
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard glyphRange.length > 0,
              let textStorage = layoutManager.textStorage else {
            return 0
        }
        var glyphBuffer = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
        var propertyBuffer = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        var characterIndexBuffer = Array(UnsafeBufferPointer(start: charIndexes, count: glyphRange.length))
        var hasHiddenDelimiter = false
        for index in propertyBuffer.indices {
            let characterIndex = characterIndexBuffer[index]
            guard characterIndex >= 0,
                  characterIndex < textStorage.length,
                  textStorage.attribute(.blockInputHiddenDelimiter, at: characterIndex, effectiveRange: nil) as? Bool == true else {
                continue
            }
            // Clear foreground hides delimiter drawing, but null glyphs remove
            // their advance so hidden Markdown markers do not read as spaces.
            propertyBuffer[index].insert(.null)
            hasHiddenDelimiter = true
        }
        guard hasHiddenDelimiter else {
            return 0
        }
        layoutManager.setGlyphs(
            &glyphBuffer,
            properties: &propertyBuffer,
            characterIndexes: &characterIndexBuffer,
            font: font,
            forGlyphRange: glyphRange
        )
        return glyphRange.length
    }
}

extension NSAttributedString.Key {
    /// Marks visual inline chip content so adjacent virtual hints can fall back to the normal typing font.
    static let blockInputInlineChip = NSAttributedString.Key("BlockInputInlineChip")
    /// Marks source delimiters/tags that should stay in storage but collapse out of visual layout.
    static let blockInputHiddenDelimiter = NSAttributedString.Key("BlockInputHiddenDelimiter")
}
