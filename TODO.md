# TODO

Stand: 2026-07-29. Die Punkte sind grob nach Priorität sortiert.

## 1. Verifizieren (als Erstes!)

Die letzten Änderungen wurden ohne macOS/Xcode geschrieben und noch nicht kompiliert.

- [ ] Projekt in Xcode bauen (Warnings durchsehen)
- [ ] Tests laufen lassen (⌘U) — ShortcutTests, ExclusionTests, AnimationCurveTests
- [ ] Manuell testen:
  - [ ] Animation: fühlt sich das Snappen jetzt flüssig an (auch bei trägen Apps wie Xcode/Word)?
  - [ ] Shortcuts-Tab: Aufnahme, ⎋ = Abbrechen, ⌫ = Löschen, Konflikt-Klau, Reset
  - [ ] Restore (⌥⌘R): Snap → Restore → Fenster ist wieder wie vorher
  - [ ] Ausnahmeliste: App hinzufügen → Gesten und Shortcuts ignorieren deren Fenster
  - [ ] Snap-Vorschau: Overlay blitzt an der richtigen Stelle auf (auch Zweitmonitor)
  - [ ] Launch at Login: an/aus, Zustand nach Neustart der Settings korrekt
  - [ ] Show in Menubar aus + App über Launchpad erneut öffnen → Settings erscheinen
  - [ ] Esc bricht laufende Geste ab, Cancel-Timeout-Slider wirkt

## 2. Bekannte Schwächen / Tech Debt

- [ ] Standard-Shortcuts ⌥⌘←/→ kollidieren mit Safaris Tab-Wechsel — dokumentieren oder Defaults überdenken
- [ ] Gespeicherte Restore-Frames veralten, wenn ein Fenster manuell verschoben wird; Store wird bei >64 Einträgen komplett geleert (grob, aber simpel)
- [ ] `ContentView.swift` ist ungenutztes Template („Hello, world!") — löschen
- [ ] `AccessibilityManager` pollt im Sekundentakt dauerhaft — nach erteilter Berechtigung stoppen
- [ ] Fullscreen-Toggle zeigt kein HUD-Feedback
- [ ] `docs/PROJECT_OVERVIEW.md` erwähnt ein 5€-Lizenzmodell — passt nicht zu MIT/Open Source, entscheiden und Doku angleichen

## 3. Nächste Features

- [ ] Gespeicherte Layouts: komplette Fensteranordnungen als Preset sichern und per Shortcut wiederherstellen
- [ ] Drag-to-Edge-Snapping (Fenster mit der Maus an den Rand ziehen) als Alternative zu Gesten
- [ ] HUD-Styling: Akzentfarbe/Glow konfigurierbar (Vibrant-Glass-Vision)
- [ ] Onboarding: kurzes Gesten-Tutorial nach der Berechtigungsvergabe
- [ ] Vertikal angeordnete Monitore beim „auf nächsten Bildschirm schieben" unterstützen
- [ ] URL-Scheme (`slide://snap/left`) für Raycast/Shortcuts-Automatisierung
- [ ] Lokalisierung (String Catalogs sind schon aktiviert; Deutsch zuerst)

## 4. Projekt / Release

- [ ] CI einrichten (GitHub Actions: build + test auf macOS-Runner)
- [ ] App-Icon gestalten (Asset-Katalog ist noch leer)
- [ ] Release-Prozess: Archive, Notarisierung, GitHub Releases
- [ ] Sparkle für Auto-Updates, sobald es Releases gibt
- [ ] CONTRIBUTING.md, sobald die ersten Contributor anklopfen

---

## Funde aus dem Sichtbarkeits-Check (2026-08-19)

Gemessen ueber die iTunes-Lookup-API, App Store Connect, die GitHub-API und die Sitemap.

### Sichtbarkeit

- [ ] Es gibt kein Release. Wer das Repo findet, kann nichts ausprobieren, sondern
      muesste selbst bauen. Ein erstes Release mit einer signierten App waere der
      groesste Einzelschritt fuer dieses Projekt
- [x] Repo-Topics gesetzt am 19.08.2026 (swift, swiftui, appkit, macos, window-manager,
      trackpad, gestures, menubar, productivity, open-source)
- [x] Auf dem GitHub-Profil gepinnt
- [ ] Stand 19.08.2026: 0 Sterne
