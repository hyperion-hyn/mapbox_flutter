package com.mapbox.mapboxgl.plugins.heaven;

import android.content.Context;

public interface HeavenMapOptionsSink {
    void addData(Context context, HeavenDataModel model);
    void removeData(String id);
}
