// Draws the Boardshot app icon (design "D": two stacked photos) and writes
// Resources/AppIcon.icns. Run: swift tools/make_icon.swift  (from the repo root)
import AppKit

let bg = NSColor(srgbRed: 0x2F/255, green: 0x6F/255, blue: 0xEB/255, alpha: 1)   // #2F6FEB
let back = NSColor(srgbRed: 0xA1/255, green: 0xBE/255, blue: 0xF6/255, alpha: 1) // #A1BEF6
let sun = NSColor(srgbRed: 0xFF/255, green: 0xC2/255, blue: 0x4B/255, alpha: 1)  // #FFC24B

/// Draws the 160×160 design into a square canvas of `px` pixels,
/// using Apple's icon grid (artwork is 824/1024 of the canvas, centred).
func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    let cg = ctx.cgContext
    let canvas = CGFloat(px)
    let art = canvas * 824 / 1024
    let k = art / 160
    // Flip to SVG-style coordinates (y down) and move into the icon grid.
    cg.translateBy(x: (canvas - art) / 2, y: canvas - (canvas - art) / 2)
    cg.scaleBy(x: k, y: -k)

    func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ c: NSColor) {
        c.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r).fill()
    }
    rr(0, 0, 160, 160, 36, bg)                 // background
    rr(28, 58, 72, 72, 11, back)               // back photo
    rr(56, 30, 76, 76, 10, .white)             // front photo
    let m = NSBezierPath()                     // mountains
    m.move(to: NSPoint(x: 64, y: 97))
    m.line(to: NSPoint(x: 83.36, y: 64.2))
    m.line(to: NSPoint(x: 97.8, y: 80.92))
    m.line(to: NSPoint(x: 107.68, y: 73.32))
    m.line(to: NSPoint(x: 124, y: 97))
    m.close()
    bg.setFill(); m.fill()
    sun.setFill()
    NSBezierPath(ovalIn: NSRect(x: 111.48 - 6.08, y: 51.28 - 6.08, width: 12.16, height: 12.16)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(px: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(px: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! render(px: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon-preview.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
