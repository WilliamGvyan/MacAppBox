import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let isBackgroundScan = ProcessInfo.processInfo.arguments.contains("--background-scan")
    private var scanObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if isBackgroundScan {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isBackgroundScan else {
            NSApp.setActivationPolicy(.accessory)
            for delay in [0.0, 0.1, 0.35, 0.8, 1.4] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSApp.windows.forEach {
                        $0.alphaValue = 0
                        $0.orderOut(nil)
                    }
                }
            }
            scanObserver = NotificationCenter.default.addObserver(
                forName: .macAppBoxScanFinished,
                object: nil,
                queue: .main
            ) { _ in
                NSApp.terminate(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: .macAppBoxStartBackgroundScan,
                    object: nil
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                NSApp.terminate(nil)
            }
            return
        }
        NSApp.setActivationPolicy(.regular)
        for delay in [0.0, 0.15, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.bringMainWindowToFront(of: NSApp)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if isBackgroundScan {
            launchForegroundInstance()
            return true
        }

        return bringMainWindowToFront(of: sender)
    }

    @discardableResult
    private func bringMainWindowToFront(of application: NSApplication) -> Bool {
        application.setActivationPolicy(.regular)
        var windows = application.windows.filter {
            $0.title == "MacApp Box" || $0.canBecomeMain
        }
        if let registered = MainWindowRegistry.shared.window,
           !windows.contains(where: { $0 === registered }) {
            windows.append(registered)
        }
        guard !windows.isEmpty else { return false }
        for window in windows {
            window.alphaValue = 1
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
        if let main = windows.first(where: { $0.title == "MacApp Box" }) ?? windows.first {
            main.makeKeyAndOrderFront(nil)
        }
        application.activate(ignoringOtherApps: true)
        return true
    }

    private func launchForegroundInstance() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct MacAppBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LauncherStore()
    private let isBackgroundScan = ProcessInfo.processInfo.arguments.contains("--background-scan")

    var body: some Scene {
        WindowGroup("MacApp Box") {
            if isBackgroundScan {
                BackgroundScanView(store: store)
            } else {
                RootView(store: store)
                    .frame(minWidth: 900, idealWidth: 1_180, minHeight: 580, idealHeight: 760)
            }
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Setting…") {
                    NotificationCenter.default.post(name: .openMacAppBoxSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu("资料库") {
                Button("粘贴并移入记住的应用") {
                    store.moveRememberedApps(to: store.selectedCategoryID)
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(
                    store.selectionMemory.isEmpty ||
                    store.selectedCategoryID == AppCategory.frequentlyUsedID ||
                    store.selectedCategoryID == AppCategory.autoClassifiedID
                )

                Divider()

                Button("重新扫描") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("清除选择") {
                    store.clearSelection()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(store.selection.isEmpty)
            }
        }
    }
}

extension Notification.Name {
    static let openMacAppBoxSettings = Notification.Name("openMacAppBoxSettings")
    static let macAppBoxScanFinished = Notification.Name("macAppBoxScanFinished")
    static let macAppBoxStartBackgroundScan = Notification.Name("macAppBoxStartBackgroundScan")
}

private struct BackgroundScanView: View {
    @ObservedObject var store: LauncherStore

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(BackgroundWindowHider())
            .task {
                store.refreshIfNeeded()
            }
    }
}

private struct BackgroundWindowHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        for delay in [0.0, 0.1, 0.35, 0.8, 1.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                view.window?.alphaValue = 0
                view.window?.orderOut(nil)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
