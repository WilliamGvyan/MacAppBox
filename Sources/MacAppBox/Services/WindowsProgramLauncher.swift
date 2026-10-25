import Foundation

enum WindowsProgramLauncher {
    private static let virtualMachineName = "Windows 11"
    private static let prlctl = "/usr/local/bin/prlctl"

    static func launch(
        hostURL: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<Void, Error>
            do {
                try ensureVirtualMachineReady()
                let windowsPath = try sharedWindowsPath(for: hostURL)
                let execution = try run(
                    arguments: [
                        "exec",
                        virtualMachineName,
                        "--current-user",
                        "cmd.exe",
                        "/c",
                        "start",
                        "",
                        windowsPath
                    ]
                )
                guard execution.status == 0 else {
                    throw LaunchError.commandFailed(execution.message)
                }
                result = .success(())
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func ensureVirtualMachineReady() throws {
        let listing = try run(arguments: ["list", "-a"])
        guard let line = listing.output
            .components(separatedBy: .newlines)
            .first(where: { $0.contains(virtualMachineName) }) else {
            throw LaunchError.virtualMachineNotFound
        }

        if line.localizedCaseInsensitiveContains("suspended") {
            let result = try run(arguments: ["resume", virtualMachineName])
            guard result.status == 0 else {
                throw LaunchError.commandFailed(result.message)
            }
            Thread.sleep(forTimeInterval: 1.5)
        } else if line.localizedCaseInsensitiveContains("stopped") {
            let result = try run(arguments: ["start", virtualMachineName])
            guard result.status == 0 else {
                throw LaunchError.commandFailed(result.message)
            }
            Thread.sleep(forTimeInterval: 3)
        }
    }

    private static func sharedWindowsPath(for hostURL: URL) throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL.path
        let path = hostURL.standardizedFileURL.path
        guard path.hasPrefix(home + "/") else {
            throw LaunchError.outsideSharedHome
        }
        let relative = String(path.dropFirst(home.count + 1))
            .split(separator: "/")
            .joined(separator: "\\")
        return "\\\\Mac\\Home\\\(relative)"
    }

    private static func run(
        arguments: [String]
    ) throws -> (status: Int32, output: String, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: prlctl)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let message = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return (process.terminationStatus, output, message)
    }

    enum LaunchError: LocalizedError {
        case virtualMachineNotFound
        case outsideSharedHome
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .virtualMachineNotFound:
                "找不到 Parallels 虚拟机“\(virtualMachineName)”"
            case .outsideSharedHome:
                "该程序不在 Parallels 可访问的 Mac 主目录共享范围内"
            case .commandFailed(let message):
                message.isEmpty
                    ? "Parallels 无法启动该 Windows 程序"
                    : message.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
