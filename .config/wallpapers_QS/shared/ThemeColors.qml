import Quickshell
import Quickshell.Io
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Кольори поточної теми — спільний компонент для всіх вікон Quickshell (символьні посилання в теках).
//  Стежить за ~/.config/wallpapers_QS/themes/current.json (пише tools/theme) — перефарбовує наживо.
//  ThemeColors { id: tc }  →  tc.accent, tc.accent2, tc.bg, tc.text, tc.sub, tc.warn, tc.good, tc.onAccent, tc.border
//  tc.a(колір, прозорість) — той самий колір з іншою прозорістю.
// ═══════════════════════════════════════════════════════════════════
Scope {
    id: tc
    FileView {
        id: f
        path: Quickshell.env("HOME") + "/.config/wallpapers_QS/themes/current.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
    }
    readonly property var p: { try { return JSON.parse(f.text()).palette || ({}) } catch (e) { return ({}) } }
    readonly property string preview: { try { return JSON.parse(f.text()).preview || "" } catch (e) { return "" } }
    readonly property string themeId: { try { return JSON.parse(f.text()).id || "sky" } catch (e) { return "sky" } }

    readonly property color bg: p.bg || "#12141c"
    readonly property color accent: p.accent || "#8cc8ff"
    readonly property color accent2: p.accent2 || "#f2b8d4"
    readonly property color text: p.text || "#e8ecf4"
    readonly property color sub: p.sub || "#9aa3b5"
    readonly property color warn: p.warn || "#ff9db0"
    readonly property color good: p.good || "#8ff0c4"
    readonly property color onAccent: p.onAccent || "#0e1420"
    readonly property color border: p.border || "#c9d6ff"
    // похідні
    readonly property color accentSoft: Qt.tint(accent, Qt.rgba(1, 1, 1, 0.35))      // світліший кінець градієнтів
    readonly property color accent2Soft: Qt.tint(accent2, Qt.rgba(accent.r, accent.g, accent.b, 0.35))

    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }
}
