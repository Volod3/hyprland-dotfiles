import QtQuick
import "../components"

// Розділ «Про систему»: залізо та версії (hyprctl version, uname, /proc).
Item {
    id: page

    property var bridge

    property var rowsModel: [
        { "icon": "\uf108", "label": "Модель", "value": page.info("model") },
        { "icon": "\uf2db", "label": "Процесор", "value": page.info("cpu"),
          "sub": page.info("cores", 0) + " потоків" },
        { "icon": "\uf26c", "label": "Відео", "value": page.info("gpu") },
        { "icon": "\uf233", "label": "Hyprland", "value": page.info("hyprland") },
        { "icon": "\uf17c", "label": "Ядро", "value": page.info("kernel") },
        { "icon": "\uf109", "label": "Екран", "value": (page.bridge && page.bridge.sysinfo
              && page.bridge.sysinfo.monitors) ? page.bridge.sysinfo.monitors.join(" · ") : "—" }
    ]

    function info(key, fallback) {
        var v = bridge && bridge.sysinfo ? bridge.sysinfo[key] : undefined;
        return (v === undefined || v === null || v === "") ? (fallback === undefined ? "—" : fallback) : v;
    }

    Component.onCompleted: if (bridge) bridge.refreshInfo()

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Repeater {
            model: page.rowsModel

            Item {
                required property int index
                readonly property var modelData: page.rowsModel[index] !== undefined
                    ? page.rowsModel[index]
                    : ({ "icon": "", "label": "", "value": "—", "sub": "" })
                width: parent.width
                height: 52

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.strokeSoft
                    opacity: 0.6
                }

                Text {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(modelData.icon)
                    color: Theme.accent
                    opacity: 0.75
                    font.family: Theme.mono
                    font.pixelSize: 13
                }

                Text {
                    id: rowLabel
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    text: String(modelData.label)
                    color: Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: 11
                }

                Text {
                    anchors.left: rowLabel.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.sub !== undefined && modelData.sub !== "")
                        ? String(modelData.value) + "   ·   " + String(modelData.sub)
                        : String(modelData.value)
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        // --------------------------------------------------------- RAM ----
        Item {
            width: parent.width
            height: 60

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.strokeSoft
                opacity: 0.6
            }

            Text {
                id: ramIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf4bc"
                color: Theme.accent
                opacity: 0.75
                font.family: Theme.mono
                font.pixelSize: 13
            }

            Text {
                id: ramLabel
                anchors.left: ramIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                text: "Пам'ять"
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Text {
                anchors.left: ramLabel.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14
                text: page.info("ram_used_gib", 0) + " / " + page.info("ram_total_gib", 0)
                      + " GiB  ·  " + page.info("ram_percent", 0) + "%"
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Rectangle {
                anchors.left: ramLabel.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                height: 4
                radius: 2
                color: Qt.rgba(0.35, 0.45, 0.65, 0.25)

                Rectangle {
                    width: parent.width * Math.min(1, page.info("ram_percent", 0) / 100)
                    height: parent.height
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accentDeep }
                        GradientStop { position: 1.0; color: Theme.accent }
                    }
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: "Дані: /proc/cpuinfo, /proc/meminfo, /sys/…/dmi, lspci, hyprctl version, uname"
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 9
    }
}
