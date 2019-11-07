package com.mapbox.mapboxgl.plugins.route.tts;

interface AudioFocusDelegate {

  void requestFocus();

  void abandonFocus();
}
