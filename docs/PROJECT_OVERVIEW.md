# Slide: Premium Trackpad-Centric Window Manager

## 🎯 Vision
**Slide** ist ein minimalistisches, aber kraftvolles Werkzeug für macOS, das die Fensterverwaltung durch intuitive Trackpad-Gesten revolutioniert. Es kombiniert eine futuristische „Vibrant-Glass“-Ästhetik mit butterweichen Animationen und einer präzisen Steuerung.

---

## 🎨 Design-Konzept (Vibrant Glass)
Inspiriert von modernsten UI-Designs (u.a. das Referenzbild), wird Slide folgende Merkmale aufweisen:

*   **Oberfläche:** Ultra-dunkle Glassmorphismus-Effekte (System-Vibrancy).
*   **Farben:** Akzente in Deep Purple, Neon Pink und Electric Blue.
*   **Animationen:** Keine harten Sprünge. Fenster bewegen sich mit einer physikalisch basierten Animation („Spring Animation“), die sich natürlich und flüssig anfühlt.
*   **Feedback:** Dynamische HUD-Icons (Heads-Up Display) folgen dem Mauszeiger während einer Geste, um die Aktion zu visualisieren.

---

## 🛠 Funktionsumfang

### 1. Gesten-Steuerung (Trackpad & Maus)
Die Steuerung ist aktiv, wenn der Mauszeiger in der **Kopfzeile (Titelzeile)** eines Fensters verweilt.

| Geste (2-Finger Slide) | Aktion | Visuelles Feedback (HUD) |
| :--- | :--- | :--- |
| **Nach Links** | Fenster auf linke 50% snappen | Abgerundetes Rechteck (linke Hälfte gefüllt) |
| **Nach Rechts** | Fenster auf rechte 50% snappen | Abgerundetes Rechteck (rechte Hälfte gefüllt) |
| **Nach Oben** | Maximieren (ganze Fenstergröße) | Vollgefülltes abgerundetes Rechteck |
| **Nach Unten** | Fenster minimieren | Pfeil nach unten / Minimieren-Symbol |

### 2. Premium Einstellungsmenü
Ein minimalistisches Menü mit:
*   **Hotkeys:** Anpassbare Tastenkombinationen für jede Aktion.
*   **Sensitivität:** Einstellung der Slide-Empfindlichkeit.
*   **Styling:** Farbwahl für die HUD-Icons und Glow-Effekte.
*   **Lizenzierung:** „Lifetime“ Aktivierungssystem (5€) über einen Lizenz-Key.

---

## 🏗 Technische Roadmap

### Phase 1: Fundament (System-Integration)
*   Einrichtung der Core Graphics Event Taps für Gesten-Tracking.
*   Implementierung der Accessibility-Berechtigungsprüfung (UX-optimiert).
*   Erstellen der App-Struktur als Menüleisten-App (Background Agent).

### Phase 2: Die „Slide“ Engine
*   Algorithmus zur Erkennung der Titelzeile unter dem Cursor.
*   Präzise 2-Finger-Gesten-Interpretation.
*   Entwicklung der **Smooth-Animate Logic** (Berechnung der Übergangs-Frames).

### Phase 3: UI & UX (The WOW-Factor)
*   Erstellung der Glassmorphic-Settings-View in SwiftUI.
*   Implementierung der HUD-Overlay-Ebene über allen Fenstern.
*   Hinzufügen von Micro-Animations bei Gestenstart.

### Phase 4: Monetarisierung & Polishing
*   Lizenzvalidierung (lokal hintelegt).
*   Feinschliff der Performance (CPU-Optimierung).

---

## 💰 Verkaufsmodell
*   **Typ:** Lifetime-Lizenz.
*   **Preis:** ~5€.
*   **Zielgruppe:** Mac-Power-User, die ein minimalistisches Setup bevorzugen.

---

*Dieses Dokument dient als Basis für die Entwicklung von Slide.*
