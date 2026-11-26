import QtQuick
import "../components"

// Розділ «Оформлення»: кожна зміна летить у Hyprland одразу
// (hyprctl eval + перевірка getoption) і зберігається у overrides.json.
Item {
    id: page

    property var bridge
    property var pending: ({})
    property var vals: ({})

    function v(key, fallback) {
        var x = vals[key];
        return (x === undefined || x === null) ? fallback : x;
    }

    function onChange(key, value) {
        pending[key] = value;
        debounce.restart();
    }

    function flush() {
        var keys = Object.keys(pending);
        if (keys.length === 0) return;
        if (bridge.busy) {
            retry.restart();
            return;
        }
        var map = pending;
        pending = {};
        bridge.applyValues(map);
    }

    function applyEverything() {
        var map = {};
        map["general:gaps_in"] = v("general:gaps_in", 5);
        map["general:gaps_out"] = v("general:gaps_out", 20);
        map["general:border_size"] = v("general:border_size", 2);
        map["decoration:rounding"] = v("decoration:rounding", 10);
        map["decoration:active_opacity"] = v("decoration:active_opacity", 0.93);
        map["decoration:inactive_opacity"] = v("decoration:inactive_opacity", 0.87);
        map["decoration:blur:enabled"] = v("decoration:blur:enabled", true);
        map["decoration:blur:size"] = v("decoration:blur:size", 6);
        map["decoration:blur:passes"] = v("decoration:blur:passes", 3);
        map["animations:enabled"] = v("animations:enabled", true);
        pending = ({});
        bridge.applyValues(map);
    }

    Connections {
        target: page.bridge
        function onValuesChanged() { page.vals = page.bridge.values; }
    }

    Component.onCompleted: vals = bridge ? bridge.values : ({})

    Timer {
        id: debounce
        interval: 170
        onTriggered: page.flush()
    }
    Timer {
        id: retry
        interval: 320
        onTriggered: page.flush()
    }

    Row {
        id: columns
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 26

        Column {
            width: 291
            spacing: 6

            SectionTitle { title: "Компонування"; icon: "\uf0c9"; width: parent.width }

            SettingSlider {
                width: parent.width
                label: "Внутрішні відступи (gaps_in)"
                from: 0; to: 30; step: 1
                value: page.v("general:gaps_in", 5)
                onMoved: (v) => page.onChange("general:gaps_in", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
            SettingSlider {
                width: parent.width
                label: "Зовнішні відступи (gaps_out)"
                from: 0; to: 60; step: 1
                value: page.v("general:gaps_out", 20)
                onMoved: (v) => page.onChange("general:gaps_out", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
            SettingSlider {
                width: parent.width
                label: "Товщина рамки (border_size)"
                suffix: " px"
                from: 0; to: 8; step: 1
                value: page.v("general:border_size", 2)
                onMoved: (v) => page.onChange("general:border_size", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
            SettingSlider {
                width: parent.width
                label: "Скруглення кутів (rounding)"
                suffix: " px"
                from: 0; to: 30; step: 1
                value: page.v("decoration:rounding", 10)
                onMoved: (v) => page.onChange("decoration:rounding", v)
                onReleased: { debounce.stop(); page.flush(); }
            }

            Item { width: 1; height: 10 }

            SectionTitle { title: "Прозорість вікон"; icon: "\uf06e"; width: parent.width }

            SettingSlider {
                width: parent.width
                label: "Активне вікно"
                from: 0.5; to: 1.0; step: 0.01; decimals: 2
                value: page.v("decoration:active_opacity", 0.93)
                onMoved: (v) => page.onChange("decoration:active_opacity", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
            SettingSlider {
                width: parent.width
                label: "Неактивне вікно"
                from: 0.4; to: 1.0; step: 0.01; decimals: 2
                value: page.v("decoration:inactive_opacity", 0.87)
                onMoved: (v) => page.onChange("decoration:inactive_opacity", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
        }

        Column {
            width: 291
            spacing: 6

            SectionTitle { title: "Розмиття (blur)"; icon: "\uf0c2"; width: parent.width }

            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Увімкнено"
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 12
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.v("decoration:blur:enabled", true)
                    onToggled: (value) => {
                        page.onChange("decoration:blur:enabled", value);
                        debounce.stop();
                        page.flush();
                    }
                }
            }

            SettingSlider {
                width: parent.width
                label: "Радіус (blur:size)"
                from: 1; to: 16; step: 1
                enabled: page.v("decoration:blur:enabled", true)
                value: page.v("decoration:blur:size", 6)
                onMoved: (v) => page.onChange("decoration:blur:size", v)
                onReleased: { debounce.stop(); page.flush(); }
            }
            SettingSlider {
                width: parent.width
                label: "Проходи (blur:passes)"
                from: 1; to: 6; step: 1
                enabled: page.v("decoration:blur:enabled", true)
                value: page.v("decoration:blur:passes", 3)
                onMoved: (v) => page.onChange("decoration:blur:passes", v)
                onReleased: { debounce.stop(); page.flush(); }
            }

            Item { width: 1; height: 10 }

            SectionTitle { title: "Анімації"; icon: "\uf0e7"; width: parent.width }

            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Увімкнено"
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 12
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.v("animations:enabled", true)
                    onToggled: (value) => {
                        page.onChange("animations:enabled", value);
                        debounce.stop();
                        page.flush();
                    }
                }
            }

            Text {
                width: parent.width
                text: "Вимкнення анімацій і блюру також робить ігровий режим — окремі профілі не конфліктують."
                color: Theme.textMute
                font.family: Theme.mono
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
        }
    }

    // ------------------------------------------------------------ кнопки ---
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.strokeSoft
        }

        Text {
            anchors.left: parent.left
            anchors.right: buttonsRow.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "Зміни летять у Hyprland одразу · перевірка hyprctl getoption"
            color: Theme.textMute
            font.family: Theme.mono
            font.pixelSize: 9
            elide: Text.ElideRight
        }

        Row {
            id: buttonsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Btn {
                text: "Скинути до теми"
                icon: "\uf0e2"
                onClicked: {
                    page.pending = ({});
                    page.bridge.resetToTheme();
                }
            }
            Btn {
                text: "Відновити збережене"
                icon: "\uf1da"
                onClicked: {
                    page.pending = ({});
                    page.bridge.restoreSaved();
                }
            }
            Btn {
                text: "Застосувати"
                icon: "\u2713"
                accent: true
                onClicked: page.applyEverything()
            }
        }
    }
}
