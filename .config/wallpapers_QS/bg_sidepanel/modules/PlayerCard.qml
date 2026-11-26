import Quickshell.Services.Mpris
import QtQuick

// Картка одного MPRIS-джерела: обкладинка, хвиля прогресу, керування, гучність плеєра.
Rectangle {
    id: card

    required property var player
    required property var theme
    property bool active: true          // false — панель закрита (зупиняє анімацію хвилі)
    property bool showVolume: false     // гучність через MPRIS у браузерів не працює — за замовчуванням вимкнено
    property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""
    property string title: player && player.trackTitle ? player.trackTitle : ""

    height: playerCol.implicitHeight + 32
    radius: 24
    color: theme.tile
    border.width: 1
    border.color: theme.border

    // 3:07, а для довгих треків/відео 1:02:07 (раніше було 62:07)
    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        const s = Math.floor(sec)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const ss = (s % 60 < 10 ? "0" : "") + (s % 60)
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss
    }

    // гучність самого плеєра — із тротлінгом, щоб не засипати D-Bus під час перетягування
    property real volPending: -1
    function setVol(v) {
        if (!player || !player.volumeSupported) return
        volPending = v
        if (!volTimer.running) volTimer.start()
    }
    Timer {
        id: volTimer
        interval: 80
        onTriggered: {
            if (card.player && card.volPending >= 0) card.player.volume = card.volPending
            card.volPending = -1
        }
    }

    Column {
        id: playerCol
        x: 18
        y: 16
        width: parent.width - 36
        spacing: 8

        Text {
            width: parent.width
            text: card.player ? card.player.identity : ""
            elide: Text.ElideRight
            font.family: theme.textFont
            font.pixelSize: 11
            color: theme.subtext
        }
        Text {
            width: parent.width
            text: card.title || "Невідомий трек"
            elide: Text.ElideRight
            font.family: theme.textFont
            font.pixelSize: 20
            font.bold: true
            color: theme.text
        }
        Text {
            width: parent.width
            text: card.player ? card.player.trackArtist : ""
            elide: Text.ElideRight
            font.family: theme.textFont
            font.pixelSize: 14
            color: theme.accent
        }

        Item {
            width: parent.width
            height: 190
            RoundImage {
                id: cover
                width: 190; height: 190
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                source: card.artUrl
                visible: status === Image.Ready
            }
            Rectangle {
                visible: !cover.visible
                width: 190; height: 190
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: theme.track
                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 64
                    color: theme.subtext
                }
            }
        }

        SideWave {
            width: parent.width
            theme: card.theme
            active: card.active
            playing: card.player !== null && card.player.playbackState === MprisPlaybackState.Playing
            seekable: card.player !== null && card.player.canSeek
            progress: card.player !== null && card.player.length > 0 ? card.player.position / card.player.length : 0
            onSeek: (f) => { if (card.player && card.player.canSeek && card.player.length > 0) card.player.position = f * card.player.length }
        }

        Item {
            width: parent.width
            height: 14
            Text {
                anchors.left: parent.left
                text: card.player ? fmtTime(card.player.position) : ""
                font.family: theme.textFont
                font.pixelSize: 11
                color: theme.subtext
            }
            Text {
                anchors.right: parent.right
                text: card.player ? fmtTime(card.player.length) : ""
                font.family: theme.textFont
                font.pixelSize: 11
                color: theme.subtext
            }
        }

        Item {
            width: parent.width
            height: 52

            Row {
                anchors.centerIn: parent
                spacing: 10

                SideIconBtn {
                    theme: card.theme
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf074"
                    iconSize: 14
                    on: card.player !== null && card.player.shuffleSupported && card.player.shuffle
                    dim: card.player === null || !card.player.shuffleSupported
                    onClicked: if (card.player && card.player.shuffleSupported) card.player.shuffle = !card.player.shuffle
                }
                SideIconBtn {
                    theme: card.theme
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf048"
                    dim: card.player === null || !card.player.canGoPrevious
                    onClicked: if (card.player && card.player.canGoPrevious) card.player.previous()
                }
                SideIconBtn {
                    theme: card.theme
                    anchors.verticalCenter: parent.verticalCenter
                    size: 48
                    iconSize: 18
                    filled: true
                    icon: card.player !== null && card.player.playbackState === MprisPlaybackState.Playing ? "\uf04c" : "\uf04b"
                    onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying()
                }
                SideIconBtn {
                    theme: card.theme
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf051"
                    dim: card.player === null || !card.player.canGoNext
                    onClicked: if (card.player && card.player.canGoNext) card.player.next()
                }
                SideIconBtn {
                    theme: card.theme
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf01e"
                    iconSize: 14
                    on: card.player !== null && card.player.loopSupported && card.player.loopState !== MprisLoopState.None
                    dim: card.player === null || !card.player.loopSupported
                    onClicked: {
                        const p = card.player
                        if (!p || !p.loopSupported) return
                        if (p.loopState === MprisLoopState.None) p.loopState = MprisLoopState.Playlist
                        else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track
                        else p.loopState = MprisLoopState.None
                    }
                }
            }
        }
        SideSlider {
            visible: card.showVolume
                && card.player !== null && card.player.volumeSupported
            width: parent.width
            theme: card.theme
            icon: card.player !== null && card.player.volume <= 0 ? "\uf026" : "\uf027"
            maxValue: 1.0
            value: card.player !== null ? card.player.volume : 0
            onMoved: (v) => card.setVol(v)
        }
    }
}
