import AppKit
import SwiftUI

final class MainWindowRegistry {
    static let shared = MainWindowRegistry()
    var window: NSWindow?

    private init() {}
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configure(window: view.window)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        MainWindowRegistry.shared.window = window
        window.title = "MacApp Box"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alphaValue = 1
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
    }
}

extension Color {
    static let macAppBlue = Color(red: 0.04, green: 0.42, blue: 0.83)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    var rgbHex: UInt32 {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return 0xEAF0F6
        }
        let red = UInt32((max(0, min(1, color.redComponent)) * 255).rounded())
        let green = UInt32((max(0, min(1, color.greenComponent)) * 255).rounded())
        let blue = UInt32((max(0, min(1, color.blueComponent)) * 255).rounded())
        return (red << 16) | (green << 8) | blue
    }
}

enum AppTypography {
    private static let chineseKey = "MacAppBox.chineseFont"
    private static let latinKey = "MacAppBox.latinFont"

    static var chineseFamily: String {
        UserDefaults.standard.string(forKey: chineseKey) ?? "__system__"
    }

    static var latinFamily: String {
        UserDefaults.standard.string(forKey: latinKey) ?? "__system__"
    }

    static func save(chinese: String, latin: String) {
        UserDefaults.standard.set(chinese, forKey: chineseKey)
        UserDefaults.standard.set(latin, forKey: latinKey)
    }

    static func font(named name: String, size: CGFloat, weight: Font.Weight) -> Font {
        if name == "__system__" || NSFont(name: name, size: size) == nil {
            return .system(size: size, weight: weight)
        }
        return .custom(name, size: size).weight(weight)
    }
}

enum FontCatalog {
    static let families: [String] = {
        let names = NSFontManager.shared.availableFontFamilies
            .filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return ["__system__"] + names
    }()

    static func displayName(_ name: String) -> String {
        guard name != "__system__" else { return "系统默认" }
        return NSFontManager.shared.localizedName(forFamily: name, face: nil)
    }

    static let chineseSuggestions: [String] = {
        [
            "PingFang SC",
            "Songti SC",
            "Kaiti SC",
            "Heiti SC",
            "STSong",
            "Microsoft YaHei"
        ].filter { families.contains($0) }
    }()

    static let latinSuggestions: [String] = {
        [
            "SF Pro",
            "Helvetica Neue",
            "Times New Roman",
            "Georgia",
            "Arial",
            "Menlo"
        ].filter { families.contains($0) }
    }()

    static func allFamilies(excluding suggestions: [String]) -> [String] {
        families.filter {
            $0 != "__system__" && !suggestions.contains($0)
        }
    }
}

extension Font {
    static func app(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppTypography.font(
            named: AppTypography.chineseFamily,
            size: size,
            weight: weight
        )
    }

    static func appLatin(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppTypography.font(
            named: AppTypography.latinFamily,
            size: size,
            weight: weight
        )
    }
}

struct BilingualText: View {
    let value: String
    var size: CGFloat
    var weight: Font.Weight = .regular
    var chineseFamily: String?
    var latinFamily: String?

    init(
        _ value: String,
        size: CGFloat,
        weight: Font.Weight = .regular,
        chineseFamily: String? = nil,
        latinFamily: String? = nil
    ) {
        self.value = value
        self.size = size
        self.weight = weight
        self.chineseFamily = chineseFamily
        self.latinFamily = latinFamily
    }

    var body: some View {
        Text(attributedValue)
    }

    private var attributedValue: AttributedString {
        var result = AttributedString()
        var buffer = ""
        var previousIsCJK: Bool?

        func append(_ text: String, isCJK: Bool) {
            guard !text.isEmpty else { return }
            var run = AttributedString(text)
            run.font = isCJK
                ? AppTypography.font(
                    named: chineseFamily ?? AppTypography.chineseFamily,
                    size: size,
                    weight: weight
                )
                : AppTypography.font(
                    named: latinFamily ?? AppTypography.latinFamily,
                    size: size,
                    weight: weight
                )
            result.append(run)
        }

        for character in value {
            let isCJK = character.unicodeScalars.contains { scalar in
                switch scalar.value {
                case 0x2E80...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF:
                    return true
                default:
                    return false
                }
            }
            if previousIsCJK == nil || previousIsCJK == isCJK {
                buffer.append(character)
            } else {
                append(buffer, isCJK: previousIsCJK!)
                buffer = String(character)
            }
            previousIsCJK = isCJK
        }
        if let previousIsCJK {
            append(buffer, isCJK: previousIsCJK)
        }
        return result
    }
}

struct SymbolBadge: View {
    let symbol: String
    var size: CGFloat = 14
    var color: Color = .secondary

    var body: some View {
        Image(systemName: symbol)
            .font(.app(size, weight: .semibold))
            .foregroundStyle(color)
    }
}
