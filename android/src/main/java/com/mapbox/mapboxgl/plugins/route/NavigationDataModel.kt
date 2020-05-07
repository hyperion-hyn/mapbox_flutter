package com.mapbox.mapboxgl.plugins.route

import com.google.gson.GsonBuilder
import com.mapbox.api.directions.v5.DirectionsAdapterFactory
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.geojson.Point
import com.mapbox.geojson.PointAsCoordinatesTypeAdapter
import com.mapbox.mapboxsdk.geometry.LatLng

data class NavigationDataModel(
        val startLatLng: LatLng,
        val endLatLng: LatLng,
        val directionsResponse: DirectionsResponse,
        val profile: String = "driving",
        val language: String,
        val startNavigationTips: String

) {
    companion object {
        fun interpretOptions(o: Any): NavigationDataModel? {
            try {
                val map = toMap(o)
                val startLatLng = toLatLng(map["startLatLng"]!!)
                val endLatLng = toLatLng(map["endLatLng"]!!)
                val directionsResponseStr = map["directionsResponse"] as String
                val gson = GsonBuilder()
                gson.registerTypeAdapterFactory(DirectionsAdapterFactory.create())
                gson.registerTypeAdapter(Point::class.java, PointAsCoordinatesTypeAdapter())
                val directionsResponse = gson.create().fromJson(directionsResponseStr, DirectionsResponse::class.java) as DirectionsResponse
                val profile = if (map.containsKey("profile")) map["profile"] as String else "driving"
                val language = if (map.containsKey("language")) map["language"] as String else "zh-Hans"
                val startTips = if (map.containsKey("startNavigationTips")) map["startNavigationTips"] as String else "开始导航"
                return NavigationDataModel(startLatLng, endLatLng, directionsResponse, profile, language, startTips)
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
        
    }


}