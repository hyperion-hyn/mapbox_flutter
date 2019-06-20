package com.mapbox.mapboxgl.plugins.route

import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MapRouteController(private var initRouteDataModel: MapRouteDataModel? = null) : IMapPlugin, MapRouteSink {

    private var routeOverlay: RouteOverlay? = null

    override fun addRouteOverlay(routeDataModel: MapRouteDataModel?) {
        routeOverlay = DriveRouteOverlay(
                mapView?.context!!,
                mapboxMap!!,
                mapView!!,
                routeDataModel!!.directionsResponse,
                routeDataModel.startLatLng,
                routeDataModel.endLatLng,
                routeDataModel.paddingTop,
                routeDataModel.paddingBottom,
                routeDataModel.paddingLeft,
                routeDataModel.paddingRight
        )
        routeOverlay?.addToMap()
    }

    override fun removeRouteOverlay() {
        routeOverlay?.removeFromMap()
    }

    private var mapView: MapView? = null
    private var mapboxMap: MapboxMap? = null
    private var style: Style? = null

    private val methodChannel: MethodChannel? = null

    override fun onMapboxStyleLoaded(mapView: MapView, mapboxMap: MapboxMap, style: Style) {
        this.mapView = mapView
        this.mapboxMap = mapboxMap
        this.style = style
        //init data layer
        val initRouteDataModel = this.initRouteDataModel
        if (initRouteDataModel != null) {
            addRouteOverlay(initRouteDataModel)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "map_route#addRouteOverlay" -> {
                val model = MapRouteDataModel.interpretOptions(call.argument<Map<*, *>>("model")!!)
                if(model != null) {
                    addRouteOverlay(model)
                }
                result.success(null)
                return true;
            }
            "map_route#removeRouteOverlay" -> {
                removeRouteOverlay()
                result.success(null)
                return true
            }
        }
        return false
    }

    override fun onDestroy() {}
}
