package com.mapbox.mapboxgl.plugins.route.tts;

import com.mapbox.services.android.navigation.ui.v5.voice.SpeechAnnouncement;
import com.mapbox.services.android.navigation.ui.v5.voice.SpeechPlayer;

import timber.log.Timber;

public class NavigationSpeechListener implements SpeechListener {
    private SpeechPlayer speechPlayer;
    private SpeechAudioFocusManager audioFocusManager;

    NavigationSpeechListener(SpeechPlayer speechPlayer, SpeechAudioFocusManager audioFocusManager) {
        this.speechPlayer = speechPlayer;
        this.audioFocusManager = audioFocusManager;
    }

    public void onStart() {
        this.audioFocusManager.requestAudioFocus();
    }

    public void onDone() {
        this.audioFocusManager.abandonAudioFocus();
    }

    public void onError(String errorText, SpeechAnnouncement speechAnnouncement) {
        Timber.e(errorText, new Object[0]);
        this.speechPlayer.play(speechAnnouncement);
    }
}