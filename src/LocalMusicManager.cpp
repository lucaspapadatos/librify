// LocalMusicManager.cpp
#include "LocalMusicManager.h"
#include "TrackListModel.h"

#include <QFileDialog>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QVariantMap>
#include <QByteArray>
#include <QUrl>
#include <QDebug>
#include <typeinfo>
#include <iostream>
#include <exception>
#include <algorithm>
#include <QSet>
#include <QStringList>
#include <QMultiHash>
#include <QImage>
#include <QBuffer>

// --- TagLib Includes ---
#include <taglib/taglib.h>
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/tbytevector.h>
// ----------------------

//=============================================================================
// Constructor
//=============================================================================
LocalMusicManager::LocalMusicManager(QObject *parent) : QObject(parent){
    // **** USE QUEUED CONNECTION ****
    // tells qt to  place the invocation of the handleScanFinished slot into the
    // main thread's event queue when the finished signal is emitted (regardless
    // of which thread emitted it). This ensures the slot runs safely on the
    // correct thread and avoids the race condition or delivery problem you were
    // experiencing without the constructor log's timing side effect.
    connect(&m_scanWatcher, &QFutureWatcher<ScanResults>::finished,
        this, &LocalMusicManager::handleScanFinished, Qt::QueuedConnection);
}

//=============================================================================
// Destructor
//=============================================================================
LocalMusicManager::~LocalMusicManager() {
    // Ensure any running background task is requested to cancel
    // Note: QtConcurrent::run doesn't directly support cancellation easily
    // without cooperation from the running function (e.g., checking QFuture::isCanceled()).
    // For now, just wait if it's running (can block shutdown).
    // m_scanWatcher.waitForFinished(); // Or manage cancellation better
    qDebug() << "[LocalMusicManager] Instance destroyed.";
}

QVariantList LocalMusicManager::sidebarItems() const { return m_sidebarItems; }

//=============================================================================
// FUNCTION: Rewrites the tags of a given mp3 file 
//=============================================================================
void LocalMusicManager::writeTrackTags(const QString &filePath, const QString &title,
                                      const QString &artist, const QString &album,
                                      const QString &imagePath) {
    qDebug() << "[writeTrackTags] Saving tags to:" << QFileInfo(filePath).canonicalFilePath();

    try {
        QString posixPath = QDir::toNativeSeparators(filePath);
        QFile file(posixPath);
        if (!file.exists()) {
            qWarning() << "File not found:" << posixPath;
            return;
        }

		QByteArray pathUtf8 = filePath.toUtf8();
		TagLib::MPEG::File f(pathUtf8.constData());
        if (!f.isValid() || !f.isOpen() || f.readOnly()) { // Added more checks
            qWarning() << "TagLib: Failed to open file for writing or file is invalid/read-only:" << filePath;
            if(!f.isValid()) qWarning() << "Reason: File not valid";
            if(f.isOpen() && f.readOnly()) qWarning() << "Reason: File is read-only";
            if(!f.isOpen()) qWarning() << "Reason: File could not be opened by TagLib";
            return;
        }

        // Save text tags
        TagLib::Tag *tag = f.tag();
        tag->setTitle(TagLib::String(title.toStdString()));
        tag->setArtist(TagLib::String(artist.toStdString()));
        tag->setAlbum(TagLib::String(album.toStdString()));

        TagLib::ID3v2::Tag *id3v2Tag = f.ID3v2Tag(true); // Get/create ID3v2 tag
        if (!id3v2Tag) {
            qWarning() << "TagLib: Could not get or create ID3v2 tag for:" << filePath;
            return;
        }

        if (id3v2Tag) {
            QByteArray titleUtf8 = title.toUtf8();
            QByteArray artistUtf8 = artist.toUtf8();
            QByteArray albumUtf8 = album.toUtf8();

            tag->setTitle(TagLib::String(titleUtf8.constData(), TagLib::String::UTF8));
            tag->setArtist(TagLib::String(artistUtf8.constData(), TagLib::String::UTF8));
            tag->setAlbum(TagLib::String(albumUtf8.constData(), TagLib::String::UTF8));
        }
        else {
            qWarning() << "File does not have an ID3v2 tag. Using generic tag interface which may have encoding limitations for:" << posixPath;
            tag->setTitle(TagLib::String(title.toStdString())); // Might lose some chars if not UTF-8 aware
            tag->setArtist(TagLib::String(artist.toStdString()));
            tag->setAlbum(TagLib::String(album.toStdString()));
        }

        if (!imagePath.isEmpty() && id3v2Tag) { // Ensure we have an ID3v2 tag to add to
            qDebug() << "[writeTrackTags] Processing imagePath:" << imagePath;
            QString localImagePath = imagePath;
            // If imagePath might be a "qrc:/" or "file:///" URL, convert to local file path
            if (imagePath.startsWith("qrc:") || imagePath.startsWith("file:")) {
                localImagePath = QUrl(imagePath).toLocalFile();
                qDebug() << "[writeTrackTags] Converted imagePath to local file:" << localImagePath;
            }

            QImage img(localImagePath);
            if (!img.isNull()) {
                qDebug() << "[writeTrackTags] Image loaded successfully. Format:" << img.format();
                QByteArray ba;
                QBuffer buffer(&ba);
                QString mimeType = "image/jpeg"; // Default to JPEG
                QString saveFormat = "JPEG";

                if (img.save(&buffer, saveFormat.toLatin1().constData())) { // Use QByteArray for format string
                    qDebug() << "[writeTrackTags] Image saved to buffer. Byte array size:" << ba.size();
                    id3v2Tag->removeFrames("APIC");

                    TagLib::ID3v2::AttachedPictureFrame *frame = new TagLib::ID3v2::AttachedPictureFrame;
                    frame->setMimeType(mimeType.toStdString());
                    frame->setPicture(TagLib::ByteVector(ba.constData(), ba.size()));
                    frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);

                    id3v2Tag->addFrame(frame);
                } else {
                    qWarning() << "[writeTrackTags] Failed to save QImage to buffer for:" << localImagePath;
                }
            }
        } else if (imagePath.isEmpty()) {
            qDebug() << "[writeTrackTags] No imagePath provided, skipping image saving.";
        } else if (!id3v2Tag) {
            qWarning() << "[writeTrackTags] No ID3v2 tag available to save image to for:" << posixPath;
        }

        // Save all changes (text and image)
        if (!f.save()) { // TagLib::MPEG::File::AllTags is default for MPEG::File::save()
            qWarning() << "Failed to save tags (after image processing) for:" << posixPath;
            // Consider returning here if save fails, as readId3Tags might show stale data
            return;
        }
        qDebug() << "[writeTrackTags] TagLib::File::save() successful.";

        // Reread tags after save
        qDebug() << "[writeTrackTags] Attempting to re-read tags after save...";
        QVariantMap updatedTrackData = readId3Tags(filePath); // filePath is still the original QString
        if (!updatedTrackData.value("filePath").toString().isEmpty()) {
            emit trackUpdated(updatedTrackData);
        }

    } catch (const std::exception& e) {
        qCritical() << "Exception:" << e.what();
    }
}

//=============================================================================
// SLOT: Scan default folder and trigger subfolder scan
//=============================================================================
void LocalMusicManager::scanDefaultMusicFolder() {
    qDebug() << "[LocalMusicManager] scanDefaultMusicFolder() slot called.";
    if (m_scanWatcher.isRunning()) {
        qWarning() << "[LocalMusicManager] A scan is already in progress. Please wait.";
        // Optionally emit a signal here if QML needs to know the request was ignored
        return;
    }

    QString defaultMusicPath = QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + "/Local";
    if (defaultMusicPath.isEmpty()) {
        qWarning() << "[LocalMusicManager] Default music location not found. Cannot start default scan.";
        // Optionally emit a signal for failure
        return;
    }

    qDebug() << "[LocalMusicManager] Starting scan of default music folder:" << defaultMusicPath;
    startScanProcess(defaultMusicPath); // Call the common helper
}
void LocalMusicManager::startScanProcess(const QString& folderPath) {
    qDebug() << "[LocalMusicManager] Starting scan process for folder:" << folderPath;
    m_selectedParentFolder = folderPath; // Keep if other parts of your class rely on this

    // --- Clear UI immediately ---
    if (!m_sidebarItems.isEmpty()) {
        m_sidebarItems.clear();
        emit sidebarItemsChanged();
    }
    // tracksReadyForDisplay will be emitted by handleScanFinished with new/empty data
    // emit tracksReadyForDisplay(QVariantList()); // Current behavior updates this in handleScanFinished

    emit loadingProgress(0, 1); // Indicate indeterminate start
    emit scanStateChanged(true); // Notify UI scan has started

    // --- Launch Background Scan ---
    qDebug() << "[LocalMusicManager] Launching background scan...";
    QFuture<ScanResults> scanFuture = QtConcurrent::run(&LocalMusicManager::performBackgroundScan, this, folderPath); // Pass folderPath
    m_scanWatcher.setFuture(scanFuture);
}

//=============================================================================
// SLOT: Selects parent folder and trigger subfolder scan
//=============================================================================
void LocalMusicManager::selectAndScanParentFolderForArtists() {
    qDebug() << "[LocalMusicManager] selectAndScanParentFolderForArtists() slot called.";
    // Cancel any previous scan still running
    if (m_scanWatcher.isRunning()) {
        qWarning() << "[LocalMusicManager] A scan is already in progress. Please wait.";
        // Optionally implement cancellation: m_scanWatcher.cancel();
        return;
    }
    QString musicLocation = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    QString dirPath = QFileDialog::getExistingDirectory(
        nullptr, tr("Select Music Folder To Scan For Artists"),
        musicLocation.isEmpty() ? QDir::homePath() : musicLocation,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);

    if (!dirPath.isEmpty()) {
        qDebug() << "[LocalMusicManager] Selected parent folder for scan:" << dirPath;
        startScanProcess(dirPath); 
    } else {
        qDebug() << "[LocalMusicManager] No parent folder selected.";
    }
}

//=============================================================================
// HELPER: Split artist names
//=============================================================================
QStringList LocalMusicManager::splitArtistName(const QString& artistName) {
    if (artistName.isEmpty()) {
        return QStringList() << "Unknown Artist";
    }

    // Define common separators
    QStringList separators = {
        ", ", " & ", " and ", " ft. ", " feat. ", " feat ", " featuring ", " vs. ", " vs ", " with "
    };

    QString normalizedName = artistName;

    // First, replace all variants of separators with a standard one
    for (const QString& sep : separators) {
        normalizedName = normalizedName.replace(sep, "|||", Qt::CaseInsensitive);
    }

    // Then split by our standard separator
    QStringList artists = normalizedName.split("|||", Qt::SkipEmptyParts);
    QStringList trimmedArtists;

    // Trim whitespace and filter empty entries
    for (QString& artist : artists) {
        artist = artist.trimmed();
        if (!artist.isEmpty()) {
            trimmedArtists << artist;
        }
    }

    // If we end up with no valid artists after splitting, use the original
    if (trimmedArtists.isEmpty()) {
        return QStringList() << artistName.trimmed();
    }

    return trimmedArtists;
}

//=============================================================================
// FUNCTION: Background Task Implementation
//=============================================================================
LocalMusicManager::ScanResults LocalMusicManager::performBackgroundScan(QString parentFolderPath) {
    qDebug() << "[BG Scan] Starting background scan for:" << parentFolderPath << "on thread:" << QThread::currentThreadId();
    ScanResults results;
    QStringList allMp3Files;

    // 1. Find all files (Recursive)
    recursiveScan(parentFolderPath, allMp3Files);
    qDebug() << "[BG Scan] Found" << allMp3Files.count() << "MP3 file paths.";
    if (allMp3Files.isEmpty()) {
        qWarning() << "[BG Scan] No MP3 files found.";
        return results; 
    }

    // 2. Read tags and populate results
    results.cachedTracks.reserve(allMp3Files.count());
    int totalFiles = allMp3Files.count();
    for(int i = 0; i < totalFiles; ++i) {
        const QString& filePath = allMp3Files.at(i);
        QVariantMap trackData = readId3Tags(filePath);
        if (!trackData.value("filePath").toString().isEmpty()) {
            results.cachedTracks.append(trackData);
			// Process Artists
            QString artistValue = trackData.value("artist", "Unknown Artist").toString();
            QStringList individualArtists = splitArtistName(artistValue);
            for (const QString& artist : individualArtists) {
                if (!artist.isEmpty()) {
                    results.uniqueArtists.insert(artist); 
                }
            }
			// Process Albums
            QString albumValue = trackData.value("album", "Unknown Album").toString();
            if (albumValue != "Unknown Album") {
                results.uniqueAlbums.insert(albumValue);
                results.albumTrackCounts[albumValue]++; 
            }
        } 
    } 
    qDebug() << "[BG Scan] Finished reading tags. Found" << results.cachedTracks.count() 
			 << "tracks and" << results.uniqueArtists.count() << "artists, and"
			 << results.uniqueAlbums.count() << "albums.";
    return results;
}

//=============================================================================
// SLOT: Handles results from background thread
//=============================================================================
void LocalMusicManager::handleScanFinished() {
	// 1. Start scan
    qDebug() << "[LocalMusicManager] >>> handleScanFinished SLOT STARTING on thread:" << QThread::currentThreadId();
    emit scanStateChanged(false);
    if (m_scanWatcher.isCanceled()) {
        qDebug() << "[LocalMusicManager] Scan was cancelled.";
        emit loadingProgress(0, 0);
        return;
    }
    ScanResults results = m_scanWatcher.result();
    qDebug() << "[LocalMusicManager] Received scan results. Tracks:" << results.cachedTracks.count();

    // 2. Update caches and index hashes
    m_cachedFullTrackData = results.cachedTracks; 
	m_albumTrackCounts = results.albumTrackCounts;
    m_artistIndexHash.clear();
    m_albumIndexHash.clear();
    for(int i = 0; i < m_cachedFullTrackData.size(); ++i) {
		const QVariantMap& track = m_cachedFullTrackData.at(i);
		// Artist Indexing
        QString artistValue = track.value("artist", "Unknown Artist").toString();
        QStringList individualArtists = splitArtistName(artistValue);
        for (const QString& artist : individualArtists) {
            if (!artist.isEmpty()) {
                m_artistIndexHash.insert(artist, i);
            }
        }
		// Album Indexing
        QString albumValue = track.value("album", "Unknown Album").toString();
        if (albumValue != "Unknown Album") {
            m_albumIndexHash.insert(albumValue, i);
        }
    }
    qDebug() << "[LocalMusicManager] Caches updated.";

    // 3. Build Sidebar List based on current grouping
	rebuildSidebarModel();

    // 4. emit full track list
    QVariantList tracksForSignal;
    tracksForSignal.reserve(m_cachedFullTrackData.size());
    for (const QVariantMap& trackMap : m_cachedFullTrackData) { tracksForSignal.append(trackMap); }
    qDebug() << "[LocalMusicManager] Emitting tracksReadyForDisplay()";
    emit tracksReadyForDisplay(tracksForSignal);
    emit loadingProgress(m_cachedFullTrackData.count(), m_cachedFullTrackData.count());
    qDebug() << "[LocalMusicManager] <<< handleScanFinished SLOT EXITED.";
}

//=============================================================================
// SLOT: Changes grouping and rebuilds the sidebar model
//=============================================================================
void LocalMusicManager::setGrouping(const QString& grouping) {
    if (m_currentGrouping == grouping) return; 
    qDebug() << "[LocalMusicManager] Grouping changed to:" << grouping;
    m_currentGrouping = grouping;
    rebuildSidebarModel();
}

//=============================================================================
// HELPER: Builds the sidebar list based on current grouping
//=============================================================================
void LocalMusicManager::rebuildSidebarModel() {
	QVariantList newSidebarItems;
	// 1. Add "All Tracks" item (always present)
    if (!m_cachedFullTrackData.isEmpty()) {
        QVariantMap allTracksMap;
        allTracksMap["type"] = "local_all";
        allTracksMap["name"] = "All Tracks";
        allTracksMap["id"] = ALL_TRACKS_IDENTIFIER;
        allTracksMap["iconSource"] = "qrc:/icons/all_tracks_icon.png";
        allTracksMap["count"] = m_cachedFullTrackData.size();
        newSidebarItems.append(allTracksMap);
    }

    // 2. Add items based on current grouping mode
	if (m_currentGrouping == "ARTISTS") {
		QStringList sortedArtists = m_artistIndexHash.uniqueKeys();
		sortedArtists.sort(Qt::CaseInsensitive);
		for(const QString& artistName : sortedArtists) {
			QVariantMap artistMap;
			artistMap["type"] = "local_artist";
			artistMap["name"] = artistName;
			artistMap["id"] = artistName; 
			artistMap["iconSource"] = "qrc:/icons/artist_icon.png";
			artistMap["count"] = m_artistIndexHash.count(artistName);
			newSidebarItems.append(artistMap);
		}
	} else if (m_currentGrouping == "ALBUMS") {
        QStringList sortedAlbums = m_albumIndexHash.uniqueKeys();
        sortedAlbums.sort(Qt::CaseInsensitive);
        for (const QString& albumName : sortedAlbums) {
            int trackCount = m_albumTrackCounts.value(albumName, 0);
            if (m_currentGrouping == "ALBUMS" && trackCount <= 1) {
                continue;
            }
            QVariantMap albumMap;
            albumMap["type"] = "local_album";
            albumMap["name"] = albumName;
            albumMap["id"] = albumName;
            albumMap["iconSource"] = "qrc:/icons/album_icon.png";
            albumMap["count"] = trackCount;
			// Album: Get cover art
			if (m_albumIndexHash.contains(albumName)) {
				int firstTrackIndex = m_albumIndexHash.value(albumName);
				if (firstTrackIndex >= 0 && firstTrackIndex < m_cachedFullTrackData.size()) {
                    const QVariantMap& trackData = m_cachedFullTrackData.at(firstTrackIndex);
                    const QString imageBase64 = trackData.value("imageBase64").toString();
                    if (!imageBase64.isEmpty()) {
                        const QString mimeType = trackData.value("imageMimeType", "image/jpeg").toString();
                        // Format the string as a data URI for QML's Image source
                        albumMap["iconSource"] = QString("data:%1;base64,%2").arg(mimeType, imageBase64);
                    }
                }
			}
            newSidebarItems.append(albumMap);
        }
    }
	qDebug() << "[LocalMusicManager] New sidebar list built for grouping" 
		     << m_currentGrouping << ". Count:" << newSidebarItems.count();

	// 3. Emit sidebarItemsChanged
    if (m_sidebarItems != newSidebarItems) {
        m_sidebarItems = newSidebarItems;
        emit sidebarItemsChanged();
    }
}

//=============================================================================
// HELPER: Recursively finds all MP3 file paths
//=============================================================================
void LocalMusicManager::recursiveScan(const QString& folderPath, QStringList& foundMp3Files) {
    QDir directory(folderPath);
    if (!directory.exists()) return;

    // Process files in the current directory
    QStringList filters;
    filters << "*.mp3";
    QFileInfoList fileInfoList = directory.entryInfoList(filters, QDir::Files | QDir::Readable);
    for (const QFileInfo &fileInfo : fileInfoList) {
        foundMp3Files.append(fileInfo.absoluteFilePath());
    }

    // Recursively process subdirectories
    QFileInfoList dirInfoList = directory.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable);
    for (const QFileInfo &dirInfo : dirInfoList) {
        recursiveScan(dirInfo.absoluteFilePath(), foundMp3Files); // Recurse
    }
}

//=============================================================================
// SLOT: Loads tracks for a given identifier (artist/album)
//=============================================================================
void LocalMusicManager::loadTracksFor(const QString& identifier, const QString& type) {
	qDebug() << "[LocalMusicManager] Request received to load tracks for:" << identifier << "of type:" << type;
    if (m_selectedParentFolder.isEmpty()) {
        emit tracksReadyForDisplay(QVariantList());
        return;
    }

    QVariantList tracksToShow;
	QList<int> indices;

    if (identifier == ALL_TRACKS_IDENTIFIER || type == "local_all") {
        qDebug() << "[loadTracksFor] Loading ALL tracks from cache.";
        // *** CONVERT m_cachedFullTrackData to QVariantList for assignment ***
        //tracksToShow.reserve(m_cachedFullTrackData.size());
        for (const QVariantMap& trackMap : m_cachedFullTrackData) {
            tracksToShow.append(trackMap); 
        }
    } else if (type == "local_artist") {
        qDebug() << "[loadTracksFor" << identifier << "] Filtering cache for artist:" << identifier;
        indices = m_artistIndexHash.values(identifier);
    } else if (type == "local_album") {
		qDebug() << "[loadTracksFor" << identifier << "] Filtering cache for album:" << identifier;
		indices = m_albumIndexHash.values(identifier);
	}

	if (!indices.isEmpty()) {
        tracksToShow.reserve(indices.size());
        qDebug() << "[loadTracksFor] Found" << indices.size() << "indices.";
        for (int index : indices) {
            if (index >= 0 && index < m_cachedFullTrackData.size()) {
                tracksToShow.append(m_cachedFullTrackData.at(index));
            }
        }
    }
	
    qDebug() << "[loadTracksFor] Emitting" << tracksToShow.count() << "tracks for display.";
    emit tracksReadyForDisplay(tracksToShow);
}

//=============================================================================
// FUNCTION: Reads ID3 tags
//=============================================================================
QVariantMap LocalMusicManager::readId3Tags(const QString& filePath) {
    QVariantMap tagsMap;
    QString imageBase64 = "";
    QString imageMimeType = "";
    bool basicTagsRead = false;

    tagsMap["source"] = "local"; // Add source type for local files

    try {
        { // FileRef scope
			QByteArray pathUtf8 = filePath.toUtf8();
			TagLib::FileRef f(pathUtf8.constData());
            if (!f.isNull()) {
                TagLib::Tag *basicTag = f.tag();
                if (basicTag) {
                    tagsMap["title"] = QString::fromUtf8(basicTag->title().toCString(true)).isEmpty() ? QFileInfo(filePath).baseName() : QString::fromUtf8(basicTag->title().toCString(true));
                    tagsMap["artist"] = QString::fromUtf8(basicTag->artist().toCString(true)).isEmpty() ? "Unknown Artist" : QString::fromUtf8(basicTag->artist().toCString(true));
                    tagsMap["album"] = QString::fromUtf8(basicTag->album().toCString(true)).isEmpty() ? "Unknown Album" : QString::fromUtf8(basicTag->album().toCString(true));
                    tagsMap["genre"] = QString::fromUtf8(basicTag->genre().toCString(true));
                    tagsMap["year"] = basicTag->year();
                    tagsMap["track"] = basicTag->track();
                    tagsMap["filePath"] = filePath;
                    basicTagsRead = true;
                } else { qWarning() << "[readId3Tags] TagLib::FileRef::tag() returned NULL for:" << filePath; }
            } else { qWarning() << "[readId3Tags] TagLib::FileRef creation failed (isNull) for:" << filePath; }
        } // End FileRef scope


        TagLib::ID3v2::Tag *id3v2tag = nullptr;
        { // MPEG::File scope for image extraction
		  QByteArray utf8Path = filePath.toUtf8();
          TagLib::MPEG::File mpegFile(utf8Path.constData(), false, TagLib::AudioProperties::Fast);
            if (mpegFile.isValid() && mpegFile.hasID3v2Tag()) {
                id3v2tag = mpegFile.ID3v2Tag();
                if (id3v2tag) {
                    TagLib::ID3v2::FrameListMap frameListMap = id3v2tag->frameListMap();
                    if (frameListMap.contains("APIC")) {
                        TagLib::ID3v2::FrameList apicFrames = frameListMap["APIC"];
                        if (!apicFrames.isEmpty()) {
                            TagLib::ID3v2::AttachedPictureFrame *pictureFrame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(apicFrames.front());
                            if (pictureFrame) {
                                imageMimeType = QString::fromStdString(pictureFrame->mimeType().to8Bit(true));
                                TagLib::ByteVector pictureData = pictureFrame->picture();
                                if (!pictureData.isEmpty()) {
                                    QByteArray imageData(pictureData.data(), pictureData.size());
                                    imageBase64 = QString::fromUtf8(imageData.toBase64());
                                }
                            }
                        }
                    }
                }
            }
        } // End MPEG::File scope

    } catch (const std::exception& e) { qWarning() << "[readId3Tags] Exception processing TagLib for" << filePath << ":" << e.what(); }
    catch (...) { qWarning() << "[readId3Tags] Unknown exception processing TagLib for" << filePath; }

    // Fallback Logic
    if (!basicTagsRead) {
        qDebug() << "[readId3Tags] Applying fallback data for file:" << filePath;
        tagsMap.clear();
        tagsMap["title"] = QFileInfo(filePath).baseName();
        tagsMap["artist"] = "Unknown Artist";
        tagsMap["album"] = "Unknown Album";
        tagsMap["genre"] = "";
        tagsMap["year"] = 0;
        tagsMap["track"] = 0;
        tagsMap["filePath"] = filePath;
        tagsMap["imageBase64"] = "";
        tagsMap["imageMimeType"] = "";
        tagsMap["source"] = "local"; // Also add source to fallback
    } else {
        tagsMap.insert("imageBase64", imageBase64);
        tagsMap.insert("imageMimeType", imageMimeType);
        // Safety checks (optional if confident)
        tagsMap.insert("artist", tagsMap.value("artist", "Unknown Artist"));
        tagsMap.insert("album", tagsMap.value("album", "Unknown Album"));
        tagsMap.insert("title", tagsMap.value("title", QFileInfo(filePath).baseName()));
    }

    // Final Log & Return
    // qDebug() << "[readId3Tags] Returning map for file:" << filePath << " Title:" << tagsMap.value("title");
    if (tagsMap.value("filePath").toString().isEmpty()) {
        qWarning() << "[readId3Tags] FATAL: Returning map WITHOUT filePath for:" << filePath;
        return QVariantMap();
    }
    return tagsMap;
}

