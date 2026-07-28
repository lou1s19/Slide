import Cocoa

/// Flashes a translucent, glassy highlight over the area a window is about to
/// occupy, so the user sees the snap target the moment a gesture locks in.
class SnapPreviewManager {
    static let shared = SnapPreviewManager()

    private let window: NSWindow
    private var hideWorkItem: DispatchWorkItem?

    init() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.15).cgColor
        view.layer?.borderColor = NSColor.systemPurple.withAlphaComponent(0.7).cgColor
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 12

        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.contentView = view
    }

    /// Shows the highlight briefly, fading in fast and out slow.
    /// - Parameter rect: Target area in Cocoa screen coordinates (bottom-left origin).
    func flash(rect: NSRect) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "showLiveTooltips") == nil ? true : defaults.bool(forKey: "showLiveTooltips")
        guard enabled, rect.width > 1, rect.height > 1 else { return }

        hideWorkItem?.cancel()
        window.setFrame(rect, display: true)
        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            window.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window.animator().alphaValue = 0
            }, completionHandler: {
                self.window.orderOut(nil)
            })
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
}
