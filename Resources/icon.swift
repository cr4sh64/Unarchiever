// Dessine l'icône : swift Resources/icon.swift <sortie.png>  (1024×1024)
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
func fill(_ path: NSBezierPath, _ top: UInt32, _ bottom: UInt32) {
    NSGradient(starting: color(bottom), ending: color(top))!.draw(in: path, angle: 90)
}
func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}
/// Ombre portée sous la forme : le dégradé seul n'en projette pas.
func shadowed(_ path: NSBezierPath, _ blur: CGFloat, _ dy: CGFloat, _ alpha: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: dy), blur: blur, color: color(0x000000, alpha).cgColor)
    color(0x000000).setFill()
    path.fill()
    ctx.restoreGState()
}

// Fond : carré arrondi standard macOS (824 px dans 1024, marge pour l'ombre).
let background = rounded(100, 100, 824, 824, 185)
shadowed(background, 28, -12, 0.35)
fill(background, 0x3A7BD5, 0x1E3C72)

// Boîte d'archive.
let box = rounded(262, 210, 500, 340, 36)
shadowed(box, 24, -10, 0.3)
fill(box, 0xF7B955, 0xE0861A)

// Fermeture éclair, ouverte en haut : le curseur est sous le couvercle.
color(0x7A4A12).setFill()
NSRect(x: 498, y: 210, width: 28, height: 320).fill()
color(0xFFE2A8).setFill()
var y: CGFloat = 228
var left = true
while y < 420 {
    NSRect(x: left ? 484 : 512, y: y, width: 28, height: 16).fill()
    left.toggle()
    y += 28
}
let slider = rounded(484, 420, 56, 92, 16)
shadowed(slider, 8, -3, 0.35)
fill(slider, 0xF7F7F7, 0xB8B8B8)
color(0x8C8C8C).setFill()
rounded(500, 436, 24, 44, 12).fill()

let lid = rounded(236, 520, 552, 96, 28)
shadowed(lid, 14, -6, 0.25)
fill(lid, 0xFFC96B, 0xEE9A2C)

// Flèche blanche qui sort de la boîte.
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 462, y: 640))
arrow.line(to: NSPoint(x: 562, y: 640))
arrow.line(to: NSPoint(x: 562, y: 742))
arrow.line(to: NSPoint(x: 642, y: 742))
arrow.line(to: NSPoint(x: 512, y: 868))
arrow.line(to: NSPoint(x: 382, y: 742))
arrow.line(to: NSPoint(x: 462, y: 742))
arrow.close()
shadowed(arrow, 16, -6, 0.3)
fill(arrow, 0xFFFFFF, 0xE6EEF8)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
