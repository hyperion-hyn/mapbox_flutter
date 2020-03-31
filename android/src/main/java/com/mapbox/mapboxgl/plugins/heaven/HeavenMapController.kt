package com.mapbox.mapboxgl.plugins.heaven

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Log
import com.mapbox.mapboxgl.R
import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import com.mapbox.mapboxsdk.plugins.annotation.SymbolManager
import com.mapbox.mapboxsdk.style.layers.PropertyFactory.*
import com.mapbox.mapboxsdk.style.sources.TileSet
import com.mapbox.mapboxsdk.style.sources.VectorSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.mapbox.mapboxsdk.style.expressions.*
import com.mapbox.mapboxsdk.style.layers.*

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
                result.success("heaven_map#addData")
                return true;
            }
            "heaven_map#removeData" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    removeData(id)
                }
                result.success("heaven_map#removeData")
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
            print("[Android] mapbox, source:${source} is not null")
            return
        }
        val tileSet = TileSet("2.1.0", model.sourceUrl)
        val vectorSource = VectorSource(sourceId, tileSet)
        style?.addSource(vectorSource)

        print("[Android] mapbox, layer${model.sourceLayer}, style:${model.sourceUrl}")
    }

    private fun addLayer(context: Context, model: HeavenDataModel) {

        val sourceId = getSourceId(model.id)
        val layerId = getLayerId(model.id)
        val sourceLayer = getLayerId(model.sourceLayer)
        if (style?.getLayer(layerId) != null) {
            print("[Android] mapbox, sourceLayer:${sourceLayer} is not null")
            return
        }

        var imageMap = mapOf("layer-heaven-police" to R.mipmap.police
                , "layer-heaven-embassy" to R.mipmap.embassy)

        val color = String.format("#%06X", 0xFFFFFF.and(model.color))


        var layers = style?.layers;

        var symbolGeojsonLayer = "";

        for (layerTemp in style!!.layers) {
            if (layerTemp.id.startsWith("mapbox-android-symbol-layer", true)) {
                symbolGeojsonLayer = layerTemp.id
            }
        }

        if (model.sourceLayer != "poi") {
            if (imageMap[sourceLayer] != null) {
                val newLayer = SymbolLayer(layerId, sourceId)
                        .withProperties(iconImage(sourceLayer))
                        .withSourceLayer(model.sourceLayer)
                style?.addImage(sourceLayer, BitmapFactory.decodeResource(
                        context.resources, imageMap[sourceLayer]!!))
                style?.addLayerBelow(newLayer, symbolGeojsonLayer)
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
                style?.addLayerBelow(newLayer, symbolGeojsonLayer)
            }
            print("[Android] mapbox, model.sourceLayer != \"poi\"")
        }
        else {
            /*
            * layerId: 当前layer的身份id
            * souceId: 当前layer的数据源
            * sourceLayer: 当前layer展示的父layer（必填项）
            * 说明：在一个地图中，父layer可能又很多，
            * 比如：poiLayer，policeLayer，embassyLayer，and so on.
            * 区别：sourceLayer  vs styleLayer
            * */
            val newLayer = HeatmapLayer(layerId, sourceId).withSourceLayer(model.sourceLayer)
            newLayer.setMaxZoom(18.0f)
            newLayer.setProperties(
                    PropertyFactory.heatmapColor(
                            Expression.interpolate(
                                    Expression.linear(), Expression.heatmapDensity(),
                                    Expression.literal(0),Expression.rgba(33,102,172,0),
                                    Expression.literal(0.2),Expression.rgba(103,169,207,1.0),
                                    Expression.literal(0.4),Expression.rgba(209,229,240,1.0),
                                    Expression.literal(0.6),Expression.rgba(253,219,199,1.0),
                                    Expression.literal(0.8),Expression.rgba(239,138,98,1.0),
                                    Expression.literal(1),Expression.rgba(178,24,43,1.0)
                                    )
                    ),
                    PropertyFactory.heatmapWeight(
                            Expression.interpolate(
                                    Expression.linear(), Expression.get("mag"),
                                    Expression.stop(0,0),
                                    Expression.stop(0,0)
                                    )
                    ),
                    PropertyFactory.heatmapIntensity(
                            Expression.interpolate(
                                    Expression.linear(), Expression.zoom(),
                                    Expression.stop(0,1),
                                    Expression.stop(18,3)
                            )
                    ),
                    PropertyFactory.heatmapRadius(
                            Expression.interpolate(
                                    Expression.linear(), Expression.zoom(),
                                    Expression.stop(0,2),
                                    Expression.stop(18,20)
                            )
                    ),
                    PropertyFactory.heatmapOpacity(
                            Expression.interpolate(
                                    Expression.linear(), Expression.zoom(),
                                    Expression.stop(7,1),
                                    Expression.stop(18,0)
                            )
                    )

            )

            style?.addLayerAbove(newLayer, symbolGeojsonLayer)
            print("[Android] mapbox, model.sourceLayer == \"poi\"")


            val circleLayer = CircleLayer("circle_layer_id", sourceId).withSourceLayer(model.sourceLayer)

            circleLayer.setProperties(
                    PropertyFactory.circleRadius(
                            Expression.interpolate(
                                    Expression.linear(),
                                    Expression.zoom(),
                                    Expression.literal(7),
                                    Expression.interpolate(
                                        Expression.linear(), Expression.get("mag"),
                                        Expression.stop(1,1),
                                        Expression.stop(6,4)
                                    ),
                                    Expression.literal(16),
                                    Expression.interpolate(
                                        Expression.linear(), Expression.get("mag"),
                                        Expression.stop(1,5),
                                        Expression.stop(6,50)
                                    )
                            )
                    ),
                    PropertyFactory.circleColor(
                            Expression.interpolate(
                                    Expression.linear(), Expression.get("mag"),
                                    Expression.literal(1),Expression.rgba(33,102,172,0),
                                    Expression.literal(2),Expression.rgba(103,169,207,1.0),
                                    Expression.literal(3),Expression.rgba(209,229,240,1.0),
                                    Expression.literal(4),Expression.rgba(253,219,199,1.0),
                                    Expression.literal(5),Expression.rgba(239,138,98,1.0),
                                    Expression.literal(6),Expression.rgba(178,24,43,1.0)
                            )
                    ),
                    PropertyFactory.circleOpacity(
                            Expression.interpolate(
                                    Expression.linear(), Expression.zoom(),
                                    Expression.stop(7,0),
                                    Expression.stop(8,1)
                            )
                    ),
                    PropertyFactory.circleStrokeColor("white"),
                    PropertyFactory.circleStrokeWidth(1.0f)
            )
            style?.addLayerBelow(circleLayer, layerId)

            /*val newLayers = CircleLayer("circle_layer_id", sourceId)
                    .withProperties(
                            circleRadius(8f),
                            circleColor(color),
                            circleStrokeColor("#ffffff"),
                            circleStrokeWidth(2f),
                            circleStrokeOpacity(0.8f),
                            circlePitchAlignment(Property.CIRCLE_PITCH_ALIGNMENT_MAP)
                    ).withSourceLayer("circle_layer_id")
            style?.addLayerBelow(newLayers, layerId)
            */
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
