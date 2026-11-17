// Draws the background of the .dmg window (install steps in Thai + English)
// and writes Resources/dmg-background.tiff (1x + 2x).
// Run from the repo root: swift tools/make_dmg_background.swift
//
// Layout must match build.sh: window 660×440, app icon at (165, 150),
// Applications at (495, 150), icon size 112.
import AppKit

let W: CGFloat = 660, H: CGFloat = 440
let blue = NSColor(srgbRed: 0x2F/255, green: 0x6F/255, blue: 0xEB/255, alpha: 1)
let ink = NSColor(srgbRed: 0x1D/255, green: 0x1D/255, blue: 0x1F/255, alpha: 1)
let muted = NSColor(srgbRed: 0x5A/255, green: 0x5F/255, blue: 0x6A/255, alpha: 1)
let paper = NSColor(srgbRed: 0xF6/255, green: 0xF7/255, blue: 0xF9/255, alpha: 1)
let card = NSColor.white
let line = NSColor(srgbRed: 0xE1/255, green: 0xE4/255, blue: 0xEA/255, alpha: 1)
let warn = NSColor(srgbRed: 0xB4/255, green: 0x23/255, blue: 0x18/255, alpha: 1)

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    // y-down coordinates, like Finder's icon positions
    let flipped = NSAffineTransform()
    flipped.translateX(by: 0, yBy: H)
    flipped.scaleX(by: 1, yBy: -1)
    flipped.concat()

    paper.setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()

    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, size: CGFloat,
              weight: NSFont.Weight = .regular, color: NSColor = ink, align: NSTextAlignment = .left) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: p,
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        // draw in a flipped sub-context so text isn't upside down
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: x, yBy: y)
        t.scaleX(by: 1, yBy: -1)
        t.concat()
        let h = str.boundingRect(with: NSSize(width: w, height: 400), options: [.usesLineFragmentOrigin]).height
        str.draw(with: NSRect(x: 0, y: -h, width: w, height: h), options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
    }

    // Step 1: arrow between the two icons
    text("① ลากไปที่ Applications  ·  Drag to Applications", 0, 44, W, size: 13, weight: .semibold,
         color: blue, align: .center)
    let a = NSBezierPath()
    a.lineWidth = 4
    a.lineCapStyle = .round
    a.move(to: NSPoint(x: 250, y: 150))
    a.line(to: NSPoint(x: 405, y: 150))
    a.move(to: NSPoint(x: 390, y: 138))
    a.line(to: NSPoint(x: 407, y: 150))
    a.line(to: NSPoint(x: 390, y: 162))
    blue.setStroke()
    a.stroke()

    // Step 2: card with first-launch instructions
    let box = NSRect(x: 24, y: 252, width: W - 48, height: 168)
    card.setFill()
    let path = NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12)
    path.fill()
    line.setStroke()
    path.lineWidth = 1
    path.stroke()

    let x = box.minX + 18, w = box.width - 36
    text("② เปิดครั้งแรก ถ้าขึ้นว่า “Boardshot” Not Opened", x, 268, w, size: 13.5, weight: .semibold)
    text("If macOS says “Boardshot” Not Opened the first time:", x, 288, w, size: 11.5, color: muted)
    text("กด Done  (อย่ากด Move to Trash)", x, 314, w, size: 13, weight: .semibold, color: warn)
    text("Click Done, not Move to Trash", x, 333, w, size: 11.5, color: muted)
    text("System Settings → Privacy & Security → เลื่อนลงล่างสุด → Open Anyway", x, 358, w, size: 13,
         weight: .medium)
    text("System Settings → Privacy & Security → scroll to the bottom → Open Anyway", x, 377, w,
         size: 11.5, color: muted)
    text("ทำครั้งเดียวต่อเครื่อง อัปเดตจากในแอปไม่ต้องทำอีก  ·  Only once; in-app updates skip this.", x, 400, w,
         size: 11, color: muted)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let img = NSImage(size: NSSize(width: W, height: H))
img.addRepresentation(render(scale: 1))
img.addRepresentation(render(scale: 2))
let out = URL(fileURLWithPath: "Resources/dmg-background.tiff")
try! img.tiffRepresentation(using: .lzw, factor: 0)!.write(to: out)
print("Wrote \(out.path)")
