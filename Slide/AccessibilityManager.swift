import Cocoa
import SwiftUI
import Combine

class AccessibilityManager: ObservableObject {
    @Published var isTrusted: Bool
    
    private var timer: Timer?
    
    init() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        self.isTrusted = AXIsProcessTrustedWithOptions(options)
        
        checkTrust()
        
        // Listen for when the app becomes active, just in case they fixed it in System Settings
        NotificationCenter.default.addObserver(self, selector: #selector(checkTrust), name: NSApplication.didBecomeActiveNotification, object: nil)
        
        // Also poll every second because background apps often miss activation events
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkTrust()
        }
    }
    
    @objc func checkTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.isTrusted = trusted
        }
    }
    
    func promptForTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.isTrusted = trusted
        }
    }
    
    func openSystemPrefs() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
}
