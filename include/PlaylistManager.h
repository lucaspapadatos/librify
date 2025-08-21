// PlaylistManager.h
#ifndef PLAYLISTMANAGER_H
#define PLAYLISTMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QStandardPaths>
#include <QDir>
#include <QJsonArray>
#include <QJsonObject>

struct Playlist {
	QString id;
    QString name;
    QString filePath;              // Path to saved JSON
	QString iconSource;			   // Path to cover image
    QVariantList tracks;    
};

/**
 * @brief The PlaylistManager class handles creation, loading, and saving
 * playlists as JSON files. It stores an ordered list of playlists and
 * exposes them for SidebarPane and other components.
 */
class PlaylistManager : public QObject
{
    Q_OBJECT
	Q_PROPERTY(QVariantList sidebarItems READ sidebarItems NOTIFY sidebarItemsChanged)

public:
	explicit PlaylistManager(QObject *parent = nullptr);

	QVariantList sidebarItems() const;
    Q_INVOKABLE void refreshSidebarItems();

	Q_INVOKABLE void createPlaylist(const QString &name, const QString &image);
    Q_INVOKABLE void deletePlaylist(const QString &name);


signals:
	void sidebarItemsChanged();

private:
	QString playlistsDirPath() const;
    QString playlistFilePath(const QString &name) const;

	void loadPlaylists();
    void savePlaylist(const QString &name, const QJsonObject &playlistObj);

	QList<Playlist> m_playlists;
	QVariantList m_sidebarItems;
};
#endif // PLAYLISTMANAGER_H

