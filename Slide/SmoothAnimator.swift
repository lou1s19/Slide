import Cocoa

class SmoothAnimator {
    private static var currentAnimationID: Int = 0

    private static let animationQueue = DispatchQueue(label: "com.slide.animator")

    /// Animates an Accessibility Window's position and size.
    /// - Parameters:
    ///   - window: The AXUIElement representing the window.
    ///   - startPosition: Current position of the window.
    ///   - startSize: Current size of the window.
    ///   - targetRect: The mathematically ideal area the window should occupy.
    ///   - alignment: The direction/corner to align the window to if it resists sizing.
    static func animateWindow(window: AXUIElement, startPosition: CGPoint, startSize: CGSize, targetRect: CGRect, alignment: SwipeDirection) {
        currentAnimationID += 1
        let animID = currentAnimationID

        let useAnimations = UserDefaults.standard.object(forKey: "useAnimations") == nil ? true : UserDefaults.standard.bool(forKey: "useAnimations")
        let duration: TimeInterval = useAnimations ? 0.18 : 0.0

        let fps: Double = 60.0
        let totalFrames = Int(duration * fps)

        animationQueue.async {
            if animID != SmoothAnimator.currentAnimationID { return }

            if !useAnimations || totalFrames <= 0 {
                // Instant snap
                applyFrameGeometry(window: window, idealRect: targetRect, alignment: alignment)
                return
            }

            for frame in 1...totalFrames {
                // If a new animation started, kill this old thread immediately to prevent math conflicts
                if animID != SmoothAnimator.currentAnimationID { return }

                let progress = Double(frame) / Double(totalFrames)

                // Ease-out cubic curve
                let easedProgress = 1.0 - pow(1.0 - progress, 3)

                let currentIdealRect = CGRect(
                    x: startPosition.x + (targetRect.origin.x - startPosition.x) * easedProgress,
                    y: startPosition.y + (targetRect.origin.y - startPosition.y) * easedProgress,
                    width: startSize.width + (targetRect.size.width - startSize.width) * easedProgress,
                    height: startSize.height + (targetRect.size.height - startSize.height) * easedProgress
                )

                applyFrameGeometry(window: window, idealRect: currentIdealRect, alignment: alignment)

                Thread.sleep(forTimeInterval: 1.0 / fps)
            }

            if animID == SmoothAnimator.currentAnimationID {
                // Ensure we hit the exact target position at the end only if we weren't cancelled.
                applyFrameGeometry(window: window, idealRect: targetRect, alignment: alignment)
            }
        }
    }

    private static func applyFrameGeometry(window: AXUIElement, idealRect: CGRect, alignment: SwipeDirection) {
        var idealSz = idealRect.size

        performOnMain {
            // 1. Ask macOS to set the ideal size.
            if let sizeValue = AXValueCreate(.cgSize, &idealSz) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue as CFTypeRef)
            }
        }

        // 2. Read back what macOS actually clamped it to.
        var actualSize = idealRect.size
        var sizeValueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValueRef) == .success,
           let sizeVal = sizeValueRef,
           CFGetTypeID(sizeVal) == AXValueGetTypeID() {
            let axSz = sizeVal as! AXValue
            AXValueGetValue(axSz, .cgSize, &actualSize)
        }

        // 3. Anchor it flush to the targeted screen edge.
        var currentPosition = idealRect.origin
        switch alignment {
        case .rightHalf, .topRightQuarter, .bottomRightQuarter, .rightThird, .topRightSixth, .bottomRightSixth:
            currentPosition.x = idealRect.maxX - actualSize.width
        case .leftHalf, .topLeftQuarter, .bottomLeftQuarter, .maximize, .minimize, .leftThird, .topLeftSixth, .bottomLeftSixth:
            currentPosition.x = idealRect.minX
        case .center, .close, .middleThird, .topMiddleSixth, .bottomMiddleSixth:
            currentPosition.x = idealRect.midX - (actualSize.width / 2)
        }

        switch alignment {
        case .bottomLeftQuarter, .bottomRightQuarter, .bottomLeftSixth, .bottomMiddleSixth, .bottomRightSixth:
            currentPosition.y = idealRect.maxY - actualSize.height
        case .leftHalf, .rightHalf, .maximize, .minimize, .topLeftQuarter, .topRightQuarter, .leftThird, .middleThird, .rightThird, .topLeftSixth, .topMiddleSixth, .topRightSixth:
            currentPosition.y = idealRect.minY
        case .center, .close:
            currentPosition.y = idealRect.midY - (actualSize.height / 2)
        }

        // 4. Set final position (Apple often needs size reaffirmed after position).
        performOnMain {
            if let posValue = AXValueCreate(.cgPoint, &currentPosition) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue as CFTypeRef)
            }
            if let sizeValue = AXValueCreate(.cgSize, &idealSz) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue as CFTypeRef)
            }
        }
    }

    private static func performOnMain(_ block: () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
}
