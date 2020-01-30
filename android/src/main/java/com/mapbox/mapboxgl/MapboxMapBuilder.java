// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.mapbox.mapboxgl;

import android.content.Context;
import android.util.Log;

import com.mapbox.mapboxsdk.camera.CameraPosition;
import com.mapbox.mapboxsdk.geometry.LatLngBounds;
import com.mapbox.mapboxsdk.maps.MapboxMapOptions;
import com.mapbox.mapboxsdk.maps.Style;

import io.flutter.plugin.common.PluginRegistry;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;


class MapboxMapBuilder implements MapboxMapOptionsSink {
    public final String TAG = getClass().getSimpleName();
    private final MapboxMapOptions options = new MapboxMapOptions()
            .textureMode(true)
            .attributionEnabled(false);
    private boolean trackCameraPosition = false;
    private boolean myLocationEnabled = false;
    private int myLocationTrackingMode = 0;
    private String styleString = Style.MAPBOX_STREETS;
    private List<Integer> compassMargins;
    private boolean enableLogo;
    private boolean enableAttribution;
    private String languageCode;
    private boolean languageEnable;

    MapboxMapController build(
            int id, Context context, AtomicInteger state, PluginRegistry.Registrar registrar) {
        final MapboxMapController controller =
                new MapboxMapController(id, context, state, registrar, options, styleString,
                        compassMargins, enableLogo, enableAttribution, languageCode, languageEnable);
        controller.init();
        controller.setMyLocationEnabled(myLocationEnabled);
        controller.setMyLocationTrackingMode(myLocationTrackingMode);
        controller.setTrackCameraPosition(trackCameraPosition);
        return controller;
    }

    public void setInitialCameraPosition(CameraPosition position) {
        options.camera(position);
    }

    @Override
    public void setCompassEnabled(boolean compassEnabled) {
        options.compassEnabled(compassEnabled);
    }

    @Override
    public void setCameraTargetBounds(LatLngBounds bounds) {
        Log.e(TAG, "setCameraTargetBounds is supported only after map initiated.");
        //throw new UnsupportedOperationException("setCameraTargetBounds is supported only after map initiated.");
        //options.latLngBoundsForCameraTarget(bounds);
    }

    @Override
    public void setStyleString(String styleString) {
        this.styleString = styleString;
        //options. styleString(styleString);
    }

    @Override
    public void setMinMaxZoomPreference(Float min, Float max) {
        if (min != null) {
            options.minZoomPreference(min);
        }
        if (max != null) {
            options.maxZoomPreference(max);
        }
    }

    @Override
    public void setTrackCameraPosition(boolean trackCameraPosition) {
        this.trackCameraPosition = trackCameraPosition;
    }

    @Override
    public void setRotateGesturesEnabled(boolean rotateGesturesEnabled) {
        options.rotateGesturesEnabled(rotateGesturesEnabled);
    }

    @Override
    public void setScrollGesturesEnabled(boolean scrollGesturesEnabled) {
        options.scrollGesturesEnabled(scrollGesturesEnabled);
    }

    @Override
    public void setTiltGesturesEnabled(boolean tiltGesturesEnabled) {
        options.tiltGesturesEnabled(tiltGesturesEnabled);
    }

    @Override
    public void setZoomGesturesEnabled(boolean zoomGesturesEnabled) {
        options.zoomGesturesEnabled(zoomGesturesEnabled);
    }

    @Override
    public void setMyLocationEnabled(boolean myLocationEnabled) {
        this.myLocationEnabled = myLocationEnabled;
    }

    @Override
    public void setMyLocationTrackingMode(int myLocationTrackingMode) {
        this.myLocationTrackingMode = myLocationTrackingMode;
    }

    @Override
    public void setEnableLogo(boolean enableLogo) {
        this.enableLogo = enableLogo;
    }

    @Override
    public void setEnableAttribution(boolean enableAttribution) {
        this.enableAttribution = enableAttribution;
    }

    @Override
    public void setCompassMargins(int left, int top, int right, int bottom) {
        compassMargins = new ArrayList<>();
        compassMargins.add(left);
        compassMargins.add(top);
        compassMargins.add(right);
        compassMargins.add(bottom);
    }

    @Override
    public void setLanguageCode(String languageCode) {
        this.languageCode = languageCode;
    }

    @Override
    public void setLanguageEnable(boolean languageEnable) {
        this.languageEnable = languageEnable;
    }

}
