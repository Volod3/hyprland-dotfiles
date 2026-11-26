import QtQuick

// ── Рядок застосунку: іконка + назва (з підсвіткою) + підзаголовок ────────
Rectangle {
    id: row

    property var app: null
    property string query: ""
    property bool current: false
    property color cAccent: "#7fdcff"
    property color cText: "#d6ecff"
    property color cDim: "#8aa6c8"
    property string ff: "JetBrainsMono Nerd Font Mono"

    signal activated()
    signal hovered()

    implicitHeight: 62
    radius: 14
    color: current ? "#267fdcff" : (ma.containsMouse ? "#12cfe8ff" : "#00000000")
    border.width: current ? 1 : 0
    border.color: current ? "#667fdcff" : "#00000000"

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // ── іконка ────────────────────────────────────────────────────────
    Rectangle {
        id: icoBox
        width: 44
        height: 44
        radius: 12
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        color: row.current ? "#1fffffff" : "#0fffffff"
        border.width: 1
        border.color: row.current ? "#4d7fdcff" : "#1a9ac8ff"

        Image {
            id: ico
            anchors.fill: parent
            anchors.margins: 5
            source: (row.app && row.app.icon) ? "file://" + row.app.icon : ""
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
            cache: true
            visible: status === Image.Ready
        }

        // фолбек, якщо іконки немає
        Text {
            anchors.centerIn: parent
            visible: ico.status !== Image.Ready
            text: "\uf059"
            color: row.current ? row.cAccent : "#4f6f96"
            font.family: row.ff
            font.pixelSize: 18
        }
    }

    // ── текст ─────────────────────────────────────────────────────────
    Column {
        id: txt
        anchors.left: icoBox.right
        anchors.leftMargin: 12
        anchors.right: badge.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            textFormat: Text.StyledText
            text: row.markup(row.app ? row.app.name : "")
            color: row.current ? "#eaf9ff" : row.cText
            font.family: row.ff
            font.pixelSize: 13
            font.weight: row.current ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: row.subtitle()
            color: row.current ? "#a7c9e8" : row.cDim
            font.family: row.ff
            font.pixelSize: 10
            elide: Text.ElideRight
            opacity: 0.9
        }
    }

    // ── бейдж праворуч ────────────────────────────────────────────────
    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: badgeTxt.implicitWidth + 16
        height: 20
        radius: 7
        visible: row.app && (row.current || row.app.terminal === true)
        color: row.current ? "#337fdcff" : "#12ffffff"
        border.width: 1
        border.color: row.current ? "#557fdcff" : "#00000000"

        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: row.app && row.app.terminal ? "термінал" : "↵"
            color: row.current ? "#bfeaff" : "#426080"
            font.family: row.ff
            font.pixelSize: 9
            font.letterSpacing: 0.6
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
        onEntered: row.hovered()
    }

    // ── хелпери ───────────────────────────────────────────────────────
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function markup(text) {
        var t = String(text === undefined || text === null ? "" : text);
        var q = String(row.query || "").trim();
        if (!q)
            return esc(t);
        var i = t.toLowerCase().indexOf(q.toLowerCase());
        if (i < 0)
            return esc(t);
        return esc(t.slice(0, i))
             + "<font color=\"" + row.cAccent + "\"><b>" + esc(t.slice(i, i + q.length)) + "</b></font>"
             + esc(t.slice(i + q.length));
    }

    function subtitle() {
        if (!row.app)
            return "";
        var parts = [];
        if (row.app.comment)
            parts.push(row.app.comment);
        else if (row.app.categories && row.app.categories.length)
            parts.push(row.app.categories.slice(0, 2).join(" · "));
        if (row.app.name_native && row.app.name_native !== row.app.name)
            parts.push(row.app.name_native);
        return parts.join("   ·   ");
    }
}
