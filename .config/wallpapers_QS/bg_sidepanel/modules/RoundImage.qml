import QtQuick
import QtQuick.Effects

// Картинка із закругленими кутами (аватар, обкладинка).
//   animated: true  — GIF / APNG / WebP програються (AnimatedImage); для звичайних картинок теж працює
//   playing:  false — анімація на паузі (панель закрита — не витрачаємо процесор)
Item {
    id: r

    property url source
    property real radius: 16
    property int maxSide: 640          // обмеження розміру декодування для статичних картинок
    property bool animated: false
    property bool playing: true

    readonly property int status: animated ? anim.status : still.status

    Image {
        id: still
        anchors.fill: parent
        source: r.animated ? "" : r.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: false
        sourceSize.width: r.maxSide
        sourceSize.height: r.maxSide
    }

    AnimatedImage {
        id: anim
        anchors.fill: parent
        source: r.animated ? r.source : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
        playing: true
        paused: !r.playing
    }

    Item {
        id: maskItem
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: r.radius; color: "black" }
    }

    MultiEffect {
        anchors.fill: parent
        source: r.animated ? anim : still
        maskEnabled: true
        maskSource: maskItem
        // згладжений край маски (без цього кути аватара й обкладинки «драбинкою»)
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: r.status === Image.Ready
    }
}
