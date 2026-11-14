import AppKit

/// Preserves continuous native pointer/accessibility adjustment while assigning
/// explicit keyboard increments to focused slider arrow-key interaction.
final class InspectionSlider3D: NSSlider {
    var keyboardIncrement: Double = 1

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              keyboardIncrement.isFinite, keyboardIncrement > 0 else {
            super.keyDown(with: event)
            return
        }

        let direction: Double
        switch event.keyCode {
        case 0x7B, 0x7D: direction = -1 // Left or Down
        case 0x7C, 0x7E: direction = 1 // Right or Up
        default:
            super.keyDown(with: event)
            return
        }

        let next = min(max(doubleValue + direction * keyboardIncrement, minValue), maxValue)
        guard next != doubleValue else { return }
        doubleValue = next
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        _ = scrollToVisible(bounds)
        return true
    }
}
