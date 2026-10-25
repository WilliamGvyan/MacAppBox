import AppKit
import Foundation

struct AppUninstallService {
    private let fileManager = FileManager.default

    func scan(_ app: LauncherApp) -> [UninstallItem] {
        let appURL = URL(fileURLWithPath: app.path)
        guard fileManager.fileExists(atPath: app.path) else { return [] }

        var items: [UninstallItem] = [
            UninstallItem(
                url: appURL,
                title: app.name,
                category: app.origin == .windows ? "Windows 快捷方式" : "应用本体",
                byteSize: allocatedSize(of: appURL),
                isRequired: true
            )
        ]

        guard app.origin != .windows,
              !app.path.hasPrefix("/System/") else {
            return items
        }

        let bundle = Bundle(url: appURL)
        let bundleID = bundle?.bundleIdentifier ?? ""
        let executable = bundle?.infoDictionary?["CFBundleExecutable"] as? String
        let appName = appURL.deletingPathExtension().lastPathComponent
        let names = Set(
            [app.name, appName, executable]
                .compactMap { $0 }
                .filter { $0.count >= 4 }
        )
        let homeLibrary = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)

        let exactCandidates = candidatePaths(
            bundleID: bundleID,
            names: names,
            homeLibrary: homeLibrary
        )
        for candidate in exactCandidates where fileManager.fileExists(atPath: candidate.url.path) {
            guard candidate.url.path != app.path else { continue }
            items.append(
                UninstallItem(
                    url: candidate.url,
                    title: candidate.url.lastPathComponent,
                    category: candidate.category,
                    byteSize: allocatedSize(of: candidate.url)
                )
            )
        }

        if !bundleID.isEmpty {
            for url in spotlightMatches(
                bundleID: bundleID,
                library: homeLibrary
            ) where url.path != app.path &&
                    !url.path.hasPrefix(app.path + "/") &&
                    !items.contains(where: { $0.url.path == url.path }) {
                items.append(
                    UninstallItem(
                        url: url,
                        title: url.lastPathComponent,
                        category: category(for: url),
                        byteSize: allocatedSize(of: url)
                    )
                )
            }
        }

        return items.sorted {
            if $0.isRequired != $1.isRequired { return $0.isRequired }
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    func recycle(_ items: [UninstallItem], completion: @escaping (Error?) -> Void) {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            completion(nil)
            return
        }
        NSWorkspace.shared.recycle(urls) { _, error in
            completion(error)
        }
    }

    private func candidatePaths(
        bundleID: String,
        names: Set<String>,
        homeLibrary: URL
    ) -> [(url: URL, category: String)] {
        var result: [(URL, String)] = []

        let bundleCandidates: [(String, String)] = [
            ("Application Support", "应用支持"),
            ("Caches", "缓存"),
            ("Preferences", "偏好设置"),
            ("Containers", "应用容器"),
            ("Group Containers", "共享容器"),
            ("Logs", "日志"),
            ("Saved Application State", "窗口状态"),
            ("WebKit", "网页数据"),
            ("HTTPStorages", "网络缓存"),
            ("Cookies", "网络凭据"),
            ("LaunchAgents", "启动代理"),
            ("Application Scripts", "应用脚本"),
            ("Services", "服务")
        ]

        for (folder, category) in bundleCandidates {
            let base = homeLibrary.appendingPathComponent(folder, isDirectory: true)
            guard !bundleID.isEmpty else { continue }
            let suffixes: [String] = switch folder {
            case "Preferences": [".plist"]
            case "Saved Application State": [".savedState"]
            case "Cookies": [".binarycookies"]
            case "LaunchAgents": [".plist"]
            default: [""]
            }
            for suffix in suffixes {
                result.append((
                    base.appendingPathComponent(bundleID + suffix),
                    category
                ))
            }

            if folder == "Group Containers",
               let children = try? fileManager.contentsOfDirectory(
                   at: base,
                   includingPropertiesForKeys: nil
               ) {
                for child in children where child.lastPathComponent
                    .localizedCaseInsensitiveContains(bundleID) {
                    result.append((child, category))
                }
            }
        }

        let plainFolders: [(String, String)] = [
            ("Application Support", "应用支持"),
            ("Caches", "缓存"),
            ("Logs", "日志")
        ]
        for (folder, category) in plainFolders {
            let base = homeLibrary.appendingPathComponent(folder, isDirectory: true)
            for name in names {
                result.append((base.appendingPathComponent(name), category))
                result.append((base.appendingPathComponent(name + ".plist"), category))
            }
        }

        var seen = Set<String>()
        return result.filter { seen.insert($0.0.path).inserted }
    }

    private func spotlightMatches(bundleID: String, library: URL) -> [URL] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "-onlyin",
            library.path,
            "kMDItemCFBundleIdentifier == '\(bundleID.replacingOccurrences(of: "'", with: "\\'"))'"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    private func category(for url: URL) -> String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return switch parent {
        case "Application Support": "应用支持"
        case "Caches": "缓存"
        case "Preferences": "偏好设置"
        case "Containers": "应用容器"
        case "Group Containers": "共享容器"
        case "Logs": "日志"
        case "Saved Application State": "窗口状态"
        case "WebKit": "网页数据"
        case "HTTPStorages": "网络缓存"
        case "Cookies": "网络凭据"
        case "LaunchAgents": "启动代理"
        case "Application Scripts": "应用脚本"
        default: "关联文件"
        }
    }

    private func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }

        if values.isDirectory == true {
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            ) else { return 0 }
            var total: Int64 = 0
            for case let child as URL in enumerator {
                guard let childValues = try? child.resourceValues(forKeys: keys),
                      childValues.isDirectory != true else { continue }
                total += Int64(
                    childValues.totalFileAllocatedSize ??
                    childValues.fileAllocatedSize ??
                    childValues.fileSize ??
                    0
                )
            }
            return total
        }

        return Int64(
            values.totalFileAllocatedSize ??
            values.fileAllocatedSize ??
            values.fileSize ??
            0
        )
    }
}
