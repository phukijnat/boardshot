import AppKit

/// Menu bar version of the app icon (design "D": two stacked photos), drawn as
/// a one-colour template image so macOS tints it for light/dark menu bars.
/// Back photo is semi-transparent, front photo is solid with the mountains and
/// sun cut out, like the full-colour icon.
enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }

            // App icon artwork spans x 28…132, y 30…130 in its 160-unit design.
            // Fit that into the 18pt square with a small margin.
            let k: CGFloat = 16.4 / 104
            cg.translateBy(x: 0.8 - 28 * k, y: 1.0 - 30 * k)
            cg.scaleBy(x: k, y: k)

            func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
                CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
            }
            let back = CGRect(x: 28, y: 58, width: 72, height: 72)
            let front = CGRect(x: 56, y: 30, width: 76, height: 76)

            // Back photo, lighter.
            cg.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
            cg.addPath(rounded(back, 13)); cg.fillPath()

            // Clear a thin gap around the front photo so the two read as separate.
            cg.setBlendMode(.clear)
            cg.addPath(rounded(front.insetBy(dx: -9, dy: -9), 19)); cg.fillPath()

            // Front photo, solid.
            cg.setBlendMode(.normal)
            cg.setFillColor(NSColor.black.cgColor)
            cg.addPath(rounded(front, 13)); cg.fillPath()

            // Cut out the mountains and the sun.
            cg.setBlendMode(.clear)
            let m = CGMutablePath()
            m.move(to: CGPoint(x: 66, y: 96))
            m.addLine(to: CGPoint(x: 84, y: 62))
            m.addLine(to: CGPoint(x: 98, y: 80))
            m.addLine(to: CGPoint(x: 108, y: 71))
            m.addLine(to: CGPoint(x: 122, y: 96))
            m.closeSubpath()
            cg.addPath(m); cg.fillPath()
            cg.fillEllipse(in: CGRect(x: 104, y: 42, width: 15, height: 15))
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = AppInfo.name
        return img
    }
}
