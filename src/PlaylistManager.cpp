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

QVariantList PlaylistManager::sidebarItems() const { return m_sidebarItems; }

void PlaylistManager::createPlaylist(const QString &name) {
    QJsonObject obj;
    obj["name"] = name;
    obj["iconSource"] = "qrc:/icons/playlist_icon.png";
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

//=============================================================================
// SLOT: Loads tracks for a given playlist name
//=============================================================================
void PlaylistManager::loadTracksFor(const QString& playlistName) {
    qDebug() << "[PlaylistManager] Request received to load tracks for playlist:" << playlistName;

    QFile file(playlistFilePath(playlistName));
	qWarning() << "Playlist: " << playlistName;

    if (!file.exists()) {
        qWarning() << "[PlaylistManager] Playlist file does not exist:" << playlistFilePath(playlistName);
        emit tracksReadyForDisplay(QVariantList());
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[PlaylistManager] Failed to open playlist file:" << playlistFilePath(playlistName);
        emit tracksReadyForDisplay(QVariantList());
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "[PlaylistManager] Invalid playlist JSON format in:" << playlistFilePath(playlistName);
        emit tracksReadyForDisplay(QVariantList());
        return;
    }

    QJsonObject obj = doc.object();
    QJsonArray trackArray = obj.value("tracks").toArray();

    QVariantList tracksToShow;
    tracksToShow.reserve(trackArray.size());

    for (const QJsonValue &val : trackArray) {
        if (val.isObject()) {
            tracksToShow.append(val.toObject().toVariantMap());
        }
    }

    qDebug() << "[PlaylistManager] Emitting" << tracksToShow.size() << "tracks for display.";
    emit tracksReadyForDisplay(tracksToShow);
}


void PlaylistManager::loadPlaylists() {
    m_sidebarItems.clear();

    QDir dir(playlistsDirPath());
    QFileInfoList files = dir.entryInfoList(QStringList() << "*.json", QDir::Files);

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
