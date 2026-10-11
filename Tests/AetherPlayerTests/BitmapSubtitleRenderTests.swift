import XCTest
import SwiftUI
import AetherEngine
@testable import AetherPlayer

/// Renders the overlay with a bitmap cue and reads the pixels back: a layout test only proves the
/// frame math, not that the image reaches the surface.
@MainActor
final class BitmapSubtitleRenderTests: XCTestCase {

    private func solidRed(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    private func redPixelCount(_ image: CGImage) -> Int {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var count = 0
        for i in stride(from: 0, to: data.count, by: 4) where data[i] > 200 && data[i + 1] < 60 && data[i + 3] > 200 {
            count += 1
        }
        return count
    }

    private func render(videoSize: CGSize) -> CGImage? {
        let cue = SubtitleCue(id: 1, startTime: 0, endTime: 10,
                              body: .image(SubtitleImage(cgImage: solidRed(width: 600, height: 60),
                                                         position: CGRect(x: 0.2, y: 0.86, width: 0.6, height: 0.06),
                                                         canvasSize: CGSize(width: 1920, height: 1080))))
        let view = SubtitleOverlayView(cues: [cue], subtitleTime: 5, videoSize: videoSize)
            .frame(width: 960, height: 540)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }

    func testTextCueStillRendersBesideABitmap() throws {
        let image = SubtitleImage(cgImage: solidRed(width: 600, height: 60),
                                  position: CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.06),
                                  canvasSize: CGSize(width: 1920, height: 1080))
        let cues = [SubtitleCue(id: 1, startTime: 0, endTime: 10, body: .image(image)),
                    SubtitleCue(id: 2, startTime: 0, endTime: 10, body: .text("Hello"))]
        let view = SubtitleOverlayView(cues: cues, subtitleTime: 5, videoSize: CGSize(width: 1920, height: 1080))
            .frame(width: 960, height: 540)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let rendered = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThan(redPixelCount(rendered), 1000)
        XCTAssertGreaterThan(whitePixelCount(rendered, belowRow: 270), 20)
    }

    private func whitePixelCount(_ image: CGImage, belowRow minRow: Int) -> Int {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var count = 0
        // The context's first row is the image's top row.
        for row in minRow..<h {
            for col in 0..<w {
                let i = (row * w + col) * 4
                if data[i] > 200, data[i + 1] > 200, data[i + 2] > 200 { count += 1 }
            }
        }
        return count
    }

    func testBitmapCueReachesTheSurface() throws {
        let image = try XCTUnwrap(render(videoSize: CGSize(width: 1920, height: 1080)))
        XCTAssertGreaterThan(redPixelCount(image), 1000)
    }

    func testBitmapCueOnScopeHDRSourceReachesTheSurface() throws {
        // AetherPlayer#10: 3840x1608 HEVC with a 1920x1080 PGS plane.
        let image = try XCTUnwrap(render(videoSize: CGSize(width: 3840, height: 1608)))
        XCTAssertGreaterThan(redPixelCount(image), 1000)
    }
}
