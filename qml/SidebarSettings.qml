// SidebarSettings.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root
	modal: true; anchors.centerIn: Overlay.overlay; width: 350; height: 380; padding: 15
	background: Rectangle { color: "#2E2E2E"; radius: 5; border.color: "#444"; border.width: 1 }

    signal saveRequested(bool crossfadeEnabled)

    function openSettings() {
        // crossfadeCheckbox.checked = cppConfigManager.getCrossfade();
        root.open()
    }

    // --- UI LAYOUT ---
    ColumnLayout {
        anchors.fill: parent; spacing: 15

        Label {
            text: "SettingsZ"
            font.pixelSize: 18
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

			// Default directory type with browse option
			RowLayout {}

            // Include singles with albums toggle switch
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                Text {
                    text: "INCLUDE SINGLES WITH ALBUMS"
                    color: "white"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true } // Spacer
                ToggleSwitch {
                    id: showEpToggle
                    // Connect the signal to an action
                    onToggled: console.log("Show SP/EPs toggled:", isChecked)
                }
            }
            
            // Enable crossfade
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                Text {
                    text: "Enable Crossfade"
                    color: "white"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true } // Spacer
                ToggleSwitch {
                    id: crossfadeToggle
                    checked: true // Can be set to be on by default
                    onToggled: console.log("Crossfade toggled:", isChecked)
                }
            }

            // High quality
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                Text {
                    text: "High Quality"
                    color: "white"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true } // Spacer
                ToggleSwitch {
                    id: qualityToggle
                    onColor: "dodgerblue" // Example of customizing the 'on' color
                    onToggled: console.log("High Quality toggled:", isChecked)
                }
			}

			// Default grouping
			RowLayout {}
        }

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
