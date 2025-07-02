// TrackListModel.cpp
#include "TrackListModel.h"
#include <QVariantMap>
#include <QString>
#include <QtGlobal>   // For Qt::CaseInsensitive
#include <algorithm>  // For std::sort
#include <QFileInfo>

TrackListModel::TrackListModel(QObject *parent) : QObject(parent){}

QVariantList TrackListModel::tracks() const{
    return m_tracks;
}


// --- Getters for Sort Properties ---
TrackListModel::SortColumn TrackListModel::sortColumn() const {
    return m_sortColumn;
}

Qt::SortOrder TrackListModel::sortOrder() const {
    return m_sortOrder;
}
// ------------------------------------

// --- Slot Implementations ---
void TrackListModel::clearTracks(){
    if (!m_tracks.isEmpty()) {
        m_tracks.clear();
        qDebug() << "[TrackListModel] Track list cleared. Emitting tracksChanged.";
        emit tracksChanged();
    }
}

// mp3 retagging
void TrackListModel::updateTrack(const QVariantMap &updatedData) {
    QString filePath = updatedData.value("filePath").toString();
    if (filePath.isEmpty()) {
        qWarning() << "[TrackListModel] updateTrack received empty filePath in data."; // Updated log message
        return;
    }
    qDebug() << "[TrackListModel] updateTrack for:" << filePath; // Updated log message

    bool found = false;
    for (int i = 0; i < m_tracks.size(); ++i) {
        QVariantMap currentTrack = m_tracks[i].toMap();
        if (QFileInfo(currentTrack.value("filePath").toString()).canonicalFilePath() == QFileInfo(filePath).canonicalFilePath()) {
            qDebug() << "  > Found track at index" << i << ". Updating data.";
            m_tracks[i] = updatedData;
            found = true;
            break;
        }
    }

    if (found) {
        applySort();
        qDebug() << "  > Emitting tracksChanged() after single track update and sort.";
        emit tracksChanged();
    } else {
        qWarning() << "[TrackListModel] Track not found in model for single update:" << filePath;
    }
}


// data refreshing
void TrackListModel::updateTracks(const QVariantList& newTracks)
{
    qDebug() << "[TrackListModel] updateTracks called. Received" << newTracks.count() << "tracks.";
    // Store the new list first
    m_tracks = newTracks;
    // Apply the *currently active* sort order to the new list
    applySort(); // Sorts m_tracks in place
    // Emit tracksChanged AFTER sorting
    qDebug() << "[TrackListModel] Track list updated and sorted. Emitting tracksChanged.";
    emit tracksChanged();
}

void TrackListModel::sortTracksBy(SortColumn column, Qt::SortOrder order)
{
    qDebug() << "[TrackListModel] sortTracksBy called. Column:" << column << "Order:" << order;
    if (m_sortColumn != column || m_sortOrder != order) {
        m_sortColumn = column;
        m_sortOrder = order;
        applySort(); // Re-sort the existing list with new criteria
        qDebug() << "[TrackListModel] Sort criteria changed and list resorted. Emitting tracksChanged & sortCriteriaChanged.";
        emit tracksChanged();       // Notify view about data reorder
        emit sortCriteriaChanged(); // Notify UI about header indicators
    } else {
        qDebug() << "[TrackListModel] Sort criteria unchanged.";
    }
}

// --- Private Helper Methods ---

// Sorts the internal m_tracks list based on current m_sortColumn and m_sortOrder
void TrackListModel::applySort()
{
    if (m_sortColumn == SortColumn::None || m_tracks.isEmpty()) {
        // No sorting needed or possible
        // Optional: Could revert to an "original" order if one was stored, but usually not needed.
        qDebug() << "[TrackListModel] applySort: No sort applied (None or empty list).";
        return;
    }

    qDebug() << "[TrackListModel] applySort: Sorting by Column" << m_sortColumn << "Order" << m_sortOrder;

    // Use std::sort with our custom static comparison function
    // Pass the current sort criteria to the comparator lambda which calls the static function
    std::sort(m_tracks.begin(), m_tracks.end(),
              [this](const QVariant& a, const QVariant& b) {
                  // Lambda captures 'this' to access member sort criteria
                  // and calls the static comparison function
                  return TrackListModel::compareTracks(a, b, this->m_sortColumn, this->m_sortOrder);
              });

    qDebug() << "[TrackListModel] applySort: Sorting complete.";
}

// Static comparison function used by std::sort
// Returns true if v1 should come before v2 based on the criteria
bool TrackListModel::compareTracks(const QVariant& v1, const QVariant& v2, SortColumn column, Qt::SortOrder order)
{
    // Should always contain QVariantMap, but check for safety
    if (!v1.canConvert<QVariantMap>() || !v2.canConvert<QVariantMap>()) {
        return false; // Or handle error differently
    }
    QVariantMap map1 = v1.toMap();
    QVariantMap map2 = v2.toMap();

    QString str1, str2; // Strings for comparison
    int result = 0; // Comparison result: <0 if str1<str2, 0 if equal, >0 if str1>str2

    switch (column) {
    case Title:
        str1 = map1.value("title").toString();
        str2 = map2.value("title").toString();
        result = QString::compare(str1, str2, Qt::CaseInsensitive);
        break;

    case ArtistAlbum: { // Composite Key: Artist first, then Album
        QString artist1 = map1.value("artist").toString();
        QString artist2 = map2.value("artist").toString();
        result = QString::compare(artist1, artist2, Qt::CaseInsensitive);
        if (result == 0) { // Artists are the same, compare by Album
            QString album1 = map1.value("album").toString();
            QString album2 = map2.value("album").toString();
            result = QString::compare(album1, album2, Qt::CaseInsensitive);
        }
        // No need for str1/str2 here as result is already determined
        break;
    }

    case Album:
        str1 = map1.value("album").toString();
        str2 = map2.value("album").toString();
        result = QString::compare(str1, str2, Qt::CaseInsensitive);
        break;

    case None:
    default:
        return false; // No sorting or unknown column
    }

    // Apply sort order
    if (order == Qt::AscendingOrder) {
        return result < 0; // For ascending, return true if v1 comes before v2 (result is negative)
    } else { // DescendingOrder
        return result > 0; // For descending, return true if v1 comes after v2 (result is positive)
    }
}
// ----------------------------
