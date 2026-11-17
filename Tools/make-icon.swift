// Draws MacKit's app icon: the fingerprint grid, with the changed cells
// spelling an M. Run from the repository root:
//
//     swift Tools/make-icon.swift
//
import AppKit

let outputFolder = URL(filePath: "MacKit/Assets.xcassets/AppIcon.appiconset")

// 1 = a changed setting (lit), 0 = stock.
let pattern: [[Int]] = [
    [1, 0, 0, 0, 1],
    [1, 1, 0, 1, 1],
    [1, 0, 1, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
]

func drawIcon(in context: CGContext, size: CGFloat) {
    let scale = size / 1024
    context.scaleBy(x: scale, y: scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // The standard macOS icon body: an 824pt rounded square on a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.32))
    context.addPath(bodyPath)
    context.setFillColor(CGColor(gray: 0.1, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let graphite = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: 0.205, green: 0.205, blue: 0.22, alpha: 1),
        CGColor(srgbRed: 0.075, green: 0.075, blue: 0.085, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(graphite, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // A hairline of light along the top edge.
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    context.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.12))
    context.setLineWidth(4)
    context.strokePath()
    context.restoreGState()

    let cell: CGFloat = 100
    let gap: CGFloat = 28
    let grid = cell * 5 + gap * 4
    let origin = CGPoint(x: (1024 - grid) / 2, y: (1024 - grid) / 2)
    let ember = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: 1.0, green: 0.56, blue: 0.22, alpha: 1),
        CGColor(srgbRed: 0.93, green: 0.33, blue: 0.04, alpha: 1),
    ] as CFArray, locations: [0, 1])!

    for (row, cells) in pattern.enumerated() {
        for (column, lit) in cells.enumerated() {
            // Row 0 is the top of the M; Core Graphics draws from the bottom.
            let rect = CGRect(
                x: origin.x + CGFloat(column) * (cell + gap),
                y: origin.y + CGFloat(4 - row) * (cell + gap),
                width: cell, height: cell
            )
            let path = CGPath(roundedRect: rect, cornerWidth: 25, cornerHeight: 25, transform: nil)
            context.saveGState()
            context.addPath(path)
            if lit == 1 {
                context.clip()
                context.drawLinearGradient(ember, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
            } else {
                context.setFillColor(CGColor(gray: 1, alpha: 0.085))
                context.fillPath()
            }
            context.restoreGState()
        }
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    drawIcon(in: graphics.cgContext, size: CGFloat(size))
    graphics.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try png(size: points * scale).write(to: outputFolder.appending(path: name))
    images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: outputFolder.appending(path: "Contents.json"))
print("Wrote \(images.count) icon sizes to \(outputFolder.path())")
