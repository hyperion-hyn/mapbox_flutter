package com.mapbox.mapboxgl.plugins

import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxgl.plugins.interf.IMapPluginBuilder
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object MapPluginsManager {
    private val pluginBuilders = mutableMapOf<String, IMapPluginBuilder>()
    private val plugins = mutableMapOf<String, IMapPlugin>()

    fun registerBuilder(builder: IMapPluginBuilder) {
        pluginBuilders[builder.getPluginName()] = builder
    }

    fun buildPlugins() {
        for ((name, builder) in pluginBuilders) {
            plugins[name] = builder.build()
        }
    }

    fun enablePlugins(mapView: MapView, mapboxMap: MapboxMap, style: Style) {
        for ((_, plugin) in plugins) {
            plugin.enableManager(mapView, mapboxMap, style)
        }
    }

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        for ((_, plugin) in plugins) {
            if(plugin.onMethodCall(call, result)) {
                return true;
            }
        }
        return false;
    }

    fun dispose() {
        for ((_, plugin) in plugins) {
            plugin.onDestroy()
        }
    }

}