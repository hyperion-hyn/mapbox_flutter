package com.mapbox.mapboxgl.plugins.route.tts;

import android.speech.tts.UtteranceProgressListener;

import androidx.annotation.RequiresApi;

@RequiresApi(
    api = 15
)
class UtteranceListener extends UtteranceProgressListener {
    private SpeechListener speechListener;

    UtteranceListener(SpeechListener speechListener) {
        this.speechListener = speechListener;
    }

    public void onStart(String utteranceId) {
        this.speechListener.onStart();
    }

    public void onDone(String utteranceId) {
        this.speechListener.onDone();
    }

    public void onError(String utteranceId) {
    }
}
