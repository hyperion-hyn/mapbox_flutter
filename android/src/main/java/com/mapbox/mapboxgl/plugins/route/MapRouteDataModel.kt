package com.mapbox.mapboxgl.plugins.route

import com.google.gson.GsonBuilder
import com.mapbox.api.directions.v5.DirectionsAdapterFactory
import com.mapbox.api.directions.v5.WalkingOptionsAdapterFactory
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.geojson.Point
import com.mapbox.geojson.PointAsCoordinatesTypeAdapter
import com.mapbox.mapboxsdk.geometry.LatLng

data class MapRouteDataModel(
        val startLatlng: LatLng,
        val endLatLng: LatLng,
        val directionsResponse: DirectionsResponse,
        val paddingTop: Int = 200,
        val paddingLeft: Int = 200,
        val paddingRight: Int = 200,
        val paddingBottom: Int = 200
) {


    companion object {
        fun fromJson(json: String): MapRouteDataModel {
            val gson = GsonBuilder()
            gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
            gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
            return gson.create().fromJson(json, MapRouteDataModel::class.java) as MapRouteDataModel
        }

        fun toJson(mapRouteDataModel: MapRouteDataModel): String {
            val gson = GsonBuilder()
            gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
            gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
            gson.registerTypeAdapterFactory(WalkingOptionsAdapterFactory.create())
            return gson.create().toJson(this)
        }
    }


}