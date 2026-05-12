import AppKit

struct BlockInputBlockItemVerticalMetrics {
    var textContainerInset: NSSize
    var topContentInset: CGFloat
    var bottomContentInset: CGFloat
    var minimumHeight: CGFloat

    static let standard = BlockInputBlockItemVerticalMetrics(
        textContainerInset: NSSize(width: 4, height: 6),
        topContentInset: 6,
        bottomContentInset: 6,
        minimumHeight: 34
    )

    static let checklist = BlockInputBlockItemVerticalMetrics(
        textContainerInset: NSSize(width: 4, height: 4),
        topContentInset: 4,
        bottomContentInset: 2,
        minimumHeight: 28
    )

    var chromeTopConstant: CGFloat {
        topContentInset + 2
    }

    func checklistButtonTopConstant(font: NSFont, checkboxHeight: CGFloat) -> CGFloat {
        topContentInset + (font.blockInputLineHeight - checkboxHeight) / 2
    }
}

extension BlockInputBlockItem {
    static let checklistButtonHeight: CGFloat = 18
    static let standardTextContainerInset = NSSize(width: 4, height: 6)
    static let checklistTextContainerInset = NSSize(width: 4, height: 4)
}

private extension NSFont {
    var blockInputLineHeight: CGFloat {
        ceil(ascender - descender + leading)
    }
}
