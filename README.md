```mermaid
graph TD
    A[NewNew Project] --> B[Main.qml]
    A --> C[SidebarPane.qml]
    A --> D[TrackListPane.qml]
    A --> E[PlaybackControlsBar.qml]
    A --> F[EditTrackPopup.qml]
    A --> G[main.cpp]
    A --> H[AuthServer.cpp]
    A --> I[SpotifyManager.cpp]
    A --> J[LocalMusicManager.cpp]
    A --> K[TrackListModel.cpp]
    A --> L[PlaybackManager.cpp]
    A --> M[Icons]
    A --> N[Fonts]

    subgraph QML Files
        B
        C
        D
        E
        F
    end

    subgraph C++ Files
        G
        H
        I
        J
        K
        L
    end

    subgraph Resources
        M[Icons]
        N[Fonts]
    end

    subgraph Build Process
        A --> O[Qt6 Libraries]
        A --> P[TagLib]
        A --> Q[windeployqt]
    end