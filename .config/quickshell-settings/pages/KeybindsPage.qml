import QtQuick
import "../components"

// Розділ «Комбінації клавіш» — лише читання hyprland.lua (через бекенд).
Item {
    id: page

    property var bridge
    property string query: ""
    property var rows: []
    property int matchCount: 0

    signal goBack()

    function plural(n) {
        var m10 = n % 10, m100 = n % 100;
        if (m10 === 1 && m100 !== 11) return "комбінація";
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return "комбінації";
        return "комбінацій";
    }

    function rebuild() {
        var q = query.trim().toLowerCase();
        var out = [];
        var groups = (bridge && bridge.binds && bridge.binds.groups) ? bridge.binds.groups : [];
        for (var gi = 0; gi < groups.length; gi++) {
            var g = groups[gi];
            var matched = [];
            for (var ii = 0; ii < g.items.length; ii++) {
                var it = g.items[ii];
                var hay = (it.combo + " " + it.action + " " + g.name).toLowerCase();
                if (q === "" || hay.indexOf(q) >= 0)
                    matched.push(it);
            }
            if (matched.length > 0) {
                out.push({ "type": "group", "name": g.name, "count": matched.length });
                for (var j = 0; j < matched.length; j++) {
                    out.push({
                        "type": "item",
                        "combo": matched[j].combo,
                        "action": matched[j].action,
                        "mouse": matched[j].mouse,
                        "line": matched[j].line
                    });
                }
            }
        }
        rows = out;
        var n = 0;
        for (var r = 0; r < out.length; r++)
            if (out[r].type === "item")
                n++;
        matchCount = n;
    }

    function clearSearch() {
        search.text = "";
        page.query = "";
    }

    function focusSearch() {
        search.forceActiveFocus();
    }

    onQueryChanged: rebuild()
    Component.onCompleted: {
        rebuild();
        if (bridge)
            bridge.refreshBinds();
    }
    Connections {
        target: page.bridge
        function onBindsChanged() { page.rebuild(); }
    }

    // ------------------------------------------------------------- пошук ---
    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 38
        radius: 10
        color: Qt.rgba(0.09, 0.13, 0.25, 0.85)
        border.width: 1
        border.color: search.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : Theme.stroke
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Theme.textMute
            font.family: Theme.mono
            font.pixelSize: 13
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: clearBtn.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 12
            selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
            selectedTextColor: Theme.text
            clip: true

            onTextChanged: page.query = text

            Text {
                visible: search.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Пошук: дія, клавіша, розділ…"
                color: Theme.textMute
                font: search.font
            }
        }

        Item {
            id: clearBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            visible: search.text.length > 0
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: clearMa.containsMouse ? Theme.danger : Theme.textMute
                font.family: Theme.mono
                font.pixelSize: 12
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.clearSearch()
            }
        }
    }

    Text {
        id: countLabel
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.topMargin: 8
        text: page.matchCount + " " + page.plural(page.matchCount)
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 10
    }

    Text {
        anchors.left: parent.left
        anchors.top: searchBox.bottom
        anchors.topMargin: 8
        text: "Джерело: ~/.config/hypr/hyprland.lua · лише перегляд"
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 10
    }

    // ------------------------------------------------------------- таблиця ---
    Item {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: countLabel.bottom
        anchors.topMargin: 8
        height: 22

        Text {
            anchors.left: parent.left
            text: "КОМБІНАЦІЯ"
            color: Theme.textMute
            font.family: Theme.mono
            font.pixelSize: 9
            font.letterSpacing: 1.2
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 250
            text: "ДІЯ"
            color: Theme.textMute
            font.family: Theme.mono
            font.pixelSize: 9
            font.letterSpacing: 1.2
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.strokeSoft
        }
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.bottom: parent.bottom
        clip: true
        model: page.rows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 0
        cacheBuffer: 800

        delegate: Item {
            id: rowItem
            required property int index
            readonly property var m: (page.rows.length > index && page.rows[index] !== undefined)
                ? page.rows[index]
                : ({ "type": "item", "combo": "", "action": "" })
            width: list.width
            height: m.type === "group" ? 32 : 28

            // --- заголовок групи ---
            Item {
                anchors.fill: parent
                visible: rowItem.m.type === "group"

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: rowItem.m.type === "group" ? String(rowItem.m.name).toUpperCase() : ""
                    color: Theme.accent
                    opacity: 0.85
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 250
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: rowItem.m.type === "group" ? String(rowItem.m.count) : ""
                    color: Theme.textMute
                    font.family: Theme.mono
                    font.pixelSize: 9
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.strokeSoft
                    opacity: 0.7
                }
            }

            // --- рядок бінда ---
            Item {
                anchors.fill: parent
                visible: rowItem.m.type === "item"

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -6
                    anchors.rightMargin: -6
                    radius: 7
                    color: Qt.rgba(0.498, 0.863, 1, rowMa.containsMouse ? 0.07 : 0)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Flow {
                    id: comboFlow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 236
                    spacing: 4

                    property var keys: {
                        var combo = (rowItem.m && rowItem.m.combo !== undefined) ? String(rowItem.m.combo) : "";
                        var parts = combo.split(" + ");
                        var out = [];
                        for (var i = 0; i < parts.length; i++)
                            out.push({ "key": parts[i], "mod": i < parts.length - 1 });
                        return out;
                    }

                    Repeater {
                        model: comboFlow.keys

                        Rectangle {
                            id: keyChip
                            required property int index
                            readonly property var k: comboFlow.keys[index] !== undefined
                                ? comboFlow.keys[index] : ({ "key": "", "mod": false })
                            width: keyText.implicitWidth + 12
                            height: 20
                            radius: 6
                            color: k.mod
                                ? Qt.rgba(0.29, 0.55, 1, 0.13)
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                            border.width: 1
                            border.color: k.mod
                                ? Qt.rgba(0.29, 0.55, 1, 0.30)
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: k.key
                                color: k.mod ? Theme.textDim : Theme.accent
                                font.family: Theme.mono
                                font.pixelSize: 10
                                font.weight: k.mod ? Font.Normal : Font.DemiBold
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 250
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: (rowItem.m && rowItem.m.action !== undefined) ? String(rowItem.m.action) : ""
                    color: Theme.text
                    opacity: 0.92
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }

    Text {
        visible: page.rows.length === 0 && (bridge ? bridge.binds.count > 0 : false)
        anchors.centerIn: list
        text: "Нічого не знайдено за запитом «" + page.query + "»"
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 12
    }

    // тонкий скролбар
    Rectangle {
        id: scrollBar
        visible: list.contentHeight > list.height + 1
        anchors.right: list.right
        anchors.rightMargin: 1
        width: 3
        radius: 2
        height: list.contentHeight > 0
            ? Math.max(24, list.height * list.height / list.contentHeight)
            : 0
        y: list.y + (list.contentHeight - list.height > 0
            ? (list.contentY / (list.contentHeight - list.height)) * (list.height - height)
            : 0)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
    }
}
