// PlaylistManager.cpp
#include "PlaylistManager.h"
#include "TrackListModel.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QImage>
#include <QUrl>

PlaylistManager::PlaylistManager(QObject *parent) : QObject(parent) {
    loadPlaylists();
}

QString PlaylistManager::playlistsDirPath() const {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/playlists";
    QDir().mkpath(base);
    return base;
}

QString PlaylistManager::playlistFilePath(const QString &name) const {
    return playlistsDirPath() + "/" + name + ".json";
}

QVariantList PlaylistManager::getPlaylists() const { 
	if (m_sidebarItems.size() <= 1) {
		return QVariantList();
	}
	return m_sidebarItems.mid(1);
}

QVariantList PlaylistManager::sidebarItems() const { return m_sidebarItems; }

void PlaylistManager::createPlaylist(const QString &name, const QString &image) {
    QJsonObject obj;
	obj["id"] = name;
    obj["name"] = name;
    obj["iconSource"] = image;
	obj["type"] = "local_playlist";
    obj["tracks"] = QJsonArray();
    savePlaylist(name, obj);
    loadPlaylists();
}

void PlaylistManager::deletePlaylist(const QString &name) {
    QFile::remove(playlistFilePath(name));
    loadPlaylists();
}

void PlaylistManager::refreshSidebarItems() {
	qDebug() << "[PlaylistManager] New sidebar list build for PLAYLISTS";
    loadPlaylists();
}

void PlaylistManager::loadPlaylists() {
    m_sidebarItems.clear();

    QDir dir(playlistsDirPath());
    QFileInfoList files = dir.entryInfoList(QStringList() << "*.json", QDir::Files);
	QVariantMap createMap;
    createMap["type"] = "create_playlist";
    createMap["name"] = "Create";
    createMap["id"] = "Create";
    createMap["iconSource"] = "qrc:/icons/all_tracks_icon.png";
    createMap["count"] = 0;
    m_sidebarItems.append(createMap);

    for (const QFileInfo &fi : files) {
        QFile file(fi.filePath());
        if (!file.open(QIODevice::ReadOnly)) continue;

        QByteArray data = file.readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject obj = doc.object();

        QVariantMap item;
		item["id"] = obj.value("name").toString();
        item["name"] = obj.value("name").toString();
        item["iconSource"] = obj.value("iconSource").toString();
		item["type"] = obj.value("type").toString();
		item["count"] = obj.value("tracks").toArray().size();
        m_sidebarItems.append(item);
    }

    emit sidebarItemsChanged();
}

void PlaylistManager::savePlaylist(const QString &name, const QJsonObject &playlistObj) {
    QFile file(playlistFilePath(name));
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to save playlist file:" << file.fileName();
        return;
    }

    QJsonDocument doc(playlistObj);
    file.write(doc.toJson());
}

void PlaylistManager::editPlaylist(const QString &oldName, const QString &newName, const QString &newIconSource) {
	// Locate the existing playlist file
    QFile file(playlistFilePath(oldName));
    if (!file.exists()) {
        qWarning() << "[PlaylistManager] Playlist file not found:" << file.fileName();
        return;
    }

    // Open existing file for reading
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[PlaylistManager] Failed to open playlist file for reading:" << file.fileName();
        return;
    }

    // Parse existing JSON data
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        qWarning() << "[PlaylistManager] Invalid playlist JSON:" << file.fileName();
        return;
    }

    QJsonObject playlistObj = doc.object();

    // Update name and iconSource
    playlistObj["name"] = newName;
    playlistObj["iconSource"] = newIconSource;

    // If the playlist name changed, remove old file and create a new one
    QString newPath = playlistFilePath(newName);
    if (oldName != newName && QFile::exists(newPath)) {
        qWarning() << "[PlaylistManager] A playlist with the new name already exists!";
        return;
    }

    if (oldName != newName) {
        QFile::remove(playlistFilePath(oldName)); // delete old file
    }

    // Save to the correct path
    QFile saveFile(newPath);
    if (!saveFile.open(QIODevice::WriteOnly)) {
        qWarning() << "[PlaylistManager] Failed to open playlist file for writing:" << saveFile.fileName();
        return;
    }

    // Write updated JSON back
    QJsonDocument updatedDoc(playlistObj);
    saveFile.write(updatedDoc.toJson());
    saveFile.close();

    qDebug() << "[PlaylistManager] Playlist updated successfully:" << newName;
}

void PlaylistManager::addTrack(const QString &playlistName, const QString &trackFilepath) {
    QFile file(playlistFilePath(playlistName));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[PlaylistManager] Failed to open playlist to add track:" << file.fileName();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        qWarning() << "[PlaylistManager] Invalid playlist JSON:" << file.fileName();
        return;
    }

    QJsonObject playlistObj = doc.object();
    QJsonArray tracks = playlistObj["tracks"].toArray();

    tracks.append(QJsonValue(trackFilepath));
    playlistObj["tracks"] = tracks;

    savePlaylist(playlistName, playlistObj);
	refreshSidebarItems();   
}

void PlaylistManager::removeTrack(const QString &playlistName, const QString &trackFilepath) {
    QFile file(playlistFilePath(playlistName));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[PlaylistManager] Failed to open playlist to remove track:" << file.fileName();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        qWarning() << "[PlaylistManager] Invalid playlist JSON:" << file.fileName();
        return;
    }

    QJsonObject playlistObj = doc.object();
    QJsonArray tracks = playlistObj["tracks"].toArray();
    QJsonArray newTracks;

    // Create a new array containing all tracks except the one to be removed
    for (const QJsonValue &value : tracks) {
        if (value.toString() != trackFilepath) {
            newTracks.append(value);
        }
    }
    playlistObj["tracks"] = newTracks;

    savePlaylist(playlistName, playlistObj);
    refreshSidebarItems();
}
