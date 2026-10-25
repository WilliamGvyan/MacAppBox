import AppKit
import SwiftUI

struct SearchFocusField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FocusTrackingTextField {
        let field = FocusTrackingTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 12.5)
        field.placeholderString = "搜索应用"
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.onFocusChange = { focused in
            context.coordinator.parent.isFocused = focused
        }
        return field
    }

    func updateNSView(_ nsView: FocusTrackingTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text,
           nsView.currentEditor() == nil {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchFocusField

        init(_ parent: SearchFocusField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}

final class FocusTrackingTextField: NSTextField {
    var onFocusChange: (Bool) -> Void = { _ in }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocusChange(true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChange(false)
        }
        return resigned
    }
}
