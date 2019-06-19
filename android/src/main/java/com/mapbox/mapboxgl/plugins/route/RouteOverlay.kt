package com.mapbox.mapboxgl.plugins.route

import android.content.Context
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.mapboxsdk.geometry.LatLng
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap

abstract class RouteOverlay(
    private val context: Context,
    private val mapboxMap: MapboxMap,
    private val mapView: MapView,
    private val routeResponseDto: DirectionsResponse,
    private val start: LatLng,
    private val end: LatLng
) {

    abstract fun addToMap()

    abstract fun removeFromMap()
}
