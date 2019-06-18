package com.mapbox.mapboxgl.plugins.interf

interface IMapPluginBuilder {
    fun getPluginName(): String
    fun interpretOptions(options: Any?): IMapPluginBuilder
    fun build(): IMapPlugin
}