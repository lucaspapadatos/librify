// Main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15 as QWindow
import QtMultimedia 6.8
import Qt5Compat.GraphicalEffects

// Import the new components (assuming they are in the same directory)
import "."

Window {
    id: mainWindow
    visible: true
    width: 1250
    minimumWidth: 850
    height: 650
    title: "R3D"
    readonly property color themeBatRed: "#E22134"
    readonly property color themeLottaRed: "#A22131"
    readonly property color themeGreen: "#1DB954"
    readonly property color themeAtKnight: "#a6b5ba"
    readonly property color yzyMusic: "#c0c0cc"

    property color themeColor: themeLottaRed

    // Remove default window frame
    flags: Qt.Window | Qt.FramelessWindowHint

    // Custom font declaration
    FontLoader {
        id: customFont
        source: "qrc:/fonts/yeezy_tstar-bold-webfont.ttf"
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
    }

    // --- CUSTOM WINDOW DRAG AREA ---
    property point startMousePos
    property point startWindowPos
    property bool isResizing: false
    property int resizeMargin: 5
    property int resizeEdge: 0 // 0: none, 1: left, 2: right, 3: top, 4: bottom, 5: top-left, 6: top-right, 7: bottom-left, 8: bottom-right

    // --- STATE PROPERTIES ---
    property bool sidebarCollapsed: false
    property int currentlyPlayingIndex: -1 // -1 is none
    property int currentSortColumn: TrackListModel.None // Default using C++ Enum (Ensure Enum accessible or use int 0)
    property int currentSortOrder: Qt.AscendingOrder   // Default to Ascending
    property string sidebarSelected: ""
    property string currentlyPlayingFilePath: ""

    // --- CONSTANTS ---
    readonly property int collapsedSidebarWidth: 40
    readonly property real expandedSidebarRatio: 0.20
    readonly property int titleBarHeight: 40

    // --- flags ---
    property bool backendIsReady: cppPlaybackManager ? cppPlaybackManager.ready : false
    property bool initialLoadAttempted: false // loads default folder upon play button HACK
    property bool isScanningLocalFiles: false
    property bool playAfterNextScan: false
    property bool isMaximized: false
    property bool isMinimized: false

    // --- media player handlers ---
    function playTrackAtIndex(index) {
        if (index >= 0 && index < cppTrackModel.tracks.length) {
            var track = cppTrackModel.tracks[index];
            if (!track || !track.filePath) { // Extra safety
                console.error("[Main] playTrackAtIndex: Track object or filePath is invalid for index", index);
                return;
            }
            var trackUrl = Qt.resolvedUrl(track.filePath);
            if (trackPlayer.source === trackUrl && trackPlayer.playbackState === MediaPlayer.PlayingState) {
                if (currentlyPlayingIndex === index) return; // Truly the same track and index
            }

            trackPlayer.source = trackUrl;
            trackPlayer.play();
            currentlyPlayingIndex = index;
            currentlyPlayingFilePath = track.filePath;
            console.log("[Main] NOW PLAYING:", currentlyPlayingFilePath, "at index", index, "URL:", trackUrl);
        }
    }
    function playCurrentOrFirst() {
        if (cppTrackModel.tracks.length === 0) { // No tracks currently in model
            if (isScanningLocalFiles) {
                console.log("[Main] Scan in progress, user wants to play. Will attempt after scan.");
                mainWindow.playAfterNextScan = true; // Set flag: user clicked play while scan was already ongoing
                return;
            }

            // If not currently scanning and no tracks:
            if (!initialLoadAttempted) { // This is the first time we've encountered no tracks and need to load defaults
                if (cppLocalManager && typeof cppLocalManager.scanDefaultMusicFolder === "function") {
                    console.log("[Main] No tracks, first play click. Initiating default music directory scan.");
                    initialLoadAttempted = true;      // Mark that an attempt to load defaults is being initiated now.
                    mainWindow.playAfterNextScan = true; // Signal that playback should occur after this scan.
                    cppLocalManager.scanDefaultMusicFolder();
                } else {
                    console.warn("[Main] LocalManager not available to scan default folder.");
                    initialLoadAttempted = true; // Still mark, as an attempt was 'conceptually' made.
                }
            } else { // Default load was already attempted in the past (and finished, since not isScanningLocalFiles)
                console.log("[Main] No tracks found after a previous default load attempt.");
                // Do not set playAfterNextScan here, as this wasn't a new request to load and play.
            }
            return; // Exit because either scan started, or determined no tracks after a past attempt
        }

        // --- If tracks ARE available ---
        mainWindow.playAfterNextScan = false; // Clear flag if we are proceeding to play immediately

        if (trackPlayer.playbackState === MediaPlayer.PausedState && currentlyPlayingIndex !== -1) {
            trackPlayer.play();
        } else if (currentlyPlayingIndex !== -1 && cppTrackModel.tracks.length > currentlyPlayingIndex) {
            // If a track is 'current' but stopped (e.g., after an error, or manual stop)
            playTrackAtIndex(currentlyPlayingIndex);
        } else {
            // No current track, or current index invalid, play the first one.
            playTrackAtIndex(0);
        }
    }
    function playPrevTrack() { // Renamed from playPrevTrack for consistency
        if (cppTrackModel.tracks.length === 0) return;

        if (trackPlayer.position > 2000) { // Restart current if playing > 2s
            trackPlayer.position = 0;
        } else {
            var newIndex = currentlyPlayingIndex - 1;
            if (newIndex < 0) {
                newIndex = cppTrackModel.tracks.length - 1; // Wrap around
            }
            if (newIndex === currentlyPlayingIndex && cppTrackModel.tracks.length === 1) {
                 trackPlayer.position = 0; // Restart if only one song
            } else {
                playTrackAtIndex(newIndex);
            }
        }
    }
    function playNextTrack() {
        if (cppTrackModel.tracks.length === 0) return;

        var newIndex = currentlyPlayingIndex + 1;
        if (newIndex >= cppTrackModel.tracks.length) {
            newIndex = 0; // Wrap around
        }
         if (newIndex === currentlyPlayingIndex && cppTrackModel.tracks.length === 1) {
             trackPlayer.position = 0; // Restart if only one song
        } else {
            playTrackAtIndex(newIndex);
        }
    }
    // --- window handlers ---
    function toggleMaximize() {
        if (isMaximized) {
            mainWindow.showNormal();
            isMaximized = false;
        } else {
            mainWindow.showMaximized();
            isMaximized = true;
        }
    }
    function toggleMinimize() {
        if (isMinimized) {
            mainWindow.showNormal();
            isMinimized = false;
        } else {
            mainWindow.showMinimized();
            isMinimized = true;
        }
    }

    // --- MULTIMEDIA OBJECTS ---
    AudioOutput { id: audioOutput }
    MediaPlayer { id: trackPlayer
        audioOutput: audioOutput
        // Event handlers remain here as they manage app-level state (currentlyPlayingIndex)
        onErrorOccurred: {
            console.error("MediaPlayer Error:", trackPlayer.error, trackPlayer.errorString);
            currentlyPlayingIndex = -1; // Reset state on error
        }
        onMediaStatusChanged: {
            if (trackPlayer.mediaStatus === MediaPlayer.EndOfMedia) {
                console.log("[Main] Track finished (EndOfMedia). Playing next.");
                mainWindow.playNextTrack(); // Auto play next
            } else if (trackPlayer.mediaStatus === MediaPlayer.LoadedMedia) {
                console.log("[Main] Media loaded, duration:", trackPlayer.duration);
            } else if (trackPlayer.mediaStatus === MediaPlayer.InvalidMedia) {
                 console.error("[Main] Invalid media:", trackPlayer.source);
                 currentlyPlayingIndex = -1; // Reset if media is bad
            }
        }
        onPlaybackStateChanged: {
            if (trackPlayer.mediaStatus === MediaPlayer.EndOfMedia) {
                console.log("[Main] Track finished (EndOfMedia). **Auto-play next is temporarily disabled for debugging.**");
                // mainWindow.playNextTrack(); // <<<< TEMPORARILY COMMENT THIS OUT
            } else if (trackPlayer.mediaStatus === MediaPlayer.LoadedMedia) {
                console.log("[Main] Media loaded, duration:", trackPlayer.duration);
            } else if (trackPlayer.mediaStatus === MediaPlayer.InvalidMedia) {
                 console.error("[Main] Invalid media:", trackPlayer.source);
                 currentlyPlayingIndex = -1;
            }
            // Add more detailed logging for other statuses if needed
            else {
                console.log("[Main] Media status changed to:", trackPlayer.mediaStatus);
            }
        }
    }

    // --- COMPONENT COMPLETION & SETUP ---
    Component.onCompleted: {
        console.log("[Main] Window mainWindow Completed.")
        if (cppPlaybackManager && typeof cppPlaybackManager.setMediaPlayer === "function") {
            cppPlaybackManager.setMediaPlayer(trackPlayer);
        } else {
            console.error("[Main] Error: Cannot call setMediaPlayer in backend");
        }
    }

    // --- TITLE BAR MULTIPLATFORM ---
    Rectangle {
        id: customTitleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: titleBarHeight
        z: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FF404045" }
            GradientStop { position: 0.5; color: "#FF303035" }
            GradientStop { position: 1.0; color: "#FF202025" }
        }
        border.color: "#111"; border.width: 1
        // App Logo (Left-aligned)
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Image {
                id: titleIcon
                width: 30
                height: 30
                source: ":/icons/pngegg.png"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: titleText
                verticalAlignment: Text.AlignVCenter
                font.family: customFont.name
                font.pixelSize: 24
                anchors.bottomMargin: 10
                text: mainWindow.title
                color: "#ffffff"
            }
        }

        // Search bar (centred default)
        Item {
            id: searchContainer
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.4, 300) // Responsive width
            height: 30
            TextField {
                id: searchField
                anchors.fill: parent
                placeholderText: "Search tracks by " + sidebarSelected
                font.pixelSize: 14
                color: "#ffffff"
                background: Rectangle {
                    color: "transparent"
                    radius: 15
                    border.color: "#555"
                    border.width: 1
                }
                //onTextChanged: cppTrackModel.setFilterString(text)
            }
        }


        // Window Controls (Right-aligned)
        Row {
            id: windowControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15
            rightPadding: 15
            topPadding: 5
            Image { // MIN Button
                id: minButton
                width: 36
                height: 32
                y: 1
                source: "qrc:/icons/MAC_MAX.png"
                smooth: true
                MouseArea {
                    id: minMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: minButtonHoverEffect.opacity = 0.2
                    onExited: minButtonHoverEffect.opacity = 0
                    onClicked: {
                        mainWindow.toggleMinimize()
                    }
                }
                ColorOverlay {
                    id: minButtonHoverEffect
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: parent.height - 12
                    source: minButton
                    color: "black"
                    opacity: 0
                    antialiasing: true
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
            }
            Image { // MAX Button
                id: maxButton
                width: 36
                height: 32
                y: 1
                source: "qrc:/icons/MAC_MAX.png"
                smooth: true
                MouseArea {
                    id: maxMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onEntered: maxButtonHoverEffect.opacity = 0.2
                    onExited: maxButtonHoverEffect.opacity = 0
                    onClicked: {
                        mainWindow.toggleMaximize()
                    }
                }
                ColorOverlay {
                    id: maxButtonHoverEffect
                    anchors.centerIn: parent
                    source: maxButton
                    color: "black"
                    width: parent.width - 8
                    height: parent.height - 12
                    opacity: 0
                    antialiasing: true
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
            }
            Image { // X Button
                id: closeButton
                width: 32
                height: 35
                source: "qrc:/icons/MAC_CLOSE.png"
                smooth: true
                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: closeButtonHoverEffect.opacity = 0.4
                    onExited: closeButtonHoverEffect.opacity = 0
                    onClicked: mainWindow.close()
                }
                ColorOverlay {
                    id: closeButtonHoverEffect
                    anchors.centerIn: parent
                    source: closeButton
                    color: themeColor
                    opacity: 0
                    width: parent.width - 8
                    height: parent.height - 8
                    antialiasing: true
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
            }
        }
        // Allows window dragging
        DragHandler {
            id: titleBarDragHandler
            target: null
            onActiveChanged: {
                if (active) {
                    mainWindow.startSystemMove()
                }
            }
        }
    }

    // --- BACKGROUND ---
    Rectangle {
        anchors.fill: parent;
        gradient: Gradient {
            orientation: Gradient.Vertical;
            GradientStop { position: 0.0; color: "#FF303030" }
            GradientStop { position: 0.5; color: "#FF1A1A1A" }
            GradientStop { position: 1.0; color: "#FF050505" }
        }
    }

    // --- WINDOW RESIZE HANDLERS ---
    // Left edge
    MouseArea {
        id: leftResize
        width: resizeMargin
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        cursorShape: Qt.SizeHorCursor
        onPressed: mainWindow.startSystemResize(Qt.LeftEdge)
    }

    // Right edge
    MouseArea {
        id: rightResize
        width: resizeMargin
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        cursorShape: Qt.SizeHorCursor
        onPressed: mainWindow.startSystemResize(Qt.RightEdge)
    }

    // Bottom edge
    MouseArea {
        id: bottomResize
        height: resizeMargin
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor
        onPressed: mainWindow.startSystemResize(Qt.BottomEdge)
    }

    // Top edge
    MouseArea {
        id: topResize
        height: resizeMargin
        anchors { top: parent.top; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor
        onPressed: mainWindow.startSystemResize(Qt.TopEdge)
        z: 9 // Below title bar but above content
    }

    // Bottom-left corner
    MouseArea {
        id: bottomLeftResize
        width: resizeMargin * 2
        height: resizeMargin * 2
        anchors { bottom: parent.bottom; left: parent.left }
        cursorShape: Qt.SizeBDiagCursor
        onPressed: mainWindow.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }

    // Bottom-right corner
    MouseArea {
        id: bottomRightResize
        width: resizeMargin * 2
        height: resizeMargin * 2
        anchors { bottom: parent.bottom; right: parent.right }
        cursorShape: Qt.SizeFDiagCursor
        onPressed: mainWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }

    // Top-left corner
    MouseArea {
        id: topLeftResize
        width: resizeMargin * 2
        height: resizeMargin * 2
        anchors { top: parent.top; left: parent.left }
        cursorShape: Qt.SizeFDiagCursor
        onPressed: mainWindow.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
        z: 9 // Below title bar but above content
    }

    // Top-right corner
    MouseArea {
        id: topRightResize
        width: resizeMargin * 2
        height: resizeMargin * 2
        anchors { top: parent.top; right: parent.right }
        cursorShape: Qt.SizeBDiagCursor
        onPressed: mainWindow.startSystemResize(Qt.TopEdge | Qt.RightEdge)
        z: 9 // Below title bar but above content
    }

    // --- TOP-LEVEL CONNECTIONS ---
    Connections { // To PlaybackManager for readiness
        target: cppPlaybackManager
        ignoreUnknownSignals: true
        function onReadyChanged() {
            console.log("[Main] Received onReadyChanged. New C++ ready state:", cppPlaybackManager.ready);
            backendIsReady = cppPlaybackManager.ready;
        }
    }

    Connections { // To Spotify Manager for global auth state changes/playlist fetching
        target: cppSpotifyManager
        ignoreUnknownSignals: true
        function onRawPlaylistsFetched(rawPlaylists) {
            console.log("[Main] Spotify rawPlaylistsFetched received, count:", rawPlaylists.length);
            if (typeof cppLocalManager !== "undefined") {
                cppLocalManager.addSpotifyPlaylistsToSidebar(rawPlaylists);
            } else {
                console.error("[Main] cppLocalManager is not defined when rawPlaylistsFetched fired!");
            }
        }
        function onIsAuthenticatedChanged() {
            console.log("[Main] Spotify isAuthenticatedChanged:", cppSpotifyManager.isAuthenticated);
        }
    }

    Connections { // To Local Manager for global events (e.g., progress, errors)
        target: cppLocalManager
        ignoreUnknownSignals: true
        function onLoadingProgress(current, total) {
            // Example: Update a progress bar potentially located in PlaybackControlsBar
            if (playbackControls && playbackControls.updateProgress) { // Assumes method/properties exist on child
                playbackControls.updateProgress(current, total);
            } else {
                // Fallback or log if controls aren't ready/don't have method
            }
        }
        function onLoadingError(errorMsg) {
            console.error("[Main] Local loading error:", errorMsg);
            if (playbackControls && playbackControls.showError) {
                // playbackControls.showError(errorMsg);
            }
        }
        function onScanStateChanged(isScanning) {
            console.log("[Main] Scanning Local Files:", isScanning);
            mainWindow.isScanningLocalFiles = isScanning;

            if (!isScanning) { // Scan has just finished
                console.log("[Main] Scan finished. Tracks available:", cppTrackModel.tracks.length);
                if (mainWindow.playAfterNextScan && cppTrackModel.tracks.length > 0) {
                    if (trackPlayer.playbackState !== MediaPlayer.PlayingState) { // Avoid interrupting if user started something else
                        console.log("[Main] Scan finished, auto-playing first track as requested.");
                        playTrackAtIndex(0);
                    } else {
                        console.log("[Main] Scan finished, play was requested, but something is already playing.");
                    }
                }
                mainWindow.playAfterNextScan = false; // Always reset the flag after a scan finishes
            }
        }
    }

    Connections { // To Track Model (if needed for global reactions beyond list view)
        target: cppTrackModel
        ignoreUnknownSignals: true
        function onTracksChanged() {
            console.log(">>>> QML Connection: TrackModel onTracksChanged received. New Count:", cppTrackModel.tracks.length);
            if (playbackControls) { // Update controls bar with track count
                 playbackControls.trackCount = cppTrackModel.tracks.length;
            }
            // ... rest of your existing onTracksChanged logic for currentPlayingFilePath ...
            if (currentlyPlayingFilePath !== "") {
                var foundNewIndex = -1;
                for (var i = 0; i < cppTrackModel.tracks.length; ++i) {
                    if (cppTrackModel.tracks[i].filePath === currentlyPlayingFilePath) {
                        foundNewIndex = i;
                        break;
                    }
                }
                if (foundNewIndex !== -1 && currentlyPlayingIndex !== foundNewIndex) {
                    console.log("[Main] Playing track", currentlyPlayingFilePath, "moved from index", currentlyPlayingIndex, "to", foundNewIndex);
                    currentlyPlayingIndex = foundNewIndex;
                } else if (foundNewIndex === -1) {
                    console.warn("[Main] Previously playing track", currentlyPlayingFilePath, "not found after tracksChanged. Resetting playback.");
                    currentlyPlayingFilePath = "";
                    currentlyPlayingIndex = -1;
                }
            }
        }
        function onSortCriteriaChanged() {
            mainWindow.currentSortColumn = cppTrackModel.sortColumn;
            mainWindow.currentSortOrder = cppTrackModel.sortOrder;
            console.log("     Main QML Sort State Updated - Column:", mainWindow.currentSortColumn, "Order:", mainWindow.currentSortOrder);
        }
    }

    // --- MAIN CONTENT AREA (Layout Root) ---
    Item {
        id: mainContentArea
        anchors.top: customTitleBar.bottom  // Anchor to custom title bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: playbackControls.top // Anchor to the new controls bar ID
        anchors.margins: 10

        // --- STATES FOR SIDEBAR COLLAPSE ---
        states: [
            State {
                name: "Collapsed"
                when: sidebarCollapsed
                PropertyChanges { target: sidebar; Layout.preferredWidth: collapsedSidebarWidth }
            },
            State {
                name: "Expanded"
                when: !sidebarCollapsed
                PropertyChanges { target: sidebar; Layout.preferredWidth: mainRowLayout.width * expandedSidebarRatio }
            }
        ]
        transitions: [
            Transition {
                NumberAnimation {
                    target: sidebar
                    property: "Layout.preferredWidth"
                    duration: 200; easing.type: Easing.InOutQuad
                }
            }
        ]

        // --- MAIN LAYOUT ---
        RowLayout {
            id: mainRowLayout
            anchors.fill: parent
            spacing: 10

            // --- INSTANTIATE SIDEBAR ---
            SidebarPane {
                id: sidebar // Give it an ID to target in states/transitions
                Layout.fillHeight: true
                localManager: cppLocalManager // Pass C++ object reference directly
                spotifyManager: cppSpotifyManager // Pass C++ object reference directly
                collapsed: sidebarCollapsed // Bind state property
                onCollapseToggleRequested: { // Handle signal coming up from sidebar
                    console.log("[Main] CollapseToggleRequested received");
                    sidebarCollapsed = !sidebarCollapsed; // Toggle state here
                }
                onSidebarSelected: (instance) => {
                    console.log("[Main] Clicked " + instance);
                    mainWindow.sidebarSelected = instance
                }
            } // End SidebarPane Instance

            // --- INSTANTIATE TRACK LIST ---
            TrackListPane {
                id: tracklistPane
                Layout.fillHeight: true
                Layout.fillWidth: true

                // Pass required properties down
                trackModel: cppTrackModel // Pass C++ object reference directly
                currentTrackIndex: mainWindow.currentlyPlayingIndex // Bind playback state

                sortColumn: mainWindow.currentSortColumn
                sortOrder: mainWindow.currentSortOrder

                EditTrackPopup {
                    id: editPopup
                    onSaveRequested: (newData) => {
                        cppLocalManager.writeTrackTags(
                            newData.filePath,
                            newData.title,
                            newData.artist,
                            newData.album,
                            newData.imagePath
                        )
                    }
                }

                // Handle signal coming up from TrackListPane.qml
                onTrackClicked: (index, modelData) => {
                    console.log("---------------------------------------");
                    console.log("[Main] onTrackClicked. Index:", index, "CurrentPlayingIdx:", currentlyPlayingIndex);
                    console.log("[Main] ModelData from delegate:", JSON.stringify(modelData.title));
                    // --- Fetch fresh model data directly from the C++ model using the index ---
                    if (index < 0 || index >= cppTrackModel.tracks.length) {
                        console.error("[Main] Clicked index", index, "is out of bounds for cppTrackModel (length:", cppTrackModel.tracks.length, ")");
                        return;
                    }
                    var freshModelData = cppTrackModel.tracks[index];
                    // --- End fetch ---

                    if (!freshModelData || typeof freshModelData.filePath !== 'string' || freshModelData.filePath === "") {
                        console.error("[Main] Invalid freshModelData or filePath for index", index, "- freshModelData:", JSON.stringify(freshModelData));
                        return;
                    }
                    console.log("[Main] Clicked track (fresh from model):", freshModelData.title, "at index:", index, " (is playing index:", (index === currentlyPlayingIndex), ")");
                    var clickedFilePath = modelData.filePath;
                    var clickedIndex = index;
                    var previousPlayingIndex = currentlyPlayingIndex;
                    if (index === currentlyPlayingIndex) {
                        // Action on the track that is already the 'currentlyPlayingIndex'
                        console.log("[Main] Action on current playing index's item.");
                        if (trackPlayer.source === Qt.resolvedUrl(clickedFilePath) || trackPlayer.source === "") {
                            // And the player source matches this track
                            if (trackPlayer.playbackState === MediaPlayer.PlayingState) {
                                trackPlayer.pause();
                                console.log("[Main] Paused.");
                            } else { // Paused or stopped
                                playTrackAtIndex(index); // This ensures source is correct and plays
                                console.log("[Main] Resumed or started playback for current index.");
                            }
                        } else {
                            // Index matches, but player source is different
                            // (e.g., list changed, index now points to new song, but currentlyPlayingIndex hasn't updated yet from onTracksChanged)
                            // This case means we should definitely play the track at 'index' as if it's new.
                            console.log("[Main] Index matches, but source differs. Playing as new.");
                            playTrackAtIndex(index);
                        }
                    } else {
                        // Clicked on a new track index (this usually comes from a double-click in the delegate).
                        // Single clicks on non-playing items in delegate now only set softSelectedIndex.
                        console.log("[Main] Clicked on a new track index. Playing.");
                        playTrackAtIndex(index); // This sets currentlyPlayingIndex and plays
                    }
                } // End onTrackClicked
                onSortRequested: (columnEnum, order) => {
                    console.log("[Main.qml] Handling onSortRequested. Column:", columnEnum, "Order:", order); // <<< ADD LOG
                    if (cppTrackModel && typeof cppTrackModel.sortTracksBy === 'function') {
                        try { // Add try-catch for C++ call
                            cppTrackModel.sortTracksBy(columnEnum, order);
                            console.log("[Main.qml] Called cppTrackModel.sortTracksBy successfully."); // <<< ADD LOG
                        } catch (e) {
                            console.error("[Main.qml] Error calling cppTrackModel.sortTracksBy:", e); // <<< ADD LOG
                        }
                    } else {
                        console.error("[Main.qml] Cannot call cppTrackModel.sortTracksBy! cppTrackModel:", cppTrackModel); // <<< ADD LOG
                    }
                }
            } // End TrackListPane Instance
        } // End Main RowLayout
    } // End Main Content Area Item


    // --- INSTANTIATE PLAYBACK CONTROLS BAR ---
    PlaybackControlsBar {
        id: playbackControls // Give it an ID for anchoring mainContentArea
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 70 // Keep height defined here

        controlsEnabled: backendIsReady // Pass the readiness flag

        mediaPlayerInstance: trackPlayer // *** Pass the MediaPlayer instance ***
        trackCount: cppTrackModel.tracks.length // Initial value
        currentTrackIdx: mainWindow.currentlyPlayingIndex // Initial value
    } // End PlaybackControlsBar Instance



} // End Window
