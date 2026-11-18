// Renders the README demo GIF. The panel is Boardshot's real PanelController
// (compiled from Sources/), drawn off-screen; the desktop, windows, cursor and
// chat around it are drawn here.
//
//   main <out.gif> <workdir>
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let outURL = URL(fileURLWithPath: args[1])
let work = URL(fileURLWithPath: args[2])
let shotsDir = work.appendingPathComponent("shots")

UserDefaults.standard.set("en", forKey: "lang")
UserDefaults.standard.set(false, forKey: "showHoverPreview")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)

// MARK: - Canvas & drawing helpers (top-left origin, points)

let W: CGFloat = 1280, H: CGFloat = 800
let outScale: CGFloat = 0.875            // GIF is 1120 x 700

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func fill(_ r: CGRect, _ c: NSColor, radius: CGFloat = 0) {
    c.setFill()
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
}

func text(_ s: String, _ p: CGPoint, _ size: CGFloat, _ color: NSColor,
          weight: NSFont.Weight = .regular, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    (s as NSString).draw(at: p, withAttributes: [.font: font, .foregroundColor: color])
}

func textWidth(_ s: String, _ size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
    (s as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
}

func withShadow(_ blur: CGFloat, _ alpha: CGFloat, dy: CGFloat = 8, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowBlurRadius = blur
    sh.shadowOffset = NSSize(width: 0, height: -dy)   // flipped: negative = down
    sh.shadowColor = NSColor.black.withAlphaComponent(alpha)
    sh.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

/// Draws into a flipped bitmap of `size` points at `scale`, returns CGImage.
func render(_ size: CGSize, scale: CGFloat, _ body: () -> Void) -> CGImage {
    let w = Int(size.width * scale), h = Int(size.height * scale)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: scale, y: -scale)
    let g = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    body()
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}

func draw(_ img: CGImage, in r: CGRect, alpha: CGFloat = 1) {
    let ns = NSImage(cgImage: img, size: r.size)
    ns.draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: nil)
}

func savePNG(_ img: CGImage, _ url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}

// MARK: - Scene pieces

let dashRect = CGRect(x: 56, y: 82, width: 660, height: 500)
let chatRect = CGRect(x: 770, y: 118, width: 450, height: 580)
let chartRect = CGRect(x: dashRect.minX + 200, y: dashRect.minY + 150, width: 436, height: 316)
let selRect = chartRect.insetBy(dx: -10, dy: -10)

func windowChrome(_ r: CGRect, title: String) {
    withShadow(28, 0.28, dy: 12) { fill(r, .white, radius: 12) }
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).addClip()
    fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 40), rgb(0xF2F2F4))
    fill(CGRect(x: r.minX, y: r.minY + 40, width: r.width, height: 1), rgb(0xDDDDE2))
    NSGraphicsContext.restoreGraphicsState()
    for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        rgb(UInt32(c)).setFill()
        NSBezierPath(ovalIn: CGRect(x: r.minX + 16 + CGFloat(i) * 20, y: r.minY + 14, width: 12, height: 12)).fill()
    }
    let tw = textWidth(title, 13, weight: .semibold)
    text(title, CGPoint(x: r.midX - tw / 2, y: r.minY + 11), 13, rgb(0x3A3A3C), weight: .semibold)
}

func chartCard(_ r: CGRect) {
    fill(r, .white, radius: 10)
    rgb(0xE5E5EA).setStroke()
    NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()
    text("Weekly active users", CGPoint(x: r.minX + 20, y: r.minY + 16), 13, rgb(0x6E6E73), weight: .medium)
    text("12,480", CGPoint(x: r.minX + 20, y: r.minY + 36), 30, rgb(0x1C1C1E), weight: .bold)
    let pill = CGRect(x: r.minX + 136, y: r.minY + 46, width: 58, height: 22)
    fill(pill, rgb(0x34C759, 0.15), radius: 11)
    text("+18%", CGPoint(x: pill.minX + 11, y: pill.minY + 3), 12, rgb(0x248A3D), weight: .semibold)
    let vals: [CGFloat] = [0.38, 0.45, 0.42, 0.55, 0.5, 0.62, 0.58, 0.7, 0.66, 0.78, 0.84, 0.95]
    let base = r.maxY - 40, top = r.minY + 96
    let gap: CGFloat = 10
    let bw = (r.width - 40 - gap * CGFloat(vals.count - 1)) / CGFloat(vals.count)
    for i in 0..<3 {
        let y = top + CGFloat(i) * (base - top) / 3
        fill(CGRect(x: r.minX + 20, y: y, width: r.width - 40, height: 1), rgb(0xF0F0F3))
    }
    for (i, v) in vals.enumerated() {
        let h = (base - top) * v
        let x = r.minX + 20 + CGFloat(i) * (bw + gap)
        fill(CGRect(x: x, y: base - h, width: bw, height: h), i == vals.count - 1 ? rgb(0x0A84FF) : rgb(0x0A84FF, 0.35), radius: 4)
    }
    for (i, m) in ["W1", "W4", "W8", "W12"].enumerated() {
        let x = r.minX + 20 + CGFloat([0, 3, 7, 11][i]) * (bw + gap)
        text(m, CGPoint(x: x + 2, y: base + 10), 11, rgb(0x8E8E93))
    }
}

func dashboard() {
    let r = dashRect
    windowChrome(r, title: "Dashboard")
    // sidebar
    fill(CGRect(x: r.minX, y: r.minY + 41, width: 180, height: r.height - 41), rgb(0xF7F7F9))
    NSGraphicsContext.saveGraphicsState()
    for (i, s) in ["Overview", "Users", "Revenue", "Retention", "Settings"].enumerated() {
        let y = r.minY + 64 + CGFloat(i) * 34
        if i == 0 { fill(CGRect(x: r.minX + 10, y: y - 6, width: 160, height: 30), rgb(0x0A84FF, 0.12), radius: 7) }
        fill(CGRect(x: r.minX + 22, y: y + 2, width: 14, height: 14), i == 0 ? rgb(0x0A84FF) : rgb(0xC7C7CC), radius: 4)
        text(s, CGPoint(x: r.minX + 46, y: y), 13, i == 0 ? rgb(0x0A84FF) : rgb(0x3A3A3C), weight: i == 0 ? .semibold : .regular)
    }
    NSGraphicsContext.restoreGraphicsState()
    text("Overview", CGPoint(x: r.minX + 200, y: r.minY + 60), 22, rgb(0x1C1C1E), weight: .bold)
    for (i, (k, v)) in [("Sign-ups", "1,204"), ("Revenue", "$8.2k")].enumerated() {
        let t = CGRect(x: r.minX + 200 + CGFloat(i) * 222, y: r.minY + 98, width: 214, height: 1)
        _ = t
        text("\(k)  ", CGPoint(x: r.minX + 330 + CGFloat(i) * 150, y: r.minY + 68), 12, rgb(0x8E8E93))
        text(v, CGPoint(x: r.minX + 330 + CGFloat(i) * 150 + textWidth("\(k)  ", 12), y: r.minY + 66), 14, rgb(0x1C1C1E), weight: .semibold)
    }
    text("Last 12 weeks", CGPoint(x: r.minX + 200, y: r.minY + 118), 12, rgb(0x8E8E93))
    chartCard(chartRect)
}

struct Msg { let who: String; let color: UInt32; let text: String }
let msgs = [Msg(who: "Mai", color: 0xFF9F0A, text: "Morning! How did sign-ups go this week?"),
            Msg(who: "Ken", color: 0x30B0C7, text: "Can someone share the latest chart?")]

func chat(dropped: CGImage?, pop: CGFloat) {
    let r = chatRect
    windowChrome(r, title: "# team-updates")
    var y = r.minY + 64
    for m in msgs {
        rgb(m.color).setFill()
        NSBezierPath(ovalIn: CGRect(x: r.minX + 18, y: y, width: 34, height: 34)).fill()
        text(String(m.who.prefix(1)), CGPoint(x: r.minX + 30, y: y + 8), 14, .white, weight: .bold)
        text(m.who, CGPoint(x: r.minX + 64, y: y - 1), 13, rgb(0x1C1C1E), weight: .semibold)
        text("10:4\(msgs.firstIndex { $0.who == m.who }! + 1)", CGPoint(x: r.minX + 70 + textWidth(m.who, 13, weight: .semibold), y: y + 1), 11, rgb(0x8E8E93))
        text(m.text, CGPoint(x: r.minX + 64, y: y + 18), 13, rgb(0x3A3A3C))
        y += 66
    }
    if let img = dropped {
        let a = min(1, pop * 1.6)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(a)
        rgb(0x0A84FF).setFill()
        NSBezierPath(ovalIn: CGRect(x: r.minX + 18, y: y, width: 34, height: 34)).fill()
        text("Y", CGPoint(x: r.minX + 30, y: y + 8), 14, .white, weight: .bold)
        text("You", CGPoint(x: r.minX + 64, y: y - 1), 13, rgb(0x1C1C1E), weight: .semibold)
        text("10:43", CGPoint(x: r.minX + 70 + textWidth("You", 13, weight: .semibold), y: y + 1), 11, rgb(0x8E8E93))
        let s = 0.92 + 0.08 * min(1, pop)
        let iw = 300 * s, ih = iw * selRect.height / selRect.width
        let ir = CGRect(x: r.minX + 64, y: y + 22, width: iw, height: ih)
        withShadow(6, 0.15, dy: 2) { fill(ir, .white, radius: 8) }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: ir, xRadius: 8, yRadius: 8).addClip()
        draw(img, in: ir)
        NSGraphicsContext.restoreGraphicsState()
        rgb(0xD1D1D6).setStroke()
        NSBezierPath(roundedRect: ir, xRadius: 8, yRadius: 8).stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    let box = CGRect(x: r.minX + 16, y: r.maxY - 58, width: r.width - 32, height: 40)
    fill(box, rgb(0xF2F2F4), radius: 10)
    rgb(0xD1D1D6).setStroke()
    NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()
    text("Message #team-updates", CGPoint(x: box.minX + 14, y: box.minY + 11), 13, rgb(0xAEAEB2))
}

let menuIcon = MenuBarIcon.make()

func desktop() {
    let g = NSGradient(colors: [rgb(0x5E7CE2), rgb(0x8A6FD8), rgb(0xD98BB4)])!
    g.draw(in: CGRect(x: 0, y: 0, width: W, height: H), angle: -60)
    // menu bar
    fill(CGRect(x: 0, y: 0, width: W, height: 26), NSColor.white.withAlphaComponent(0.28))
    if let apple = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil) {
        let a = apple.withSymbolConfiguration(.init(pointSize: 14, weight: .regular))!
        a.isTemplate = true
        tinted(a, .black).draw(in: CGRect(x: 18, y: 5, width: 14, height: 16), from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
    }
    text("Finder", CGPoint(x: 46, y: 4), 13, .black, weight: .bold)
    for (i, s) in ["File", "Edit", "View", "Go", "Window"].enumerated() {
        text(s, CGPoint(x: 104 + CGFloat(i) * 50, y: 4), 13, NSColor.black.withAlphaComponent(0.85))
    }
    text("Wed 18 Nov  10:42", CGPoint(x: W - 140, y: 4), 13, NSColor.black.withAlphaComponent(0.85))
    tinted(menuIcon, .black).draw(in: CGRect(x: W - 176, y: 4, width: 18, height: 18), from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
    for (i, n) in ["wifi", "battery.75percent"].enumerated() {
        if let s = NSImage(systemSymbolName: n, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 13, weight: .regular)) {
            let sz = s.size
            tinted(s, .black).draw(in: CGRect(x: W - 240 + CGFloat(i) * 30, y: 13 - sz.height / 2, width: sz.width, height: sz.height), from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
        }
    }
}

func tinted(_ img: NSImage, _ c: NSColor) -> NSImage {
    NSImage(size: img.size, flipped: false) { r in
        img.draw(in: r)
        c.set()
        r.fill(using: .sourceAtop)
        return true
    }
}

// MARK: - Sample screenshots for the panel

func sample(_ kind: Int, _ hue: Int) -> CGImage {
    let size = kind == 5 ? CGSize(width: 420, height: 860) : CGSize(width: 1200, height: 780)
    let accents: [UInt32] = [0x0A84FF, 0xFF9F0A, 0x30D158, 0xBF5AF2, 0xFF375F]
    let acc = rgb(accents[hue % accents.count])
    return render(size, scale: 1) {
        let r = CGRect(origin: .zero, size: size)
        switch kind {
        case 0: // code editor
            fill(r, rgb(0x1E1F29))
            fill(CGRect(x: 0, y: 0, width: 220, height: size.height), rgb(0x16171F))
            for i in 0..<14 { fill(CGRect(x: 24, y: 40 + CGFloat(i) * 34, width: CGFloat(80 + (i * 37) % 100), height: 12), rgb(0x3B3D4E), radius: 6) }
            let cols: [NSColor] = [acc, rgb(0x6CD3A4), rgb(0xE5C07B), rgb(0xABB2BF), rgb(0xE06C75)]
            for i in 0..<18 {
                var x: CGFloat = 270 + CGFloat((i % 4) * 30)
                for j in 0..<(2 + (i * 7) % 4) {
                    let w = CGFloat(40 + ((i * 13 + j * 29) % 120))
                    fill(CGRect(x: x, y: 44 + CGFloat(i) * 38, width: w, height: 16), cols[(i + j) % cols.count], radius: 8)
                    x += w + 14
                }
            }
        case 1: // colour palette
            fill(r, rgb(0xFAFAFC))
            text("Brand palette", CGPoint(x: 60, y: 50), 44, rgb(0x1C1C1E), weight: .bold)
            let pal: [UInt32] = [[0x0A84FF, 0x5E5CE6, 0xBF5AF2, 0xFF375F, 0xFF9F0A], [0x30D158, 0x64D2FF, 0x0A84FF, 0x1C1C1E, 0xF2F2F7]][hue % 2]
            for (i, c) in pal.enumerated() {
                let sw = CGRect(x: 60 + CGFloat(i) * 220, y: 170, width: 200, height: 420)
                fill(sw, rgb(c), radius: 18)
                text(String(format: "#%06X", c), CGPoint(x: sw.minX + 10, y: sw.maxY + 24), 26, rgb(0x6E6E73), mono: true)
            }
        case 2: // sign-in form
            fill(r, rgb(0xEEF1F6))
            let card = CGRect(x: 360, y: 110, width: 480, height: 560)
            withShadow(30, 0.12) { fill(card, .white, radius: 22) }
            text("Sign in", CGPoint(x: card.minX + 50, y: card.minY + 50), 42, rgb(0x1C1C1E), weight: .bold)
            for i in 0..<2 {
                text(["Email", "Password"][i], CGPoint(x: card.minX + 50, y: card.minY + 150 + CGFloat(i) * 120), 22, rgb(0x6E6E73))
                let f = CGRect(x: card.minX + 50, y: card.minY + 186 + CGFloat(i) * 120, width: 380, height: 58)
                fill(f, rgb(0xF5F5F7), radius: 12)
            }
            fill(CGRect(x: card.minX + 50, y: card.minY + 440, width: 380, height: 64), acc, radius: 14)
            let tw = textWidth("Continue", 24, weight: .semibold)
            text("Continue", CGPoint(x: card.midX - tw / 2, y: card.minY + 457), 24, .white, weight: .semibold)
        case 3: // landscape photo
            NSGradient(colors: [[rgb(0x89C4F4), rgb(0xFBD3A6)], [rgb(0x2C3E7A), rgb(0xF29E6D)]][hue % 2])!.draw(in: r, angle: -90)
            rgb(0xFFF1C9).setFill()
            NSBezierPath(ovalIn: CGRect(x: 760, y: 170, width: 150, height: 150)).fill()
            for (k, c) in [(0, 0x5B6D8C), (1, 0x2F3E5C)].map({ ($0.0, $0.1) }) {
                let p = NSBezierPath()
                p.move(to: CGPoint(x: 0, y: size.height))
                let pts: [CGFloat] = k == 0 ? [420, 300, 460, 260, 380, 330, 450] : [560, 470, 600, 430, 520, 580, 500]
                for (i, y) in pts.enumerated() { p.line(to: CGPoint(x: CGFloat(i) * size.width / CGFloat(pts.count - 1), y: y)) }
                p.line(to: CGPoint(x: size.width, y: size.height)); p.close()
                rgb(UInt32(c)).setFill(); p.fill()
            }
        case 4: // table
            fill(r, .white)
            text("Orders", CGPoint(x: 50, y: 40), 40, rgb(0x1C1C1E), weight: .bold)
            fill(CGRect(x: 50, y: 120, width: 1100, height: 54), rgb(0xF2F2F7), radius: 8)
            for i in 0..<9 {
                let y = 190 + CGFloat(i) * 62
                fill(CGRect(x: 50, y: y + 60, width: 1100, height: 1), rgb(0xE5E5EA))
                fill(CGRect(x: 70, y: y + 20, width: 160, height: 18), rgb(0xD1D1D6), radius: 9)
                fill(CGRect(x: 330, y: y + 20, width: CGFloat(200 + (i * 53) % 220), height: 18), rgb(0xE5E5EA), radius: 9)
                fill(CGRect(x: 900, y: y + 14, width: 110, height: 30), (i % 3 == 0 ? acc : rgb(0x30D158)).withAlphaComponent(0.18), radius: 15)
            }
        default: // phone screen
            fill(r, rgb(0xF2F2F7))
            fill(CGRect(x: 0, y: 0, width: size.width, height: 230), acc)
            text("Today", CGPoint(x: 30, y: 120), 46, .white, weight: .bold)
            for i in 0..<5 {
                let c = CGRect(x: 24, y: 260 + CGFloat(i) * 116, width: size.width - 48, height: 100)
                fill(c, .white, radius: 18)
                fill(CGRect(x: c.minX + 18, y: c.minY + 22, width: 56, height: 56), acc.withAlphaComponent(0.25), radius: 14)
                fill(CGRect(x: c.minX + 92, y: c.minY + 30, width: 180, height: 16), rgb(0xC7C7CC), radius: 8)
                fill(CGRect(x: c.minX + 92, y: c.minY + 58, width: 120, height: 14), rgb(0xE5E5EA), radius: 7)
            }
        }
    }
}

// The screenshot taken in the clip: the chart card, cropped from the scene.
let newShot: CGImage = render(selRect.size, scale: 2) {
    NSGraphicsContext.current?.cgContext.translateBy(x: -selRect.minX, y: -selRect.minY)
    dashboard()
}

try? FileManager.default.removeItem(at: shotsDir)
try! FileManager.default.createDirectory(at: shotsDir, withIntermediateDirectories: true)
let olds: [(Int, Int)] = [(0, 0), (3, 0), (2, 1), (4, 3), (1, 0), (5, 2), (0, 3), (3, 1), (2, 4), (1, 1), (4, 0)]
let now = Date()
for (i, (k, h)) in olds.enumerated() {
    let url = shotsDir.appendingPathComponent(String(format: "Screenshot 2026-11-17 at 16.%02d.%02d.png", 50 - i * 3, (i * 17) % 60))
    savePNG(sample(k, h), url)
    try? FileManager.default.setAttributes([.creationDate: now.addingTimeInterval(-Double(3600 + i * 900))], ofItemAtPath: url.path)
}
let newURL = shotsDir.appendingPathComponent("Screenshot 2026-11-18 at 10.42.07.png")
savePNG(newShot, newURL)
try? FileManager.default.setAttributes([.creationDate: now], ofItemAtPath: newURL.path)

// MARK: - Render Boardshot's real panel off-screen

func child<T>(_ o: Any, _ name: String) -> T {
    Mirror(reflecting: o).children.first { $0.label == name }!.value as! T
}

let store = ShotStore(folder: shotsDir)
let controller = PanelController(store: store)
let panel: ClipPanel = child(controller, "panel")
let grid: GridView = child(controller, "grid")
panel.setFrameOrigin(NSPoint(x: -8000, y: -8000))
panel.orderFrontRegardless()
grid.selectionIndexPaths = [IndexPath(item: 0, section: 0)]
RunLoop.main.run(until: Date().addingTimeInterval(2.0))
panel.contentView!.layoutSubtreeIfNeeded()
panel.displayIfNeeded()
CATransaction.flush()
RunLoop.main.run(until: Date().addingTimeInterval(0.5))

let panelSize = panel.frame.size
let panelImage: CGImage = {
    let s: CGFloat = 2
    let ctx = CGContext(data: nil, width: Int(panelSize.width * s), height: Int(panelSize.height * s),
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    // The visual-effect material renders as flat grey off-screen, so hide its own
    // layers (the ones not backing a subview) and draw the blur in drawPanel().
    let root = panel.contentView!.layer!
    let viewLayers = Set(panel.contentView!.subviews.compactMap { $0.layer.map(ObjectIdentifier.init) })
    for l in root.sublayers ?? [] where !viewLayers.contains(ObjectIdentifier(l)) { l.isHidden = true }
    root.backgroundColor = nil
    root.contents = nil
    root.render(in: ctx)
    return ctx.makeImage()!
}()
savePNG(panelImage, work.appendingPathComponent("panel.png"))

// Thumbnail image of item 0, used as the drag image.
let dragThumb: CGImage = render(CGSize(width: 176, height: 118), scale: 2) {
    let r = CGRect(x: 0, y: 0, width: 176, height: 118)
    fill(r, NSColor.white.withAlphaComponent(0.12), radius: 8)
    let a = selRect.width / selRect.height
    var ir = r.insetBy(dx: 4, dy: 4)
    let h = ir.width / a
    ir = CGRect(x: ir.minX, y: r.midY - h / 2, width: ir.width, height: h)
    draw(newShot, in: ir)
}

// MARK: - Animation

let panelRect = CGRect(x: (W - panelSize.width) / 2,
                       y: { // same placement rule as PanelController.positionOnActiveScreen (flipped)
                           let vfTop: CGFloat = 26, vfH = H - 26
                           let midY = vfTop + vfH / 2 - vfH * 0.08
                           return midY - panelSize.height / 2 }(),
                       width: panelSize.width, height: panelSize.height)
// First grid item centre, in canvas coordinates (header 44, inset 14/4).
let item0 = CGRect(x: panelRect.minX + 14, y: panelRect.minY + 44 + 4, width: 176, height: 118)

func scene(dropped: CGImage?, pop: CGFloat) {
    desktop()
    dashboard()
    chat(dropped: dropped, pop: pop)
}

// Blurred backdrop for the panel's HUD material (scene behind it doesn't change).
let backdrop: CGImage = {
    let base = render(CGSize(width: W, height: H), scale: 1) { scene(dropped: nil, pop: 0) }
    let ci = CIImage(cgImage: base).clampedToExtent()
        .applyingGaussianBlur(sigma: 30)
        .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    return CIContext().createCGImage(ci, from: CGRect(x: 0, y: 0, width: W, height: H))!
}()

func ease(_ t: CGFloat) -> CGFloat { let x = max(0, min(1, t)); return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
func seg(_ t: Double, _ a: Double, _ b: Double) -> CGFloat { CGFloat(max(0, min(1, (t - a) / (b - a)))) }

func keycap(_ label: String, alpha: CGFloat) {
    guard alpha > 0 else { return }
    let size: CGFloat = 26
    let w = textWidth(label, size, weight: .semibold) + 48
    let r = CGRect(x: (W - w) / 2, y: H - 110, width: w, height: 56)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    withShadow(18, 0.3) { fill(r, NSColor.black.withAlphaComponent(0.78), radius: 14) }
    text(label, CGPoint(x: r.minX + 24, y: r.minY + 11), size, .white, weight: .semibold)
    NSGraphicsContext.restoreGraphicsState()
}

func cursor(_ p: CGPoint, crosshair: Bool) {
    let c = crosshair ? NSCursor.crosshair : NSCursor.arrow
    let img = c.image, hs = c.hotSpot
    img.draw(in: CGRect(x: p.x - hs.x, y: p.y - hs.y, width: img.size.width, height: img.size.height),
             from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

func drawPanel(alpha: CGFloat) {
    guard alpha > 0 else { return }
    let ctx = NSGraphicsContext.current!.cgContext
    NSGraphicsContext.saveGraphicsState()
    ctx.setAlpha(alpha)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let path = NSBezierPath(roundedRect: panelRect, xRadius: 14, yRadius: 14)
    withShadow(40, 0.45, dy: 18) { NSColor.black.setFill(); path.fill() }
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    if let crop = backdrop.cropping(to: panelRect) { draw(crop, in: panelRect) }
    fill(panelRect, rgb(0x1C1C1E, 0.86))
    draw(panelImage, in: panelRect)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.12).setStroke()
    NSBezierPath(roundedRect: panelRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14).stroke()
    ctx.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()
}

let start = CGPoint(x: 1010, y: 690)
let selA = CGPoint(x: selRect.minX, y: selRect.minY)
let selB = CGPoint(x: selRect.maxX, y: selRect.maxY)
let rest = CGPoint(x: 1030, y: 560)
let grab = CGPoint(x: item0.midX + 10, y: item0.midY + 6)
let dropAt = CGPoint(x: chatRect.minX + 200, y: chatRect.maxY - 120)
let thumbCorner: CGRect = {
    let s = min(220 / selRect.width, 150 / selRect.height)
    let sz = CGSize(width: selRect.width * s, height: selRect.height * s)
    return CGRect(x: W - sz.width - 20, y: H - sz.height - 20, width: sz.width, height: sz.height)
}()

func frame(_ t: Double) {
    let dropped = t >= 5.3
    scene(dropped: dropped ? newShot : nil, pop: dropped ? seg(t, 5.3, 5.55) : 0)

    // ⇧⌘4 selection
    if t >= 0.9 && t < 1.75 {
        let p = lerp(selA, selB, ease(seg(t, 0.95, 1.65)))
        let r = CGRect(x: selA.x, y: selA.y, width: p.x - selA.x, height: p.y - selA.y)
        fill(r, NSColor.white.withAlphaComponent(0.18))
        NSColor.white.withAlphaComponent(0.9).setStroke()
        NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let lbl = "\(Int(r.width * 2)) × \(Int(r.height * 2))"
        text(lbl, CGPoint(x: p.x + 14, y: p.y + 8), 11, .black, weight: .medium)
    }
    // shutter flash
    if t >= 1.75 && t < 2.05 { fill(CGRect(x: 0, y: 0, width: W, height: H), NSColor.white.withAlphaComponent(0.55 * (1 - seg(t, 1.75, 2.05)))) }

    // Boardshot corner thumbnail
    if t >= 1.85 && t < 3.15 {
        let a = seg(t, 1.85, 2.03)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(a)
        let path = NSBezierPath(roundedRect: thumbCorner, xRadius: 10, yRadius: 10)
        withShadow(20, 0.35) { NSColor.black.setFill(); path.fill() }
        NSGraphicsContext.saveGraphicsState(); path.addClip(); draw(newShot, in: thumbCorner); NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.25).setStroke(); path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Panel: open at 3.2, fades out the moment the drag starts (as in the app)
    if t >= 3.2 && t < 4.35 { drawPanel(alpha: seg(t, 3.2, 3.36)) }

    keycap("⇧ ⌘ 4", alpha: t < 0.35 ? 0 : t < 0.5 ? seg(t, 0.35, 0.5) : t < 1.5 ? 1 : 1 - seg(t, 1.5, 1.7))
    keycap("⇧ ⌘ Space", alpha: t < 2.75 ? 0 : t < 2.9 ? seg(t, 2.75, 2.9) : t < 3.8 ? 1 : 1 - seg(t, 3.8, 4.0))

    // cursor path
    var p: CGPoint
    if t < 0.9 { p = lerp(start, selA, ease(seg(t, 0.1, 0.85))) }
    else if t < 1.75 { p = lerp(selA, selB, ease(seg(t, 0.95, 1.65))) }
    else if t < 3.3 { p = lerp(selB, rest, ease(seg(t, 1.9, 2.6))) }
    else if t < 4.3 { p = lerp(rest, grab, ease(seg(t, 3.4, 4.1))) }
    else if t < 5.3 { p = lerp(grab, dropAt, ease(seg(t, 4.35, 5.2))) }
    else { p = lerp(dropAt, CGPoint(x: dropAt.x + 160, y: dropAt.y + 40), ease(seg(t, 5.5, 6.3))) }

    // drag image follows the cursor
    if t >= 4.3 && t < 5.3 {
        let off = CGPoint(x: grab.x - item0.minX, y: grab.y - item0.minY)
        draw(dragThumb, in: CGRect(x: p.x - off.x, y: p.y - off.y, width: 176, height: 118), alpha: 0.85)
    }
    cursor(p, crosshair: t >= 0.9 && t < 1.75)
}

// MARK: - Encode GIF (identical consecutive frames are merged)

let fps = 20.0, duration = 7.6
let ow = Int(W * outScale), oh = Int(H * outScale)
var frames: [(CGImage, Double)] = []
var lastData: Data?
for i in 0..<Int(duration * fps) {
    let t = Double(i) / fps
    let img = render(CGSize(width: W, height: H), scale: outScale) { frame(t) }
    for st in [1.4, 2.4, 4.8, 6.5] where abs(t - st) < 0.001 { savePNG(img, work.appendingPathComponent("still-\(st).png")) }
    let data = img.dataProvider!.data! as Data
    if data == lastData { frames[frames.count - 1].1 += 1 / fps; continue }
    lastData = data
    frames.append((img, 1 / fps))
    if abs(t - 3.6) < 0.001 { savePNG(img, work.appendingPathComponent("still.png")) }
}
_ = (ow, oh)
let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (img, d) in frames {
    CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: d, kCGImagePropertyGIFUnclampedDelayTime: d]] as CFDictionary)
}
CGImageDestinationFinalize(dest)
print("frames: \(frames.count)")
