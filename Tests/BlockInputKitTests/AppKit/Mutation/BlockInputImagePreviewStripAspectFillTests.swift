import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BlockInputKit

@MainActor
final class ImagePreviewStripAspectFillTests: XCTestCase {
    func testPreviewStripThumbnailsAspectFillWideImages() async throws {
        let loader = AspectFillPreviewImageLoader(imageData: try Self.pngData(width: 240, height: 120))
        var style = BlockInputStyle.default
        style.imagePreviewStrip = BlockInputImagePreviewStripStyle(
            thumbnailSize: NSSize(width: 24, height: 24),
            removeButton: BlockInputImagePreviewRemoveButtonStyle(isVisible: false)
        )
        var openedURL: URL?
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(text: "![Alt](image.png)")
            ]),
            style: style,
            imagePresentation: .textLinksWithPreviewStrip,
            imageLoader: loader,
            imageDiskCache: nil,
            imageBaseURL: try XCTUnwrap(URL(string: "https://example.com/assets/")),
            urlOpener: {
                openedURL = $0
                return true
            }
        ))
        let view = mounted.view

        let imageFrame = try await waitForLoadedImageFrame(in: view)

        XCTAssertEqual(imageFrame.height, style.imagePreviewStrip.thumbnailSize.height, accuracy: 0.5)
        XCTAssertGreaterThan(imageFrame.width, style.imagePreviewStrip.thumbnailSize.width)
        XCTAssertLessThan(imageFrame.minX, 0)
        XCTAssertGreaterThan(imageFrame.maxX, style.imagePreviewStrip.thumbnailSize.width)

        try clickFirstPreviewTile(in: mounted)
        XCTAssertEqual(openedURL, try XCTUnwrap(URL(string: "https://example.com/assets/image.png")))
    }

    private func waitForLoadedImageFrame(in view: BlockInputView) async throws -> NSRect {
        for _ in 0..<100 {
            if let frame = view.imagePreviewStripView.firstTileImageFrameForTesting {
                return frame
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return try XCTUnwrap(view.imagePreviewStripView.firstTileImageFrameForTesting)
    }

    private func clickFirstPreviewTile(in mounted: (view: BlockInputView, window: NSWindow)) throws {
        let contentView = try XCTUnwrap(mounted.window.contentView)
        let windowPoint = try XCTUnwrap(mounted.view.imagePreviewStripView.firstTileCenterWindowPointForTesting)
        let contentPoint = contentView.convert(windowPoint, from: nil)
        let hitView = try XCTUnwrap(contentView.hitTest(contentPoint))
        hitView.mouseDown(with: try mouseDownEvent(location: windowPoint, windowNumber: mounted.window.windowNumber))
    }

    private static func pngData(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AspectFillPreviewImageLoaderError.invalidFixture
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw AspectFillPreviewImageLoaderError.invalidFixture
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw AspectFillPreviewImageLoaderError.invalidFixture
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AspectFillPreviewImageLoaderError.invalidFixture
        }
        return data as Data
    }
}

private actor AspectFillPreviewImageLoader: BlockInputImageLoading {
    private let imageData: Data

    init(imageData: Data) {
        self.imageData = imageData
    }

    func loadImage(_ request: BlockInputImageLoadRequest) async throws -> BlockInputLoadedImage {
        BlockInputLoadedImage(
            data: imageData,
            dimensions: BlockInputImageDimensions(width: 1, height: 1)
        )
    }
}

private enum AspectFillPreviewImageLoaderError: Error {
    case invalidFixture
}
