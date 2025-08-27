// EditPlaylistPopup.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.3  

Popup {
	id: root
	modal: true; anchors.centerIn: Overlay.overlay; width: 400; height: 500; padding: 10
	font.family: customFont.name 

	property bool isCreateMode: true	// creating or editing	
	property var modelData

	signal createRequested(string name, string imagePath)
	signal editRequested(string name, string imagePath)
	signal deleteRequested(string name)

	FontLoader {
		id: customFont
		source: "qrc:/fonts/Readex_Pro/static/ReadexPro-Bold.ttf"
	}

    function openForCreate() {
		console.log("[EditPlaylistPopup] Opening popup in CREATE mode")
		isCreateMode = true
        titleField.text = ""
        imagePreview.source = "qrc:/icons/default_playlist_cover.png"
        root.open();
	}

	function openForEdit(playlist) {
        console.log("[EditPlaylistPopup] Opening in EDIT mode:", playlist.name)
        isCreateMode = false
        titleField.text = playlist.name
		imagePreview.source = playlist.iconSource ? playlist.iconSource : "qrc:/icons/default_playlist_cover.png"
		modelData = playlist
        root.open()
    }

	// --- UI LAYOUT ---
    ColumnLayout {
        anchors.fill: parent; spacing: 10

        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: "Playlist Name"
        }

        Image {
            id: imagePreview
            Layout.preferredWidth: 100
            Layout.preferredHeight: 100
            fillMode: Image.PreserveAspectFit
        }

        Button {
            text: "Change Cover"
            onClicked: imageFileDialog.open()
        }

        FileDialog {
            id: imageFileDialog
            title: "Select Cover Image"
            nameFilters: ["Image files (*.png *.jpg *.jpeg)"]
            onAccepted: {
				imagePreview.source = selectedFile
            }
        }

		// --- Action Buttons ---
        RowLayout {
            Button {
				text: isCreateMode ? "Create" : "Save"
				onClicked: {
					if (isCreateMode) {
                        console.log("[EditPlaylistPopup] Creating playlist:", titleField.text)
                        cppPlaylistManager.createPlaylist(
                            titleField.text,
                            imageFileDialog.selectedFile || imagePreview.source
                        )
                        root.createRequested(titleField.text, imageFileDialog.selectedFile)
                    } else {
                        console.log("[EditPlaylistPopup] Saving playlist:", titleField.text)
						cppPlaylistManager.editPlaylist(
							modelData.name, titleField.text, 
							imageFileDialog.selectedFile
						)
                        root.editRequested(titleField.text, imageFileDialog.selectedFile)
                    }
                    root.close()
                }
            }
            Button {
                text: "Cancel"
                onClicked: root.close()
			}
			Item {
				Layout.fillWidth: true
			}
			Button {
				visible: !isCreateMode; Layout.alignment: Qt.AlignRight
				text: "Delete"
				background: Rectangle {
                    radius: 4
                    color: "#d32f2f" // Red color
                }
                contentItem: Text {
                    text: "Delete"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
				}
				onClicked: {
                    console.log("[EditPlaylistPopup] Deleting playlist:", modelData.name)
                    cppPlaylistManager.deletePlaylist(modelData.name)
                    root.deleteRequested(modelData.name)
                    root.close()
                }
			}
        }
    }
}

