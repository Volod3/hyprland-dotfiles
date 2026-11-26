import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// ═══════════════════════════════════════════════════════════════════
//  Заставка входу в систему: після SDDM (той гасне в чорне) з чорного проступає привітання,
//  потім усе плавно розкривається — і видно робочий стіл (ховає мерехтіння, поки вантажаться
//  шпалери й панелі). Мишу не перехоплює. Запускається першою з hyprland.lua і сама завершується.
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    readonly property string userName: Quickshell.env("USER") || "друже"
    readonly property int hour: new Date().getHours()
    readonly property string hello: hour < 5 ? "Доброї ночі" : hour < 12 ? "Доброго ранку" : hour < 18 ? "Доброго дня" : "Доброго вечора"

    property real t: 0                       // 0 → 1 за весь показ
    NumberAnimation on t { from: 0; to: 1; duration: 2600; running: true; onFinished: Qt.quit() }

    function cl(x) { return Math.max(0, Math.min(1, x)) }
    function eo(x) { x = cl(x); return 1 - Math.pow(1 - x, 3) }
    function eio(x) { x = cl(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "welcome"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region {}                   // кліки проходять крізь заставку

            // чорне тло, що розкривається колом від центру
            Item {
                id: veil
                anchors.fill: parent
                readonly property real open: root.eio((root.t - 0.55) / 0.42)     // 0 — закрито, 1 — відкрито
                Rectangle {
                    anchors.fill: parent
                    color: "#060709"
                    opacity: 1 - veil.open
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 18
                opacity: root.eo(root.t / 0.18) * (1 - root.eio((root.t - 0.5) / 0.22))
                scale: 0.94 + 0.06 * root.eo(root.t / 0.3) + 0.06 * root.eio((root.t - 0.5) / 0.3)
                transform: Translate { y: 18 * (1 - root.eo(root.t / 0.3)) }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 86; height: 86
                    Image {
                        id: logo
                        anchors.fill: parent
                        source: "logo.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    // м'яке сяйво
                    MultiEffect {
                        anchors.fill: logo
                        source: logo
                        blurEnabled: true; blur: 1.0; blurMax: 48
                        opacity: 0.55 + 0.25 * Math.sin(root.t * Math.PI * 2)
                        z: -1
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hello + ", " + root.userName
                    color: "#e8ecf4"
                    font.family: "Comfortaa"; font.pixelSize: 30
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "HH:mm") + "  ·  " + ["неділя", "понеділок", "вівторок", "середа", "четвер", "пʼятниця", "субота"][new Date().getDay()]
                    color: "#8f98ab"
                    font.family: "Comfortaa"; font.pixelSize: 15
                }
            }
        }
    }
}
