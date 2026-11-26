import Quickshell
import Quickshell.Io
import QtQuick

// ===== CURSOR =====
// Видимість курсора над шпалерами (лише поки він над цим вікном; settings.json -> cursor).
//   "mode": "visible" — як є, завжди видно (за замовчуванням)
//           "idle"    — ховається, якщо не рухається hideAfterMs мс; з'являється, щойно рушив
//           "instant" — ховається майже одразу після зупинки (instantMs, ~60 мс), видно лише в русі
//           "hidden"  — над шпалерами курсора немає взагалі
//   "hideAfterMs": 3000   — для idle
//   "instantMs": 60       — для instant (скільки без руху вважати зупинкою)
//   "debug": true         — писати в консоль зміни стану
//
// Як працює: Qt сам форму курсора на нерухомій миші не перемальовує, тому курсор ховає сам Hyprland:
// hyprctl eval 'hl.config({ cursor = { invisible = true/false } })' (у Hyprland з Lua-конфігом keyword не працює).
// Це глобальна опція, тож вона вмикається ЛИШЕ поки курсор над шпалерами (HoverHandler), а коли курсор
// пішов кудись ще — вимикається назад.
// Команди йдуть по черзі через один процес: раніше два швидкі execDetached (сховати/показати)
// могли виконатися не в тому порядку, і курсор «застрягав» невидимим.
Item {
    id: root

    required property var cfg        // settings.json -> cursor
    required property var parallax   // модуль Parallax (звідти позиція курсора)

    anchors.fill: parent
    z: -1      // ПІД усім: інакше цей на весь екран HoverHandler забирає hover у кнопок плеєра

    readonly property string mode: cfg.mode !== undefined ? cfg.mode : "visible"
    readonly property int hideAfterMs: cfg.hideAfterMs !== undefined ? cfg.hideAfterMs : 3000
    readonly property int instantMs: cfg.instantMs !== undefined ? cfg.instantMs : 60
    readonly property bool debug: cfg.debug === true

    property bool idle: false                         // курсор давно не рухався
    readonly property bool over: hover.hovered        // курсор саме над шпалерами
    readonly property bool hideNow: over && (mode === "hidden" || ((mode === "idle" || mode === "instant") && idle))

    HoverHandler { id: hover }

    // ===== ЧЕРГА КОМАНД ДО HYPRLAND =====
    property bool wanted: false     // який стан потрібен
    property bool applied: false    // який стан уже відправлено

    function command(on) {
        return ["hyprctl", "eval", "hl.config({ cursor = { invisible = " + (on ? "true" : "false") + " } })"];
    }

    Process {
        id: hypr
        onRunningChanged: if (!running) root.flush()
    }

    function flush() {
        if (hypr.running || wanted === applied) return;
        applied = wanted;
        if (debug) console.log("cursor: invisible =", applied, "(mode " + mode + ", over " + over + ")");
        hypr.command = command(applied);
        hypr.running = true;
    }

    onHideNowChanged: { wanted = hideNow; flush(); }
    onOverChanged: if (debug) console.log("cursor: over wallpaper =", over)
    onIdleChanged: if (debug) console.log("cursor: idle =", idle)
    onModeChanged: wake()

    function wake() {
        idle = false;
        if (mode === "idle" || mode === "instant") idleTimer.restart();
        else idleTimer.stop();
    }

    Connections {
        target: root.parallax
        function onCxChanged() { root.wake(); }
        function onCyChanged() { root.wake(); }
    }

    Timer {
        id: idleTimer
        interval: root.mode === "instant" ? root.instantMs : root.hideAfterMs
        onTriggered: root.idle = true
    }

    Component.onCompleted: wake()
    Component.onDestruction: if (wanted || applied) Quickshell.execDetached(command(false))
}
