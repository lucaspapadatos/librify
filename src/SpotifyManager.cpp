#include "SpotifyManager.h"
#include <QUrlQuery>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QTimer> // For potential delayed auth
#include <QDesktopServices> // <<< ADD THIS INCLUDE
#include <QDebug>
#include <QUrl>

// --- Constructor, Getter methods ---
SpotifyManager::SpotifyManager(QObject *parent) : QObject(parent), manager(new QNetworkAccessManager(this)) {}

QVariantList SpotifyManager::playlists() const {
    return m_playlists;
}

bool SpotifyManager::isAuthenticated() const {
    return m_isAuthenticated;
}
// --------------------------------

void SpotifyManager::authenticate() {
    // ... (authenticate method remains the same - opens browser) ...
    QString clientId = "71d70dc1b6254649a3629d2cd3ecb722"; // Use your ID
    QString redirectUri = "http://localhost:8888/callback";
    QString scope = "playlist-read-private playlist-read-collaborative user-read-private user-read-email";
    QString authUrl = QString("https://accounts.spotify.com/authorize?client_id=%1&response_type=code&redirect_uri=%2&scope=%3")
                          .arg(clientId)
                          .arg(redirectUri)
                          .arg(scope);


    qDebug() << "Opening auth URL:" << authUrl;
    QDesktopServices::openUrl(QUrl(authUrl));



}

// Modified to update auth state
void SpotifyManager::requestAccessToken(const QString &code) {
    // ... (setup request, query as before) ...
    QString clientId = "71d70dc1b6254649a3629d2cd3ecb722";
    QString clientSecret = "ede95fed283a41db8464c7f1ab6720d2"; // Keep secret secure
    QString redirectUri = "http://localhost:8888/callback";


    QUrl url("https://accounts.spotify.com/api/token");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    QString authHeader = QString("%1:%2").arg(clientId).arg(clientSecret);
    request.setRawHeader("Authorization", "Basic " + authHeader.toUtf8().toBase64());
    QUrlQuery query;
    query.addQueryItem("grant_type", "authorization_code");
    query.addQueryItem("code", code);
    query.addQueryItem("redirect_uri", redirectUri);

    qDebug() << "Requesting access token...";
    QNetworkReply *reply = manager->post(request, query.toString(QUrl::FullyEncoded).toUtf8());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        bool authStateChanged = false; // Track if state actually changes
        bool previousAuthState = m_isAuthenticated;

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray response = reply->readAll();
            QJsonDocument jsonDoc = QJsonDocument::fromJson(response);
            QJsonObject jsonObj = jsonDoc.object();

            if (jsonObj.contains("access_token") && !jsonObj["access_token"].toString().isEmpty()) {
                this->accessToken = jsonObj["access_token"].toString();
                this->m_isAuthenticated = true; // Set authenticated flag
                qDebug() << "Access Token obtained successfully.";
                // Optional: Automatically fetch playlists after getting token
                // fetchPlaylists();
            } else {
                this->m_isAuthenticated = false; // Ensure false on failure
                qWarning() << "Error obtaining access token: No valid token in response" << response;
                emit authenticationError("Failed to parse access token from response.");
            }
        } else {
            this->m_isAuthenticated = false; // Ensure false on failure
            qWarning() << "Network Error requesting access token:" << reply->errorString() << reply->readAll();
            emit authenticationError("Network Error: " + reply->errorString());
        }

        // Emit signal only if state changed
        if (m_isAuthenticated != previousAuthState) {
            emit isAuthenticatedChanged();
        }

        reply->deleteLater();
    });



}

// Fetch user's playlists (unchanged)
void SpotifyManager::fetchPlaylists() {
    if (!m_isAuthenticated || accessToken.isEmpty()) {
        qWarning() << "Cannot fetch playlists: Not authenticated.";
        emit playlistsFetchError("Authentication required.");
        return;
    }
    QUrl url("https://api.spotify.com/v1/me/playlists");
    QNetworkRequest request(url);
    request.setRawHeader("Authorization", ("Bearer " + accessToken).toUtf8());


    qDebug() << "Fetching user playlists...";
    QNetworkReply *reply = manager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { // Use this capture
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray response = reply->readAll();
            QJsonDocument jsonDoc = QJsonDocument::fromJson(response);
            QJsonObject rootObject = jsonDoc.object();

            if (rootObject.contains("items") && rootObject["items"].isArray()) {
                QJsonArray playlistsArray = rootObject["items"].toArray();
                QVariantList newPlaylists;
                for (const QJsonValue &value : playlistsArray) {
                    QJsonObject playlistObj = value.toObject();
                    QVariantMap playlistMap;
                    playlistMap["name"] = playlistObj["name"].toString();
                    playlistMap["id"] = playlistObj["id"].toString();
                    playlistMap["owner"] = playlistObj["owner"].toObject()["display_name"].toString();
                    playlistMap["track_count"] = playlistObj["tracks"].toObject()["total"].toInt();
                    newPlaylists.append(playlistMap);
                }
                if (m_playlists != newPlaylists) {
                    m_playlists = newPlaylists;
                    qDebug() << "Fetched" << m_playlists.count() << "playlists. Emitting playlistsChanged.";
                    emit playlistsChanged();
                }
            } else { /* Handle error */ emit playlistsFetchError("Could not parse playlists."); }
        } else { /* Handle network error */ emit playlistsFetchError("Network Error: " + reply->errorString()); }
        reply->deleteLater();
    });



}

// **** NEW: Fetch tracks for a specific playlist ****
void SpotifyManager::fetchTracksForPlaylist(const QString& playlistId)
{
    if (!m_isAuthenticated || accessToken.isEmpty() || playlistId.isEmpty()) {
        qWarning() << "Cannot fetch tracks: Authentication or playlist ID missing.";
        emit tracksFetchError("Authentication or Playlist ID required.");
        return;
    }


    // Construct the URL for the playlist tracks endpoint
    // Add 'fields' parameter to limit data: items(track(name,artists(name),album(name)))
    QString fields = "items(track(name,artists(name),album(name),duration_ms))"; // Example fields
    QUrl url(QString("https://api.spotify.com/v1/playlists/%1/tracks").arg(playlistId));
    QUrlQuery query;
    query.addQueryItem("fields", fields);
    query.addQueryItem("limit", "50"); // Get up to 50 tracks initially (max 100 per request)
    url.setQuery(query);


    QNetworkRequest request(url);
    request.setRawHeader("Authorization", ("Bearer " + accessToken).toUtf8());

    qDebug() << "Fetching tracks for playlist ID:" << playlistId << "URL:" << url.toString();
    QNetworkReply *reply = manager->get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, playlistId]() { // Capture necessary vars
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray response = reply->readAll();
            qDebug() << "Received track data for playlist" << playlistId; //. Size:" << response.size();
            QVariantList tracks = parseTracksFromJson(response); // Use helper to parse

            // TODO: Handle pagination ('next' field in response JSON) later if needed.
            // For now, just emit the first batch of tracks.

            qDebug() << "Parsed" << tracks.count() << "tracks. Emitting tracksFetched.";
            emit tracksFetched(tracks); // Emit the signal with parsed tracks

        } else {
            qWarning() << "Network Error fetching tracks for playlist" << playlistId << ":" << reply->errorString() << reply->readAll();
            emit tracksFetchError("Network Error fetching tracks: " + reply->errorString());
        }
        reply->deleteLater();
    });

}

// **** NEW: Helper to parse tracks JSON ****
QVariantList SpotifyManager::parseTracksFromJson(const QByteArray& jsonData)
{
    QVariantList trackList;
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData);
    QJsonObject rootObject = jsonDoc.object();


    if (rootObject.contains("items") && rootObject["items"].isArray()) {
        QJsonArray items = rootObject["items"].toArray();

        for (const QJsonValue &itemValue : items) {
            QJsonObject itemObj = itemValue.toObject();
            if (itemObj.contains("track") && itemObj["track"].isObject()) {
                QJsonObject trackObj = itemObj["track"].toObject();
                if (trackObj.isEmpty() || trackObj.value("name").isNull()) {
                    qDebug() << "Skipping item with null or empty track data.";
                    continue; // Skip local tracks or tracks that couldn't be retrieved
                }


                QVariantMap trackMap;
                trackMap["title"] = trackObj["name"].toString();

                // Combine artist names
                QStringList artistNames;
                if (trackObj.contains("artists") && trackObj["artists"].isArray()) {
                    QJsonArray artists = trackObj["artists"].toArray();
                    for (const QJsonValue &artistValue : artists) {
                        artistNames.append(artistValue.toObject()["name"].toString());
                    }
                }
                trackMap["artist"] = artistNames.join(", "); // Join multiple artists

                // Get album name
                if (trackObj.contains("album") && trackObj["album"].isObject()) {
                    trackMap["album"] = trackObj["album"].toObject()["name"].toString();
                } else {
                    trackMap["album"] = "Unknown Album";
                }

                // Add other fields if needed (ensure consistency with local format)
                trackMap["duration_ms"] = trackObj.value("duration_ms").toInt(0);
                trackMap["source"] = "spotify"; // <<< ADDED SOURCE FIELD
                trackMap["filePath"] = ""; // Empty for Spotify tracks
                trackMap["imageBase64"] = ""; // No image data fetched here
                trackMap["imageMimeType"] = "";

                trackList.append(trackMap);
            }
        }
        // Check for pagination ('next' URL) - implement later
        // QString nextUrl = rootObject.value("next").toString();
        // if(!nextUrl.isEmpty()){ /* Store nextUrl and trigger fetchPaginatedTracks */ }

    } else {
        qWarning() << "Could not parse tracks: 'items' array not found or not an array in JSON response.";
    }

    return trackList;


}
