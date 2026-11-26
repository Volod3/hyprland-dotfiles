import QtQuick
import QtQuick.Effects

// ═══════════════════════════════════════════════════════════════════
//  SDDM «Glass» — екран входу в стилі нашого екрана блокування (bg_lock):
//  розмиті шпалери з повільним рухом, годинник, скляна картка з аватаркою.
//  Перевірка без виходу з сесії:
//      sddm-greeter-qt6 --test-mode --theme ~/.config/wallpapers_QS/sddm-theme/glass
//  Встановлена копія: /usr/share/sddm/themes/glass (оновити — скопіювати туди цю теку).
// ═══════════════════════════════════════════════════════════════════
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0b0d13"

    // ── палітра (як у всьому робочому столі: темне скло + блакитний + рожевий) ──
    readonly property color cText: "#e8ecf4"
    readonly property color cSub: "#9aa3b5"
    readonly property color cMute: "#717a8e"
    readonly property color cAccent: "#8cc8ff"
    readonly property color cPink: "#f2b8d4"
    readonly property color cWarn: "#f2a0b4"
    readonly property color cGlass: Qt.rgba(0.07, 0.078, 0.106, 0.62)
    readonly property color cStroke: Qt.rgba(0.79, 0.84, 1, 0.16)
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    FontLoader { id: comfortaa; source: "assets/Comfortaa.ttf" }
    readonly property string titleFont: comfortaa.status === FontLoader.Ready ? comfortaa.name : "Noto Sans"

    // ── стан ──
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    // ролі моделей читаємо через приховані Repeater-и (так надійніше, ніж за номерами ролей)
    Repeater { id: usersRep; model: userModel; Item { required property string name; required property string realName; required property string icon } }
    Repeater {
        id: sessRep; model: sessionModel
        Item { required property string name }
        onItemAdded: (i, it) => {
            // якщо попередньої сесії нема — за замовчуванням Hyprland
            if (sessionModel.lastIndex < 0 && String(it.name).toLowerCase() === "hyprland") root.sessionIndex = i
        }
    }
    readonly property var curUser: usersRep.count > userIndex ? usersRep.itemAt(userIndex) : null
    property string userName: curUser ? curUser.name : (userModel.lastUser || "")
    property string realName: curUser && curUser.realName ? curUser.realName : userName
    property string sessionName: sessRep.count > sessionIndex && sessRep.itemAt(sessionIndex) ? sessRep.itemAt(sessionIndex).name : "Сесія"
    property bool busy: false
    property string msg: ""
    property bool sessionsOpen: false
    property bool ready: false
    property string confirm: ""            // "reboot" / "poweroff" — друге натискання підтверджує

    function login() {
        if (busy) return
        busy = true
        msg = ""
        sddm.login(userName, field.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.msg = "Неправильний пароль"
            field.text = ""
            shake.restart()
            field.forceActiveFocus()
        }
        function onLoginSucceeded() { root.leaving = true; leave.start() }
    }

    Component.onCompleted: { ready = true; field.forceActiveFocus() }
    property bool leaving: false
    // поле пароля одразу в фокусі — без кліків (вікно greeter-а отримує фокус трохи пізніше)
    Timer { interval: 150; repeat: true; running: true; property int n: 0
            onTriggered: { if (!root.sessionsOpen) field.forceActiveFocus(); if (++n >= 10) stop() } }
    // якщо фокус загубився — будь-яка клавіша все одно йде в поле пароля
    focus: true
    Keys.onPressed: (e) => {
        if (field.activeFocus || root.busy) return
        field.forceActiveFocus()
        if (e.text.length && e.key !== Qt.Key_Escape && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) {
            field.insert(field.cursorPosition, e.text); e.accepted = true
        }
    }
    Timer { id: confirmReset; interval: 3500; onTriggered: root.confirm = "" }

    // ═══════════ фон: шпалери, розмиття, повільний «наїзд камери» ═══════════
    Item {
        id: bgWrap
        anchors.fill: parent
        Image {
            id: bg
            anchors.centerIn: parent
            width: parent.width * 1.08
            height: parent.height * 1.08
            source: "assets/background.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            visible: false
            sourceSize.width: 1920
        }
        MultiEffect {
            id: bgFx
            anchors.fill: bg
            source: bg
            blurEnabled: true
            blur: root.ready ? 0.85 : 0.0
            blurMax: 64
            saturation: 0.05
            brightness: -0.10
            Behavior on blur { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
            // повільний рух: ледь помітно «пливе» туди-сюди
            transform: [
                Scale { id: zoom; origin.x: bgFx.width / 2; origin.y: bgFx.height / 2; xScale: 1.0; yScale: xScale }
            ]
            SequentialAnimation {
                running: true; loops: Animation.Infinite
                NumberAnimation { target: zoom; property: "xScale"; from: 1.0; to: 1.05; duration: 24000; easing.type: Easing.InOutSine }
                NumberAnimation { target: zoom; property: "xScale"; from: 1.05; to: 1.0; duration: 24000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on x {
                running: true; loops: Animation.Infinite
                NumberAnimation { from: -40; to: 40; duration: 31000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 40; to: -40; duration: 31000; easing.type: Easing.InOutSine }
            }
        }
        // темне скло зверху + ледь рожевий низ
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.06, 0.09, 0.50) }
                GradientStop { position: 0.65; color: Qt.rgba(0.05, 0.06, 0.09, 0.58) }
                GradientStop { position: 1.0; color: Qt.rgba(0.17, 0.09, 0.15, 0.72) }
            }
        }
        // м'які світлові плями, що повільно дихають (розмиті — без різких країв)
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; autoPaddingEnabled: false }
            Rectangle {
                width: 760; height: 760; radius: 380
                x: -260; y: parent.height - 460
                color: root.cPink; opacity: 0.10
                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.16; duration: 7000; easing.type: Easing.InOutSine } NumberAnimation { to: 0.07; duration: 7000; easing.type: Easing.InOutSine } }
            }
            Rectangle {
                width: 820; height: 820; radius: 410
                x: parent.width - 520; y: -460
                color: root.cAccent; opacity: 0.08
                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.14; duration: 9000; easing.type: Easing.InOutSine } NumberAnimation { to: 0.05; duration: 9000; easing.type: Easing.InOutSine } }
            }
        }
    }

    // плавна поява всього вмісту
    Item {
        id: content
        anchors.fill: parent
        opacity: root.leaving ? 0 : (root.ready ? 1 : 0)
        scale: root.leaving ? 1.04 : 1
        Behavior on opacity { NumberAnimation { duration: root.leaving ? 380 : 900; easing.type: root.leaving ? Easing.InCubic : Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.InCubic } }

        // ═══════════ годинник ═══════════
        Column {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.13 + (root.ready ? 0 : -30)
            Behavior on y { NumberAnimation { duration: 1100; easing.type: Easing.OutCubic } }
            spacing: 2

            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clockCol.now = new Date() }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clockCol.now, "HH:mm")
                color: root.cText
                font.family: root.titleFont; font.weight: Font.Bold
                font.pixelSize: 150
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.45); shadowBlur: 0.8; shadowVerticalOffset: 4 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const d = ["неділя", "понеділок", "вівторок", "середа", "четвер", "пʼятниця", "субота"]
                    const m = ["січня", "лютого", "березня", "квітня", "травня", "червня", "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"]
                    const n = clockCol.now
                    return d[n.getDay()] + ", " + n.getDate() + " " + m[n.getMonth()]
                }
                color: "#c4cad8"
                font.family: root.titleFont
                font.pixelSize: 24
            }
        }

        // ═══════════ картка входу ═══════════
        Item {
            id: cardWrap
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: shakeX
            property real shakeX: 0
            y: parent.height * 0.50 + (root.ready ? 0 : 60)
            Behavior on y { NumberAnimation { duration: 1000; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            width: 400; height: 290

            SequentialAnimation {
                id: shake
                NumberAnimation { target: cardWrap; property: "shakeX"; to: -16; duration: 50 }
                NumberAnimation { target: cardWrap; property: "shakeX"; to: 14; duration: 60 }
                NumberAnimation { target: cardWrap; property: "shakeX"; to: -9; duration: 60 }
                NumberAnimation { target: cardWrap; property: "shakeX"; to: 5; duration: 60 }
                NumberAnimation { target: cardWrap; property: "shakeX"; to: 0; duration: 70 }
            }

            // тінь
            Rectangle {
                anchors.fill: card; anchors.margins: -2
                radius: card.radius + 2
                color: "transparent"
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowBlur: 1.0; shadowVerticalOffset: 10 }
                Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(0, 0, 0, 0.01) }
            }
            Rectangle {
                id: card
                anchors.fill: parent
                radius: 30
                color: root.cGlass
                border.width: 1
                border.color: root.cStroke
                Rectangle {          // рожевий відблиск угорі
                    anchors.top: parent.top; anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(0.95, 0.72, 0.83, 0.75) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {          // ледь рожевий низ
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.55; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0.95, 0.72, 0.83, 0.08) }
                    }
                }
            }

            // ── аватар з кільцем, що світиться ──
            Item {
                id: av
                anchors.horizontalCenter: parent.horizontalCenter
                y: -52
                width: 104; height: 104

                Rectangle {            // м'яке сяйво
                    anchors.centerIn: parent
                    width: parent.width + 26; height: width; radius: width / 2
                    color: root.busy ? root.cPink : root.cAccent
                    opacity: 0.16
                    Behavior on color { ColorAnimation { duration: 300 } }
                    SequentialAnimation on scale { loops: Animation.Infinite; NumberAnimation { to: 1.08; duration: 1800; easing.type: Easing.InOutSine } NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine } }
                }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: Qt.rgba(0.07, 0.078, 0.106, 0.92)
                    border.width: 3
                    border.color: root.busy ? root.cPink : root.cAccent
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                }
                // крутиться під час входу
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: "transparent"
                    visible: root.busy
                    Rectangle { width: 12; height: 12; radius: 6; color: root.cText; x: parent.width / 2 - 6; y: -4 }
                    RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                AnimatedImage {
                    id: avImg
                    anchors.fill: parent; anchors.margins: 6
                    source: "assets/avatar.gif"
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    playing: true
                }
                Rectangle { id: avMask; anchors.fill: avImg; radius: width / 2; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: avImg; source: avImg; maskEnabled: true; maskSource: avMask }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 66
                width: parent.width - 56
                spacing: 14

                // ім'я (стрілки — якщо користувачів кілька)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Text {
                        visible: userModel.count > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅁"; font.family: root.iconFont; font.pixelSize: 18; color: ul.containsMouse ? root.cAccent : root.cMute
                        MouseArea { id: ul; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.userIndex = (root.userIndex + userModel.count - 1) % userModel.count }
                    }
                    Text {
                        text: root.realName
                        color: root.cText; font.family: root.titleFont; font.pixelSize: 22; font.weight: Font.Bold
                    }
                    Text {
                        visible: userModel.count > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅂"; font.family: root.iconFont; font.pixelSize: 18; color: ur.containsMouse ? root.cAccent : root.cMute
                        MouseArea { id: ur; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.userIndex = (root.userIndex + 1) % userModel.count }
                    }
                }

                // поле пароля
                Rectangle {
                    id: pwBox
                    width: parent.width; height: 52; radius: 18
                    color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.08 : 0.05)
                    border.width: field.activeFocus ? 2 : 1
                    border.color: root.msg.length && !root.busy ? root.cWarn : (field.activeFocus ? root.cAccent : root.cStroke)
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        x: 17; anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"; font.family: root.iconFont; font.pixelSize: 18
                        color: field.activeFocus ? root.cAccent : root.cSub
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 48; anchors.rightMargin: 92
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: eye.shown ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        color: root.cText
                        font.pixelSize: 18
                        enabled: !root.busy
                        focus: true
                        clip: true
                        selectionColor: root.cAccent
                        onAccepted: root.login()
                        onTextChanged: if (text.length) root.msg = ""
                        Keys.onEscapePressed: text = ""
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !field.text.length
                            text: root.busy ? "Входжу…" : "Пароль"
                            color: root.cMute; font.pixelSize: 16
                        }
                    }
                    // показати пароль
                    Text {
                        id: eye
                        property bool shown: false
                        anchors.right: go.left; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: shown ? "󰈈" : "󰈉"; font.family: root.iconFont; font.pixelSize: 18
                        color: em.containsMouse ? root.cAccent : root.cMute
                        visible: field.text.length > 0
                        MouseArea { id: em; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eye.shown = !eye.shown }
                    }
                    // кнопка «увійти»
                    Rectangle {
                        id: go
                        anchors.right: parent.right; anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40; radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: gm.containsMouse ? "#a6d4ff" : root.cAccent }
                            GradientStop { position: 1.0; color: gm.containsMouse ? "#f6c8dc" : "#d9c2e8" }
                        }
                        opacity: field.text.length ? 1 : 0.35
                        scale: gm.pressed ? 0.9 : (gm.containsMouse ? 1.06 : 1)
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: root.busy ? "󰔟" : "󰁔"; font.family: root.iconFont; font.pixelSize: 20; color: "#0e1420" }
                        MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                    }
                }

                // підказка / помилка / Caps Lock
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.msg.length ? root.msg
                         : (keyboard.capsLock ? "󰪛  Увімкнено Caps Lock" : "Введи пароль і натисни Enter")
                    color: root.msg.length || keyboard.capsLock ? root.cWarn : root.cSub
                    font.family: root.iconFont.length && keyboard.capsLock ? root.iconFont : root.titleFont
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // сесія
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 32; radius: 16
                    width: sessText.implicitWidth + 40
                    color: sm.containsMouse || root.sessionsOpen ? Qt.rgba(0.55, 0.78, 1, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1; border.color: root.cStroke
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: sessText
                        anchors.centerIn: parent
                        text: "󰍹  " + root.sessionName + "  " + (root.sessionsOpen ? "󰅃" : "󰅀")
                        font.family: root.iconFont; font.pixelSize: 13; color: root.cText
                    }
                    MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sessionsOpen = !root.sessionsOpen }
                }
            }
        }

        // список сесій (над карткою, з анімацією)
        Rectangle {
            id: sessList
            anchors.horizontalCenter: parent.horizontalCenter
            y: cardWrap.y + cardWrap.height + 12
            width: 300
            height: root.sessionsOpen ? sessCol.implicitHeight + 16 : 0
            radius: 18
            clip: true
            color: root.cGlass
            border.width: root.sessionsOpen ? 1 : 0; border.color: root.cStroke
            opacity: root.sessionsOpen ? 1 : 0
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Column {
                id: sessCol
                x: 8; y: 8; width: parent.width - 16
                spacing: 2
                Repeater {
                    model: sessionModel
                    Rectangle {
                        required property int index
                        required property string name
                        width: sessCol.width; height: 36; radius: 12
                        color: index === root.sessionIndex ? Qt.rgba(0.55, 0.78, 1, 0.18) : (sim.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: name; color: index === root.sessionIndex ? root.cAccent : root.cText; font.pixelSize: 14 }
                        MouseArea { id: sim; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.sessionIndex = index; root.sessionsOpen = false; field.forceActiveFocus() } }
                    }
                }
            }
        }

        // ═══════════ низ: розкладка, батарея-заглушка, живлення ═══════════
        Row {
            anchors.left: parent.left; anchors.leftMargin: 34
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            spacing: 10
            // розкладка (клік — наступна)
            Rectangle {
                visible: keyboard.layouts && keyboard.layouts.length > 0
                height: 40; radius: 14
                width: kbT.implicitWidth + 28
                color: km.containsMouse ? Qt.rgba(0.55, 0.78, 1, 0.16) : Qt.rgba(0.07, 0.078, 0.106, 0.55)
                border.width: 1; border.color: root.cStroke
                Text {
                    id: kbT; anchors.centerIn: parent
                    text: "󰌌  " + (keyboard.layouts && keyboard.layouts.length ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : "")
                    font.family: root.iconFont; font.pixelSize: 14; color: root.cText
                }
                MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length }
            }
            Rectangle {
                height: 40; radius: 14
                width: nlT.implicitWidth + 28
                color: Qt.rgba(0.07, 0.078, 0.106, 0.55)
                border.width: 1; border.color: root.cStroke
                Text {
                    id: nlT; anchors.centerIn: parent
                    text: (keyboard.numLock ? "󰎠" : "󰎡") + "  Num"
                    font.family: root.iconFont; font.pixelSize: 14
                    color: keyboard.numLock ? root.cAccent : root.cMute
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 34
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            spacing: 10
            Repeater {
                model: [
                    { id: "suspend", icon: "󰤄", text: "Сон", can: sddm.canSuspend, danger: false },
                    { id: "reboot", icon: "󰜉", text: "Перезапустити", can: sddm.canReboot, danger: true },
                    { id: "poweroff", icon: "󰐥", text: "Вимкнути", can: sddm.canPowerOff, danger: true }
                ]
                Rectangle {
                    required property var modelData
                    readonly property bool asking: root.confirm === modelData.id
                    visible: modelData.can
                    height: 40; radius: 14
                    width: pRow.implicitWidth + 28
                    color: asking ? Qt.rgba(1, 0.62, 0.69, 0.22) : (pm.containsMouse ? Qt.rgba(0.55, 0.78, 1, 0.16) : Qt.rgba(0.07, 0.078, 0.106, 0.55))
                    border.width: 1; border.color: asking ? root.cWarn : root.cStroke
                    scale: pm.pressed ? 0.94 : 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row {
                        id: pRow; anchors.centerIn: parent; spacing: 8
                        Text { text: modelData.icon; font.family: root.iconFont; font.pixelSize: 17; color: asking ? root.cWarn : root.cText; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: asking ? "Точно?" : modelData.text
                            font.pixelSize: 13; color: asking ? root.cWarn : root.cText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.danger && root.confirm !== modelData.id) { root.confirm = modelData.id; confirmReset.restart(); return }
                            if (modelData.id === "suspend") sddm.suspend()
                            else if (modelData.id === "reboot") sddm.reboot()
                            else sddm.powerOff()
                        }
                    }
                }
            }
        }
    }

    // клік повз список сесій — закрити його
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: { root.sessionsOpen = false; field.forceActiveFocus() }
    }

    // ── вихід після успішного входу: усе плавно гасне ──
    Rectangle {
        id: fadeOut
        anchors.fill: parent
        color: "#0b0d13"
        opacity: 0
        z: 100
    }
    SequentialAnimation {
        id: leave
        PauseAnimation { duration: 200 }
        NumberAnimation { target: fadeOut; property: "opacity"; to: 1; duration: 450; easing.type: Easing.InOutCubic }
    }
}
