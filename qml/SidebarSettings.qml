import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root

    modal: true; anchors.centerIn: Overlay.overlay; width: 350; height: 200; padding: 15
    background: Rectangle {
        color: "#2E2E2E"
        radius: 5
        border.color: "#444"
        border.width: 1
    }

    // --- SIGNALS ---
    signal saveRequested(bool crossfadeEnabled)

    // --- FUNCTIONS ---
    function openSettings() {
        // crossfadeCheckbox.checked = cppConfigManager.getCrossfade();
        root.open()
    }

    // --- UI LAYOUT ---
    ColumnLayout {
        anchors.fill: parent; spacing: 20

        Label {
            text: "Sidebar Settings"
            font.pixelSize: 18
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }

		// --- Settings Content ---
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Enable Track Crossfade"
                color: "white"
                font.pixelSize: 14
            }
            Item { Layout.fillWidth: true } // Spacer
            CheckBox {
                id: crossfadeCheckbox
                // In a real app, you would bind `checked` to your settings model
            }
        }

        Item { Layout.fillHeight: true } 

        // --- Action Buttons ---
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: 10
            Button {
                text: "Save"
                highlighted: true 
                onClicked: {
                    root.settingsSaved(crossfadeCheckbox.checked)
                    root.close()
                }
            }
            Button {
                text: "Close"
                onClicked: root.close() 
            }
        }
    }
}
