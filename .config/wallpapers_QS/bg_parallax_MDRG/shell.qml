import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "wallpaper"

// Запуск шпалер:  qs -p /шлях/до/shell.qml
// Структура:      shell.qml + settings.json + assets/ — у корені;
//                 wallpaper/ — шпалери та їхні модулі

ShellRoot {
    id: shell

    // ===== НАЛАШТУВАННЯ (settings.json) =====
    // У файлі можна писати коментарі (// та /* */) і ставити кому після останнього елемента.
    // Якщо після збереження в JSON помилка — шпалери лишаються з попередніми налаштуваннями,
    // а в консоль пишеться, що саме не так (раніше від однієї помилки падало все).
    FileView {
        id: settingsFile
        path: Quickshell.shellPath("settings.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => console.warn("settings.json: не вдалося прочитати файл:", err)
    }

    property var lastGoodCfg: ({})
    readonly property var cfg: {
        const parsed = shell.parseJsonc(settingsFile.text());
        return parsed !== null ? parsed : shell.lastGoodCfg;
    }
    onCfgChanged: lastGoodCfg = cfg

    // JSON з коментарями та зайвими комами -> об'єкт (або null, якщо помилка)
    function parseJsonc(text) {
        const s = String(text || "");
        if (s.trim() === "") return null;

        // 1) прибрати коментарі (але не чіпати те, що всередині "рядків")
        let a = "";
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            if (c === '"') {
                let j = i + 1;
                while (j < s.length && s[j] !== '"') j += (s[j] === "\\") ? 2 : 1;
                a += s.slice(i, j + 1);
                i = j;
            } else if (c === "/" && s[i + 1] === "/") {
                while (i + 1 < s.length && s[i + 1] !== "\n") i++;
            } else if (c === "/" && s[i + 1] === "*") {
                const e = s.indexOf("*/", i + 2);
                i = e < 0 ? s.length : e + 1;
            } else {
                a += c;
            }
        }

        // 2) прибрати кому перед } або ]
        let b = "";
        for (let i = 0; i < a.length; i++) {
            const c = a[i];
            if (c === '"') {
                let j = i + 1;
                while (j < a.length && a[j] !== '"') j += (a[j] === "\\") ? 2 : 1;
                b += a.slice(i, j + 1);
                i = j;
            } else if (c === ",") {
                let j = i + 1;
                while (j < a.length && /\s/.test(a[j])) j++;
                if (a[j] !== "}" && a[j] !== "]") b += c;
            } else {
                b += c;
            }
        }

        try {
            const obj = JSON.parse(b);
            if (obj === null || typeof obj !== "object" || Array.isArray(obj)) {
                console.warn("settings.json: усередині має бути об'єкт { ... }");
                return null;
            }
            return obj;
        } catch (e) {
            console.warn("settings.json: помилка в JSON, лишаю попередні налаштування —", e.message || e);
            return null;
        }
    }

    // секція налаштувань (якщо її нема — порожній об'єкт, а не падіння)
    function section(name) {
        const s = cfg[name];
        return (s !== null && typeof s === "object" && !Array.isArray(s)) ? s : ({});
    }
    // модуль увімкнений, якщо секція є і в ній не "enabled": false
    function isOn(name) {
        const s = cfg[name];
        return s !== null && typeof s === "object" && s.enabled !== false;
    }

    // ===== ПОЗИЦІЯ КУРСОРА (один процес на всі екрани) =====
    // Раніше кожен екран запускав свій нескінченний цикл hyprctl; тепер він один.
    // Якщо hyprctl впаде (наприклад, перезапуск Hyprland) — цикл перезапуститься.
    property real cursorX: 0
    property real cursorY: 0
    readonly property int cursorPollMs: Math.max(5, Number(section("parallax").pollMs) || 33)

    Process {
        id: cursorPoll
        running: true
        command: ["sh", "-c", 'while hyprctl cursorpos; do sleep "$1"; done', "sh", String(shell.cursorPollMs / 1000)]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(",");
                if (p.length < 2) return;
                const x = parseFloat(p[0]);
                const y = parseFloat(p[1]);
                if (isFinite(x) && isFinite(y)) {
                    shell.cursorX = x;
                    shell.cursorY = y;
                }
            }
        }
        onRunningChanged: if (!running) cursorRestart.restart()
    }
    Timer {
        id: cursorRestart
        interval: 2000
        onTriggered: cursorPoll.running = true
    }

    // ===== ВІКНО НА КОЖЕН ЕКРАН =====
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "parallax-wallpaper"
            anchors { top: true; bottom: true; left: true; right: true }
            color: "black"

            // ===== МОДУЛІ ШПАЛЕР =====
            Parallax {
                id: par
                cfg: shell.section("parallax")
                win: panel
                cx: shell.cursorX
                cy: shell.cursorY

                ModuleLoader {
                    isOn: shell.isOn("visualizer")
                    delegate: Visualizer { cfg: shell.section("visualizer"); parallax: par }
                }

                ModuleLoader {
                    isOn: shell.isOn("clock")
                    delegate: Clock { cfg: shell.section("clock"); parallax: par }
                }

                ModuleLoader {
                    isOn: shell.isOn("player")
                    delegate: Player { cfg: shell.section("player"); parallax: par }
                }

                ModuleLoader {
                    isOn: shell.isOn("widgets")
                    delegate: Widgets { cfg: shell.section("widgets"); parallax: par }
                }

                ModuleLoader {
                    isOn: shell.isOn("cursor")
                    delegate: Cursor { cfg: shell.section("cursor"); parallax: par }
                }
            }
        }
    }
}
