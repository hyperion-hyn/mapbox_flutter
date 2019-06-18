package com.mapbox.mapboxgl.plugins.heaven;

public interface HeavenMapOptionsSink {
    void addData(HeavenDataModel model);
    void removeData(String id);
}
