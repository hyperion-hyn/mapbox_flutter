package com.mapbox.mapboxgl.plugins.route;


public interface MapRouteSink {
    void addRouteOverlay(MapRouteDataModel routeDataModel);

    void removeRouteOverlay();
}