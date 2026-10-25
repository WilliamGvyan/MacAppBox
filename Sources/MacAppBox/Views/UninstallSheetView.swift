import AppKit
import SwiftUI

struct UninstallSheetView: View {
    @ObservedObject var store: LauncherStore
    let app: LauncherApp
    @Environment(\.dismiss) private var dismiss

    private let service = AppUninstallService()
    private var _items = State<[UninstallItem]>(initialValue: [])
    private var _selectedIDs = State<Set<String>>(initialValue: [])
    private var _isScanning = State(initialValue: true)
    private var _isRemoving = State(initialValue: false)
    private var _errorMessage = State<String?>(initialValue: nil)

    private var items: [UninstallItem] {
        get { _items.wrappedValue }
        nonmutating set { _items.wrappedValue = newValue }
    }

    private var selectedIDs: Set<String> {
        get { _selectedIDs.wrappedValue }
        nonmutating set { _selectedIDs.wrappedValue = newValue }
    }

    private var isScanning: Bool {
        get { _isScanning.wrappedValue }
        nonmutating set { _isScanning.wrappedValue = newValue }
    }

    private var isRemoving: Bool {
        get { _isRemoving.wrappedValue }
        nonmutating set { _isRemoving.wrappedValue = newValue }
    }

    private var errorMessage: String? {
        get { _errorMessage.wrappedValue }
        nonmutating set { _errorMessage.wrappedValue = newValue }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var selectedItems: [UninstallItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.byteSize }
    }

    private var appIsRunning: Bool {
        store.isRunning(app)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            if isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在扫描应用与关联文件…")
                        .font(.app(12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileList
            }

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            footer
        }
        .frame(width: 720, height: 560)
        .background(.regularMaterial)
        .onAppear(perform: scan)
        .alert("无法完成卸载", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                BilingualText("卸载 \(app.name)", size: 21, weight: .semibold)
                BilingualText(
                    "先核对文件和空间占用，再把所选内容移到废纸篓。",
                    size: 11
                )
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.065)))
            }
            .buttonStyle(.plain)
            .disabled(isRemoving)
        }
        .padding(20)
    }

    private var fileList: some View {
        VStack(spacing: 10) {
            HStack {
                BilingualText(
                    "找到 \(items.count) 个项目，共 \(formattedSize(items.reduce(0) { $0 + $1.byteSize }))",
                    size: 11,
                    weight: .medium
                )
                .foregroundStyle(.secondary)

                Spacer()

                Button("全选") {
                    selectedIDs = Set(items.map(\.id))
                }
                .font(.app(10.5, weight: .medium))
                .buttonStyle(.plain)

                Text("·")
                    .foregroundStyle(.tertiary)

                Button("仅应用本体") {
                    selectedIDs = Set(items.filter(\.isRequired).map(\.id))
                }
                .font(.app(10.5, weight: .medium))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(items) { item in
                        UninstallItemRow(
                            item: item,
                            accentColor: store.accentColor,
                            isSelected: selectedIDs.contains(item.id),
                            toggle: {
                                guard !item.isRequired else { return }
                                if selectedIDs.contains(item.id) {
                                    selectedIDs.remove(item.id)
                                } else {
                                    selectedIDs.insert(item.id)
                                }
                            },
                            reveal: {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                BilingualText(
                    "已选 \(selectedItems.count) 项 · \(formattedSize(selectedSize))",
                    size: 10.5,
                    weight: .medium
                )
                .foregroundStyle(.secondary)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(removalButtonTitle) {
                    requestRemoval()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedItems.isEmpty || isRemoving)
            }
        }
        .padding(16)
    }

    private func scan() {
        guard items.isEmpty else { return }
        isScanning = true
        let target = app
        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = service.scan(target)
            DispatchQueue.main.async {
                items = scanned
                selectedIDs = Set(scanned.map(\.id))
                isScanning = false
            }
        }
    }

    private func removeSelected() {
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        isRemoving = true
        service.recycle(targets) { error in
            DispatchQueue.main.async {
                isRemoving = false
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    store.refresh()
                    dismiss()
                }
            }
        }
    }

    private var removalButtonTitle: String {
        if isRemoving { return "正在处理…" }
        return appIsRunning ? "退出并卸载" : "移到废纸篓"
    }

    private func requestRemoval() {
        guard !selectedItems.isEmpty, !isRemoving else { return }
        guard appIsRunning else {
            removeSelected()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(app.name) 正在运行"
        alert.informativeText = "深度清理前需要退出应用。请先保存正在编辑的内容；如果应用没有完全退出，卸载会中止。"
        alert.addButton(withTitle: "退出并继续")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isRemoving = true
        store.quitForUninstall(app)
        waitForTermination(attempt: 0)
    }

    private func waitForTermination(attempt: Int) {
        guard !store.isRunning(app) else {
            if attempt >= 16 {
                isRemoving = false
                errorMessage = "应用没有完全退出。请保存工作后手动退出，再重新尝试卸载。"
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                waitForTermination(attempt: attempt + 1)
            }
            return
        }
        removeSelected()
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct UninstallItemRow: View {
    let item: UninstallItem
    let accentColor: Color
    let isSelected: Bool
    let toggle: () -> Void
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: toggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isRequired ? Color.secondary : accentColor)
            }
            .buttonStyle(.plain)
            .disabled(item.isRequired)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.app(12, weight: .medium))
                        .lineLimit(1)

                    Text(item.category)
                        .font(.app(9))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                }

                Text(item.url.path)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 10)

            Text(ByteCountFormatter.string(fromByteCount: item.byteSize, countStyle: .file))
                .font(.app(10.5))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(action: reveal) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("在访达中显示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? Color.primary.opacity(0.05)
                        : Color.primary.opacity(0.022)
                )
        }
    }
}
