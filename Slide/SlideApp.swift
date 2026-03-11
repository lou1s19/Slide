//
//  SlideApp.swift
//  Slide
//
//  Created by Louis Saks on 06.03.26.
//

import SwiftUI

class SlideAppDelegate: NSObject, NSApplicationDelegate {
    var accessManager: AccessibilityManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App just launched, let's check permissions right away
        // We delay the UI logic slightly to ensure the RunLoop is ready
        DispatchQueue.main.async {
            guard let manager = self.accessManager else { return }
            
            if !manager.isTrusted {
                OnboardingWindowManager.shared.show(manager: manager)
            } else {
                GestureManager.shared.startMonitoring()
                // Show Settings Window so the user knows the app started
                SettingsWindowManager.shared.show()
            }
        }
    }
}

@main
struct SlideApp: App {
    @NSApplicationDelegateAdaptor(SlideAppDelegate.self) var appDelegate
    @StateObject private var accessManager = AccessibilityManager()

    var body: some Scene {
        MenuBarExtra("Slide", systemImage: "sparkles") {
            MenuBarItems(accessManager: accessManager)
        }
        .onChange(of: accessManager.isTrusted) { oldValue, newValue in
            if newValue {
                OnboardingWindowManager.shared.close()
                GestureManager.shared.startMonitoring()
            } else {
                GestureManager.shared.stopMonitoring()
            }
        }
    }
    
    init() {
        // Pass the StateObject reference correctly to the AppDelegate
        appDelegate.accessManager = accessManager
    }
}

struct MenuBarItems: View {
    @ObservedObject var accessManager: AccessibilityManager
    
    var body: some View {
        Button("Settings") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            SettingsWindowManager.shared.show()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button("Quit Slide") {
            NSApplication.shared.terminate(nil)
        }
    }
}

class OnboardingWindowManager: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowManager()
    private var window: NSWindow?
    
    func show(manager: AccessibilityManager) {
        if window == nil {
            let hostingController = NSHostingController(rootView: OnboardingView(manager: manager))
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.isReleasedWhenClosed = false
            window?.contentViewController = hostingController
            window?.title = "Welcome to Slide"
            window?.titlebarAppearsTransparent = true
            window?.titleVisibility = .hidden
            window?.isOpaque = false
            window?.backgroundColor = .clear
            window?.delegate = self
        }
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window?.close()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window?.orderOut(nil)
        return false
    }
}

class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?
    
    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.setFrameAutosaveName("SlideSettings")
            window?.isReleasedWhenClosed = false
            window?.contentViewController = hostingController
            window?.title = "Slide Settings"
            window?.titlebarAppearsTransparent = true
            window?.titleVisibility = .visible // Keep title text visible
            window?.delegate = self
            
            // To fix reopening bug, we do not let the system release the window on close.
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    // NSWindowDelegate method to handle closing safely without deallocation
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window?.orderOut(nil)
        return false
    }
}
