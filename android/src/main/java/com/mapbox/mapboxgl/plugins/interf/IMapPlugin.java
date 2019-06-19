package com.mapbox.mapboxgl.plugins.interf;

import androidx.annotation.NonNull;

import com.mapbox.mapboxsdk.maps.MapView;
import com.mapbox.mapboxsdk.maps.MapboxMap;
import com.mapbox.mapboxsdk.maps.Style;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public interface IMapPlugin {
    void onMapboxStyleLoaded(MapView mapView, MapboxMap mapboxMap, @NonNull Style style);

    boolean onMethodCall(MethodCall call, MethodChannel.Result result);

    void onDestroy();
}
