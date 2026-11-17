import AppKit
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct Shot: Equatable {
    let url: URL
    let created: Date
}

/// Lists the screenshot folder and watches it for changes.
final class ShotStore {
    let folder: URL
    private(set) var shots: [Shot] = []
    var onChange: (() -> Void)?
    /// Called with the newest file that just appeared (not on the first load).
    var onNewShot: ((Shot) -> Void)?
    private var known: Set<URL>?

    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private let thumbs = NSCache<NSString, NSImage>()

    init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
        watch()
    }

    func reload() {
        let keys: [URLResourceKey] = [.creationDateKey, .contentTypeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        shots = urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let type = v.contentType,
                  type.conforms(to: .image) || type.conforms(to: .movie) else { return nil }
            return Shot(url: url, created: v.creationDate ?? .distantPast)
        }
        .sorted { $0.created > $1.created }

        let now = Set(shots.map(\.url))
        if let known {
            let fresh = shots.filter { !known.contains($0.url) && $0.created > Date().addingTimeInterval(-20) }
            if let newest = fresh.first { onNewShot?(newest) }
        }
        known = now
        onChange?()
    }

    private func watch() {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in self?.scheduleReload() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func scheduleReload() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.reload() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    /// Sharp thumbnail for `size` (in points). Images are decoded straight from
    /// the file at Retina resolution; movies fall back to Quick Look.
    func thumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        // Cache per size: the grid and the corner thumbnail ask for different sizes.
        let key = "\(url.path)|\(Int(size.width))x\(Int(size.height))" as NSString
        if let img = thumbs.object(forKey: key) { completion(img); return }

        // Use the sharpest screen attached, so it's crisp on Retina and external displays.
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let maxPixels = Int(max(size.width, size.height) * scale)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let img = Self.decode(url, maxPixels: maxPixels, scale: scale) {
                DispatchQueue.main.async {
                    self?.thumbs.setObject(img, forKey: key)
                    completion(img)
                }
                return
            }
            let req = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale,
                                                   representationTypes: .all)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
                let img = rep?.nsImage
                DispatchQueue.main.async {
                    if let img { self?.thumbs.setObject(img, forKey: key) }
                    completion(img)
                }
            }
        }
    }

    /// Downscales an image file with ImageIO (high quality, honours rotation).
    /// The NSImage's point size is pixels ÷ scale, so it draws 1:1 on Retina.
    private static func decode(_ url: URL, maxPixels: Int, scale: CGFloat) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale,
                                                 height: CGFloat(cg.height) / scale))
    }

    func trash(_ urls: [URL]) {
        for u in urls { try? FileManager.default.trashItem(at: u, resultingItemURL: nil) }
        reload()
    }
}
