# Librify: The best offline music player for PC and Android

[![Build Status](https://img.shields.io/github/actions/workflow/status/lucaspapadatos/librify/main.yml?branch=main&style=for-the-badge)](https://github.com/lucaspapadatos/librify/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Qt Version](https://img.shields.io/badge/Qt-6.5+-green.svg?style=for-the-badge)](https://www.qt.io/)

A modern, cross-platform desktop music player built with C++ and Qt/QML, designed to seamlessly blend your local music library with Spotify streaming.

<!-- 💡 TODO: Add a real screenshot of your application and update the path! -->

## ✨ Core Features

*   **Hybrid Music Library**: Access and play tracks from your local folders and your Spotify account in one unified interface.
*   **Modern & Responsive UI**: A fluid and intuitive user interface built with QML, ensuring a great experience on any desktop and android device.
*   **Local Metadata Editing**: Easily edit the tags (artist, album, title, cover art) of your local music files directly within the app.
*   **Secure Spotify Integration**: Uses a standard OAuth2 flow with a local server to securely authenticate with the Spotify Web API.
*   **Cross-Platform**: Built on the Qt framework for native performance on Windows, Android, and Linux.

## 🏛️ System Architecture

This project is designed with a clear separation between the **QML-based frontend** and the **C++ backend**, communicating through Qt's robust signals and slots mechanism. This ensures a responsive UI while heavy lifting like file I/O and network requests are handled efficiently in the background.

The diagram below illustrates the high-level interaction between the main components, UI elements, backend managers, and external services.

### Class Diagram

```mermaid
classDiagram
    direction LR

    class UserBrowser {
        <<Actor>>
        User's Web Browser
    }
    
    class SpotifyAPI {
        <<Actor>>
        Spotify Web API
    }

    class Main_qml {
        <<QML Window>>
        +int currentlyPlayingIndex
        +MediaPlayer trackPlayer
        +onTrackClicked(index, modelData) slot
        +playTrackAtIndex(index)
        +playNextTrack()
        +playPrevTrack()
    }

    class PlaybackControlsBar_qml {
        <<QML Component>>
        +var mediaPlayerInstance
        +var playbackManager
        +Slider positionSlider
        +Slider volumeSlider
    }

    class TrackListPane_qml {
        <<QML Component>>
        +var trackModel
        +int currentTrackIndex
        +trackClicked(index, modelData) signal
        +sortRequested(column, order) signal
    }

    class SidebarPane_qml {
        <<QML Component>>
        +var localManager
        +var spotifyManager
    }
    
    class EditTrackPopup_qml {
        <<QML Component>>
        +saveRequested(trackData) signal
    }

    class LocalMusicManager_cpp {
        <<C++ Backend>>
        +writeTrackTags(...)
        +scanDefaultMusicFolder()
        +tracksReadyForDisplay(tracks) signal
        +trackMetadataUpdated(trackData) signal
    }
    
    class TrackListModel_cpp {
        <<C++ Backend>>
        +QVariantList tracks
        +updateTracks(tracks) slot
        +updateTrack(trackData) slot
    }

    class PlaybackManager_cpp {
        <<C++ Backend>>
        +double volume
        +bool muted
        +setMediaPlayer(player)
    }
    
    class SpotifyManager_cpp {
        <<C++ Backend>>
        +bool isAuthenticated
        +authenticate() slot
        +requestAccessToken(code) slot
    }

    class AuthServer_cpp {
        <<C++ Backend>>
        +start()
        +stop()
        +authorizationCodeReceived(code) signal
    }
    
    class MediaPlayer {
        <<Qt Multimedia>>
        +source
        +position
        +duration
        +playbackState
        +mediaStatus
        +onMediaStatusChanged event
        +onPlaybackStateChanged event
        +play()
        +pause()
    }
    
    class AudioOutput {
        <<Qt Multimedia>>
    }

    class QTcpServer {
        <<Qt Network>>
    }

    class QNetworkAccessManager {
        <<Qt Network>>
    }

    %% --- Relationships ---

    %% Composition
    Main_qml o-- PlaybackControlsBar_qml
    Main_qml o-- TrackListPane_qml
    Main_qml o-- SidebarPane_qml
    Main_qml o-- MediaPlayer : owns "trackPlayer"
    TrackListPane_qml o-- EditTrackPopup_qml
    
    %% UI Interactions & Data Flow
    SidebarPane_qml ..> SpotifyManager_cpp : calls authenticate()
    TrackListPane_qml ..> TrackListModel_cpp : displays data from
    TrackListPane_qml ..> Main_qml : signals trackClicked
    EditTrackPopup_qml ..> LocalMusicManager_cpp : calls writeTrackTags()
    Main_qml ..> LocalMusicManager_cpp : triggers scans
    Main_qml ..> TrackListModel_cpp : reads model
    Main_qml ..> PlaybackManager_cpp : reads readiness
    Main_qml ..> SpotifyManager_cpp : reads auth state

    %% PlaybackControlsBar Interactions
    PlaybackControlsBar_qml ..> Main_qml : calls play/next/prev/currentOrFirst
    PlaybackControlsBar_qml ..> PlaybackManager_cpp : controls volume/mute
    PlaybackControlsBar_qml ..> MediaPlayer : "reads state (pos, dur, etc)"
    PlaybackControlsBar_qml ..> MediaPlayer : "sets position (seek)"
    
    %% C++ Backend Signal/Slot
    LocalMusicManager_cpp ..> TrackListModel_cpp : signals to
    AuthServer_cpp ..> SpotifyManager_cpp : signals authorizationCodeReceived
    
    %% Qt & External System Interactions
    QTcpServer <|-- AuthServer_cpp : inherits from
    SpotifyManager_cpp o-- QNetworkAccessManager : uses
    SpotifyManager_cpp --> SpotifyAPI : "requests data"
    SpotifyManager_cpp --> UserBrowser : "opens auth URL"
    UserBrowser --> AuthServer_cpp : "sends auth code"
    MediaPlayer -- AudioOutput : uses
    PlaybackManager_cpp ..> AudioOutput : controls volume of
```
