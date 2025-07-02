// TrackListPane.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects // For DropShadow effect
import QtQuick.Window 2.15

// Root item is a Rectangle that behaves like the TrackListPane
Rectangle {
    id: tracklistPane
    property real rowScale: 1.0
    property real titleColumnFlex: 0.4
    property real artistColumnFlex: 0.3
    readonly property real albumColumnFlex: Math.max(0.15, 1.0 - titleColumnFlex - artistColumnFlex)

    QtObject {
        id: currentFlexValues
        property real title: tracklistPane.titleColumnFlex
        property real artist: tracklistPane.artistColumnFlex
        property real album: tracklistPane.albumColumnFlex
    }

    readonly property int splitterInteractiveWidth: 8
    readonly property int splitterVisualWidth: 1
    readonly property real baseImageSize: 55
    readonly property real baseRowHeight: 65
    readonly property real baseFontSize: 14
    readonly property real scrollSpeedMultiplier: 2.0

    required property var trackModel
    required property int currentTrackIndex
    property int sortColumn: TrackListModel.None // Assuming TrackListModel.None is defined
    property int sortOrder: Qt.AscendingOrder

    signal trackClicked(int index, variant modelData)
    signal sortRequested(int columnEnum, int order)

    color: Qt.darker(themeColor, 3.5) // Very dark version of theme for main background
    border.color: Qt.darker(themeColor, 2.0)
    border.width: 1
    radius: 5
    clip: true

    FontLoader {
        id: customFont
        source: "qrc:/fonts/yeezy_tstar-bold-webfont.ttf"
    }

    // SORT Header Component Definition with ThemeColor-based CRT Design
    Component {
        id: headerComponent
        Rectangle {
            id: headerRoot
            property int columnId
            property string columnName

            implicitHeight: 35
            Layout.minimumWidth: 80
            radius: 2
            clip: true

            // --- CRT Theme Properties derived from tracklistPane.themeColor ---
            readonly property color crtDefaultBgColor: Qt.rgba(themeColor.r * 0.1, themeColor.g * 0.1, themeColor.b * 0.1, 0.9)
            readonly property color crtHoverBgColor: Qt.rgba(themeColor.r * 0.15, themeColor.g * 0.15, themeColor.b * 0.15, 0.95)
            readonly property color crtActiveBgColor: Qt.rgba(themeColor.r * 0.2, themeColor.g * 0.2, themeColor.b * 0.2, 1.0)
            readonly property color crtScanlineColor: Qt.rgba(0,0,0, 0.25)

            readonly property color crtDefaultTextColor: Qt.lighter(themeColor, 1.5)
            readonly property color crtHoverTextColor: Qt.lighter(themeColor, 1.8)
            readonly property color crtActiveTextColor: Qt.lighter(themeColor, 2.2)

            readonly property color crtDefaultGlowColor: Qt.rgba(crtDefaultTextColor.r, crtDefaultTextColor.g, crtDefaultTextColor.b, 0.35)
            readonly property color crtHoverGlowColor: Qt.rgba(crtHoverTextColor.r, crtHoverTextColor.g, crtHoverTextColor.b, 0.45)
            readonly property color crtActiveGlowColor: Qt.rgba(crtActiveTextColor.r, crtActiveTextColor.g, crtActiveTextColor.b, 0.55)

            readonly property bool isHovered: mouseArea.containsMouse
            readonly property bool isActive: tracklistPane.sortColumn === columnId

            color: isActive ? crtActiveBgColor : (isHovered ? crtHoverBgColor : crtDefaultBgColor)
            border.color: isActive ? crtActiveTextColor : (isHovered ? crtHoverTextColor : Qt.darker(crtDefaultTextColor, 1.2))
            border.width: 1

            Repeater { // Scan Lines
                width: headerRoot.width
                model: Math.floor(headerRoot.height / 3)
                visible: headerRoot.height > 15
                delegate: Rectangle {
                    x: 0; y: index * 3; width: headerRoot.width; height: 1
                    color: headerRoot.crtScanlineColor
                }
            }

            Text { // Header Text
                id: headerTextElement
                font.family: customFont.name
                anchors.centerIn: parent
                anchors.leftMargin: 6; anchors.rightMargin: 6
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: tracklistPane.headerText(headerRoot.columnId, headerRoot.columnName)
                color: headerRoot.isActive ? headerRoot.crtActiveTextColor : (headerRoot.isHovered ? headerRoot.crtHoverTextColor : headerRoot.crtDefaultTextColor)
                font.pointSize: 9

                layer.enabled: true
                layer.effect: DropShadow { // Glow Effect
                    anchors.fill: headerTextElement
                    horizontalOffset: 0; verticalOffset: 0
                    radius: 7.0; samples: 17
                    color: {
                        if (headerRoot.isActive) return headerRoot.crtActiveGlowColor;
                        if (headerRoot.isHovered) return headerRoot.crtHoverGlowColor;
                        return headerRoot.crtDefaultGlowColor;
                    }
                    spread: 0.15
                }
            }

            MouseArea { // Interaction
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var nextOrder = Qt.AscendingOrder;
                    if (tracklistPane.sortColumn === headerRoot.columnId) {
                        nextOrder = (tracklistPane.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder);
                    }
                    tracklistPane.sortRequested(headerRoot.columnId, nextOrder);
                }
            }
        }
    }

    function headerText(columnEnum, columnName) { // Unchanged
        if (tracklistPane.sortColumn === columnEnum) {
            return columnName + (tracklistPane.sortOrder === Qt.AscendingOrder ? " ▲" : " ▼");
        }
        return columnName;
    }

    ColumnLayout {
        id: trackListColumn
        anchors.fill: parent
        anchors.margins: 8

        RowLayout { // Header Row
            id: headerRow
            Layout.fillWidth: true
            spacing: 0
            property real availableWidthForHeaders: trackListColumn.width - (tracklistPane.splitterInteractiveWidth * 2)

            Loader { // Title Header
                id: titleHeaderLoader; sourceComponent: headerComponent
                Layout.preferredWidth: headerRow.availableWidthForHeaders * tracklistPane.titleColumnFlex
                onLoaded: { item.columnId = TrackListModel.Title; item.columnName = "TITLE"; }
            }
            Rectangle { // Splitter 1
                id: splitterTitleArtist
                width: tracklistPane.splitterInteractiveWidth
                Layout.preferredHeight: parent.height
                color: "transparent"
                Rectangle { // Visual line
                    width: tracklistPane.splitterVisualWidth; height: parent.height * 0.6
                    anchors.centerIn: parent
                    color: Qt.darker(tracklistPane.themeColor, 1.8) // Themed splitter line
                }
                DragHandler {
                    target: null; xAxis.enabled: true; yAxis.enabled: false; property real initialTitleFlex: 0; property real initialArtistFlex: 0
                    onActiveChanged: { if (active) { initialTitleFlex = tracklistPane.titleColumnFlex; initialArtistFlex = tracklistPane.artistColumnFlex; } }
                    onTranslationChanged: {
                        var deltaX = translation.x; if (headerRow.availableWidthForHeaders <= 0) return;
                        var deltaFlex = deltaX / headerRow.availableWidthForHeaders;
                        var newTitleFlex = initialTitleFlex + deltaFlex; var newArtistFlex = initialArtistFlex - deltaFlex;
                        var minFlex = 0.15; var maxFlexForFirstTwo = 1.0 - minFlex;
                        newTitleFlex = Math.max(minFlex, newTitleFlex); newArtistFlex = Math.max(minFlex, newArtistFlex);
                        if (newTitleFlex + newArtistFlex > maxFlexForFirstTwo) {
                            if (deltaFlex > 0) { newTitleFlex = maxFlexForFirstTwo - newArtistFlex; } else { newArtistFlex = maxFlexForFirstTwo - newTitleFlex; }
                            newTitleFlex = Math.max(minFlex, newTitleFlex); newArtistFlex = Math.max(minFlex, newArtistFlex);
                        }
                        tracklistPane.titleColumnFlex = newTitleFlex; tracklistPane.artistColumnFlex = newArtistFlex;
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.SplitHCursor; acceptedButtons: Qt.LeftButton }
            }
            Loader { // Artist Header
                id: artistHeaderLoader; sourceComponent: headerComponent
                Layout.preferredWidth: headerRow.availableWidthForHeaders * tracklistPane.artistColumnFlex
                onLoaded: { item.columnId = TrackListModel.ArtistAlbum; item.columnName = "ARTIST"; }
            }
            Rectangle { // Splitter 2
                id: splitterArtistAlbum
                width: tracklistPane.splitterInteractiveWidth
                Layout.preferredHeight: parent.height
                color: "transparent"
                Rectangle { // Visual line
                    width: tracklistPane.splitterVisualWidth; height: parent.height * 0.6
                    anchors.centerIn: parent
                    color: Qt.darker(tracklistPane.themeColor, 1.8) // Themed splitter line
                }
                DragHandler { /* ... existing DragHandler logic ... */
                    target: null; xAxis.enabled: true; yAxis.enabled: false; property real initialArtistFlex: 0; property real initialAlbumFlexHint: 0
                    onActiveChanged: { if (active) { initialArtistFlex = tracklistPane.artistColumnFlex; initialAlbumFlexHint = tracklistPane.albumColumnFlex; } }
                    onTranslationChanged: {
                        var deltaX = translation.x; if (headerRow.availableWidthForHeaders <= 0) return;
                        var deltaFlex = deltaX / headerRow.availableWidthForHeaders;
                        var newArtistFlex = initialArtistFlex + deltaFlex;
                        var minFlex = 0.15; var maxArtistFlex = 1.0 - tracklistPane.titleColumnFlex - minFlex;
                        newArtistFlex = Math.min(newArtistFlex, maxArtistFlex); newArtistFlex = Math.max(minFlex, newArtistFlex);
                        tracklistPane.artistColumnFlex = newArtistFlex;
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.SplitHCursor; acceptedButtons: Qt.LeftButton }
            }
            Loader { // Album Header
                id: albumHeaderLoader; sourceComponent: headerComponent
                Layout.preferredWidth: headerRow.availableWidthForHeaders * tracklistPane.albumColumnFlex
                onLoaded: { item.columnId = TrackListModel.Album; item.columnName = "ALBUM"; }
            }
        }

        ListView {
            id: localTrackView
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; cacheBuffer: 200
            model: tracklistPane.trackModel ? tracklistPane.trackModel.tracks : null
            currentIndex: tracklistPane.currentTrackIndex
            property int softSelectedIndex: -1

            delegate: Rectangle {
                id: delegateRoot
                width: localTrackView.width
                height: tracklistPane.baseRowHeight * tracklistPane.rowScale
                clip: true

                readonly property real _actualAlbumArtWidth: Math.max(0, tracklistPane.baseImageSize * tracklistPane.rowScale)
                readonly property real _delegateContentRowHorizontalMargins: (delegateContentRow.anchors.leftMargin + delegateContentRow.anchors.rightMargin)
                readonly property real _availableWidthInContentRow: delegateRoot.width - _delegateContentRowHorizontalMargins
                readonly property real _widthAllocatedToTrackInfoTextLayout: Math.max(0, _availableWidthInContentRow - _actualAlbumArtWidth - delegateContentRow.spacing)

                readonly property bool isPlayingTrack: tracklistPane.currentTrackIndex === index
                readonly property bool isSoftSelected: localTrackView.softSelectedIndex === index && !isPlayingTrack
                property bool isPressedByMouse: false // For visual pressed state

                readonly property color baseBackgroundColor: {
                    var base = index % 2 ? Qt.rgba(themeColor.r * 0.18, themeColor.g * 0.18, themeColor.b * 0.18, 0.75)
                                          : Qt.rgba(themeColor.r * 0.22, themeColor.g * 0.22, themeColor.b * 0.22, 0.75);
                    return (isPressedByMouse && !isPlayingTrack && !isSoftSelected) ? Qt.darker(base, 1.3) : base;
                }
                color: isPlayingTrack ? "transparent" : baseBackgroundColor
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: {
                            if (isPlayingTrack) return Qt.rgba(themeColor.r, themeColor.g, themeColor.b, 0.55);
                            return index % 2 ? Qt.rgba(themeColor.r * 0.2, themeColor.g * 0.2, themeColor.b * 0.2, 0.7)
                                             : Qt.rgba(themeColor.r * 0.25, themeColor.g * 0.25, themeColor.b * 0.25, 0.7);
                        }
                    }
                    GradientStop {
                        position: 1.0
                        color: {
                            if (isPlayingTrack) return Qt.rgba(themeColor.r * 0.8, themeColor.g * 0.8, themeColor.b * 0.8, 0.45);
                            return index % 2 ? Qt.rgba(themeColor.r * 0.15, themeColor.g * 0.15, themeColor.b * 0.15, 0.7)
                                             : Qt.rgba(themeColor.r * 0.2, themeColor.g * 0.2, themeColor.b * 0.2, 0.7);
                        }
                    }
                }
                border.color: isPlayingTrack ? Qt.lighter(themeColor, 1.2) : Qt.darker(themeColor, 1.5)
                border.width: isPlayingTrack ? 2 : 1

                // --- SOFT SELECT OVERLAY ---
                Rectangle {
                    id: softSelectOverlay
                    anchors.fill: parent
                    height: hoverOverlay * 0.8; width: hoverOverlay * 0.8; radius: parent.radius + 30
                    color: Qt.rgba(themeColor.r * 0.7, themeColor.g * 0.7, themeColor.b * 0.7, 0.20)
                    visible: delegateRoot.isSoftSelected
                    Behavior on opacity { OpacityAnimator { duration: 80 } }
                    opacity: visible ? 1 : 0
                }

                // --- HOVER OVERLAY ---
                Rectangle {
                    id: hoverOverlay
                    anchors.fill: parent
                    color: Qt.rgba(themeColor.r, themeColor.g, themeColor.b, 0.15) // 15% opacity of themeColor
                    visible: delegateMouseArea.containsMouse
                    radius: parent.radius + 30
                    opacity: visible ? 0.5 : 0
                }

                MouseArea { // delegateMouseArea
                    id: delegateMouseArea;
                    anchors.fill: parent;
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true; propagateComposedEvents: true
                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            delegateRoot.isPressedByMouse = true;
                        }
                    }

                    onReleased: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            delegateRoot.isPressedByMouse = false;
                        }
                    }
                    onCanceled: { delegateRoot.isPressedByMouse = false; }
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            if (typeof editTrackPopup !== 'undefined') { editTrackPopup.openForTrack(modelData); } else { console.warn("editTrackPopup not found!") }
                        }
                        // Left Click Logic
                        if (mouse.button === Qt.LeftButton) {
                           // --- Fetch fresh model data ---
                           var currentItemData = null;
                           if (index >= 0 && index < localTrackView.model.length) {
                               currentItemData = localTrackView.model[index];
                           }
                           if (!currentItemData) {
                               console.warn("Delegate onClicked: Could not get valid modelData for index", index);
                               return;
                           }
                           // --- End fetch ---

                           if (isPlayingTrack) { // Single click on a playing track
                               console.log("Delegate: Single click on PLAYING track", index);
                               // Request Main.qml to handle pause/play toggle for this track
                               tracklistPane.trackClicked(index, currentItemData);
                           } else if (localTrackView.softSelectedIndex === index) { // Single click on an already soft-selected track
                               console.log("Delegate: Single click on SOFT-SELECTED track", index, "-> Deselecting.");
                               localTrackView.softSelectedIndex = -1; // Deselect
                           } else { // Single click on a non-playing, non-soft-selected track
                               console.log("Delegate: Single click on NEW track", index, "-> Soft selecting.");
                               localTrackView.softSelectedIndex = index; // Soft select it
                               // DO NOT play on single click
                           }
                        }
                    }
                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            // --- Fetch fresh model data ---
                            var currentItemData = null;
                            if (index >= 0 && index < localTrackView.model.length) {
                                currentItemData = localTrackView.model[index];
                            }
                            if (!currentItemData) {
                                console.warn("Delegate onDoubleClicked: Could not get valid modelData for index", index);
                                return;
                            }
                            // --- End fetch ---

                            console.log("Delegate: Double click on track", index, "-> Requesting play.");
                            tracklistPane.trackClicked(index, currentItemData); // Always request play on double click
                            localTrackView.softSelectedIndex = index; // Also make it soft-selected
                        }
                    }
                    onWheel: function(wheel) {
                        if (wheel.modifiers & Qt.ControlModifier) { // Ctrl + Wheel for zooming
                            tracklistPane.rowScale = Math.min(2.0, Math.max(0.5, tracklistPane.rowScale + (wheel.angleDelta.y > 0 ? 0.1 : -0.1)));
                            wheel.accepted = true; // Consume the event
                        } else { // Normal Wheel Scroll
                            var itemCurrentHeight = tracklistPane.baseRowHeight * tracklistPane.rowScale;
                            var scrollAmountPerStandardTick = itemCurrentHeight * tracklistPane.scrollSpeedMultiplier;
                            var pixelScroll = (wheel.angleDelta.y / 120.0) * scrollAmountPerStandardTick;
                            var newContentY = localTrackView.contentY - pixelScroll;
                            newContentY = Math.max(0, newContentY);
                            newContentY = Math.min(newContentY, localTrackView.contentHeight - localTrackView.height);
                            if (localTrackView.contentHeight > localTrackView.height) { // Only scroll if there's something to scroll
                                localTrackView.contentY = newContentY;
                                wheel.accepted = true; // Consume the event, we handled it
                            } else {
                                wheel.accepted = false; // Nothing to scroll, let it propagate if needed
                            }
                        }
                    }
                }
                Row { // delegateContentRow
                    id: delegateContentRow
                    anchors.fill: parent
                    anchors.margins: 5 * tracklistPane.rowScale
                    spacing: 8 * tracklistPane.rowScale

                    Rectangle { // albumArt
                        id: albumArt
                        width: tracklistPane.baseImageSize * tracklistPane.rowScale
                        height: tracklistPane.baseImageSize * tracklistPane.rowScale
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.darker(tracklistPane.themeColor, 2.5) // Themed placeholder
                        radius: 3; visible: width > 0 && height > 0
                        Image {
                            id: trackImage; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; smooth: true
                            source: modelData.source === "local" && modelData.imageBase64 ? ("data:" + modelData.imageMimeType + ";base64," + modelData.imageBase64) : ""
                            visible: status == Image.Ready && trackImage.source !== ""
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.source === "spotify" ? "S" : (trackImage.status == Image.Ready ? "" : "?")
                            font.bold: true; font.pixelSize: modelData.source === "spotify" ? 24 * rowScale : 30 * rowScale
                            color: modelData.source === "spotify" ? Qt.lighter(tracklistPane.themeColor, 3.0) : Qt.lighter(tracklistPane.themeColor, 1.5) // Themed placeholder text
                            visible: trackImage.status != Image.Ready || trackImage.source === ""
                        }
                    }
                    RowLayout { // trackInfoTextLayout
                        id: trackInfoTextLayout
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 5 * tracklistPane.rowScale
                        readonly property real _contentWidthForTextItems: Math.max(0, delegateRoot._widthAllocatedToTrackInfoTextLayout - (trackInfoTextLayout.spacing * 2))

                        // --- Title text with hover effects ---
                        Text {
                            id: titleText
                            Layout.preferredWidth: trackInfoTextLayout._contentWidthForTextItems * currentFlexValues.title
                            Layout.minimumWidth: 40
                            text: modelData.title
                            elide: Text.ElideRight
                            color: titleMouseArea.containsMouse ? Qt.lighter(themeColor, 2.5) : themeColor
                            font.pixelSize: tracklistPane.baseFontSize * tracklistPane.rowScale
                            font.bold: true
                            MouseArea {
                                id: titleMouseArea
                                width: parent.paintedWidth
                                height: parent.height
                                hoverEnabled: true
                                propagateComposedEvents: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        Text { // artistText
                            id: artistText; Layout.preferredWidth: trackInfoTextLayout._contentWidthForTextItems * currentFlexValues.artist; Layout.minimumWidth: 30
                            horizontalAlignment: Text.AlignLeft; font.family: customFont.name
                            font.pixelSize: tracklistPane.baseFontSize * 0.8 * tracklistPane.rowScale
                            text: modelData.artist;
                            color: artistMouseArea.containsMouse ? Qt.lighter(themeColor, 2.5) : themeColor
                            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                            MouseArea {
                                id: artistMouseArea
                                width: parent.paintedWidth
                                height: parent.height
                                hoverEnabled: true
                                propagateComposedEvents: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        Text { // albumText
                            id: albumText; Layout.preferredWidth: trackInfoTextLayout._contentWidthForTextItems * currentFlexValues.album; Layout.minimumWidth: 30
                            horizontalAlignment: Text.AlignLeft; font.family: customFont.name
                            text: modelData.album; color: albumMouseArea.containsMouse ? Qt.lighter(themeColor, 2.5) : themeColor;
                            font.pixelSize: tracklistPane.baseFontSize * 0.8 * tracklistPane.rowScale
                            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                            MouseArea {
                                id: albumMouseArea
                                width: parent.paintedWidth
                                height: parent.height
                                hoverEnabled: true
                                propagateComposedEvents: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            } // End delegate
        } // End ListView
    }
    EditTrackPopup {
        id: editTrackPopup
        onSaveRequested: ({filePath,title,artist,album,imagePath}) => {
            console.log("Save requested for:", filePath, title, artist, album, imagePath);
            if (tracklistPane.trackModel && typeof tracklistPane.trackModel.updateTrack === 'function') {
                cppLocalManager.writeTrackTags(filePath, title, artist, album, imagePath);
            }
        }
    }
}
