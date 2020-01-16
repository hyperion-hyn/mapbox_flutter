package com.mapbox.mapboxgl.plugins.heaven

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import com.mapbox.mapboxgl.R
import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import com.mapbox.mapboxsdk.plugins.annotation.SymbolManager
import com.mapbox.mapboxsdk.style.layers.CircleLayer
import com.mapbox.mapboxsdk.style.layers.Property
import com.mapbox.mapboxsdk.style.layers.PropertyFactory.*
import com.mapbox.mapboxsdk.style.layers.SymbolLayer
import com.mapbox.mapboxsdk.style.sources.TileSet
import com.mapbox.mapboxsdk.style.sources.VectorSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HeavenMapController(private var initModels: List<HeavenDataModel>? = null) : IMapPlugin, HeavenMapOptionsSink {
    private var mapView: MapView? = null
    private var mapboxMap: MapboxMap? = null
    private var style: Style? = null

    private val methodChannel: MethodChannel? = null

    val MARKER_IMAGE_ID = "hyn-marker-image"

    override fun onMapboxStyleLoaded(mapView: MapView, mapboxMap: MapboxMap, style: Style) {
        this.mapView = mapView
        this.mapboxMap = mapboxMap
        this.style = style
        //init data layer
        val models = this.initModels
        if (models != null && models.isNotEmpty() && mapView.context != null) {
            for (model in models) {
                addData(mapView.context, model)
            }
        }
        println(style.url)
        style.addImage(
                MARKER_IMAGE_ID,
                BitmapFactory.decodeResource(
                        mapView.context!!.resources, R.mipmap.marker_big
                )
        )
    }

    override fun onMethodCall(mapView: MapView, call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "heaven_map#addData" -> {
                val model = mapToModel(call.argument<Map<*, *>>("model"))
                if (model != null) {
                    addData(mapView.context, model)
                }
                result.success(null)
                return true;
            }
            "heaven_map#removeData" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    removeData(id)
                }
                result.success(null)
                return true
            }
        }
        return false
    }

    override fun onDestroy() {}

    override fun addData(context: Context, model: HeavenDataModel) {
        addSource(model)
        addLayer(context, model)
    }

    private fun addSource(model: HeavenDataModel) {
        val sourceId = getSourceId(model.id)
        val source = style?.getSource(sourceId)
        if (source != null) {
            return
        }
        val tileSet = TileSet("2.1.0", model.sourceUrl)
        val vectorSource = VectorSource(sourceId, tileSet)
        style?.addSource(vectorSource)
    }

    private fun addLayer(context: Context, model: HeavenDataModel) {


        val sourceId = getSourceId(model.id)
        val layerId = getLayerId(model.id)
        val sourceLayer = getLayerId(model.sourceLayer)
        if (style?.getLayer(layerId) != null) {
            return
        }

        var imageMap = mapOf("layer-heaven-police" to R.mipmap.police
                , "layer-heaven-embassy" to R.mipmap.embassy)

        val color = String.format("#%06X", 0xFFFFFF.and(model.color))

        if (imageMap[sourceLayer] != null) {
            val newLayer = SymbolLayer(layerId, sourceId)
                    .withProperties(iconImage(sourceLayer))
                    .withSourceLayer(model.sourceLayer)
            style?.addImage(sourceLayer, BitmapFactory.decodeResource(
                    context.resources, imageMap[sourceLayer]!!))
            style?.addLayerBelow(newLayer, SymbolManager.ID_GEOJSON_LAYER)
        } else {
            val newLayer = CircleLayer(layerId, sourceId)
                    .withProperties(
                            circleRadius(8f),
                            circleColor(color),
                            circleStrokeColor("#ffffff"),
                            circleStrokeWidth(2f),
                            circleStrokeOpacity(0.8f),
                            circlePitchAlignment(Property.CIRCLE_PITCH_ALIGNMENT_MAP)
                    ).withSourceLayer(model.sourceLayer)
            style?.addLayerBelow(newLayer, SymbolManager.ID_GEOJSON_LAYER)
        }

    }

    override fun removeData(id: String) {
        val layerId = getLayerId(id)
        style?.removeLayer(layerId)
        val sourceId = getSourceId(id)
        style?.removeSource(sourceId)
    }

    private fun getLayerId(id: String): String {
        return "layer-heaven-$id"
    }

    private fun getSourceId(sourceId: String): String {
        return "source-heaven-$sourceId"
    }

    private fun mapToModel(map: Map<*, *>?): HeavenDataModel? {
        if (map != null && map["id"] is String && map["sourceUrl"] is String && map["color"] is Number) {
            return HeavenDataModel(map["id"] as String, map["sourceUrl"] as String, (map["color"] as Number).toInt(), map["sourceLayer"] as String);
        }
        return null
    }
}
