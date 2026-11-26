import QtQuick

// Пошук і запуск програм (відкривається разом з боковою панеллю).
// Друкуй — фільтр; ↑ ↓ — вибір; Enter — запустити; ☆ — додати в «Обране» панелі; Esc — закрити.
Rectangle {
    id: box

    required property var theme
    property var apps: []                 // з tools/apps.py
    property var favIds: []
    signal launch(var app)
    signal toggleFav(string id)
    signal closeRequested()

    radius: 28
    color: theme.bg
    border.width: 1
    border.color: theme.border

    // легкий рожевий відтінок унизу (як у панелі)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.6; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(box.theme.accent2.r, box.theme.accent2.g, box.theme.accent2.b, 0.14) }
        }
    }

    function reset() {
        search.text = ""
        list.currentIndex = 0
        list.positionViewAtBeginning()
        search.forceActiveFocus()
    }

    // назва важливіша за опис: спершу ті, що починаються з запиту, потім — що містять його в назві
    readonly property var filtered: {
        const q = search.text.trim().toLowerCase()
        if (!q.length) return apps
        const words = q.split(/\s+/)
        const scored = []
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            const name = (a.name + " " + (a.name_native || "")).toLowerCase()
            const hay = name + " " + (a.comment || "").toLowerCase() + " "
                + (a.keywords || []).join(" ").toLowerCase() + " " + (a.exec || "").toLowerCase()
                + " " + (a.categories || []).join(" ").toLowerCase()
            if (!words.every(w => hay.indexOf(w) >= 0)) continue
            const s = name.startsWith(q) ? 0 : (name.indexOf(q) >= 0 ? 1 : 2)
            scored.push({ s: s, a: a })
        }
        scored.sort((x, y) => x.s - y.s)
        return scored.map(x => x.a)
    }

    // ── поле пошуку ──
    Rectangle {
        id: field
        x: 14; y: 14
        width: parent.width - 28
        height: 46
        radius: 16
        color: box.theme.tile
        border.width: search.activeFocus ? 2 : 1
        border.color: search.activeFocus ? box.theme.accent : box.theme.border

        Text {
            id: lens
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            font.family: box.theme.iconFont
            font.pixelSize: 18
            color: box.theme.subtext
        }
        TextInput {
            id: search
            anchors.left: lens.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: box.theme.text
            font.family: box.theme.textFont
            font.pixelSize: 15
            selectByMouse: true
            focus: true
            onTextChanged: list.currentIndex = 0
            Keys.onEscapePressed: box.closeRequested()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onTabPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: if (box.filtered.length) box.launch(box.filtered[Math.max(0, list.currentIndex)])
            Keys.onEnterPressed: if (box.filtered.length) box.launch(box.filtered[Math.max(0, list.currentIndex)])
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text.length
                text: "Пошук програм…"
                font: search.font
                color: box.theme.subtext
            }
        }
    }

    Text {
        id: countLabel
        x: 22; y: field.y + field.height + 10
        text: search.text.length ? ("Знайдено: " + box.filtered.length) : ("Усі програми · " + box.apps.length)
        font.family: box.theme.textFont
        font.pixelSize: 11
        color: box.theme.subtext
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 22
        y: countLabel.y
        text: "☆ — в обране панелі"
        font.family: box.theme.textFont
        font.pixelSize: 11
        color: box.theme.subtext
    }

    // ── літери для швидкого гортання (лише коли нічого не шукаєш) ──
    readonly property var letters: {
        if (search.text.length) return []
        const out = []
        const seen = ({})
        for (let i = 0; i < filtered.length; i++) {
            let c = (filtered[i].name || "?").charAt(0).toUpperCase()
            if (!/[A-ZА-ЯІЇЄҐ]/.test(c)) c = "#"
            if (!seen[c]) { seen[c] = true; out.push({ l: c, i: i }) }
        }
        return out
    }
    property string railLetter: ""

    // ── список ──
    ListView {
        id: list
        x: 8
        y: countLabel.y + countLabel.height + 8
        width: parent.width - 16 - (box.letters.length > 1 ? 24 : 0)
        height: parent.height - y - 12
        clip: true
        model: box.filtered
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        currentIndex: 0

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isFav: box.favIds.indexOf(modelData.id) >= 0
            readonly property bool current: ListView.isCurrentItem
            width: list.width
            height: 54
            radius: 16
            // вибір клавіатурою — яскравіше, наведення мишею — ледь помітно (і не прокручує список)
            color: current ? box.theme.tileHover : (rma.containsMouse ? box.theme.tile : "transparent")

            MouseArea {
                id: rma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: box.launch(row.modelData)
            }

            Image {
                id: ic
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                sourceSize: Qt.size(64, 64)
                source: row.modelData.icon ? "file://" + row.modelData.icon : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Text {
                visible: ic.status !== Image.Ready
                anchors.centerIn: ic
                text: row.modelData.name.charAt(0)
                font.pixelSize: 18; font.bold: true
                color: box.theme.accent
            }
            Column {
                x: 56
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 56 - 48
                spacing: 1
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name
                    font.family: box.theme.textFont
                    font.pixelSize: 14
                    font.bold: true
                    color: box.theme.text
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    elide: Text.ElideRight
                    text: row.modelData.comment || ""
                    font.family: box.theme.textFont
                    font.pixelSize: 11
                    color: box.theme.subtext
                }
            }
            // ☆ / ★ — в обране
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: 12
                color: sma.containsMouse ? box.theme.tile : "transparent"
                visible: row.isFav || rma.containsMouse || sma.containsMouse
                Text {
                    anchors.centerIn: parent
                    text: row.isFav ? "★" : "☆"
                    font.pixelSize: 18
                    color: row.isFav ? box.theme.accent : box.theme.subtext
                }
                MouseArea {
                    id: sma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: box.toggleFav(row.modelData.id)
                }
            }
        }
    }

    Item {
        id: rail
        visible: box.letters.length > 1
        x: parent.width - 30
        y: list.y
        width: 24
        height: list.height
        readonly property real step: height / Math.max(1, box.letters.length)

        Rectangle { anchors.fill: parent; radius: 12; color: railMa.pressed || railMa.containsMouse ? box.theme.tile : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } } }
        Repeater {
            model: box.letters
            Text {
                required property var modelData
                required property int index
                x: 0; width: rail.width
                y: index * rail.step + (rail.step - height) / 2
                horizontalAlignment: Text.AlignHCenter
                text: modelData.l
                font.pixelSize: Math.min(11, rail.step * 0.8)
                font.bold: box.railLetter === modelData.l
                color: box.railLetter === modelData.l ? box.theme.accent : box.theme.subtext
            }
        }
        MouseArea {
            id: railMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function jump(my) {
                const k = Math.max(0, Math.min(box.letters.length - 1, Math.floor(my / rail.step)))
                const it = box.letters[k]
                box.railLetter = it.l
                list.positionViewAtIndex(it.i, ListView.Beginning)
                list.currentIndex = it.i
            }
            onPressed: (m) => jump(m.y)
            onPositionChanged: (m) => { if (pressed) jump(m.y) }
            onReleased: hideLetter.restart()
        }
        Timer { id: hideLetter; interval: 700; onTriggered: box.railLetter = "" }
    }

    // велика буква посередині під час гортання
    Rectangle {
        anchors.centerIn: list
        width: 76; height: 76; radius: 22
        color: box.theme.accent
        opacity: box.railLetter.length ? 0.92 : 0
        scale: box.railLetter.length ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Text { anchors.centerIn: parent; text: box.railLetter; font.pixelSize: 38; font.bold: true; color: box.theme.onAccent }
    }
}
