import QtQuick
import "../components"

// Розділ «Тема та ефекти»: theme-switch, ігровий режим, шпалери, скріншот.
Item {
    id: page

    property var bridge

    function themeId() { return bridge && bridge.state && bridge.state.theme ? bridge.state.theme.id : ""; }
    function gameOn() { return bridge && bridge.state ? !!bridge.state.game_on : false; }

    Component.onCompleted: if (bridge) bridge.refreshState()

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12

        // ------------------------------------------------ поточна тема ----
        Rectangle {
            width: parent.width
            height: 176
            radius: 14
            color: Qt.rgba(0.10, 0.14, 0.26, 0.72)
            border.width: 1
            border.color: Theme.strokeSoft

            Item {
                anchors.fill: parent
                anchors.margins: 16

                SectionTitle {
                    id: themeTitle
                    width: parent.width
                    title: "Тема оформлення"
                    icon: "\uf1fc"
                    note: "theme-switch"
                }

                Row {
                    id: currentRow
                    anchors.top: themeTitle.bottom
                    anchors.topMargin: 10
                    spacing: 10

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: (bridge && bridge.state.theme && bridge.state.theme.accent) ? bridge.state.theme.accent : Theme.accent

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: parent.color
                            opacity: 0.22
                        }
                    }

                    Column {
                        spacing: 2
                        Text {
                            text: (bridge && bridge.state.theme && bridge.state.theme.label) ? bridge.state.theme.label : "…"
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "id: " + page.themeId()
                                  + " · шпалери: " + (bridge && bridge.state.wallpaper ? bridge.state.wallpaper : "—")
                            color: Theme.textMute
                            font.family: Theme.mono
                            font.pixelSize: 9
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 74
                    height: 20
                    radius: 6
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: "ПОТОЧНА"
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 8

                    Repeater {
                        model: bridge && bridge.state.themes ? bridge.state.themes : []

                        Rectangle {
                            id: themeCard
                            required property int index
                            readonly property var modelData: (page.bridge && page.bridge.state && page.bridge.state.themes
                                && page.bridge.state.themes[index]) ? page.bridge.state.themes[index]
                                : ({ "id": "", "label": "", "icon": "", "accent": "#7fdcff" })
                            width: 194
                            height: 56
                            radius: 10
                            color: page.themeId() === modelData.id
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                                : (themeMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07) : Qt.rgba(0.06, 0.09, 0.18, 0.6))
                            border.width: 1
                            border.color: page.themeId() === modelData.id
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65)
                                : Theme.strokeSoft
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                text: String(modelData.icon)
                                color: modelData.accent !== undefined ? modelData.accent : Theme.accent
                                font.family: Theme.mono
                                font.pixelSize: 15
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.top: parent.top
                                anchors.topMargin: 9
                                text: String(modelData.label)
                                color: Theme.text
                                font.family: Theme.mono
                                font.pixelSize: 11
                                width: parent.width - 44
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                text: "apply " + (modelData.id === "madara" ? "1" : "2")
                                color: Theme.textMute
                                font.family: Theme.mono
                                font.pixelSize: 9
                            }

                            MouseArea {
                                id: themeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.bridge.setTheme(modelData.id === "madara" ? "1" : "2")
                            }
                        }
                    }

                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Перемкнути"
                        icon: "\uf021"
                        minW: 130
                        onClicked: page.bridge.toggleTheme()
                    }
                }
            }
        }

        // ---------------------------------------------- ігровий режим ----
        Rectangle {
            width: parent.width
            height: 88
            radius: 14
            color: Qt.rgba(0.10, 0.14, 0.26, 0.72)
            border.width: 1
            border.color: Theme.strokeSoft

            Item {
                anchors.fill: parent
                anchors.margins: 16

                Text {
                    id: gameIcon
                    text: "\uf11b"
                    color: page.gameOn() ? Theme.ok : Theme.textMute
                    font.family: Theme.mono
                    font.pixelSize: 16
                }

                Column {
                    anchors.left: gameIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: page.gameOn() ? Theme.ok : Theme.textMute
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: parent.color
                                opacity: page.gameOn() ? 0.25 : 0
                            }
                        }
                        Text {
                            text: page.gameOn() ? "Ігровий режим УВІМКНЕНО" : "Ігровий режим вимкнено"
                            color: page.gameOn() ? Theme.ok : Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        text: page.gameOn()
                            ? "блюр/тіні/анімації вимкнено, gaps 0, tearing on"
                            : "профіль швидкодії для fullscreen-ігор · game-mode"
                        color: Theme.textMute
                        font.family: Theme.mono
                        font.pixelSize: 9
                    }
                }

                Btn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.gameOn() ? "Вимкнути" : "Увімкнути"
                    icon: "\uf0e7"
                    danger: page.gameOn()
                    minW: 118
                    onClicked: page.bridge.toggleGame()
                }
            }
        }

        // ------------------------------------------------------- дії ----
        Rectangle {
            width: parent.width
            height: 126
            radius: 14
            color: Qt.rgba(0.10, 0.14, 0.26, 0.72)
            border.width: 1
            border.color: Theme.strokeSoft

            Item {
                anchors.fill: parent
                anchors.margins: 16

                SectionTitle {
                    id: actionsTitle
                    width: parent.width
                    title: "Шпалери та знімки"
                    icon: "\uf03e"
                }

                Row {
                    anchors.top: actionsTitle.bottom
                    anchors.topMargin: 10
                    spacing: 8

                    Btn {
                        text: "Оновити шпалери"
                        icon: "\uf021"
                        onClicked: page.bridge.refreshWallpaper()
                    }
                    Btn {
                        text: "Скріншот"
                        icon: "\uf030"
                        onClicked: page.bridge.screenshot()
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: bridge && bridge.lastShot !== ""
                        ? "Останній знімок: " + bridge.lastShot
                        : "spectacle -f -b -n -o /tmp/hypr-settings-*.png"
                    color: Theme.textMute
                    font.family: Theme.mono
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
