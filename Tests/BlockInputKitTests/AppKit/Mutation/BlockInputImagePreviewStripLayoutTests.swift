import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputImagePreviewStripLayoutTests: XCTestCase {
    func testOpaquePreviewStripDrawsAboveChromeFillBelowStrokeOverlay() throws {
        var style = blockInputStyleWithChrome()
        style.imagePreviewStrip = BlockInputImagePreviewStripStyle(backgroundColor: .systemPurple)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        view.configure(BlockInputConfiguration(
            style: style,
            imagePreviewAttachments: [previewAttachment()]
        ))
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.imagePreviewStripHeightConstraint?.constant, style.imagePreviewStrip.preferredHeight)
        XCTAssertEqual(view.scrollViewTopConstraint?.constant, style.imagePreviewStrip.preferredHeight)

        let chromeIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.editorChromeView))
        let previewIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.imagePreviewStripView))
        let strokeOverlayIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.editorChromeStrokeOverlayView))
        XCTAssertLessThan(chromeIndex, previewIndex)
        XCTAssertGreaterThan(strokeOverlayIndex, previewIndex)
        XCTAssertTrue(view.editorChromeView.drawsFill)
        XCTAssertFalse(view.editorChromeStrokeOverlayView.drawsFill)
        XCTAssertFalse(view.editorChromeView.drawsStroke)
        XCTAssertTrue(view.editorChromeStrokeOverlayView.drawsStroke)
        XCTAssertEqual(view.editorChromeStrokeOverlayView.strokePassCount, 2)
        XCTAssertNil(view.editorChromeStrokeLayer.superlayer)
    }

    func testTransparentPreviewStripKeepsStrokeOverlayAboveStrip() throws {
        var style = blockInputStyleWithChrome()
        style.imagePreviewStrip = BlockInputImagePreviewStripStyle(backgroundColor: nil)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        view.configure(BlockInputConfiguration(
            style: style,
            imagePreviewAttachments: [previewAttachment()]
        ))
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.imagePreviewStripHeightConstraint?.constant, style.imagePreviewStrip.preferredHeight)
        XCTAssertEqual(view.scrollViewTopConstraint?.constant, style.imagePreviewStrip.preferredHeight)

        let previewIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.imagePreviewStripView))
        let strokeOverlayIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.editorChromeStrokeOverlayView))
        XCTAssertGreaterThan(strokeOverlayIndex, previewIndex)
        XCTAssertFalse(view.editorChromeStrokeOverlayView.drawsFill)
        XCTAssertFalse(view.editorChromeView.drawsStroke)
        XCTAssertTrue(view.editorChromeStrokeOverlayView.drawsStroke)
        XCTAssertEqual(view.editorChromeStrokeOverlayView.strokePassCount, 2)
        XCTAssertNil(view.editorChromeStrokeLayer.superlayer)
    }

    func testPreviewStripContentUsesEditorHorizontalInset() throws {
        var style = BlockInputStyle.default
        style.imagePreviewStrip = BlockInputImagePreviewStripStyle(
            thumbnailSize: NSSize(width: 48, height: 48),
            contentInsets: NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        )
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 160))
        view.configure(BlockInputConfiguration(
            editorHorizontalInset: 28,
            style: style,
            imagePreviewAttachments: [previewAttachment()]
        ))
        view.layoutSubtreeIfNeeded()

        let tileFrame = try XCTUnwrap(view.imagePreviewStripView.firstTileFrameForTesting)
        XCTAssertEqual(tileFrame.minX, 28, accuracy: 0.5)
    }

    func testPreviewStripCompactsTopEditorInsetOnlyWhileVisible() {
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 160))
        view.configure(BlockInputConfiguration(
            editorVerticalInset: 12,
            imagePreviewAttachments: [previewAttachment()]
        ))

        XCTAssertEqual(view.editorVerticalInset, 12)
        XCTAssertEqual(view.layout.sectionInset.top, 0)
        XCTAssertEqual(view.layout.sectionInset.bottom, 12)

        view.configure(BlockInputConfiguration(editorVerticalInset: 12))

        XCTAssertTrue(view.imagePreviewStripView.isHidden)
        XCTAssertEqual(view.editorVerticalInset, 12)
        XCTAssertEqual(view.layout.sectionInset.top, 12)
        XCTAssertEqual(view.layout.sectionInset.bottom, 12)
    }

    private func blockInputStyleWithChrome() -> BlockInputStyle {
        var style = BlockInputStyle.default
        style.editorSurface = BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .clear,
                strokeColor: .systemGreen,
                borderWidth: 3,
                cornerRadius: 12
            )
        )
        return style
    }

    private func previewAttachment() -> BlockInputImagePreviewAttachment {
        BlockInputImagePreviewAttachment(
            id: "host",
            fileURL: URL(fileURLWithPath: "/tmp/host.png"),
            label: "Host Image",
            open: { _ in },
            remove: { _ in }
        )
    }
}
