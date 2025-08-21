// EditPlaylistPopup.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.3  

Popup {
	id: root
	modal: true; anchors.centerIn: Overlay.overlay; width: 400; height: 500; padding: 10

	property bool isCreateMode: true	// creating or editing	
	property var trackData: ({})

	signal createRequested(string name, string imagePath)
	signal editRequested(var updatedPlaylist)

    function openForCreate() {
		console.log("[EditPlaylistPopup] Opening popup in CREATE mode")
		isCreateMode = true
		trackData = {}
        titleField.text = ""
        imagePreview.source = "qrc:/icons/default_playlist_cover.png"
        root.open();
	}

	function openForEdit(playlistData) {
        console.log("[EditPlaylistPopup] Opening in EDIT mode:", playlistData.name)
        isCreateMode = false
        root.trackData = playlistData
        titleField.text = playlistData.name
        imagePreview.source = playlistData.iconSource ? playlistData.iconSource : "qrc:/icons/playlist_icon.png"
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
                        cppPlaylistManager.savePlaylist(titleField.text, updated)
                        root.editRequested(updated)
                    }
                    root.close()
                }
            }
            Button {
                text: "Cancel"
                onClicked: root.close()
            }
        }
    }
}

