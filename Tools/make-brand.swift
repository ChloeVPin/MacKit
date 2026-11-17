// Draws MacKit's brand images: the wordmark for the README and the social
// preview. The lettering is Allo by Josh Puckett (SIL Open Font License,
// see Brand/Allo/OFL.txt). The app itself uses system fonts only.
// Run from the repository root:
//
//     swift Tools/make-brand.swift
//
import AppKit
import CoreText

for name in ["Allo-Bold", "Allo-Regular"] {
    let url = URL(filePath: "Brand/Allo/\(name).otf") as CFURL
    guard CTFontManagerRegisterFontsForURL(url, .process, nil) else { fatalError("Couldn't load \(name)") }
}
func allo(_ name: String, _ size: CGFloat) -> NSFont { NSFont(name: name, size: size)! }

let icon = NSImage(contentsOfFile: "MacKit/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")!

func image(width: Int, height: Int, draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.current?.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

func text(_ string: String, _ font: NSFont, _ color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .kern: kern])
}

/// Draws a line with its cap height centred on `midY`.
func draw(_ line: NSAttributedString, x: CGFloat, capMiddle midY: CGFloat) {
    let font = line.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
    line.draw(at: NSPoint(x: x, y: midY - font.capHeight / 2 + font.descender))
}

// The wordmark: icon and name on a clear background, for light and dark pages.
for (file, ink) in [("wordmark-light", NSColor(white: 0.09, alpha: 1)), ("wordmark-dark", NSColor.white)] {
    let name = text("MacKit", allo("Allo-Bold", 150), ink, kern: -3)
    let width = Int(220 + 36 + ceil(name.size().width) + 8)
    let data = image(width: width, height: 220) {
        icon.draw(in: NSRect(x: 0, y: 0, width: 220, height: 220))
        draw(name, x: 256, capMiddle: 110)
    }
    try data.write(to: URL(filePath: "Docs/\(file).png"))
}

// The social preview GitHub shows when the repository is shared.
let social = image(width: 1280, height: 640) {
    NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1280, height: 640).fill()
    let name = text("MacKit", allo("Allo-Bold", 132), .white, kern: -3)
    let line = text("Tune your Mac from one calm window.", allo("Allo-Regular", 35), NSColor(white: 0.68, alpha: 1))
    let block = 300 + 56 + max(name.size().width, line.size().width)
    let left = (1280 - block) / 2
    icon.draw(in: NSRect(x: left, y: 170, width: 300, height: 300))
    draw(name, x: left + 356, capMiddle: 356)
    draw(line, x: left + 360, capMiddle: 262)
}
try social.write(to: URL(filePath: "Docs/social.png"))
print("Wrote Docs/wordmark-light.png, Docs/wordmark-dark.png, Docs/social.png")
