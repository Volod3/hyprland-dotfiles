import QtQuick
import Quickshell
import Quickshell.Io
import "../components"

// Сторінка налаштувань, побудована з опису (schema) — як розділи «Параметрів системи» KDE.
// schema: [ { title, icon, items: [ { type, key, label, hint, ... } ] } ]
//   type "toggle"  — перемикач
//   type "slider"  — from, to, step, suffix, decimals, mul (значення в налаштуваннях = повзунок * mul),
//                    zeroText ("ніколи" тощо — підпис для 0)
//   type "choice"  — options: [ { v, t } ]
//   type "text"    — рядок, застосовується Enter-ом
//   type "button"  — cmd (shell), text
// Значення читаються/пишуться через bin/usettings (переживають перезапуск).
Item {
    id: page

    property var schema: []
    property var vals: ({})
    readonly property string ctl: Quickshell.shellDir + "/bin/usettings"
    property string note: ""

    function val(k, d) { const x = vals[k]; return (x === undefined || x === null) ? d : x }

    function reload() { if (!getP.running) getP.running = true }
    Component.onCompleted: reload()
    onVisibleChanged: if (visible) reload()

    // зміни — в черзі, по одній (повзунок шле значення, коли його відпустили, або через 250 мс)
    property var queue: []
    function setVal(k, v) {
        const nv = Object.assign({}, vals)
        nv[k] = v
        vals = nv
        const q = queue.filter(x => x.k !== k)
        q.push({ k: k, v: v })
        queue = q
        pump()
    }
    function pump() {
        if (setP.running || !queue.length) return
        const it = queue[0]
        queue = queue.slice(1)
        setP.command = [ctl, "set", it.k, String(it.v)]
        setP.running = true
    }

    property var allLayouts: []
    Process {
        id: layP
        running: true
        command: [page.ctl, "layouts"]
        stdout: StdioCollector { onStreamFinished: { try { page.allLayouts = JSON.parse(text) } catch (e) {} } }
    }
    // теми робочого столу (сторінка «Теми»)
    property var themeList: []
    readonly property bool hasThemes: JSON.stringify(schema).indexOf('"themes"') >= 0
    Process {
        id: thP
        running: page.hasThemes
        command: [Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/theme", "list"]
        stdout: StdioCollector { onStreamFinished: { try { page.themeList = JSON.parse(text) } catch (e) {} } }
    }
    Timer { id: thReload; interval: 3500; onTriggered: { thP.running = false; thP.running = true } }

    // монітори (сторінка «Екран» → «Дисплеї»)
    property var monitors: []
    readonly property bool hasDisplays: JSON.stringify(schema).indexOf('"displays"') >= 0
    Process {
        id: monP
        running: page.hasDisplays
        command: [page.ctl, "monitors"]
        stdout: StdioCollector { onStreamFinished: { try { page.monitors = JSON.parse(text) } catch (e) {} } }
    }
    Timer { id: monReload; interval: 900; onTriggered: { monP.running = false; monP.running = true } }
    Process {
        id: monSet
        stdout: StdioCollector {
            onStreamFinished: {
                try { const j = JSON.parse(text); page.note = j.ok ? "Застосовано ✓" : ("Помилка: " + (j.error || "")) } catch (e) {}
                noteTimer.restart(); monReload.restart()
            }
        }
    }
    function setDisplay(name, obj) {
        if (monSet.running) return
        monSet.command = [page.ctl, "display", name, JSON.stringify(obj)]
        monSet.running = true
    }

    // теми курсора (галерея з прев'ю) — тільки якщо на сторінці є такий рядок
    property var cursorThemes: []
    readonly property bool hasCursors: JSON.stringify(schema).indexOf('"cursors"') >= 0
    Process {
        id: curP
        running: page.hasCursors
        command: [page.ctl, "cursors"]
        stdout: StdioCollector { onStreamFinished: { try { page.cursorThemes = JSON.parse(text) } catch (e) {} } }
    }
    function layoutName(code) { const l = allLayouts.find(x => x.code === code); return l ? l.name : code }
    function curLayouts(key) { return String(val(key, "")).split(",").map(x => x.trim()).filter(x => x.length) }
    function setLayouts(key, list) { setVal(key, list.join(", ")) }

    // час «ГГ:ХХ» → зсунути на delta хвилин
    function addMin(t, delta) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(t)) || [0, "20", "00"]
        let mins = (parseInt(m[1]) * 60 + parseInt(m[2]) + delta + 1440) % 1440
        const h = Math.floor(mins / 60), mm = mins % 60
        return (h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm
    }

    Process {
        id: getP
        command: [page.ctl, "get"]
        stdout: StdioCollector {
            onStreamFinished: { try { const j = JSON.parse(text); if (j.ok) page.vals = j.values } catch (e) {} }
        }
    }
    Process {
        id: setP
        stdout: StdioCollector {
            onStreamFinished: {
                try { const j = JSON.parse(text); page.note = j.ok ? "Збережено ✓" : ("Помилка: " + (j.error || "")) } catch (e) {}
                noteTimer.restart()
            }
        }
        // після останньої зміни — перечитати значення (живі підказки: ліміт заряду, відеокарта, профіль)
        onExited: { if (page.queue.length) page.pump(); else page.reload() }
    }
    Timer { id: reloadSoon; interval: 1200; onTriggered: page.reload() }
    Timer { id: noteTimer; interval: 1800; onTriggered: page.note = "" }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: page.note
        color: Theme.ok
        font.pixelSize: 11
        opacity: page.note.length ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        z: 5
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width - 8
            spacing: 18

            Repeater {
                model: page.schema
                Column {
                    id: sec
                    required property var modelData
                    width: col.width
                    spacing: 6

                    SectionTitle { title: sec.modelData.title; icon: sec.modelData.icon || ""; width: parent.width }

                    Rectangle {
                        width: parent.width
                        height: rows.implicitHeight + 12
                        radius: Theme.radius
                        color: Qt.rgba(0.43, 0.62, 1.0, 0.06)
                        border.width: 1
                        border.color: Theme.strokeSoft

                        Column {
                            id: rows
                            x: 14; y: 6
                            width: parent.width - 28

                            Repeater {
                                model: sec.modelData.items
                                Item {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    readonly property var it: modelData
                                    width: rows.width
                                    property bool open: false        // розгорнутий список (розкладки)
                                    height: it.type === "slider" ? 62
                                          : it.type === "layouts" ? 58 + (open ? 250 : 0)
                                          : it.type === "cursors" ? 48 + Math.ceil(Math.max(1, page.cursorThemes.length) / 4) * 98
                                          : it.type === "displays" ? 50 + dispCol.implicitHeight
                                          : it.type === "themes" ? 50 + Math.ceil(Math.max(1, page.themeList.length) / 3) * 196
                                          : it.type === "kbdlight" ? (kbLoader.item && kbLoader.item.present ? 24 + kbLoader.item.height : 44)
                                          : (it.hint || it.hintKey ? 54 : 44)
                                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                    clip: it.type === "layouts"

                                    Rectangle {          // роздільник між рядками
                                        visible: row.index > 0
                                        width: parent.width; height: 1
                                        color: Theme.strokeSoft
                                    }

                                    Column {
                                        visible: row.it.type !== "slider"
                                        y: row.it.type === "layouts" || row.it.type === "cursors" || row.it.type === "displays" || row.it.type === "themes" ? 10 : (row.height - height) / 2
                                        // ширина підпису = усе місце зліва від елемента керування (раніше фіксовані 170/300 px
                                        // обрізали текст трикрапкою, хоча місця вистачало)
                                        width: Math.max(120, parent.width - 16 - (
                                                   row.it.type === "toggle" ? 56
                                                 : row.it.type === "choice" ? choiceRow.width
                                                 : row.it.type === "layouts" ? layoutsRow.width
                                                 : row.it.type === "time" ? timeRow.width
                                                 : row.it.type === "text" ? (row.it.width || 240)
                                                 : row.it.type === "button" ? buttonCtl.width
                                                 : row.it.type === "note" || row.it.type === "cursors" || row.it.type === "displays" || row.it.type === "kbdlight" || row.it.type === "themes" ? 0
                                                 : 300))
                                        spacing: 2
                                        Text { text: row.it.label; color: Theme.text; font.pixelSize: 13; width: parent.width; elide: Text.ElideRight }
                                        Text {
                                            // hintKey — підказка береться зі значень бекенда (живий стан: ліміт заряду, відеокарта…)
                                            readonly property string t: row.it.hintKey ? String(page.val(row.it.hintKey, "")) : (row.it.hint || "")
                                            visible: t.length > 0; text: t
                                            color: Theme.textMute; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight
                                        }
                                    }

                                    // ── перемикач ──
                                    Toggle {
                                        visible: row.it.type === "toggle"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: page.val(row.it.key, false) === true || page.val(row.it.key, 0) === 1
                                        onToggled: (v) => page.setVal(row.it.key, v)
                                    }

                                    // ── вибір ──
                                    Row {
                                        id: choiceRow
                                        visible: row.it.type === "choice"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Repeater {
                                            model: row.it.type === "choice" ? row.it.options : []
                                            Rectangle {
                                                required property var modelData
                                                readonly property bool on: String(page.val(row.it.key, "")).replace("[[EMPTY]]", "") === String(modelData.v)
                                                width: lbl.implicitWidth + 22; height: 28; radius: 9
                                                color: on ? Theme.accent : (cma.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05))
                                                border.width: on ? 0 : 1
                                                border.color: Theme.stroke
                                                Behavior on color { ColorAnimation { duration: 140 } }
                                                Text { id: lbl; anchors.centerIn: parent; text: modelData.t; font.pixelSize: 12; font.bold: on; color: on ? Theme.bg0 : Theme.text }
                                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setVal(row.it.key, modelData.v) }
                                            }
                                        }
                                    }

                                    // ── розкладки: «пігулки» з ✕ + «Додати» зі списком ──
                                    Row {
                                        id: layoutsRow
                                        visible: row.it.type === "layouts"
                                        anchors.right: parent.right
                                        y: 13
                                        spacing: 6
                                        Repeater {
                                            model: row.it.type === "layouts" ? page.curLayouts(row.it.key) : []
                                            Rectangle {
                                                required property string modelData
                                                required property int index
                                                height: 30; radius: 10
                                                width: lt.implicitWidth + 44
                                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                                border.width: 1; border.color: Theme.stroke
                                                Text { id: lt; x: 10; anchors.verticalCenter: parent.verticalCenter; text: (index + 1) + ". " + page.layoutName(modelData); color: Theme.text; font.pixelSize: 12 }
                                                Text {
                                                    anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                                                    text: "✕"; font.pixelSize: 12
                                                    color: xm.containsMouse ? Theme.danger : Theme.textMute
                                                    visible: page.curLayouts(row.it.key).length > 1
                                                    MouseArea { id: xm; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: page.setLayouts(row.it.key, page.curLayouts(row.it.key).filter(x => x !== modelData)) }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            height: 30; radius: 10; width: addT.implicitWidth + 22
                                            color: row.open ? Theme.accent : (am.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05))
                                            border.width: row.open ? 0 : 1; border.color: Theme.stroke
                                            Text { id: addT; anchors.centerIn: parent; text: row.open ? "Готово" : "+ Додати"; font.pixelSize: 12; font.bold: true; color: row.open ? Theme.bg0 : Theme.text }
                                            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { row.open = !row.open; if (row.open) { lsearch.text = ""; lsearch.forceActiveFocus() } } }
                                        }
                                    }
                                    Rectangle {
                                        visible: row.it.type === "layouts" && row.open
                                        x: 0; y: 56
                                        width: parent.width; height: 240; radius: 12
                                        color: Qt.rgba(0, 0, 0, 0.22)
                                        border.width: 1; border.color: Theme.strokeSoft
                                        Rectangle {
                                            x: 8; y: 8; width: parent.width - 16; height: 30; radius: 9
                                            color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: lsearch.activeFocus ? Theme.accent : Theme.stroke
                                            TextInput {
                                                id: lsearch
                                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: Theme.text; font.pixelSize: 13
                                                Text { anchors.verticalCenter: parent.verticalCenter; visible: !lsearch.text.length; text: "Пошук розкладки…"; color: Theme.textMute; font.pixelSize: 13 }
                                            }
                                        }
                                        ListView {
                                            x: 8; y: 44; width: parent.width - 16; height: parent.height - 52
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds
                                            model: page.allLayouts.filter(l => {
                                                const q = lsearch.text.trim().toLowerCase()
                                                return !q.length || l.name.toLowerCase().indexOf(q) >= 0 || l.code.indexOf(q) >= 0
                                            })
                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool has: page.curLayouts(row.it.key).indexOf(modelData.code) >= 0
                                                width: ListView.view.width; height: 32; radius: 8
                                                color: lm.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10) : "transparent"
                                                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: has ? "✓" : ""; color: Theme.accent; font.bold: true }
                                                Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: has ? Theme.accent : Theme.text; font.pixelSize: 13 }
                                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.code; color: Theme.textMute; font.pixelSize: 11 }
                                                MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { if (!has) page.setLayouts(row.it.key, page.curLayouts(row.it.key).concat([modelData.code])) } }
                                            }
                                        }
                                    }

                                    // ── час: ГГ:ХХ зі стрілками / коліщатком + швидкі варіанти ──
                                    Row {
                                        id: timeRow
                                        visible: row.it.type === "time"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Repeater {
                                            model: row.it.type === "time" ? (row.it.presets || []) : []
                                            Rectangle {
                                                required property string modelData
                                                readonly property bool on: String(page.val(row.it.key, "")) === modelData
                                                width: 52; height: 28; radius: 9
                                                color: on ? Theme.accent : (pm.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05))
                                                border.width: on ? 0 : 1; border.color: Theme.stroke
                                                Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 11; color: on ? Theme.bg0 : Theme.textDim }
                                                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setVal(row.it.key, modelData) }
                                            }
                                        }
                                        Rectangle {
                                            width: 112; height: 34; radius: 10
                                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                            border.width: 1; border.color: Theme.accent
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Repeater {
                                                    model: row.it.type === "time" ? [{ part: "h", step: 60 }, { part: "sep" }, { part: "m", step: 5 }] : []
                                                    Item {
                                                        required property var modelData
                                                        width: modelData.part === "sep" ? 8 : 40; height: 30
                                                        readonly property string t: String(page.val(row.it.key, "20:00"))
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.part === "sep" ? ":" : (modelData.part === "h" ? t.split(":")[0] : t.split(":")[1])
                                                            color: Theme.text; font.pixelSize: 16; font.bold: true; font.family: Theme.mono
                                                        }
                                                        MouseArea {
                                                            visible: modelData.part !== "sep"
                                                            anchors.fill: parent
                                                            cursorShape: Qt.SizeVerCursor
                                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                            onWheel: (w) => page.setVal(row.it.key, page.addMin(t, (w.angleDelta.y > 0 ? 1 : -1) * modelData.step))
                                                            onClicked: (m) => page.setVal(row.it.key, page.addMin(t, (m.button === Qt.RightButton ? -1 : 1) * modelData.step))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── текст ──
                                    Rectangle {
                                        visible: row.it.type === "text"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: row.it.width || 240; height: 30; radius: 9
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                                        border.width: ti.activeFocus ? 1 : 1
                                        border.color: ti.activeFocus ? Theme.accent : Theme.stroke
                                        TextInput {
                                            id: ti
                                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: Theme.text; font.pixelSize: 13; selectByMouse: true
                                            text: row.it.type === "text" ? String(page.val(row.it.key, "")) : ""
                                            onAccepted: page.setVal(row.it.key, text)
                                        }
                                    }

                                    // ── кнопка ──
                                    Btn {
                                        id: buttonCtl
                                        visible: row.it.type === "button"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.it.text || "Відкрити"
                                        onClicked: { Quickshell.execDetached(["sh", "-c", row.it.cmd]); reloadSoon.restart() }
                                    }

                                    // ── підсвітка клавіатури (спільний компонент KbdLight.qml, той самий, що в боковій панелі) ──
                                    Loader {
                                        id: kbLoader
                                        active: row.it.type === "kbdlight"          // лише в цьому рядку (не в кожному)
                                        x: 0; y: 12
                                        width: parent.width
                                        sourceComponent: KbdLight {
                                            cAccent: Theme.accent; cText: Theme.text; cSub: Theme.textMute
                                            cTrack: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07); cHover: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13); cOnAccent: Theme.bg0
                                        }
                                    }
                                    Text {
                                        visible: row.it.type === "kbdlight" && !(kbLoader.item && kbLoader.item.present)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "У цього ноутбука немає керованої підсвітки клавіатури"
                                        color: Theme.textMute; font.pixelSize: 12
                                    }

                                    // ── галерея тем ──
                                    Flow {
                                        visible: row.it.type === "themes"
                                        x: 0; y: 46
                                        width: parent.width
                                        spacing: 14
                                        Repeater {
                                            model: row.it.type === "themes" ? page.themeList : []
                                            Item {
                                                id: tcard
                                                required property var modelData
                                                readonly property var t: modelData
                                                width: (parent.width - 28) / 3; height: 182
                                                scale: tma.pressed ? 0.97 : (tma.containsMouse ? 1.03 : 1)
                                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Rectangle {
                                                    id: tthumb
                                                    width: parent.width; height: width * 9 / 16; radius: 14
                                                    color: tcard.t.palette.bg
                                                    clip: true
                                                    border.width: tcard.t.current ? 2 : 1
                                                    border.color: tcard.t.current ? tcard.t.palette.accent : Theme.strokeSoft
                                                    Image {
                                                        anchors.fill: parent; anchors.margins: 2
                                                        source: "file://" + tcard.t.thumb
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        sourceSize.width: 480
                                                    }
                                                    Rectangle {
                                                        visible: tcard.t.current
                                                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                                                        height: 22; radius: 11; width: ctxt.implicitWidth + 16
                                                        color: Qt.rgba(0, 0, 0, 0.55)
                                                        Text { id: ctxt; anchors.centerIn: parent; text: "зараз"; color: "#ffffff"; font.pixelSize: 11 }
                                                    }
                                                }
                                                Row {
                                                    anchors.top: tthumb.bottom; anchors.topMargin: 10
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    spacing: 8
                                                    Text { text: tcard.t.icon + "  " + tcard.t.name; color: tcard.t.current ? Theme.accent : Theme.text
                                                           font.pixelSize: 13; font.bold: tcard.t.current; font.family: Theme.mono; anchors.verticalCenter: parent.verticalCenter }
                                                    Repeater {
                                                        model: [tcard.t.palette.accent, tcard.t.palette.accent2]
                                                        Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: modelData; anchors.verticalCenter: parent.verticalCenter }
                                                    }
                                                }
                                                MouseArea {
                                                    id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/wallpapers_QS/bg_themes/shell.qml", "ipc", "call", "themes", "apply", tcard.t.id])
                                                        thReload.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── дисплеї: картка на кожен монітор ──
                                    Column {
                                        id: dispCol
                                        visible: row.it.type === "displays"
                                        x: 0; y: 46
                                        width: parent.width
                                        spacing: 10
                                        Repeater {
                                            model: row.it.type === "displays" ? page.monitors : []
                                            Rectangle {
                                                id: mcard
                                                required property var modelData
                                                readonly property var m: modelData
                                                width: dispCol.width
                                                height: mc.implicitHeight + 24
                                                radius: 14
                                                color: Qt.rgba(0, 0, 0, 0.2)
                                                border.width: 1; border.color: Theme.strokeSoft
                                                component Chip: Rectangle {
                                                    id: ch
                                                    property string t: ""
                                                    property bool on: false
                                                    signal pick()
                                                    width: ctx.implicitWidth + 20; height: 28; radius: 9
                                                    color: on ? Theme.accent : (chm.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05))
                                                    border.width: on ? 0 : 1; border.color: Theme.stroke
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Text { id: ctx; anchors.centerIn: parent; text: ch.t; font.pixelSize: 12; font.bold: ch.on; color: ch.on ? Theme.bg0 : Theme.text }
                                                    MouseArea { id: chm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.pick() }
                                                }
                                                Column {
                                                    id: mc
                                                    x: 14; y: 12; width: parent.width - 28
                                                    spacing: 10
                                                    Item {
                                                        width: parent.width; height: 36
                                                        Column {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            Text { text: (m.builtin ? "󰌢  Вбудований екран" : "󰍹  " + m.name) + (m.enabled ? "" : "  · вимкнено"); color: Theme.text; font.pixelSize: 14; font.bold: true }
                                                            Text { text: m.desc + "  ·  " + m.w + "×" + m.h; color: Theme.textMute; font.pixelSize: 11 }
                                                        }
                                                        Toggle {
                                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                                            visible: page.monitors.length > 1
                                                            checked: m.enabled
                                                            onToggled: (v) => page.setDisplay(m.name, { enabled: v })
                                                        }
                                                    }
                                                    Flow {
                                                        width: parent.width; spacing: 6
                                                        visible: m.enabled
                                                        Text { text: "Режим"; color: Theme.textDim; font.pixelSize: 12; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                                                        Repeater {
                                                            model: m.modes.slice(0, 8)
                                                            Chip { required property string modelData; t: modelData.replace("@", " · ") + " Гц"; on: modelData === m.mode
                                                                   onPick: page.setDisplay(m.name, { mode: modelData }) }
                                                        }
                                                    }
                                                    Flow {
                                                        width: parent.width; spacing: 6
                                                        visible: m.enabled
                                                        Text { text: "Масштаб"; color: Theme.textDim; font.pixelSize: 12; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                                                        Repeater {
                                                            model: [1, 1.25, 1.5, 1.75, 2]
                                                            Chip { required property var modelData; t: Math.round(modelData * 100) + "%"; on: Math.abs(m.scale - modelData) < 0.01
                                                                   onPick: page.setDisplay(m.name, { scale: modelData }) }
                                                        }
                                                    }
                                                    Flow {
                                                        width: parent.width; spacing: 6
                                                        visible: m.enabled && page.monitors.length > 1 && !m.builtin
                                                        Text { text: "Розташування"; color: Theme.textDim; font.pixelSize: 12; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                                                        Repeater {
                                                            model: [ { v: "auto-right", t: "Праворуч" }, { v: "auto-left", t: "Ліворуч" }, { v: "auto-up", t: "Зверху" },
                                                                     { v: "auto-down", t: "Знизу" }, { v: "mirror", t: "Дзеркало" } ]
                                                            Chip { required property var modelData; t: modelData.t; on: m.position === modelData.v
                                                                   onPick: page.setDisplay(m.name, { position: modelData.v }) }
                                                        }
                                                    }
                                                    Flow {
                                                        width: parent.width; spacing: 6
                                                        visible: m.enabled
                                                        Text { text: "Поворот"; color: Theme.textDim; font.pixelSize: 12; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                                                        Repeater {
                                                            model: [ { v: 0, t: "Звичайно" }, { v: 1, t: "90°" }, { v: 2, t: "180°" }, { v: 3, t: "270°" } ]
                                                            Chip { required property var modelData; t: modelData.t; on: m.transform === modelData.v
                                                                   onPick: page.setDisplay(m.name, { transform: modelData.v }) }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            visible: page.monitors.length < 2
                                            width: parent.width; wrapMode: Text.Wrap
                                            text: "Підключи другий монітор (HDMI / USB-C) — тут з'являться його налаштування: увімкнення, роздільність, розташування, дзеркало."
                                            color: Theme.textMute; font.pixelSize: 11
                                        }
                                    }

                                    // ── галерея тем курсора ──
                                    Flow {
                                        visible: row.it.type === "cursors"
                                        x: 0; y: 42
                                        width: parent.width
                                        spacing: 10
                                        Repeater {
                                            model: row.it.type === "cursors" ? page.cursorThemes : []
                                            Rectangle {
                                                required property var modelData
                                                readonly property bool on: String(page.val(row.it.key, "")) === modelData.id
                                                width: (parent.width - 30) / 4; height: 88; radius: 14
                                                color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : (tm.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.09) : Qt.rgba(0, 0, 0, 0.22))
                                                border.width: on ? 2 : 1
                                                border.color: on ? Theme.accent : Theme.strokeSoft
                                                scale: tm.pressed ? 0.97 : 1
                                                Behavior on color { ColorAnimation { duration: 140 } }
                                                Behavior on scale { NumberAnimation { duration: 120 } }
                                                Image {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    y: 10
                                                    width: 176 * 0.8; height: 44 * 0.8
                                                    source: "file://" + modelData.preview
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    cache: false
                                                }
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                                    width: parent.width - 12
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    text: modelData.name
                                                    color: parent.on ? Theme.accent : Theme.text
                                                    font.pixelSize: 12; font.bold: parent.on
                                                }
                                                MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: page.setVal(row.it.key, modelData.id) }
                                            }
                                        }
                                    }

                                    // ── повзунок ──
                                    SettingSlider {
                                        visible: row.it.type === "slider"
                                        width: parent.width
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: row.it.label
                                        hint: row.it.hint || ""
                                        from: row.it.from !== undefined ? row.it.from : 0
                                        to: row.it.to !== undefined ? row.it.to : 100
                                        step: row.it.step || 1
                                        decimals: row.it.decimals || 0
                                        suffix: row.it.suffix || ""
                                        zeroText: row.it.zeroText || ""
                                        readonly property real mul: row.it.mul || 1
                                        value: Number(page.val(row.it.key, 0)) / mul
                                        onMoved: (v) => { sendT.v = v; sendT.restart() }
                                        onReleased: { if (sendT.running) { sendT.stop(); page.setVal(row.it.key, sendT.v * mul) } }
                                        Timer { id: sendT; property real v: 0; interval: 250; onTriggered: page.setVal(row.it.key, v * parent.mul) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
