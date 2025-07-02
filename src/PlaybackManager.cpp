// PlaybackManager.cpp
#include "PlaybackManager.h"
#include <QDebug>
#include <QtMath>

PlaybackManager::PlaybackManager(QObject *parent) : QObject(parent){}

bool PlaybackManager::ready() const {return m_ready;}
double PlaybackManager::volume() const {return m_volume;}
bool PlaybackManager::muted() const {return m_muted;}

// ***** SET MEDIAPLAYER *****
void PlaybackManager::setMediaPlayer(QMediaPlayer *player) {
    bool previousReadyState = m_ready;
    m_ready = false;

    if (m_mediaPlayer == player && m_audioOutput == (player ? player->audioOutput() : nullptr)) {
        m_ready = (m_audioOutput != nullptr); // Stay ready only if output still exists
        if (m_ready != previousReadyState) emit readyChanged(); // Emit if state toggled
        return;
    }

    // Disconnect from OLD AudioOutput
    if (m_audioOutput) {
        disconnect(m_audioOutput, &QAudioOutput::volumeChanged, this, &PlaybackManager::onAudioOutputVolumeChanged);
        disconnect(m_audioOutput, &QAudioOutput::mutedChanged, this, &PlaybackManager::onAudioOutputMutedChanged);
    }
    m_audioOutput = nullptr; // Clear pointer

    m_mediaPlayer = player; // Store player pointer

    if (m_mediaPlayer) {
        m_audioOutput = m_mediaPlayer->audioOutput(); // Get the audioOutput

        if (m_audioOutput) {
            // *** Connect Signals ***
            connect(m_audioOutput, &QAudioOutput::volumeChanged, this, &PlaybackManager::onAudioOutputVolumeChanged);
            connect(m_audioOutput, &QAudioOutput::mutedChanged, this, &PlaybackManager::onAudioOutputMutedChanged);
            double initialGain = m_audioOutput->volume(); // Linear gain (0-1) from output
            m_volume = qPow(initialGain, 1.0 / 3.0);
            m_muted = m_audioOutput->isMuted();
            emit volumeChanged();
            emit mutedChanged();

            // *** SET READY STATE TO TRUE ***
            m_ready = true;
            qDebug() << "[PlaybackManager] Backend is now READY.";

        } else {
            qWarning() << "[PlaybackManager] FAILURE: MediaPlayer provided, but its audioOutput is null!";
            m_ready = false;
        }
    } else {
        qDebug() << "[PlaybackManager] MediaPlayer pointer is null. Backend is NOT ready.";
        m_ready = false;
    }
    // *** Emit readyChanged if the state actually changed ***
    if (m_ready != previousReadyState) {
        qDebug() << "[PlaybackManager] Emitting readyChanged signal. New state:" << m_ready;
        emit readyChanged();
    }
}
void PlaybackManager::setVolume(double linearVolume) { // Parameter is the linear slider value (0-1)
    linearVolume = qBound(0.0, linearVolume, 1.0);

    if (!m_ready || !m_audioOutput) {
        qWarning() << "[PlaybackManager] setVolume called but not ready or no AudioOutput. Ready:" << m_ready << "Output:" << m_audioOutput;
        return;
    }

    // *** APPLY VOLUME CURVE ***.
    double gain = qPow(linearVolume, 3.0); // 3 exp

    // Compare the *GAIN ALGORITHM* with the *CURRENT AUDIO OUTPUT GAIN*
    if (qFuzzyCompare(static_cast<double>(m_audioOutput->volume()), gain)) {
        return; // No significant change in target gain
    }
    m_audioOutput->setVolume(gain); // Send the curved gain value to the output
}
void PlaybackManager::setMuted(bool muted) {
    if (!m_audioOutput) { return; }
    if (m_audioOutput->isMuted() == muted) { return; }
    m_audioOutput->setMuted(muted);
}
void PlaybackManager::onAudioOutputVolumeChanged(qreal currentGain) { // Parameter is the linear gain (0-1) from QAudioOutput
    // *** Convert gain back to linear slider position ***
    double linearSliderPosition = qPow(currentGain, 1.0 / 3.0); // Use the *same* exponent as in setVolume's qPow calculation

    // Compare and update m_volume (which represents the linear slider position)
    if (!qFuzzyCompare(static_cast<double>(m_volume), linearSliderPosition)) {
        m_volume = linearSliderPosition; // Store the linear value
        emit volumeChanged(); // Notify QML (slider value binding uses m_volume)
    }
}
void PlaybackManager::onAudioOutputMutedChanged(bool muted) {
    if (m_muted != muted) {
        m_muted = muted;
        emit mutedChanged();
    }
}
