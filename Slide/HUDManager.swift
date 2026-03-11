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
        }
    }
}

struct HUDView: View {
    @ObservedObject var manager: HUDManager
    
    var body: some View {
        ZStack {
            if let direction = manager.currentDirection {
                VisualEffectView()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: direction.iconName)
                    .font(.system(size: 18, weight: .bold))
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
        currentDirection = direction
        
        // Position the window
        if let win = window {
            if let loc = pointerLocation {
                // loc is top-left origin (from GestureManager/NSEvent) or bottom-left?
                // we should pass bottom-left origin from NSEvent.mouseLocation
                win.setFrameOrigin(NSPoint(x: loc.x - 22, y: loc.y - 22))
            } else {
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
