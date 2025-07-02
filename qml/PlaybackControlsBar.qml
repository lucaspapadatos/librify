// PlaybackControlsBar.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.8 // Needed for MediaPlayer type hints
import Qt5Compat.GraphicalEffects

Rectangle {
    id: controlsBar
    height: 80 // Set explicit height for visibility
    width: parent.width
    anchors.left: parent.left
    anchors.right: parent.right
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#FF404045" }
        GradientStop { position: 0.5; color: "#FF303035" }
        GradientStop { position: 1.0; color: "#FF202025" }
    }
    border.color: "#111"; border.width: 1

    // -- PROPERTIES ---
    property bool controlsEnabled: false // Reflects backend readiness
    required property var mediaPlayerInstance // Expecting a MediaPlayer object

    // New properties to be set/bound from Main.qml
    property int trackCount: 0
    property int currentTrackIdx: -1 // For knowing if something *is* playing for prev/next logic nuances

        // --- TRACK NAVIGATION PROPERTIES ---
    property bool hasNextTrack: false // Will be set based on available tracks
    property bool hasPrevTrack: false // Will be set based on available tracks
    signal nextTrackRequested() // Signal to notify parent to change track
    signal prevTrackRequested() // Signal to notify parent to change track
    
    // --- PROGRESS SLIDER PROPERTIES  ---
    property real progressValue: 0.0
    property string progressTextValue: ""
    property bool progressVisible: false

    // --- HELPER FUNCTION for time formatting ---
    function formatTime(ms) {
        if (!mediaPlayerInstance || isNaN(ms) || ms < 0 || mediaPlayerInstance.mediaStatus < MediaPlayer.LoadedMedia) {
             // Show 00:00 if invalid, not loaded, or negative
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

    // --- HELPER FUNCTION for progress update (called by Main.qml) ---
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
        interval: 50 // Delay in ms after release before seeking
        repeat: false // Only run once per start()
        property real seekTargetValue: 0 // Store the value to seek to
        onTriggered: {
            if (mediaPlayerInstance && mediaPlayerInstance.seekable) {
                console.log("[ControlsBar] Seek timer triggered. Setting position to:", seekTargetValue);
                // *** CORRECTED: Set the position property for Qt 6 ***
                mediaPlayerInstance.position = seekTargetValue;
            } else {
                console.warn("[ControlsBar] Seek timer triggered, but seeking not possible.");
            }
        }
    }

    // ***** MAIN LAYOUT *****
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 10
        // --- PLAYBACK CONTROLS LAYOUT Play/Pause/Next/Prev Area ---
        Item {
            id: playbackControlsContainer
            Layout.preferredWidth: parent.width * 0.2
            Layout.fillHeight: true
            anchors.leftMargin: 30
            Row {
                id: playbackControlsLayout
                anchors.centerIn: parent
                spacing: 25

                Image { // PREV Button
                    id: prevButton
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    source: prevMouseArea.pressed ? ":/icons/pressed_prev.png" : ":/icons/unpressed_prev.png"
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
                                    mainWindow.playPrevTrack(); // Call Main.qml function
                                }
                        }
                    }
                    ColorOverlay {
                        id: prevButtonOverlay
                        anchors.fill: parent
                        source: prevButton
                        color: "white"
                        opacity: 0
                        antialiasing: true
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }
                }

                Image { // Play/Pause Button
                    id: playPauseButton
                    width: 50
                    height: 50
                    enabled: controlsEnabled
                    property bool isPlaying: mediaPlayerInstance ?
                        (mediaPlayerInstance.playbackState === MediaPlayer.PlayingState) : false
                    source: isPlaying ? ":/icons/pressed_playpause.png" : ":/icons/unpressed_playpause.png"
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
                                // Let Main.qml handle the logic of whether to scan or play
                                mainWindow.playCurrentOrFirst();
                            }
                        }
                    }
                    ColorOverlay {
                        id: playButtonOverlay
                        anchors.fill: parent
                        source: playPauseButton
                        color: "white"
                        opacity: 0
                        antialiasing: true
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

                Image { // NEXT Button
                    id: nextButton
                    width: 40
                    height: 40
                    y: 5
                    source: nextMouseArea.pressed ? ":/icons/pressed_next.png" : ":/icons/unpressed_next.png"
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
                                mainWindow.playNextTrack(); // Call Main.qml function
                            }
                        }
                    }
                    ColorOverlay {
                        id: nextButtonOverlay
                        anchors.fill: parent
                        source: nextButton
                        color: "white"
                        opacity: 0
                        antialiasing: true
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
        // --- Seek Bar and Time Display Area ---
        Item {
            id: seekAreaContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            RowLayout {
                id: seekAreaLayout
                anchors.fill: parent
                spacing: 8

                // Current Time Label
                Text {
                    id: currentTimeLabel
                    // Text binding simplified - always show formatted player position
                    text: formatTime(mediaPlayerInstance ? mediaPlayerInstance.position : 0)
                    color: "#C0C0C0"
                    font.pixelSize: 12
                    Layout.preferredWidth: 45 // Fixed width
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Position Slider
                Slider {
                    id: positionSlider
                    Layout.fillWidth: true // Take available horizontal space
                    Layout.preferredHeight: 48 // Fixed height for consistent layout
                    Layout.alignment: Qt.AlignVCenter
                    enabled: mediaPlayerInstance && mediaPlayerInstance.seekable // Enable only if seekable

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
                             // Force re-check of enabled state based on status if needed
                             positionSlider.enabled = mediaPlayerInstance && mediaPlayerInstance.seekable;
                        }
                        function onPositionChanged() {
                            // Check if the user is NOT currently dragging the slider
                            if (!positionSlider.pressed) {
                                var newPos = mediaPlayerInstance.position;
                                var dur = mediaPlayerInstance.duration;
                                if (dur > 0 && isFinite(dur) && newPos >= 0 && newPos <= dur) {
                                    // Check difference to avoid jitter from slight backend updates
                                    if (Math.abs(positionSlider.value - newPos) > 100) { // Threshold in ms
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
                                seekTimer.seekTargetValue = value; // Use slider's current value
                                console.log("  > Storing seek target:", seekTimer.seekTargetValue, "and starting timer.");
                                seekTimer.start();
                             } else {
                                console.log("  > Conditions NOT MET for seeking (enabled:", enabled, "player:", mediaPlayerInstance, "). Seek skipped.");
                            }
                        }
                    }

                    // --- BACKGROUND: revER (Concave) ---
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
                                color: "#303030" // Dark shadow
                            }

                            // 2. Main Track Groove (medium grey)
                            Rectangle {
                                id: track // Essential ID
                                width: parent.width
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                radius: height / 2
                                color: "#707070" // Groove base
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
                                color: Qt.rgba(1, 1, 1, 0.3) // Subtle white highlight
                            }

                            // 4. RED Filled Portion (Progress Bar)
                            Rectangle {
                                id: filledTrack
                                anchors.verticalCenter: parent.verticalCenter
                                height: track.height - 2
                                radius: height / 2
                                color: themeColor // RED fill as requested
                                // *** Use control for dynamic width ***
                                width: sliderHandle.x + sliderHandle.width/2 - track.x
                                clip: true
                            }
                        } // End trackContainer
                    } // --- END COPIED BACKGROUND ---
                    // Custom handle (knob) - Using mix_knob.png (wwxww)
                    handle: Rectangle {
                        id: sliderHandle // Unique ID
                        width: 20
                        height: 20
                        x: positionSlider.leftPadding + positionSlider.visualPosition * (positionSlider.availableWidth - width) - 10

                        color: "transparent" // No background color
                        anchors.verticalCenter: parent.verticalCenter
                        // Knob image
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
                    // Use formatTime function, always show total duration
                    text: formatTime(mediaPlayerInstance ? mediaPlayerInstance.duration : 0)
                    color: "#CCCCCC"
                    font.pixelSize: 12
                    Layout.preferredWidth: 45 // Fixed width (adjust if HH:MM:SS needed often)
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            } // End Seek Area Layout
        }
        // --- Volume Controls Area ---
        Item {
            id: volumeControlContainer
            Layout.preferredWidth: parent.width * 0.15
            Layout.fillHeight: true

            RowLayout {
                id: volumeControlLayout
                anchors.fill: parent
                anchors.margins: 5
                spacing: 8
                anchors.rightMargin: 20
                Image { // Volume Button
                    id: volumeIcon
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    source: {
                        if (!cppPlaybackManager) return "qrc:/icons/MAC_CLOSE.png"; // Default if no manager
                        if (cppPlaybackManager.muted || cppPlaybackManager.volume <= 0) return "qrc:/icons/MAC_CLOSE.png"; // Muted or zero volume
                        if (cppPlaybackManager.volume < 0.5) return "qrc:/icons/MAC_MIN.png"; // Low volume
                        return "qrc:/icons/MAC_MAX.png"; // High volume
                    }
                    fillMode: Image.PreserveAspectFit
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true // Always allow hover to show cursor
                        onEntered: {

                        }

                        onClicked: {
                            var currentVol = cppPlaybackManager ? cppPlaybackManager.volume : 0;
                            var currentMuted = cppPlaybackManager ? cppPlaybackManager.muted : true; // Assume muted if no manager

                            if (currentMuted || currentVol <= 0) {
                                cppPlaybackManager?.setMuted(false) // Unmute first
                                cppPlaybackManager?.setVolume(0.5)   // Set to default level
                            } else {
                                cppPlaybackManager?.setMuted(true) // Mute
                            }
                        }
                    }
                }  // End Volume Button
                Slider { // Volume slider
                    id: volumeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    from: 0.0
                    to: 1.0
                    value: cppPlaybackManager ? cppPlaybackManager.volume : 0.35
                    stepSize: 0.01
                    // Set initial volume to 50% when component is completed
                    Component.onCompleted: {
                        if (cppPlaybackManager) {
                            cppPlaybackManager.setVolume(0.35)
                        }
                    }

                    // Update volume when slider value changes
                    onValueChanged: {
                        if (pressed && cppPlaybackManager) { // Only update backend if user interacted
                           cppPlaybackManager.setVolume(value);
                           cppPlaybackManager.setMuted(value <= 0); // Also update mute state based on volume
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

                    // --- CUSTOM BACKGROUND ---
                    background: Item {
                        anchors.fill: parent
                        Item {
                            id: trackContainer1
                            width: parent.width - volumeSlider.leftPadding - volumeSlider.rightPadding
                            height: 8 // Desired height of the main track groove
                            anchors.centerIn: parent

                            // 1. Base "Divot" Shadow (darker bottom edge)
                            Rectangle {
                                width: parent.width
                                height: parent.height / 2
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: parent.height / 4 // Rounded bottom corners of the shadow
                                color: "#303030" // Dark grey shadow
                            }

                            // 2. Main Track Groove (medium grey)
                            Rectangle {
                                id: track1 // *** ID needed for handle alignment and fill calculation ***
                                width: parent.width
                                height: parent.height // Use the container height
                                anchors.verticalCenter: parent.verticalCenter // Center within container
                                radius: height / 2 // Fully rounded ends for the groove
                                color: "#707070" // Medium grey for the groove base
                                border.color: "#505050" // Slightly darker border for definition
                                border.width: 1
                            }

                             // 3. Top Highlight (lighter top edge) - Subtle
                            Rectangle {
                                width: parent.width - 2 // Slightly inset
                                height: 1
                                anchors.top: track1.top
                                anchors.topMargin: 1 // Push down slightly into the groove
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Qt.rgba(1, 1, 1, 0.3) // Semi-transparent white highlight
                            }

                            // 4. COLORED Filled Portion (Progress Bar)
                            //    Place *inside* the trackContainer but *after* base visuals
                            //    so it draws on top.
                            Rectangle {
                                id: filledTrack1
                                anchors.left: track1.left // Position relative to the main 'track' groove
                                anchors.verticalCenter: track1.verticalCenter // Align with the groove center
                                height: track1.height - 2 // Slightly thinner than groove for inset look
                                radius: height / 2       // Match rounding
                                color: themeColor            // The requested fill color
                                // SYNC: Dynamic width based on slider value
                                width: sliderHandle1.x + sliderHandle1.width/2 - track1.x
                                clip: true // Essential for rounded ends on the right
                            }
                        } // End trackContainer
                    } // --- END NEW CUSTOM BACKGROUND ---

                    // Custom handle (knob) - FOR VOLUME
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
            } // End Volume Control Area Layout
        }
    }// ***** End MAIN LAYOUT *****

    // Loading progress overlay (shown while loading tracks)
    Rectangle {
        anchors.fill: parent
        visible: progressVisible
        color: Qt.rgba(0, 0, 0, 0)

        Column {
            anchors.fill: parent
            spacing: 10

            Text {
                text: progressTextValue
                color: "#FFFFFF"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
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
