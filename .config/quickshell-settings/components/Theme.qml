pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Палітра застосунку — береться з поточної теми робочого столу (~/.config/wallpapers_QS/themes/current.json,
// пише tools/theme; перемикання — Pause або сторінка «Теми»). Змінюється наживо.
QtObject {
    id: th
    property FileView _f: FileView {
        path: Quickshell.env("HOME") + "/.config/wallpapers_QS/themes/current.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
    }
    readonly property var _p: { try { return JSON.parse(_f.text()).palette || ({}) } catch (e) { return ({}) } }
    readonly property color _bg: _p.bg || "#12141c"
    readonly property string name: { try { return JSON.parse(_f.text()).name || "" } catch (e) { return "" } }

    readonly property color bg0: Qt.darker(_bg, 1.25)
    readonly property color bg1: _bg
    readonly property color panel: Qt.tint(_bg, Qt.rgba(1, 1, 1, 0.05))
    readonly property color panelHi: Qt.tint(_bg, Qt.rgba(1, 1, 1, 0.09))
    readonly property color panelSoft: Qt.tint(_bg, Qt.rgba(1, 1, 1, 0.07))
    readonly property color accent: _p.accent || "#8cc8ff"
    readonly property color accent2: _p.accent2 || "#f2b8d4"
    readonly property color accentDeep: Qt.darker(accent, 1.9)
    readonly property color text: _p.text || "#e8ecf4"
    readonly property color textDim: Qt.tint(_p.sub || "#a7b0c2", Qt.rgba(1, 1, 1, 0.12))
    readonly property color textMute: _p.sub || "#717a8e"
    readonly property color danger: _p.warn || "#ff7096"
    readonly property color ok: _p.good || "#7ef0c0"
    readonly property color stroke: Qt.tint(_bg, Qt.rgba(1, 1, 1, 0.14))
    readonly property color strokeSoft: Qt.tint(_bg, Qt.rgba(1, 1, 1, 0.09))

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int radius: 18
    readonly property int radiusSm: 10
}
