import AppKit
import Foundation

enum GeneratedAppIcon {
    private static let symbols = [
        "shippingbox.fill",
        "terminal.fill",
        "waveform.path.ecg",
        "cpu",
        "chart.xyaxis.line",
        "rectangle.3.group.fill",
        "sparkles",
        "bolt.fill",
        "gearshape.2.fill",
        "externaldrive.fill",
        "network",
        "function"
    ]

    private static let palettes: [(NSColor, NSColor)] = [
        (
            NSColor(calibratedRed: 0.04, green: 0.38, blue: 0.76, alpha: 1),
            NSColor(calibratedRed: 0.18, green: 0.73, blue: 0.88, alpha: 1)
        ),
        (
            NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.32, alpha: 1),
            NSColor(calibratedRed: 0.42, green: 0.75, blue: 0.44, alpha: 1)
        ),
        (
            NSColor(calibratedRed: 0.48, green: 0.24, blue: 0.62, alpha: 1),
            NSColor(calibratedRed: 0.76, green: 0.45, blue: 0.82, alpha: 1)
        ),
        (
            NSColor(calibratedRed: 0.68, green: 0.26, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.28, alpha: 1)
        ),
        (
            NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.42, alpha: 1),
            NSColor(calibratedRed: 0.29, green: 0.52, blue: 0.76, alpha: 1)
        ),
        (
            NSColor(calibratedRed: 0.45, green: 0.32, blue: 0.16, alpha: 1),
            NSColor(calibratedRed: 0.78, green: 0.61, blue: 0.28, alpha: 1)
        )
    ]

    static func icon(for url: URL, name: String) -> NSImage {
        if hasDeclaredIcon(url) {
            let workspaceIcon = NSWorkspace.shared.icon(forFile: url.path)
            if isMeaningfullyColored(workspaceIcon) {
                workspaceIcon.size = NSSize(width: 256, height: 256)
                return workspaceIcon
            }
        }
        return generatedIcon(name: name, seed: url.path)
    }

    private static func hasDeclaredIcon(_ url: URL) -> Bool {
        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else { return false }
        let resources = url.appendingPathComponent("Contents/Resources", isDirectory: true)

        if let iconFile = info["CFBundleIconFile"] as? String, !iconFile.isEmpty {
            let candidates = [
                resources.appendingPathComponent(iconFile),
                resources.appendingPathComponent(iconFile + ".icns")
            ]
            if candidates.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                return true
            }
        }

        if info["CFBundleIconName"] != nil {
            return FileManager.default.fileExists(
                atPath: resources.appendingPathComponent("Assets.car").path
            )
        }
        return false
    }

    private static func isMeaningfullyColored(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let color = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2),
              let rgb = color.usingColorSpace(.deviceRGB) else {
            return false
        }
        return rgb.saturationComponent > 0.045 || abs(rgb.redComponent - rgb.blueComponent) > 0.05
    }

    private static func generatedIcon(name: String, seed: String) -> NSImage {
        let checksum = seed.unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7FFFFFFF
        }
        let palette = palettes[checksum % palettes.count]
        let symbolName = symbols[checksum % symbols.count]
        let size = CGFloat(256)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.shouldAntialias = true
        NSGraphicsContext.current?.imageInterpolation = .high

        let outer = NSRect(x: 10, y: 10, width: size - 20, height: size - 20)
        let body = NSBezierPath(roundedRect: outer, xRadius: 52, yRadius: 52)
        NSGradient(
            starting: palette.0,
            ending: palette.1
        )?.draw(in: body, angle: -52)

        NSColor.white.withAlphaComponent(0.18).setStroke()
        body.lineWidth = 2
        body.stroke()

        let shine = NSBezierPath(
            ovalIn: NSRect(x: 38, y: 122, width: 180, height: 112)
        )
        NSGradient(
            starting: NSColor.white.withAlphaComponent(0.22),
            ending: NSColor.white.withAlphaComponent(0)
        )?.draw(in: shine, angle: -90)

        if let symbol = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: name
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 104, weight: .semibold)
        ) {
            let symbolSize = symbol.size
            let rect = NSRect(
                x: (size - symbolSize.width) / 2,
                y: (size - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol.isTemplate = true
            NSColor.white.withAlphaComponent(0.94).set()
            symbol.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
        return image
    }
}
