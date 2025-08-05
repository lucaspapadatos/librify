// ToggleSwitch.qml
import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: 50
    height: 26
    radius: height / 2

    // --- PUBLIC API ---
    // The main property to control the switch's state (on/off)
    property bool checked: false
    // Customizable colors
    property color onColor: "#4CAF50" // A pleasant green
    property color offColor: "#999999"

    // --- SIGNALS ---
    // Emitted whenever the switch is clicked and its state changes
    signal toggled(bool isChecked)

    // --- IMPLEMENTATION ---
    color: root.checked ? root.onColor : root.offColor
    
    // Smooth color transition
    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    // The moving handle of the switch
    Rectangle {
        id: toggleHandle
        width: 22
        height: 22
        radius: width / 2
        color: "#FFFFFF"
        x: root.checked ? root.width - width - 2 : 2
        y: 2

        // Drop shadow for a bit of depth
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 1
            radius: 4.0
            samples: 9
            color: "#30000000"
        }

        // Smooth position transition when toggled
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // 1. Invert the checked state
            root.checked = !root.checked
            // 2. Emit the signal to notify the parent
            root.toggled(root.checked)
        }
    }
}
