// TrackListModel.h
#ifndef TRACKLISTMODEL_H
#define TRACKLISTMODEL_H

#include <QObject>
#include <QVariantList>
#include <QString>
#include <QDebug>

class TrackListModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList tracks READ tracks NOTIFY tracksChanged)

public:
    // Enum to identify sort columns clearly
    enum SortColumn {
        None, // Default or no specific sort
        Title,
        ArtistAlbum, // Composite key: Artist first, then Album
        Album        // Album first
    };
    Q_ENUM(SortColumn) // Make enum usable in QML/meta-system if needed later

    explicit TrackListModel(QObject *parent = nullptr);

    QVariantList tracks() const;

    // Expose current sort state to QML (Optional but useful for UI indicators)
    Q_PROPERTY(SortColumn sortColumn READ sortColumn NOTIFY sortCriteriaChanged)
    Q_PROPERTY(Qt::SortOrder sortOrder READ sortOrder NOTIFY sortCriteriaChanged)
    SortColumn sortColumn() const;
    Qt::SortOrder sortOrder() const;


public slots:
    // Updates the internal list, applies current sort, and emits tracksChanged
    void updateTracks(const QVariantList& newTracks);
    // Clears the internal list and emits tracksChanged
    void clearTracks();
    // Sets the sort criteria and resorts the CURRENTLY held tracks
    void sortTracksBy(SortColumn column, Qt::SortOrder order);
    void updateTrack(const QVariantMap &updatedTrack);

signals:
    void tracksChanged();
    // Signal to notify QML when sort criteria change (for UI indicators)
    void sortCriteriaChanged();

private:
    // Helper function to perform the actual sort on m_tracks
    void applySort();
    // Comparison function for std::sort
    static bool compareTracks(const QVariant& v1, const QVariant& v2, SortColumn column, Qt::SortOrder order);

    // Member variables
    QVariantList m_tracks;
    SortColumn m_sortColumn = SortColumn::None; // Default sort state
    Qt::SortOrder m_sortOrder = Qt::AscendingOrder; // Default sort order
};

#endif // TRACKLISTMODEL_H
