import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// ═══════════════════════════════════════════════════════════════════════════
//  Азур · Лаунчер застосунків (Quickshell)
//  Відкриття/закриття: ~/.config/theme-switch/bin/app-menu   (toggle)
//  Esc — закрити · ↑↓ — вибір · Enter — запуск · клік — запуск
//  Список програм: apps.py (парсер .desktop + пошук файлів іконок)
// ═══════════════════════════════════════════════════════════════════════════
PanelWindow {
    id: win

    // ── палітра ────────────────────────────────────────────────────────────
    readonly property color cBg0: "#0b1020"
    readonly property color cBg1: "#131829"
    readonly property color cPanel: "#16203c"
    readonly property color cAccent: "#7fdcff"
    readonly property color cText: "#d6ecff"
    readonly property color cDim: "#8aa6c8"
    readonly property string ff: "JetBrainsMono Nerd Font Mono"
    // «Режим з бару» — меню виїжджає з-під панелі (як меню Пуск у KDE Plasma)
    readonly property bool barMode: (Quickshell.env("APP_MENU_MODE") || "") === "bar"
    readonly property string base: Qt.resolvedUrl(".").toString()
        .replace(/^file:\/\//, "").replace(/\/$/, "")

    // ── шар ────────────────────────────────────────────────────────────────
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true

    // ── стан ───────────────────────────────────────────────────────────────
    property var apps: []
    property var filtered: []
    property string query: ""
    property int sel: 0
    property int cat: 0   // 0=усі, 1=програми, 2=система, 3=утиліти
    property real rev: 0
    property bool closing: false
    property bool loading: true
    property string errorText: ""

    // початковий запит: env QS_LAUNCHER_QUERY (з app-menu --query) або аргумент CLI
    readonly property string startQuery: {
        var e = "";
        try { e = Quickshell.env("QS_LAUNCHER_QUERY") || ""; } catch (x) { e = ""; }
        if (e.length > 0)
            return e;
        var a = Qt.application.arguments || [];
        for (var i = 0; i < a.length; i++)
            if (a[i] === "--query" || a[i] === "-q")
                return a[i + 1] || "";
        return "";
    }

    // ── завантаження списку ────────────────────────────────────────────────
    Process {
        id: appProc
        command: ["python3", win.base + "/apps.py"]
        running: true

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: win.loadApps(this.text)
        }
    }

    function loadApps(txt) {
        var data = null;
        try { data = JSON.parse(txt); } catch (e) { data = null; }
        if (!data || !data.length) {
            win.loading = false;
            win.errorText = "не вдалось отримати список програм";
            console.log("launcher: ПОМИЛКА розбору JSON, байт=" + String(txt).length);
            return;
        }
        win.apps = data;
        win.loading = false;
        win.errorText = "";
        console.log("launcher: завантажено " + data.length + " застосунків, з іконками "
                    + data.filter(function (a) { return !!a.icon; }).length);
        win.query = win.startQuery;
        win.refresh();
    }

    // ── фільтрація ─────────────────────────────────────────────────────────
    function score(app, q) {
        var n = String(app.name || "").toLowerCase();
        if (n.startsWith(q)) return 0;
        if (n.indexOf(q) >= 0) return 1;
        var nat = String(app.name_native || "").toLowerCase();
        if (nat.indexOf(q) >= 0) return 2;
        var kw = (app.keywords || []).join(" ").toLowerCase();
        if (kw.indexOf(q) >= 0) return 3;
        var cm = String(app.comment || "").toLowerCase();
        if (cm.indexOf(q) >= 0) return 4;
        var ex = String(app.exec || "").toLowerCase();
        if (ex.indexOf(q) >= 0) return 5;
        var cat = (app.categories || []).join(" ").toLowerCase();
        if (cat.indexOf(q) >= 0) return 6;
        return -1;
    }

    function catMatch(app) {
        if (win.cat === 0) return true;
        var c = (app.categories || []).join(" ").toLowerCase();
        if (win.cat === 2) return c.indexOf("system") >= 0 || c.indexOf("settings") >= 0;
        if (win.cat === 3) return c.indexOf("utility") >= 0 || c.indexOf("accessories") >= 0;
        return c.indexOf("system") < 0 && c.indexOf("settings") < 0;
    }

    function refresh() {
        var q = win.query.trim().toLowerCase();
        var src = win.apps.filter(win.catMatch);
        if (q === "") {
            win.filtered = src;
        } else {
            var scored = [];
            for (var i = 0; i < src.length; i++) {
                var s = win.score(src[i], q);
                if (s >= 0)
                    scored.push({ s: s, a: src[i] });
            }
            scored.sort(function (x, y) {
                if (x.s !== y.s) return x.s - y.s;
                return x.a.name.toLowerCase() < y.a.name.toLowerCase() ? -1 : 1;
            });
            var out = [];
            for (var j = 0; j < scored.length; j++)
                out.push(scored[j].a);
            win.filtered = out;
        }
        if (win.sel >= win.filtered.length)
            win.sel = Math.max(0, win.filtered.length - 1);
        console.log("filter: \"" + q + "\"  " + win.apps.length + " -> " + win.filtered.length);
    }

    onQueryChanged: {
        win.refresh();
        win.sel = 0;
        list.positionViewAtBeginning();
    }

    // ── навігація / запуск ────────────────────────────────────────────────
    function move(d) {
        if (win.filtered.length === 0) return;
        var n = win.sel + d;
        if (n < 0) n = win.filtered.length - 1;
        if (n >= win.filtered.length) n = 0;
        win.sel = n;
        list.positionViewAtIndex(n, ListView.Contain);
    }

    function launchCurrent() {
        if (win.filtered.length > 0)
            win.launch(win.filtered[win.sel]);
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function launch(app) {
        if (!app || !app.exec) return;
        var full = app.terminal ? ("kitty -e sh -c " + win.shq(app.exec)) : String(app.exec);
        console.log("launch: " + full);
        // setsid -f: повністю відв'язуємо дочірній процес, щоб лаунчер його не тримав
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", full]);
        win.closePanel();
    }

    function closePanel() {
        if (win.closing) return;
        win.closing = true;
        win.rev = 0;
        quitTimer.start();
    }

    // ── анімації ──────────────────────────────────────────────────────────
    Behavior on rev {
        NumberAnimation {
            duration: win.closing ? 150 : 300
            easing.type: win.closing ? Easing.InCubic : Easing.OutCubic
        }
    }
    Timer { id: quitTimer; interval: 180; onTriggered: Qt.exit(0) }
    Component.onCompleted: Qt.callLater(function () { win.rev = 1; })

    // коли шар знову показується — повертаємо курсор у поле пошуку
    onVisibleChanged: if (win.visible && field) field.forceActiveFocus()

    // ── затемнення екрана + клік поза панеллю ─────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#04070f"
        opacity: 0.52 * win.rev
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.closePanel()
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  СКЛЯНА ПАНЕЛЬ
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        id: panel
        width: win.barMode ? 460 : 720
        height: win.barMode ? 556 : 520
        x: win.barMode ? 12 : (parent.width - width) / 2
        y: win.barMode ? 44 : 84
        opacity: win.rev
        scale: 0.94 + 0.06 * win.rev
        transform: Translate { y: (win.barMode ? -26 : 18) * (1 - win.rev) }

        // м'яка тінь
        MultiEffect {
            source: bg
            anchors.fill: bg
            z: -1
            shadowEnabled: true
            shadowColor: "#f0050a18"
            shadowBlur: 1.0
            blurMax: 72
            shadowVerticalOffset: 18
            autoPaddingEnabled: true
        }

        // скло
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 22
            border.width: 1
            border.color: "#3a7fdcff"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f6273c63" }
                GradientStop { position: 0.42; color: "#f41a2444" }
                GradientStop { position: 1.0; color: "#f70e1730" }
            }

            // верхній відблиск
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 0.5; color: "#8ac9f4ff" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }

            // акцентна смуга зліва
            Rectangle {
                width: 2
                height: parent.height - 120
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 0.35; color: "#997fdcff" }
                    GradientStop { position: 0.65; color: "#997fdcff" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }
        }

        // поглинач кліків по фону панелі
        MouseArea { anchors.fill: parent }

        // ── ПОШУК ─────────────────────────────────────────────────────────
        Rectangle {
            id: searchWrap
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            height: 48
            radius: 15
            color: field.activeFocus ? "#1c2749" : "#131c33"
            border.width: 1
            border.color: field.activeFocus ? "#667fdcff" : "#267fdcff"

            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            // верхній відблиск (gradient на самому Rectangle перебив би color)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                height: 1
                radius: 1
                color: "#14ffffff"
                opacity: field.activeFocus ? 1.0 : 0.55
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"
                color: field.activeFocus ? win.cAccent : "#5f7ba6"
                font.family: win.ff
                font.pixelSize: 15
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            TextField {
                id: field
                anchors.left: searchGlyph.right
                anchors.leftMargin: 12
                anchors.right: clearBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 12

                placeholderText: "Пошук програм…"
                placeholderTextColor: "#5d779c"
                color: win.cText
                selectionColor: "#557fdcff"
                selectedTextColor: "#08202f"
                font.family: win.ff
                font.pixelSize: 13
                verticalAlignment: TextInput.AlignVCenter
                background: Item {}
                padding: 0
                focus: true
                inputMethodHints: Qt.ImhNoPredictiveText

                onTextChanged: win.query = text
                onAccepted: win.launchCurrent()

                Keys.onDownPressed: (e) => { win.move(1); e.accepted = true; }
                Keys.onUpPressed: (e) => { win.move(-1); e.accepted = true; }
                Keys.onEscapePressed: (e) => { win.closePanel(); e.accepted = true; }
                Keys.onTabPressed: (e) => { win.move(e.modifiers & Qt.ShiftModifier ? -1 : 1); e.accepted = true; }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_PageDown) { win.move(6); e.accepted = true; }
                    else if (e.key === Qt.Key_PageUp) { win.move(-6); e.accepted = true; }
                }
            }

            // кнопка очищення
            Rectangle {
                id: clearBtn
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 8
                visible: field.text.length > 0
                color: clearMa.containsMouse ? "#2a3a63" : "#00000000"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    color: clearMa.containsMouse ? win.cText : "#7f9ec2"
                    font.family: win.ff
                    font.pixelSize: 11
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { field.text = ""; field.forceActiveFocus(); }
                }
            }
        }

        // ── розділювач ────────────────────────────────────────────────────
        Rectangle {
            id: divider
            anchors.top: searchWrap.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.5; color: "#337fdcff" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }

        // ── СПИСОК ────────────────────────────────────────────────────────

        // ── БІЧНЕ МЕНЮ КАТЕГОРІЙ (як у KDE Plasma) ────────────────────────
        Column {
            id: side
            anchors.top: listWrap.top
            anchors.left: parent.left
            anchors.leftMargin: 14
            width: 116
            spacing: 6

            Repeater {
                model: [
                    { t: "Усі",       i: "󰀻", c: 0 },
                    { t: "Програми",  i: "󰀻", c: 1 },
                    { t: "Система",   i: "󰒓", c: 2 },
                    { t: "Утиліти",   i: "󰃣", c: 3 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: side.width
                    height: 36
                    radius: 12
                    color: win.cat === modelData.c ? "#3a7fdcff" : (hma.containsMouse ? "#16ffffff" : "transparent")
                    border.width: win.cat === modelData.c ? 1 : 0
                    border.color: "#5a7fdcff"
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.i + "  " + modelData.t
                        color: win.cat === modelData.c ? "#eaf7ff" : "#9db4d2"
                        font.family: win.ff
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: hma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { win.cat = modelData.c; win.refresh(); win.sel = 0 }
                    }
                }
            }
        }

        // ── ФУТЕР: швидкі дії ─────────────────────────────────────────────
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            Repeater {
                model: [
                    { t: "󰒓  Налаштування", c: "/home/voltimeter/.config/theme-switch/bin/hypr-settings" },
                    { t: "󰕾  Панель",      c: "/home/voltimeter/.config/theme-switch/bin/cc" },
                    { t: "󰐥  Вихід",        c: "hyprctl dispatch exit" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - 16) / 3
                    height: 36
                    radius: 12
                    color: fma.containsMouse ? "#26ffffff" : "#12ffffff"
                    border.width: 1
                    border.color: "#1effffff"
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        color: "#cfe4fb"
                        font.family: win.ff
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: fma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            win.closing = true
                            Quickshell.execDetached(["setsid", "-f", "sh", "-c", modelData.c])
                            quitTimer.start()
                        }
                    }
                }
            }
        }

        Item {
            id: listWrap
            anchors.top: divider.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            // список займає всю висоту до футера швидких дій
            height: (win.barMode ? 412 : 380)
            anchors.leftMargin: 138
            anchors.rightMargin: 12
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.rightMargin: 8
                model: win.filtered
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400
                reuseItems: true

                ScrollBar.vertical: ScrollBar {
                    id: sb
                    policy: ScrollBar.AsNeeded
                    width: 12
                    interactive: true
                    minimumSize: 0.12

                    contentItem: Rectangle {
                        implicitWidth: 8
                        radius: 4
                        color: sb.pressed ? win.cAccent : "#6f7fdcff"
                        opacity: sb.pressed ? 1.0 : (sb.hovered ? 0.85 : 0.55)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    background: Rectangle {
                        implicitWidth: 8
                        x: (sb.width - width) / 2
                        radius: 4
                        color: "#14ffffff"
                        opacity: 0.5
                    }
                }

                delegate: AppRow {
                    required property var modelData
                    required property int index

                    width: list.width
                    app: modelData
                    query: win.query
                    current: index === win.sel
                    cAccent: win.cAccent
                    cText: win.cText
                    cDim: win.cDim
                    ff: win.ff
                    onActivated: win.launch(modelData)
                    onHovered: win.sel = index
                }
            }

            // стан завантаження
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: win.loading
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf110"
                    color: win.cAccent
                    font.family: win.ff
                    font.pixelSize: 22
                    opacity: 0.8
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Завантаження списку програм…"
                    color: win.cDim
                    font.family: win.ff
                    font.pixelSize: 11
                }
            }

            // нічого не знайдено
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !win.loading && win.filtered.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf059"
                    color: "#4f6f96"
                    font.family: win.ff
                    font.pixelSize: 26
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.errorText.length > 0 ? win.errorText : "Нічого не знайдено"
                    color: win.cDim
                    font.family: win.ff
                    font.pixelSize: 12
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.query.length > 0
                    text: "«" + win.query + "»"
                    color: "#4f6f96"
                    font.family: win.ff
                    font.pixelSize: 10
                }
            }
        }

        // ── ФУТЕР ─────────────────────────────────────────────────────────
    }

    // ── українське відмінювання: 1 програма, 2 програми, 5 програм ────────
    function plural(n) {
        var m10 = n % 10, m100 = n % 100;
        if (m10 === 1 && m100 !== 11) return "програма";
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return "програми";
        return "програм";
    }
}
