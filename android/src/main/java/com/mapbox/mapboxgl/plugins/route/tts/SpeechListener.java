package com.mapbox.mapboxgl.plugins.route.tts;

import com.mapbox.services.android.navigation.ui.v5.voice.SpeechAnnouncement;

public interface SpeechListener {

    void onStart();

    void onDone();

    void onError(String errorText, SpeechAnnouncement speechAnnouncement);
}
