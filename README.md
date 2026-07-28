# Slide

Slide is an experimental macOS window manager built around trackpad gestures, smooth window animations, and a lightweight menu bar experience.

The goal is simple: make common window actions feel faster and more natural on Mac by letting you control windows directly from the title bar area with gestures.

## Status

This project is currently an early open source prototype.

What already exists:
- A macOS menu bar app built with SwiftUI and AppKit
- Accessibility permission onboarding
- Gesture monitoring and window detection
- Basic snapping, minimize, close, and fullscreen interactions
- A HUD overlay for gesture feedback
- A settings window with an initial UI structure

What is still in progress:
- Reliability across more macOS apps and window types
- Better gesture tuning and edge-case handling
- More tests
- Packaging, release process, and contributor workflow

## Why Slide

Slide is aimed at people who prefer a native-feeling macOS workflow but want faster window management without a heavy tiling setup.

Core ideas:
- Trackpad-first interaction
- Smooth, polished motion instead of abrupt snapping
- Minimal UI with a menu bar footprint
- Native macOS technologies where possible

## Current Features

- Menu bar app entry point
- Accessibility permission detection and onboarding flow
- Detection of the window under the cursor
- Title bar targeting for gesture-triggered actions
- Window snapping for left, right, and maximize layouts
- Minimize and close actions
- Fullscreen toggle support
- On-screen HUD feedback near the pointer
- Early settings UI for behavior and snapping controls
- Customizable global keyboard shortcuts for all snap actions (halves, quarters, thirds, maximize, minimize, center, restore), configurable in Settings → Shortcuts
- Smooth, time-based window animations with a spring easing curve
- Restore a window to the size and position it had before its first snap (default ⌥⌘R)
- Snap preview overlay that briefly highlights the target area
- Per-app exclusion list so games and drawing apps are left alone
- Launch at Login and a hideable menu bar icon
- Esc (or resting for the configurable timeout) cancels a running gesture

## Tech Stack

- Swift
- SwiftUI
- AppKit
- macOS Accessibility APIs
- Xcode project-based app structure

## Project Structure

```text
Slide/          Main app source
SlideTests/     Unit tests
SlideUITests/   UI tests
docs/           Project notes and planning docs
references/     External reference material kept outside the main app source
```

## Getting Started

### Requirements

- macOS
- Xcode

### Run locally

1. Open `Slide.xcodeproj` in Xcode.
2. Build and run the `Slide` scheme.
3. Grant Accessibility permission when prompted.
4. Use the menu bar app to open onboarding or settings.

## Contributing

Contributions are welcome, and contributors are actively wanted.

If you want to help, good areas to contribute include:
- Gesture recognition improvements
- Better window snapping logic
- Accessibility API robustness
- macOS UX polish
- Test coverage
- Documentation
- Issue triage and bug reproduction

If you contribute, please:
1. Fork the repository and create a focused branch.
2. Keep changes small and scoped.
3. Include a clear description of the problem and solution.
4. Add or update tests where it makes sense.
5. Open a pull request with screenshots or recordings for UI behavior changes.

If you are not ready to code yet, opening issues with reproducible bugs, device details, and macOS version information is also very helpful.

## Contributors Wanted

This repository is open to collaborators.

Especially useful would be contributors with experience in:
- macOS accessibility APIs
- Gesture handling on macOS
- SwiftUI/AppKit integration
- Animation and interaction design
- Open source maintenance

If you want to become an early contributor, open an issue or submit a pull request.

## Roadmap

- Improve gesture stability and reduce false positives
- Expand snapping layouts and multi-display handling
- Add more tests around gesture and window behavior
- Clean up settings architecture and persistence
- Prepare the project for public releases

## Notes

- Slide relies on macOS Accessibility permissions to inspect and control windows.
- Behavior may vary depending on the target application and macOS version.
- This project is currently best understood as an experimental foundation rather than a finished product.

## License

Slide is released under the [MIT License](LICENSE).
