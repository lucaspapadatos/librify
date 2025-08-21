// SidebarPane.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: sidebarPane
    color: Qt.darker(themeColor, 4.0); radius: 5; border.color: "#444"; border.width: 1; clip: true

    // --- PROPERTIES ---
    required property var localManager
	required property var spotifyManager
	required property var playlistManager
	required property bool collapsed
	required property var settings
    property string currentGrouping: "ARTISTS"
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
	readonly property real baseImageSize: 30
	
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
	
	// -- INIT --
	Component.onCompleted: {
		currentGrouping = settings.value("sidebarGrouping", "ARTISTS");
        if (localManager) {
            console.log("[SidebarPane] Component completed. Setting initial grouping to:", currentGrouping)
			localManager.setGrouping(currentGrouping)
			localManager.setDefaultMusicPath(mainWindow.defaultDirectory)
        }
    }

    // --- UI LAYOUT ---
    ColumnLayout {
        id: sidebarColumn
        anchors.fill: parent; anchors.margins: topSpacing; spacing: 5

        // --- ACTION BUTTONS ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

			// Collapse Button
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

            // Local Files Button
            Rectangle {
                id: loadLocalButton
                Layout.fillWidth: true
                height: 32
				radius: 20
				visible: !collapsed
                color: mouseArea.pressed ? "#33FFFFFF" :
                      (mouseArea.containsMouse ? "#22FFFFFF" : "transparent")
                opacity: mainWindow.isScanningLocalFiles ? 0.5 : 1.0
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        id: allTracksIcon
                        smooth: true
						source: "qrc:/icons/open_folder.png"
						fillMode: Image.PreserveAspectFit
						height: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: mouseArea
					anchors.fill: parent
					ToolTip.visible: mouseArea.containsMouse
                    ToolTip.text: "Open Folder"
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
                height: 32
                radius: 20
				visible: !collapsed
                color: spotifyMouseArea.pressed ? "#33FFFFFF" :
                      (spotifyMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
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

			// Settings Button
			Rectangle {
				id: settingsButton
				Layout.fillWidth: true; height: 32; visible: !collapsed; radius: 20
				color: settingsMouseArea.pressed ? "#33FFFFFF" :
                  (settingsMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
				Row {
					anchors.centerIn: parent; spacing: 18
					Image {
                        smooth: true
                        source: "qrc:/icons/cogwheel.png"
                        width: 16
                        height: 16
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
						if (settingsLoader.item) {
							settingsLoader.item.initialGrouping = sidebarPane.currentGrouping;
							settingsLoader.item.initialColor = mainWindow.themeColor;
							settingsLoader.item.initialDirectory = mainWindow.defaultDirectory;
							settingsLoader.item.initialColorList = mainWindow.themeColorList;
							settingsLoader.item.openSettings();
						} else {
							settingsLoader.setSource("qrc:/SidebarSettings.qml", { 
								"settings": sidebarPane.settings,
								"initialGrouping": sidebarPane.currentGrouping,
								"initialColor": mainWindow.themeColor,
								"initialDirectory": mainWindow.defaultDirectory,
								"initialColorList": mainWindow.themeColorList
							});
						}
					}
				}
			}

		}

        // --- LIST OF ARTISTS/ALBUMS/PLAYLISTS ---
        Rectangle {
            id: sidebarViewWrapper
            Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
            ListView {
				id: sidebarListView; anchors.fill: parent; clip: true; currentIndex: -1; spacing: 5
				model: {
					if (currentGrouping === "PLAYLISTS") return playlistManager ? playlistManager.sidebarItems : null
					return localManager ? localManager.sidebarItems : null
				}
                onModelChanged: {
                    sidebarPane.defaultAllTracksIndex = -1
					if (model) {
						// Auto-select 2nd item when in PLAYLISTS, if it exists
						if (currentGrouping === "PLAYLISTS" && model.length > 1) {
							sidebarListView.currentIndex = 1
						} else {
							sidebarListView.currentIndex = sidebarPane.defaultAllTracksIndex >= 0
								? sidebarPane.defaultAllTracksIndex
								: 0
						}

						for (var i = 0; i < model.length; i++) {
							if (model[i].id === allTracksId || model[i].type === "local_all") {
								sidebarPane.defaultAllTracksIndex = i
                                break
                            }
                        }
                    }
                }
				delegate: Rectangle {
					id: delegateItem
                    width: sidebarListView.width
                    height: !collapsed ? 50 : sidebarListView.width
                    radius: 3
                    color: sidebarListView.currentIndex === index ? "#40FFFFFF" :
                          (delegateMouseArea.containsMouse ? "#25FFFFFF" : "transparent")
					Behavior on height {
						NumberAnimation {
							duration: transitionSpeed
							easing.type: Easing.InOutQuad
						}
					}
                    property bool isSpotify: modelData.type === "spotify_playlist"
					property bool isArtist: modelData.type === "local_artist"
					property bool isAlbum: modelData.type === "local_album"
					property bool isAllTracks: modelData.type === "local_all"
					property bool isPlaylist: modelData.type === "local_playlist"
					property bool isCreate: modelData.type === "create_playlist"
                    property string displayName: modelData.name

					RowLayout {
						id: delegateRowLayout
						anchors.fill: parent
						anchors.leftMargin: collapsed ? 0 : 2
                        spacing: 5
						Image {
                            Layout.preferredWidth: delegateItem.height - 5
							Layout.preferredHeight: delegateItem.height - 5
							Layout.alignment: collapsed ? Qt.AlignCenter : Qt.AlignLeft
							clip: true
							Behavior on Layout.preferredWidth { 
								NumberAnimation { 
									duration: transitionSpeed; easing.type: Easing.InOutQuad } }
							Behavior on Layout.preferredHeight { 
								NumberAnimation { 
									duration: transitionSpeed; easing.type: Easing.InOutQuad } }
                            source: {
                                if (isAllTracks) return modelData.iconSource
                                if (isSpotify) return "qrc:/icons/spotify_playlist_icon.png"
                                if (isAlbum) return modelData.iconSource
								if (isArtist) return modelData.iconSource
								if (isPlaylist) return modelData.iconSource
								if (isCreate) return "qrc:/icons/create_playlist_icon.png"
                                return ""
                            }
                        } 
                        Column {
							Layout.fillWidth: true
							Layout.alignment: Qt.AlignVCenter
							spacing: 2 * rowScale
							opacity: !collapsed ? 1.0 : 0.0
							Behavior on opacity {
								NumberAnimation { duration: transitionSpeed - 50 } // Fade a bit faster
							}
							visible: opacity > 0
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
                                text: !isCreate ? modelData.count + " tracks" : "PLAYLIST"
                                color: "#AAAAAA"
                                font.pixelSize: baseFontSize * rowScale
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
						id: delegateMouseArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
						onClicked: {
							var item = modelData
							// Special behaviour for CREATE PLAYLIST BUTTON
							if (isCreate) {
								if (editPlaylistPopup && typeof editPlaylistPopup.openForCreate === "function") {
									editPlaylistPopup.openForCreate()
								} else {
									console.log("[SidebarPane] ERROR: editPlaylistPopup not found!")
								}
								return
							}

							// Normal selection behavior
                            if (sidebarListView.currentIndex === index) {
                                // If already selected, unselect and select ALL TRACKS
                                if (sidebarPane.defaultAllTracksIndex >= 0 && index !== sidebarPane.defaultAllTracksIndex) {
                                    item = sidebarListView.model[sidebarPane.defaultAllTracksIndex]
                                    sidebarListView.currentIndex = sidebarPane.defaultAllTracksIndex
                                    console.log("Switched to ALL TRACKS:", item.name)
                                } else {
									console.log("Maintaining current selection")
									return;
                                }
                            } else {
								sidebarListView.currentIndex = index
								console.log("Selected:", item.name, "ID:", item.id, "Type:", item.type)
							}
							sidebarPane.currentSelectedId = item.id
							sidebarPane.sidebarSelected(item.id)

							localManager.loadTracksFor(item.id, item.type)
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

		// --- GROUP BY BUTTON ---
		RowLayout {
            Layout.fillWidth: true
            height: 40 
			Layout.topMargin: 5 
			spacing: 5
			Item { 
				Layout.fillWidth: true
				visible: sidebarPane.collapsed
			}
			Rectangle {
				id: sourcesLabel
				Layout.fillWidth: true
				visible: !collapsed
				height: 30
				radius: 12
				color: sourcesMouseArea.pressed ? "#33FFFFFF" :
                  (sourcesMouseArea.containsMouse ? "#22FFFFFF" : "transparent")
				border.color: sourcesLabel.enabled ? "#666" : "#444"
				border.width: 1
				Text {
					id: sourceText
					font.family: customFont.name
					text: currentGrouping
					color: "white"
					font.pixelSize: 14
					anchors.centerIn: parent
				}
				MouseArea {
					id: sourcesMouseArea
					anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
					onClicked: {
						if (currentGrouping === "ARTISTS") {
							currentGrouping = "PLAYLISTS"
							sourceIcon = "qrc:/icons/all_tracks_icon.png"
						} else if (currentGrouping === "PLAYLISTS") {
							currentGrouping = "ALBUMS"
							sourceIcon = "qrc:/icons/all_tracks_icon.png"
						} else {
							currentGrouping = "ARTISTS"
							sourceIcon = "qrc:/icons/artist_icon.png"
						}
						if (currentGrouping === "PLAYLISTS") {
							playlistManager.refreshSidebarItems()
						} else {
							localManager.setGrouping(currentGrouping)
						}
					}
				}
			}
            Item {
                Layout.fillWidth: true
                visible: sidebarPane.collapsed
            }
		} // --- END GROUP BY BUTTON

		Loader {
			id: settingsLoader
			onLoaded: { 
				item.openSettings(
                    sidebarPane.currentGrouping,
                    mainWindow.themeColor,
                    mainWindow.defaultDirectory,
                    mainWindow.themeColorList
                );
			}
		}
		Connections { 
			target: settingsLoader.item
			function onSaveRequested(newDirectory, newColor, newGrouping) {
				console.log("[SidebarPane.qml]: Save requested.");
				// Update the properties in the main application
                sidebarPane.currentGrouping = newGrouping;
                mainWindow.themeColor = newColor;
                mainWindow.defaultDirectory = newDirectory;
                // Inform the backend of the change
				localManager.setGrouping(newGrouping);
				localManager.setDefaultMusicPath(newDirectory);
			}
		}

	} // End Sidebar ColumnLayout

	EditPlaylistPopup {
        id: editPlaylistPopup
		onCreateRequested: {
			console.log("[SidebarPane] Playlist created:", name)
			cppPlaylistManager.refreshSidebarItems()
		}
		onEditRequested: {
			console.log("[SidebarPane] Playlist saved:", updatedPlaylist.name)
			cppPlaylistManager.refreshSidebarItems()
		}	
    }
}
