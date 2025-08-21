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
