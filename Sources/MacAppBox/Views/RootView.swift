import SwiftUI

struct RootView: View {
    @ObservedObject var store: LauncherStore
    @Environment(\.colorScheme) private var colorScheme
    private var _showingSettings = State(initialValue: false)
    private var _settingsPane = State(initialValue: SettingsPane.sidebar)

    init(store: LauncherStore) {
        self.store = store
    }

    private var showingSettings: Bool {
        get { _showingSettings.wrappedValue }
        nonmutating set { _showingSettings.wrappedValue = newValue }
    }

    private var settingsBinding: Binding<Bool> {
        Binding(
            get: { showingSettings },
            set: { showingSettings = $0 }
        )
    }

    private var settingsPane: SettingsPane {
        get { _settingsPane.wrappedValue }
        nonmutating set { _settingsPane.wrappedValue = newValue }
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .opacity(
                    store.backgroundKind == .transparent
                        ? 1
                        : store.backgroundOpacity
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                SidebarView(
                    store: store,
                    showSettings: settingsBinding,
                    openSettingsPane: openSettings
                )
                .frame(width: store.sidebarWidth)

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)

                LibraryView(
                    store: store,
                    showSettings: settingsBinding,
                    openSettingsPane: openSettings
                )
            }

            WindowConfigurator()
                .frame(width: 0, height: 0)

            if showingSettings {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingSettings = false
                    }

                HStack {
                    Spacer()
                    SettingsPanelView(
                        store: store,
                        isPresented: settingsBinding,
                        initialSection: settingsPane
                    )
                    .id(settingsPane)
                        .padding(.top, 14)
                        .padding(.trailing, 14)
                        .padding(.bottom, 14)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .environment(
            \.locale,
            Locale(identifier: store.appLanguage.localeIdentifier)
        )
        .environment(\.font, .app(12.5))
        .onReceive(NotificationCenter.default.publisher(for: .openMacAppBoxSettings)) { _ in
            withAnimation(.snappy(duration: 0.24)) {
                showingSettings = true
            }
        }
        .animation(.snappy(duration: 0.24), value: showingSettings)
        .task {
            store.refreshIfNeeded()
        }
    }

    private func openSettings(_ pane: SettingsPane) {
        settingsPane = pane
        withAnimation(.snappy(duration: 0.24)) {
            showingSettings = true
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch store.backgroundKind {
        case .material:
            ZStack {
                VisualEffectView(material: .underWindowBackground)
                store.surfaceColor.opacity(colorScheme == .dark ? 0.16 : 0.14)
                ambientBackground
            }
        case .frostedGlass:
            ZStack {
                VisualEffectView(material: .underWindowBackground)
                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18)
                Color.primary.opacity(0.025)
            }
        case .transparent:
            store.surfaceColor.opacity(store.backgroundOpacity * 0.22)
        case .wallpaper:
            wallpaperBackground(dimming: 0.10)
        case .wallpaperBlur:
            wallpaperBackground(dimming: 0.18)
        case .lightGlass:
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                Color.white.opacity(colorScheme == .dark ? 0.07 : 0.28)
            }
        case .darkGlass:
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(colorScheme == .dark ? 0.18 : 0.28)
            }
        case .gradient:
            LinearGradient(
                colors: [
                    store.surfaceColor,
                    store.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.20),
                    store.surfaceColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solid:
            ZStack {
                store.customBackgroundColor
                LinearGradient(
                    colors: [
                        .white.opacity(colorScheme == .dark ? 0.015 : 0.09),
                        .black.opacity(colorScheme == .dark ? 0.12 : 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .image:
            GeometryReader { proxy in
                ZStack {
                    if let image = store.backgroundImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        store.surfaceColor
                    }
                    Color.black.opacity(colorScheme == .dark ? 0.24 : 0.06)
                }
            }
        }
    }

    private func wallpaperBackground(dimming: Double) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let wallpaper = store.renderedWallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    store.surfaceColor
                }
                Color.black.opacity(dimming)
            }
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    store.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.09),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 620
            )

            RadialGradient(
                colors: [
                    store.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 720
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.015 : 0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
