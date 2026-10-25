import AppKit
import SwiftUI

enum InsertionGapOrientation {
    case vertical
    case horizontal
}

struct InsertionGapTarget: NSViewRepresentable {
    let accentColor: NSColor
    let orientation: InsertionGapOrientation
    let targetChanged: (Bool) -> Void
    let performDrop: (String) -> Bool

    func makeNSView(context: Context) -> InsertionGapTargetView {
        let view = InsertionGapTargetView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: InsertionGapTargetView, context: Context) {
        update(nsView)
    }

    private func update(_ view: InsertionGapTargetView) {
        view.accentColor = accentColor
        view.orientation = orientation
        view.targetChanged = targetChanged
        view.performDrop = performDrop
    }
}

final class InsertionGapTargetView: NSView {
    var accentColor = NSColor.controlAccentColor
    var orientation: InsertionGapOrientation = .vertical
    var targetChanged: (Bool) -> Void = { _ in }
    var performDrop: (String) -> Bool = { _ in false }

    private var isTargeted = false {
        didSet {
            guard oldValue != isTargeted else { return }
            needsDisplay = true
            targetChanged(isTargeted)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string])
    }

    override var isOpaque: Bool { false }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isSupported(sender) else { return [] }
        isTargeted = true
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isSupported(sender) else {
            isTargeted = false
            return []
        }
        isTargeted = true
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isSupported(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { isTargeted = false }
        guard let payload = sender.draggingPasteboard.string(forType: .string) else {
            return false
        }
        return performDrop(payload)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isTargeted, bounds.width > 0, bounds.height > 0 else { return }

        let lineWidth: CGFloat = 3
        let lineRect: NSRect
        let glowRect: NSRect
        switch orientation {
        case .vertical:
            let lineHeight = max(44, bounds.height - 22)
            lineRect = NSRect(
                x: bounds.midX - lineWidth / 2,
                y: bounds.midY - lineHeight / 2,
                width: lineWidth,
                height: lineHeight
            )
            glowRect = lineRect.insetBy(dx: -7, dy: -4)
        case .horizontal:
            let lineLength = max(44, bounds.width - 24)
            lineRect = NSRect(
                x: bounds.midX - lineLength / 2,
                y: bounds.midY - lineWidth / 2,
                width: lineLength,
                height: lineWidth
            )
            glowRect = lineRect.insetBy(dx: -4, dy: -7)
        }

        accentColor.withAlphaComponent(0.09).setFill()
        NSBezierPath(
            roundedRect: glowRect,
            xRadius: glowRect.width / 2,
            yRadius: glowRect.width / 2
        ).fill()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = accentColor.withAlphaComponent(0.42)
        shadow.shadowBlurRadius = 6
        shadow.set()
        accentColor.setFill()
        NSBezierPath(
            roundedRect: lineRect,
            xRadius: lineWidth / 2,
            yRadius: lineWidth / 2
        ).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func isSupported(_ info: NSDraggingInfo) -> Bool {
        guard let payload = info.draggingPasteboard.string(forType: .string) else {
            return false
        }
        return payload.hasPrefix("app:")
            || payload.hasPrefix("apps:")
            || payload.hasPrefix("folder:")
            || payload.hasPrefix("folder-item:")
    }
}
