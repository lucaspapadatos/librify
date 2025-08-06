// PlaybackControlsBar.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.8 
import Qt5Compat.GraphicalEffects

Rectangle {
	id: controlsBar
	gradient: Gradient {
		GradientStop { position: 0.0; color: Qt.darker(themeColor, 3.0) }
		GradientStop { position: 0.5; color: Qt.darker(themeColor, 4.0) }
		GradientStop { position: 1.0; color: Qt.darker(themeColor, 6.0) }
    }

    // --- PROPERTIES ---
    property bool controlsEnabled: false 
    required property var mediaPlayerInstance 
    property int trackCount: 0
    property int currentTrackIdx: -1 
    property bool hasNextTrack: false
    property bool hasPrevTrack: false
    property real progressValue: 0.0
    property string progressTextValue: ""
    property bool progressVisible: false

	// --- SIGNALS --- 
	signal nextTrackRequested() 
	signal prevTrackRequested()

	// --- FONTS ---
    FontLoader {
        id: retroFont
        source: "qrc:/fonts/disc-operating-sans-serif.ttf"
	}	
    
    // --- FUNCTIONS ---
    function formatTime(ms) {
        if (!mediaPlayerInstance || isNaN(ms) || ms < 0 || mediaPlayerInstance.mediaStatus < MediaPlayer.LoadedMedia) {
             return "00:00";
        }
        var totalSeconds = Math.floor(ms / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        var minStr = minutes < 10 ? "0" + minutes : minutes;
        var secStr = seconds < 10 ? "0" + seconds : seconds;
        if (hours > 0) {
            return hours + ":" + minStr + ":" + secStr;
        } else {
            return minStr + ":" + secStr;
        }
    }
    function updateProgress(current, total) {
        if (total > 0 && current < total) {
            progressValue = current / total;
            progressTextValue = "Loading Tracks: " + current + " / " + total;
            progressVisible = true;
        } else {
            progressValue = (total > 0) ? 1.0 : 0;
            progressTextValue = "";
            progressVisible = false;
        }
    }

    // --- TIMER for delayed seek ---
    Timer {
        id: seekTimer
        interval: 50 
        repeat: false
        property real seekTargetValue: 0 
        onTriggered: {
            if (mediaPlayerInstance && mediaPlayerInstance.seekable) {
                console.log("[ControlsBar] Seek timer triggered. Setting position to:", seekTargetValue);
                mediaPlayerInstance.position = seekTargetValue;
            } else {
                console.warn("[ControlsBar] Seek timer triggered, but seeking not possible.");
            }
        }
    }

	// --- MAIN UI LAYOUT ---
    RowLayout {
		id: mainLayout; 
		spacing: 15; anchors.fill: parent;

		Item {
			Layout.preferredWidth: mainLayout.width * 0.2
		}

		// CENTRAL STACK
		ColumnLayout {
			Layout.preferredWidth: mainLayout.width * 0.6;
			// SEEK BAR AND TIME DISPLAY
			RowLayout {
				Layout.fillWidth: true
				spacing: 8
				Text {
					id: currentTimeLabel
					text: formatTime(mediaPlayerInstance ? mediaPlayerInstance.position : 0)
					color: "#C0C0C0"
					font.pixelSize: 14
					font.family: retroFont.name
					Layout.preferredWidth: 45
					horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
				}
				Slider {
					id: positionSlider
					Layout.fillWidth: true; Layout.preferredHeight: 10; Layout.alignment: Qt.AlignVCenter
					enabled: mediaPlayerInstance && mediaPlayerInstance.seekable
					from: 0
					to: mediaPlayerInstance ? mediaPlayerInstance.duration : 0
					value: {
						var pos = mediaPlayerInstance ? mediaPlayerInstance.position : 0;
						var dur = mediaPlayerInstance ? mediaPlayerInstance.duration : 0;
						(dur > 0 && isFinite(dur) && pos >= 0 && pos <= dur) ? pos : 0;
					}
					Connections {
						target: mediaPlayerInstance
						ignoreUnknownSignals: true
						function onSeekableChanged() {
							console.log("[ControlsBar] MediaPlayer seekable changed:", mediaPlayerInstance.seekable);
							positionSlider.enabled = mediaPlayerInstance && mediaPlayerInstance.seekable;
						}
						function onMediaStatusChanged() {
							 console.log("[ControlsBar] MediaPlayer mediaStatus changed:", mediaPlayerInstance.mediaStatus);
							 positionSlider.enabled = mediaPlayerInstance && mediaPlayerInstance.seekable;
						}
						function onPositionChanged() {
							// Check if the user is NOT currently dragging the slider
							if (!positionSlider.pressed) {
								var newPos = mediaPlayerInstance.position;
								var dur = mediaPlayerInstance.duration;
								if (dur > 0 && isFinite(dur) && newPos >= 0 && newPos <= dur) {
									// Check difference to avoid jitter from slight backend updates
									if (Math.abs(positionSlider.value - newPos) > 100) { 
										positionSlider.value = newPos;
									}
								} else if (positionSlider.value !== 0) {
									positionSlider.value = 0; // Reset if duration becomes invalid
								}
							}
						}
						function onDurationChanged() {
							 // Update the 'to' value when duration changes
							positionSlider.to = mediaPlayerInstance.duration > 0 && isFinite(mediaPlayerInstance.duration)
												? mediaPlayerInstance.duration
												: 0; // Set to 0 if invalid
						}
					}
					onPressedChanged: {
						if (pressed) {
							// User started dragging
							if (seekTimer.running) {
								console.log("[ControlsBar] Slider pressed while seek timer running - stopping timer.");
								seekTimer.stop();
							}
							console.log("[ControlsBar] Slider pressed.");
						} else {
							// User released the slider
							console.log("[ControlsBar] Slider released (pressed is false).");
							if (enabled && mediaPlayerInstance) {
								// Start the seek timer using the slider's value *at release*
								seekTimer.seekTargetValue = value;
								console.log("  > Storing seek target:", seekTimer.seekTargetValue, "and starting timer.");
								seekTimer.start();
							 } else {
								console.log("  > Conditions NOT MET for seeking (enabled:", enabled, "player:", mediaPlayerInstance, "). Seek skipped.");
							}
						}
					}
					background: Item {
						anchors.fill: parent
						Item {
							id: trackContainer
							width: parent.width - positionSlider.leftPadding - positionSlider.rightPadding
							height: 8
							anchors.centerIn: parent
							// 1. Base "Divot" Shadow (darker bottom edge) - CONCAVE
							Rectangle {
								width: parent.width
								height: parent.height / 2
								anchors.bottom: parent.bottom
								anchors.horizontalCenter: parent.horizontalCenter
								radius: parent.height / 4
								color: "#303030"
							}
							// 2. Main Track Groove (medium grey)
							Rectangle {
								id: track // Essential ID
								width: parent.width
								height: parent.height
								anchors.verticalCenter: parent.verticalCenter
								radius: height / 2
								color: "#707070"
								border.color: "#505050"
								border.width: 1
							}
							// 3. Top Highlight (lighter top edge) - CONCAVE
							Rectangle {
								width: parent.width - 2
								height: 1
								anchors.top: track.top
								anchors.topMargin: 1
								anchors.horizontalCenter: parent.horizontalCenter
								color: Qt.rgba(1, 1, 1, 0.3)
							}
							// 4. RED Filled Portion (Progress Bar)
							Rectangle {
								id: filledTrack
								anchors.verticalCenter: parent.verticalCenter
								height: track.height - 2
								radius: height / 2
								color: themeColor
								width: sliderHandle.x + sliderHandle.width/2 - track.x
								clip: true
							}
						}
					}
					handle: Rectangle {
						id: sliderHandle
						width: 20
						height: 20
						x: positionSlider.leftPadding + positionSlider.visualPosition * (positionSlider.availableWidth - width) - 10
						color: "transparent"
						anchors.verticalCenter: parent.verticalCenter
						Image {
							source: "qrc:/icons/slider_knob.png"
							anchors.fill: parent
							fillMode: Image.PreserveAspectFit
							smooth: true
						}
						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							preventStealing: false
							propagateComposedEvents: true
							onPressed: (mouse) => { mouse.accepted = false }
							onReleased: (mouse) => { mouse.accepted = false }
						}
					}
				} // End Position Slider
				Text { // Total Time Label
					id: totalTimeLabel
					text: formatTime(mediaPlayerInstance ? mediaPlayerInstance.duration : 0)
					color: "#CCCCCC"
					font.pixelSize: 14
					font.family: retroFont.name
					Layout.preferredWidth: 45
					horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignVCenter
				}
			} // END PROGRESS BAR ROWLAYOUT

			// PLAYBACK CONTROLS
			Row {
				Layout.alignment: Qt.AlignHCenter
				spacing: 35
				Image {
					id: prevButton; 
					width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter
					source: prevMouseArea.pressed ? "qrc:/icons/pressed_prev.png" : "qrc:/icons/unpressed_prev.png"
					fillMode: Image.PreserveAspectFit
					smooth: true
					MouseArea {
						id: prevMouseArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: prevButtonOverlay.opacity = 0.2
						onExited: prevButtonOverlay.opacity = 0
						onClicked: {
							if (controlsEnabled && trackCount > 0) {
									mainWindow.playPrevTrack(); 
							}
						}
					}
					ColorOverlay {
						id: prevButtonOverlay
						source: prevButton
						anchors.fill: parent; color: "white"; opacity: 0; antialiasing: true
						Behavior on opacity { NumberAnimation { duration: 100 } }
					}
				}
				Image {
					id: playPauseButton
					width: 50; height: 50; anchors.verticalCenter: parent.verticalCenter
					enabled: controlsEnabled
					property bool isPlaying: mediaPlayerInstance ?
						(mediaPlayerInstance.playbackState === MediaPlayer.PlayingState) : false
					source: isPlaying ? "qrc:/icons/pressed_playpause.png" : "qrc:/icons/unpressed_playpause.png"
					MouseArea {
						id: playMouseArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: playButtonOverlay.opacity = 0.2
						onExited: playButtonOverlay.opacity = 0
						onClicked: {
							console.log("[PlaybackControlsBar] Play/Pause toggled. ControlsEnabled:", controlsEnabled)
							if (!controlsEnabled) {
								console.warn("[PlaybackControlsBar] Audio backend not ready.");
								return;
							}
							if (mediaPlayerInstance.playbackState === MediaPlayer.PlayingState) {
								mediaPlayerInstance.pause();
							} else {
								mainWindow.playCurrentOrFirst();
							}
						}
					}
					ColorOverlay {
						id: playButtonOverlay
						source: playPauseButton
						anchors.fill: parent; color: "white"; opacity: 0; antialiasing: true
						Behavior on opacity { NumberAnimation { duration: 100 } }
					}
					Connections {
						target: mediaPlayerInstance
						ignoreUnknownSignals: true
						function onPlaybackStateChanged() {
							console.log("[PlaybackControlsBar] Playback state changed:",
										mediaPlayerInstance.playbackState);
							playPauseButton.isPlaying = mediaPlayerInstance.playbackState === MediaPlayer.PlayingState;
						}
					}
				}
				Image {
					id: nextButton
					width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter
					source: nextMouseArea.pressed ? "qrc:/icons/pressed_next.png" : "qrc:/icons/unpressed_next.png"
					fillMode: Image.PreserveAspectFit
					smooth: true
					MouseArea {
						id: nextMouseArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: nextButtonOverlay.opacity = 0.2
						onExited: nextButtonOverlay.opacity = 0
						onClicked: {
							if (controlsEnabled && trackCount > 0) {
								mainWindow.playNextTrack();
							}
						}
					}
					ColorOverlay {
						id: nextButtonOverlay
						source: nextButton
						anchors.fill: parent; color: "white"; opacity: 0; antialiasing: true
						Behavior on opacity { NumberAnimation { duration: 100 } }
					}
				}
			} // END PLAYBACK CONTROLS
		} // END CENTRAL STACK

		RowLayout {
			Layout.preferredWidth: mainLayout.width * 0.2;
			Layout.fillHeight: true
			// VOLUME STACK
			Image {
				id: volumeIcon
				Layout.preferredWidth: 24; Layout.preferredHeight: 24; Layout.alignment: Qt.AlignVCenter
				source: {
					if (cppPlaybackManager.muted || cppPlaybackManager.volume <= 0) 
						return "qrc:/icons/MAC_CLOSE.png"; // Muted or zero volume
					if (cppPlaybackManager.volume < 0.5) 
						return "qrc:/icons/MAC_MIN.png"; // Low volume
					return "qrc:/icons/MAC_MAX.png"; // High volume
				}
				fillMode: Image.PreserveAspectFit
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: {
						// todo: add highlighting to volume icon
					}
					onClicked: {
						var currentVol = cppPlaybackManager ? cppPlaybackManager.volume : 0;
						var currentMuted = cppPlaybackManager ? cppPlaybackManager.muted : true;
						if (currentMuted || currentVol <= 0) {
							cppPlaybackManager?.setMuted(false) // Unmute first
							cppPlaybackManager?.setVolume(0.5)   // Set to default level
						} else {
							cppPlaybackManager?.setMuted(true) // Mute
						}
					}
				}
			}
			Slider {
				id: volumeSlider
				Layout.fillWidth: true; Layout.minimumWidth: mainLayout.width / 8
				Layout.alignment: Qt.AlignVCenter; Layout.rightMargin: 15
				from: 0.0; to: 1.0
				value: cppPlaybackManager ? cppPlaybackManager.volume : 0.35
				stepSize: 0.01
				// Set initial volume to 50% when component is completed
				Component.onCompleted: {
					if (cppPlaybackManager) {
						cppPlaybackManager.setVolume(0.35)
					}
				}
				onValueChanged: {
					if (pressed && cppPlaybackManager) {
					   cppPlaybackManager.setVolume(value);
					   cppPlaybackManager.setMuted(value <= 0);
					}
				}
				// Listen for volume changes from the backend
				Connections {
					target: cppPlaybackManager
					ignoreUnknownSignals: true
					function onVolumeChanged() {
						if (Math.abs(volumeSlider.value - cppPlaybackManager.volume) > volumeSlider.stepSize / 2) {
							volumeSlider.value = cppPlaybackManager.volume;
						}
					}
					function onMutedChanged() {
						 // If muted externally, potentially set slider value to 0 or adjust visual
						 if (cppPlaybackManager.muted && volumeSlider.value > 0) {
							 // Ensure volume change reflects mute:
							 if(cppPlaybackManager.volume > 0) {
								 cppPlaybackManager.setVolume(0);
							 }
						 }
					 }
				}
				background: Item {
					anchors.fill: parent
					Item {
						id: trackContainer1
						width: parent.width - volumeSlider.leftPadding - volumeSlider.rightPadding
						height: 8
						anchors.centerIn: parent
						// 1. Base "Divot" Shadow (darker bottom edge)
						Rectangle {
							width: parent.width
							height: parent.height / 2
							anchors.bottom: parent.bottom
							anchors.horizontalCenter: parent.horizontalCenter
							radius: parent.height / 4
							color: "#303030"
						}
						// 2. Main Track Groove (medium grey)
						Rectangle {
							id: track1
							width: parent.width
							height: parent.height
							anchors.verticalCenter: parent.verticalCenter
							radius: height / 2
							color: "#707070"
							border.color: "#505050"
							border.width: 1
						}
						 // 3. Top Highlight (lighter top edge) - Subtle
						Rectangle {
							width: parent.width - 2
							height: 1
							anchors.top: track1.top
							anchors.topMargin: 1
							anchors.horizontalCenter: parent.horizontalCenter
							color: Qt.rgba(1, 1, 1, 0.3)
						}
						// 4. COLORED Filled Portion (Progress Bar)
						Rectangle {
							id: filledTrack1
							anchors.left: track1.left
							anchors.verticalCenter: track1.verticalCenter
							height: track1.height - 2
							radius: height / 2  
							color: themeColor    
							width: sliderHandle1.x + sliderHandle1.width/2 - track1.x
							clip: true
						}
					}
				}
				handle: Rectangle {
					id: sliderHandle1
					width: 18
					height: 18
					color: "transparent"
					x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
					anchors.verticalCenter: parent.verticalCenter
					Image {
						source: "qrc:/icons/slider_knob.png"
						anchors.fill: parent
						fillMode: Image.PreserveAspectFit
						smooth: true
					}
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						preventStealing: false
						propagateComposedEvents: true
						onPressed: (mouse) => { mouse.accepted = false }
						onReleased: (mouse) => { mouse.accepted = false }
					}
				}
			} // End Volume Slider
		} // End VOLUME STACK

    } // --- END MAIN UI LAYOUT ---

    // Loading progress overlay (shown while loading tracks)
    Rectangle {
        anchors.fill: parent; visible: progressVisible; color: Qt.rgba(0, 0, 0, 0)
        Column {
            anchors.fill: parent; spacing: 10
            Text {
				color: "#FFFFFF"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter
				text: progressTextValue
            }
            Rectangle {
                width: 200
                height: 8
                color: "#303030"
                radius: 4
				anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: parent.width * progressValue
                    height: parent.height
                    color: themeColor
                    radius: 4
                }
            }
        }
    }
}
