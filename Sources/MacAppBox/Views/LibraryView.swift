import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var store: LauncherStore
    @Binding var showSettings: Bool
    let openSettingsPane: (SettingsPane) -> Void
    private var _activeSheet = State<LibrarySheet?>(initialValue: nil)
    private var _folderToRename = State<AppFolder?>(initialValue: nil)
    private var _renameText = State(initialValue: "")
    private var _draggedItemToken = State<String?>(initialValue: nil)
    private var _groupingTargetID = State<String?>(initialValue: nil)
    private var _insertionPreview = State<LibraryInsertionPreview?>(initialValue: nil)
    private var _classificationDropTargetID = State<String?>(initialValue: nil)
    private var _thirdPartyImportError = State<String?>(initialValue: nil)

    private let tileSpacing: CGFloat = 24

    init(
        store: LauncherStore,
        showSettings: Binding<Bool>,
        openSettingsPane: @escaping (SettingsPane) -> Void
    ) {
        self.store = store
        self._showSettings = showSettings
        self.openSettingsPane = openSettingsPane
    }

    private var activeSheet: LibrarySheet? {
        get { _activeSheet.wrappedValue }
        nonmutating set { _activeSheet.wrappedValue = newValue }
    }

    private var folderToRename: AppFolder? {
        get { _folderToRename.wrappedValue }
        nonmutating set { _folderToRename.wrappedValue = newValue }
    }

    private var renameText: String {
        get { _renameText.wrappedValue }
        nonmutating set { _renameText.wrappedValue = newValue }
    }

    private var activeSheetBinding: Binding<LibrarySheet?> {
        Binding(
            get: { activeSheet },
            set: { activeSheet = $0 }
        )
    }

    private var renameTextBinding: Binding<String> {
        Binding(
            get: { renameText },
            set: { renameText = $0 }
        )
    }

    private var draggedItemToken: String? {
        get { _draggedItemToken.wrappedValue }
        nonmutating set { _draggedItemToken.wrappedValue = newValue }
    }

    private var groupingTargetID: String? {
        get { _groupingTargetID.wrappedValue }
        nonmutating set { _groupingTargetID.wrappedValue = newValue }
    }

    private var draggedItemBinding: Binding<String?> {
        Binding(
            get: { draggedItemToken },
            set: { draggedItemToken = $0 }
        )
    }

    private var groupingTargetBinding: Binding<String?> {
        Binding(
            get: { groupingTargetID },
            set: { groupingTargetID = $0 }
        )
    }

    private var insertionPreview: LibraryInsertionPreview? {
        get { _insertionPreview.wrappedValue }
        nonmutating set { _insertionPreview.wrappedValue = newValue }
    }

    private var insertionPreviewBinding: Binding<LibraryInsertionPreview?> {
        Binding(
            get: { insertionPreview },
            set: { insertionPreview = $0 }
        )
    }

    private var classificationDropTargetID: String? {
        get { _classificationDropTargetID.wrappedValue }
        nonmutating set { _classificationDropTargetID.wrappedValue = newValue }
    }

    private var classificationDropTargetBinding: Binding<String?> {
        Binding(
            get: { classificationDropTargetID },
            set: { classificationDropTargetID = $0 }
        )
    }

    private var thirdPartyImportErrorBinding: Binding<Bool> {
        Binding(
            get: { _thirdPartyImportError.wrappedValue != nil },
            set: { if !$0 { _thirdPartyImportError.wrappedValue = nil } }
        )
    }

    private var displayedLibraryItems: [LibraryItem] {
        let items = store.currentLibraryItems
        guard let insertionPreview else { return items }
        let available = Dictionary(
            uniqueKeysWithValues: items.map { ($0.orderToken, $0) }
        )
        var order = items.map(\.orderToken)
        let moving = insertionPreview.movingTokens.filter {
            available[$0] != nil
        }
        guard !moving.isEmpty else { return items }

        order.removeAll { moving.contains($0) }
        guard !moving.contains(insertionPreview.targetToken),
              let target = order.firstIndex(of: insertionPreview.targetToken) else {
            return items
        }
        order.insert(
            contentsOf: moving,
            at: target + (insertionPreview.placeAfter ? 1 : 0)
        )
        return order.compactMap { available[$0] }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            GeometryReader { geometry in
                Group {
                    if store.selectedCategoryID == AppCategory.autoClassifiedID {
                        autoClassificationReport
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if store.currentItemCount == 0 {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        appGrid(in: geometry.size)
                    }
                }
                .id(store.selectedCategoryID)
                .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.17), value: store.selectedCategoryID)

            statusBar
        }
        .background {
            Color.primary.opacity(0.012)
        }
        .contextMenu {
            Button(store.isSelectionMode ? "完成多项选择" : "多项选择") {
                withAnimation(.snappy(duration: 0.18)) {
                    store.toggleSelectionMode()
                }
            }
            if !store.selectionMemory.isEmpty,
               store.selectedCategoryID != AppCategory.frequentlyUsedID,
               store.selectedCategoryID != AppCategory.autoClassifiedID {
                Button("粘贴并移入 \(store.selectionMemory.count) 个应用") {
                    store.moveRememberedApps(to: store.selectedCategoryID)
                }
                Button("清除已记住的选择") {
                    store.clearSelectionMemory()
                }
            }
            Divider()
            settingsMenuItems
            Divider()
            Button("导入第三方软件…") {
                importThirdPartySoftware()
            }
            Button("重新扫描") {
                store.refresh()
            }
            Divider()
            Button("退出 MacApp Box") {
                NSApp.terminate(nil)
            }
        }
        .sheet(item: activeSheetBinding) { sheet in
            switch sheet {
            case .folder(let folder):
                FolderContentsView(store: store, initialFolder: folder)
            case .uninstall(let app):
                UninstallSheetView(store: store, app: app)
            }
        }
        .alert(
            "重命名文件夹",
            isPresented: Binding(
                get: { folderToRename != nil },
                set: { if !$0 { folderToRename = nil } }
            )
        ) {
            TextField("文件夹名称", text: renameTextBinding)
            Button("取消", role: .cancel) {
                folderToRename = nil
            }
            Button("保存") {
                if let folder = folderToRename {
                    store.renameFolder(folder, to: renameText)
                }
                folderToRename = nil
            }
        }
        .alert("导入第三方软件失败", isPresented: thirdPartyImportErrorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(_thirdPartyImportError.wrappedValue ?? "未知错误")
        }
    }

    private func importThirdPartySoftware() {
        let panel = NSOpenPanel()
        panel.title = "导入第三方软件"
        panel.message = "选择 .app、.exe 或整个软件文件夹；带 DLL/资源文件时请选择整个文件夹。"
        panel.prompt = "导入"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .applicationBundle,
            .folder,
            UTType(filenameExtension: "exe") ?? .data
        ]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importThirdPartySoftware(from: url)
        } catch {
            _thirdPartyImportError.wrappedValue = error.localizedDescription
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            searchField
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openSettingsPane(.layout)
        }
        .help("双击空白区域设置主界面布局")
        .padding(.horizontal, 30)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .frame(height: 58)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            SearchFocusField(
                text: $store.searchText,
                isFocused: $store.isSearchFocused
            )
            .frame(width: 154, height: 22)

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 200, height: 32)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    store.isSearchFocused
                        ? store.accentColor.opacity(0.075)
                        : Color(nsColor: .windowBackgroundColor).opacity(0.48)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            store.isSearchFocused
                                ? store.accentColor.opacity(0.32)
                                : Color.primary.opacity(0.082),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: store.isSearchFocused
                        ? store.accentColor.opacity(0.12)
                        : .clear,
                    radius: 7
                )
        }
        .animation(.easeOut(duration: 0.16), value: store.isSearchFocused)
    }

    private func appGrid(in size: CGSize) -> some View {
        let desiredTileWidth = 104 * store.iconScale
        let effectiveSpacing = max(14, min(30, tileSpacing * sqrt(store.iconScale)))
        let automaticColumnsCount = max(
            3,
            min(
                16,
                Int((size.width - 60 + effectiveSpacing) / (desiredTileWidth + effectiveSpacing))
            )
        )
        let columnsCount = (1...16).contains(store.gridColumnCount)
            ? store.gridColumnCount
            : automaticColumnsCount
        let fixedRows = (1...8).contains(store.gridRowCount)
            ? store.gridRowCount
            : nil
        let contentWidth = max(120, size.width - 60)
        let leadingRailWidth = max(18, effectiveSpacing)
        let tileWidth = max(
            36,
            (
                contentWidth -
                leadingRailWidth -
                effectiveSpacing * CGFloat(columnsCount - 1)
            ) / CGFloat(columnsCount)
        )
        let nameSize = max(8, min(17, 11.5 * sqrt(store.iconScale)))
        let rowSpacing = max(9, 24 * sqrt(store.iconScale))
        let baseItems = store.currentLibraryItems
        let items = displayedLibraryItems
        let baseRows = stride(from: 0, to: baseItems.count, by: columnsCount).map {
            Array(baseItems[$0 ..< min($0 + columnsCount, baseItems.count)])
        }
        let rows = stride(from: 0, to: items.count, by: columnsCount).map {
            Array(items[$0 ..< min($0 + columnsCount, items.count)])
        }
        let baseIconSize = min(
            150,
            max(18, 72 * store.iconScale)
        )
        let nameArea = store.showNames ? max(45, nameSize * 2 + 27) : 18
        let availableHeight = max(120, size.height - 36)
        let maximumRowHeight = fixedRows != nil
            ? max(
                54,
                (
                    availableHeight -
                    rowSpacing * CGFloat(max(0, (fixedRows ?? 1) - 1))
                ) / CGFloat(fixedRows ?? 1)
            )
            : .greatestFiniteMagnitude
        let iconSize = min(
            baseIconSize,
            max(18, tileWidth - 24),
            max(18, maximumRowHeight - nameArea - 18)
        )
        let rowHeight = min(
            maximumRowHeight,
            iconSize
            + (store.showNames ? max(45, nameSize * 2 + 27) : 18)
            + 18
        )
        let rowsHeight = rows.isEmpty
            ? 0
            : CGFloat(rows.count) * rowHeight +
                CGFloat(max(0, rows.count - 1)) * rowSpacing
        let trailingBlankHeight = max(
            48,
            size.height - rowsHeight - 36
        )

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    let baseRow = baseRows.indices.contains(row.offset)
                        ? baseRows[row.offset]
                        : row.element
                    let previousBaseRow = row.offset > 0 &&
                        baseRows.indices.contains(row.offset - 1)
                        ? baseRows[row.offset - 1]
                        : []
                    let nextBaseRow = baseRows.indices.contains(row.offset + 1)
                        ? baseRows[row.offset + 1]
                        : []

                    HStack(spacing: 0) {
                        rowLeadingInsertionView(
                            first: baseRow.first ?? row.element[0],
                            previous: previousBaseRow.last,
                            width: leadingRailWidth,
                            height: rowHeight
                        )

                        ForEach(Array(row.element.enumerated()), id: \.offset) { entry in
                            libraryItemView(
                                entry.element,
                                iconSize: iconSize,
                                nameSize: nameSize,
                                tileWidth: tileWidth,
                                rowHeight: rowHeight
                            )

                            if entry.offset < row.element.count - 1 {
                                if draggedItemToken == nil {
                                    Color.clear
                                        .frame(
                                            width: effectiveSpacing,
                                            height: rowHeight
                                        )
                                } else {
                                    insertionGapView(
                                        left: entry.element,
                                        right: row.element[entry.offset + 1],
                                        width: effectiveSpacing,
                                        height: rowHeight
                                    )
                                }
                            }
                        }

                        if row.offset == rows.count - 1,
                           row.element.count < columnsCount {
                            let occupiedWidth =
                                leadingRailWidth +
                                CGFloat(row.element.count) * tileWidth +
                                CGFloat(max(0, row.element.count - 1)) *
                                    effectiveSpacing
                            endInsertionView(
                                width: max(0, contentWidth - occupiedWidth),
                                height: rowHeight,
                                orientation: .horizontal
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if row.offset < rows.count - 1,
                       let left = baseRow.last ?? row.element.last,
                       let right = nextBaseRow.first ??
                            rows[row.offset + 1].first {
                        rowInsertionGapView(
                            left: left,
                            right: right,
                            width: max(120, size.width - 60),
                            height: max(18, rowSpacing)
                        )
                    }
                }

                endInsertionView(
                    width: contentWidth,
                    height: trailingBlankHeight,
                    orientation: .horizontal
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.never)
        .animation(
            .snappy(duration: 0.18),
            value: displayedLibraryItems.map(\.id)
        )
    }

    private var autoClassificationReport: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if store.autoClassificationGroups.isEmpty {
                    Text("无")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(store.autoClassificationGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(group.title)：")
                                .font(.app(14, weight: .semibold))
                                .foregroundStyle(store.accentColor)

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(
                                        .flexible(minimum: 96),
                                        spacing: 14,
                                        alignment: .leading
                                    ),
                                    count: store.classificationReferenceColumns
                                ),
                                alignment: .leading,
                                spacing: 9
                            ) {
                                ForEach(group.entries) { entry in
                                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                                        Text("•")
                                            .foregroundStyle(store.accentColor.opacity(0.7))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.app(12.5, weight: .medium))
                                                .foregroundStyle(store.fontColor)
                                                .lineLimit(2)
                                            if let reason = entry.reason {
                                                Text(reason)
                                                    .font(.app(9.5))
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .overlay {
                                        TextDragSurface(
                                            payload: "app:\(entry.id)",
                                            label: entry.name,
                                            accentColor: NSColor(store.accentColor),
                                            contextMenuItems: store.categories
                                                .filter {
                                                    $0.id != group.id &&
                                                    $0.id != AppCategory.frequentlyUsedID &&
                                                    $0.id != AppCategory.autoClassifiedID &&
                                                    $0.id != AppCategory.essentialsID
                                                }
                                                .map { category in
                                                    TextDragMenuItem(
                                                        title: category.name
                                                    ) {
                                                        store.move(
                                                            [entry.id],
                                                            to: category.id
                                                        )
                                                    }
                                                }
                                        )
                                    }
                                    .help("左键拖动，或右键移动到其他类别")
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    classificationDropTargetID == group.id
                                        ? store.accentColor.opacity(0.11)
                                        : Color.primary.opacity(0.035)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            store.accentColor.opacity(
                                                classificationDropTargetID == group.id
                                                    ? 0.38
                                                    : 0.10
                                            ),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: ClassificationGroupDropDelegate(
                                categoryID: group.id,
                                targetID: classificationDropTargetBinding,
                                move: { appIDs in
                                    store.move(appIDs, to: group.id)
                                }
                            )
                        )
                        .animation(
                            .snappy(duration: 0.16),
                            value: classificationDropTargetID == group.id
                        )
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.never)
    }

    private func libraryItemView(
        _ item: LibraryItem,
        iconSize: CGFloat,
        nameSize: CGFloat,
        tileWidth: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        Group {
            switch item {
            case .folder(let folder):
                FolderTile(
                    store: store,
                    folder: folder,
                    iconSize: iconSize,
                    nameSize: nameSize,
                    accentColor: store.accentColor,
                    fontColor: store.fontColor,
                    showName: store.showNames,
                    dragHoldDuration: store.dragHoldDuration,
                    dragPayload: {
                        let payload = "folder:\(folder.id)"
                        beginDragging(payload)
                        return payload
                    },
                    cancelDrag: cancelDragging,
                    open: { activeSheet = .folder(folder) }
                )
                .contextMenu {
                    settingsMenuItems
                    Divider()
                    Button("打开") {
                        activeSheet = .folder(folder)
                    }
                    Button("重命名…") {
                        folderToRename = folder
                        renameText = folder.name
                    }
                    Divider()
                    Button("解散文件夹", role: .destructive) {
                        store.deleteFolder(folder)
                    }
                }
                .onDrop(
                    of: [.text],
                    delegate: FolderItemDropDelegate(
                        targetToken: item.orderToken,
                        draggedItemToken: draggedItemBinding,
                        addApps: { appIDs in
                            store.addApps(appIDs, to: folder.id)
                        },
                        reorder: { dragged, target in
                            store.moveLibraryItem(dragged, before: target)
                        }
                    )
                )

            case .app(let app):
                AppTile(
                    app: app,
                    isSelected:
                        store.isSelectionMode &&
                        store.selection.contains(app.id),
                    showName: store.showNames,
                    iconSize: iconSize,
                    nameSize: nameSize,
                    accentColor: store.accentColor,
                    fontColor: store.fontColor,
                    isGroupingTarget: groupingTargetID == "app:\(app.id)",
                    insertionEdge: insertionPreview?.targetToken == item.orderToken
                        ? (insertionPreview?.placeAfter == true ? .trailing : .leading)
                        : nil,
                    dragHoldDuration: store.dragHoldDuration,
                    dragPayload: {
                        let payload = dragPayload(for: app)
                        beginDragging(payload)
                        return payload
                    },
                    cancelDrag: cancelDragging,
                    select: { extend in
                        guard store.isSelectionMode else { return }
                        withAnimation(.snappy(duration: 0.15)) {
                            store.select(
                                app.id,
                                extend: store.isSelectionMode || extend
                            )
                        }
                    },
                    open: {
                        if !store.isSelectionMode {
                            store.open(app)
                        }
                    }
                )
                .contextMenu {
                    appContextMenu(for: app)
                }
                .onDrop(
                    of: [.text],
                    delegate: AppItemDropDelegate(
                        targetToken: item.orderToken,
                        targetAppID: app.id,
                        iconSize: iconSize,
                        tileWidth: tileWidth,
                        draggedItemToken: draggedItemBinding,
                        groupingTargetID: groupingTargetBinding,
                        insertionPreview: insertionPreviewBinding,
                        reorder: { draggedTokens, targetToken, placeAfter in
                            withAnimation(.snappy(duration: 0.24)) {
                                store.moveLibraryItems(
                                    draggedTokens,
                                    relativeTo: targetToken,
                                    placeAfter: placeAfter
                                )
                            }
                        },
                        group: { appIDs in
                            store.createFolder(containing: appIDs)
                        }
                    )
                )
            }
        }
        .frame(width: tileWidth, height: rowHeight, alignment: .top)
    }

    private func insertionGapView(
        left: LibraryItem,
        right: LibraryItem,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let gapID = "\(left.orderToken)|\(right.orderToken)"
        return InsertionGapTarget(
            accentColor: NSColor(store.accentColor),
            orientation: .vertical,
            targetChanged: { isTargeted in
                if isTargeted {
                    groupingTargetID = nil
                    if let payload = draggedItemToken {
                        let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                        let targetToken: String
                        let placeAfter: Bool
                        if !movingTokens.contains(left.orderToken) {
                            targetToken = left.orderToken
                            placeAfter = true
                        } else if !movingTokens.contains(right.orderToken) {
                            targetToken = right.orderToken
                            placeAfter = false
                        } else {
                            targetToken = ""
                            placeAfter = false
                        }
                        if !targetToken.isEmpty {
                            withAnimation(.snappy(duration: 0.16)) {
                                insertionPreview = LibraryInsertionPreview(
                                    movingTokens: movingTokens,
                                    targetToken: targetToken,
                                    placeAfter: placeAfter
                                )
                            }
                        }
                    }
                } else if insertionPreview?.targetToken == left.orderToken ||
                            insertionPreview?.targetToken == right.orderToken {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
            },
            performDrop: { payload in
                defer { draggedItemToken = nil }
                defer {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
                let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                guard !movingTokens.isEmpty else { return false }

                let targetToken: String
                let placeAfter: Bool
                if !movingTokens.contains(left.orderToken) {
                    targetToken = left.orderToken
                    placeAfter = true
                } else if !movingTokens.contains(right.orderToken) {
                    targetToken = right.orderToken
                    placeAfter = false
                } else {
                    return false
                }
                return withAnimation(.snappy(duration: 0.24)) {
                    store.moveLibraryItems(
                        movingTokens,
                        relativeTo: targetToken,
                        placeAfter: placeAfter
                    )
                }
            }
        )
        .frame(width: width, height: height)
        .id(gapID)
    }

    private func rowInsertionGapView(
        left: LibraryItem,
        right: LibraryItem,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let gapID = "row:\(left.orderToken)|\(right.orderToken)"
        return InsertionGapTarget(
            accentColor: NSColor(store.accentColor),
            orientation: .horizontal,
            targetChanged: { isTargeted in
                if isTargeted, let payload = draggedItemToken {
                    let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                    let targetToken: String
                    let placeAfter: Bool
                    if !movingTokens.contains(left.orderToken) {
                        targetToken = left.orderToken
                        placeAfter = true
                    } else if !movingTokens.contains(right.orderToken) {
                        targetToken = right.orderToken
                        placeAfter = false
                    } else {
                        targetToken = ""
                        placeAfter = false
                    }
                    if !targetToken.isEmpty {
                        groupingTargetID = nil
                        withAnimation(.snappy(duration: 0.16)) {
                            insertionPreview = LibraryInsertionPreview(
                                movingTokens: movingTokens,
                                targetToken: targetToken,
                                placeAfter: placeAfter
                            )
                        }
                    }
                } else if insertionPreview?.targetToken == left.orderToken ||
                            insertionPreview?.targetToken == right.orderToken {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
            },
            performDrop: { payload in
                defer {
                    draggedItemToken = nil
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
                let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                guard !movingTokens.isEmpty else { return false }
                let targetToken: String
                let placeAfter: Bool
                if !movingTokens.contains(left.orderToken) {
                    targetToken = left.orderToken
                    placeAfter = true
                } else if !movingTokens.contains(right.orderToken) {
                    targetToken = right.orderToken
                    placeAfter = false
                } else {
                    return false
                }
                return withAnimation(.snappy(duration: 0.24)) {
                    store.moveLibraryItems(
                        movingTokens,
                        relativeTo: targetToken,
                        placeAfter: placeAfter
                    )
                }
            }
        )
        .frame(width: width, height: height)
        .id(gapID)
    }

    private func endInsertionView(
        width: CGFloat,
        height: CGFloat,
        orientation: InsertionGapOrientation
    ) -> some View {
        InsertionGapTarget(
            accentColor: NSColor(store.accentColor),
            orientation: orientation,
            targetChanged: { isTargeted in
                if isTargeted,
                   let payload = draggedItemToken,
                   let lastToken = store.currentLibraryItems.last?.orderToken {
                    let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                    if !movingTokens.contains(lastToken) {
                        groupingTargetID = nil
                        withAnimation(.snappy(duration: 0.16)) {
                            insertionPreview = LibraryInsertionPreview(
                                movingTokens: movingTokens,
                                targetToken: lastToken,
                                placeAfter: true
                            )
                        }
                    }
                } else if insertionPreview?.placeAfter == true,
                          insertionPreview?.targetToken ==
                            store.currentLibraryItems.last?.orderToken {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
            },
            performDrop: { payload in
                defer {
                    draggedItemToken = nil
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
                guard let lastToken = store.currentLibraryItems.last?.orderToken else {
                    return false
                }
                let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                guard !movingTokens.isEmpty,
                      !movingTokens.contains(lastToken) else {
                    return false
                }
                return withAnimation(.snappy(duration: 0.24)) {
                    store.moveLibraryItems(
                        movingTokens,
                        relativeTo: lastToken,
                        placeAfter: true
                    )
                }
            }
        )
        .frame(width: width, height: height)
    }

    private func rowLeadingInsertionView(
        first: LibraryItem,
        previous: LibraryItem?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        InsertionGapTarget(
            accentColor: NSColor(store.accentColor),
            orientation: .vertical,
            targetChanged: { isTargeted in
                if isTargeted, let payload = draggedItemToken {
                    let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                    let targetToken: String
                    let placeAfter: Bool
                    if !movingTokens.contains(first.orderToken) {
                        targetToken = first.orderToken
                        placeAfter = false
                    } else if let previous,
                              !movingTokens.contains(previous.orderToken) {
                        targetToken = previous.orderToken
                        placeAfter = true
                    } else {
                        targetToken = ""
                        placeAfter = false
                    }
                    if !targetToken.isEmpty {
                        groupingTargetID = nil
                        withAnimation(.snappy(duration: 0.16)) {
                            insertionPreview = LibraryInsertionPreview(
                                movingTokens: movingTokens,
                                targetToken: targetToken,
                                placeAfter: placeAfter
                            )
                        }
                    }
                } else if insertionPreview?.targetToken == first.orderToken ||
                            insertionPreview?.targetToken == previous?.orderToken {
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
            },
            performDrop: { payload in
                defer {
                    draggedItemToken = nil
                    withAnimation(.snappy(duration: 0.16)) {
                        insertionPreview = nil
                    }
                }
                let movingTokens = LibraryDragPayload.itemTokens(from: payload)
                guard !movingTokens.isEmpty else { return false }
                let targetToken: String
                let placeAfter: Bool
                if !movingTokens.contains(first.orderToken) {
                    targetToken = first.orderToken
                    placeAfter = false
                } else if let previous,
                          !movingTokens.contains(previous.orderToken) {
                    targetToken = previous.orderToken
                    placeAfter = true
                } else {
                    return false
                }
                return withAnimation(.snappy(duration: 0.24)) {
                    store.moveLibraryItems(
                        movingTokens,
                        relativeTo: targetToken,
                        placeAfter: placeAfter
                    )
                }
            }
        )
        .frame(width: width, height: height)
    }

    private func beginDragging(_ payload: String) {
        draggedItemToken = payload
        groupingTargetID = nil
        insertionPreview = nil
    }

    private func cancelDragging() {
        draggedItemToken = nil
        groupingTargetID = nil
        insertionPreview = nil
    }

    @ViewBuilder
    private func appContextMenu(for app: LauncherApp) -> some View {
        let selectedIDs = store.selection.contains(app.id)
            ? store.selection
            : [app.id]

        Button(store.isSelectionMode ? "完成多项选择" : "多项选择") {
            withAnimation(.snappy(duration: 0.18)) {
                store.toggleSelectionMode()
            }
        }

        Divider()

        settingsMenuItems

        Divider()

        Button("打开") {
            store.open(app)
        }

        let allEssential = selectedIDs.allSatisfy(store.isEssential)
        Button(allEssential ? "从常用软件移除" : "添加到常用软件") {
            if allEssential {
                store.removeFromEssentials(Set(selectedIDs))
            } else {
                store.addToEssentials(Set(selectedIDs))
            }
        }

        Button("在访达中显示") {
            store.reveal(app)
        }

        Button("添加到程序坞") {
            store.addToDock(app)
        }

        if store.isRunning(app) {
            Button("重新启动") {
                store.restart(app)
            }
            Button("强制退出") {
                store.forceQuit(app)
            }
        }

        Divider()

        if store.selectedCategoryID != AppCategory.frequentlyUsedID,
           store.selectedCategoryID != AppCategory.autoClassifiedID {
            Button(selectedIDs.count > 1 ? "用所选应用新建文件夹" : "新建文件夹") {
                store.selection = Set(selectedIDs)
                store.createFolder()
            }

            Button("上移") {
                store.moveAppInCategory(app.id, offset: -1)
            }
            .disabled(selectedIDs.count != 1)

            Button("下移") {
                store.moveAppInCategory(app.id, offset: 1)
            }
            .disabled(selectedIDs.count != 1)
        }

        if store.selectedCategoryID != AppCategory.essentialsID {
            Menu("移动到") {
                ForEach(store.categories.filter {
                    $0.id != store.selectedCategoryID &&
                    $0.id != AppCategory.frequentlyUsedID &&
                    $0.id != AppCategory.autoClassifiedID
                }) { category in
                    Button(
                        category.id == AppCategory.essentialsID
                            ? "添加到常用软件"
                            : category.name
                    ) {
                        store.move(Set(selectedIDs), to: category.id)
                    }
                }
            }
        }

        let assignmentHistory = store.assignmentHistory(for: app.id)
        if !assignmentHistory.isEmpty {
            Menu("分类日期") {
                ForEach(assignmentHistory) { record in
                    Button(
                        "\(record.name) · "
                        + record.date.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    ) {}
                    .disabled(true)
                }
            }
        }

        if let reason = store.automaticReason(for: app.id) {
            Divider()
            Button(reason) {}
                .disabled(true)
        }

        Divider()

        Button("隐藏") {
            store.hide(Set(selectedIDs))
        }

        Divider()

        if app.origin == .windows {
            Button("移除 Windows 快捷方式…", role: .destructive) {
                confirmWindowsShortcutRemoval(app)
            }
        } else if app.path.hasPrefix("/System/") {
            Button("系统应用不可卸载") {}
                .disabled(true)
        } else {
            Button("卸载并清理…", role: .destructive) {
                activeSheet = .uninstall(app)
            }
        }
    }

    @ViewBuilder
    private var settingsMenuItems: some View {
        Menu("Setting") {
            ForEach(SettingsPane.allCases) { pane in
                Button {
                    openSettingsPane(pane)
                } label: {
                    Label(
                        "    \(store.settingsTitle(for: pane))",
                        systemImage: pane.symbol
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(store.accentColor.opacity(0.09))
                    .frame(width: 78, height: 78)

                Image(
                    systemName: store.searchText.isEmpty
                        ? (store.selectedCategoryID == AppCategory.frequentlyUsedID
                            ? "sparkles"
                            : "square.grid.2x2")
                        : "magnifyingglass"
                )
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(store.accentColor.opacity(0.78))
            }

            BilingualText(
                emptyTitle,
                size: 17,
                weight: .semibold
            )

            BilingualText(
                emptyDescription,
                size: 12.5
            )
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 30)
    }

    private var emptyTitle: String {
        if !store.searchText.isEmpty { return "没有匹配的应用" }
        if store.selectedCategoryID == AppCategory.frequentlyUsedID {
            return "还没有推荐"
        }
        if store.selectedCategoryID == AppCategory.autoClassifiedID {
            return "还没有自动分类结果"
        }
        if store.selectedCategoryID == AppCategory.essentialsID {
            return "还没有常用软件"
        }
        return "这里还是空的"
    }

    private var emptyDescription: String {
        if !store.searchText.isEmpty {
            return "换个关键词，或切换上方的系统。"
        }
        if store.selectedCategoryID == AppCategory.frequentlyUsedID {
            return "跨天重复使用后才会进入推荐，短暂连续打开不会把它顶上。"
        }
        if store.selectedCategoryID == AppCategory.autoClassifiedID {
            return "证据不足的软件会继续留在未分类，等待你人工审核。"
        }
        if store.selectedCategoryID == AppCategory.essentialsID {
            return "在任意软件上右键添加；这里只保存引用，不移动原分类。"
        }
        return "把应用拖进来，或从其他类别移动到这里。"
    }

    private var statusBar: some View {
        HStack {
            if store.selection.isEmpty {
                if !store.selectionMemory.isEmpty,
                   store.selectedCategoryID != AppCategory.frequentlyUsedID,
                   store.selectedCategoryID != AppCategory.autoClassifiedID {
                    Text("已记住 \(store.selectionMemory.count) 个应用")
                        .font(.app(10.5, weight: .semibold))
                        .foregroundStyle(store.accentColor)
                    Button(
                        store.selectedCategoryID == AppCategory.essentialsID
                            ? "添加到常用软件"
                            : "移动到此类别"
                    ) {
                        store.moveRememberedApps(to: store.selectedCategoryID)
                    }
                    .buttonStyle(.plain)
                    .font(.app(10.5, weight: .medium))
                    Button("清除") {
                        store.clearSelectionMemory()
                    }
                    .buttonStyle(.plain)
                    .font(.app(10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                } else if store.selectedCategoryID == AppCategory.autoClassifiedID {
                    BilingualText(
                        "分类参考：拖动名称到左侧类别即可手动调整；未分类留在最后一组",
                        size: 10.5,
                        weight: .medium
                    )
                    .foregroundStyle(.tertiary)
                } else if store.selectedCategoryID == AppCategory.essentialsID {
                    BilingualText(
                        "常用软件是快捷引用：添加或移除不会改变应用原分类",
                        size: 10.5,
                        weight: .medium
                    )
                    .foregroundStyle(.tertiary)
                } else {
                    BilingualText(
                        "双击打开  ·  长按拖动排序  ·  拖到图标中心成组",
                        size: 10.5,
                        weight: .medium
                    )
                    .foregroundStyle(.tertiary)
                }
            } else {
                BilingualText(
                    "已选 \(store.selection.count) 个应用",
                    size: 10.5,
                    weight: .semibold
                )
                .foregroundStyle(store.accentColor)

                if store.selectedCategoryID == AppCategory.essentialsID {
                    Button("从常用软件移除") {
                        store.removeFromEssentials(store.selection)
                    }
                    .buttonStyle(.plain)
                    .font(.app(10.5, weight: .semibold))
                    .foregroundStyle(store.accentColor)
                } else {
                    Menu("移入类别") {
                        ForEach(store.categories.filter {
                            $0.id != store.selectedCategoryID &&
                            $0.id != AppCategory.frequentlyUsedID &&
                            $0.id != AppCategory.autoClassifiedID
                        }) { category in
                            Button(category.name) {
                                store.move(store.selection, to: category.id)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button("添加到常用软件") {
                        store.addToEssentials(store.selection)
                    }
                    .buttonStyle(.plain)
                    .font(.app(10.5, weight: .semibold))
                    .foregroundStyle(store.accentColor)
                }

                if store.selectedCategoryID != AppCategory.frequentlyUsedID,
                   store.selectedCategoryID != AppCategory.autoClassifiedID,
                   store.selectedCategoryID != AppCategory.essentialsID {
                    Button("新建文件夹") {
                        store.createFolder()
                    }
                    .buttonStyle(.plain)
                    .font(.app(10.5, weight: .medium))
                }

                Button("取消") {
                    store.clearSelection()
                }
                .buttonStyle(.plain)
                .font(.app(10.5, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if store.selectedSystem == .windows,
               store.filteredWindowsCount > 0,
               !store.showWindowsUtilities {
                BilingualText(
                    "已过滤 \(store.filteredWindowsCount) 个系统项",
                    size: 10.5,
                    weight: .medium
                )
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 38)
        .background(Color.primary.opacity(0.018))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func dragPayload(for app: LauncherApp) -> String {
        if store.selection.contains(app.id), store.selection.count > 1 {
            return "apps:" + store.selection.sorted().joined(separator: "|")
        }
        return "app:\(app.id)"
    }

    private func confirmWindowsShortcutRemoval(_ app: LauncherApp) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "移除 \(app.name) 的 Parallels 快捷方式？"
        alert.informativeText = "只会移除 Mac 上的快捷方式，不会卸载 Windows 虚拟机里的程序。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            store.uninstall(app)
        }
    }
}

private enum LibrarySheet: Identifiable {
    case folder(AppFolder)
    case uninstall(LauncherApp)

    var id: String {
        switch self {
        case .folder(let folder): "folder:\(folder.id)"
        case .uninstall(let app): "uninstall:\(app.id)"
        }
    }
}

private struct AppItemDropDelegate: DropDelegate {
    let targetToken: String
    let targetAppID: String
    let iconSize: CGFloat
    let tileWidth: CGFloat
    @Binding var draggedItemToken: String?
    @Binding var groupingTargetID: String?
    @Binding var insertionPreview: LibraryInsertionPreview?
    let reorder: ([String], String, Bool) -> Bool
    let group: (Set<String>) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropUpdated(info: DropInfo) -> DropOperation? {
        let shouldGroup = isOverIconCenter(info.location)
        groupingTargetID = shouldGroup ? targetToken : nil
        if shouldGroup {
            insertionPreview = nil
        } else if let payload = draggedItemToken {
            let moving = LibraryDragPayload.itemTokens(from: payload)
            if !moving.isEmpty {
                insertionPreview = LibraryInsertionPreview(
                    movingTokens: moving,
                    targetToken: targetToken,
                    placeAfter: info.location.x > tileWidth / 2
                )
            }
        }
        return .move
    }

    func dropExited(info: DropInfo) {
        if groupingTargetID == targetToken {
            groupingTargetID = nil
        }
        if insertionPreview?.targetToken == targetToken {
            insertionPreview = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        groupingTargetID = nil
        insertionPreview = nil
        defer { draggedItemToken = nil }

        let payload = draggedItemToken
        guard let payload, payload != targetToken else { return false }
        if isOverIconCenter(info.location) {
            var appIDs = LibraryDragPayload.appIDs(from: payload)
            appIDs.remove(targetAppID)
            guard !appIDs.isEmpty else { return false }
            appIDs.insert(targetAppID)
            group(appIDs)
            return true
        }

        let movingTokens = LibraryDragPayload.itemTokens(from: payload)
        guard !movingTokens.isEmpty else { return false }
        return reorder(
            movingTokens,
            targetToken,
            info.location.x > tileWidth / 2
        )
    }

    private func isOverIconCenter(_ location: CGPoint) -> Bool {
        let iconCenterY = 9 + (iconSize + 8) / 2
        let dx = location.x - tileWidth / 2
        let dy = location.y - iconCenterY
        let radius = max(24, iconSize * 0.5)
        return (dx * dx) + (dy * dy) <= radius * radius
    }
}

private enum LibraryDragPayload {
    static func itemTokens(from payload: String) -> [String] {
        if payload.hasPrefix("app:") || payload.hasPrefix("folder:") {
            return [payload]
        }
        guard payload.hasPrefix("apps:") else { return [] }
        return payload
            .dropFirst(5)
            .split(separator: "|")
            .map { "app:\($0)" }
    }

    static func appIDs(from payload: String) -> Set<String> {
        Set(
            itemTokens(from: payload)
                .filter { $0.hasPrefix("app:") }
                .map { String($0.dropFirst(4)) }
        )
    }
}

private struct LibraryInsertionPreview: Equatable {
    let movingTokens: [String]
    let targetToken: String
    let placeAfter: Bool
}

private struct ClassificationGroupDropDelegate: DropDelegate {
    let categoryID: String
    @Binding var targetID: String?
    let move: (Set<String>) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        targetID = categoryID
    }

    func dropExited(info: DropInfo) {
        if targetID == categoryID {
            targetID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        targetID = nil
        let providers = info.itemProviders(for: [UTType.text])
        guard !providers.isEmpty else { return false }
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let payload = object as? String else { return }
                let appIDs = LibraryDragPayload.appIDs(from: payload)
                guard !appIDs.isEmpty else { return }
                DispatchQueue.main.async {
                    move(appIDs)
                }
            }
        }
        return true
    }
}

private struct FolderItemDropDelegate: DropDelegate {
    let targetToken: String
    @Binding var draggedItemToken: String?
    let addApps: (Set<String>) -> Void
    let reorder: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedItemToken = nil }
        guard let payload = draggedItemToken, payload != targetToken else {
            return false
        }

        if payload.hasPrefix("folder:") {
            reorder(payload, targetToken)
            return true
        }

        let appIDs: Set<String>
        if payload.hasPrefix("apps:") {
            appIDs = Set(
                payload
                    .dropFirst(5)
                    .split(separator: "|")
                    .map(String.init)
            )
        } else if payload.hasPrefix("app:") {
            appIDs = [String(payload.dropFirst(4))]
        } else {
            return false
        }
        addApps(appIDs)
        return true
    }
}
