package com.mapbox.mapboxgl.plugins.route

import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.api.directions.v5.models.DirectionsRoute
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.geojson.Point
import com.mapbox.mapboxgl.R
import com.mapbox.mapboxgl.language
import com.mapbox.mapboxgl.plugins.interf.IMapPlugin
import com.mapbox.mapboxsdk.camera.CameraPosition
import com.mapbox.mapboxsdk.geometry.LatLng
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.Style
import com.mapbox.services.android.navigation.ui.v5.NavigationLauncherOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MapRouteController(private var initRouteDataModel: MapRouteDataModel? = null) : IMapPlugin, MapRouteSink {

    private var routeOverlay: RouteOverlay? = null

    val ACCESS_TOKEN = "pk.hyn"
    val NAVIGATION_USER = "hyperion"
    val NAVIGATION_UUID = "UUID"
    val DOMAIN = "https://api.hyn.space/"

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
                if (model != null) {
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
            "map_route#startNavigation" -> {
                val model = NavigationDataModel.interpretOptions(call.argument<Map<*, *>>("model")!!)
                if (model != null) {
                    startNavigate(model);
                }
                result.success(null)
                return true;
            }
        }
        return false
    }

    fun startNavigate(navigationDataModel: NavigationDataModel) {
        val route = navigationDataModel.directionsResponse!!.routes()[0]

        val corrdinateList = mutableListOf<Point>(
                Point.fromLngLat(navigationDataModel.startLatLng!!.longitude, navigationDataModel.startLatLng!!.latitude),
                Point.fromLngLat(navigationDataModel.endLatLng!!.longitude, navigationDataModel.endLatLng!!.latitude)
        )

        var directionsRoute = route.toBuilder().routeOptions(
                RouteOptions.builder()
                        .profile(navigationDataModel.profile)
                        .coordinates(corrdinateList)
                        .language(language)
                        .voiceInstructions(true)
                        .bannerInstructions(true)
                        .geometries(DirectionsCriteria.GEOMETRY_POLYLINE6)
                        .overview(DirectionsCriteria.OVERVIEW_FULL)
                        .voiceUnits(DirectionsCriteria.METRIC)
                        .steps(true)
                        .baseUrl(DOMAIN)
                        .user(NAVIGATION_USER)
                        .accessToken(ACCESS_TOKEN)
                        .requestUuid(NAVIGATION_UUID)
                        .build()
        ).build()


        val simulateRoute = true

        val initialPosition = CameraPosition.Builder()
                .target(navigationDataModel.startLatLng)
                .zoom(15.0)
                .build()
        // Create a NavigationLauncherOptions object to package everything together
        val options = NavigationLauncherOptions.builder()
                .directionsRoute(directionsRoute)
                .shouldSimulateRoute(simulateRoute)
                .darkThemeResId(R.style.TitanNavigationTheme)
                .lightThemeResId(R.style.TitanNavigationTheme)
                .initialMapCameraPosition(initialPosition)
                .build()

        NavigationLauncher.startNavigation(mapView!!.context, options)
    }


    override fun onDestroy() {}
}
