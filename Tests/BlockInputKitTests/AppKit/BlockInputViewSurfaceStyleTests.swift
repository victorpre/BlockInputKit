import AppKit
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
}
