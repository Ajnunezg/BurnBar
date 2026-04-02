import SwiftUI
import AppKit

// MARK: - Popover Tooltip

/// SwiftUI's `.help()` modifier doesn't show tooltips inside `MenuBarExtra` popovers because
/// the `NSPopover` window doesn't participate in `NSToolTipManager` tracking. This modifier
/// overlays an `NSView` with `toolTip` set, which AppKit handles regardless of window type.
private struct PopoverTooltipOverlay: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> PopoverTooltipNSView {
        let v = PopoverTooltipNSView()
        v.toolTip = text
        return v
    }

    func updateNSView(_ nsView: PopoverTooltipNSView, context: Context) {
        nsView.toolTip = text
    }
}

/// Transparent hit-testing view that only exists to carry an NSView `toolTip`.
/// Returns `self` from `hitTest` so AppKit's tooltip tracking rects work,
/// but overrides `mouseDown`/`mouseUp` to forward clicks to the next responder.
private class PopoverTooltipNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension View {
    /// Tooltip that works inside `MenuBarExtra` popovers (where `.help()` is silent).
    func popoverTooltip(_ text: String) -> some View {
        overlay(PopoverTooltipOverlay(text: text).allowsHitTesting(false))
    }
}
