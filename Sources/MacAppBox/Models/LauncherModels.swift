import AppKit
import Foundation

enum PlatformKind: String, CaseIterable, Codable, Identifiable {
    case macOS
    case windows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .macOS: "macOS"
        case .windows: "Windows"
        }
    }

    var symbol: String {
        switch self {
        case .macOS: "apple.logo"
        case .windows: "rectangle.grid.2x2.fill"
        }
    }
}

enum AppOrigin: String, Codable {
    case macOS
    case windows
    case selfMade
    case thirdParty
}

struct LauncherApp: Identifiable {
    let id: String
    let name: String
    let path: String
    let platform: PlatformKind
    let origin: AppOrigin
    let icon: NSImage
    let isWindowsUtility: Bool
    let hostName: String?
}

struct AppCategory: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var isBuiltIn: Bool
    var isNameLocked: Bool

    init(
        id: String,
        name: String,
        isBuiltIn: Bool,
        isNameLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isNameLocked = isNameLocked
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isBuiltIn
        case isNameLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        isNameLocked = try container.decodeIfPresent(Bool.self, forKey: .isNameLocked) ?? false
    }

    static let unclassified = AppCategory(
        id: "__unclassified__",
        name: "未分类软件",
        isBuiltIn: true,
        isNameLocked: false
    )

    static let autoClassified = AppCategory(
        id: "__auto-classified__",
        name: "自动分类",
        isBuiltIn: true,
        isNameLocked: false
    )

    static let essentials = AppCategory(
        id: "__essentials__",
        name: "常用软件",
        isBuiltIn: true,
        isNameLocked: false
    )

    static let thirdParty = AppCategory(
        id: "third-party",
        name: "第三方软件",
        isBuiltIn: true
    )

    static let defaults: [AppCategory] = [
        AppCategory(id: "frequently-used", name: "常用推荐", isBuiltIn: true),
        .autoClassified,
        .essentials,
        AppCategory(id: "learning", name: "学习效率", isBuiltIn: true),
        AppCategory(id: "audio", name: "音频娱乐", isBuiltIn: true),
        AppCategory(id: "development", name: "软件开发", isBuiltIn: true),
        AppCategory(id: "self-made", name: "自研软件", isBuiltIn: true),
        .thirdParty,
        AppCategory(id: "system", name: "系统软件", isBuiltIn: true),
        .unclassified
    ]
}

struct AppFolder: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var categoryID: String
    var platform: PlatformKind
    var appIDs: [String]
}

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: "简体中文"
        case .english: "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .chinese: "zh-Hans"
        case .english: "en"
        }
    }
}

enum AppFontStyle: String, CaseIterable, Codable, Identifiable {
    case system
    case yahei
    case times

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统字体"
        case .yahei: "微软雅黑"
        case .times: "新罗马"
        }
    }
}

enum AppThemePreset: String, CaseIterable, Codable, Identifiable {
    case system
    case frost
    case ocean
    case forest
    case sakura
    case sand
    case graphite
    case midnight
    case violet
    case terracotta
    case celadon
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统原生"
        case .frost: "雾白"
        case .ocean: "海盐蓝"
        case .forest: "森林"
        case .sakura: "樱花"
        case .sand: "暖沙"
        case .graphite: "石墨"
        case .midnight: "午夜"
        case .violet: "星云紫"
        case .terracotta: "赤陶"
        case .celadon: "青瓷"
        case .amber: "琥珀"
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .system: 0x0B66C3
        case .frost: 0x4D6F86
        case .ocean: 0x1778A8
        case .forest: 0x2F7451
        case .sakura: 0xC75B7A
        case .sand: 0x9A6A3A
        case .graphite: 0x59616D
        case .midnight: 0x4A78C2
        case .violet: 0x7452B5
        case .terracotta: 0xB4533C
        case .celadon: 0x4E7D73
        case .amber: 0xB47716
        }
    }

    var surfaceHex: UInt32 {
        switch self {
        case .system: 0xEAF0F6
        case .frost: 0xEEF2F5
        case .ocean: 0xE4F1F6
        case .forest: 0xE8F0E8
        case .sakura: 0xF8EBEE
        case .sand: 0xF5EEE3
        case .graphite: 0xE7E9EC
        case .midnight: 0x182134
        case .violet: 0xF0EAF7
        case .terracotta: 0xF7EBE7
        case .celadon: 0xE8F1EE
        case .amber: 0xF7EFDC
        }
    }
}

enum AppBackgroundKind: String, CaseIterable, Codable, Identifiable {
    case material
    case frostedGlass
    case transparent
    case wallpaper
    case wallpaperBlur
    case lightGlass
    case darkGlass
    case gradient
    case solid
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .material: "主题材质"
        case .frostedGlass: "毛玻璃"
        case .transparent: "透明"
        case .wallpaper: "壁纸"
        case .wallpaperBlur: "壁纸模糊"
        case .lightGlass: "浅色玻璃"
        case .darkGlass: "深色玻璃"
        case .gradient: "主题渐变"
        case .solid: "纯色"
        case .image: "图片"
        }
    }

    var symbol: String {
        switch self {
        case .material: "circle.hexagongrid.fill"
        case .frostedGlass: "rectangle.on.rectangle.angled"
        case .transparent: "square.dashed"
        case .wallpaper: "photo.on.rectangle"
        case .wallpaperBlur: "photo.on.rectangle.angled"
        case .lightGlass: "sun.max"
        case .darkGlass: "moon"
        case .gradient: "circle.lefthalf.filled"
        case .solid: "paintpalette"
        case .image: "photo"
        }
    }
}

enum AppInsertionEdge {
    case leading
    case trailing
}

struct SavedLauncherState: Codable {
    var categories: [AppCategory]
    var categorySets: [String: [AppCategory]]?
    var assignments: [String: String]
    var folders: [AppFolder]
    var itemOrders: [String: [String]]?
    var hiddenAppIDs: [String]
    var showWindowsUtilities: Bool
    var showNames: Bool
    var iconScale: Double
    var appearanceMode: AppearanceMode
    var fontStyle: AppFontStyle?
    var theme: AppThemePreset?
    var chineseFontName: String?
    var latinFontName: String?
    var fontScale: Double?
    var fontSize: Double?
    var useCustomFontColor: Bool?
    var fontColorHex: UInt32?
    var layoutSnapshots: [LayoutSnapshot]?
    var launchStats: [String: LaunchStat]?
    var recommendationsEnabled: Bool?
    var windowsCategoriesReset: Bool?
    var backgroundKind: AppBackgroundKind?
    var backgroundColorHex: UInt32?
    var backgroundImagePath: String?
    var wallpaperPath: String?
    var backgroundOpacity: Double?
    var wallpaperBlurRadius: Double?
    var dragHoldDuration: Double?
    var gridColumnCount: Int?
    var gridRowCount: Int?
    var showAllSidebarCategories: Bool?
    var sidebarUsesCustomColor: Bool?
    var sidebarColorHex: UInt32?
    var sidebarFontSize: Double?
    var sidebarWidth: Double?
    var sidebarUsesMainBackground: Bool?
    var sidebarUsesMainFontColor: Bool?
    var sidebarFontColorHex: UInt32?
    var sidebarUsesMainFonts: Bool?
    var sidebarChineseFontName: String?
    var sidebarLatinFontName: String?
    var sidebarUsesMainAccent: Bool?
    var sidebarAccentColorHex: UInt32?
    var categoryAssignmentDates: [String: [String: Date]]?
    var categoryStatisticsStartedAt: Date?
    var automaticClassificationEnabled: Bool?
    var autoClassifiedAppIDs: [String]?
    var autoClassificationExcludedAppIDs: [String]?
    var autoClassificationReasons: [String: String]?
    var essentialAppIDs: [String]?
    var selectionMemory: [String]?
    var classificationReferenceColumns: Int?
    var appLanguage: AppLanguage?
}

struct LayoutSnapshot: Identifiable, Codable {
    var id: String
    var name: String?
    var createdAt: Date
    var categories: [AppCategory]
    var categorySets: [String: [AppCategory]]?
    var assignments: [String: String]
    var folders: [AppFolder]
    var itemOrders: [String: [String]]
    var gridColumnCount: Int?
    var gridRowCount: Int?
}

struct CategoryUsageSummary: Identifiable {
    let id: String
    let name: String
    let appCount: Int
    let newestAssignment: Date?
}

struct AppCategoryDateRecord: Identifiable {
    let id: String
    let name: String
    let date: Date
}

struct AutoClassifiedTextEntry: Identifiable {
    let id: String
    let name: String
    let reason: String?
}

struct AutoClassificationTextGroup: Identifiable {
    let id: String
    let title: String
    let entries: [AutoClassifiedTextEntry]
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case sidebar
    case layout
    case categories
    case library
    case language

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: "侧边栏布局"
        case .layout: "主界面布局"
        case .categories: "软件分类设置"
        case .library: "资源库与扫描"
        case .language: "语言"
        }
    }

    var symbol: String {
        switch self {
        case .sidebar: "sidebar.left"
        case .layout: "rectangle.grid.2x2.fill"
        case .categories: "square.grid.2x2.fill"
        case .library: "externaldrive.fill"
        case .language: "globe"
        }
    }
}

struct LaunchStat: Codable, Hashable {
    var count: Int
    var lastLaunched: Date
    var firstLaunched: Date?
    var launchDates: [Date]?
    var activeDayKeys: [String]?

    init(
        count: Int,
        lastLaunched: Date,
        firstLaunched: Date? = nil,
        launchDates: [Date]? = nil,
        activeDayKeys: [String]? = nil
    ) {
        self.count = count
        self.lastLaunched = lastLaunched
        self.firstLaunched = firstLaunched
        self.launchDates = launchDates
        self.activeDayKeys = activeDayKeys
    }
}

struct CachedLauncherApp: Codable {
    let id: String
    let name: String
    let path: String
    let platform: PlatformKind
    let origin: AppOrigin
    let isWindowsUtility: Bool
    let hostName: String?

    init(_ app: LauncherApp) {
        id = app.id
        name = app.name
        path = app.path
        platform = app.platform
        origin = app.origin
        isWindowsUtility = app.isWindowsUtility
        hostName = app.hostName
    }
}

struct CachedInventory: Codable {
    var generatedAt: Date
    var apps: [CachedLauncherApp]
}

struct ScanResult {
    var apps: [LauncherApp]
    var filteredWindowsCount: Int
}

extension AppCategory {
    static let unclassifiedID = unclassified.id
    static let autoClassifiedID = autoClassified.id
    static let essentialsID = essentials.id
    static let selfMadeID = "self-made"
    static let thirdPartyID = "third-party"
    static let frequentlyUsedID = "frequently-used"
    static let learningID = "learning"
}

enum LauncherConstants {
    static let bundleIdentifier = "com.williamgvyan.MacAppBox"
    static let stateDirectoryName = "MacApp Box"
    static var selfMadeLibrary: String {
        NSString(string: "~/自研软件/程序库").expandingTildeInPath
    }
    static var thirdPartyLibrary: String {
        NSString(string: "~/第三方软件/程序库").expandingTildeInPath
    }
    static var selfMadeRegistry: String {
        let current = NSString(
            string: "~/Library/Application Support/自研软件/清单.txt"
        ).expandingTildeInPath
        if FileManager.default.fileExists(atPath: current) {
            return current
        }
        return NSString(
            string: "~/Applications/自研软件.app/Contents/Resources/apps.txt"
        ).expandingTildeInPath
    }
}
