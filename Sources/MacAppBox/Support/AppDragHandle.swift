import AppKit
import SwiftUI

struct AppDragSurface: NSViewRepresentable {
    let icon: NSImage
    let payload: () -> String
    let holdDuration: TimeInterval
    let select: (Bool) -> Void
    let open: () -> Void
    let cancelDrag: () -> Void

    func makeNSView(context: Context) -> AppDragSurfaceView {
        let view = AppDragSurfaceView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: AppDragSurfaceView, context: Context) {
        update(nsView)
    }

    private func update(_ view: AppDragSurfaceView) {
        view.icon = icon
        view.payload = payload
        view.holdDuration = holdDuration
        view.select = select
        view.open = open
        view.cancelDrag = cancelDrag
    }
}

final class AppDragSurfaceView: NSView, NSDraggingSource {
    var icon: NSImage = NSImage()
    var payload: () -> String = { "" }
    var holdDuration: TimeInterval = 0.35
    var select: (Bool) -> Void = { _ in }
    var open: () -> Void = {}
    var cancelDrag: () -> Void = {}

    private var startPoint: NSPoint?
    private var holdTask: DispatchWorkItem?
    private var holdReady = false
    private var startedDragging = false
    private var cursorPushed = false
    private var preparedPayload: String?

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        holdReady = false
        startedDragging = false

        if event.clickCount == 1 {
            select(event.modifierFlags.contains(.command))
        } else if event.clickCount == 2 {
            open()
            return
        }

        let task = DispatchWorkItem { [weak self] in
            guard let self, self.startPoint != nil else { return }
            self.holdReady = true
            self.preparedPayload = self.payload()
            NSCursor.closedHand.push()
            self.cursorPushed = true
        }
        holdTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: task)
    }

    override func mouseDragged(with event: NSEvent) {
        guard holdReady, !startedDragging else { return }
        startedDragging = true

        let pasteboardItem = NSPasteboardItem()
        let payload = preparedPayload ?? payload()
        pasteboardItem.setString(payload, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        let dragImage = icon.copy() as? NSImage ?? icon
        let dragSide: CGFloat = 46
        dragImage.size = NSSize(width: dragSide, height: dragSide)
        let pointer = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(
            NSRect(
                x: pointer.x - dragSide / 2,
                y: pointer.y - dragSide / 2,
                width: dragSide,
                height: dragSide
            ),
            contents: dragImage
        )
        beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )
    }

    override func mouseUp(with event: NSEvent) {
        holdTask?.cancel()
        holdTask = nil
        startPoint = nil
        holdReady = false
        let wasDragging = startedDragging
        startedDragging = false
        preparedPayload = nil
        if !wasDragging {
            cancelDrag()
        }
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
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

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        preparedPayload = nil
        cancelDrag()
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }
}
