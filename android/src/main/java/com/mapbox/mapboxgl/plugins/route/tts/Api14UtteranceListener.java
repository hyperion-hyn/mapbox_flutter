package com.mapbox.mapboxgl.plugins.route.tts;

import android.speech.tts.TextToSpeech.OnUtteranceCompletedListener;

class Api14UtteranceListener implements OnUtteranceCompletedListener {
    private SpeechListener speechListener;

    Api14UtteranceListener(SpeechListener speechListener) {
        this.speechListener = speechListener;
    }

    public void onUtteranceCompleted(String utteranceId) {
        this.speechListener.onDone();
    }
}
