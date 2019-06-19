package com.mapbox.mapboxgl.plugins.route;

import com.mapbox.mapboxgl.plugins.interf.IMapPlugin;
import com.mapbox.mapboxgl.plugins.interf.IMapPluginBuilder;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public class MapRouteBuilder implements MapRouteSink, IMapPluginBuilder {

    private MapRouteOptions options = new MapRouteOptions();

    @NotNull
    @Override
    public String getPluginName() {
        return "map_route";
    }

    @NotNull
    @Override
    public IMapPlugin build() {
        return new MapRouteController(this.options.getMapRouteDataModel());
    }

    @NotNull
    @Override
    public IMapPluginBuilder interpretOptions(@Nullable Object options) {
        return this;
    }



    @Override
    public void addRouteOverlay(MapRouteDataModel routeDataModel) {

        options.setMapRouteDataModel(routeDataModel);
    }

    @Override
    public void removeRouteOverlay() {
        options.setMapRouteDataModel(null);
    }
}
