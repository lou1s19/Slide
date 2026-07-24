import Cocoa

class SmoothAnimator {
    private static let stateLock = NSLock()
    private static var currentAnimationID: Int = 0

    private static let animationQueue = DispatchQueue(label: "com.slide.animator", qos: .userInteractive)

    private static let duration: TimeInterval = 0.24
    private static let maxFrameRate: Double = 120.0

    /// Animates an Accessibility Window's position and size.
    ///
    /// The animation is driven by wall-clock time, not by a fixed frame count:
    /// Accessibility calls are IPC into the target app and can easily take
    /// 10-30 ms each, so a naive "sleep 1/60s per frame" loop stretches a
    /// 0.18 s animation into a second of stutter. Here every iteration samples
    /// the elapsed time and jumps to the mathematically correct intermediate
    /// frame, so slow apps simply get fewer frames while the total duration
    /// stays constant.
    ///
    /// - Parameters:
    ///   - window: The AXUIElement representing the window.
    ///   - startPosition: Current position of the window.
    ///   - startSize: Current size of the window.
    ///   - targetRect: The mathematically ideal area the window should occupy.
    ///   - alignment: The direction/corner to align the window to if it resists sizing.
    static func animateWindow(window: AXUIElement, startPosition: CGPoint, startSize: CGSize, targetRect: CGRect, alignment: SwipeDirection) {
        stateLock.lock()
        currentAnimationID += 1
        let animID = currentAnimationID
        stateLock.unlock()

        let useAnimations = UserDefaults.standard.object(forKey: "useAnimations") == nil ? true : UserDefaults.standard.bool(forKey: "useAnimations")

        animationQueue.async {
            guard isCurrent(animID) else { return }

            let movesFarEnough = abs(startPosition.x - targetRect.origin.x) > 1 ||
                                 abs(startPosition.y - targetRect.origin.y) > 1 ||
                                 abs(startSize.width - targetRect.width) > 1 ||
                                 abs(startSize.height - targetRect.height) > 1

            if !useAnimations || !movesFarEnough {
                applyFinalGeometry(window: window, idealRect: targetRect, alignment: alignment)
                return
            }

            let startTime = CFAbsoluteTimeGetCurrent()
            let minFrameTime = 1.0 / maxFrameRate

            while true {
                // If a new animation started, kill this one immediately so the two never fight
                guard isCurrent(animID) else { return }

                let frameStart = CFAbsoluteTimeGetCurrent()
                let elapsed = frameStart - startTime
                if elapsed >= duration { break }

                let progress = springProgress(elapsed / duration)

                let currentRect = CGRect(
                    x: startPosition.x + (targetRect.origin.x - startPosition.x) * progress,
                    y: startPosition.y + (targetRect.origin.y - startPosition.y) * progress,
                    width: startSize.width + (targetRect.size.width - startSize.width) * progress,
                    height: startSize.height + (targetRect.size.height - startSize.height) * progress
                )

                // Intermediate frames are fire-and-forget: no read-back, no
                // edge correction. That halves the IPC cost per frame.
                setFrame(window: window, rect: currentRect)

                let frameCost = CFAbsoluteTimeGetCurrent() - frameStart
                if frameCost < minFrameTime {
                    Thread.sleep(forTimeInterval: minFrameTime - frameCost)
                }
            }

            guard isCurrent(animID) else { return }
            // Land exactly on the target, including clamped-size edge anchoring.
            applyFinalGeometry(window: window, idealRect: targetRect, alignment: alignment)
        }
    }

    /// Critically damped spring curve: fast start, soft landing, no overshoot.
    /// Normalized so progress(0) == 0 and progress(1) == 1.
    static func springProgress(_ t: Double) -> Double {
        let clamped = min(max(t, 0.0), 1.0)
        let stiffness = 9.0
        let raw = 1.0 - (1.0 + stiffness * clamped) * exp(-stiffness * clamped)
        let terminal = 1.0 - (1.0 + stiffness) * exp(-stiffness)
        return raw / terminal
    }

    private static func isCurrent(_ animID: Int) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return animID == currentAnimationID
    }

    /// Cheap intermediate frame: just push position and size.
    /// The Accessibility API is safe to call from a background queue, and
    /// keeping the whole animation off the main thread avoids blocking UI
    /// and the event tap while a slow target app processes the request.
    private static func setFrame(window: AXUIElement, rect: CGRect) {
        var position = rect.origin
        var size = rect.size

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue as CFTypeRef)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue as CFTypeRef)
        }
    }

    /// Final frame: set the ideal size, read back what the app actually
    /// accepted (many windows enforce a minimum size), then anchor the
    /// clamped window flush to the targeted screen edge.
    private static func applyFinalGeometry(window: AXUIElement, idealRect: CGRect, alignment: SwipeDirection) {
        var idealSz = idealRect.size

        if let sizeValue = AXValueCreate(.cgSize, &idealSz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue as CFTypeRef)
        }

        var actualSize = idealRect.size
        var sizeValueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValueRef) == .success,
           let sizeVal = sizeValueRef,
           CFGetTypeID(sizeVal) == AXValueGetTypeID() {
            let axSz = sizeVal as! AXValue
            AXValueGetValue(axSz, .cgSize, &actualSize)
        }

        var finalPosition = idealRect.origin
        switch alignment {
        case .rightHalf, .topRightQuarter, .bottomRightQuarter, .rightThird, .topRightSixth, .bottomRightSixth:
            finalPosition.x = idealRect.maxX - actualSize.width
        case .leftHalf, .topLeftQuarter, .bottomLeftQuarter, .maximize, .minimize, .leftThird, .topLeftSixth, .bottomLeftSixth:
            finalPosition.x = idealRect.minX
        case .center, .close, .middleThird, .topMiddleSixth, .bottomMiddleSixth:
            finalPosition.x = idealRect.midX - (actualSize.width / 2)
        }

        switch alignment {
        case .bottomLeftQuarter, .bottomRightQuarter, .bottomLeftSixth, .bottomMiddleSixth, .bottomRightSixth:
            finalPosition.y = idealRect.maxY - actualSize.height
        case .leftHalf, .rightHalf, .maximize, .minimize, .topLeftQuarter, .topRightQuarter, .leftThird, .middleThird, .rightThird, .topLeftSixth, .topMiddleSixth, .topRightSixth:
            finalPosition.y = idealRect.minY
        case .center, .close:
            finalPosition.y = idealRect.midY - (actualSize.height / 2)
        }

        if let posValue = AXValueCreate(.cgPoint, &finalPosition) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue as CFTypeRef)
        }
        // Apple often needs the size reaffirmed after the position moved.
        if let sizeValue = AXValueCreate(.cgSize, &idealSz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue as CFTypeRef)
        }
    }
}
