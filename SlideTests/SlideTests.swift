//
//  SlideTests.swift
//  SlideTests
//
//  Created by Louis Saks on 06.03.26.
//

import Testing
import AppKit
@testable import Slide

@MainActor
struct ShortcutTests {

    private func freshDefaults() -> UserDefaults {
        let suiteName = "SlideTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func shortcutCodableRoundtrip() throws {
        let shortcut = KeyboardShortcut(keyCode: 123, modifiers: [.option, .command])
        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(KeyboardShortcut.self, from: data)
        #expect(decoded == shortcut)
    }

    @Test func shortcutIgnoresIrrelevantModifiers() {
        // Arrow keys carry Fn/NumericPad flags that must not affect matching
        let a = KeyboardShortcut(keyCode: 123, modifiers: [.option, .command, .numericPad, .function])
        let b = KeyboardShortcut(keyCode: 123, modifiers: [.option, .command])
        #expect(a == b)
    }

    @Test func displayStringContainsModifiersAndKey() {
        let shortcut = KeyboardShortcut(keyCode: 123, modifiers: [.option, .command])
        #expect(shortcut.displayString == "⌥⌘←")
    }

    @Test func defaultsAreSeededAndMatch() {
        let manager = ShortcutManager(defaults: freshDefaults())

        #expect(manager.shortcut(for: .leftHalf) == KeyboardShortcut(keyCode: 123, modifiers: [.option, .command]))
        #expect(manager.shortcut(for: .topLeftQuarter) == nil)

        let flags: CGEventFlags = [.maskAlternate, .maskCommand]
        #expect(manager.action(matching: 123, flags: flags) == .leftHalf)
        #expect(manager.action(matching: 124, flags: flags) == .rightHalf)
        // Wrong modifiers must not match
        #expect(manager.action(matching: 123, flags: [.maskCommand]) == nil)
        // Extra modifiers must not match either
        #expect(manager.action(matching: 123, flags: [.maskAlternate, .maskCommand, .maskShift]) == nil)
    }

    @Test func customShortcutPersistsAcrossInstances() {
        let defaults = freshDefaults()
        let custom = KeyboardShortcut(keyCode: 8, modifiers: [.control, .command]) // ⌃⌘C

        let manager = ShortcutManager(defaults: defaults)
        manager.setShortcut(custom, for: .center)

        let reloaded = ShortcutManager(defaults: defaults)
        #expect(reloaded.shortcut(for: .center) == custom)
    }

    @Test func clearingAShortcutPersists() {
        let defaults = freshDefaults()

        let manager = ShortcutManager(defaults: defaults)
        manager.setShortcut(nil, for: .leftHalf)

        let reloaded = ShortcutManager(defaults: defaults)
        #expect(reloaded.shortcut(for: .leftHalf) == nil)
    }

    @Test func assigningTakesShortcutFromOtherAction() {
        let manager = ShortcutManager(defaults: freshDefaults())
        let leftHalfShortcut = manager.shortcut(for: .leftHalf)!

        manager.setShortcut(leftHalfShortcut, for: .leftThird)

        #expect(manager.shortcut(for: .leftThird) == leftHalfShortcut)
        #expect(manager.shortcut(for: .leftHalf) == nil)
    }

    @Test func resetRestoresDefaults() {
        let manager = ShortcutManager(defaults: freshDefaults())
        manager.setShortcut(nil, for: .leftHalf)
        manager.setShortcut(KeyboardShortcut(keyCode: 8, modifiers: [.command]), for: .rightThird)

        manager.resetToDefaults()

        #expect(manager.shortcut(for: .leftHalf) == SnapAction.leftHalf.defaultShortcut)
        #expect(manager.shortcut(for: .rightThird) == nil)
    }

    @Test func everyActionMapsToADirection() {
        // Compile-time exhaustiveness plus a sanity check that titles exist
        for action in SnapAction.allCases {
            #expect(!action.title.isEmpty)
            _ = action.direction
        }
    }

    @Test func restoreHasDefaultShortcut() {
        let manager = ShortcutManager(defaults: freshDefaults())
        #expect(manager.shortcut(for: .restore) == KeyboardShortcut(keyCode: 15, modifiers: [.option, .command]))
        #expect(manager.action(matching: 15, flags: [.maskAlternate, .maskCommand]) == .restore)
    }
}

@MainActor
struct ExclusionTests {

    private func freshDefaults() -> UserDefaults {
        let suiteName = "SlideTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func startsEmpty() {
        let manager = ExclusionManager(defaults: freshDefaults())
        #expect(manager.excludedBundleIDs.isEmpty)
        #expect(!manager.isExcluded(bundleID: "com.example.app"))
        #expect(!manager.isExcluded(bundleID: nil))
    }

    @Test func addAndRemovePersist() {
        let defaults = freshDefaults()

        let manager = ExclusionManager(defaults: defaults)
        manager.add(bundleID: "com.example.game")
        manager.add(bundleID: "com.example.game") // duplicate is ignored
        manager.add(bundleID: "   ") // blank is ignored

        #expect(manager.excludedBundleIDs == ["com.example.game"])
        #expect(manager.isExcluded(bundleID: "com.example.game"))

        let reloaded = ExclusionManager(defaults: defaults)
        #expect(reloaded.isExcluded(bundleID: "com.example.game"))

        reloaded.remove(bundleID: "com.example.game")
        #expect(!reloaded.isExcluded(bundleID: "com.example.game"))

        let reloadedAgain = ExclusionManager(defaults: defaults)
        #expect(reloadedAgain.excludedBundleIDs.isEmpty)
    }

    @Test func listIsSorted() {
        let manager = ExclusionManager(defaults: freshDefaults())
        manager.add(bundleID: "com.zeta.app")
        manager.add(bundleID: "com.alpha.app")
        #expect(manager.excludedBundleIDs == ["com.alpha.app", "com.zeta.app"])
    }
}

@MainActor
struct AnimationCurveTests {

    @Test func springCurveHitsEndpoints() {
        #expect(abs(SmoothAnimator.springProgress(0)) < 0.0001)
        #expect(abs(SmoothAnimator.springProgress(1) - 1.0) < 0.0001)
    }

    @Test func springCurveIsMonotonicAndBounded() {
        var previous = -0.0001
        for step in 0...100 {
            let t = Double(step) / 100.0
            let p = SmoothAnimator.springProgress(t)
            #expect(p >= previous)
            #expect(p >= 0.0 && p <= 1.0001)
            previous = p
        }
    }

    @Test func springCurveClampsOutOfRangeInput() {
        #expect(SmoothAnimator.springProgress(-1) == SmoothAnimator.springProgress(0))
        #expect(SmoothAnimator.springProgress(2) == SmoothAnimator.springProgress(1))
    }
}
