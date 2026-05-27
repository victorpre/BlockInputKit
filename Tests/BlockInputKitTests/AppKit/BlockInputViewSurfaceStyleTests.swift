import AppKit
import QuartzCore
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewSurfaceStyleTests: XCTestCase {
    func testMountedEditorAppliesConfiguredSurfaceStyle() throws {
        let style = BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: .systemRed,
            scrollBackgroundColor: .systemGreen,
            collectionBackgroundColor: .systemBlue
        ))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [BlockInputBlock(id: "paragraph", text: "Surface")]),
            style: style
        ))

        XCTAssertEqual(mounted.view.layer?.backgroundColor, NSColor.systemRed.cgColor)
        XCTAssertEqual(mounted.view.scrollView.contentView.backgroundColor, .systemGreen)
        XCTAssertEqual(mounted.view.collectionView.backgroundColors, [.systemBlue])
    }

    func testMountedEditorAppliesTransparentSurfaceStyle() {
        let style = BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil
        ))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [BlockInputBlock(id: "paragraph", text: "Surface")]),
            style: style
        ))

        XCTAssertNil(mounted.view.layer?.backgroundColor)
        XCTAssertEqual(mounted.view.scrollView.contentView.backgroundColor, .clear)
        XCTAssertTrue(mounted.view.collectionView.backgroundColors.isEmpty)
    }

    func testMountedEditorReconfiguresSurfaceStyle() throws {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: .systemRed,
            scrollBackgroundColor: .systemGreen,
            collectionBackgroundColor: .systemBlue
        ))))

        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil
        ))))

        XCTAssertNil(view.layer?.backgroundColor)
        XCTAssertEqual(view.scrollView.contentView.backgroundColor, .clear)
        XCTAssertTrue(view.collectionView.backgroundColors.isEmpty)
    }

    func testMountedEditorUpdatesDynamicSurfaceStyleForAppearanceChange() throws {
        let dynamicColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .systemGreen : .systemRed
        }
        let view = BlockInputView()
        view.appearance = NSAppearance(named: .aqua)
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: dynamicColor,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil
        ))))
        let lightColor = try XCTUnwrap(NSColor(cgColor: try XCTUnwrap(view.layer?.backgroundColor)))

        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()
        let darkColor = try XCTUnwrap(NSColor(cgColor: try XCTUnwrap(view.layer?.backgroundColor)))

        XCTAssertNotEqual(lightColor, darkColor)
    }

    func testProgressiveLoadingRowUsesCollectionSurfaceStyle() throws {
        let store = BlockInputProgressiveMemoryDocumentStore(
            blocks: [
                BlockInputBlock(id: "first", text: "Loaded"),
                BlockInputBlock(id: "second", text: "Unloaded")
            ],
            initialLimit: 1
        )
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        view.configure(BlockInputConfiguration(
            documentStore: store,
            style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(collectionBackgroundColor: .systemBlue))
        ))

        let item = try XCTUnwrap(view.collectionView(
            view.collectionView,
            itemForRepresentedObjectAt: IndexPath(item: 1, section: 0)
        ) as? BlockInputLoadingItem)

        XCTAssertEqual(item.view.layer?.backgroundColor, NSColor.systemBlue.cgColor)
    }

    func testMountedEditorAppliesChromeStyle() {
        let style = BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .systemRed,
                strokeColor: .systemGreen,
                borderWidth: 2,
                cornerRadius: 18,
                roundedCorners: .bottom,
                clipsContentToShape: true
            )
        ))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [BlockInputBlock(id: "paragraph", text: "Surface")]),
            style: style
        ))

        XCTAssertNil(mounted.view.layer?.backgroundColor)
        XCTAssertNil(mounted.view.layer?.borderColor)
        XCTAssertEqual(mounted.view.layer?.borderWidth, 0)
        XCTAssertEqual(mounted.view.editorChromeFillLayer.fillColor, NSColor.systemRed.cgColor)
        XCTAssertEqual(mounted.view.editorChromeStrokeLayer.strokeColor, NSColor.systemGreen.cgColor)
        XCTAssertEqual(mounted.view.editorChromeStrokeLayer.lineWidth, 2)
        XCTAssertTrue(mounted.view.editorChromeFillLayer.superlayer === mounted.view.layer)
        XCTAssertTrue(mounted.view.editorChromeStrokeLayer.superlayer === mounted.view.layer)
        XCTAssertTrue(mounted.view.layer?.mask === mounted.view.editorChromeMaskLayer)
        XCTAssertNotNil(mounted.view.editorChromeFillLayer.path)
        XCTAssertNotNil(mounted.view.editorChromeStrokeLayer.path)
        XCTAssertNotNil(mounted.view.editorChromeMaskLayer.path)
    }

    func testMountedEditorReconfiguresChromeStyle() throws {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: .systemBlue,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .systemRed,
                strokeColor: .systemGreen,
                borderWidth: 2,
                cornerRadius: 18,
                clipsContentToShape: true
            )
        ))))

        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: .systemBlue,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil
        ))))

        XCTAssertEqual(view.layer?.backgroundColor, NSColor.systemBlue.cgColor)
        XCTAssertNil(view.layer?.borderColor)
        XCTAssertEqual(view.layer?.borderWidth, 0)
        XCTAssertEqual(view.layer?.cornerRadius, 0)
        XCTAssertEqual(view.layer?.maskedCorners, [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ])
        XCTAssertEqual(view.layer?.masksToBounds, false)
        XCTAssertNil(view.layer?.mask)
        XCTAssertNil(view.editorChromeFillLayer.superlayer)
        XCTAssertNil(view.editorChromeStrokeLayer.superlayer)
        XCTAssertNil(view.editorChromeFillLayer.path)
        XCTAssertNil(view.editorChromeStrokeLayer.path)
        XCTAssertNil(view.editorChromeMaskLayer.path)
    }

    func testMountedEditorUpdatesChromePathForFrameSizeChange() throws {
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 80, height: 40))
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .systemRed,
                strokeColor: .systemGreen,
                borderWidth: 2,
                cornerRadius: 12
            )
        ))))
        let initialPath = try XCTUnwrap(view.editorChromeFillLayer.path)
        XCTAssertEqual(initialPath.boundingBox.width, 78)
        XCTAssertEqual(initialPath.boundingBox.height, 38)

        view.setFrameSize(NSSize(width: 120, height: 60))

        let resizedPath = try XCTUnwrap(view.editorChromeFillLayer.path)
        XCTAssertEqual(resizedPath.boundingBox.width, 118)
        XCTAssertEqual(resizedPath.boundingBox.height, 58)
    }

    func testMountedEditorReconfiguresChromeClipping() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .systemRed,
                cornerRadius: 12,
                clipsContentToShape: true
            )
        ))))
        XCTAssertTrue(view.layer?.mask === view.editorChromeMaskLayer)

        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(
                fillColor: .systemRed,
                cornerRadius: 12,
                clipsContentToShape: false
            )
        ))))

        XCTAssertNil(view.layer?.mask)
        XCTAssertTrue(view.editorChromeFillLayer.superlayer === view.layer)
    }

    func testMountedEditorUpdatesDynamicChromeStyleForAppearanceChange() throws {
        let dynamicFill = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .systemGreen : .systemRed
        }
        let view = BlockInputView()
        view.appearance = NSAppearance(named: .aqua)
        view.configure(BlockInputConfiguration(style: BlockInputStyle(editorSurface: BlockInputEditorSurfaceStyle(
            editorBackgroundColor: nil,
            scrollBackgroundColor: nil,
            collectionBackgroundColor: nil,
            chrome: BlockInputEditorChromeStyle(fillColor: dynamicFill)
        ))))
        let lightColor = try XCTUnwrap(NSColor(cgColor: try XCTUnwrap(view.editorChromeFillLayer.fillColor)))

        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()
        let darkColor = try XCTUnwrap(NSColor(cgColor: try XCTUnwrap(view.editorChromeFillLayer.fillColor)))

        XCTAssertNotEqual(lightColor, darkColor)
    }
}
