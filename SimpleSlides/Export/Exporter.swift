import SwiftUI
import UIKit
import AVFoundation

enum ExportError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .failed(let m): return m
        }
    }
}

@MainActor
enum Exporter {
    private static func slides(_ deck: Deck, includeSkipped: Bool) -> [Slide] {
        let s = deck.slides.filter { includeSkipped || !$0.isSkipped }
        return s.isEmpty ? deck.slides : s
    }

    private static func exportDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "Export-\(UUID().uuidString.prefix(6))")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func renderImage(_ slide: Slide, deck: Deck, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: SlideRenderer(slide: slide, theme: deck.theme, size: deck.size))
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    // MARK: PDF

    static func pdf(_ deck: Deck, includeSkipped: Bool) throws -> URL {
        let url = exportDirectory().appending(path: "\(deck.title.sanitizedFileName).pdf")
        var box = CGRect(origin: .zero, size: deck.size)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw ExportError.failed("Couldn't create the PDF file.")
        }
        for slide in slides(deck, includeSkipped: includeSkipped) {
            let renderer = ImageRenderer(content: SlideRenderer(slide: slide, theme: deck.theme, size: deck.size))
            renderer.render { size, render in
                var page = CGRect(origin: .zero, size: size)
                ctx.beginPage(mediaBox: &page)
                render(ctx)
                ctx.endPage()
            }
        }
        ctx.closePDF()
        return url
    }

    // MARK: Images

    static func images(_ deck: Deck, includeSkipped: Bool, scale: CGFloat, jpeg: Bool) throws -> [URL] {
        let dir = exportDirectory()
        var urls: [URL] = []
        for (i, slide) in slides(deck, includeSkipped: includeSkipped).enumerated() {
            guard let image = renderImage(slide, deck: deck, scale: scale),
                  let data = jpeg ? image.jpegData(compressionQuality: 0.92) : image.pngData() else { continue }
            let url = dir.appending(path: String(format: "%@ %02d.%@", deck.title.sanitizedFileName, i + 1, jpeg ? "jpg" : "png"))
            try data.write(to: url)
            urls.append(url)
        }
        if urls.isEmpty { throw ExportError.failed("Couldn't render slides.") }
        return urls
    }

    // MARK: Video

    /// Exports an H.264 movie: each slide is held for `secondsPerSlide`, with a cross-fade between slides.
    static func video(_ deck: Deck, includeSkipped: Bool, height: Int, secondsPerSlide: Double,
                      progress: @escaping (Double) -> Void) async throws -> URL {
        let list = slides(deck, includeSkipped: includeSkipped)
        let aspect = deck.size.width / deck.size.height
        var h = height, w = Int((Double(height) * aspect).rounded())
        if deck.size.height > deck.size.width { w = height; h = Int((Double(height) / aspect).rounded()) }
        w -= w % 2; h -= h % 2
        let scale = CGFloat(w) / deck.size.width

        let url = exportDirectory().appending(path: "\(deck.title.sanitizedFileName).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: w * h * 6],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ])
        guard writer.canAdd(input) else { throw ExportError.failed("Video writer unavailable.") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ExportError.failed("Couldn't start writing video.") }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let fade = 0.5
        let fadeFrames = Int(fade * Double(fps))
        var time = 0.0

        func append(_ draw: (CGContext) -> Void, at seconds: Double) async throws {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { throw ExportError.failed("No pixel buffer pool.") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pb = buffer else { throw ExportError.failed("Couldn't allocate frame.") }
            CVPixelBufferLockBaseAddress(pb, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                draw(ctx)
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600))
        }

        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        var current = renderImage(list[0], deck: deck, scale: scale)?.cgImage
        for i in list.indices {
            guard let img = current else { throw ExportError.failed("Couldn't render slide \(i + 1).") }
            try await append({ $0.draw(img, in: rect) }, at: time)
            time += secondsPerSlide
            if i + 1 < list.count {
                let next = renderImage(list[i + 1], deck: deck, scale: scale)?.cgImage
                if let next {
                    for f in 1...fadeFrames {
                        let k = CGFloat(f) / CGFloat(fadeFrames)
                        try await append({ ctx in
                            ctx.draw(img, in: rect)
                            ctx.setAlpha(k)
                            ctx.draw(next, in: rect)
                        }, at: time + Double(f - 1) / Double(fps))
                    }
                    time += fade
                }
                current = next
            }
            progress(Double(i + 1) / Double(list.count))
        }
        if let img = current {
            try await append({ $0.draw(img, in: rect) }, at: time)
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: time, preferredTimescale: 600))
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? ExportError.failed("Video export failed.")
        }
        return url
    }
}
