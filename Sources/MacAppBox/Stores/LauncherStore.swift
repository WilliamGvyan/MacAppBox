import AppKit
import Combine
import CoreImage
import Darwin
import Foundation
import ImageIO
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var apps: [LauncherApp] = []
    @Published private(set) var categorySets: [PlatformKind: [AppCategory]] = [
        .macOS: AppCategory.defaults,
        .windows: AppCategory.defaults
    ]
    @Published private(set) var assignments: [String: String] = [:]
    @Published private(set) var folders: [AppFolder] = []
    @Published private(set) var itemOrders: [String: [String]] = [:]
    @Published private(set) var hiddenAppIDs: Set<String> = []
    @Published private(set) var filteredWindowsCount = 0
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanSummary = "等待扫描"
    @Published private(set) var layoutSnapshots: [LayoutSnapshot] = []
    @Published private(set) var lastLayoutMessage = ""
    @Published private(set) var launchStats: [String: LaunchStat] = [:]
    @Published var selectedSystem: PlatformKind = .macOS
    @Published var selectedCategoryID = AppCategory.unclassifiedID
    @Published var searchText = ""
    @Published var selection: Set<String> = []
    @Published var isSelectionMode = false
    @Published var isSearchFocused = false {
        didSet { ensureValidCategorySelection() }
    }
    @Published var recommendationsEnabled = true {
        didSet {
            ensureValidCategorySelection()
            save()
        }
    }
    @Published var backgroundKind: AppBackgroundKind = .material {
        didSet {
            refreshWallpaperRender()
            save()
        }
    }
    @Published var backgroundColorHex: UInt32 = 0xEAF0F6 {
        didSet { save() }
    }
    @Published var backgroundImagePath: String? {
        didSet { save() }
    }
    @Published var wallpaperPath: String? {
        didSet { save() }
    }
    @Published var backgroundOpacity = 1.0 {
        didSet { save() }
    }
    @Published var wallpaperBlurRadius = 26.0 {
        didSet {
            refreshWallpaperRender()
            save()
        }
    }
    @Published var dragHoldDuration = 0.35 {
        didSet { save() }
    }
    @Published var showWindowsUtilities = false {
        didSet { save() }
    }
    @Published var showNames = true {
        didSet { save() }
    }
    @Published var iconScale = 1.0 {
        didSet { save() }
    }
    @Published var gridColumnCount = 0 {
        didSet { save() }
    }
    @Published var gridRowCount = 0 {
        didSet { save() }
    }
    @Published var showAllSidebarCategories = false {
        didSet {
            ensureValidCategorySelection()
            save()
        }
    }
    @Published var sidebarUsesCustomColor = false {
        didSet { save() }
    }
    @Published var sidebarColorHex: UInt32 = 0xEAF0F6 {
        didSet { save() }
    }
    @Published var sidebarFontSize = 13.5 {
        didSet { save() }
    }
    @Published var sidebarWidth = 236.0 {
        didSet { save() }
    }
    @Published var sidebarUsesMainBackground = false {
        didSet { save() }
    }
    @Published var sidebarUsesMainFontColor = true {
        didSet { save() }
    }
    @Published var sidebarFontColorHex: UInt32 = 0x354052 {
        didSet { save() }
    }
    @Published var sidebarUsesMainFonts = true {
        didSet { save() }
    }
    @Published var sidebarChineseFontName = "__system__" {
        didSet { save() }
    }
    @Published var sidebarLatinFontName = "__system__" {
        didSet { save() }
    }
    @Published var sidebarUsesMainAccent = true {
        didSet { save() }
    }
    @Published var sidebarAccentColorHex: UInt32 = 0x0B66C3 {
        didSet { save() }
    }
    @Published private(set) var categoryAssignmentDates: [String: [String: Date]] = [:]
    @Published private(set) var categoryStatisticsStartedAt: Date?
    @Published var automaticClassificationEnabled = true {
        didSet {
            if automaticClassificationEnabled {
                applyAutomaticClassification()
            }
            save()
        }
    }
    @Published private(set) var autoClassifiedAppIDs: Set<String> = []
    @Published private(set) var autoClassificationExcludedAppIDs: Set<String> = []
    @Published private(set) var autoClassificationReasons: [String: String] = [:]
    @Published private(set) var essentialAppIDs: Set<String> = []
    @Published private(set) var selectionMemory: Set<String> = []
    @Published var classificationReferenceColumns = 3 {
        didSet { save() }
    }
    @Published private(set) var renderedWallpaper: NSImage?
    @Published var appearanceMode: AppearanceMode = .system {
        didSet { save() }
    }
    @Published var appLanguage: AppLanguage = .chinese {
        didSet { save() }
    }
    @Published var theme: AppThemePreset = .system {
        didSet { save() }
    }
    @Published var chineseFontName = "__system__" {
        didSet {
            AppTypography.save(
                chinese: chineseFontName,
                latin: latinFontName
            )
            save()
        }
    }
    @Published var latinFontName = "__system__" {
        didSet {
            AppTypography.save(
                chinese: chineseFontName,
                latin: latinFontName
            )
            save()
        }
    }
    @Published var useCustomFontColor = false {
        didSet { save() }
    }
    @Published var fontColorHex: UInt32 = 0x354052 {
        didSet { save() }
    }

    private var hasScanned = false
    private var windowsCategoriesReset = false
    private var isLoadingState = false
    private var cachedBackgroundImage: NSImage?
    private var backgroundImageCachePath: String?
    private var wallpaperRenderGeneration = 0
    private var wallpaperRenderWorkItem: DispatchWorkItem?
    private let stateSaveQueue = DispatchQueue(
        label: "com.williamgvyan.MacAppBox.state-save",
        qos: .utility
    )
    private let stateSaveGate = StateSaveGate()
    private var backgroundScanObserver: NSObjectProtocol?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    init() {
        load()
        loadInventoryCache()
        migrateWindowsCategoriesIfNeeded()
        backgroundScanObserver = NotificationCenter.default.addObserver(
            forName: .macAppBoxStartBackgroundScan,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIfNeeded()
            }
        }
    }

    var categories: [AppCategory] {
        get { categorySets[selectedSystem] ?? [] }
        set { categorySets[selectedSystem] = newValue }
    }

    var currentCategory: AppCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    var visibleCategories: [AppCategory] {
        categories.filter { category in
            if category.id == AppCategory.frequentlyUsedID {
                return recommendationsEnabled && isSearchFocused
            }
            if category.id == AppCategory.autoClassifiedID {
                return automaticClassificationEnabled ||
                    !autoClassifiedAppIDs.isEmpty ||
                    showAllSidebarCategories
            }
            if category.id == AppCategory.unclassifiedID {
                return unclassifiedCount > 0 || showAllSidebarCategories
            }
            return true
        }
    }

    var unclassifiedCount: Int {
        baseApps(for: selectedSystem)
            .filter { assignment(for: $0.id) == AppCategory.unclassifiedID }
            .count
    }

    var macOSInstalledCount: Int {
        baseApps(for: .macOS).count
    }

    var windowsInstalledCount: Int {
        baseApps(for: .windows).count
    }

    var currentFolders: [AppFolder] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        guard selectedCategoryID != AppCategory.frequentlyUsedID,
              selectedCategoryID != AppCategory.autoClassifiedID,
              selectedCategoryID != AppCategory.essentialsID else { return [] }
        return folders
            .filter {
                $0.categoryID == selectedCategoryID &&
                $0.platform == selectedSystem &&
                !$0.appIDs.isEmpty
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var currentApps: [LauncherApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let platformApps = baseApps(for: selectedSystem)

        if selectedCategoryID == AppCategory.frequentlyUsedID {
            let now = Date()
            return platformApps
                .compactMap { app -> (LauncherApp, LaunchRecommendation)? in
                    guard query.isEmpty ||
                        app.name.localizedCaseInsensitiveContains(query) else {
                        return nil
                    }
                    let recommendation = launchStats[app.id]?.recommendation(at: now)
                        ?? LaunchStat(count: 0, lastLaunched: .distantPast)
                            .recommendation(at: now)
                    guard recommendation.isEligible else { return nil }
                    return (app, recommendation)
                }
                .sorted { lhs, rhs in
                    if lhs.1.score != rhs.1.score {
                        return lhs.1.score > rhs.1.score
                    }
                    return lhs.1.lastLaunched > rhs.1.lastLaunched
                }
                .map(\.0)
        }

        if selectedCategoryID == AppCategory.autoClassifiedID {
            return platformApps
                .filter {
                    autoClassifiedAppIDs.contains($0.id) &&
                    (query.isEmpty ||
                        $0.name.localizedCaseInsensitiveContains(query) ||
                        ($0.hostName?.localizedCaseInsensitiveContains(query) ?? false))
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        if selectedCategoryID == AppCategory.essentialsID {
            return platformApps
                .filter {
                    essentialAppIDs.contains($0.id) &&
                    (query.isEmpty ||
                        $0.name.localizedCaseInsensitiveContains(query) ||
                        ($0.hostName?.localizedCaseInsensitiveContains(query) ?? false))
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        if !query.isEmpty {
            return platformApps
                .filter {
                    $0.name.localizedCaseInsensitiveContains(query) ||
                    ($0.hostName?.localizedCaseInsensitiveContains(query) ?? false)
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        let foldedIDs = Set(currentFolders.flatMap(\.appIDs))
        return platformApps
            .filter {
                assignment(for: $0.id) == selectedCategoryID &&
                !foldedIDs.contains($0.id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var currentItemCount: Int {
        currentFolders.count + currentApps.count
    }

    var accentColor: Color {
        Color(hex: theme.accentHex)
    }

    func localized(_ chinese: String, _ english: String) -> String {
        appLanguage == .english ? english : chinese
    }

    func settingsTitle(for pane: SettingsPane) -> String {
        switch pane {
        case .sidebar:
            localized("侧边栏布局", "Sidebar")
        case .layout:
            localized("主界面布局", "Main Layout")
        case .categories:
            localized("软件分类设置", "Categories")
        case .library:
            localized("资源库与扫描", "Library & Scanning")
        case .language:
            localized("语言", "Language")
        }
    }

    var surfaceColor: Color {
        Color(hex: theme.surfaceHex)
    }

    var fontColor: Color {
        useCustomFontColor ? Color(hex: fontColorHex) : .primary
    }

    var customBackgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var sidebarTextColor: Color {
        sidebarUsesMainFontColor
            ? fontColor
            : Color(hex: sidebarFontColorHex)
    }

    var sidebarAccentColor: Color {
        sidebarUsesMainAccent
            ? accentColor
            : Color(hex: sidebarAccentColorHex)
    }

    var effectiveSidebarChineseFontName: String {
        sidebarUsesMainFonts ? chineseFontName : sidebarChineseFontName
    }

    var effectiveSidebarLatinFontName: String {
        sidebarUsesMainFonts ? latinFontName : sidebarLatinFontName
    }

    func sidebarFont(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        AppTypography.font(
            named: effectiveSidebarChineseFontName,
            size: size,
            weight: weight
        )
    }

    func sidebarLatinFont(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        AppTypography.font(
            named: effectiveSidebarLatinFontName,
            size: size,
            weight: weight
        )
    }

    var backgroundImage: NSImage? {
        guard let backgroundImagePath else { return nil }
        if backgroundImageCachePath == backgroundImagePath,
           let cachedBackgroundImage {
            return cachedBackgroundImage
        }
        let image = NSImage(contentsOfFile: backgroundImagePath)
        cachedBackgroundImage = image
        backgroundImageCachePath = backgroundImagePath
        return image
    }

    var desktopWallpaper: NSImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return nil
        }
        return Self.downsampledImage(at: url.path, maxPixelSize: 1_800)
    }

    var selectedWallpaper: NSImage? {
        renderedWallpaper
    }

    private func refreshWallpaperRender() {
        guard backgroundKind == .wallpaper ||
            backgroundKind == .wallpaperBlur else {
            return
        }
        wallpaperRenderWorkItem?.cancel()
        wallpaperRenderGeneration += 1
        let generation = wallpaperRenderGeneration
        let selectedPath = wallpaperPath
        let screen = NSScreen.main
        let desktopPath = screen.flatMap {
            NSWorkspace.shared.desktopImageURL(for: $0)?.path
        }
        let blurRadius = backgroundKind == .wallpaperBlur
            ? wallpaperBlurRadius
            : 0

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let path = selectedPath ?? desktopPath
            let rendered = autoreleasepool {
                path.flatMap {
                    Self.renderedWallpaper(
                        at: $0,
                        blurRadius: blurRadius
                    )
                }
            }
            DispatchQueue.main.async {
                guard generation == self.wallpaperRenderGeneration else { return }
                self.renderedWallpaper = rendered
            }
        }
        wallpaperRenderWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.12,
            execute: workItem
        )
    }

    nonisolated private static func renderedWallpaper(
        at path: String,
        blurRadius: Double
    ) -> NSImage? {
        let maxPixelSize = blurRadius > 0 ? 1_600 : 2_400
        guard let thumbnail = downsampledCGImage(
            at: path,
            maxPixelSize: maxPixelSize
        ) else { return nil }
        let input = CIImage(cgImage: thumbnail)
        guard blurRadius > 0 else {
            let size = NSSize(width: thumbnail.width, height: thumbnail.height)
            return NSImage(cgImage: thumbnail, size: size)
        }
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(blurRadius * 0.62, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else {
            return nil
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(output, from: input.extent) else {
            return nil
        }
        context.clearCaches()
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: input.extent.width, height: input.extent.height)
        )
    }

    nonisolated private static func downsampledImage(
        at path: String,
        maxPixelSize: Int
    ) -> NSImage? {
        guard let cgImage = downsampledCGImage(
            at: path,
            maxPixelSize: maxPixelSize
        ) else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    nonisolated private static func downsampledCGImage(
        at path: String,
        maxPixelSize: Int
    ) -> CGImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        )
    }

    var currentLibraryItems: [LibraryItem] {
        if selectedCategoryID == AppCategory.frequentlyUsedID ||
            selectedCategoryID == AppCategory.autoClassifiedID {
            return currentApps.map(LibraryItem.app)
        }
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentApps.map(LibraryItem.app)
        }

        let foldersByToken = Dictionary(
            uniqueKeysWithValues: currentFolders.map { ("folder:\($0.id)", LibraryItem.folder($0)) }
        )
        let appsByToken = Dictionary(
            uniqueKeysWithValues: currentApps.map { ("app:\($0.id)", LibraryItem.app($0)) }
        )
        let available = foldersByToken.merging(appsByToken) { current, _ in current }
        let key = orderKey(platform: selectedSystem, categoryID: selectedCategoryID)
        let orderedTokens = (itemOrders[key] ?? []).filter { available[$0] != nil }
        let missingTokens = available.keys.filter { !orderedTokens.contains($0) }.sorted()
        return (orderedTokens + missingTokens).compactMap { available[$0] }
    }

    func refreshIfNeeded() {
        guard !hasScanned else { return }
        hasScanned = true
        beginBackgroundScan()
    }

    func refresh() {
        beginBackgroundScan()
    }

    private func beginBackgroundScan() {
        guard !isScanning else { return }
        isScanning = true
        selection.removeAll()
        isSelectionMode = false
        let cachedIcons = Dictionary(
            uniqueKeysWithValues: apps.map { ($0.id, $0.icon) }
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = autoreleasepool {
                Self.reducedScanResult(
                    AppScanner(cachedIcons: cachedIcons).scan()
                )
            }
            malloc_zone_pressure_relief(nil, 0)
            DispatchQueue.main.async {
                self?.applyScan(result)
            }
        }
    }

    nonisolated private static func reducedScanResult(
        _ result: ScanResult
    ) -> ScanResult {
        let reducedApps = result.apps.map { app in
            let icon: NSImage
            if let data = smallIconPNG(app.icon),
               let reduced = NSImage(data: data) {
                icon = reduced
            } else {
                icon = app.icon
            }
            return LauncherApp(
                id: app.id,
                name: app.name,
                path: app.path,
                platform: app.platform,
                origin: app.origin,
                icon: icon,
                isWindowsUtility: app.isWindowsUtility,
                hostName: app.hostName
            )
        }
        return ScanResult(
            apps: reducedApps,
            filteredWindowsCount: result.filteredWindowsCount
        )
    }

    private func applyScan(_ result: ScanResult) {
        apps = result.apps
        filteredWindowsCount = result.filteredWindowsCount

        for app in apps {
            let current = assignments[app.id]
            let needsAssignment = current == nil ||
                ((app.origin == .selfMade || app.origin == .thirdParty) &&
                    current == AppCategory.unclassifiedID)
            guard needsAssignment else { continue }

            let categoryID = preferredOriginCategoryID(for: app)
                ?? AppCategory.unclassifiedID
            assignments[app.id] = categoryID
            recordAssignment(appID: app.id, categoryID: categoryID)
        }
        normalizeAssignmentsForPlatforms()
        applyAutomaticClassification()

        let installedIDs = Set(apps.map(\.id))
        autoClassifiedAppIDs.formIntersection(installedIDs)
        essentialAppIDs.formIntersection(installedIDs)
        selectionMemory.formIntersection(installedIDs)
        autoClassifiedAppIDs = Set(autoClassifiedAppIDs.filter {
            let categoryID = assignment(for: $0)
            return categoryID != AppCategory.unclassifiedID &&
                categoryID != AppCategory.frequentlyUsedID &&
                categoryID != AppCategory.autoClassifiedID
        })
        autoClassificationReasons = autoClassificationReasons.filter {
            autoClassifiedAppIDs.contains($0.key)
        }
        folders = folders.compactMap { folder in
            var folder = folder
            folder.appIDs = folder.appIDs.filter {
                installedIDs.contains($0) &&
                assignment(for: $0) == folder.categoryID
            }
            return folder.appIDs.isEmpty ? nil : folder
        }

        hiddenAppIDs = hiddenAppIDs.intersection(installedIDs)
        isScanning = false
        ensureValidCategorySelection()
        lastScanSummary = scanSummary()
        saveInventoryCache {
            NotificationCenter.default.post(name: .macAppBoxScanFinished, object: nil)
        }
        save()
    }

    func app(withID id: String) -> LauncherApp? {
        apps.first { $0.id == id }
    }

    func assignment(for appID: String) -> String {
        assignments[appID] ?? AppCategory.unclassifiedID
    }

    func assignmentDate(for appID: String, categoryID: String) -> Date? {
        categoryAssignmentDates[appID]?[categoryID]
    }

    func assignmentHistory(for appID: String) -> [AppCategoryDateRecord] {
        let categoryNames = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0.name) }
        )
        return (categoryAssignmentDates[appID] ?? [:])
            .compactMap { categoryID, date in
                guard let name = categoryNames[categoryID] else { return nil }
                return AppCategoryDateRecord(
                    id: categoryID,
                    name: name,
                    date: date
                )
            }
            .sorted { $0.date > $1.date }
    }

    var categoryUsageSummaries: [CategoryUsageSummary] {
        let platformApps = baseApps(for: selectedSystem)
        return categories
            .filter {
                $0.id != AppCategory.frequentlyUsedID &&
                $0.id != AppCategory.autoClassifiedID
            }
            .map { category in
                let matchingApps: [LauncherApp]
                if category.id == AppCategory.essentialsID {
                    matchingApps = platformApps.filter {
                        essentialAppIDs.contains($0.id)
                    }
                } else {
                    matchingApps = platformApps.filter {
                        assignment(for: $0.id) == category.id
                    }
                }
                let newest = matchingApps
                    .compactMap { assignmentDate(for: $0.id, categoryID: category.id) }
                    .max()
                return CategoryUsageSummary(
                    id: category.id,
                    name: category.name,
                    appCount: matchingApps.count,
                    newestAssignment: newest
                )
            }
    }

    var autoClassificationGroups: [AutoClassificationTextGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let platformApps = baseApps(for: selectedSystem)
        let matchedApps = platformApps.filter {
            query.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.hostName?.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matchedApps) {
            assignment(for: $0.id)
        }
        return categories.compactMap { category in
            guard category.id != AppCategory.frequentlyUsedID,
                  category.id != AppCategory.autoClassifiedID,
                  category.id != AppCategory.essentialsID,
                  let apps = grouped[category.id],
                  !apps.isEmpty else { return nil }
            return AutoClassificationTextGroup(
                id: category.id,
                title: category.name,
                entries: apps
                    .sorted {
                        $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    }
                    .map {
                        AutoClassifiedTextEntry(
                            id: $0.id,
                            name: $0.name,
                            reason: autoClassificationReasons[$0.id]
                        )
                    }
            )
        }
    }

    private func recordAssignment(
        appID: String,
        categoryID: String,
        date: Date = Date()
    ) {
        guard categoryID != AppCategory.frequentlyUsedID,
              categoryID != AppCategory.autoClassifiedID else { return }
        var categoriesForApp = categoryAssignmentDates[appID] ?? [:]
        if categoriesForApp[categoryID] == nil {
            categoriesForApp[categoryID] = date
        }
        categoryAssignmentDates[appID] = categoriesForApp
    }

    private func migrateCategoryAssignmentDatesIfNeeded() {
        guard categoryAssignmentDates.isEmpty, !assignments.isEmpty else { return }
        let startedAt = categoryStatisticsStartedAt ?? Date()
        categoryStatisticsStartedAt = startedAt
        for (appID, categoryID) in assignments {
            recordAssignment(
                appID: appID,
                categoryID: categoryID,
                date: startedAt
            )
        }
    }

    func selectSystem(_ system: PlatformKind) {
        rememberCurrentSelectionIfNeeded()
        selectedSystem = system
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
    }

    func selectCategory(_ id: String) {
        rememberCurrentSelectionIfNeeded()
        selectedCategoryID = id
        selection.removeAll()
        isSelectionMode = false
    }

    func select(_ appID: String, extend: Bool) {
        guard isSelectionMode else { return }
        if extend {
            if selection.contains(appID) {
                selection.remove(appID)
            } else {
                selection.insert(appID)
            }
        } else {
            selection = [appID]
        }
    }

    func clearSelection() {
        selection.removeAll()
        isSelectionMode = false
    }

    func toggleSelectionMode() {
        if isSelectionMode {
            rememberCurrentSelectionIfNeeded()
            isSelectionMode = false
            selection.removeAll()
        } else {
            isSelectionMode = true
        }
    }

    func rememberCurrentSelectionIfNeeded() {
        let valid = selection.filter { app(withID: $0) != nil }
        guard !valid.isEmpty else { return }
        selectionMemory = Set(valid)
        save()
    }

    func clearSelectionMemory() {
        selectionMemory.removeAll()
        save()
    }

    func moveRememberedApps(to categoryID: String) {
        guard !selectionMemory.isEmpty,
              categoryID != AppCategory.frequentlyUsedID,
              categoryID != AppCategory.autoClassifiedID else { return }
        move(selectionMemory, to: categoryID)
    }

    func createFolder(name: String = "新建文件夹") {
        createFolder(containing: selection, name: name)
    }

    func createFolder(containing appIDs: Set<String>, name: String = "新建文件夹") {
        guard selectedCategoryID != AppCategory.frequentlyUsedID,
              selectedCategoryID != AppCategory.autoClassifiedID,
              selectedCategoryID != AppCategory.essentialsID else { return }
        let candidateIDs = appIDs.filter { app(withID: $0) != nil }
        guard !candidateIDs.isEmpty else { return }

        for id in candidateIDs {
            assignments[id] = selectedCategoryID
            recordAssignment(appID: id, categoryID: selectedCategoryID)
        }
        folders = folders.compactMap { folder in
            var folder = folder
            folder.appIDs.removeAll { candidateIDs.contains($0) }
            return folder.appIDs.isEmpty ? nil : folder
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = AppFolder(
            id: UUID().uuidString,
            name: trimmed.isEmpty ? "新建文件夹" : trimmed,
            categoryID: selectedCategoryID,
            platform: selectedSystem,
            appIDs: Array(candidateIDs)
        )
        folders.append(folder)
        removeOrderTokens(
            candidateIDs.map { "app:\($0)" },
            in: selectedCategoryID,
            platform: selectedSystem
        )
        appendOrderToken("folder:\(folder.id)", in: selectedCategoryID, platform: selectedSystem)
        selection.removeAll()
        isSelectionMode = false
        save()
    }

    func renameFolder(_ folder: AppFolder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = trimmed
        save()
    }

    func deleteFolder(_ folder: AppFolder) {
        folders.removeAll { $0.id == folder.id }
        removeOrderTokens(
            ["folder:\(folder.id)"],
            in: folder.categoryID,
            platform: folder.platform
        )
        save()
    }

    func addApps(_ appIDs: Set<String>, to folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let validIDs = appIDs.filter { id in
            guard let app = app(withID: id) else { return false }
            return app.platform == folders[index].platform &&
                assignment(for: id) == folders[index].categoryID
        }
        for id in validIDs where !folders[index].appIDs.contains(id) {
            folders[index].appIDs.append(id)
        }
        removeOrderTokens(
            validIDs.map { "app:\($0)" },
            in: folders[index].categoryID,
            platform: folders[index].platform
        )
        selection.removeAll()
        isSelectionMode = false
        save()
    }

    func moveLibraryItem(_ draggedID: String, before targetID: String) {
        moveLibraryItem(draggedID, relativeTo: targetID, placeAfter: false)
    }

    func moveLibraryItem(
        _ draggedID: String,
        relativeTo targetID: String,
        placeAfter: Bool
    ) {
        _ = moveLibraryItems(
            [draggedID],
            relativeTo: targetID,
            placeAfter: placeAfter
        )
    }

    @discardableResult
    func moveLibraryItems(
        _ draggedIDs: [String],
        relativeTo targetID: String,
        placeAfter: Bool
    ) -> Bool {
        guard selectedCategoryID != AppCategory.frequentlyUsedID,
              selectedCategoryID != AppCategory.autoClassifiedID else {
            return false
        }
        let key = orderKey(platform: selectedSystem, categoryID: selectedCategoryID)
        var order = preparedItemOrder(for: key)
        let available = Set(order)
        var seen = Set<String>()
        let moving = draggedIDs.filter {
            $0 != targetID && available.contains($0) && seen.insert($0).inserted
        }
        guard !moving.isEmpty, !moving.contains(targetID) else { return false }

        order.removeAll { moving.contains($0) }
        guard let destination = order.firstIndex(of: targetID) else {
            return false
        }
        order.insert(contentsOf: moving, at: destination + (placeAfter ? 1 : 0))
        itemOrders[key] = order
        save()
        return true
    }

    func moveAppInCategory(_ appID: String, offset: Int) {
        guard selectedCategoryID != AppCategory.frequentlyUsedID,
              selectedCategoryID != AppCategory.autoClassifiedID,
              offset != 0 else { return }
        let key = orderKey(platform: selectedSystem, categoryID: selectedCategoryID)
        var order = preparedItemOrder(for: key)
        let token = "app:\(appID)"
        guard let source = order.firstIndex(of: token) else { return }
        let destination = max(0, min(order.count - 1, source + offset))
        guard destination != source else { return }
        order.swapAt(source, destination)
        itemOrders[key] = order
        save()
    }

    func moveAppInFolder(
        _ folderID: String,
        draggedAppID: String,
        before targetAppID: String
    ) {
        moveAppInFolder(
            folderID,
            draggedAppID: draggedAppID,
            relativeTo: targetAppID,
            placeAfter: false
        )
    }

    func moveAppInFolder(
        _ folderID: String,
        draggedAppID: String,
        relativeTo targetAppID: String,
        placeAfter: Bool
    ) {
        guard draggedAppID != targetAppID,
              let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              let source = folders[folderIndex].appIDs.firstIndex(of: draggedAppID),
              let target = folders[folderIndex].appIDs.firstIndex(of: targetAppID) else {
            return
        }
        let appID = folders[folderIndex].appIDs.remove(at: source)
        let destination = folders[folderIndex].appIDs.firstIndex(of: targetAppID) ?? target
        folders[folderIndex].appIDs.insert(
            appID,
            at: min(
                folders[folderIndex].appIDs.endIndex,
                destination + (placeAfter ? 1 : 0)
            )
        )
        save()
    }

    func moveFolder(_ folderID: String, to categoryID: String) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              categories.contains(where: { $0.id == categoryID }),
              categoryID != AppCategory.frequentlyUsedID else { return }
        if categoryID == AppCategory.essentialsID {
            addToEssentials(Set(folders[folderIndex].appIDs))
            return
        }

        let oldCategory = folders[folderIndex].categoryID
        guard oldCategory != categoryID else { return }
        let appIDs = folders[folderIndex].appIDs
        for id in appIDs {
            assignments[id] = categoryID
            recordAssignment(appID: id, categoryID: categoryID)
        }
        folders[folderIndex].categoryID = categoryID
        removeOrderTokens(
            ["folder:\(folderID)"],
            in: oldCategory,
            platform: folders[folderIndex].platform
        )
        appendOrderToken(
            "folder:\(folderID)",
            in: categoryID,
            platform: folders[folderIndex].platform
        )
        save()
    }

    func hide(_ appIDs: Set<String>) {
        guard !appIDs.isEmpty else { return }
        hiddenAppIDs.formUnion(appIDs)
        folders = folders.compactMap { folder in
            var folder = folder
            folder.appIDs.removeAll { appIDs.contains($0) }
            return folder.appIDs.isEmpty ? nil : folder
        }
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
        save()
    }

    func unhideAll() {
        hiddenAppIDs.removeAll()
        save()
    }

    func isEssential(_ appID: String) -> Bool {
        essentialAppIDs.contains(appID)
    }

    func addToEssentials(_ appIDs: Set<String>) {
        let validApps = appIDs.compactMap(app(withID:))
        let validIDs = Set(validApps.map(\.id))
        guard !validIDs.isEmpty else { return }
        essentialAppIDs.formUnion(validIDs)
        for app in validApps {
            appendOrderToken(
                "app:\(app.id)",
                in: AppCategory.essentialsID,
                platform: app.platform
            )
        }
        selection.removeAll()
        isSelectionMode = false
        save()
    }

    func removeFromEssentials(_ appIDs: Set<String>) {
        guard !appIDs.isEmpty else { return }
        let platforms = Set(appIDs.compactMap { app(withID: $0)?.platform })
        essentialAppIDs.subtract(appIDs)
        for platform in platforms {
            removeOrderTokens(
                appIDs.map { "app:\($0)" },
                in: AppCategory.essentialsID,
                platform: platform
            )
        }
        selection.removeAll()
        isSelectionMode = false
        save()
    }

    func move(_ appIDs: Set<String>, to categoryID: String) {
        guard !appIDs.isEmpty,
              categoryID != AppCategory.frequentlyUsedID,
              categoryID != AppCategory.autoClassifiedID,
              categories.contains(where: { $0.id == categoryID }) else { return }
        if categoryID == AppCategory.essentialsID {
            addToEssentials(appIDs)
            return
        }

        for id in appIDs {
            assignments[id] = categoryID
            recordAssignment(appID: id, categoryID: categoryID)
            autoClassifiedAppIDs.remove(id)
            autoClassificationReasons.removeValue(forKey: id)
            if categoryID == AppCategory.unclassifiedID {
                autoClassificationExcludedAppIDs.insert(id)
            } else {
                autoClassificationExcludedAppIDs.remove(id)
            }
        }
        folders = folders.compactMap { folder in
            var folder = folder
            folder.appIDs.removeAll {
                appIDs.contains($0) && folder.categoryID != categoryID
            }
            return folder.appIDs.isEmpty ? nil : folder
        }
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
        save()
    }

    @discardableResult
    func addCategory(named name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !categories.contains(where: {
                  $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
              }) else { return false }

        let category = AppCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmed,
            isBuiltIn: false
        )
        let insertionIndex = categories.firstIndex {
            $0.id == AppCategory.unclassifiedID
        } ?? categories.endIndex
        categories.insert(category, at: insertionIndex)
        if category.name == "自研软件" {
            for app in apps where app.platform == selectedSystem &&
                app.origin == .selfMade {
                assignments[app.id] = category.id
                recordAssignment(appID: app.id, categoryID: category.id)
            }
        }
        save()
        return true
    }

    @discardableResult
    func renameCategory(_ category: AppCategory, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !category.isNameLocked,
              !trimmed.isEmpty,
              let index = categories.firstIndex(where: { $0.id == category.id }),
              !categories.contains(where: {
                  $0.id != category.id &&
                  $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
              }) else {
            return false
        }
        categories[index].name = trimmed
        save()
        return true
    }

    func setCategoryNameLocked(_ category: AppCategory, locked: Bool) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }
        categories[index].isNameLocked = locked
        save()
    }

    func moveCategory(_ draggedID: String, before targetID: String) {
        guard draggedID != AppCategory.unclassifiedID,
              draggedID != AppCategory.frequentlyUsedID,
              draggedID != AppCategory.autoClassifiedID,
              targetID != AppCategory.frequentlyUsedID,
              targetID != AppCategory.autoClassifiedID,
              draggedID != targetID,
              let source = categories.firstIndex(where: { $0.id == draggedID }) else {
            return
        }

        let moved = categories.remove(at: source)
        let target = categories.firstIndex(where: { $0.id == targetID })
            ?? categories.firstIndex(where: { $0.id == AppCategory.unclassifiedID })
            ?? categories.endIndex
        categories.insert(moved, at: target)
        moveUnclassifiedToEnd()
        moveFrequentlyUsedToTop()
        save()
    }

    func moveCategoryUp(_ categoryID: String) {
        guard categoryID != AppCategory.frequentlyUsedID,
              categoryID != AppCategory.autoClassifiedID,
              categoryID != AppCategory.unclassifiedID,
              let index = categories.firstIndex(where: { $0.id == categoryID }),
              index > 1 else { return }
        categories.swapAt(index, index - 1)
        moveUnclassifiedToEnd()
        moveFrequentlyUsedToTop()
        save()
    }

    func moveCategoryDown(_ categoryID: String) {
        guard categoryID != AppCategory.frequentlyUsedID,
              categoryID != AppCategory.autoClassifiedID,
              categoryID != AppCategory.unclassifiedID,
              let index = categories.firstIndex(where: { $0.id == categoryID }),
              index + 1 < categories.count,
              categories[index + 1].id != AppCategory.unclassifiedID else { return }
        categories.swapAt(index, index + 1)
        moveUnclassifiedToEnd()
        moveFrequentlyUsedToTop()
        save()
    }

    func saveLayout(named name: String? = nil) {
        pushLayoutSnapshot(name: name)
        layoutSnapshots = Array(layoutSnapshots.suffix(20))
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        lastLayoutMessage = trimmed.isEmpty ? "当前布局已保存" : "已保存布局“\(trimmed)”"
        save()
    }

    func restorePreviousLayout() {
        while let snapshot = layoutSnapshots.popLast() {
            guard isRecoverableLayout(snapshot) else { continue }
            guard !layoutMatchesCurrent(snapshot) else { continue }
            applyLayoutSnapshot(snapshot)
            lastLayoutMessage = "已恢复上一布局"
            save()
            return
        }
        lastLayoutMessage = "没有更早的不同布局"
        save()
    }

    func restoreLayout(id: String) {
        guard let snapshot = layoutSnapshots.first(where: { $0.id == id }),
              !layoutMatchesCurrent(snapshot) else {
            lastLayoutMessage = "该布局与当前状态相同"
            return
        }
        pushLayoutSnapshot(name: "恢复前自动保存")
        applyLayoutSnapshot(snapshot)
        lastLayoutMessage = "已恢复布局“\(snapshot.name ?? "未命名")”"
        save()
    }

    func deleteLayoutSnapshot(id: String) {
        layoutSnapshots.removeAll { $0.id == id }
        save()
    }

    func resetLayout() {
        pushLayoutSnapshot()
        assignments = Dictionary(
            uniqueKeysWithValues: apps.map { app in
                (
                    app.id,
                    preferredOriginCategoryID(for: app)
                        ?? AppCategory.unclassifiedID
                )
            }
        )
        for (appID, categoryID) in assignments {
            recordAssignment(appID: appID, categoryID: categoryID)
        }
        autoClassifiedAppIDs.removeAll()
        autoClassificationReasons.removeAll()
        folders.removeAll()
        itemOrders.removeAll()
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
        lastLayoutMessage = "已重置为初始布局"
        save()
    }

    func applyClassicLayout() {
        pushLayoutSnapshot()
        let current = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0) }
        )
        let builtIns = AppCategory.defaults.map { fallback -> AppCategory in
            guard let existing = current[fallback.id], existing.isNameLocked else {
                return fallback
            }
            return existing
        }
        let custom = categories.filter { !$0.isBuiltIn }
        categories = builtIns.filter { $0.id != AppCategory.unclassifiedID }
            + custom
            + [builtIns.first(where: { $0.id == AppCategory.unclassifiedID }) ?? .unclassified]
        itemOrders.removeAll()
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
        lastLayoutMessage = "已切换为经典布局"
        save()
    }

    func resetAppearanceSettings() {
        appearanceMode = .system
        theme = .system
        chineseFontName = "__system__"
        latinFontName = "__system__"
        useCustomFontColor = false
        fontColorHex = 0x354052
        backgroundKind = .material
        backgroundColorHex = 0xEAF0F6
        backgroundImagePath = nil
        wallpaperPath = nil
        backgroundOpacity = 1
        wallpaperBlurRadius = 26
        showNames = true
        save()
    }

    func resetLayoutPreferences() {
        iconScale = 1
        gridColumnCount = 0
        gridRowCount = 0
        dragHoldDuration = 0.35
        save()
    }

    func resetSidebarSettings() {
        showAllSidebarCategories = false
        sidebarUsesCustomColor = false
        sidebarColorHex = 0xEAF0F6
        sidebarFontSize = 13.5
        sidebarWidth = 236
        sidebarUsesMainBackground = false
        sidebarUsesMainFontColor = true
        sidebarFontColorHex = 0x354052
        sidebarUsesMainFonts = true
        sidebarChineseFontName = "__system__"
        sidebarLatinFontName = "__system__"
        sidebarUsesMainAccent = true
        sidebarAccentColorHex = 0x0B66C3
        save()
    }

    func resetLibrarySettings() {
        showWindowsUtilities = false
        recommendationsEnabled = true
        automaticClassificationEnabled = true
        classificationReferenceColumns = 3
        save()
    }

    func resetLanguageSettings() {
        appLanguage = .chinese
    }

    func resetAllCustomizableSettings() {
        resetAppearanceSettings()
        resetLayoutPreferences()
        resetSidebarSettings()
        resetLibrarySettings()
        resetLanguageSettings()
        save()
    }

    func deleteCategory(_ category: AppCategory) {
        guard !category.isBuiltIn,
              category.id != AppCategory.selfMadeID else { return }

        for app in apps where app.platform == selectedSystem &&
            assignments[app.id] == category.id {
            assignments[app.id] = AppCategory.unclassifiedID
            recordAssignment(
                appID: app.id,
                categoryID: AppCategory.unclassifiedID
            )
        }
        folders.removeAll { $0.categoryID == category.id }
        categories.removeAll { $0.id == category.id }
        if selectedCategoryID == category.id {
            selectedCategoryID = AppCategory.unclassifiedID
        }
        ensureValidCategorySelection()
        save()
    }

    func open(_ app: LauncherApp) {
        let previous = launchStats[app.id]
            ?? LaunchStat(count: 0, lastLaunched: .distantPast)
        launchStats[app.id] = previous.recordingLaunch()
        save()
        let url = URL(fileURLWithPath: app.path)
        if app.platform == .windows,
           url.pathExtension.lowercased() == "exe",
           app.origin == .selfMade || app.origin == .thirdParty {
            WindowsProgramLauncher.launch(hostURL: url) { [weak self] result in
                if case .failure(let error) = result {
                    self?.presentWindowsLaunchError(error, app: app)
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    func importThirdPartySoftware(from source: URL) throws -> PlatformKind {
        let root = URL(
            fileURLWithPath: LauncherConstants.thirdPartyLibrary,
            isDirectory: true
        )
        let macRoot = root.appendingPathComponent("macOS", isDirectory: true)
        let windowsRoot = root.appendingPathComponent("Windows", isDirectory: true)
        let source = source.standardizedFileURL
        let extensionName = source.pathExtension.lowercased()

        if source.path.hasPrefix(root.path + "/") {
            let platform: PlatformKind = source.path.hasPrefix(macRoot.path + "/")
                ? .macOS : .windows
            selectSystem(platform)
            selectedCategoryID = AppCategory.thirdPartyID
            refresh()
            return platform
        }

        let platform: PlatformKind
        let destination: URL
        if extensionName == "app" {
            platform = .macOS
            try FileManager.default.createDirectory(
                at: macRoot,
                withIntermediateDirectories: true
            )
            destination = uniqueDestination(
                macRoot.appendingPathComponent(source.lastPathComponent)
            )
            try FileManager.default.moveItem(at: source, to: destination)
        } else if extensionName == "exe" {
            platform = .windows
            try FileManager.default.createDirectory(
                at: windowsRoot,
                withIntermediateDirectories: true
            )
            let folder = uniqueDestination(
                windowsRoot.appendingPathComponent(
                    source.deletingPathExtension().lastPathComponent,
                    isDirectory: true
                )
            )
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            destination = folder.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.moveItem(at: source, to: destination)
            try destination.lastPathComponent.write(
                to: folder.appendingPathComponent(".macappbox-entry"),
                atomically: true,
                encoding: .utf8
            )
        } else {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: source.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw ThirdPartyImportError.unsupported
            }
            let entry = try findEntryExecutable(in: source)
            let relativeEntry = String(entry.path.dropFirst(source.path.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            platform = .windows
            try FileManager.default.createDirectory(
                at: windowsRoot,
                withIntermediateDirectories: true
            )
            destination = uniqueDestination(
                windowsRoot.appendingPathComponent(
                    source.lastPathComponent,
                    isDirectory: true
                )
            )
            try FileManager.default.moveItem(at: source, to: destination)
            try relativeEntry.write(
                to: destination.appendingPathComponent(".macappbox-entry"),
                atomically: true,
                encoding: .utf8
            )
        }

        selectSystem(platform)
        selectedCategoryID = AppCategory.thirdPartyID
        lastLayoutMessage = "已导入第三方软件：\(destination.lastPathComponent)"
        refresh()
        return platform
    }

    private func uniqueDestination(_ preferred: URL) -> URL {
        guard FileManager.default.fileExists(atPath: preferred.path) else {
            return preferred
        }
        let base = preferred.deletingPathExtension()
        let extensionPart = preferred.pathExtension
        for index in 2...999 {
            let suffix = extensionPart.isEmpty
                ? " \(index)"
                : " \(index).\(extensionPart)"
            let candidate = URL(fileURLWithPath: base.path + suffix)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: base.path + " \(UUID().uuidString)")
    }

    private func findEntryExecutable(in folder: URL) throws -> URL {
        let skipped = ["setup", "install", "unins", "update", "helper", "redist"]
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys
        ) else {
            throw ThirdPartyImportError.noExecutable
        }
        var candidates: [(url: URL, size: Int)] = []
        for case let url as URL in enumerator
        where url.pathExtension.lowercased() == "exe" {
            let lower = url.lastPathComponent.lowercased()
            if skipped.contains(where: { lower.contains($0) }) {
                continue
            }
            let size = (try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0
            candidates.append((url, size))
        }
        guard let best = candidates.max(by: { $0.size < $1.size }) else {
            throw ThirdPartyImportError.noExecutable
        }
        return best.url
    }

    private func presentWindowsLaunchError(
        _ error: Error,
        app: LauncherApp
    ) {
        let alert = NSAlert()
        alert.messageText = "无法启动 \(app.name)"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    enum ThirdPartyImportError: LocalizedError {
        case unsupported
        case noExecutable

        var errorDescription: String? {
            switch self {
            case .unsupported:
                "请选择 .app、.exe 或包含 Windows 程序的文件夹"
            case .noExecutable:
                "所选文件夹中没有找到可用的 exe"
            }
        }
    }

    func applyAutomaticClassification() {
        guard automaticClassificationEnabled else { return }
        var changed = false

        for platform in PlatformKind.allCases {
            let platformCategories = (categorySets[platform] ?? []).filter {
                $0.id != AppCategory.frequentlyUsedID &&
                $0.id != AppCategory.autoClassifiedID &&
                $0.id != AppCategory.unclassifiedID
            }
            guard platformCategories.count >= 2 else { continue }
            let categoryByID = Dictionary(
                uniqueKeysWithValues: platformCategories.map { ($0.id, $0) }
            )
            let platformApps = baseApps(for: platform)
            let manualApps = platformApps.filter {
                !autoClassifiedAppIDs.contains($0.id) &&
                assignment(for: $0.id) != AppCategory.unclassifiedID &&
                categoryByID[assignment(for: $0.id)] != nil
            }

            var vendorRules: [String: [String: Set<String>]] = [:]
            var tokenRules: [String: [String: Set<String>]] = [:]
            for app in manualApps {
                let categoryID = assignment(for: app.id)
                if let vendor = Self.vendorKey(for: app) {
                    vendorRules[vendor, default: [:]][categoryID, default: []]
                        .insert(app.id)
                }
                for token in Self.classificationTokens(for: app) {
                    tokenRules[token, default: [:]][categoryID, default: []]
                        .insert(app.id)
                }
            }

            let candidates = platformApps.filter {
                assignment(for: $0.id) == AppCategory.unclassifiedID &&
                $0.origin != .selfMade &&
                !autoClassificationExcludedAppIDs.contains($0.id)
            }
            for candidate in candidates {
                var scores: [String: Int] = [:]
                var reasons: [String: [String]] = [:]

                if let vendor = Self.vendorKey(for: candidate),
                   let categoriesForVendor = vendorRules[vendor] {
                    let eligible = categoriesForVendor.filter {
                        $0.value.count >= 2
                    }
                    if eligible.count == 1, let match = eligible.first {
                        scores[match.key, default: 0] += 4
                        reasons[match.key, default: []].append(
                            "同一开发商已有 \(match.value.count) 个应用"
                        )
                    }
                }

                for token in Self.classificationTokens(for: candidate) {
                    guard let categoriesForToken = tokenRules[token] else { continue }
                    for (categoryID, matchingIDs) in categoriesForToken
                    where matchingIDs.count >= 2 {
                        scores[categoryID, default: 0] += min(3, matchingIDs.count)
                        reasons[categoryID, default: []].append(
                            "名称特征“\(token)”已有 \(matchingIDs.count) 个样本"
                        )
                    }
                }

                let ranked = scores.sorted {
                    if $0.value != $1.value { return $0.value > $1.value }
                    return $0.key < $1.key
                }
                guard let best = ranked.first, best.value >= 4 else { continue }
                if ranked.count > 1, best.value - ranked[1].value < 2 { continue }

                let categoryName = categoryByID[best.key]?.name ?? "目标类别"
                assignments[candidate.id] = best.key
                autoClassifiedAppIDs.insert(candidate.id)
                autoClassificationReasons[candidate.id] =
                    "自动放入\(categoryName)："
                    + (reasons[best.key]?.prefix(2).joined(separator: "；") ?? "历史分类一致")
                recordAssignment(appID: candidate.id, categoryID: best.key)
                changed = true
            }
        }

        if changed {
            ensureValidCategorySelection()
            save()
        }
    }

    func undoAutomaticClassifications() {
        guard !autoClassifiedAppIDs.isEmpty else { return }
        for appID in autoClassifiedAppIDs {
            assignments[appID] = AppCategory.unclassifiedID
            recordAssignment(
                appID: appID,
                categoryID: AppCategory.unclassifiedID
            )
        }
        autoClassifiedAppIDs.removeAll()
        autoClassificationReasons.removeAll()
        ensureValidCategorySelection()
        save()
    }

    func retryAutomaticClassification() {
        autoClassificationExcludedAppIDs.removeAll()
        applyAutomaticClassification()
        save()
    }

    func automaticReason(for appID: String) -> String? {
        autoClassificationReasons[appID]
    }

    private static func vendorKey(for app: LauncherApp) -> String? {
        var value = app.id
        if value.hasPrefix("mac:") {
            value = String(value.dropFirst(4))
        } else if value.hasPrefix("win:") {
            value = String(value.dropFirst(4))
        }
        guard !value.hasPrefix("/") else { return nil }
        let parts = value.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        return parts.prefix(2).joined(separator: ".").lowercased()
    }

    private static func classificationTokens(for app: LauncherApp) -> Set<String> {
        let ignored: Set<String> = [
            "app", "apps", "mac", "macos", "windows", "microsoft",
            "google", "apple", "tencent", "pro", "lite", "max", "plus"
        ]
        let folded = app.name
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
        let tokens = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && !ignored.contains($0) }
        return Set(tokens)
    }

    func clearLaunchHistory() {
        launchStats.removeAll()
        ensureValidCategorySelection()
        save()
    }

    func setBackgroundImage(from url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: supportDirectory,
                withIntermediateDirectories: true
            )
            let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
            let destination = supportDirectory
                .appendingPathComponent("background-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: url, to: destination)

            if let previous = backgroundImagePath,
               previous.hasPrefix(supportDirectory.path),
               FileManager.default.fileExists(atPath: previous) {
                try? FileManager.default.removeItem(atPath: previous)
            }
            backgroundKind = .image
            backgroundImagePath = destination.path
        } catch {
            NSSound.beep()
        }
    }

    func clearBackgroundImage() {
        if let path = backgroundImagePath,
           path.hasPrefix(supportDirectory.path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        backgroundImagePath = nil
        backgroundKind = .material
    }

    func setWallpaperImage(from url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: supportDirectory,
                withIntermediateDirectories: true
            )
            let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
            let destination = supportDirectory
                .appendingPathComponent("wallpaper-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: url, to: destination)

            if let previous = wallpaperPath,
               previous.hasPrefix(supportDirectory.path),
               FileManager.default.fileExists(atPath: previous) {
                try? FileManager.default.removeItem(atPath: previous)
            }
            wallpaperPath = destination.path
            backgroundKind = .wallpaper
            refreshWallpaperRender()
        } catch {
            NSSound.beep()
        }
    }

    func clearWallpaperSelection() {
        if let path = wallpaperPath,
           path.hasPrefix(supportDirectory.path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        wallpaperPath = nil
        refreshWallpaperRender()
    }

    func reveal(_ app: LauncherApp) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
    }

    func isRunning(_ app: LauncherApp) -> Bool {
        runningApplications(for: app).isEmpty == false
    }

    func restart(_ app: LauncherApp) {
        forceQuit(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        }
    }

    func forceQuit(_ app: LauncherApp) {
        runningApplications(for: app).forEach { $0.forceTerminate() }
    }

    func quitForUninstall(_ app: LauncherApp) {
        runningApplications(for: app).forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func addToDock(_ app: LauncherApp) {
        let path = app.path
        let entry = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(path)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.dock", "persistent-apps", "-array-add", entry]
        try? process.run()
        process.waitUntilExit()

        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["Dock"]
        try? restart.run()
    }

    func uninstall(_ app: LauncherApp) {
        NSWorkspace.shared.recycle([URL(fileURLWithPath: app.path)]) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refresh()
            }
        }
    }

    private func baseApps(for system: PlatformKind) -> [LauncherApp] {
        apps.filter { app in
            app.platform == system &&
            !hiddenAppIDs.contains(app.id) &&
            (showWindowsUtilities || !app.isWindowsUtility)
        }
    }

    private func runningApplications(for app: LauncherApp) -> [NSRunningApplication] {
        guard let bundleID = Bundle(url: URL(fileURLWithPath: app.path))?.bundleIdentifier,
              !bundleID.isEmpty else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }

    private func ensureValidCategorySelection() {
        let visibleIDs = Set(visibleCategories.map(\.id))
        if !visibleIDs.contains(selectedCategoryID) {
            selectedCategoryID = visibleCategories.first?.id ?? AppCategory.unclassifiedID
        }
        let selectableIDs = Set(currentApps.map(\.id))
            .union(currentFolders.flatMap(\.appIDs))
        selection = selection.intersection(selectableIDs)
    }

    private func scanSummary() -> String {
        let macCount = baseApps(for: .macOS).count
        let windowsCount = baseApps(for: .windows).count
        return "\(macCount) 个 macOS 应用  ·  \(windowsCount) 个 Windows 应用"
    }

    private func stateURL() -> URL {
        supportDirectory
            .appendingPathComponent("state.json")
    }

    private var supportDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base
            .appendingPathComponent(LauncherConstants.stateDirectoryName, isDirectory: true)
    }

    private var inventoryURL: URL {
        supportDirectory.appendingPathComponent("inventory.json")
    }

    private var iconCacheDirectory: URL {
        supportDirectory.appendingPathComponent("AppIcons", isDirectory: true)
    }

    private func load() {
        let url = stateURL()
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SavedLauncherState.self, from: data) else {
            return
        }
        isLoadingState = true

        let hasSeparateCategorySets = state.categorySets != nil
        for platform in PlatformKind.allCases {
            let saved = state.categorySets?[platform.rawValue] ?? state.categories
            categorySets[platform] = hasSeparateCategorySets
                ? normalizeExistingCategories(saved)
                : mergeBuiltInCategories(saved)
        }
        assignments = state.assignments
        folders = state.folders
        hiddenAppIDs = Set(state.hiddenAppIDs)
        showWindowsUtilities = state.showWindowsUtilities
        showNames = state.showNames
        appLanguage = state.appLanguage ?? .chinese
        iconScale = min(2.0, max(0.25, state.iconScale))
        appearanceMode = state.appearanceMode
        itemOrders = state.itemOrders ?? [:]
        chineseFontName = state.chineseFontName ?? legacyChineseFont(state.fontStyle)
        latinFontName = state.latinFontName ?? legacyLatinFont(state.fontStyle)
        useCustomFontColor = state.useCustomFontColor ?? false
        fontColorHex = state.fontColorHex ?? 0x354052
        theme = state.theme ?? .system
        layoutSnapshots = state.layoutSnapshots ?? []
        launchStats = state.launchStats ?? [:]
        recommendationsEnabled = state.recommendationsEnabled ?? true
        windowsCategoriesReset = state.windowsCategoriesReset ?? false
        backgroundKind = state.backgroundKind ?? .material
        backgroundColorHex = state.backgroundColorHex ?? 0xEAF0F6
        backgroundImagePath = state.backgroundImagePath
        wallpaperPath = state.wallpaperPath
        backgroundOpacity = min(1.0, max(0.0, state.backgroundOpacity ?? 1.0))
        wallpaperBlurRadius = min(
            48,
            max(0, state.wallpaperBlurRadius ?? 26)
        )
        dragHoldDuration = min(0.8, max(0.2, state.dragHoldDuration ?? 0.35))
        let savedColumnCount = state.gridColumnCount ?? 0
        gridColumnCount = (1...16).contains(savedColumnCount)
            ? savedColumnCount
            : 0
        let savedRowCount = state.gridRowCount ?? 0
        gridRowCount = (1...8).contains(savedRowCount) ? savedRowCount : 0
        showAllSidebarCategories = state.showAllSidebarCategories ?? false
        sidebarUsesCustomColor = state.sidebarUsesCustomColor ?? false
        sidebarColorHex = state.sidebarColorHex ?? 0xEAF0F6
        sidebarFontSize = min(20, max(10, state.sidebarFontSize ?? 13.5))
        sidebarWidth = min(340, max(190, state.sidebarWidth ?? 236))
        sidebarUsesMainBackground = state.sidebarUsesMainBackground ?? false
        sidebarUsesMainFontColor = state.sidebarUsesMainFontColor ?? true
        sidebarFontColorHex = state.sidebarFontColorHex ?? 0x354052
        sidebarUsesMainFonts = state.sidebarUsesMainFonts ?? true
        sidebarChineseFontName = state.sidebarChineseFontName ?? "__system__"
        sidebarLatinFontName = state.sidebarLatinFontName ?? "__system__"
        sidebarUsesMainAccent = state.sidebarUsesMainAccent ?? true
        sidebarAccentColorHex = state.sidebarAccentColorHex ?? 0x0B66C3
        categoryAssignmentDates = state.categoryAssignmentDates ?? [:]
        categoryStatisticsStartedAt = state.categoryStatisticsStartedAt
        automaticClassificationEnabled = state.automaticClassificationEnabled ?? true
        autoClassifiedAppIDs = Set(state.autoClassifiedAppIDs ?? [])
        autoClassificationExcludedAppIDs = Set(
            state.autoClassificationExcludedAppIDs ?? []
        )
        autoClassificationReasons = state.autoClassificationReasons ?? [:]
        essentialAppIDs = Set(state.essentialAppIDs ?? [])
        selectionMemory = Set(state.selectionMemory ?? [])
        classificationReferenceColumns = min(
            6,
            max(1, state.classificationReferenceColumns ?? 3)
        )
        migrateCategoryAssignmentDatesIfNeeded()
        AppTypography.save(
            chinese: chineseFontName,
            latin: latinFontName
        )
        ensureValidCategorySelection()
        refreshWallpaperRender()
        isLoadingState = false
        save()
    }

    private func loadInventoryCache() {
        guard let data = try? Data(contentsOf: inventoryURL),
              let inventory = try? JSONDecoder().decode(CachedInventory.self, from: data) else {
            return
        }

        apps = inventory.apps.map { cached in
            LauncherApp(
                id: cached.id,
                name: cached.name,
                path: cached.path,
                platform: cached.platform,
                origin: cached.origin,
                icon: cachedIcon(for: cached),
                isWindowsUtility: cached.isWindowsUtility,
                hostName: cached.hostName
            )
        }
        filteredWindowsCount = apps.filter {
            $0.platform == .windows && $0.isWindowsUtility
        }.count

        for app in apps where assignments[app.id] == nil {
            let categoryID = preferredOriginCategoryID(for: app)
                ?? AppCategory.unclassifiedID
            assignments[app.id] = categoryID
            recordAssignment(appID: app.id, categoryID: categoryID)
        }
        normalizeAssignmentsForPlatforms()
        lastScanSummary = "\(scanSummary()) · 缓存"
        ensureValidCategorySelection()
    }

    private func migrateWindowsCategoriesIfNeeded() {
        guard !windowsCategoriesReset else { return }

        let frequency = AppCategory.defaults.first {
            $0.id == AppCategory.frequentlyUsedID
        } ?? AppCategory(
            id: AppCategory.frequentlyUsedID,
            name: "常用推荐",
            isBuiltIn: true
        )
        categorySets[.windows] = [frequency, .unclassified]

        let windowsAppIDs = Set(
            apps.filter { $0.platform == .windows }.map(\.id)
        )
        for id in windowsAppIDs {
            assignments[id] = AppCategory.unclassifiedID
            recordAssignment(
                appID: id,
                categoryID: AppCategory.unclassifiedID
            )
        }
        folders.removeAll { $0.platform == .windows }
        itemOrders = itemOrders.filter {
            !$0.key.hasPrefix(PlatformKind.windows.rawValue + ":")
        }
        windowsCategoriesReset = true
        ensureValidCategorySelection()
        save()
    }

    private func saveInventoryCache(completion: (() -> Void)? = nil) {
        let appSnapshot = apps
        let inventory = CachedInventory(
            generatedAt: Date(),
            apps: appSnapshot.map(CachedLauncherApp.init)
        )
        guard let data = try? encoder.encode(inventory) else { return }

        try? FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        try? data.write(to: inventoryURL, options: .atomic)

        let directory = iconCacheDirectory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            for app in appSnapshot {
                autoreleasepool {
                    let url = directory.appendingPathComponent(self.iconCacheName(for: app.id))
                    if let modified = try? url.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate,
                       modified > Date().addingTimeInterval(-7 * 86_400) {
                        return
                    }
                    guard let png = Self.smallIconPNG(app.icon) else { return }
                    try? png.write(to: url, options: .atomic)
                }
            }
            malloc_zone_pressure_relief(nil, 0)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    nonisolated private static func smallIconPNG(_ icon: NSImage) -> Data? {
        let side: CGFloat = 160
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        icon.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func cachedIcon(for app: CachedLauncherApp) -> NSImage {
        let url = iconCacheDirectory.appendingPathComponent(iconCacheName(for: app.id))
        if let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 128, height: 128)
            return image
        }
        if app.origin == .selfMade || app.origin == .thirdParty {
            return GeneratedAppIcon.icon(
                for: URL(fileURLWithPath: app.path),
                name: app.name
            )
        }
        let image = NSImage(
            systemSymbolName: "app.fill",
            accessibilityDescription: app.name
        ) ?? NSImage()
        image.size = NSSize(width: 128, height: 128)
        return image
    }

    nonisolated private func iconCacheName(for id: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16) + ".png"
    }

    private func save() {
        guard !isLoadingState else { return }
        let state = SavedLauncherState(
            categories: categories,
            categorySets: Dictionary(
                uniqueKeysWithValues: categorySets.map { ($0.key.rawValue, $0.value) }
            ),
            assignments: assignments,
            folders: folders,
            itemOrders: itemOrders,
            hiddenAppIDs: Array(hiddenAppIDs),
            showWindowsUtilities: showWindowsUtilities,
            showNames: showNames,
            iconScale: iconScale,
            appearanceMode: appearanceMode,
            fontStyle: nil,
            theme: theme,
            chineseFontName: chineseFontName,
            latinFontName: latinFontName,
            fontScale: nil,
            fontSize: nil,
            useCustomFontColor: useCustomFontColor,
            fontColorHex: fontColorHex,
            layoutSnapshots: layoutSnapshots,
            launchStats: launchStats,
            recommendationsEnabled: recommendationsEnabled,
            windowsCategoriesReset: windowsCategoriesReset,
            backgroundKind: backgroundKind,
            backgroundColorHex: backgroundColorHex,
            backgroundImagePath: backgroundImagePath,
            wallpaperPath: wallpaperPath,
            backgroundOpacity: backgroundOpacity,
            wallpaperBlurRadius: wallpaperBlurRadius,
            dragHoldDuration: dragHoldDuration,
            gridColumnCount: gridColumnCount == 0 ? nil : gridColumnCount,
            gridRowCount: gridRowCount == 0 ? nil : gridRowCount,
            showAllSidebarCategories: showAllSidebarCategories,
            sidebarUsesCustomColor: sidebarUsesCustomColor,
            sidebarColorHex: sidebarColorHex,
            sidebarFontSize: sidebarFontSize,
            sidebarWidth: sidebarWidth,
            sidebarUsesMainBackground: sidebarUsesMainBackground,
            sidebarUsesMainFontColor: sidebarUsesMainFontColor,
            sidebarFontColorHex: sidebarFontColorHex,
            sidebarUsesMainFonts: sidebarUsesMainFonts,
            sidebarChineseFontName: sidebarChineseFontName,
            sidebarLatinFontName: sidebarLatinFontName,
            sidebarUsesMainAccent: sidebarUsesMainAccent,
            sidebarAccentColorHex: sidebarAccentColorHex,
            categoryAssignmentDates: categoryAssignmentDates,
            categoryStatisticsStartedAt: categoryStatisticsStartedAt,
            automaticClassificationEnabled: automaticClassificationEnabled,
            autoClassifiedAppIDs: Array(autoClassifiedAppIDs),
            autoClassificationExcludedAppIDs: Array(autoClassificationExcludedAppIDs),
            autoClassificationReasons: autoClassificationReasons,
            essentialAppIDs: Array(essentialAppIDs),
            selectionMemory: Array(selectionMemory),
            classificationReferenceColumns: classificationReferenceColumns,
            appLanguage: appLanguage
        )
        let generation = stateSaveGate.next()
        let gate = stateSaveGate
        let url = stateURL()
        stateSaveQueue.async {
            guard gate.isCurrent(generation) else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(state) else { return }
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }

    private func orderKey(platform: PlatformKind, categoryID: String) -> String {
        "\(platform.rawValue):\(categoryID)"
    }

    private func preparedItemOrder(for key: String) -> [String] {
        let currentTokens = currentLibraryItems.map(\.orderToken)
        let available = Set(currentTokens)
        var order = (itemOrders[key] ?? []).filter { available.contains($0) }
        let existing = Set(order)
        order.append(contentsOf: currentTokens.filter { !existing.contains($0) })
        return order
    }

    private func appendOrderToken(
        _ token: String,
        in categoryID: String,
        platform: PlatformKind
    ) {
        let key = orderKey(platform: platform, categoryID: categoryID)
        var order = itemOrders[key] ?? []
        if !order.contains(token) {
            order.append(token)
        }
        itemOrders[key] = order
    }

    private func removeOrderTokens(
        _ tokens: [String],
        in categoryID: String,
        platform: PlatformKind
    ) {
        let key = orderKey(platform: platform, categoryID: categoryID)
        itemOrders[key]?.removeAll { tokens.contains($0) }
    }

    private func legacyChineseFont(_ style: AppFontStyle?) -> String {
        switch style {
        case .yahei: "Microsoft YaHei"
        case .times: "Times New Roman"
        default: "__system__"
        }
    }

    private func legacyLatinFont(_ style: AppFontStyle?) -> String {
        switch style {
        case .yahei: "Microsoft YaHei"
        case .times: "Times New Roman"
        default: "__system__"
        }
    }

    private func mergeBuiltInCategories(_ saved: [AppCategory]) -> [AppCategory] {
        let builtInIDs = Set(AppCategory.defaults.map(\.id))
        var savedBuiltIns = Dictionary(
            uniqueKeysWithValues: saved
                .filter { builtInIDs.contains($0.id) }
                .map { ($0.id, $0) }
        )
        if savedBuiltIns[AppCategory.unclassifiedID]?.name == "未归类" {
            savedBuiltIns[AppCategory.unclassifiedID] = .unclassified
        }
        let savedCustom = saved.filter { !builtInIDs.contains($0.id) }
        let builtInDefaults = AppCategory.defaults.filter {
            $0.id != AppCategory.unclassifiedID
        }
        return builtInDefaults.map { savedBuiltIns[$0.id] ?? $0 }
            + savedCustom
            + [savedBuiltIns[AppCategory.unclassifiedID] ?? .unclassified]
    }

    private func normalizeExistingCategories(_ saved: [AppCategory]) -> [AppCategory] {
        var categories = saved
        if !categories.contains(where: { $0.id == AppCategory.frequentlyUsedID }) {
            categories.insert(
                AppCategory(
                    id: AppCategory.frequentlyUsedID,
                    name: "常用推荐",
                    isBuiltIn: true
                ),
                at: 0
            )
        }
        if !categories.contains(where: { $0.id == AppCategory.autoClassifiedID }) {
            let insertionIndex = categories.firstIndex {
                $0.id == AppCategory.unclassifiedID
            } ?? categories.endIndex
            categories.insert(.autoClassified, at: insertionIndex)
        }
        if !categories.contains(where: { $0.id == AppCategory.essentialsID }) {
            let learningIndex = categories.firstIndex {
                $0.id == AppCategory.learningID
            }
            let unclassifiedIndex = categories.firstIndex {
                $0.id == AppCategory.unclassifiedID
            }
            let insertionIndex = learningIndex ?? unclassifiedIndex ?? categories.endIndex
            categories.insert(.essentials, at: insertionIndex)
        }
        if !categories.contains(where: { $0.id == AppCategory.thirdPartyID }) {
            let selfMadeIndex = categories.firstIndex {
                $0.id == AppCategory.selfMadeID
            }
            let unclassifiedIndex = categories.firstIndex {
                $0.id == AppCategory.unclassifiedID
            }
            let insertionIndex = unclassifiedIndex
                ?? selfMadeIndex.map { min(categories.count, $0 + 1) }
                ?? categories.endIndex
            categories.insert(.thirdParty, at: insertionIndex)
        }
        if !categories.contains(where: { $0.id == AppCategory.unclassifiedID }) {
            categories.append(.unclassified)
        }
        return categories
    }

    private func normalizeAssignmentsForPlatforms() {
        for app in apps {
            let validIDs = Set(
                (categorySets[app.platform] ?? []).map(\.id)
            )
            let current = assignments[app.id] ?? AppCategory.unclassifiedID
            guard validIDs.contains(current) else {
                let preferred = preferredOriginCategoryID(for: app)
                    ?? AppCategory.unclassifiedID
                assignments[app.id] = validIDs.contains(preferred)
                    ? preferred
                    : AppCategory.unclassifiedID
                recordAssignment(
                    appID: app.id,
                    categoryID: assignment(for: app.id)
                )
                continue
            }
        }
    }

    private func selfMadeCategoryID(for platform: PlatformKind) -> String? {
        let platformCategories = categorySets[platform] ?? []
        if platformCategories.contains(where: { $0.id == AppCategory.selfMadeID }) {
            return AppCategory.selfMadeID
        }
        return platformCategories.first {
            $0.name.compare("自研软件", options: .caseInsensitive) == .orderedSame
        }?.id
    }

    private func thirdPartyCategoryID(for platform: PlatformKind) -> String? {
        let platformCategories = categorySets[platform] ?? []
        if platformCategories.contains(where: { $0.id == AppCategory.thirdPartyID }) {
            return AppCategory.thirdPartyID
        }
        return platformCategories.first {
            $0.name.compare("第三方软件", options: .caseInsensitive) == .orderedSame
        }?.id
    }

    private func preferredOriginCategoryID(for app: LauncherApp) -> String? {
        switch app.origin {
        case .selfMade:
            selfMadeCategoryID(for: app.platform)
        case .thirdParty:
            thirdPartyCategoryID(for: app.platform)
        case .macOS, .windows:
            nil
        }
    }

    private func pushLayoutSnapshot(name: String? = nil) {
        layoutSnapshots.append(
            LayoutSnapshot(
                id: UUID().uuidString,
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: Date(),
                categories: categories,
                categorySets: Dictionary(
                    uniqueKeysWithValues: categorySets.map {
                        ($0.key.rawValue, $0.value)
                    }
                ),
                assignments: assignments,
                folders: folders,
                itemOrders: itemOrders,
                gridColumnCount: gridColumnCount == 0 ? nil : gridColumnCount,
                gridRowCount: gridRowCount == 0 ? nil : gridRowCount
            )
        )
        layoutSnapshots = Array(layoutSnapshots.suffix(20))
    }

    private func layoutMatchesCurrent(_ snapshot: LayoutSnapshot) -> Bool {
        let currentSets = Dictionary(
            uniqueKeysWithValues: categorySets.map {
                ($0.key.rawValue, $0.value)
            }
        )
        return snapshot.assignments == assignments
            && snapshot.folders == folders
            && snapshot.itemOrders == itemOrders
            && snapshot.categorySets == currentSets
            && (snapshot.gridColumnCount ?? 0) == gridColumnCount
            && (snapshot.gridRowCount ?? 0) == gridRowCount
    }

    private func isRecoverableLayout(_ snapshot: LayoutSnapshot) -> Bool {
        if !snapshot.folders.isEmpty || !snapshot.itemOrders.isEmpty {
            return true
        }
        let neutralCategoryIDs: Set<String> = [
            AppCategory.frequentlyUsedID,
            AppCategory.selfMadeID,
            AppCategory.unclassifiedID
        ]
        return snapshot.assignments.values.contains {
            !neutralCategoryIDs.contains($0)
        }
    }

    private func applyLayoutSnapshot(_ snapshot: LayoutSnapshot) {
        if let savedSets = snapshot.categorySets {
            for platform in PlatformKind.allCases {
                categorySets[platform] = normalizeExistingCategories(
                    savedSets[platform.rawValue] ?? snapshot.categories
                )
            }
        } else {
            for platform in PlatformKind.allCases {
                categorySets[platform] = normalizeExistingCategories(snapshot.categories)
            }
        }
        assignments = snapshot.assignments
        for (appID, categoryID) in assignments {
            recordAssignment(appID: appID, categoryID: categoryID)
        }
        folders = snapshot.folders
        itemOrders = snapshot.itemOrders
        if let savedColumnCount = snapshot.gridColumnCount,
           (1...16).contains(savedColumnCount) {
            gridColumnCount = savedColumnCount
        } else {
            gridColumnCount = 0
        }
        if let savedRowCount = snapshot.gridRowCount,
           (1...8).contains(savedRowCount) {
            gridRowCount = savedRowCount
        } else {
            gridRowCount = 0
        }
        moveUnclassifiedToEnd()
        moveFrequentlyUsedToTop()
        selection.removeAll()
        isSelectionMode = false
        ensureValidCategorySelection()
    }

    private func moveUnclassifiedToEnd() {
        if let index = categories.firstIndex(where: {
            $0.id == AppCategory.unclassifiedID
        }), index != categories.index(before: categories.endIndex) {
            let unclassified = categories.remove(at: index)
            categories.append(unclassified)
        }
    }

    private func moveFrequentlyUsedToTop() {
        guard let index = categories.firstIndex(where: {
            $0.id == AppCategory.frequentlyUsedID
        }), index != categories.startIndex else { return }
        let category = categories.remove(at: index)
        categories.insert(category, at: categories.startIndex)
    }
}

private final class StateSaveGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        return generation
    }

    func isCurrent(_ value: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == value
    }
}

enum LibraryItem: Identifiable {
    case app(LauncherApp)
    case folder(AppFolder)

    var id: String { orderToken }

    var orderToken: String {
        switch self {
        case .app(let app): "app:\(app.id)"
        case .folder(let folder): "folder:\(folder.id)"
        }
    }
}
