import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case windows = "Windows"
    case snapping = "Snapping"
    case shortcuts = "Shortcuts"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .windows: return "macwindow"
        case .snapping: return "uiwindow.split.2x1"
        case .shortcuts: return "keyboard"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 10) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SidebarTab(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)
            .frame(width: 180)
            .background(Color.black.opacity(0.2))
            
            Divider()
            
            // Main Content Area
            ZStack {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .windows:
                    WindowControlsView()
                case .snapping:
                    GridSnappingView()
                case .shortcuts:
                    ShortcutsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 750, height: 600)
        // Ensure glassmorphism
        .background(VisualEffectView().ignoresSafeArea())
    }
}

struct SidebarTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundColor(isSelected ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Subviews

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInMenubar") private var showInMenubar: Bool = true
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("touchSensitivity") private var touchSensitivity: Double = 0.5
    @AppStorage("cancelTimeout") private var cancelTimeout: Double = 2.0
    @AppStorage("showTooltips") private var showTooltips: Bool = true
    @AppStorage("tooltipSize") private var tooltipSize: Double = 0.5
    @AppStorage("showLiveTooltips") private var showLiveTooltips: Bool = true
    @AppStorage("useAnimations") private var useAnimations: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "System")

                SettingsSection(title: "System Integration") {
                    HStack {
                        ToggleSettingRow(title: "Launch at Login", isOn: $launchAtLogin)
                        ToggleSettingRow(title: "Show in Menubar", isOn: $showInMenubar)
                    }
                    Text("You can always access this window by opening Slide via Finder or Launchpad.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                SettingsHeader(title: "Gestures")

                SettingsSection(title: "Feedback & Timing") {
                    ToggleSettingRow(title: "Window Animations", isOn: $useAnimations, description: "Smoothly animate windows when snapping.")
                    ToggleSettingRow(title: "Haptic Feedback", isOn: $hapticFeedback, description: "Slide will provide haptic feedback if enabled via System Settings.")

                    SliderSettingRow(title: "Touch Sensitivity", value: $touchSensitivity, range: 0...1, label: touchSensitivity > 0.75 ? "Very Snappy" : (touchSensitivity < 0.25 ? "Relaxed" : "Balanced"))
                    Text("Higher sensitivity means shorter swipes trigger actions. Depending on your hardware, you might want to decrease sensitivity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                    SliderSettingRow(title: "Cancel Timeout", value: $cancelTimeout, range: 0.5...3.0, label: String(format: "%.1f Seconds", cancelTimeout))
                    Text("Cancel gestures by pressing Esc or resting for the specified timeout.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                SettingsHeader(title: "Tooltips")

                SettingsSection(title: "Visual Guides") {
                    HStack {
                        ToggleSettingRow(title: "Show Tooltips", isOn: $showTooltips)
                        SliderSettingRow(title: "Size", value: $tooltipSize, range: 0...1, label: "")
                    }
                    Text("Tooltips will always let you know what's going on.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                    ToggleSettingRow(title: "Show Snap Preview", isOn: $showLiveTooltips, description: "Briefly highlights the target area a window is about to snap into.")
                }

                SettingsHeader(title: "Excluded Apps")

                ExcludedAppsSection()

                Spacer()
            }
            .padding(30)
        }
        .onAppear {
            // The system is the source of truth for the login item state
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Slide: Failed to update login item: \(error)")
            }
        }
    }
}

struct ExcludedAppsSection: View {
    @ObservedObject private var exclusionManager = ExclusionManager.shared

    var body: some View {
        SettingsSection(title: "Slide is disabled for these apps") {
            if exclusionManager.excludedBundleIDs.isEmpty {
                Text("No apps excluded. Add games or drawing apps whose windows Slide should never touch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                ForEach(exclusionManager.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Image(systemName: "app.dashed")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exclusionManager.displayName(for: bundleID))
                                .font(.body)
                            Text(bundleID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { exclusionManager.remove(bundleID: bundleID) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider().background(Color.white.opacity(0.1))
                }
            }

            HStack {
                Spacer()
                Button("Add App…") {
                    addAppViaPanel()
                }
            }
            .padding()
        }
    }

    private func addAppViaPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose apps Slide should ignore"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundleID = Bundle(url: url)?.bundleIdentifier {
                    exclusionManager.add(bundleID: bundleID)
                }
            }
        }
    }
}

struct WindowControlsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "Windows")
                Text("Control basic functionality by swiping and pinching while the pointer rests on a window's title bar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                SettingsSection(title: "Window Actions") {
                    GestureRow(icon: "xmark.circle", iconColor: .red, title: "Close", gestureIcon: "arrow.down.right.and.arrow.up.left", description: "Pinch in to close a window.")
                    GestureRow(icon: "minus.circle.fill", iconColor: .yellow, title: "Minimize", gestureIcon: "arrow.down", description: "Swipe down once to minimize a window.")
                    GestureRow(icon: "plus.circle.fill", iconColor: .green, title: "Fullscreen", gestureIcon: "hand.tap", description: "Double-tap with two fingers on the title bar to toggle fullscreen.")
                    GestureRow(icon: "rectangle.center.inset.filled", iconColor: .blue, title: "Center", gestureIcon: "arrow.up.left.and.arrow.down.right", description: "Pinch out — or double-tap while holding ⌥ — to center a window at 70% size.")
                }

                Spacer()
            }
            .padding(30)
        }
    }
}

struct GridSnappingView: View {
    @AppStorage("gridSpacing") private var gridSpacing: Double = 0.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "Snapping")
                Text("Snap windows to halves, quarters, thirds and sixths.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                SettingsSection(title: "Behavior") {
                    SliderSettingRow(title: "Grid Spacing", value: $gridSpacing, range: 0...1, label: gridSpacing == 0 ? "Off" : "\(Int((gridSpacing * 16).rounded())) pt")
                    Text("A small distance between windows and screen edges can visually declutter your desktop.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                SettingsSection(title: "Standard Snaps") {
                    GestureRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Maximize", gestureIcon: "arrow.up", description: "Swipe up once to fill the entire desktop area.")
                    GestureRow(icon: "rectangle.split.2x1", iconColor: .blue, title: "Halves", gestureIcon: "arrow.left.and.right", description: "Swipe horizontally to snap to the left or right half. Swipe again in the same direction to push the window to the adjacent display.")
                    GestureRow(icon: "rectangle.split.2x2", iconColor: .blue, title: "Quarters", gestureIcon: "arrow.up.right.and.arrow.down.left", description: "Swipe diagonally — or horizontally and vertically in sequence — to snap to a quarter.")
                    GestureRow(icon: "rectangle.split.3x1", iconColor: .blue, title: "Thirds & Sixths", gestureIcon: "option", description: "Hold ⌥ while swiping to snap to thirds; add a vertical or diagonal component for sixths.")
                }

                Spacer()
            }
            .padding(30)
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    @AppStorage("keyboardShortcutsEnabled") private var shortcutsEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "Shortcuts")
                Text("Trigger any snap action from the keyboard — works on the window under the cursor, otherwise on the frontmost window.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                SettingsSection(title: "Keyboard Control") {
                    ToggleSettingRow(title: "Enable Keyboard Shortcuts", isOn: $shortcutsEnabled, description: "Global shortcuts work in every app while Slide is running.")
                }

                Group {
                    SettingsSection(title: "Basics") {
                        ForEach([SnapAction.leftHalf, .rightHalf, .maximize, .minimize, .center, .restore]) { action in
                            ShortcutRow(action: action)
                        }
                    }

                    SettingsSection(title: "Quarters") {
                        ForEach([SnapAction.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]) { action in
                            ShortcutRow(action: action)
                        }
                    }

                    SettingsSection(title: "Thirds") {
                        ForEach([SnapAction.leftThird, .middleThird, .rightThird]) { action in
                            ShortcutRow(action: action)
                        }
                    }

                    HStack {
                        Text("Click a shortcut to record a new one. Press ⎋ to cancel, ⌫ to remove.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Reset to Defaults") {
                            shortcutManager.resetToDefaults()
                        }
                    }
                }
                .disabled(!shortcutsEnabled)
                .opacity(shortcutsEnabled ? 1 : 0.4)

                Spacer()
            }
            .padding(30)
        }
    }
}

struct ShortcutRow: View {
    let action: SnapAction

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: action.direction.iconName)
                .foregroundColor(.purple)
                .font(.title3)
                .frame(width: 24)

            Text(action.title)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            ShortcutRecorderButton(action: action)
        }
        .padding()
        Divider().background(Color.white.opacity(0.1))
    }
}

struct ShortcutRecorderButton: View {
    let action: SnapAction
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            Text(labelText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .purple : (shortcutManager.shortcuts[action] == nil ? .secondary : .primary))
                .frame(minWidth: 100)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isRecording ? 0.15 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.purple : Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private var labelText: String {
        if isRecording { return "Type shortcut…" }
        return shortcutManager.shortcuts[action]?.displayString ?? "None"
    }

    private func startRecording() {
        isRecording = true
        // Tell the global event tap to let key events through while recording
        shortcutManager.isCapturingShortcut = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleRecordedEvent(event)
            return nil // swallow the event while recording
        }
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(KeyboardShortcut.relevantModifiers)

        if event.keyCode == 53 { // Esc cancels
            stopRecording()
            return
        }
        if event.keyCode == 51 && modifiers.isEmpty { // plain Backspace clears
            shortcutManager.setShortcut(nil, for: action)
            stopRecording()
            return
        }
        // Require ⌘, ⌥ or ⌃ so a global shortcut can never block plain typing
        guard !modifiers.intersection([.command, .option, .control]).isEmpty else {
            NSSound.beep()
            return
        }

        shortcutManager.setShortcut(KeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers), for: action)
        stopRecording()
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        isRecording = false
        shortcutManager.isCapturingShortcut = false
    }
}

// MARK: - Reusable UI Components

struct SettingsHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.bottom, 10)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.bottom, 10)
    }
}

struct ToggleSettingRow: View {
    let title: String
    @Binding var isOn: Bool
    var description: String? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
            }
            
            if let desc = description {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        Divider().background(Color.white.opacity(0.1))
    }
}

struct SliderSettingRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Slider(value: $value, in: range)
                    .frame(width: 80)
                    .accentColor(.purple)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding()
        Divider().background(Color.white.opacity(0.1))
    }
}

struct GestureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let gestureIcon: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 80, alignment: .leading)
                    
                    Image(systemName: gestureIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        Divider().background(Color.white.opacity(0.1))
    }
}
