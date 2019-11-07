package com.mapbox.mapboxgl.plugins.route.tts;

import android.content.Context;
import android.media.AudioManager;
import android.os.Build;
import android.speech.tts.TextToSpeech;
import android.text.TextUtils;

import com.mapbox.services.android.navigation.ui.v5.voice.SpeechAnnouncement;
import com.mapbox.services.android.navigation.ui.v5.voice.SpeechPlayer;

import java.util.HashMap;
import java.util.Locale;

import timber.log.Timber;

import static android.content.Context.AUDIO_SERVICE;

public class AndroidSpeechPlayer implements SpeechPlayer {
    private static final String DEFAULT_UTTERANCE_ID = "default_id";
    private TextToSpeech textToSpeech;
    private SpeechListener speechListener;
    private boolean isMuted;
    private boolean languageSupported = false;

    public AndroidSpeechPlayer(Context context, final String language, final TextToSpeech.OnInitListener initListener) {

        AudioManager audioManager = (AudioManager) context.getSystemService(AUDIO_SERVICE);
        AudioFocusDelegateProvider provider = new AudioFocusDelegateProvider(audioManager);
        SpeechAudioFocusManager audioFocusManager = new SpeechAudioFocusManager(provider);
        speechListener = new NavigationSpeechListener(this, audioFocusManager);

        this.textToSpeech = new TextToSpeech(context, new TextToSpeech.OnInitListener() {
            public void onInit(int status) {
                boolean ableToInitialize = status == 0 && language != null;
                if (!ableToInitialize) {
                    Timber.e("There was an error initializing native TTS");
                } else {
                    AndroidSpeechPlayer.this.setSpeechListener(speechListener);
                    AndroidSpeechPlayer.this.initializeWithLanguage(new Locale(language));
                }
                initListener.onInit(status);
            }
        });
    }

    public void play(SpeechAnnouncement speechAnnouncement) {
        boolean isValidAnnouncement = speechAnnouncement != null && !TextUtils.isEmpty(speechAnnouncement.announcement());
        boolean canPlay = isValidAnnouncement && this.languageSupported && !this.isMuted;
        if (canPlay) {
            this.fireInstructionListenerIfApi14();
            HashMap<String, String> params = new HashMap(1);
            params.put("utteranceId", "default_id");
            this.textToSpeech.speak(speechAnnouncement.announcement(), 1, params);
        }
    }

    public boolean isMuted() {
        return this.isMuted;
    }

    public void setMuted(boolean isMuted) {
        this.isMuted = isMuted;
        if (isMuted) {
            this.muteTts();
        }

    }

    public void onOffRoute() {
        this.muteTts();
    }

    public void onDestroy() {
        if (this.textToSpeech != null) {
            this.textToSpeech.stop();
            this.textToSpeech.shutdown();
        }

    }

    private void muteTts() {
        if (this.textToSpeech.isSpeaking()) {
            this.textToSpeech.stop();
        }

    }

    private void initializeWithLanguage(Locale language) {
        boolean isLanguageAvailable = this.textToSpeech.isLanguageAvailable(language) == 0;
        if (!isLanguageAvailable) {
            Timber.w("The specified language is not supported by TTS");
        } else {
            this.languageSupported = true;
            this.textToSpeech.setLanguage(language);
        }
    }

    private void fireInstructionListenerIfApi14() {
        if (Build.VERSION.SDK_INT < 15) {
            this.speechListener.onStart();
        }

    }

    private void setSpeechListener(SpeechListener speechListener) {
        this.speechListener = speechListener;
        if (Build.VERSION.SDK_INT < 15) {
            this.textToSpeech.setOnUtteranceCompletedListener(new Api14UtteranceListener(speechListener));
        } else {
            this.textToSpeech.setOnUtteranceProgressListener(new UtteranceListener(speechListener));
        }

    }
}