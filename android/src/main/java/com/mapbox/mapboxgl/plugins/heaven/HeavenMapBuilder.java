package com.mapbox.mapboxgl.plugins.heaven;

import android.content.Context;

import com.mapbox.mapboxgl.plugins.interf.IMapPlugin;
import com.mapbox.mapboxgl.plugins.interf.IMapPluginBuilder;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public class HeavenMapBuilder implements HeavenMapOptionsSink, IMapPluginBuilder {

    private HeavenMapOptions options = new HeavenMapOptions();

    @NotNull
    @Override
    public String getPluginName() {
        return "heaven_map";
    }

    @NotNull
    @Override
    public IMapPlugin build() {
        return new HeavenMapController(this.options.getModels());
    }

    @NotNull
    @Override
    public IMapPluginBuilder interpretOptions(@Nullable Object options) {
        return this;
    }

    @Override
    public void addData(Context context, HeavenDataModel model) {
        options.getModels().add(model);
    }

    @Override
    public void removeData(String id) {
        for (HeavenDataModel model : options.getModels()) {
            if (model.getId().equals(id)) {
                options.getModels().remove(model);
                break;
            }
        }
    }
}
