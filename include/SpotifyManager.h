#ifndef SPOTIFYMANAGER_H
#define SPOTIFYMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList> // For return types and signals
#include <QNetworkAccessManager> // For member variable type
#include <QUrl>           // For signals/slots if needed, good practice
#include <QJsonArray>     // For signals/slots if needed

// Forward declare QNetworkReply if only pointers are used in the header
// class QNetworkReply; // Not strictly necessary here as it's only used in .cpp

class SpotifyManager : public QObject
{
    Q_OBJECT // Essential for signals, slots, properties

    // --- Properties Exposed to QML ---

    // Property for the list of user's playlists (if needed by UI directly)
    // Note: The current fetchPlaylists implementation emits rawPlaylistsFetched
    //       and optionally updates this. Decide if you still need this property.
    Q_PROPERTY(QVariantList playlists READ playlists NOTIFY playlistsChanged)

    // Property to indicate if the user is currently authenticated
    Q_PROPERTY(bool isAuthenticated READ isAuthenticated NOTIFY isAuthenticatedChanged)

public:
    // --- Constructor ---
    explicit SpotifyManager(QObject *parent = nullptr);

    // --- Getter Methods for Properties ---
    QVariantList playlists() const;
    bool isAuthenticated() const;

public slots:
    // --- Public Slots Callable from QML or C++ ---

    // Initiates the Spotify authentication process (opens browser)
    void authenticate();

    // Called internally (usually by AuthServer signal) to exchange code for token
    // Declared as slot to be connectable
    void requestAccessToken(const QString &code);

    // Fetches the list of the current user's Spotify playlists
    void fetchPlaylists();

    // Fetches the track list for a specific Spotify playlist ID
    void fetchTracksForPlaylist(const QString& playlistId);

signals:
    // --- Signals Emitted to Notify QML or Other C++ Components ---

    // Emitted when the internal playlist list (m_playlists) changes (if property is used)
    void playlistsChanged();

    // Emitted when the authentication state (m_isAuthenticated) changes
    void isAuthenticatedChanged();

    // Emitted when an error occurs during the authentication process (token exchange)
    void authenticationError(const QString& error);

    // Emitted when an error occurs while fetching the list of playlists
    void playlistsFetchError(const QString& error);

    // Emitted when tracks for a specific playlist have been successfully fetched and parsed
    void tracksFetched(const QVariantList& tracks); // Carries the list of tracks

    // Emitted when an error occurs while fetching tracks for a playlist
    void tracksFetchError(const QString& error);

    // Emitted by fetchPlaylists with the raw data, intended for LocalMusicManager integration
    void rawPlaylistsFetched(const QVariantList& rawPlaylists);


private:
    // --- Private Helper Methods ---

    // Parses the JSON response from Spotify's track endpoint
    QVariantList parseTracksFromJson(const QByteArray& jsonData);

    // Future enhancement: Helper for recursive track fetching (pagination)
    // void fetchPaginatedTracks(const QUrl& nextUrl);

    // --- Member Variables ---
    QNetworkAccessManager *manager;       // Manages network requests
    QString accessToken;                  // Stores the current OAuth access token
    QVariantList m_playlists;             // Backing store for the 'playlists' property
    bool m_isAuthenticated;               // Tracks current authentication status

    // Optional: Store state for pagination or current operations
    // QString m_currentlyFetchingPlaylistId;
    // QUrl m_nextTracksUrl;

};

#endif // SPOTIFYMANAGER_H
