import Cocoa

class GestureManager {
    static let shared = GestureManager()
    
    // Event Tap (Keyboard & Gestures)
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    func startMonitoring() {
        startEventTap()
        print("Slide: Started monitoring gestures")
    }
    
    func stopMonitoring() {
        stopEventTap()
        print("Slide: Stopped monitoring gestures")
    }
    
    // MARK: - Event Tap
    
    private func startEventTap() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << 29) // CGEventType.gesture
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GestureManager>.fromOpaque(refcon).takeUnretainedValue()

            // macOS silently disables event taps that respond too slowly (or on
            // certain user input). Without re-enabling, all gestures and
            // shortcuts would stay dead until app restart.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                manager.reenableEventTap()
                return nil
            }

            if type == .keyDown {
                if manager.handleKeyDown(event) {
                    return nil // block event
                }
            } else if type == .scrollWheel || type.rawValue == 29 {
                if let nsEvent = NSEvent(cgEvent: event) {
                    if manager.handleEvent(nsEvent) {
                        return nil // block event
                    }
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Slide: Failed to create event tap")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func reenableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Slide: Event tap was disabled by the system, re-enabled it")
        }
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Esc cancels a running gesture immediately
        if keyCode == 53 && activeWindow != nil {
            endSwipeWorkItem?.cancel()
            idleTimer?.cancel()
            endGestureSequence()
            return true
        }

        let shortcutManager = ShortcutManager.shared
        guard shortcutManager.isEnabled, !shortcutManager.isCapturingShortcut else { return false }

        guard let action = shortcutManager.action(matching: keyCode, flags: event.flags) else {
            return false
        }

        var windowToSnap: AXUIElement? = nil
        if let window = WindowManager.shared.getWindowUnderCursor(), WindowManager.shared.isMouseInTitleBar(of: window) {
            windowToSnap = window
        } else {
            windowToSnap = WindowManager.shared.getFrontmostWindow()
        }

        guard let window = windowToSnap, !ExclusionManager.shared.isExcluded(window: window) else { return false }

        activeWindow = window
        activateAndForeground(window: window)
        checkAndSnap(direction: action.direction)
        scheduleGestureEnd()

        return true
    }
    
    // Internal tracking state
    private var activeWindow: AXUIElement? = nil
    private var swipeAccumulatorX: CGFloat = 0
    private var swipeAccumulatorY: CGFloat = 0
    private var pinchAccumulator: CGFloat = 0
    private var endSwipeWorkItem: DispatchWorkItem?
    private var idleTimer: DispatchWorkItem?
    private var gestureCountThisSwipe: Int = 0
    private var isPinching: Bool = false
    private var startedInPinch: Bool = false
    private var lastSnappedDirection: SwipeDirection? = nil

    /// Hashable wrapper so AXUIElements can key the saved-frame store.
    private struct WindowKey: Hashable {
        let element: AXUIElement

        init(_ element: AXUIElement) { self.element = element }

        static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
            CFEqual(lhs.element, rhs.element)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(CFHash(element))
        }
    }

    /// The frame each window had before its first snap, for the Restore action.
    private var savedFrames: [WindowKey: CGRect] = [:]

    /// How long a resting finger keeps a gesture alive, driven by the
    /// "Cancel Timeout" slider.
    private var gestureIdleTimeout: TimeInterval {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "cancelTimeout") == nil ? 2.0 : defaults.double(forKey: "cancelTimeout")
    }

    /// Swipe distance needed to trigger an action, driven by the
    /// "Touch Sensitivity" slider (0 = sluggish 110pt, 1 = snappy 15pt,
    /// default 0.5 = the previous fixed 60pt).
    private var swipeThreshold: CGFloat {
        let defaults = UserDefaults.standard
        let sensitivity = defaults.object(forKey: "touchSensitivity") == nil ? 0.5 : defaults.double(forKey: "touchSensitivity")
        return max(15.0, 110.0 - CGFloat(sensitivity) * 100.0)
    }

    /// Ends the current gesture sequence (and hides the HUD) shortly after
    /// the last action, unless a follow-up gesture keeps it alive.
    private func scheduleGestureEnd(after delay: TimeInterval = 0.35) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.endGestureSequence()
        }
        endSwipeWorkItem?.cancel()
        endSwipeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func endGestureSequence() {
        swipeAccumulatorX = 0
        swipeAccumulatorY = 0
        pinchAccumulator = 0
        gestureCountThisSwipe = 0
        activeWindow = nil
        startedInPinch = false
        isPinching = false
        lastSnappedDirection = nil
        HUDManager.shared.hideHUD()
    }

    /// Main event handler returning true if we handled the event and want to block it
    private func handleEvent(_ event: NSEvent) -> Bool {
        // --- Smart Magnify (Double Tap) ---
        if event.type == .smartMagnify {
            if let window = WindowManager.shared.getWindowUnderCursor(), WindowManager.shared.isMouseInTitleBar(of: window), !ExclusionManager.shared.isExcluded(window: window) {
                activeWindow = window
                activateAndForeground(window: window)
                
                if event.modifierFlags.contains(.option) {
                    checkAndSnap(direction: .center)
                } else {
                    toggleFullscreen(window: window)
                }

                scheduleGestureEnd()

                return true
            }
            return false
        }
        
        // --- Magnify (Pinch In / Pinch Out) ---
        if event.type == .magnify {
            let phase = event.phase
            
            if phase == .began || (phase == .changed && !startedInPinch) {
                isPinching = false
                startedInPinch = true
                pinchAccumulator = 0
                if let window = WindowManager.shared.getWindowUnderCursor(), WindowManager.shared.isMouseInTitleBar(of: window), !ExclusionManager.shared.isExcluded(window: window) {
                    activeWindow = window
                    activateAndForeground(window: window)
                } else {
                    activeWindow = nil
                }
            }
            
            guard let window = activeWindow else { return false }
            
            if phase == .changed || phase == .began {
                pinchAccumulator += event.magnification
                
                if !isPinching {
                    // Accumulate magnification over the gesture
                    if pinchAccumulator > 0.35 { // Pinch out
                        isPinching = true
                        checkAndSnap(direction: .center)
                    } else if pinchAccumulator < -0.35 { // Pinch in
                        isPinching = true
                        HUDManager.shared.showHUD(direction: .close, at: NSEvent.mouseLocation)
                        closeWindow(window: window)
                    }
                }
            }
            
            if phase == .ended || phase == .cancelled {
                scheduleGestureEnd()
            }

            return true
        }
        
        // --- Scroll Wheel (Swipes) ---
        guard event.type == .scrollWheel, event.hasPreciseScrollingDeltas else { return false }
        
        let phase = event.phase
        
        if phase == .began {
            endSwipeWorkItem?.cancel()
            idleTimer?.cancel()
            
            // Allow continuous swipes if window is still locked
            let isContinuing = (activeWindow != nil && gestureCountThisSwipe > 0 && !startedInPinch)
            if !isContinuing {
                endGestureSequence()
                if let window = WindowManager.shared.getWindowUnderCursor(), WindowManager.shared.isMouseInTitleBar(of: window), !ExclusionManager.shared.isExcluded(window: window) {
                    activeWindow = window
                    activateAndForeground(window: window)
                }
            }
            
            swipeAccumulatorX = 0
            swipeAccumulatorY = 0
        }
        
        guard let _ = activeWindow else { return false }
        guard !startedInPinch else { return true } // Ignore scroll deltas if we are in a pinch motion
        
        if phase == .began || phase == .changed {
            idleTimer?.cancel()
            let idleWorkItem = DispatchWorkItem { [weak self] in
                self?.endGestureSequence()
            }
            idleTimer = idleWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + gestureIdleTimeout, execute: idleWorkItem)
            
            swipeAccumulatorX += event.scrollingDeltaX
            swipeAccumulatorY += event.scrollingDeltaY
            
            let absX = abs(swipeAccumulatorX)
            let absY = abs(swipeAccumulatorY)
            
            if absX > swipeThreshold || absY > swipeThreshold {
                let flags = event.modifierFlags
                if let newDirection = determineDirection(dx: swipeAccumulatorX, dy: swipeAccumulatorY, currentZone: lastSnappedDirection, flags: flags) {
                    
                    if newDirection == lastSnappedDirection {
                        let pushThreshold = swipeThreshold * 3.0 // Much larger threshold to prevent spamming the same action
                        if absX < pushThreshold && absY < pushThreshold {
                            return true // Absorb but wait for deeper gesture
                        }
                    }
                    
                    gestureCountThisSwipe += 1
                    checkAndSnap(direction: newDirection)
                    
                    swipeAccumulatorX = 0
                    swipeAccumulatorY = 0
                }
            }
        } else if phase == .ended || phase == .cancelled {
            idleTimer?.cancel()
            scheduleGestureEnd()
        }
        
        return true
    }
    
    private func determineDirection(dx: CGFloat, dy: CGFloat, currentZone: SwipeDirection?, flags: NSEvent.ModifierFlags) -> SwipeDirection? {
        let absX = abs(dx)
        let absY = abs(dy)
        let diagThreshold = swipeThreshold * 0.6 // Diagonal vectors usually have less delta per axis
        
        let isThirdsMode = flags.contains(.option)
        
        if isThirdsMode {
            // Diagonal Sixths (Corners)
            if absX > diagThreshold && absY > diagThreshold {
                if dy < 0 { // Up
                    return dx < 0 ? .topLeftSixth : .topRightSixth 
                } else { // Down
                    return dx < 0 ? .bottomLeftSixth : .bottomRightSixth
                }
            }
            // Vertical 
            if absY > swipeThreshold && absY > absX {
                let isDown = dy > 0
                if isDown {
                    switch currentZone {
                    case .topLeftSixth: return .bottomLeftSixth
                    case .topMiddleSixth: return .bottomMiddleSixth
                    case .topRightSixth: return .bottomRightSixth
                    case .leftThird: return .bottomLeftSixth
                    case .middleThird: return .bottomMiddleSixth
                    case .rightThird: return .bottomRightSixth
                    default: return .minimize
                    }
                } else { // Up
                    switch currentZone {
                    case .bottomLeftSixth: return .topLeftSixth
                    case .bottomMiddleSixth: return .topMiddleSixth
                    case .bottomRightSixth: return .topRightSixth
                    case .leftThird: return .topLeftSixth
                    case .middleThird: return .topMiddleSixth
                    case .rightThird: return .topRightSixth
                    default: return .maximize
                    }
                }
            }
            // Horizontal
            if absX > swipeThreshold && absX > absY {
                let isRight = dx > 0
                if isRight {
                    switch currentZone {
                    case .leftThird: return .middleThird
                    case .middleThird: return .rightThird
                    case .topLeftSixth: return .topMiddleSixth
                    case .topMiddleSixth: return .topRightSixth
                    case .bottomLeftSixth: return .bottomMiddleSixth
                    case .bottomMiddleSixth: return .bottomRightSixth
                    default: return .rightThird
                    }
                } else { // Left
                    switch currentZone {
                    case .rightThird: return .middleThird
                    case .middleThird: return .leftThird
                    case .topRightSixth: return .topMiddleSixth
                    case .topMiddleSixth: return .topLeftSixth
                    case .bottomRightSixth: return .bottomMiddleSixth
                    case .bottomMiddleSixth: return .bottomLeftSixth
                    default: return .leftThird
                    }
                }
            }
            return nil
        }
        
        // --- Regular 2x2 Grid (Halves & Quarters) ---
        // Diagonal Quarter Snapping
        if absX > diagThreshold && absY > diagThreshold {
            if dy < 0 { // Up
                return dx < 0 ? .topLeftQuarter : .topRightQuarter
            } else { // Down
                return dx < 0 ? .bottomLeftQuarter : .bottomRightQuarter
            }
        }
        
        // Horizontal Halves
        if absX > swipeThreshold && absX > absY {
            return dx < 0 ? .leftHalf : .rightHalf
        }
        
        // Vertical Maximize/Minimize
        if absY > swipeThreshold && absY > absX {
            let isDown = dy > 0
            if isDown {
                switch currentZone {
                case .topLeftQuarter: return .bottomLeftQuarter
                case .topRightQuarter: return .bottomRightQuarter
                case .bottomLeftQuarter, .bottomRightQuarter: return currentZone // Block minimize
                default: return .minimize
                }
            } else { // Up
                switch currentZone {
                case .bottomLeftQuarter: return .topLeftQuarter
                case .bottomRightQuarter: return .topRightQuarter
                default: return .maximize
                }
            }
        }
        
        return nil
    }

    private func checkAndSnap(direction: SwipeDirection) {
        guard let window = activeWindow else { return }

        if direction == .restore {
            restorePreviousFrame(of: window)
            return
        }

        lastSnappedDirection = direction
        performHapticFeedback()

        guard let currentScreen = getScreenForWindow(window) else { return }
        
        var targetScreen = currentScreen
        let currentZone = detectZone(window: window, screenRect: currentScreen.visibleFrame)
        
        // Monitor Logic: Push to next screen if already in a half configuration
        if direction == .leftHalf && currentZone == .leftHalf {
            if let leftMonitor = getAdjacentScreen(to: currentScreen, direction: .leftHalf) {
                targetScreen = leftMonitor
            }
        } else if direction == .rightHalf && currentZone == .rightHalf {
            if let rightMonitor = getAdjacentScreen(to: currentScreen, direction: .rightHalf) {
                targetScreen = rightMonitor
            }
        }
        
        let screenRect = targetScreen.visibleFrame
        guard let mainScreen = NSScreen.screens.first else { return }
        let axY = mainScreen.frame.height - screenRect.maxY
        let axScreenRect = CGRect(x: screenRect.minX, y: axY, width: screenRect.width, height: screenRect.height)
        
        var newPosition = CGPoint.zero
        var newSize = CGSize.zero
        var shouldMinimize = false
        
        switch direction {
        case .leftHalf:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height)
        case .rightHalf:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 2), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height)
        case .maximize:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width, height: axScreenRect.height)
        case .minimize:
            shouldMinimize = true
        case .center:
            newSize = CGSize(width: axScreenRect.width * 0.7, height: axScreenRect.height * 0.7)
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width - newSize.width) / 2, y: axScreenRect.minY + (axScreenRect.height - newSize.height) / 2)
        case .topLeftQuarter:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height / 2)
        case .topRightQuarter:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 2), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height / 2)
        case .bottomLeftQuarter:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY + (axScreenRect.height / 2))
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height / 2)
        case .bottomRightQuarter:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 2), y: axScreenRect.minY + (axScreenRect.height / 2))
            newSize = CGSize(width: axScreenRect.width / 2, height: axScreenRect.height / 2)
        case .leftThird:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height)
        case .middleThird:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 3), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height)
        case .rightThird:
            newPosition = CGPoint(x: axScreenRect.minX + 2 * (axScreenRect.width / 3), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height)
        case .topLeftSixth:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .topMiddleSixth:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 3), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .topRightSixth:
            newPosition = CGPoint(x: axScreenRect.minX + 2 * (axScreenRect.width / 3), y: axScreenRect.minY)
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .bottomLeftSixth:
            newPosition = CGPoint(x: axScreenRect.minX, y: axScreenRect.minY + (axScreenRect.height / 2))
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .bottomMiddleSixth:
            newPosition = CGPoint(x: axScreenRect.minX + (axScreenRect.width / 3), y: axScreenRect.minY + (axScreenRect.height / 2))
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .bottomRightSixth:
            newPosition = CGPoint(x: axScreenRect.minX + 2 * (axScreenRect.width / 3), y: axScreenRect.minY + (axScreenRect.height / 2))
            newSize = CGSize(width: axScreenRect.width / 3, height: axScreenRect.height / 2)
        case .close, .restore:
            return // Handled before reaching this switch
        }
        
        // Show HUD Feedback
        DispatchQueue.main.async {
            HUDManager.shared.showHUD(direction: direction, at: NSEvent.mouseLocation)
        }
        
        if shouldMinimize {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, true as CFTypeRef)
        } else {
            let current = readFrame(of: window)

            // Remember the pre-snap frame once, so Restore can bring it back
            let key = WindowKey(window)
            if savedFrames[key] == nil, current.size.width > 1, current.size.height > 1 {
                if savedFrames.count > 64 { savedFrames.removeAll() }
                savedFrames[key] = CGRect(origin: current.position, size: current.size)
            }

            var targetRect = CGRect(origin: newPosition, size: newSize)

            // Apply window gaps, driven by the "Grid Spacing" slider (0-16pt)
            let windowGap = CGFloat(UserDefaults.standard.double(forKey: "gridSpacing")) * 16.0
            if windowGap > 0 && direction != .center && direction != .minimize && direction != .close {
                targetRect = targetRect.insetBy(dx: windowGap, dy: windowGap)
            }

            // Flash the snap target so the user sees where the window will land
            let previewRect = cocoaRect(fromAXRect: targetRect)
            DispatchQueue.main.async {
                SnapPreviewManager.shared.flash(rect: previewRect)
            }

            SmoothAnimator.animateWindow(
                window: window,
                startPosition: current.position,
                startSize: current.size,
                targetRect: targetRect,
                alignment: direction
            )
        }
    }

    /// Moves a window back to the frame it had before its first snap.
    /// Falls back to centering when there is nothing to restore.
    private func restorePreviousFrame(of window: AXUIElement) {
        guard let saved = savedFrames.removeValue(forKey: WindowKey(window)) else {
            checkAndSnap(direction: .center)
            return
        }

        lastSnappedDirection = nil
        performHapticFeedback()

        let current = readFrame(of: window)
        let previewRect = cocoaRect(fromAXRect: saved)
        DispatchQueue.main.async {
            HUDManager.shared.showHUD(direction: .restore, at: NSEvent.mouseLocation)
            SnapPreviewManager.shared.flash(rect: previewRect)
        }

        SmoothAnimator.animateWindow(
            window: window,
            startPosition: current.position,
            startSize: current.size,
            targetRect: saved,
            alignment: .restore
        )
    }

    private func performHapticFeedback() {
        let enabled = UserDefaults.standard.object(forKey: "hapticFeedback") == nil ? true : UserDefaults.standard.bool(forKey: "hapticFeedback")
        if enabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }

    private func readFrame(of window: AXUIElement) -> (position: CGPoint, size: CGSize) {
        var position = CGPoint.zero
        var size = CGSize.zero
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let pVal = posValue, let sVal = sizeValue,
           CFGetTypeID(pVal) == AXValueGetTypeID(), CFGetTypeID(sVal) == AXValueGetTypeID() {
            AXValueGetValue(pVal as! AXValue, .cgPoint, &position)
            AXValueGetValue(sVal as! AXValue, .cgSize, &size)
        }
        return (position, size)
    }

    /// Converts a rect from Accessibility coordinates (top-left origin of the
    /// main screen) to Cocoa screen coordinates (bottom-left origin).
    private func cocoaRect(fromAXRect rect: CGRect) -> NSRect {
        guard let mainScreen = NSScreen.screens.first else { return rect }
        return NSRect(x: rect.minX, y: mainScreen.frame.height - rect.minY - rect.height, width: rect.width, height: rect.height)
    }
    
    // MARK: - App & Native Helpers
    
    private func activateAndForeground(window: AXUIElement) {
        let cfTrue: CFTypeRef = kCFBooleanTrue
        var pid: pid_t = 0
        if AXUIElementGetPid(window, &pid) == .success {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, cfTrue)
            
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: .activateAllWindows)
            }
        }
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, cfTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, cfTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func toggleFullscreen(window: AXUIElement) {
        var isFullscreen: CFTypeRef?
        let axFullScreenAttribute = "AXFullScreen" as CFString
        if AXUIElementCopyAttributeValue(window, axFullScreenAttribute, &isFullscreen) == .success {
            let current = (isFullscreen as? NSNumber)?.boolValue ?? false
            let newValue: CFTypeRef = (!current) as CFTypeRef
            AXUIElementSetAttributeValue(window, axFullScreenAttribute, newValue)
        } else {
            // Some apps lack readable state, try to force set it
            AXUIElementSetAttributeValue(window, axFullScreenAttribute, true as CFTypeRef)
        }
    }
    
    private func closeWindow(window: AXUIElement) {
        var closeButton: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButton) == .success {
            let btn = closeButton as! AXUIElement
            AXUIElementPerformAction(btn, kAXPressAction as CFString)
        } else {
            // Fallback: Send Cmd+W since we just foregrounded it
            let src = CGEventSource(stateID: .hidSystemState)
            let cmdWDown = CGEvent(keyboardEventSource: src, virtualKey: 0x0D, keyDown: true)
            let cmdWUp = CGEvent(keyboardEventSource: src, virtualKey: 0x0D, keyDown: false)
            cmdWDown?.flags = .maskCommand
            cmdWUp?.flags = .maskCommand
            cmdWDown?.post(tap: .cghidEventTap)
            cmdWUp?.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Screen Management Helpers

    private func getScreenForWindow(_ window: AXUIElement) -> NSScreen? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
            if let pVal = posValue, let sVal = sizeValue, CFGetTypeID(pVal) == AXValueGetTypeID(), CFGetTypeID(sVal) == AXValueGetTypeID() {
                var pos = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(pVal as! AXValue, .cgPoint, &pos)
                AXValueGetValue(sVal as! AXValue, .cgSize, &size)
                
                let windowRect = CGRect(origin: pos, size: size)
                if let mainScreen = NSScreen.screens.first {
                    let y = mainScreen.frame.height - windowRect.maxY
                    let cgWindowRect = CGRect(x: windowRect.minX, y: y, width: windowRect.width, height: windowRect.height)
                    
                    // Prioritize the screen containing the center of the window
                    let center = CGPoint(x: cgWindowRect.midX, y: cgWindowRect.midY)
                    return NSScreen.screens.first(where: { $0.frame.contains(center) }) ??
                           NSScreen.screens.first(where: { $0.frame.intersects(cgWindowRect) })
                }
            }
        }
        return NSScreen.main
    }

    private func getAdjacentScreen(to screen: NSScreen, direction: SwipeDirection) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        
        let sortedLeftToRight = screens.sorted { $0.frame.minX < $1.frame.minX }
        guard let index = sortedLeftToRight.firstIndex(of: screen) else { return nil }
        
        if direction == .leftHalf && index > 0 {
            return sortedLeftToRight[index - 1]
        } else if direction == .rightHalf && index < sortedLeftToRight.count - 1 {
            return sortedLeftToRight[index + 1]
        }
        return nil
    }

    private func detectZone(window: AXUIElement, screenRect: NSRect) -> SwipeDirection? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let pVal = posValue, let sVal = sizeValue,
           CFGetTypeID(pVal) == AXValueGetTypeID(), CFGetTypeID(sVal) == AXValueGetTypeID() {
            var pos = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(pVal as! AXValue, .cgPoint, &pos)
            AXValueGetValue(sVal as! AXValue, .cgSize, &size)
            
            guard let mainScreen = NSScreen.screens.first else { return nil }
            let axY = mainScreen.frame.height - screenRect.maxY
            let axScreenRect = CGRect(x: screenRect.minX, y: axY, width: screenRect.width, height: screenRect.height)
            
            let isLeft = abs(pos.x - axScreenRect.minX) < 40
            let isRight = abs(pos.x + size.width - axScreenRect.maxX) < 40
            let isHalfWidth = abs(size.width - (axScreenRect.width / 2)) < 150
            
            if isHalfWidth {
                if isLeft { return .leftHalf }
                if isRight { return .rightHalf }
            }
        }
        return nil
    }
}
