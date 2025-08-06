// LocalMusicManager.h
#ifndef LOCALMUSICMANAGER_H
#define LOCALMUSICMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QString>
#include <QUrl>
#include <QDebug>
#include <QStringList>
#include <QMultiHash>
#include <QFuture>      
#include <QFutureWatcher>
#include <QtConcurrent>  
#include <QSet>
#include <QHash>

class TrackListModel;
const QString ALL_TRACKS_IDENTIFIER = QStringLiteral("*ALL_TRACKS*");

class LocalMusicManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList sidebarItems READ sidebarItems NOTIFY sidebarItemsChanged)

public:
    explicit LocalMusicManager(QObject *parent = nullptr);
    ~LocalMusicManager(); // Add destructor for watcher cleanup later maybe
    QVariantList sidebarItems() const;
    QStringList splitArtistName(const QString &artistName);

public slots:
    void selectAndScanParentFolderForArtists();
    Q_INVOKABLE void scanDefaultMusicFolder();
    void loadTracksFor(const QString &identifier, const QString &type);
    void setGrouping(const QString &grouping);
    void writeTrackTags(const QString &filePath, const QString &title,
                        const QString &artist, const QString &album,
                        const QString &imagePath);

private slots: 
    void handleScanFinished();

signals:
    void sidebarItemsChanged();
    void loadingError(const QString &errorMsg);
    void loadingProgress(int current, int total);
    void tracksReadyForDisplay(const QVariantList& loadedTracks);
    void scanStateChanged(bool isScanning);
    void trackUpdated(const QVariantMap &updatedTrack);

private:
    struct ScanResults {
        QList<QVariantMap> cachedTracks;
        QSet<QString> uniqueArtists;
        QSet<QString> uniqueAlbums;
		QHash<QString, int> albumTrackCounts;
    };
    void startScanProcess(const QString& folderPath);
    ScanResults performBackgroundScan(QString parentFolderPath); 
    QVariantMap readId3Tags(const QString& filePath);
    void recursiveScan(const QString& folderPath, QStringList& foundMp3Files);
	void rebuildSidebarModel();

    // Member variables
    QVariantList m_sidebarItems;
    QString m_selectedParentFolder;
    void scanForArtists(const QString& parentFolderPath);
    QList<QVariantMap> m_cachedFullTrackData; // Use specific type for cache is fine
    QMultiHash<QString, int> m_artistIndexHash;
	QMultiHash<QString, int> m_albumIndexHash;
    QHash<QString, int> m_albumTrackCounts;
    QString m_currentGrouping;

    QFutureWatcher<ScanResults> m_scanWatcher;
};

#endif // LOCALMUSICMANAGER_H
