import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FolderContentsView: View {
    @ObservedObject var store: LauncherStore
    let initialFolder: AppFolder
    @Environment(\.dismiss) private var dismiss

    private var _draggedAppID = State<String?>(initialValue: nil)
    private var _showRename = State(initialValue: false)
    private var _renameText = State(initialValue: "")
    private var _insertionPreview = State<FolderInsertionPreview?>(initialValue: nil)

    init(store: LauncherStore, initialFolder: AppFolder) {
        self.store = store
        self.initialFolder = initialFolder
    }

    private var folder: AppFolder? {
        store.folders.first { $0.id == initialFolder.id }
    }

    private var apps: [LauncherApp] {
        (folder?.appIDs ?? []).compactMap(store.app(withID:))
    }

    private var insertionPreview: FolderInsertionPreview? {
        get { _insertionPreview.wrappedValue }
        nonmutating set { _insertionPreview.wrappedValue = newValue }
    }

    private var displayedApps: [LauncherApp] {
        guard let insertionPreview else { return apps }
        var order = apps.map(\.id)
        guard order.contains(insertionPreview.movingAppID) else { return apps }
        order.removeAll { $0 == insertionPreview.movingAppID }
        let anchorID: String
        let placeAfter: Bool
        if insertionPreview.leftAppID != insertionPreview.movingAppID {
            anchorID = insertionPreview.leftAppID
            placeAfter = true
        } else if insertionPreview.rightAppID != insertionPreview.movingAppID {
            anchorID = insertionPreview.rightAppID
            placeAfter = false
        } else {
            return apps
        }
        guard let anchor = order.firstIndex(of: anchorID) else { return apps }
        order.insert(
            insertionPreview.movingAppID,
            at: anchor + (placeAfter ? 1 : 0)
        )
        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        return order.compactMap { byID[$0] }
    }

    private var draggedAppID: String? {
        get { _draggedAppID.wrappedValue }
        nonmutating set { _draggedAppID.wrappedValue = newValue }
    }

    private var draggedAppBinding: Binding<String?> {
        Binding(
            get: { draggedAppID },
            set: { draggedAppID = $0 }
        )
    }

    private var showRename: Bool {
        get { _showRename.wrappedValue }
        nonmutating set { _showRename.wrappedValue = newValue }
    }

    private var renameText: String {
        get { _renameText.wrappedValue }
        nonmutating set { _renameText.wrappedValue = newValue }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { showRename },
            set: { showRename = $0 }
        )
    }

    private var renameTextBinding: Binding<String> {
        Binding(
            get: { renameText },
            set: { renameText = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        BilingualText(
                            folder?.name ?? initialFolder.name,
                            size: 22,
                            weight: .semibold
                        )

                        Button {
                            renameText = folder?.name ?? initialFolder.name
                            showRename = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("重命名文件夹")
                    }
                    BilingualText("\(apps.count) 个应用 · 拖动可调整顺序", size: 11.5)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            GeometryReader { geometry in
                let columnCount = 5
                let spacing: CGFloat = 16
                let tileWidth = max(
                    92,
                    (
                        geometry.size.width - 48 -
                        spacing * CGFloat(columnCount - 1)
                    ) / CGFloat(columnCount)
                )
                let rows = stride(
                    from: 0,
                    to: displayedApps.count,
                    by: columnCount
                ).map {
                    Array(
                        displayedApps[
                            $0 ..< min($0 + columnCount, displayedApps.count)
                        ]
                    )
                }

                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { row in
                            HStack(spacing: 0) {
                                ForEach(
                                    Array(row.element.enumerated()),
                                    id: \.offset
                                ) { entry in
                                    folderAppCard(
                                        entry.element,
                                        width: tileWidth
                                    )
                                    if entry.offset < row.element.count - 1 {
                                        folderInsertionGap(
                                            left: entry.element,
                                            right: row.element[entry.offset + 1],
                                            width: spacing
                                        )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(24)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(minWidth: 620, minHeight: 460)
        .background(.regularMaterial)
        .onChange(of: folder?.appIDs.count ?? 0) { _, newValue in
            if newValue == 0 { dismiss() }
        }
        .alert("重命名文件夹", isPresented: renameBinding) {
            TextField("文件夹名称", text: renameTextBinding)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if let folder {
                    store.renameFolder(folder, to: renameText)
                }
            }
        }
    }

    private func folderAppCard(
        _ app: LauncherApp,
        width: CGFloat
    ) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 62, height: 62)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            BilingualText(app.name, size: 11.5, weight: .medium)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(width: width, height: 118)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        }
        .contentShape(Rectangle())
        .overlay {
            AppDragSurface(
                icon: app.icon,
                payload: {
                    draggedAppID = app.id
                    return "folder-item:\(app.id)"
                },
                holdDuration: store.dragHoldDuration,
                select: { _ in },
                open: { store.open(app) },
                cancelDrag: {
                    draggedAppID = nil
                    insertionPreview = nil
                }
            )
        }
        .onDrop(
            of: [UTType.text],
            delegate: FolderContentDropDelegate(
                folderID: initialFolder.id,
                targetAppID: app.id,
                draggedAppID: draggedAppBinding,
                move: { dragged, target in
                    insertionPreview = nil
                    store.moveAppInFolder(
                        initialFolder.id,
                        draggedAppID: dragged,
                        before: target
                    )
                }
            )
        )
    }

    private func folderInsertionGap(
        left: LauncherApp,
        right: LauncherApp,
        width: CGFloat
    ) -> some View {
        InsertionGapTarget(
            accentColor: NSColor(store.accentColor),
            orientation: .vertical,
            targetChanged: { targeted in
                if targeted, let draggedAppID {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = FolderInsertionPreview(
                            movingAppID: draggedAppID,
                            leftAppID: left.id,
                            rightAppID: right.id
                        )
                    }
                } else if insertionPreview?.leftAppID == left.id,
                          insertionPreview?.rightAppID == right.id {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
            },
            performDrop: { payload in
                defer {
                    draggedAppID = nil
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
                guard payload.hasPrefix("folder-item:") else { return false }
                let movingID = String(payload.dropFirst("folder-item:".count))
                let anchorID: String
                let placeAfter: Bool
                if movingID != left.id {
                    anchorID = left.id
                    placeAfter = true
                } else if movingID != right.id {
                    anchorID = right.id
                    placeAfter = false
                } else {
                    return false
                }
                return withAnimation(.snappy(duration: 0.24)) {
                    store.moveAppInFolder(
                        initialFolder.id,
                        draggedAppID: movingID,
                        relativeTo: anchorID,
                        placeAfter: placeAfter
                    )
                    return true
                }
            }
        )
        .frame(width: width, height: 118)
    }
}

private struct FolderInsertionPreview: Equatable {
    let movingAppID: String
    let leftAppID: String
    let rightAppID: String
}

private struct FolderContentDropDelegate: DropDelegate {
    let folderID: String
    let targetAppID: String
    @Binding var draggedAppID: String?
    let move: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedAppID = nil }
        guard let draggedAppID, draggedAppID != targetAppID else { return false }
        move(draggedAppID, targetAppID)
        return true
    }
}
