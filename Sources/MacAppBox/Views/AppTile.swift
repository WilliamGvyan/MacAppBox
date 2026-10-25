import AppKit
import SwiftUI

struct AppTile: View {
    let app: LauncherApp
    let isSelected: Bool
    let showName: Bool
    let iconSize: CGFloat
    let nameSize: CGFloat
    let accentColor: Color
    let fontColor: Color
    let isGroupingTarget: Bool
    let insertionEdge: AppInsertionEdge?
    let dragHoldDuration: TimeInterval
    let dragPayload: () -> String
    let cancelDrag: () -> Void
    let select: (Bool) -> Void
    let open: () -> Void

    private var _isHovered = State(initialValue: false)
    private var isHovered: Bool {
        get { _isHovered.wrappedValue }
        nonmutating set { _isHovered.wrappedValue = newValue }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                    .scaleEffect(isHovered && !reduceMotion ? 1.045 : 1)

                if isGroupingTarget {
                    RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                        .stroke(accentColor, lineWidth: 2)
                        .frame(width: iconSize + 14, height: iconSize + 14)
                        .shadow(color: accentColor.opacity(0.35), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, accentColor)
                        .offset(x: 5, y: -5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: iconSize + 12, height: iconSize + 8)

            if showName {
                BilingualText(
                    app.name,
                    size: nameSize,
                    weight: isSelected ? .semibold : .medium
                )
                    .foregroundStyle(
                        isSelected ? fontColor : fontColor.opacity(0.84)
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: max(54, iconSize * 1.2))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    isSelected
                        ? accentColor.opacity(0.105)
                        : (isHovered ? Color.primary.opacity(0.055) : Color.clear)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(accentColor.opacity(0.26), lineWidth: 1)
                    }
                }
        }
        .overlay(alignment: .bottom) {
            if isGroupingTarget {
                Text("松开成组")
                    .font(.app(9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accentColor, in: Capsule())
                    .offset(y: 5)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .overlay(alignment: insertionEdge == .trailing ? .trailing : .leading) {
            if let insertionEdge {
                Capsule()
                    .fill(accentColor)
                    .frame(width: 3, height: iconSize + 34)
                    .shadow(color: accentColor.opacity(0.35), radius: 4)
                    .offset(x: insertionEdge == .leading ? -5 : 5)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            AppDragSurface(
                icon: app.icon,
                payload: dragPayload,
                holdDuration: dragHoldDuration,
                select: select,
                open: open,
                cancelDrag: cancelDrag
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .help("\(app.name)\n\(app.path)")
        .accessibilityLabel(app.name)
        .accessibilityHint("双击打开")
    }
}

struct FolderTile: View {
    let store: LauncherStore
    let folder: AppFolder
    let iconSize: CGFloat
    let nameSize: CGFloat
    let accentColor: Color
    let fontColor: Color
    let showName: Bool
    let dragHoldDuration: TimeInterval
    let dragPayload: () -> String
    let cancelDrag: () -> Void
    let open: () -> Void

    private var _isHovered = State(initialValue: false)
    private var isHovered: Bool {
        get { _isHovered.wrappedValue }
        nonmutating set { _isHovered.wrappedValue = newValue }
    }

    private var folderApps: [LauncherApp] {
        folder.appIDs.compactMap(store.app(withID:))
    }

    private var dragIcon: NSImage {
        let image = NSImage(
            systemSymbolName: "folder.fill",
            accessibilityDescription: folder.name
        ) ?? NSImage()
        image.size = NSSize(width: 128, height: 128)
        return image
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: iconSize * 0.21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.78),
                                Color(hex: 0x2D7FF9).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: iconSize * 0.21, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(iconSize * 0.29), spacing: iconSize * 0.08),
                        GridItem(.fixed(iconSize * 0.29))
                    ],
                    spacing: iconSize * 0.08
                ) {
                    ForEach(Array(folderApps.prefix(4))) { app in
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize * 0.29, height: iconSize * 0.29)
                    }
                }
                .padding(iconSize * 0.15)
            }
            .frame(width: iconSize, height: iconSize)
            .shadow(color: accentColor.opacity(0.18), radius: 10, y: 5)
            .scaleEffect(isHovered ? 1.035 : 1)

            if showName {
                BilingualText(folder.name, size: nameSize, weight: .medium)
                .foregroundStyle(fontColor.opacity(0.84))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: max(54, iconSize * 1.2))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.055) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .overlay {
            AppDragSurface(
                icon: dragIcon,
                payload: dragPayload,
                holdDuration: dragHoldDuration,
                select: { _ in },
                open: open,
                cancelDrag: cancelDrag
            )
        }
        .help("\(folder.name)\n\(folder.appIDs.count) 个应用")
    }
}
