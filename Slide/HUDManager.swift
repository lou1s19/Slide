import SwiftUI
import Cocoa
import Combine

enum SwipeDirection {
    case leftHalf, rightHalf, center, maximize, minimize
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, middleThird, rightThird
    case topLeftSixth, topMiddleSixth, topRightSixth
    case bottomLeftSixth, bottomMiddleSixth, bottomRightSixth
    case close // For Pinch In
    case restore // Back to the frame the window had before its first snap

    var iconName: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.inset.filled"
        case .rightHalf: return "rectangle.righthalf.inset.filled"
        case .center: return "rectangle.center.inset.filled"
        case .maximize: return "rectangle.inset.filled"
        case .minimize: return "arrow.down.to.line"
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return "rectangle.split.2x2.fill"
        case .leftThird, .middleThird, .rightThird:
            return "rectangle.split.3x1.fill"
        case .topLeftSixth, .topMiddleSixth, .topRightSixth, .bottomLeftSixth, .bottomMiddleSixth, .bottomRightSixth:
            return "rectangle.split.3x3.fill"
        case .close: return "xmark.circle.fill"
        case .restore: return "arrow.uturn.backward"
        }
    }
}

struct HUDView: View {
    @ObservedObject var manager: HUDManager
    
    var body: some View {
        ZStack {
            if let direction = manager.currentDirection {
                VisualEffectView()
                    .frame(width: manager.hudSize, height: manager.hudSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Image(systemName: direction.iconName)
                    .font(.system(size: manager.hudSize * 0.41, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .opacity(manager.isVisible ? 1 : 0)
        .scaleEffect(manager.isVisible ? 1 : 0.8)
        .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: manager.isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: manager.currentDirection)
    }
}

class HUDManager: ObservableObject {
    static let shared = HUDManager()
    
    @Published var isVisible: Bool = false
    @Published var currentDirection: SwipeDirection?
    @Published var hudSize: CGFloat = 44

    private var window: NSWindow?
    
    init() {
        createWindow()
    }
    
    private func createWindow() {
        let hostingController = NSHostingController(rootView: HUDView(manager: self))
        
        // This makes sure the background is completely transparent
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 44, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating // Stay above regular windows
        win.ignoresMouseEvents = true // Pass clicks right through
        win.contentViewController = hostingController
        
        self.window = win
    }
    
    func showHUD(direction: SwipeDirection, at pointerLocation: CGPoint? = nil) {
        let defaults = UserDefaults.standard
        let tooltipsEnabled = defaults.object(forKey: "showTooltips") == nil ? true : defaults.bool(forKey: "showTooltips")
        guard tooltipsEnabled else { return }

        // "Size" slider: 0 -> 33pt, 0.5 -> 44pt (default), 1 -> 55pt
        let sizeSetting = defaults.object(forKey: "tooltipSize") == nil ? 0.5 : defaults.double(forKey: "tooltipSize")
        hudSize = 44.0 * (0.75 + CGFloat(sizeSetting) * 0.5)

        currentDirection = direction

        // Position the window centered on the pointer
        if let win = window {
            let half = hudSize / 2
            if let loc = pointerLocation {
                // loc is bottom-left origin from NSEvent.mouseLocation
                win.setFrame(NSRect(x: loc.x - half, y: loc.y - half, width: hudSize, height: hudSize), display: true)
            } else {
                win.setContentSize(NSSize(width: hudSize, height: hudSize))
                win.center()
            }
            win.orderFront(nil)
        }

        withAnimation {
            isVisible = true
        }
    }
    
    func hideHUD() {
        withAnimation {
            isVisible = false
        }
    }
}
