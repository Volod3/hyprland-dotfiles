import QtQuick
import Quickshell
import Quickshell.Io

// Місток між QML та bin/qsettings-ctl (python3): усі відповіді — один рядок JSON.
QtObject {
    id: bridge

    property string dir: ""
    readonly property string ctl: dir + "/bin/qsettings-ctl"

    property var values: ({})
    property var defaults: ({})
    property var savedOverrides: ({})
    property var binds: ({ "groups": [], "count": 0 })
    property var state: ({ "theme": {}, "themes": [], "game_on": false })
    property var sysinfo: ({})

    property bool loaded: false
    property bool busy: false
    property string status: "Завантажую стан Hyprland…"
    property bool statusOk: true
    property string lastShot: ""
    property string actionTag: ""


    function parseJson(txt) {
        try { return JSON.parse(String(txt).trim()); } catch (e) { return null; }
    }

    function note(msg, ok) {
        status = msg;
        statusOk = ok !== false;
        clearTimer.restart();
    }

    property Timer clearTimer: Timer {
        interval: 7000
        onTriggered: bridge.status = ""
    }

    // ---------------------------------------------------------- read state --
    property Process optsProc: Process {
        command: [bridge.ctl, "opts"]
        stdout: StdioCollector { id: optsOut; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            var d = bridge.parseJson(optsOut.text);
            if (d && d.ok) {
                bridge.values = d.values || ({});
                bridge.defaults = d.defaults || ({});
                bridge.savedOverrides = d.overrides || ({});
                bridge.loaded = true;
                if (bridge.status === "Завантажую стан Hyprland…")
                    bridge.status = "";
            } else {
                bridge.note("Не вдалося прочитати опції Hyprland (hyprctl)", false);
            }
        }
    }

    property Process bindsProc: Process {
        command: [bridge.ctl, "binds"]
        stdout: StdioCollector { id: bindsOut; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            var d = bridge.parseJson(bindsOut.text);
            if (d && d.ok) {
                bridge.binds = d;
                } else {
                bridge.note("Не вдалося розібрати hyprland.lua", false);
            }
        }
    }

    property Process stateProc: Process {
        command: [bridge.ctl, "state"]
        stdout: StdioCollector { id: stateOut; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            var d = bridge.parseJson(stateOut.text);
            if (d && d.ok) {
                bridge.state = d;
            }
        }
    }

    property Process infoProc: Process {
        command: [bridge.ctl, "sysinfo"]
        stdout: StdioCollector { id: infoOut; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            var d = bridge.parseJson(infoOut.text);
            if (d && d.ok) {
                bridge.sysinfo = d;
            }
        }
    }

    function refreshValues() { if (!optsProc.running) optsProc.running = true; }
    function refreshBinds() { if (!bindsProc.running) bindsProc.running = true; }
    function refreshState() { if (!stateProc.running) stateProc.running = true; }
    function refreshInfo() { if (!infoProc.running) infoProc.running = true; }

    function refreshAll() {
        refreshValues();
        refreshBinds();
        refreshState();
        refreshInfo();
    }

    // ------------------------------------------------------------- actions --
    property Process action: Process {
        command: []
        stdout: StdioCollector { id: actOut; waitForEnd: true }
        onExited: (exitCode, exitStatus) => bridge.handleAction(exitCode, actOut.text)
    }

    function runAction(tag, args, msg) {
        if (action.running) {
            note("Зачекайте: попередня дія ще виконується…", false);
            return false;
        }
        actionTag = tag;
        busy = true;
        if (msg)
            note(msg);
        action.command = [ctl].concat(args);
        action.running = true;
        return true;
    }

    function mergeValues(vals) {
        var merged = {};
        for (var k in values)
            merged[k] = values[k];
        for (var k2 in vals)
            merged[k2] = vals[k2];
        values = merged;
    }

    function pluralResults(results) {
        var total = results.length;
        var good = 0;
        for (var i = 0; i < total; i++)
            if (results[i].verified) good++;
        return good + "/" + total;
    }

    function handleAction(code, text) {
        busy = false;
        var d = parseJson(text);
        if (!d) {
            note("Помилка: бекенд не повернув JSON", false);
            return;
        }

        if (actionTag === "apply" || actionTag === "set" || actionTag === "reset" || actionTag === "restore") {
            if (d.values)
                mergeValues(d.values);
            if (!d.ok && d.error) {
                note("Помилка: " + d.error, false);
                return;
            }
            var results = d.results || [];
            if (results.length > 0) {
                var failed = 0;
                for (var i = 0; i < results.length; i++)
                    if (!results[i].verified) failed++;
                if (failed === 0)
                    note("Застосовано й перевірено getoption: " + pluralResults(results) + " опцій ✓", true);
                else
                    note("Застосовано, але " + failed + " опцій не збіглися з getoption", false);
            } else if (d.key) {
                note(d.key + " = " + d.got + (d.verified ? " · getoption ✓" : " · getoption ✗"), d.verified);
            }
            if (actionTag === "reset")
                note("Скинуто до теми: gaps 5/20, border 2, rounding 10, opacity 0.93/0.87, blur 6/3, анімації ✓", true);
            if (actionTag === "restore")
                note("Відновлено збережені значення з overrides.json ✓", true);
            return;
        }

        if (actionTag === "theme") {
            if (d.theme) {
                var st = {};
                for (var k in state) st[k] = state[k];
                st.theme = d.theme;
                state = st;
            }
            note(d.ok ? "Тему застосовано: " + (d.theme ? d.theme.label : "?") : "Не вдалося змінити тему", d.ok);
            refreshState();
            return;
        }

        if (actionTag === "game") {
            var st2 = {};
            for (var k2 in state) st2[k2] = state[k2];
            st2.game_on = !!d.game_on;
            state = st2;
            note(d.ok ? ("Ігровий режим: " + (d.game_on ? "УВІМКНЕНО" : "вимкнено")) : "Не вдалося перемкнути ігровий режим", d.ok);
            refreshValues();
            refreshState();
            return;
        }

        if (actionTag === "wallpaper") {
            note(d.ok ? "Шпалери теми оновлено" : "Не вдалося оновити шпалери", d.ok);
            refreshState();
            return;
        }

        if (actionTag === "shot") {
            if (d.ok) {
                lastShot = d.path;
                note("Скріншот: " + d.path, true);
            } else {
                note("Скріншот не вдався: " + (d.error || "?"), false);
            }
            return;
        }

        note(d.ok ? "Готово" : ("Помилка (код " + code + ")"), d.ok);
    }

    function applyValues(map) {
        var keys = Object.keys(map || {});
        if (keys.length === 0) {
            note("Немає змін для застосування");
            return;
        }
        runAction("apply", ["apply", JSON.stringify(map)], "Застосовую " + keys.length + " опцій…");
    }

    function resetToTheme() {
        runAction("reset", ["reset"], "Скидаю до типових значень теми…");
    }

    function restoreSaved() {
        runAction("restore", ["restore"], "Відновлюю збережені значення…");
    }

    function setTheme(id) {
        runAction("theme", ["theme", String(id)], "Застосовую тему…");
    }

    function toggleTheme() {
        runAction("theme", ["theme", "toggle"], "Перемикаю тему…");
    }

    function toggleGame() {
        runAction("game", ["game", "toggle"], "Перемикаю ігровий режим…");
    }

    function refreshWallpaper() {
        runAction("wallpaper", ["wallpaper"], "Оновлюю шпалери…");
    }

    function screenshot() {
        runAction("shot", ["shot"], "Роблю скріншот (spectacle)…");
    }
}
