import AppKit
import Foundation

struct AppScanner {
    private let fileManager = FileManager.default
    private let cachedIcons: [String: NSImage]

    init(cachedIcons: [String: NSImage] = [:]) {
        self.cachedIcons = cachedIcons
    }

    func scan() -> ScanResult {
        var apps: [LauncherApp] = []
        var knownIDs = Set<String>()
        var knownPaths = Set<String>()

        for app in scanSelfMadeApps() {
            if knownIDs.insert(app.id).inserted {
                apps.append(app)
                knownPaths.insert(canonicalPath(app.path))
            }
        }

        for app in scanSelfMadeWindowsApps() where knownIDs.insert(app.id).inserted {
            apps.append(app)
        }

        for app in scanSelfMadeLibraryApps() where knownIDs.insert(app.id).inserted {
            apps.append(app)
            knownPaths.insert(canonicalPath(app.path))
        }

        for app in scanThirdPartyLibraryApps() where knownIDs.insert(app.id).inserted {
            apps.append(app)
            knownPaths.insert(canonicalPath(app.path))
        }

        for app in scanMacApps(skipping: knownPaths) {
            if knownIDs.insert(app.id).inserted {
                apps.append(app)
            }
        }

        let windowsResult = scanParallelsApps()
        for app in windowsResult.apps where knownIDs.insert(app.id).inserted {
            apps.append(app)
        }

        apps.sort {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return ScanResult(
            apps: apps,
            filteredWindowsCount: windowsResult.filteredCount
        )
    }

    private func scanMacApps(skipping knownPaths: Set<String>) -> [LauncherApp] {
        let home = fileManager.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        var result: [LauncherApp] = []
        var paths = Set<String>()

        for root in roots {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil
            ) else { continue }

            for url in entries where url.pathExtension.lowercased() == "app" {
                let canonical = canonicalPath(url.path)
                guard !knownPaths.contains(canonical),
                      !url.lastPathComponent.hasPrefix("自研软件"),
                      paths.insert(canonical).inserted else { continue }

                let bundle = Bundle(url: url)
                let bundleID = bundle?.bundleIdentifier ?? ""
                let identity = bundleID.isEmpty ? canonical : bundleID
                let appID = "mac:\(identity)"
                let name = displayName(for: url) ?? url.deletingPathExtension().lastPathComponent
                let icon = cachedIcons[appID]
                    ?? NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 128, height: 128)
                result.append(
                    LauncherApp(
                        id: appID,
                        name: name,
                        path: url.path,
                        platform: .macOS,
                        origin: .macOS,
                        icon: icon,
                        isWindowsUtility: false,
                        hostName: nil
                    )
                )
            }
        }
        return result
    }

    private func scanSelfMadeLibraryApps() -> [LauncherApp] {
        let library = URL(
            fileURLWithPath: LauncherConstants.selfMadeLibrary,
            isDirectory: true
        )
        let macRoot = library.appendingPathComponent("macOS", isDirectory: true)
        let windowsRoot = library.appendingPathComponent("Windows", isDirectory: true)
        var result: [LauncherApp] = []
        var seenIDs = Set<String>()

        if let macs = try? fileManager.contentsOfDirectory(
            at: macRoot,
            includingPropertiesForKeys: nil
        ) {
            for url in macs where url.pathExtension.lowercased() == "app" {
                let canonical = canonicalPath(url.path)
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? canonical
                let appID = "own:\(bundleID)"
                guard seenIDs.insert(appID).inserted else { continue }
                let icon = cachedIcons[appID]
                    ?? GeneratedAppIcon.icon(for: url, name: displayName(for: url) ?? "")
                icon.size = NSSize(width: 128, height: 128)
                result.append(
                    LauncherApp(
                        id: appID,
                        name: displayName(for: url)
                            ?? url.deletingPathExtension().lastPathComponent,
                        path: url.path,
                        platform: .macOS,
                        origin: .selfMade,
                        icon: icon,
                        isWindowsUtility: false,
                        hostName: nil
                    )
                )
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: windowsRoot,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return result }

        let inHouseRoot = windowsRoot
            .appendingPathComponent("刷机程序/InHouse-Programs")
            .path
        let inHouseAllowed = [
            inHouseRoot + "/刷机程序入口.exe",
            inHouseRoot + "/川崎-Kawasaki/Kawasaki-KCMonitor/kawasaki_net_toggle.exe",
            inHouseRoot + "/川崎-Kawasaki/Kawasaki-KCMonitor/tools/川崎刷机.exe"
        ]
        let skippedParts = [
            "/drivers/",
            "/engines/uarttest/",
            "/tools/legacy/",
            "/_build/out/",
            "/_Launcher/out/",
            "/com0com setup.exe"
        ]

        for case let url as URL in enumerator
        where url.pathExtension.lowercased() == "exe" {
            let path = url.path
            if path.hasPrefix(inHouseRoot), !inHouseAllowed.contains(path) {
                continue
            }
            if skippedParts.contains(where: { path.localizedCaseInsensitiveContains($0) }) {
                continue
            }
            let canonical = canonicalPath(path)
            let appID = "own-windows:\(canonical)"
            guard seenIDs.insert(appID).inserted else { continue }
            let icon = cachedIcons[appID]
                ?? GeneratedAppIcon.icon(for: url, name: url.deletingPathExtension().lastPathComponent)
            icon.size = NSSize(width: 128, height: 128)
            result.append(
                LauncherApp(
                    id: appID,
                    name: url.deletingPathExtension().lastPathComponent,
                    path: path,
                    platform: .windows,
                    origin: .selfMade,
                    icon: icon,
                    isWindowsUtility: false,
                    hostName: "自研软件"
                )
            )
        }
        return result
    }

    private func scanThirdPartyLibraryApps() -> [LauncherApp] {
        let library = URL(
            fileURLWithPath: LauncherConstants.thirdPartyLibrary,
            isDirectory: true
        )
        let macRoot = library.appendingPathComponent("macOS", isDirectory: true)
        let windowsRoot = library.appendingPathComponent("Windows", isDirectory: true)
        var result: [LauncherApp] = []
        var seenIDs = Set<String>()

        if let macs = try? fileManager.contentsOfDirectory(
            at: macRoot,
            includingPropertiesForKeys: nil
        ) {
            for url in macs where url.pathExtension.lowercased() == "app" {
                let canonical = canonicalPath(url.path)
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? canonical
                let appID = "third:\(bundleID)"
                guard seenIDs.insert(appID).inserted else { continue }
                let name = displayName(for: url)
                    ?? url.deletingPathExtension().lastPathComponent
                let icon = cachedIcons[appID]
                    ?? NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 128, height: 128)
                result.append(
                    LauncherApp(
                        id: appID,
                        name: name,
                        path: url.path,
                        platform: .macOS,
                        origin: .thirdParty,
                        icon: icon,
                        isWindowsUtility: false,
                        hostName: nil
                    )
                )
            }
        }

        if let folders = try? fileManager.contentsOfDirectory(
            at: windowsRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for folder in folders where folder.hasDirectoryPath {
                let metadata = folder.appendingPathComponent(".macappbox-entry")
                guard let relative = try? String(contentsOf: metadata, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !relative.isEmpty else { continue }
                let exe = folder.appendingPathComponent(relative)
                guard fileManager.fileExists(atPath: exe.path) else { continue }
                let canonical = canonicalPath(exe.path)
                let appID = "third-windows:\(canonical)"
                guard seenIDs.insert(appID).inserted else { continue }
                let icon = cachedIcons[appID]
                    ?? GeneratedAppIcon.icon(
                        for: exe,
                        name: exe.deletingPathExtension().lastPathComponent
                    )
                icon.size = NSSize(width: 128, height: 128)
                result.append(
                    LauncherApp(
                        id: appID,
                        name: exe.deletingPathExtension().lastPathComponent,
                        path: exe.path,
                        platform: .windows,
                        origin: .thirdParty,
                        icon: icon,
                        isWindowsUtility: false,
                        hostName: "第三方软件"
                    )
                )
            }
        }

        return result
    }

    private func scanSelfMadeApps() -> [LauncherApp] {
        guard let text = try? String(
            contentsOfFile: LauncherConstants.selfMadeRegistry,
            encoding: .utf8
        ) else { return [] }

        var result: [LauncherApp] = []
        var seenPaths = Set<String>()

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let fields = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fields.count >= 2, fields[1].hasSuffix(".app") else { continue }

            let path = fields[1]
            let canonical = canonicalPath(path)
            guard fileManager.fileExists(atPath: path),
                  seenPaths.insert(canonical).inserted else { continue }

            let url = URL(fileURLWithPath: path)
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? canonical
            let appID = "own:\(bundleID)"
            let icon = cachedIcons[appID]
                ?? GeneratedAppIcon.icon(for: url, name: fields[0])
            icon.size = NSSize(width: 128, height: 128)
            result.append(
                LauncherApp(
                    id: appID,
                    name: fields[0].isEmpty ? url.deletingPathExtension().lastPathComponent : fields[0],
                    path: path,
                    platform: .macOS,
                    origin: .selfMade,
                    icon: icon,
                    isWindowsUtility: false,
                    hostName: nil
                )
            )
        }
        return result
    }

    private func scanSelfMadeWindowsApps() -> [LauncherApp] {
        guard let text = try? String(
            contentsOfFile: LauncherConstants.selfMadeRegistry,
            encoding: .utf8
        ) else { return [] }

        var result: [LauncherApp] = []
        var seenPaths = Set<String>()

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let fields = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fields.count >= 3,
                  fields[2].lowercased().hasSuffix(".exe"),
                  fields.count < 5 || fields[4] != "隐藏" else { continue }

            let path = fields[2]
            let canonical = canonicalPath(path)
            guard fileManager.fileExists(atPath: path),
                  seenPaths.insert(canonical).inserted else { continue }

            let url = URL(fileURLWithPath: path)
            let appID = "own-windows:\(canonical)"
            let icon = cachedIcons[appID]
                ?? GeneratedAppIcon.icon(for: url, name: fields[0])
            icon.size = NSSize(width: 128, height: 128)
            result.append(
                LauncherApp(
                    id: appID,
                    name: fields[0].isEmpty
                        ? url.deletingPathExtension().lastPathComponent
                        : fields[0],
                    path: path,
                    platform: .windows,
                    origin: .selfMade,
                    icon: icon,
                    isWindowsUtility: false,
                    hostName: "自研软件"
                )
            )
        }
        return result
    }

    private func scanParallelsApps() -> (apps: [LauncherApp], filteredCount: Int) {
        let home = fileManager.homeDirectoryForCurrentUser
        let parallellsRoot = home.appendingPathComponent("Applications (Parallels)", isDirectory: true)
        guard let folders = try? fileManager.contentsOfDirectory(
            at: parallellsRoot,
            includingPropertiesForKeys: nil
        ) else { return ([], 0) }

        var apps: [LauncherApp] = []
        var filteredCount = 0
        var seenIDs = Set<String>()

        for folder in folders where folder.lastPathComponent.hasSuffix("Applications.localized") {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            ) else { continue }

            for url in entries where url.pathExtension.lowercased() == "app" {
                let bundle = Bundle(url: url)
                let info = bundle?.infoDictionary
                let bundleID = bundle?.bundleIdentifier ?? canonicalPath(url.path)
                let identity = "win:\(bundleID)"
                guard seenIDs.insert(identity).inserted else { continue }

                let name = (info?["CFBundleDisplayName"] as? String)
                    ?? (info?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let isUtility = isWindowsUtility(name: name)
                if isUtility { filteredCount += 1 }
                let icon = cachedIcons[identity]
                    ?? NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 128, height: 128)
                let vmName = readParallelsVMName(
                    from: url.appendingPathComponent("Contents/Resources/AppParams.pva")
                )
                apps.append(
                    LauncherApp(
                        id: identity,
                        name: name,
                        path: url.path,
                        platform: .windows,
                        origin: .windows,
                        icon: icon,
                        isWindowsUtility: isUtility,
                        hostName: vmName
                    )
                )
            }
        }
        return (apps, filteredCount)
    }

    private func readParallelsVMName(from url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text.components(separatedBy: .newlines)
            .first { $0.hasPrefix("VM Name =") }?
            .split(separator: "=", maxSplits: 1)
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayName(for url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        return (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
    }

    private func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private func isWindowsUtility(name: String) -> Bool {
        let exactNames: Set<String> = [
            "COM Surrogate",
            "CmDust",
            "CodeMeter Control Center",
            "CODESYS Control Win V3 - x64",
            "CODESYS Control Win V3 - x64 SysTray",
            "CODESYS Gateway V3",
            "Credential Manager UI Host",
            "Configure Virtual Serial Port Driver",
            "DiskPart",
            "Eplan.IdentityClient",
            "File Picker UI Host",
            "Game Bar",
            "HTML5 Control Editor",
            "Licence Manager",
            "Microsoft Clipchamp",
            "Microsoft 管理控制台",
            "Microsoft® HTML 帮助可执行文件",
            "Microsoft Store",
            "Microsoft 资讯",
            "Modern Apps",
            "ODBC 数据源(32 位)",
            "Program Compatibility Assistant User Interface",
            "ShellHost",
            "Solitaire & Casual Games",
            "Visual Styles Editor",
            "Windows Media Player Legacy",
            "Windows PowerShell",
            "Windows PowerShell (x86)",
            "Windows PowerShell ISE",
            "Windows PowerShell ISE (x86)",
            "Windows Security",
            "Windows 备份",
            "Windows 问题报告",
            "Windows 工具",
            "任务管理器",
            "便笺",
            "入门",
            "单击以执行(预览)",
            "反馈中心",
            "命令提示符",
            "天气",
            "字符映射表",
            "实时字幕",
            "屏幕键盘",
            "媒体播放器",
            "开发人员主页",
            "录音机",
            "快速助手",
            "恢复驱动器",
            "截图工具",
            "手机连接",
            "放大镜",
            "文件资源管理器",
            "时钟",
            "更改打印机设置",
            "服务控制管理器配置工具",
            "步骤记录器",
            "注册表编辑器",
            "照片",
            "电源设置命令行工具",
            "画图",
            "相机",
            "碎片整理和优化驱动器",
            "磁盘清理",
            "系统信息",
            "系统配置",
            "终端",
            "网络命令外壳",
            "获取帮助",
            "计算器",
            "记事本",
            "讲述人",
            "设置",
            "语音访问",
            "资源监视器",
            "远程桌面连接",
            "配置工具",
            "配置工具 [1]",
            "Setup",
            "rgnupdt",
            "setupc.exe"
        ]

        if exactNames.contains(name) { return true }
        if name.hasPrefix("Install ") || name.hasPrefix("Install or Uninstall") { return true }
        if name.localizedCaseInsensitiveContains("HTML 帮助") { return true }
        return false
    }
}
