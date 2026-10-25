import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPanelView: View {
    @ObservedObject var store: LauncherStore
    @Binding var isPresented: Bool
    let initialSection: SettingsPane
    private var _newCategoryName = State(initialValue: "")
    private var _editingCategoryID = State<String?>(initialValue: nil)
    private var _editedCategoryName = State(initialValue: "")
    private var _layoutExpanded = State(initialValue: false)
    private var _sidebarExpanded = State(initialValue: false)
    private var _categoriesExpanded = State(initialValue: false)
    private var _libraryExpanded = State(initialValue: false)
    private var _confirmation = State<SettingsConfirmation?>(initialValue: nil)
    private var _layoutName = State(initialValue: "")
    private var _selectedLayoutID = State<String?>(initialValue: nil)
    private var _activePane = State(initialValue: SettingsPane.sidebar)

    private var newCategoryName: String {
        get { _newCategoryName.wrappedValue }
        nonmutating set { _newCategoryName.wrappedValue = newValue }
    }

    private var newCategoryNameBinding: Binding<String> {
        Binding(
            get: { newCategoryName },
            set: { newCategoryName = $0 }
        )
    }

    private var editingCategoryID: String? {
        get { _editingCategoryID.wrappedValue }
        nonmutating set { _editingCategoryID.wrappedValue = newValue }
    }

    private var editedCategoryName: String {
        get { _editedCategoryName.wrappedValue }
        nonmutating set { _editedCategoryName.wrappedValue = newValue }
    }

    private var editingCategoryBinding: Binding<Bool> {
        Binding(
            get: { editingCategoryID != nil },
            set: { if !$0 { editingCategoryID = nil } }
        )
    }

    private var editedCategoryNameBinding: Binding<String> {
        Binding(
            get: { editedCategoryName },
            set: { editedCategoryName = $0 }
        )
    }

    private var layoutExpanded: Bool {
        get { _layoutExpanded.wrappedValue }
        nonmutating set { _layoutExpanded.wrappedValue = newValue }
    }

    private var sidebarExpanded: Bool {
        get { _sidebarExpanded.wrappedValue }
        nonmutating set { _sidebarExpanded.wrappedValue = newValue }
    }

    private var categoriesExpanded: Bool {
        get { _categoriesExpanded.wrappedValue }
        nonmutating set { _categoriesExpanded.wrappedValue = newValue }
    }

    private var libraryExpanded: Bool {
        get { _libraryExpanded.wrappedValue }
        nonmutating set { _libraryExpanded.wrappedValue = newValue }
    }

    private var confirmation: SettingsConfirmation? {
        get { _confirmation.wrappedValue }
        nonmutating set { _confirmation.wrappedValue = newValue }
    }

    private var layoutName: String {
        get { _layoutName.wrappedValue }
        nonmutating set { _layoutName.wrappedValue = newValue }
    }

    private var selectedLayoutID: String? {
        get { _selectedLayoutID.wrappedValue }
        nonmutating set { _selectedLayoutID.wrappedValue = newValue }
    }

    private var activePane: SettingsPane {
        get { _activePane.wrappedValue }
        nonmutating set { _activePane.wrappedValue = newValue }
    }

    private var layoutNameBinding: Binding<String> {
        Binding(get: { layoutName }, set: { layoutName = $0 })
    }

    private var layoutBinding: Binding<Bool> {
        Binding(get: { layoutExpanded }, set: { layoutExpanded = $0 })
    }

    private var sidebarBinding: Binding<Bool> {
        Binding(get: { sidebarExpanded }, set: { sidebarExpanded = $0 })
    }

    private var categoriesBinding: Binding<Bool> {
        Binding(get: { categoriesExpanded }, set: { categoriesExpanded = $0 })
    }

    private var libraryBinding: Binding<Bool> {
        Binding(get: { libraryExpanded }, set: { libraryExpanded = $0 })
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { store.customBackgroundColor },
            set: { store.backgroundColorHex = $0.rgbHex }
        )
    }

    private var fontColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.fontColorHex) },
            set: { store.fontColorHex = $0.rgbHex }
        )
    }

    private var sidebarColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.sidebarColorHex) },
            set: { store.sidebarColorHex = $0.rgbHex }
        )
    }

    private var sidebarFontColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.sidebarFontColorHex) },
            set: { store.sidebarFontColorHex = $0.rgbHex }
        )
    }

    private var sidebarAccentColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.sidebarAccentColorHex) },
            set: { store.sidebarAccentColorHex = $0.rgbHex }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Setting")
                        .font(.app(21, weight: .semibold))
                    Text("所有修改立即生效")
                        .font(.app(10.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Menu {
                    Button("恢复全部默认设置…") {
                        confirmation = .resetAll
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.065)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.065)))
                }
                .buttonStyle(.plain)
                .help("关闭设置")
            }
            .padding(20)

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 16) {
                    settingsNavigator
                    selectedSettingsSection
                }
                .padding(16)
            }
            .scrollIndicators(.never)
        }
        .frame(width: 368)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 26, y: 14)
        .onAppear {
            expandInitialSection()
        }
        .alert("重命名类别", isPresented: editingCategoryBinding) {
            TextField("类别名称", text: editedCategoryNameBinding)
            Button("取消", role: .cancel) {
                editingCategoryID = nil
            }
            Button("保存") {
                if let id = editingCategoryID,
                   let category = store.categories.first(where: { $0.id == id }) {
                    if !store.renameCategory(category, to: editedCategoryName) {
                        NSSound.beep()
                    }
                }
                editingCategoryID = nil
            }
        } message: {
            Text("锁定的类别需要先解除名称锁。")
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if confirmation == .resetLayout {
                Button("重置布局", role: .destructive) {
                    store.resetLayout()
                    confirmation = nil
                }
            } else if confirmation == .resetAll {
                Button("恢复全部默认设置", role: .destructive) {
                    store.resetAllCustomizableSettings()
                    confirmation = nil
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(confirmation?.message ?? "")
        }
    }

    private var settingsNavigator: some View {
        VStack(spacing: 3) {
            ForEach(SettingsPane.allCases) { pane in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        activePane = pane
                        expandOnly(pane)
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: pane.symbol)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(
                                activePane == pane
                                    ? .white
                                    : store.fontColor.opacity(0.48)
                            )
                            .frame(width: 20, height: 20)
                            .background {
                                Circle()
                                    .fill(
                                        activePane == pane
                                            ? store.accentColor
                                            : Color.primary.opacity(0.055)
                                    )
                            }

                        Text(pane.title)
                            .font(.app(11.5, weight: activePane == pane ? .semibold : .medium))
                            .foregroundStyle(
                                activePane == pane
                                    ? store.fontColor
                                    : store.fontColor.opacity(0.66)
                            )

                        Spacer()

                        if activePane == pane {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(store.accentColor)
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 31)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                activePane == pane
                                    ? store.accentColor.opacity(0.10)
                                    : Color.clear
                            )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var selectedSettingsSection: some View {
        switch activePane {
        case .layout:
            layoutSection
        case .sidebar:
            sidebarSection
        case .categories:
            categoriesSection
        case .library:
            librarySection
        }
    }

    private var mainAppearanceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
                Text("字体、字色和背景只影响右侧内容区；明暗模式为窗口级设置，两侧共用。侧边栏可在“侧边栏布局”中独立设置，也可逐项跟随这里。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                appearanceLinkSettings

                SettingsRow(title: "窗口明暗模式") {
                    Picker("", selection: $store.appearanceMode) {
                        Text("跟随系统").tag(AppearanceMode.system)
                        Text("浅色").tag(AppearanceMode.light)
                        Text("深色").tag(AppearanceMode.dark)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 184)
                }

                SettingsRow(title: "字体颜色") {
                    HStack(spacing: 8) {
                        Text(store.useCustomFontColor ? "自定义" : "跟随系统")
                            .font(.app(10.5))
                            .foregroundStyle(.secondary)

                        Toggle("", isOn: $store.useCustomFontColor)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)

                        ColorPicker(
                            "",
                            selection: fontColorBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .disabled(!store.useCustomFontColor)
                    }
                }

                Text("字号会根据窗口宽度、网格列宽和图标大小自动调整，无需手动设置。")
                    .font(.app(10.5))
                    .foregroundStyle(.secondary)

                SettingsRow(title: "背景效果") {
                    Picker("", selection: $store.backgroundKind) {
                        ForEach(AppBackgroundKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                switch store.backgroundKind {
                case .solid:
                    SettingsRow(title: "背景颜色") {
                        ColorPicker(
                            "",
                            selection: backgroundColorBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                case .image:
                    HStack(spacing: 8) {
                        Text(
                            store.backgroundImagePath
                                .map { URL(fileURLWithPath: $0).lastPathComponent }
                                ?? "尚未选择图片"
                        )
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                        Spacer()

                        Button("选择图片…") {
                            chooseBackgroundImage()
                        }
                        .font(.app(10.5, weight: .medium))

                        if store.backgroundImagePath != nil {
                            Button("移除") {
                                store.clearBackgroundImage()
                            }
                            .font(.app(10.5, weight: .medium))
                        }
                    }
                case .transparent:
                    Text("完全透出桌面；侧栏和设置面板仍保留可读材质。")
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                case .wallpaper, .wallpaperBlur:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text(
                                store.wallpaperPath
                                    .map { URL(fileURLWithPath: $0).lastPathComponent }
                                    ?? "当前系统桌面"
                            )
                            .font(.app(10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Button("选择壁纸…") {
                                chooseWallpaper()
                            }
                            .font(.app(10.5, weight: .medium))

                            Button("系统壁纸文件夹") {
                                openSystemWallpaperFolder()
                            }
                            .font(.app(10.5, weight: .medium))

                            if store.wallpaperPath != nil {
                                Button("恢复当前桌面") {
                                    store.clearWallpaperSelection()
                                }
                                .font(.app(10.5, weight: .medium))
                            }
                        }
                    }
                default:
                    Text("该效果会跟随当前主题与系统明暗模式。")
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("背景透明度")
                            .font(.app(12, weight: .medium))
                        Spacer()
                        Text("\(Int(store.backgroundOpacity * 100))%")
                            .font(.app(10.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Slider(value: $store.backgroundOpacity, in: 0...1, step: 0.01)
                }

                if store.backgroundKind == .wallpaperBlur {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("壁纸模糊")
                                .font(.app(12, weight: .medium))
                            Spacer()
                            Text("\(Int(store.wallpaperBlurRadius)) px")
                                .font(.app(10.5, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: $store.wallpaperBlurRadius,
                            in: 0...48,
                            step: 1
                        )
                    }
                }

                fontPicker(
                    title: "汉字字体",
                    selection: $store.chineseFontName,
                    suggestions: FontCatalog.chineseSuggestions
                )

                fontPicker(
                    title: "英文字体",
                    selection: $store.latinFontName,
                    suggestions: FontCatalog.latinSuggestions
                )

                HStack(alignment: .center, spacing: 12) {
                    Text("汉字示例")
                        .font(
                            AppTypography.font(
                                named: store.chineseFontName,
                                size: 13,
                                weight: .medium
                            )
                        )
                    Text("Aa English 123")
                        .font(
                            AppTypography.font(
                                named: store.latinFontName,
                                size: 13,
                                weight: .medium
                            )
                        )
                    Spacer()
                    Text("系统字体 \(FontCatalog.families.count - 1) 款")
                        .font(.app(9))
                        .foregroundStyle(.tertiary)
                }

                SettingsRow(title: "显示应用名称") {
                    Toggle("", isOn: $store.showNames)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                sectionResetButton("恢复外观默认值") {
                    store.resetAppearanceSettings()
                }
        }
    }

    private var sidebarSection: some View {
        SettingsSection(
            title: "侧边栏布局",
            symbol: SettingsPane.sidebar.symbol,
            isExpanded: sidebarBinding,
            accentColor: store.fontColor
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("侧边栏拥有独立的字体、字色、背景和强调色。开启某一项联动的开关后，侧边栏会实时跟随主界面。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                appearanceLinkSettings

                SettingsRow(title: "侧边栏背景") {
                    Text(store.sidebarUsesMainBackground ? "跟随主界面" : "独立背景")
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                }

                SettingsRow(title: "自定义背景色") {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $store.sidebarUsesCustomColor)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .disabled(store.sidebarUsesMainBackground)

                        ColorPicker(
                            "",
                            selection: sidebarColorBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .disabled(
                            store.sidebarUsesMainBackground ||
                            !store.sidebarUsesCustomColor
                        )
                    }
                }

                SettingsRow(title: "字体颜色") {
                    ColorPicker(
                        "",
                        selection: sidebarFontColorBinding,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .disabled(store.sidebarUsesMainFontColor)
                }

                if !store.sidebarUsesMainFonts {
                    fontPicker(
                        title: "侧边栏汉字字体",
                        selection: $store.sidebarChineseFontName,
                        suggestions: FontCatalog.chineseSuggestions
                    )

                    fontPicker(
                        title: "侧边栏英文字体",
                        selection: $store.sidebarLatinFontName,
                        suggestions: FontCatalog.latinSuggestions
                    )
                }

                SettingsRow(title: "主题强调色") {
                    ColorPicker(
                        "",
                        selection: sidebarAccentColorBinding,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .disabled(store.sidebarUsesMainAccent)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("字体大小")
                            .font(.app(12, weight: .medium))
                        Spacer()
                        Text(String(format: "%.1f pt", store.sidebarFontSize))
                            .font(.app(10.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $store.sidebarFontSize,
                        in: 10...20,
                        step: 0.5
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("侧边栏宽度")
                            .font(.app(12, weight: .medium))
                        Spacer()
                        Text("\(Int(store.sidebarWidth)) pt")
                            .font(.app(10.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $store.sidebarWidth,
                        in: 190...340,
                        step: 2
                    )
                }

                Toggle("显示全部类别（常用推荐仍只在搜索时出现）", isOn: $store.showAllSidebarCategories)
                    .font(.app(11.5))
                    .toggleStyle(.switch)

                HStack {
                    Text("默认宽度 236 pt，默认字号 13.5 pt。")
                        .font(.app(9.5))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("恢复侧栏默认值") {
                        store.resetSidebarSettings()
                    }
                    .font(.app(10.5, weight: .medium))
                }
            }
        }
    }

    private var appearanceLinkSettings: some View {
        VStack(spacing: 8) {
            Toggle(
                "侧边栏背景与主界面保持一致",
                isOn: $store.sidebarUsesMainBackground
            )
            Toggle(
                "侧边栏字色与主界面保持一致",
                isOn: $store.sidebarUsesMainFontColor
            )
            Toggle(
                "侧边栏字体与主界面保持一致",
                isOn: $store.sidebarUsesMainFonts
            )
            Toggle(
                "侧边栏主题色与主界面保持一致",
                isOn: $store.sidebarUsesMainAccent
            )
        }
        .font(.app(11))
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(store.accentColor.opacity(0.065))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(store.accentColor.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private func fontPicker(
        title: String,
        selection: Binding<String>,
        suggestions: [String]
    ) -> some View {
        SettingsRow(title: title) {
            Menu {
                Button("系统默认") {
                    selection.wrappedValue = "__system__"
                }

                if !suggestions.isEmpty {
                    Divider()
                    Menu("推荐字体") {
                        ForEach(suggestions, id: \.self) { family in
                            Button(FontCatalog.displayName(family)) {
                                selection.wrappedValue = family
                            }
                        }
                    }
                }

                Menu("系统全部字体") {
                    ForEach(
                        FontCatalog.allFamilies(excluding: suggestions),
                        id: \.self
                    ) { family in
                        Button(family) {
                            selection.wrappedValue = family
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(FontCatalog.displayName(selection.wrappedValue))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.app(11))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .trailing)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var layoutSection: some View {
        SettingsSection(
            title: "主界面布局",
            symbol: SettingsPane.layout.symbol,
            isExpanded: layoutBinding,
            accentColor: store.fontColor
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.accentColor)
                    Text("外观与字体")
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(store.fontColor)
                    Spacer()
                }

                mainAppearanceSettings

                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                HStack(spacing: 7) {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.accentColor)
                    Text("图标、网格与拖动")
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(store.fontColor)
                    Spacer()
                }

                Text("拖动应用可调整顺序，或拖到左侧类别完成归类。把应用拖到文件夹上即可放入文件夹。")
                    .font(.app(10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("图标大小")
                            .font(.app(12, weight: .medium))
                        Spacer()
                        Text("\(Int(store.iconScale * 100))%")
                            .font(.app(10.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Slider(value: $store.iconScale, in: 0.25...2.0, step: 0.05)
                }

                HStack {
                    Text("自动模式会随窗口重排，固定模式严格按所选列数排列。")
                        .font(.app(10.5))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("重置图标") {
                        store.iconScale = 1
                    }
                    .font(.app(10.5, weight: .medium))
                }

                SettingsRow(title: "网格列数") {
                    Picker("", selection: $store.gridColumnCount) {
                        Text("自动").tag(0)
                        ForEach(1...16, id: \.self) { count in
                            Text("\(count) 列").tag(count)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 108)
                }

                SettingsRow(title: "网格行数") {
                    Picker("", selection: $store.gridRowCount) {
                        Text("自动").tag(0)
                        ForEach(1...8, id: \.self) { count in
                            Text("\(count) 行").tag(count)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 108)
                }

                Text("固定行数和列数后，一屏显示设定的行数；超出的项目在同一页继续上下滑查看。每个图标统一尺寸并从左上角排列。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("长按拖动触发时间")
                            .font(.app(11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f 秒", store.dragHoldDuration))
                            .font(.app(10.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Slider(value: $store.dragHoldDuration, in: 0.2...0.8, step: 0.05)
                }

                HStack(spacing: 8) {
                    TextField("布局名称（可选）", text: layoutNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.app(11))

                    Button("保存布局") {
                        saveCurrentLayout()
                    }
                    .font(.app(10.5, weight: .medium))
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    layoutButton("上一布局", symbol: "arrow.uturn.backward") {
                        store.restorePreviousLayout()
                    }
                    .disabled(store.layoutSnapshots.isEmpty)
                    layoutButton("重置布局", symbol: "arrow.counterclockwise") {
                        confirmation = .resetLayout
                    }
                    layoutButton("经典布局", symbol: "square.grid.3x3.topleft.filled") {
                        store.applyClassicLayout()
                    }
                }

                if !store.layoutSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已保存布局")
                            .font(.app(10.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(store.layoutSnapshots.reversed()) { snapshot in
                            layoutSnapshotRow(snapshot)
                        }

                        HStack {
                            Button("恢复所选布局") {
                                if let selectedLayoutID {
                                    store.restoreLayout(id: selectedLayoutID)
                                }
                            }
                            .font(.app(10.5, weight: .semibold))
                            .disabled(selectedLayoutID == nil)

                            Spacer()

                            Text("可保存多个布局，选中后恢复")
                                .font(.app(9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 2)
                }

                HStack {
                    Text(
                        store.lastLayoutMessage.isEmpty
                            ? "已保存 \(store.layoutSnapshots.count) 个布局快照"
                            : store.lastLayoutMessage
                    )
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    Spacer()
                }

                Text("恢复布局会同时带回分类、顺序、行数和列数；恢复前会自动保存当前状态。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)

                sectionResetButton("恢复布局参数默认值") {
                    store.resetLayoutPreferences()
                }
            }
        }
    }

    private func layoutButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.app(10.5, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 31)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func saveCurrentLayout() {
        let trimmed = layoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty
            ? "布局 \(store.layoutSnapshots.count + 1)"
            : trimmed
        store.saveLayout(named: name)
        selectedLayoutID = store.layoutSnapshots.last?.id
        layoutName = ""
    }

    private func layoutSnapshotRow(_ snapshot: LayoutSnapshot) -> some View {
        let selected = selectedLayoutID == snapshot.id
        return HStack(spacing: 8) {
            Button {
                selectedLayoutID = snapshot.id
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            selected ? store.accentColor : Color.secondary
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.name ?? "自动恢复点")
                            .font(.app(10.5, weight: selected ? .semibold : .medium))
                            .lineLimit(1)
                        Text(layoutDateText(snapshot.createdAt))
                            .font(.app(8.5))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                if selectedLayoutID == snapshot.id {
                    selectedLayoutID = nil
                }
                store.deleteLayoutSnapshot(id: snapshot.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("删除此布局")
        }
        .padding(.horizontal, 9)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    selected
                        ? store.accentColor.opacity(0.12)
                        : Color.primary.opacity(0.035)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            selected
                                ? store.accentColor.opacity(0.3)
                                : Color.primary.opacity(0.05),
                            lineWidth: 1
                        )
                }
        }
    }

    private func layoutDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func sectionResetButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Spacer()
            Button(title, action: action)
                .font(.app(10, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func expandInitialSection() {
        activePane = initialSection
        expandOnly(initialSection)
    }

    private func expandOnly(_ pane: SettingsPane) {
        layoutExpanded = pane == .layout
        sidebarExpanded = pane == .sidebar
        categoriesExpanded = pane == .categories
        libraryExpanded = pane == .library
    }

    private var categoriesSection: some View {
        SettingsSection(
            title: "软件分类设置 · \(store.selectedSystem.title)",
            symbol: SettingsPane.categories.symbol,
            isExpanded: categoriesBinding,
            accentColor: store.fontColor
        ) {
            VStack(spacing: 8) {
                Toggle("启用自动分类", isOn: $store.automaticClassificationEnabled)
                    .font(.app(11.5))
                    .toggleStyle(.switch)

                Text("只处理未分类软件。至少有两个同类样本，且名称或开发商明确一致时才会自动归类；证据不足继续留在未分类。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                SettingsRow(title: "分类参考列数") {
                    Picker(
                        "",
                        selection: $store.classificationReferenceColumns
                    ) {
                        ForEach(1...6, id: \.self) { count in
                            Text("\(count) 列").tag(count)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 98)
                }

                Text("自动分类页按所选列数排列软件名称，行数随内容自动增加。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button("重新审核未分类") {
                        store.retryAutomaticClassification()
                    }
                    .font(.app(10.5, weight: .medium))

                    Button("撤销自动分类") {
                        store.undoAutomaticClassifications()
                    }
                    .font(.app(10.5, weight: .medium))
                    .disabled(store.autoClassifiedAppIDs.isEmpty)

                    Spacer()
                    Text("自动 \(store.autoClassifiedAppIDs.count)")
                        .font(.app(9.5))
                        .foregroundStyle(.tertiary)
                }

                Divider()

                ForEach(store.categories) { category in
                    HStack {
                        Text(category.name)
                            .font(.app(12, weight: .medium))
                            .onTapGesture(count: 2) {
                                beginEditing(category)
                            }
                        Spacer()

                        Button {
                            beginEditing(category)
                        } label: {
                            Image(systemName: category.isNameLocked ? "lock.fill" : "pencil")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(category.isNameLocked ? .tertiary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(category.isNameLocked)
                        .help(category.isNameLocked ? "名称已锁定" : "重命名")

                        Button {
                            store.setCategoryNameLocked(
                                category,
                                locked: !category.isNameLocked
                            )
                        } label: {
                            Image(systemName: category.isNameLocked ? "lock.open" : "lock")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(category.isNameLocked ? "允许修改名称" : "锁定名称")

                        if !category.isBuiltIn {
                            Button {
                                store.deleteCategory(category)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("删除类别")
                        }
                    }
                    .frame(height: 25)
                }

                HStack(spacing: 7) {
                    TextField("新类别名称", text: newCategoryNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.app(11.5))
                        .onSubmit(addCategory)

                    Button("新增") {
                        addCategory()
                    }
                    .font(.app(11, weight: .medium))
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 2)

                Text("双击类别名称或点铅笔修改；点锁图标可设为不可修改。“未分类软件”固定在最后。")
                    .font(.app(9.5))
                    .foregroundStyle(.tertiary)

                Divider()

                Text("分类日期统计")
                    .font(.app(10.5, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    store.categoryStatisticsStartedAt.map {
                        "统计从 \(layoutDateText($0)) 开始；显示每个类别当前应用数与最近一次进入日期。"
                    } ?? "尚未建立分类日期统计。"
                )
                .font(.app(9))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(store.categoryUsageSummaries) { summary in
                    HStack(spacing: 8) {
                        Text(summary.name)
                            .font(.app(10.5, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(summary.appCount) 个")
                            .font(.app(9.5))
                            .foregroundStyle(.secondary)
                        Text(
                            summary.newestAssignment.map(layoutDateText)
                                ?? "待记录"
                        )
                        .font(.app(9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 68, alignment: .trailing)
                    }
                    .frame(height: 20)
                }
            }
        }
    }

    private var librarySection: some View {
        SettingsSection(
            title: "资源库与扫描",
            symbol: SettingsPane.library.symbol,
            isExpanded: libraryBinding,
            accentColor: store.fontColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.lastScanSummary)
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("重新扫描") {
                        store.refresh()
                    }
                    .font(.app(10.5, weight: .medium))
                }

                Text("已启用登录后的隐藏后台更新：每次打开 MacApp Box 会先显示缓存，再静默刷新。")
                    .font(.app(10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("显示 Windows 系统工具与安装器", isOn: $store.showWindowsUtilities)
                    .font(.app(11.5))
                    .toggleStyle(.switch)

                Toggle("启用常用推荐", isOn: $store.recommendationsEnabled)
                    .font(.app(11.5))
                    .toggleStyle(.switch)

                Text("常用推荐类别平时隐藏，点击搜索框时才出现；排序依据跨天历史、近 30 天活跃度和最近使用时间。")
                    .font(.app(10.5))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("已隐藏 \(store.hiddenAppIDs.count) 个应用")
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("全部恢复") {
                        store.unhideAll()
                    }
                    .font(.app(10.5, weight: .medium))
                    .disabled(store.hiddenAppIDs.isEmpty)
                }

                HStack {
                    Text("已积累 \(store.launchStats.count) 个应用的使用历史")
                        .font(.app(10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清空推荐记录") {
                        store.clearLaunchHistory()
                    }
                    .font(.app(10.5, weight: .medium))
                    .disabled(store.launchStats.isEmpty)
                }

                Text("自研软件统一放在 ~/自研软件，并登记到「自研软件」启动器，不进入 /Applications。")
                    .font(.app(10.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                sectionResetButton("恢复资料库默认值") {
                    store.resetLibrarySettings()
                }
            }
        }
    }

    private func addCategory() {
        if store.addCategory(named: newCategoryName) {
            newCategoryName = ""
        } else if !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSSound.beep()
        }
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.title = "选择背景图片"
        panel.prompt = "使用图片"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.setBackgroundImage(from: url)
    }

    private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.title = "选择壁纸"
        panel.prompt = "使用壁纸"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        let systemFolder = URL(
            fileURLWithPath: "/System/Library/Desktop Pictures",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: systemFolder.path) {
            panel.directoryURL = systemFolder
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.setWallpaperImage(from: url)
    }

    private func openSystemWallpaperFolder() {
        let folder = URL(
            fileURLWithPath: "/System/Library/Desktop Pictures",
            isDirectory: true
        )
        NSWorkspace.shared.open(folder)
    }

    private func beginEditing(_ category: AppCategory) {
        guard !category.isNameLocked else {
            NSSound.beep()
            return
        }
        editedCategoryName = category.name
        editingCategoryID = category.id
    }
}
private enum SettingsConfirmation {
    case resetLayout
    case resetAll

    var title: String {
        switch self {
        case .resetLayout: "重置布局？"
        case .resetAll: "恢复全部默认设置？"
        }
    }

    var message: String {
        switch self {
        case .resetLayout:
            "会把应用归类和顺序恢复为初始状态。重置前会自动保存当前布局，之后可恢复。"
        case .resetAll:
            "只恢复外观、布局参数、侧栏和资料库设置；不会删除分类、应用归属或已保存布局。"
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @Binding var isExpanded: Bool
    let accentColor: Color
    let content: Content

    init(
        title: String,
        symbol: String,
        isExpanded: Binding<Bool>,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self._isExpanded = isExpanded
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(title)
                        .font(.app(11, weight: .semibold))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.075))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(accentColor.opacity(0.14), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(13)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(accentColor.opacity(0.08), lineWidth: 1)
                            }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.app(12, weight: .medium))
            Spacer(minLength: 12)
            content
        }
    }
}
