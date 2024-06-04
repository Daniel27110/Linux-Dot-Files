import QtQuick
import org.kde.kirigami 2 as Kirigami


Image {
    id: root
    source: "images/background.png"
    fillMode: Image.PreserveAspectCrop

     property int stage
     
     property real size: units.gridUnit * 20

    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = false
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        TextMetrics {
            id: units
            text: "M"
            property int gridUnit: boundingRect.height
            property int largeSpacing: units.gridUnit
            property int smallSpacing: Math.max(2, gridUnit/4)
        }
}
}
