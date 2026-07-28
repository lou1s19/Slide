import Cocoa
import Combine

/// Keeps the list of apps whose windows Slide must leave alone.
/// Useful for games, drawing apps, or anything where two-finger swipes
/// near the title bar have their own meaning.
class ExclusionManager: ObservableObject {
    static let shared = ExclusionManager()

    @Published private(set) var excludedBundleIDs: [String]

    private let defaults: UserDefaults
    private static let storageKey = "excludedApps"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.excludedBundleIDs = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    func add(bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !excludedBundleIDs.contains(trimmed) else { return }
        excludedBundleIDs.append(trimmed)
        excludedBundleIDs.sort()
        defaults.set(excludedBundleIDs, forKey: Self.storageKey)
    }

    func remove(bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
        defaults.set(excludedBundleIDs, forKey: Self.storageKey)
    }

    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID = bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    /// Checks whether the app owning the given Accessibility window is excluded.
    func isExcluded(window: AXUIElement) -> Bool {
        guard !excludedBundleIDs.isEmpty else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return false }
        return isExcluded(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }

    /// Best-effort pretty name for the settings list.
    func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            if !name.isEmpty { return name }
        }
        return bundleID
    }
}
