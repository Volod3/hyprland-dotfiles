import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects

// ═══════════════════════════════════════════════════════════════════
//  Екран блокування (як у KDE): годинник, дата, аватар, поле пароля.
//  Заблокувати:  ~/.config/wallpapers_QS/tools/lock        (або Win+L / меню живлення / сон)
//  Перегляд без блокування (для налаштування вигляду):
//      LOCK_PREVIEW=1 qs -p ~/.config/wallpapers_QS/bg_lock/shell.qml      (Esc — закрити)
//  Пароль перевіряє PAM (той самий, що при вході). Після розблокування процес завершується.
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    ThemeColors { id: tc }          // кольори поточної теми (Pause — меню тем)

    readonly property bool preview: Quickshell.env("LOCK_PREVIEW") === "1"
    readonly property string home: Quickshell.env("HOME")
    // шпалери поточної теми (tools/theme пише шлях у themes/current.json); запасний варіант — wp4
    readonly property string wallpaper: tc.preview.length ? "file://" + tc.preview : "file://" + home + "/.config/wallpapers_QS/bg_parallax_MDRG/assets/images/wp4.jpg"
    readonly property string avatar: "file://" + home + "/.config/wallpapers_QS/bg_parallax_MDRG/assets/gifs/mimi_spining.gif"
    readonly property string userName: Quickshell.env("USER") || home.split("/").pop()

    property string pw: ""
    property string msg: ""
    property bool busy: false
    property int fails: 0
    property bool leaving: false          // розблоковано — граємо анімацію виходу, тоді знімаємо блокування
    signal shake()

    function submit(t) {
        if (root.busy || !t.length) return
        root.pw = t
        root.busy = true
        root.msg = ""
        if (root.preview) { previewCheck.restart(); return }   // у перегляді пароль не перевіряється
        pam.start()
    }
    function unlockNow() {
        root.leaving = true
        leaveTimer.start()
    }
    Timer {
        id: leaveTimer
        interval: 420
        onTriggered: { if (!root.preview) lock.locked = false; Qt.quit() }
    }

    PamContext {
        id: pam
        config: "swaylock"                 // /etc/pam.d/swaylock → auth include login
        user: root.userName
        onPamMessage: { if (pam.responseRequired) pam.respond(root.pw) }
        onCompleted: (result) => {
            root.busy = false
            root.pw = ""
            if (result === PamResult.Success) { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", "unlock"]); root.unlockNow(); return }
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", "error"])
            root.fails++
            root.msg = result === PamResult.MaxTries ? "Забагато спроб — зачекай трохи" : "Неправильний пароль"
            root.shake()
        }
        onError: (e) => { root.busy = false; root.pw = ""; root.msg = "Помилка перевірки пароля"; root.shake() }
    }
    Timer { id: previewCheck; interval: 600; onTriggered: { root.busy = false; root.msg = "Перегляд: пароль не перевіряється"; root.shake() } }

    // заряд батареї для рядка внизу
    property string battery: ""
    Process {
        running: true
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.battery = text.trim() }
    }
    SystemClock { id: clk; precision: SystemClock.Seconds }

    // ── сам вигляд (однаковий для блокування й перегляду) ──
    component LockView: Item {
        id: v
        focus: true

        Image {
            id: bg
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bg
            blurEnabled: true
            blur: v.shownT
            blurMax: 64
            scale: 1.0 + 0.04 * (1 - v.shownT) + (root.leaving ? 0.03 : 0)
            Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            saturation: 0.1
            brightness: -0.12
        }
        // темне скло зверху + ледь рожевий низ
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: tc.a(tc.bg, 0.55) }
                GradientStop { position: 0.7; color: tc.a(tc.bg, 0.62) }
                GradientStop { position: 1.0; color: Qt.rgba(0.16, 0.09, 0.14, 0.70) }
            }
        }

        // поява: розмиття наростає, годинник опускається, картка виїжджає знизу; вихід — усе гасне й «відлітає»
        property real shownT: 0
        NumberAnimation on shownT { id: appear; running: false; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        opacity: root.leaving ? 0 : Math.min(1, v.shownT * 2)
        Behavior on opacity { enabled: root.leaving; NumberAnimation { duration: 380; easing.type: Easing.InCubic } }
        Component.onCompleted: { appear.start(); field.forceActiveFocus(); if (!root.preview) Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", "lock"]) }

        // поле пароля одразу в фокусі — без кліків (поверхня блокування отримує фокус трохи пізніше)
        Timer { id: focusT; interval: 120; repeat: true; running: true; property int n: 0
                onTriggered: { field.forceActiveFocus(); if (++n >= 8) stop() } }
        // якщо фокус десь загубився — будь-яка клавіша все одно йде в поле
        Keys.onPressed: (e) => {
            if (field.activeFocus || root.busy) return
            field.forceActiveFocus()
            if (e.text.length && e.key !== Qt.Key_Escape && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) {
                field.insert(field.cursorPosition, e.text); e.accepted = true
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.14 - 40 * (1 - v.shownT) - (root.leaving ? 30 : 0)
            Behavior on y { enabled: root.leaving; NumberAnimation { duration: 420; easing.type: Easing.InCubic } }
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clk.date, "HH:mm")
                color: tc.text
                font.family: "Comfortaa"; font.styleName: "Bold"
                font.pixelSize: 150
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const d = ["неділя", "понеділок", "вівторок", "середа", "четвер", "пʼятниця", "субота"]
                    const m = ["січня", "лютого", "березня", "квітня", "травня", "червня", "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"]
                    return d[clk.date.getDay()] + ", " + clk.date.getDate() + " " + m[clk.date.getMonth()]
                }
                color: tc.a(tc.text, 0.8)
                font.pixelSize: 22
            }
        }

        // ── картка входу ──
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: shakeX
            property real shakeX: 0
            y: parent.height * 0.52 + 70 * (1 - v.shownT) + (root.leaving ? 40 : 0)
            Behavior on y { enabled: root.leaving; NumberAnimation { duration: 420; easing.type: Easing.InCubic } }
            scale: (0.94 + 0.06 * v.shownT) * (root.leaving ? 0.92 : 1)
            Behavior on scale { enabled: root.leaving; NumberAnimation { duration: 420; easing.type: Easing.InCubic } }
            width: 380; height: 250; radius: 28
            color: tc.a(tc.bg, 0.72)
            border.width: 1
            border.color: tc.a(tc.border, 0.16)
            Rectangle {      // рожевий відблиск угорі
                anchors.top: parent.top; anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.6; height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: tc.a(tc.accent2, 0.7) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: card; property: "shakeX"; to: -14; duration: 50 }
                NumberAnimation { target: card; property: "shakeX"; to: 12; duration: 60 }
                NumberAnimation { target: card; property: "shakeX"; to: -8; duration: 60 }
                NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 70 }
            }
            Connections { target: root; function onShake() { shakeAnim.restart(); field.text = ""; field.forceActiveFocus() } }

            // аватар
            Rectangle {
                id: av
                anchors.horizontalCenter: parent.horizontalCenter
                y: -44
                width: 92; height: 92; radius: 46
                color: tc.a(tc.bg, 0.9)
                border.width: 3
                border.color: root.busy ? tc.accent2 : tc.accent
                Behavior on border.color { ColorAnimation { duration: 200 } }
                AnimatedImage {
                    id: avImg
                    anchors.fill: parent; anchors.margins: 5
                    source: root.avatar
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Rectangle { id: avMask; anchors.fill: avImg; radius: width / 2; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: avImg
                    source: avImg
                    maskEnabled: true
                    maskSource: avMask
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 62
                width: parent.width - 56
                spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.userName
                    color: tc.text; font.pixelSize: 20; font.bold: true
                }
                Rectangle {
                    width: parent.width; height: 48; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: field.activeFocus ? 2 : 1
                    border.color: root.msg.length && !root.busy ? tc.warn : (field.activeFocus ? tc.accent : tc.a(tc.border, 0.16))
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    Text {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                        color: tc.sub
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 46; anchors.rightMargin: 46
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: tc.text
                        font.pixelSize: 18
                        enabled: !root.busy
                        focus: true
                        onAccepted: root.submit(text)
                        Keys.onEscapePressed: { if (root.preview) Qt.quit(); else text = "" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !field.text.length
                            text: root.busy ? "Перевіряю…" : "Пароль"
                            color: tc.a(tc.sub, 0.75); font.pixelSize: 16
                        }
                    }
                    // кнопка «увійти»
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; radius: 12
                        color: gm.containsMouse ? tc.accentSoft : tc.accent
                        opacity: field.text.length ? 1 : 0.35
                        Text { anchors.centerIn: parent; text: root.busy ? "󰔟" : "󰁔"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: tc.onAccent }
                        MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit(field.text) }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.msg.length ? root.msg : "Введи пароль і натисни Enter"
                    color: root.msg.length ? tc.warn : tc.sub
                    font.pixelSize: 13
                }
            }
        }

        // ── рядок унизу: батарея, розкладка ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 28
            spacing: 22
            Text { text: root.battery.length ? "󰁹  " + root.battery + "%" : ""; color: tc.a(tc.text, 0.8); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
            Text { text: root.preview ? "перегляд · Esc — закрити" : ""; color: tc.a(tc.sub, 0.75); font.pixelSize: 13 }
        }
    }

    // ── справжнє блокування ──
    WlSessionLock {
        id: lock
        locked: !root.preview
        WlSessionLockSurface {
            color: "black"
            LockView { anchors.fill: parent }
        }
    }

    // ── перегляд (звичайне вікно на весь екран) ──
    Loader {
        active: root.preview
        sourceComponent: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "black"
            LockView { anchors.fill: parent }
        }
    }
}
