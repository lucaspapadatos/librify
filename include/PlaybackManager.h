#ifndef PLAYBACKMANAGER_H
#define PLAYBACKMANAGER_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

class PlaybackManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    // *** ADD READINESS PROPERTY ***
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit PlaybackManager(QObject *parent = nullptr);

    double volume() const;
    bool muted() const;
    // *** Add getter for ready property ***
    bool ready() const;

    Q_INVOKABLE void setMediaPlayer(QMediaPlayer* player);

public slots:
    void setVolume(double volume);
    void setMuted(bool muted);

signals:
    void volumeChanged();
    void mutedChanged();
    // *** Add signal for readiness ***
    void readyChanged();

private slots:
    void onAudioOutputVolumeChanged(qreal volume);
    void onAudioOutputMutedChanged(bool muted);

private:
    QPointer<QMediaPlayer> m_mediaPlayer = nullptr;
    QPointer<QAudioOutput> m_audioOutput = nullptr;
    double m_volume = 0.5;
    bool m_muted = false;
    // *** Add member for readiness state ***
    bool m_ready = false; // Start as not ready
};

#endif // PLAYBACKMANAGER_H
