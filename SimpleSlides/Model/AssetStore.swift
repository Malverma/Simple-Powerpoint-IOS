import UIKit

/// Stores image assets on disk, keyed by UUID, with an in-memory cache.
final class AssetStore {
    static let shared = AssetStore()

    private let cache = NSCache<NSUUID, UIImage>()
    let directory: URL

    private init() {
        directory = URL.documentsDirectory.appending(path: "Assets", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cache.countLimit = 80
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: id.uuidString)
    }

    func image(_ id: UUID) -> UIImage? {
        if let cached = cache.object(forKey: id as NSUUID) { return cached }
        guard let data = try? Data(contentsOf: url(for: id)), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    func data(_ id: UUID) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    /// Saves raw image data, downsampling very large images. Returns the new asset ID and pixel size.
    func add(imageData: Data, maxDimension: CGFloat = 2600) -> (UUID, CGSize)? {
        guard var image = UIImage(data: imageData) else { return nil }
        let longest = max(image.size.width, image.size.height)
        var data = imageData
        if longest > maxDimension {
            let scale = maxDimension / longest
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            image = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            data = image.pngData() ?? data
        }
        let id = UUID()
        return add(data: data, id: id) ? (id, image.size) : nil
    }

    @discardableResult
    func add(data: Data, id: UUID) -> Bool {
        do {
            try data.write(to: url(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func remove(_ id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
