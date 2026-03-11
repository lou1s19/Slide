import Cocoa
import ApplicationServices

class WindowManager {
    static let shared = WindowManager()
    
    /// Gets the window currently directly under the mouse cursor.
    func getWindowUnderCursor() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Accessibility origin is top-left of the main screen (screen 0)
        // NSEvent.mouseLocation origin is bottom-left of the main screen
        if let mainScreen = NSScreen.screens.first {
            let y = mainScreen.frame.height - mouseLocation.y
            let adjustedPoint = CGPoint(x: mouseLocation.x, y: y)
            
            var elementAtPoint: AXUIElement?
            let error = AXUIElementCopyElementAtPosition(systemWideElement, Float(adjustedPoint.x), Float(adjustedPoint.y), &elementAtPoint)
            
            if error == .success, let element = elementAtPoint {
                // The element might be a button or text field. We need to traverse up to find the actual Window it belongs to.
                return getWindow(for: element)
            }
        }
        return nil
    }
    
    /// Helper to climb the accessibility tree to find the window an element belongs to.
    private func getWindow(for element: AXUIElement) -> AXUIElement? {
        var currentElement = element
        
        while true {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &role) == .success,
               let roleString = role as? String {
                if roleString == kAXWindowRole {
                    return currentElement
                }
            }
            
            // Climb up to the parent
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parent) == .success,
               let parentElement = parent,
               CFGetTypeID(parentElement) == AXUIElementGetTypeID() {
                currentElement = parentElement as! AXUIElement
            } else {
                break
            }
        }
        return nil
    }
    
    /// Checks if the mouse is currently within the title bar area of the given window
    func isMouseInTitleBar(of window: AXUIElement) -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.screens.first else { return false }
        let y = mainScreen.frame.height - mouseLocation.y
        let adjustedMouse = CGPoint(x: mouseLocation.x, y: y)
        
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return false
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if let posVal = positionValue, let szVal = sizeValue,
           CFGetTypeID(posVal) == AXValueGetTypeID(), CFGetTypeID(szVal) == AXValueGetTypeID() {
            let axPos = posVal as! AXValue
            let axSz = szVal as! AXValue
            AXValueGetValue(axPos, .cgPoint, &position)
            AXValueGetValue(axSz, .cgSize, &size)
        } else {
            return false
        }
        
        // Define title bar bounds: Top 40 pixels of the window
        let titleBarHeight: CGFloat = 40.0
        let titleBarRect = CGRect(x: position.x, y: position.y, width: size.width, height: titleBarHeight)
        
        return titleBarRect.contains(adjustedMouse)
    }
    
    /// Gets the frontmost window of the currently active application.
    func getFrontmostWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
            return (focusedWindow as! AXUIElement)
        }
        
        // Fallback: get main window
        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindow) == .success {
            return (mainWindow as! AXUIElement)
        }
        
        // Fallback: get first window in list
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
           let windowArray = windows as? [AXUIElement], let firstWindow = windowArray.first {
            return firstWindow
        }
        
        return nil
    }
}
