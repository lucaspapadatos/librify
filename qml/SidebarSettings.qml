// SidebarSettings.qml
import QtQuick
import QtQuick.Controls 
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore 6.5
import Qt.labs.platform as Platform

Popup {
    id: root
	modal: true; anchors.centerIn: Overlay.overlay; width: 360; height: 380; padding: 15
	background: Rectangle { color: "#2E2E2E"; radius: 5; border.color: "#444"; border.width: 1 }

	required property var settings

	signal saveRequested(string newDirectory, color newColor, string newGrouping)

	property color initialColor: "#FF0000"
	property string initialDirectory: ""
	property var initialColorList: []
    property string initialGrouping: "ARTISTS"

	property color _selectedColor: initialColor
	property string _selectedDirectory: initialDirectory
	property list<color> _themeColorList: initialColorList

	// --- FILE DIALOG FOR DIRECTORY ---
    Platform.FolderDialog {
        id: fileDialog
		title: "Select Default Music Directory"
        folder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
		onAccepted: {
			var selectedPath = fileDialog.folder.toString().replace("file://", "")
            _selectedDirectory = selectedPath
            directoryField.text = selectedPath
        }
    }

	function openSettings(currentGrouping, currentColor, currentDirectory, colorList) {
		_selectedColor = initialColor;
        _selectedDirectory = initialDirectory;
        _themeColorList = initialColorList;
        directoryField.text = initialDirectory;
        root.open()
    }

    // --- UI LAYOUT ---
    ColumnLayout {
        anchors.fill: parent; spacing: 15
        Label {
            text: "Settings"
            font.pixelSize: 18
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
		// 1. DEFAULT DIRECTORY
		Label {
			text: "Default Music Directory"
            color: "#AAAAAA"
            font.bold: true
		}
		RowLayout {
            Layout.fillWidth: true
            TextField {
                id: directoryField
                Layout.fillWidth: true
                placeholderText: cppLocalManager.defaultMusicPath
                color: "#333"
                background: Rectangle {
                    color: "white"
                    border.color: "#444"
                    radius: 4
                }
            }
			Rectangle  {
				Layout.preferredWidth: 100
				Layout.preferredHeight: directoryField.height
				radius: 4
				color: browseMouseArea.pressed ? Qt.darker(themeColor) :
                  (browseMouseArea.containsMouse ? Qt.darker(themeColor) : "transparent")
				border.color: "#444"
				border.width: 1
				MouseArea {
					id: browseMouseArea
					anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor;
					onClicked: fileDialog.open()
				}
				Text {
					text: "Browse"
					font.pixelSize: 14
					anchors.centerIn: parent
					color: "white"
				}

            }
        }
		// --- 2. THEME COLOR ---
        Label {
            text: "Theme Color"
            color: "#AAAAAA"
            font.bold: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: _themeColorList
                delegate: Rectangle {
                    property color modelColor: modelData
                    width: 30; height: 30; radius: 15
                    color: modelColor
                    border.color: _selectedColor.toString() === modelColor.toString() ? "white" : "transparent"
                    border.width: 2

                    ToolTip.visible: mouseArea.containsMouse
                    ToolTip.text: modelColor.toString()

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            _selectedColor = modelColor
                        }
                    }
                }
            }
        }
		// --- 3. SIDEBAR GROUPING ---
        Label {
            text: "Default Sidebar Grouping"
            color: "#AAAAAA"
            font.bold: true
        }
        ButtonGroup { id: groupingGroup }
        RowLayout {
            spacing: 10
            RadioButton {
                id: artistsRadio
                text: "Artists"
				ButtonGroup.group: groupingGroup
				checked: root.initialGrouping === "ARTISTS"
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font: parent.font
                    leftPadding: parent.indicator.width + parent.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
            RadioButton {
                id: albumsRadio
                text: "Albums"
				ButtonGroup.group: groupingGroup
				checked: root.initialGrouping === "ALBUMS"
                contentItem: Text {
					text: parent.text
					color: "white"
                    font: parent.font
                    leftPadding: parent.indicator.width + parent.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
            RadioButton {
                id: playlistsRadio
                text: "Playlists"
				ButtonGroup.group: groupingGroup
				checked: root.initialGrouping === "PLAYLISTS"
				contentItem: Text {
					text: parent.text
					color: "white"
					font: parent.font
					leftPadding: parent.indicator.width + parent.spacing
					verticalAlignment: Text.AlignVCenter
				}
            }
        }

        Item { Layout.fillHeight: true } // Spacer
		

        // --- Action Buttons ---
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: 10
            Button {
                text: "Save"
				highlighted: true
				MouseArea {
					anchors.fill: parent; hoverEnabled: true;
					cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.NoButton
				}
				onClicked: {
					var newGrouping = "ARTISTS";
                    if (albumsRadio.checked) newGrouping = "ALBUMS";
                    else if (playlistsRadio.checked) newGrouping = "PLAYLISTS";
                    var newColor = _selectedColor;
					var newDirectory = directoryField.text;
					settings.setValue("sidebarGrouping", newGrouping);
                    settings.setValue("themeColor", newColor.toString());
                    settings.setValue("defaultDirectory", newDirectory);
                    root.saveRequested(newDirectory, newColor, newGrouping)
                    root.close()
                }
            }
            Button {
				text: "Close"
				MouseArea {
					anchors.fill: parent; hoverEnabled: true;
					cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.NoButton
				}
				onClicked: root.close()
            }
        }
    }
}
