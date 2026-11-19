import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Moves screenshots and screen recordings left in the user's old screenshot
/// folder (usually the Desktop) into Boardshot's folder. Only files macOS made
/// are touched: screenshots carry the `kMDItemIsScreenCapture` attribute that
/// macOS writes on each capture, and recordings carry the QuickTime author
/// "ReplayKitRecording". Other files in that folder are left alone.
enum Sweep {
    /// The screenshots and recordings directly inside `folders` (not in subfolders).
    static func find(in folders: [URL]) async -> [URL] {
        var found: [URL] = []
        let fm = FileManager.default
        for folder in folders {
            let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentTypeKey],
                                                    options: [.skipsHiddenFiles])) ?? []
            for url in urls {
                guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { continue }
                if type.conforms(to: .image), isScreenCapture(url) {
                    found.append(url)
                } else if type.conforms(to: .movie), await isScreenRecording(url) {
                    found.append(url)
                }
            }
        }
        return found
    }

    /// Moves each file into `folder`, adding " 2", " 3"… if the name is taken.
    /// Moving keeps the creation date, so each shot lands at its own time in
    /// the grid. Returns how many were moved.
    static func move(_ urls: [URL], to folder: URL) -> Int {
        let fm = FileManager.default
        var moved = 0
        for url in urls {
            let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
            var dest = folder.appendingPathComponent(url.lastPathComponent)
            var n = 2
            while fm.fileExists(atPath: dest.path) {
                dest = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
                n += 1
            }
            if (try? fm.moveItem(at: url, to: dest)) != nil { moved += 1 }
        }
        return moved
    }

    private static func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    private static func isScreenRecording(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.metadata) else { return false }
        for item in items where item.identifier == .quickTimeMetadataAuthor {
            if (try? await item.load(.stringValue)) == "ReplayKitRecording" { return true }
        }
        return false
    }
}
