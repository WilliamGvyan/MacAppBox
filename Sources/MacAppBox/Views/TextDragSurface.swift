import AppKit
import SwiftUI

struct TextDragSurface: NSViewRepresentable {
    let payload: String
    let label: String
    let accentColor: NSColor

    func makeNSView(context: Context) -> TextDragSurfaceView {
        let view = TextDragSurfaceView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: TextDragSurfaceView, context: Context) {
        update(nsView)
    }

    private func update(_ view: TextDragSurfaceView) {
        view.payload = payload
        view.label = label
        view.accentColor = accentColor
    }
}

final class TextDragSurfaceView: NSView, NSDraggingSource {
    var payload = ""
    var label = ""
    var accentColor = NSColor.controlAccentColor

    private var startPoint: NSPoint?
    private var startedDragging = false

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging,
              let startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        let distance = hypot(current.x - startPoint.x, current.y - startPoint.y)
        guard distance >= 3 else { return }
        startedDragging = true

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(payload, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let dragSize = NSSize(width: 180, height: 34)
        draggingItem.setDraggingFrame(
            NSRect(
                x: current.x - dragSize.width / 2,
                y: current.y - dragSize.height / 2,
                width: dragSize.width,
                height: dragSize.height
            ),
            contents: dragImage(size: dragSize)
        )
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        startPoint = nil
        startedDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    private func dragImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 2, dy: 3)
        accentColor.withAlphaComponent(0.94).setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: rect.height / 2,
            yRadius: rect.height / 2
        ).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(
            string: label,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .paragraphStyle: paragraph
            ]
        )
        text.draw(
            in: rect.insetBy(dx: 12, dy: 8)
        )
        image.unlockFocus()
        return image
    }
}
