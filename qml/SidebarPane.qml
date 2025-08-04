// SidebarPane.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: sidebarPane
    color: "#AA252528"; radius: 5; border.color: "#444"; border.width: 1; clip: true

    // --- PROPERTIES ---
    required property var localManager
    required property var spotifyManager
    required property bool collapsed // Determines visibility of top controls
    property string currentGrouping: "ARTIST"
    property string sourceIcon: "qrc:/icons/artist_icon.png"
    property bool showToggle: false
    property string currentSelectedId: ""  // Track currently selected item ID
	property int defaultAllTracksIndex: -1 // Index of the ALL TRACKS item
    property real rowScale: 1.0

    // --- CONSTANTS ---
    readonly property int topSpacing: 8
    readonly property string allTracksId: "*ALL_TRACKS*"
    readonly property real baseRowHeight: 45
    readonly property real baseFontSize: 12
    readonly property real baseImageSize: 24
	
    // --- SIGNALS ---
    signal collapseToggleRequested
    signal sidebarSelected(string name)
    signal wheel
    signal tracklistRequested(string sourceId, string sourceType)

    // --- FONTS ---
    FontLoader {
        id: customFont
        source: "qrc:/fonts/yeezy_tstar-bold-webfont.ttf"
    }

    // --- UI LAYOUT ---
    ColumnLayout {
        id: sidebarColumn
        anchors.fill: parent; anchors.margins: topSpacing; spacing: 5
		
		Rectangle {
            id: settingsButton
            Layout.fillWidth: true; height: 30; visible: !collapsed
            radius: 4
            color: settingsMouseArea.pressed ? "#33FFFFFF" :
                  (settingsMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
            Row {
                anchors.centerIn: parent; spacing: 8
                Text {
                    font.family: customFont.name
                    text: "Settings"
                    color: "white"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: settingsMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
					console.log("[SidebarPane] Settings button clicked")
					sidebarSettings.openSettings()
                }
            }
        }

        Rectangle {
            id: toggleContainer
            Layout.fillWidth: true
            height: 30
            radius: 4
            visible: !collapsed && currentGrouping === "ALBUM"
            color: "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10
                Text {
                    text: "SP/EP"
                    color: "white"
                    font.pixelSize: 12
                    font.family: customFont.name
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    id: toggleSwitch
                    width: 50
                    height: 26
                    radius: height / 2
                    color: showToggle ? themeColor : "#999999"  // Green when on, Gray when off
                    // Smooth color transition
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                    // Toggle handle
                    Rectangle {
                        id: toggleHandle
                        width: 22
                        height: 22
                        radius: width / 2
                        color: "#FFFFFF"
                        x: showToggle ? parent.width - width - 2 : 2
                        y: 2
                        // Drop shadow for toggle handle
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 4.0
                            samples: 9
                            color: "#30000000"
                        }
                        // Smooth position transition
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
                            showToggle = !showToggle
                            console.log("toggled SP/EP:", showToggle)
                        }
                    }
                }
            }
        }

        // --- ACTION BUTTONS ---
        RowLayout {
            visible: !collapsed
            Layout.fillWidth: true
            spacing: 5

            // Local Files Button
            Rectangle {
                id: loadLocalButton
                Layout.fillWidth: true
                height: 30
                radius: 4
                color: mouseArea.pressed ? "#33FFFFFF" :
                      (mouseArea.containsMouse ? "#22FFFFFF" : "transparent")
                border.color: "#666"
                border.width: 1
                opacity: mainWindow.isScanningLocalFiles ? 0.5 : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        id: allTracksIcon
                        smooth: true
                        source: "qrc:/icons/all_tracks_icon.png"
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: mainWindow.isScanningLocalFiles ? "Scanning..." : "Local"
                        color: "white"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !mainWindow.isScanningLocalFiles
                    onClicked: {
                        if (localManager && typeof localManager.selectAndScanParentFolderForArtists === "function") {
                            localManager.selectAndScanParentFolderForArtists();
                        }
                    }
                }
            }

            // Spotify Button
            Rectangle {
                id: getSpotifyPlaylistsButton
                Layout.fillWidth: true
                height: 30
                radius: 4
                color: spotifyMouseArea.pressed ? "#33FFFFFF" :
                      (spotifyMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
                border.color: enabled ? "#666" : "#444"
                border.width: 1
                enabled: cppSpotifyManager.isAuthenticated && !mainWindow.isScanningLocalFiles
                opacity: enabled ? 1.0 : 0.5

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        id: spotifyIcon
                        smooth: true
                        source: "qrc:/icons/spotify_black_icon.png"
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Spotify"
                        color: "white"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: spotifyMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (spotifyManager && typeof spotifyManager.fetchPlaylists === "function") {
                            spotifyManager.fetchPlaylists();
                        }
                    }
                }
            }
		}

        Rectangle { // Separator
            id: separatorLine
            visible: !collapsed // Use property
            Layout.fillWidth: true; height: 1; color: "#444"; Layout.topMargin: 8; Layout.bottomMargin: 5; opacity: 1.0
		}

        // --- LIST OF ARTISTS/ALBUMS/PLAYLISTS ---
        Rectangle {
            id: sidebarViewWrapper
            Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"

            ListView {
				id: sidebarListView; anchors.fill: parent; clip: true; currentIndex: -1
                model: localManager ? localManager.sidebarItems : null; spacing: 2

                onModelChanged: {
                    // Reset default index
                    sidebarPane.defaultAllTracksIndex = -1
                   // Find ALL TRACKS item
                   if (model) {
                       for (var i = 0; i < model.length; i++) {
                           if (model[i].id === allTracksId || model[i].type === "local_all") {
                               sidebarPane.defaultAllTracksIndex = i
                               console.log("Found ALL TRACKS at index:", i)
                               break
                           }
                       }
                   }
                }
                delegate: Rectangle {
                    width: sidebarListView.width
                    height: 45 * rowScale
                    radius: 3
                    color: sidebarListView.currentIndex === index ? "#40FFFFFF" :
                          (delegateMouseArea.containsMouse ? "#25FFFFFF" : "transparent")

                    property bool isSpotify: modelData.type === "spotify_playlist"
                    property bool isArtist: modelData.type === "local_artist"
                    property bool isAllTracks: modelData.type === "local_all"
                    property string displayName: modelData.name

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Image {
                            width: baseImageSize * rowScale
                            height: baseImageSize * rowScale
                            anchors.verticalCenter: parent.verticalCenter
                            source: {
                                if (isAllTracks) return "qrc:/icons/all_tracks_icon.png"
                                if (isSpotify) return "qrc:/icons/spotify_playlist_icon.png"
                                return "qrc:/icons/artist_icon.png"
                            }
                        }

                        Column {
                            width: parent.width - 44
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2 * rowScale

                            Text {
                                width: parent.width
                                text: displayName
                                color: "white"
                                font { family: customFont.name; pixelSize: baseFontSize * rowScale }
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: !collapsed
                                text: modelData.count + " tracks"
                                color: "#AAAAAA"
                                font.pixelSize: baseFontSize * rowScale
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sidebarListView.currentIndex === index) {
                                // If already selected, unselect and select ALL TRACKS
                                if (sidebarPane.defaultAllTracksIndex >= 0 && index !== sidebarPane.defaultAllTracksIndex) {
                                    // Switch to ALL TRACKS
                                    sidebarListView.currentIndex = sidebarPane.defaultAllTracksIndex
                                    var allTracksItem = sidebarListView.model[sidebarPane.defaultAllTracksIndex]
                                    sidebarPane.currentSelectedId = allTracksItem.id
                                    sidebarPane.sidebarSelected(allTracksItem.id)
                                    localManager.loadTracksForArtist(allTracksItem.id)
                                    console.log("Switched to ALL TRACKS:", allTracksItem.name)
                                } else {
                                    // Handle when clicking the ALL TRACKS item when it's already selected
                                    // or when there's no ALL TRACKS item - just maintain current selection
                                    console.log("Maintaining current selection")
                                }
                            } else {
                                // Normal selection
                                sidebarListView.currentIndex = index
                                sidebarPane.currentSelectedId = modelData.id
                                sidebarPane.sidebarSelected(modelData.id)
                                localManager.loadTracksForArtist(modelData.id)


                                console.log("Selected:", modelData.name, "ID:", modelData.id, "Type:", modelData.type)
                            }
                        }

                        onWheel: function(wheel) {
                            if (wheel.modifiers & Qt.ControlModifier) {
                                sidebarPane.rowScale = Math.min(2.0, Math.max(0.5, sidebarPane.rowScale + (wheel.angleDelta.y > 0 ? 0.1 : -0.1))) // explain what this does !
                                wheel.accepted = true
                            } else {
                                wheel.accepted = false // Allow normal scrolling
                                sidebarPane.wheel() // Emit the wheel signal
                            }
                        }
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

		} // End Rectangle

		// --- COLLAPSE BUTTON ---
		RowLayout {
            Layout.fillWidth: true
            height: 40 // Provides a decent vertical click area
			Layout.topMargin: 5 // Space above the button
			spacing: 5

            // This first spacer is always visible. It pushes the icon to the right.
			Item { 
				Layout.fillWidth: true
				visible: sidebarPane.collapsed
			}
			
			// Group By Button
			Rectangle {
				id: sourcesLabel
				Layout.fillWidth: true
				visible: !collapsed
				height: 30
				radius: 4
				color: sourcesMouseArea.pressed ? "#33FFFFFF" :
                  (sourcesMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
				border.color: sourcesLabel.enabled ? "#666" : "#444"
				border.width: 1

				Row {
					anchors.centerIn: parent
					spacing: 8
					Image {
						id: sourcesIcon
						source: sourceIcon
						width: 16
						height: 16
						anchors.verticalCenter: parent.verticalCenter
					}
					Text {
						id: sourceText
						font.family: customFont.name
						text: "Group by: " + currentGrouping
						color: "white"
						font.pixelSize: 12
						anchors.verticalCenter: parent.verticalCenter
					}
				}

				MouseArea {
					id: sourcesMouseArea
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						if (currentGrouping === "ARTIST") {
							currentGrouping = "ALBUM"
							sourceIcon = "qrc:/icons/all_tracks_icon.png"
						} else if (currentGrouping === "ALBUM") {
							currentGrouping = "PLAYLIST"
							sourceIcon = "qrc:/icons/all_tracks_icon.png"
						} else {
							currentGrouping = "ARTIST"
							sourceIcon = "qrc:/icons/artist_icon.png"
						}
					}
				}
			}

            // The icon and its clickable area
            Text {
                id: toggleIcon
                text: sidebarPane.collapsed ? ">" : "<"
                color: "#AAAAAA"
                font.pixelSize: 22
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10 // Make click area larger than the text
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebarPane.collapseToggleRequested()
                }
            }

            // This *second* spacer is ONLY visible when collapsed.
            // With both spacers active, the icon is pushed to the center.
            // When expanded, this spacer is hidden, and the first spacer pushes the icon to the far right.
            Item {
                Layout.fillWidth: true
                visible: sidebarPane.collapsed
            }
		} // --- END COLLAPSE BUTTON

		SidebarSettings {
			id: sidebarSettings
			onSaveRequested: () => {
				console.log("[SidebarPane.qml]: Save requested.");
			}
		}

    } // End Sidebar ColumnLayout
}
