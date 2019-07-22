package com.mapbox.mapboxgl.plugins.route

import com.google.gson.GsonBuilder
import com.mapbox.api.directions.v5.DirectionsAdapterFactory
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.geojson.Point
import com.mapbox.geojson.PointAsCoordinatesTypeAdapter
import com.mapbox.mapboxsdk.geometry.LatLng

data class MapRouteDataModel(
        val startLatLng: LatLng,
        val endLatLng: LatLng,
        val directionsResponse: DirectionsResponse,
        val paddingTop: Int = 200,
        val paddingLeft: Int = 200,
        val paddingRight: Int = 200,
        val paddingBottom: Int = 200
) {
    companion object {
        fun interpretOptions(o: Any): MapRouteDataModel? {
            try {
                val map = toMap(o)
                val startLatLng = toLatLng(map["startLatLng"]!!)
                val endLatLng = toLatLng(map["endLatLng"]!!)
                val directionsResponseStr = map["directionsResponse"] as String
                val gson = GsonBuilder()
                gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
                gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
                val directionsResponse = gson.create().fromJson(directionsResponseStr, DirectionsResponse::class.java) as DirectionsResponse
                val paddingTop = if (map.containsKey("paddingTop")) map["paddingTop"] as Int else 200
                val paddingLeft = if (map.containsKey("paddingLeft")) map["paddingLeft"] as Int else 200
                val paddingBottom = if (map.containsKey("paddingBottom")) map["paddingBottom"] as Int else 200
                val paddingRight = if (map.containsKey("paddingRight")) map["paddingRight"] as Int else 200
                return MapRouteDataModel(startLatLng, endLatLng, directionsResponse, paddingTop, paddingLeft, paddingRight, paddingBottom)
            } catch (e: Exception) {
                return null
            }
        }

        private fun toDouble(o: Any): Double {
            return (o as Number).toDouble()
        }

        private fun toLatLng(o: Any): LatLng {
            val data = toList(o)
            return LatLng(toDouble(data[0]!!), toDouble(data[1]!!))
        }

        private fun toList(o: Any): List<*> {
            return o as List<*>
        }

        private fun toMap(o: Any): Map<*, *> {
            return o as Map<*, *>
        }

//        fun fromJson(json: String): MapRouteDataModel {
//            val gson = GsonBuilder()
//            gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
//            gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
//            return gson.create().fromJson(json, MapRouteDataModel::class.java) as MapRouteDataModel
//        }
//
//        fun toJson(mapRouteDataModel: MapRouteDataModel): String {
//            val gson = GsonBuilder()
//            gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
//            gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
//            gson.registerTypeAdapterFactory(WalkingOptionsAdapterFactory.create())
//            return gson.create().toJson(this)
//        }
    }


}