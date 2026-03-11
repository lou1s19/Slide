import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case windows = "Windows"
    case snapping = "Snapping"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .windows: return "macwindow"
        case .snapping: return "uiwindow.split.2x1"
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
    @AppStorage("tapAndHold") private var tapAndHold: Bool = true
    @AppStorage("cancelTimeout") private var cancelTimeout: Double = 0.8
    @AppStorage("showTooltips") private var showTooltips: Bool = true
    @AppStorage("tooltipSize") private var tooltipSize: Double = 0.5
    @AppStorage("hideCursor") private var hideCursor: Bool = true
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
                    
                    HStack {
                        SliderSettingRow(title: "Touch Sensitivity", value: $touchSensitivity, range: 0...1, label: "Very Snappy")
                        ToggleSettingRow(title: "Tap & Hold", isOn: $tapAndHold)
                    }
                    Text("Depending on your hardware, you might want to decrease sensitivity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    
                    SliderSettingRow(title: "Cancel Timeout", value: $cancelTimeout, range: 0.1...2.0, label: String(format: "%.1f Seconds", cancelTimeout))
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
                        ToggleSettingRow(title: "Hide Cursor", isOn: $hideCursor)
                    }
                    Text("Tooltips will always let you know what's going on.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    
                    ToggleSettingRow(title: "Show Live Tooltips", isOn: $showLiveTooltips, description: "Live tooltips provide animated snapping previews.")
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

struct WindowControlsView: View {
    @AppStorage("missionControlGestures") private var missionControlGestures: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "Windows")
                Text("Control basic functionality by swiping and pinching on window titlebars.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                SettingsSection(title: "Core") {
                    ToggleSettingRow(title: "Mission Control", isOn: $missionControlGestures, description: "Most Window and Snapping gestures also work in Mission Control & App Exposé.")
                    
                    HStack {
                        Text("General Modifier")
                            .font(.body)
                            .fontWeight(.medium)
                        Image(systemName: "command")
                            .padding(4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding()
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    GestureRow(icon: "xmark.circle.fill", iconColor: .red, title: "Quit", gestureIcon: "arrow.down.right.and.arrow.up.left",  description: "Pinch in twice to quit an application.")
                    GestureRow(icon: "xmark.circle", iconColor: .red, title: "Close", gestureIcon: "arrow.down.right.and.arrow.up.left", description: "Pinch in once to close a window.")
                    GestureRow(icon: "minus.circle.fill", iconColor: .yellow, title: "Minimize", gestureIcon: "arrow.down", description: "Swipe down once to minimize a window.")
                    GestureRow(icon: "plus.circle.fill", iconColor: .green, title: "Fullscreen", gestureIcon: "arrow.up.left.and.arrow.down.right", description: "Pinch out or tap, hold and swipe up to enter or exit fullscreen mode.")
                    GestureRow(icon: "eye.slash.fill", iconColor: .gray, title: "Hide", gestureIcon: "hand.tap.file", description: "Double tap with the general modifier to hide all windows of an application.")
                }
                
                SettingsHeader(title: "Tabs")
                Text("Control tabs in native macOS windows.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                SettingsSection(title: "Tab Management") {
                    GestureRow(icon: "xmark.circle", iconColor: .blue, title: "Close Tab", gestureIcon: "arrow.down.right.and.arrow.up.left", description: "Pinch in to close a tab.")
                    GestureRow(icon: "circle.fill.pattern.3.to.3.blue", iconColor: .gray, title: "Detach", gestureIcon: "hand.tap.file", description: "Tap and hold to detach a native tab into a new window.")
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

struct GridSnappingView: View {
    @AppStorage("nativeWindowTiling") private var nativeWindowTiling: Bool = true
    @AppStorage("gridSpacing") private var gridSpacing: Double = 0.0
    @AppStorage("dragToUnsnap") private var dragToUnsnap: Bool = true
    @AppStorage("resizeAdjacent") private var resizeAdjacent: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                SettingsHeader(title: "Snapping")
                Text("Snap windows to a 2x2, 3x2 or 3x3 grid.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                SettingsSection(title: "Behavior") {
                    ToggleSettingRow(title: "Native Window Tiling", isOn: $nativeWindowTiling, description: "Combine native macOS drag to edge tiling with Slide's 2x2 snapping gestures.")
                    SliderSettingRow(title: "Grid Spacing", value: $gridSpacing, range: 0...1, label: gridSpacing == 0 ? "Off" : "On")
                    Text("A small distance between windows and screen edges can visually declutter your desktop.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    
                    ToggleSettingRow(title: "Drag to Unsnap", isOn: $dragToUnsnap, description: "Use the secondary modifier to temporarily disable Drag to Unsnap.")
                    ToggleSettingRow(title: "Resize Adjacent Windows", isOn: $resizeAdjacent, description: "Quickly resize multiple snapped windows at once by dragging the divider between them.")
                }
                
                SettingsSection(title: "Standard Snaps") {
                    GestureRow(icon: "rectangle.center.inset.filled", iconColor: .blue, title: "Center", gestureIcon: "hand.tap.file", description: "Double tap to unsnap and/or center a window.")
                    GestureRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Maximize", gestureIcon: "arrow.up", description: "Swipe up once to fill the entire desktop area.")
                    GestureRow(icon: "rectangle.split.2x1", iconColor: .blue, title: "Halves", gestureIcon: "arrow.left.and.right", description: "Swipe horizontally to snap to the left or right half of the screen.")
                    GestureRow(icon: "rectangle.split.1x2", iconColor: .blue, title: "Vertical", gestureIcon: "arrow.up.and.down", description: "Double-swipe vertically to snap to the top or bottom half.")
                    GestureRow(icon: "rectangle.split.2x2", iconColor: .blue, title: "Quarters", gestureIcon: "arrow.up.right.and.arrow.down.left", description: "Swipe horizontally and vertically to snap to a quarter. Both orders work.")
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

// Removed unused views

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
