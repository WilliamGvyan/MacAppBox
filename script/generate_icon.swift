import AppKit

let outputDirectory = CommandLine.arguments.dropFirst().first
    ?? FileManager.default.currentDirectoryPath + "/Resources/AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = CGFloat(size) * 0.055
    let body = canvas.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(size) * 0.22
    let bodyPath = CGPath(
        roundedRect: body,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()

    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.22, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.025, green: 0.34, blue: 0.68, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: body.minX, y: body.maxY),
        end: CGPoint(x: body.maxX, y: body.minY),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.28).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: body.maxX * 0.78, y: body.maxY * 0.82),
        startRadius: 0,
        endCenter: CGPoint(x: body.maxX * 0.78, y: body.maxY * 0.82),
        endRadius: body.width * 0.62,
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -CGFloat(size) * 0.012),
        blur: CGFloat(size) * 0.035,
        color: NSColor.black.withAlphaComponent(0.3).cgColor
    )
    context.addPath(bodyPath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
    context.setLineWidth(max(1, CGFloat(size) * 0.006))
    context.strokePath()
    context.restoreGState()

    let tileSize = CGFloat(size) * 0.19
    let gap = CGFloat(size) * 0.065
    let total = tileSize * 2 + gap
    let startX = (CGFloat(size) - total) / 2
    let startY = (CGFloat(size) - total) / 2

    let tileColors = [
        NSColor.white.withAlphaComponent(0.96),
        NSColor(calibratedRed: 0.52, green: 0.82, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.40, green: 0.68, blue: 1, alpha: 1),
        NSColor.white.withAlphaComponent(0.78)
    ]

    for row in 0..<2 {
        for column in 0..<2 {
            let rect = CGRect(
                x: startX + CGFloat(column) * (tileSize + gap),
                y: startY + CGFloat(row) * (tileSize + gap),
                width: tileSize,
                height: tileSize
            )
            let tilePath = CGPath(
                roundedRect: rect,
                cornerWidth: tileSize * 0.28,
                cornerHeight: tileSize * 0.28,
                transform: nil
            )
            context.addPath(tilePath)
            context.setFillColor(tileColors[row * 2 + column].cgColor)
            context.fillPath()
        }
    }

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode icon")
    }
    try data.write(to: outputURL.appendingPathComponent(name))
}
