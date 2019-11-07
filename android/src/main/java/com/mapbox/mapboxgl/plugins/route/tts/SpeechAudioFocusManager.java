package com.mapbox.mapboxgl.plugins.route.tts;

class SpeechAudioFocusManager {

  private final AudioFocusDelegate audioFocusDelegate;

  SpeechAudioFocusManager(AudioFocusDelegateProvider provider) {
    audioFocusDelegate = provider.retrieveAudioFocusDelegate();
  }

  void requestAudioFocus() {
    audioFocusDelegate.requestFocus();
  }

  void abandonAudioFocus() {
    audioFocusDelegate.abandonFocus();
  }
}
