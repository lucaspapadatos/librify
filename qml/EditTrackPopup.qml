// EditTrackPopup.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.3  // For FileDialog

Popup {
    id: root
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 400
    height: 500
    padding: 10

    property var trackData: ({})

    signal saveRequested(var newData)

    function openForTrack(trackData) {
        console.log("Opening popup for track:", trackData.title)
        root.trackData = trackData
        titleField.text = trackData.title;
        artistField.text = trackData.artist;
        albumField.text = trackData.album;
        if (trackData.imageBase64) {
            imagePreview.source = "data:" + trackData.imageMimeType + ";base64," + trackData.imageBase64
        }
        root.open();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: "Title"
        }

        TextField {
            id: artistField
            Layout.fillWidth: true
            placeholderText: "Artist"
        }

        TextField {
            id: albumField
            Layout.fillWidth: true
            placeholderText: "Album"
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

        RowLayout {
            Button {
                text: "Save"
                onClicked: {
                    console.log("Saving:", artistField.text, " - ", titleField.text)
                    root.saveRequested({
                        filePath: root.trackData.filePath,
                        title: titleField.text,
                        artist: artistField.text,
                        album: albumField.text,
                        imagePath: imageFileDialog.selectedFile
                    });
                    console.log("Image saved", imageFileDialog.selectedFile)
                    root.close();
                }
            }
            Button {
                text: "Cancel"
                onClicked: root.close()
            }
        }
    }
}
