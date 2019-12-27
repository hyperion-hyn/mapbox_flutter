package com.mapbox.mapboxgl.plugins

import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxgl.plugins.interf.IMapPluginBuilder
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object MapPluginsManager {
    private val pluginBuilders = mutableMapOf<Int, MutableMap<String, IMapPluginBuilder>>()
    private val plugins = mutableMapOf<Int, MutableMap<String, IMapPlugin>>()

    fun registerBuilder(id: Int, builder: IMapPluginBuilder) {
        var mapPluginBuilders = pluginBuilders[id];
        if (mapPluginBuilders == null) {
            mapPluginBuilders = mutableMapOf<String, IMapPluginBuilder>();
            pluginBuilders[id] = mapPluginBuilders;
        }
        mapPluginBuilders[builder.getPluginName()] = builder
    }

    fun buildPlugins(id: Int) {
        val mapPluginBuilders = pluginBuilders[id]!!;
        for ((name, builder) in mapPluginBuilders) {
            var mapPlugins = plugins[id];
            if (mapPlugins == null) {
                mapPlugins = mutableMapOf<String, IMapPlugin>();
                plugins[id] = mapPlugins;
            }
            mapPlugins[name] = builder.build()
        }
    }

    fun onStyleLoaded(id: Int, mapView: MapView, mapboxMap: MapboxMap, style: Style) {

        val mapPlugins = plugins[id] ?: return

        for ((_, plugin) in mapPlugins) {
            plugin.onMapboxStyleLoaded(mapView, mapboxMap, style)
        }
    }

    fun onMethodCall(id: Int, call: MethodCall, result: MethodChannel.Result): Boolean {
        val mapPlugins = plugins[id] ?: return false
        for ((_, plugin) in mapPlugins) {
            if (plugin.onMethodCall(call, result)) {
                return true;
            }
        }
        return false;
    }

    fun dispose(id: Int) {
        val mapPlugins = plugins[id] ?: return
        for ((_, plugin) in mapPlugins) {
            plugin.onDestroy()
        }

        plugins.remove(id)
        pluginBuilders.remove(id)

    }

}