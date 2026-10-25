import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @ObservedObject var store: LauncherStore
    @Binding var showSettings: Bool
    let openSettingsPane: (SettingsPane) -> Void
    private var _showAddCategory = State(initialValue: false)
    private var _newCategoryName = State(initialValue: "")
    private var _draggedCategoryID = State<String?>(initialValue: nil)
    private var _showingAbout = State(initialValue: false)

    init(
        store: LauncherStore,
        showSettings: Binding<Bool>,
        openSettingsPane: @escaping (SettingsPane) -> Void
    ) {
        self.store = store
        self._showSettings = showSettings
        self.openSettingsPane = openSettingsPane
    }

    private var showAddCategory: Bool {
        get { _showAddCategory.wrappedValue }
        nonmutating set { _showAddCategory.wrappedValue = newValue }
    }

    private var newCategoryName: String {
        get { _newCategoryName.wrappedValue }
        nonmutating set { _newCategoryName.wrappedValue = newValue }
    }

    private var showingAbout: Bool {
        get { _showingAbout.wrappedValue }
        nonmutating set { _showingAbout.wrappedValue = newValue }
    }

    private var aboutBinding: Binding<Bool> {
        Binding(
            get: { showingAbout },
            set: { showingAbout = $0 }
        )
    }

    private var addCategoryBinding: Binding<Bool> {
        Binding(
            get: { showAddCategory },
            set: { showAddCategory = $0 }
        )
    }

    private var categoryNameBinding: Binding<String> {
        Binding(
            get: { newCategoryName },
            set: { newCategoryName = $0 }
        )
    }

    private var draggedCategoryIDBinding: Binding<String?> {
        Binding(
            get: { _draggedCategoryID.wrappedValue },
            set: { _draggedCategoryID.wrappedValue = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 46)

            HStack(spacing: 0) {
                Button {
                    openSettingsPane(.sidebar)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("Setting")
                            .font(
                                store.sidebarLatinFont(
                                    size: max(10.5, store.sidebarFontSize - 1.5),
                                    weight: .semibold
                                )
                            )
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(store.sidebarTextColor.opacity(0.86))
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(store.sidebarTextColor.opacity(0.10))
                    .frame(width: 1, height: 15)

                Button {
                    showingAbout.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("关于")
                            .font(store.sidebarFont(size: 9, weight: .medium))
                    }
                    .foregroundStyle(store.sidebarTextColor.opacity(0.62))
                    .frame(width: 44, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("关于 MacApp Box")
                .popover(isPresented: aboutBinding, arrowEdge: .top) {
                    AboutPopoverView(
                        version: appVersion,
                        build: appBuild,
                        accentColor: store.sidebarAccentColor,
                        fontColor: store.sidebarTextColor,
                        chineseFontName: store.effectiveSidebarChineseFontName,
                        latinFontName: store.effectiveSidebarLatinFontName
                    )
                }

                Rectangle()
                    .fill(store.sidebarTextColor.opacity(0.10))
                    .frame(width: 1, height: 15)

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        store.showAllSidebarCategories.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(
                            systemName: store.showAllSidebarCategories
                                ? "eye.fill"
                                : "eye"
                        )
                        .font(.system(size: 9.5, weight: .semibold))
                        Text("全部")
                            .font(store.sidebarFont(size: 8.5, weight: .medium))
                    }
                    .foregroundStyle(
                        store.sidebarTextColor.opacity(
                            store.showAllSidebarCategories ? 0.78 : 0.54
                        )
                    )
                    .frame(width: 40, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(store.showAllSidebarCategories ? "隐藏空类别" : "显示全部类别")
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                store.sidebarAccentColor.opacity(0.09),
                                lineWidth: 1
                            )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            systemSelector
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.visibleCategories) { category in
                        CategorySidebarRow(
                            store: store,
                            category: category,
                            draggedCategoryID: draggedCategoryIDBinding,
                            openSettingsPane: openSettingsPane
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 18)
                .padding(.top, 18)
            }

            Spacer(minLength: 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MacOS：\(store.macOSInstalledCount)")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Windows：\(store.windowsInstalledCount)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(
                store.sidebarFont(
                    size: max(9.5, store.sidebarFontSize - 3),
                    weight: .medium
                )
            )
            .foregroundStyle(store.sidebarTextColor.opacity(0.46))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background { sidebarBackground }
        .contentShape(Rectangle())
        .contextMenu {
            settingsContextMenu
            Divider()
            Button("新增类别…") {
                newCategoryName = ""
                showAddCategory = true
            }
            Button("重新扫描") {
                store.refresh()
            }
            Divider()
            Button("退出 MacApp Box") {
                NSApp.terminate(nil)
            }
        }
        .alert("新增类别", isPresented: addCategoryBinding) {
            TextField("类别名称", text: categoryNameBinding)
            Button("取消", role: .cancel) {}
            Button("新增") {
                if !store.addCategory(named: newCategoryName) {
                    NSSound.beep()
                }
            }
        } message: {
            Text("新类别会立即出现在左侧，可直接拖入应用。")
        }
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0"
    }

    private var appBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    @ViewBuilder
    private var settingsContextMenu: some View {
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

    @ViewBuilder
    private var sidebarBackground: some View {
        if store.sidebarUsesMainBackground {
            Color.clear
        } else {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                if store.sidebarUsesCustomColor {
                    Color(hex: store.sidebarColorHex)
                        .opacity(0.92)
                }
            }
        }
    }

    private var systemSelector: some View {
        HStack(spacing: 3) {
            ForEach(PlatformKind.allCases) { system in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        store.selectSystem(system)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: system.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(system.title)
                            .font(
                                store.sidebarLatinFont(
                                    size: max(11, store.sidebarFontSize - 1),
                                    weight: .semibold
                                )
                            )
                    }
                    .foregroundStyle(
                        store.selectedSystem == system
                            ? store.sidebarTextColor
                            : store.sidebarTextColor.opacity(0.56)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background {
                        if store.selectedSystem == system {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.background.opacity(0.72))
                                .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

private struct CategorySidebarRow: View {
    @ObservedObject var store: LauncherStore
    let category: AppCategory
    @Binding var draggedCategoryID: String?
    let openSettingsPane: (SettingsPane) -> Void
    private var _isDropTarget = State(initialValue: false)
    private var _isHovered = State(initialValue: false)
    private var _showRename = State(initialValue: false)
    private var _renameText = State(initialValue: "")

    init(
        store: LauncherStore,
        category: AppCategory,
        draggedCategoryID: Binding<String?>,
        openSettingsPane: @escaping (SettingsPane) -> Void
    ) {
        self.store = store
        self.category = category
        self._draggedCategoryID = draggedCategoryID
        self.openSettingsPane = openSettingsPane
    }

    private var isDropTarget: Bool {
        get { _isDropTarget.wrappedValue }
        nonmutating set { _isDropTarget.wrappedValue = newValue }
    }

    private var isHovered: Bool {
        get { _isHovered.wrappedValue }
        nonmutating set { _isHovered.wrappedValue = newValue }
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
        let selected = store.selectedCategoryID == category.id

        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(selected || isDropTarget ? store.sidebarAccentColor : Color.clear)
                .frame(width: selected ? 4 : 3, height: selected ? 21 : 16)
                .shadow(
                    color: selected ? store.sidebarAccentColor.opacity(0.32) : .clear,
                    radius: 4
                )

            BilingualText(
                category.name,
                size: store.sidebarFontSize,
                weight: selected ? .semibold : .regular,
                chineseFamily: store.effectiveSidebarChineseFontName,
                latinFamily: store.effectiveSidebarLatinFontName
            )
                .foregroundStyle(
                    selected
                        ? store.sidebarTextColor
                        : store.sidebarTextColor.opacity(0.66)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if category.isNameLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            if isHovered,
               category.id != AppCategory.frequentlyUsedID,
               category.id != AppCategory.autoClassifiedID,
               category.id != AppCategory.unclassifiedID {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: max(36, store.sidebarFontSize + 23))
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    selected
                        ? store.sidebarAccentColor.opacity(0.14)
                        : (
                            isDropTarget
                                ? store.sidebarAccentColor.opacity(0.13)
                                : (isHovered ? Color.primary.opacity(0.045) : Color.clear)
                        )
                )
                .overlay {
                    if selected || isDropTarget {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(
                                store.sidebarAccentColor.opacity(selected ? 0.34 : 0.28),
                                lineWidth: 1
                            )
                    }
                }
                .shadow(
                    color: selected ? store.sidebarAccentColor.opacity(0.12) : .clear,
                    radius: 7,
                    y: 2
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.18)) {
                store.selectCategory(category.id)
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onDrag {
            draggedCategoryID = category.id
            return NSItemProvider(object: "category:\(category.id)" as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: CategoryDropDelegate(
                target: category,
                draggedCategoryID: $draggedCategoryID,
                setHighlighted: { highlighted in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isDropTarget = highlighted
                    }
                },
                moveCategory: { draggedID, targetID in
                    store.moveCategory(draggedID, before: targetID)
                },
                moveApps: { payload in
                    if payload.hasPrefix("app:") {
                        store.move(
                            Set([String(payload.dropFirst(4))]),
                            to: category.id
                        )
                    } else if payload.hasPrefix("apps:") {
                        let ids = payload
                            .dropFirst(5)
                            .split(separator: "|")
                            .map(String.init)
                        store.move(Set(ids), to: category.id)
                    } else if payload.hasPrefix("folder:") {
                        store.moveFolder(
                            String(payload.dropFirst(7)),
                            to: category.id
                        )
                    }
                }
            )
        )
        .contextMenu {
            settingsContextMenu
            Divider()
            if !store.selectionMemory.isEmpty,
               category.id != AppCategory.frequentlyUsedID,
               category.id != AppCategory.autoClassifiedID {
                Button("粘贴并移入 \(store.selectionMemory.count) 个应用") {
                    store.moveRememberedApps(to: category.id)
                }
                Divider()
            }
            Button("上移") {
                store.moveCategoryUp(category.id)
            }
            .disabled(!canMoveUp)

            Button("下移") {
                store.moveCategoryDown(category.id)
            }
            .disabled(!canMoveDown)

            Divider()

            Button("重命名…") {
                renameText = category.name
                showRename = true
            }
            .disabled(category.isNameLocked)

            Button(category.isNameLocked ? "允许修改名称" : "锁定名称") {
                store.setCategoryNameLocked(category, locked: !category.isNameLocked)
            }

            if !category.isBuiltIn {
                Divider()
                Button("删除类别", role: .destructive) {
                    store.deleteCategory(category)
                }
            }
        }
        .alert("重命名类别", isPresented: renameBinding) {
            TextField("类别名称", text: renameTextBinding)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if !store.renameCategory(category, to: renameText) {
                    NSSound.beep()
                }
            }
        } message: {
            Text(category.isNameLocked ? "该类别名称已锁定。" : "修改后所有位置立即更新。")
        }
        .animation(.snappy(duration: 0.2), value: selected)
    }

    @ViewBuilder
    private var settingsContextMenu: some View {
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

    private var canMoveUp: Bool {
        guard category.id != AppCategory.frequentlyUsedID,
              category.id != AppCategory.autoClassifiedID,
              category.id != AppCategory.unclassifiedID,
              let index = store.categories.firstIndex(where: { $0.id == category.id }),
              index > 1 else { return false }
        return store.categories[index - 1].id != AppCategory.frequentlyUsedID
    }

    private var canMoveDown: Bool {
        guard category.id != AppCategory.frequentlyUsedID,
              category.id != AppCategory.autoClassifiedID,
              category.id != AppCategory.unclassifiedID,
              let index = store.categories.firstIndex(where: { $0.id == category.id }),
              index + 1 < store.categories.count else { return false }
        return store.categories[index + 1].id != AppCategory.unclassifiedID
    }
}

private struct CategoryDropDelegate: DropDelegate {
    let target: AppCategory
    @Binding var draggedCategoryID: String?
    let setHighlighted: (Bool) -> Void
    let moveCategory: (String, String) -> Void
    let moveApps: (String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        setHighlighted(true)
    }

    func dropExited(info: DropInfo) {
        setHighlighted(false)
    }

    func performDrop(info: DropInfo) -> Bool {
        setHighlighted(false)
        if let draggedCategoryID {
            self.draggedCategoryID = nil
            moveCategory(draggedCategoryID, target.id)
            return true
        }

        let providers = info.itemProviders(for: [UTType.text])
        guard !providers.isEmpty else { return false }
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let payload = object as? String else { return }
                DispatchQueue.main.async {
                    moveApps(payload)
                }
            }
        }
        return true
    }
}
