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
#include <QFuture>          // <<< Include
#include <QFutureWatcher>   // <<< Include
#include <QtConcurrent>     // <<< Include

class TrackListModel;
const QString ALL_TRACKS_IDENTIFIER = QStringLiteral("*ALL_TRACKS*");

class LocalMusicManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList sidebarItems READ sidebarItems NOTIFY sidebarItemsChanged)

public:
    explicit LocalMusicManager(QObject *parent = nullptr);
    ~LocalMusicManager(); // Add destructor for watcher cleanup maybe
    QVariantList sidebarItems() const;
    QStringList splitArtistName(const QString& artistName);

public slots:
    void selectAndScanParentFolderForArtists();
    Q_INVOKABLE void scanDefaultMusicFolder();
    void loadTracksForArtist(const QString& artistName);
    // Add a slot to cancel scanning if needed
    // void cancelScan();
    void writeTrackTags(const QString &filePath, const QString &title,
                        const QString &artist, const QString &album,
                        const QString &imagePath);

private slots: // <<< Make private slots for handling results
    void handleScanFinished(); // Called when background scan completes

signals:
    void sidebarItemsChanged();
    void loadingError(const QString &errorMsg);
    void loadingProgress(int current, int total);
    void tracksReadyForDisplay(const QVariantList& loadedTracks);
    void scanStateChanged(bool isScanning);
    void trackUpdated(const QVariantMap &updatedTrack);

private:
    // Background task function (now returns results)
    // Define a struct to hold results for type safety
    struct ScanResults {
        QList<QVariantMap> cachedTracks; // Use specific type here is okay
        QSet<QString> uniqueArtists;
        // Add bool success? QString errorMsg?
    };
    void startScanProcess(const QString& folderPath);
    ScanResults performBackgroundScan(QString parentFolderPath); // Moved core logic here

    // Reads full ID3 tags (can be called by background task)
    QVariantMap readId3Tags(const QString& filePath);
    // Helper for recursive scan (can be called by background task)
    void recursiveScan(const QString& folderPath, QStringList& foundMp3Files);

    // Member variables
    QVariantList m_sidebarItems;
    QString m_selectedParentFolder;
    // Caches are now populated by handleScanFinished
    void scanForArtists(const QString& parentFolderPath);
    QList<QVariantMap> m_cachedFullTrackData; // Use specific type for cache is fine
    QMultiHash<QString, int> m_artistIndexHash;

    // Future watcher for the background task
    QFutureWatcher<ScanResults> m_scanWatcher; // <<< Watcher member
};

#endif // LOCALMUSICMANAGER_H
