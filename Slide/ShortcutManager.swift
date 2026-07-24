import Cocoa
import Combine

/// A user-configurable keyboard shortcut (key + modifiers) for a snap action.
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierRawValue: UInt

    /// Only these modifiers are considered when storing and matching shortcuts.
    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierRawValue = modifiers.intersection(KeyboardShortcut.relevantModifiers).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue).intersection(KeyboardShortcut.relevantModifiers)
    }

    /// Human readable representation, e.g. "⌥⌘←".
    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + KeyboardShortcut.keyName(for: keyCode)
    }

    static func modifierFlags(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskControl) { result.insert(.control) }
        return result
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
            27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 50: "`",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤",
            115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}

/// Every window action that can be triggered from the keyboard.
enum SnapAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, maximize, minimize, center
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, middleThird, rightThird

    var id: String { rawValue }

    var direction: SwipeDirection {
        switch self {
        case .leftHalf: return .leftHalf
        case .rightHalf: return .rightHalf
        case .maximize: return .maximize
        case .minimize: return .minimize
        case .center: return .center
        case .topLeftQuarter: return .topLeftQuarter
        case .topRightQuarter: return .topRightQuarter
        case .bottomLeftQuarter: return .bottomLeftQuarter
        case .bottomRightQuarter: return .bottomRightQuarter
        case .leftThird: return .leftThird
        case .middleThird: return .middleThird
        case .rightThird: return .rightThird
        }
    }

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .maximize: return "Maximize"
        case .minimize: return "Minimize"
        case .center: return "Center"
        case .topLeftQuarter: return "Top Left Quarter"
        case .topRightQuarter: return "Top Right Quarter"
        case .bottomLeftQuarter: return "Bottom Left Quarter"
        case .bottomRightQuarter: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .middleThird: return "Middle Third"
        case .rightThird: return "Right Third"
        }
    }

    /// Shipped defaults: ⌥⌘ + Arrows for the basics, ⌥⌘⌫ for center.
    /// Quarters and thirds ship without a shortcut so they never surprise anyone.
    var defaultShortcut: KeyboardShortcut? {
        let optCmd: NSEvent.ModifierFlags = [.option, .command]
        switch self {
        case .leftHalf: return KeyboardShortcut(keyCode: 123, modifiers: optCmd)
        case .rightHalf: return KeyboardShortcut(keyCode: 124, modifiers: optCmd)
        case .maximize: return KeyboardShortcut(keyCode: 126, modifiers: optCmd)
        case .minimize: return KeyboardShortcut(keyCode: 125, modifiers: optCmd)
        case .center: return KeyboardShortcut(keyCode: 51, modifiers: optCmd)
        default: return nil
        }
    }
}

/// Stores the shortcut assignments and resolves incoming key events to actions.
class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    @Published private(set) var shortcuts: [SnapAction: KeyboardShortcut] = [:]

    /// True while the settings UI records a new shortcut. The global event tap
    /// must ignore key events during that time so the recorder can see them.
    var isCapturingShortcut: Bool = false

    private let defaults: UserDefaults
    private static let initializedKey = "shortcuts.initialized"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // First launch: persist the defaults so storage stays authoritative
        // afterwards (a cleared shortcut must stay cleared across restarts).
        if !defaults.bool(forKey: Self.initializedKey) {
            for action in SnapAction.allCases {
                if let shortcut = action.defaultShortcut,
                   let data = try? JSONEncoder().encode(shortcut) {
                    defaults.set(data, forKey: Self.storageKey(for: action))
                }
            }
            defaults.set(true, forKey: Self.initializedKey)
        }

        var loaded: [SnapAction: KeyboardShortcut] = [:]
        for action in SnapAction.allCases {
            if let data = defaults.data(forKey: Self.storageKey(for: action)),
               let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
                loaded[action] = shortcut
            }
        }
        self.shortcuts = loaded
    }

    var isEnabled: Bool {
        defaults.object(forKey: "keyboardShortcutsEnabled") == nil
            ? true
            : defaults.bool(forKey: "keyboardShortcutsEnabled")
    }

    func shortcut(for action: SnapAction) -> KeyboardShortcut? {
        shortcuts[action]
    }

    /// Assigns a shortcut (or clears it with nil). If another action already
    /// uses the same combination it is taken away from that action, so one
    /// key combo can never trigger two things.
    func setShortcut(_ shortcut: KeyboardShortcut?, for action: SnapAction) {
        if let shortcut = shortcut {
            for (other, existing) in shortcuts where other != action && existing == shortcut {
                shortcuts[other] = nil
                defaults.removeObject(forKey: Self.storageKey(for: other))
            }
            shortcuts[action] = shortcut
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: Self.storageKey(for: action))
            }
        } else {
            shortcuts[action] = nil
            defaults.removeObject(forKey: Self.storageKey(for: action))
        }
    }

    func resetToDefaults() {
        for action in SnapAction.allCases {
            let shortcut = action.defaultShortcut
            shortcuts[action] = shortcut
            if let shortcut = shortcut, let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: Self.storageKey(for: action))
            } else {
                defaults.removeObject(forKey: Self.storageKey(for: action))
            }
        }
    }

    /// Resolves a low-level key event to a configured action, requiring an
    /// exact match of the relevant modifiers.
    func action(matching keyCode: Int64, flags: CGEventFlags) -> SnapAction? {
        guard keyCode >= 0 && keyCode <= Int64(UInt16.max) else { return nil }
        let code = UInt16(keyCode)
        let pressed = KeyboardShortcut.modifierFlags(from: flags)
        return shortcuts.first(where: { $0.value.keyCode == code && $0.value.modifiers == pressed })?.key
    }

    private static func storageKey(for action: SnapAction) -> String {
        "shortcut.\(action.rawValue)"
    }
}
