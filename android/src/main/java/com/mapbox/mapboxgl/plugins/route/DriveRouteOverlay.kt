package com.mapbox.mapboxgl.plugins.route

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import com.mapbox.api.directions.v5.models.DirectionsResponse
import com.mapbox.api.directions.v5.models.DirectionsWaypoint
import com.mapbox.core.constants.Constants.PRECISION_6
import com.mapbox.geojson.Feature
import com.mapbox.geojson.FeatureCollection
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Point
import com.mapbox.mapboxgl.R
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_ARROW_ICON
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_ARROW_LAYER_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_END_ICON
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_ICON_ANCHOR_PROPERTY
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_ICON_PROPERTY
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_LAYER_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_SOURCE_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_LINE_START_ICON
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_START_END_LAYER_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_START_END_SOURCE_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_SUPPLEMENT_LINE_LAYER_NAME
import com.mapbox.mapboxgl.plugins.route.DriveRouteOverlay.Constant.ROUTE_SUPPLEMENT_LINE_SOURCE_NAME
import com.mapbox.mapboxsdk.camera.CameraUpdateFactory
import com.mapbox.mapboxsdk.geometry.LatLng
import com.mapbox.mapboxsdk.geometry.LatLngBounds
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.style.expressions.Expression
import com.mapbox.mapboxsdk.style.expressions.Expression.*
import com.mapbox.mapboxsdk.style.layers.LineLayer
import com.mapbox.mapboxsdk.style.layers.Property
import com.mapbox.mapboxsdk.style.layers.PropertyFactory
import com.mapbox.mapboxsdk.style.layers.SymbolLayer
import com.mapbox.mapboxsdk.style.sources.GeoJsonSource
import java.util.*

class DriveRouteOverlay(
    val context: Context,
    val mapboxMap: MapboxMap,
    val mapView: MapView,
    val routeResponseDto: DirectionsResponse,
    val start: LatLng,
    val end: LatLng
) : RouteOverlay(context, mapboxMap, mapView, routeResponseDto, start, end) {

    private var paddingTop: Int = 200
    private var paddingBottom: Int = 200
    private var paddingLeft: Int = 200
    private var paddingRight: Int = 200


    private val SHADOW_LAYER = "mapbox-location-shadow-layer"

    constructor(
        context: Context,
        mapboxMap: MapboxMap,
        mapView: MapView,
        routeResponseDto: DirectionsResponse,
        start: LatLng,
        end: LatLng,
        paddingTop: Int,
        paddingBottom: Int,
        paddingLeft: Int,
        paddingRight: Int
    ) : this(context, mapboxMap, mapView, routeResponseDto, start, end) {
        this.paddingTop = paddingTop
        this.paddingLeft = paddingLeft
        this.paddingRight = paddingRight
        this.paddingBottom = paddingBottom
    }

    private lateinit var routeLineGenjsonSource: GeoJsonSource
    private lateinit var routeLineFeatureCollection: FeatureCollection

    override fun addToMap() {
        addDataSource(routeResponseDto)
        addLayer()
        zoomToSpan()
    }

    override fun removeFromMap() {
        mapboxMap.style!!.removeLayer(ROUTE_LINE_LAYER_NAME)
        mapboxMap.style!!.removeLayer(ROUTE_START_END_LAYER_NAME)
        mapboxMap.style!!.removeLayer(ROUTE_LINE_ARROW_LAYER_NAME)
        mapboxMap.style!!.removeSource(ROUTE_LINE_SOURCE_NAME)
        mapboxMap.style!!.removeSource(ROUTE_START_END_SOURCE_NAME)

        mapboxMap.style!!.removeLayer(ROUTE_SUPPLEMENT_LINE_LAYER_NAME)
        mapboxMap.style!!.removeSource(ROUTE_SUPPLEMENT_LINE_SOURCE_NAME)
    }

    private fun addDataSource(directionsResponse: DirectionsResponse) {

        val directionsRoute = directionsResponse.routes()[0]
        //删除旧的导航数据
        removeFromMap()

        val directionsRouteFeature =
            Feature.fromGeometry(LineString.fromPolyline(directionsRoute.geometry()!!, PRECISION_6))
        // 获取第一条path
        routeLineFeatureCollection = FeatureCollection.fromFeature(directionsRouteFeature)
        routeLineGenjsonSource = GeoJsonSource(ROUTE_LINE_SOURCE_NAME, routeLineFeatureCollection)
        mapboxMap.style!!.addSource(routeLineGenjsonSource)

        //添加起点和终点的marker的source
        addStartEndSource()
        addSupplementLineSource(directionsResponse)
    }

    private fun addStartEndSource() {

        val startWayPoint = routeResponseDto.waypoints()?.get(0)
        val startEndFeatureList = ArrayList<Feature>()
        startEndFeatureList.add(
            createStartEndFeature(
                LatLng(
                    startWayPoint?.location()?.latitude()!!,
                    startWayPoint.location()?.longitude()!!
                ), ROUTE_LINE_START_ICON, Property.ICON_ANCHOR_BOTTOM
            )
        )
        startEndFeatureList.add(createStartEndFeature(end, ROUTE_LINE_END_ICON, Property.ICON_ANCHOR_BOTTOM))
        val startEndFeatureCollection = FeatureCollection.fromFeatures(startEndFeatureList)
        val startEndGenjsonSource = GeoJsonSource(ROUTE_START_END_SOURCE_NAME, startEndFeatureCollection)
        mapboxMap.style!!.addSource(startEndGenjsonSource)
    }


    private fun createStartEndFeature(point: LatLng, icon: String, anchor: String): Feature {
        val feature = Feature.fromGeometry(Point.fromLngLat(point.longitude, point.latitude))
        feature.addStringProperty(ROUTE_LINE_ICON_PROPERTY, icon)
        feature.addStringProperty(ROUTE_LINE_ICON_ANCHOR_PROPERTY, anchor)
        return feature
    }

    private fun addLayer() {

        //添加补充线Layer

        val routeSupplementLineLayer =
            LineLayer(ROUTE_SUPPLEMENT_LINE_LAYER_NAME, ROUTE_SUPPLEMENT_LINE_SOURCE_NAME)

        routeSupplementLineLayer.setProperties(
            //                PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
            //                PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
            PropertyFactory.lineDasharray(arrayOf(1f, 1f)),
            PropertyFactory.lineWidth(
                interpolate(
                    exponential(1.2f), zoom(),
                    stop(5f, 10f),
                    stop(22.0f, 22f)
                )
            ),
            PropertyFactory.lineColor(Color.parseColor("#FF969696"))
        )

        mapboxMap.style!!.addLayerBelow(routeSupplementLineLayer, SHADOW_LAYER)


        //        添加导航线的layer
        val routeIndoorLineLayer = LineLayer(ROUTE_LINE_LAYER_NAME, ROUTE_LINE_SOURCE_NAME)

        routeIndoorLineLayer.setProperties(
            PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
            PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
            PropertyFactory.lineWidth(
                interpolate(
                    exponential(1.2f), zoom(),
                    stop(5f, 10f),
                    stop(22.0f, 22f)
                )
            ),
            PropertyFactory.lineColor(Color.parseColor("#4596fe"))
        )
        mapboxMap.style!!.addLayerBelow(routeIndoorLineLayer, SHADOW_LAYER)

        if (mapboxMap.style!!.getImage(ROUTE_LINE_ARROW_ICON) == null) {
            mapboxMap.style!!.addImage(
                ROUTE_LINE_ARROW_ICON,
                BitmapFactory.decodeResource(
                    context.resources, R.mipmap.line_arrow_white
                )
            )
        }

        //        添加箭头的layer
        val routeIndoorArrowLayer = SymbolLayer(ROUTE_LINE_ARROW_LAYER_NAME, ROUTE_LINE_SOURCE_NAME)

        routeIndoorArrowLayer.setProperties(
            PropertyFactory.symbolPlacement(Property.SYMBOL_PLACEMENT_LINE),
            PropertyFactory.iconAllowOverlap(true),
            PropertyFactory.symbolSpacing(
                interpolate(
                    exponential(1f), zoom(),
                    stop(5f, 30f),
                    stop(22.0f, 50f)
                )
            ),
            PropertyFactory.iconImage(ROUTE_LINE_ARROW_ICON),
            PropertyFactory.iconSize(
                interpolate(
                    exponential(1.2f), zoom(),
                    stop(7f, 0.4f),
                    stop(22.0f, 0.9f)
                )
            )
        )

        mapboxMap.style!!.addLayerBelow(routeIndoorArrowLayer, SHADOW_LAYER)




        //判断起点和终点的图标是否存在
        if (mapboxMap.style!!.getImage(ROUTE_LINE_START_ICON) == null) {
            mapboxMap.style!!.addImage(
                ROUTE_LINE_START_ICON,
                BitmapFactory.decodeResource(
                    context.resources, R.mipmap.route_start
                )
            )
        }

        if (mapboxMap.style!!.getImage(ROUTE_LINE_END_ICON) == null) {
            mapboxMap.style!!.addImage(
                ROUTE_LINE_END_ICON,
                BitmapFactory.decodeResource(
                    context.resources, R.mipmap.route_end
                )
            )
        }

        //        添加起点和终点的layer

        val routeStartEndLayer = SymbolLayer(ROUTE_START_END_LAYER_NAME, ROUTE_START_END_SOURCE_NAME)
        routeStartEndLayer.setProperties(
            PropertyFactory.iconImage(Expression.get(ROUTE_LINE_ICON_PROPERTY)),
            PropertyFactory.iconAllowOverlap(true),
            PropertyFactory.iconAnchor(Expression.get(ROUTE_LINE_ICON_ANCHOR_PROPERTY)),
            PropertyFactory.iconSize(1f),
            PropertyFactory.symbolSpacing(1f)
        )
        mapboxMap.style!!.addLayerBelow(routeStartEndLayer, SHADOW_LAYER)


    }

    private fun addSupplementLineSource(routeResponseDto: DirectionsResponse) {

        val supplementLineFeatureList = ArrayList<Feature>()


        //处理起点连接线
        val startWayPoint = routeResponseDto.waypoints()?.get(0);

        addInstrcutionSupplementLine(supplementLineFeatureList, startWayPoint!!, true)

        val lastWayPoint = routeResponseDto.waypoints()?.get(routeResponseDto.waypoints()!!.lastIndex)

        addInstrcutionSupplementLine(supplementLineFeatureList, lastWayPoint!!, false)

        val supplementLineFeatureCollection = FeatureCollection.fromFeatures(supplementLineFeatureList)

        val supplementLineGenjsonSource =
            GeoJsonSource(ROUTE_SUPPLEMENT_LINE_SOURCE_NAME, supplementLineFeatureCollection)
        mapboxMap.style!!.addSource(supplementLineGenjsonSource)
    }

    private fun addInstrcutionSupplementLine(
        supplementLineFeatureList: MutableList<Feature>,
        waypoint: DirectionsWaypoint,
        isFirst: Boolean
    ) {
        if (isFirst) {
            val supplementLineCoordinates = ArrayList<Point>()
            supplementLineCoordinates.add(Point.fromLngLat(start.longitude, start.latitude))
            supplementLineCoordinates.add(waypoint.location()!!)
            supplementLineFeatureList.add(createLineFeature(supplementLineCoordinates))
        } else {
            val supplementLineCoordinates = ArrayList<Point>()
            supplementLineCoordinates.add(waypoint.location()!!)
            supplementLineCoordinates.add(Point.fromLngLat(end.longitude, end.latitude))
            supplementLineFeatureList.add(createLineFeature(supplementLineCoordinates))
        }
    }

    private fun createLineFeature(routeCoordinates: List<Point>): Feature {
        val lineString = LineString.fromLngLats(routeCoordinates)
        return Feature.fromGeometry(lineString)
    }


    object Constant {

        //Line
        const val ROUTE_LINE_SOURCE_NAME = "hyn-route-line-source"
        const val ROUTE_LINE_LAYER_NAME: String = "hyn-route-line-layer"


        //Arrow on line
        const val ROUTE_LINE_ARROW_LAYER_NAME: String = "hyn-route-line-arrow-layer"
        const val ROUTE_LINE_ARROW_ICON: String = "hyn-route-line-arrow-icon"


        //Supplement
        const val ROUTE_SUPPLEMENT_LINE_SOURCE_NAME = "hyn-route-supplement-line-source"
        const val ROUTE_SUPPLEMENT_LINE_LAYER_NAME = "hyn-route-supplement-line-layer"


        //Start & End Marker
        const val ROUTE_START_END_LAYER_NAME = "hyn-route-start-end-layer"
        const val ROUTE_START_END_SOURCE_NAME = "hyn-route-start-end-source"
        const val ROUTE_LINE_START_ICON: String = "hyn-route-line-start-icon"
        const val ROUTE_LINE_END_ICON: String = "hyn-route-line-end-icon"
        const val ROUTE_LINE_ICON_PROPERTY: String = "hyn-route-line-icon-property"
        const val ROUTE_LINE_ICON_ANCHOR_PROPERTY: String = "hyn-route-line-icon-anchor-property"
    }

    private fun zoomToSpan() {
        val latLngBoundsBuilder = LatLngBounds.Builder()
        val latlngList = ArrayList<LatLng>()
        for (feature in routeLineFeatureCollection.features()!!) {
            val lineString = feature.geometry() as LineString
            for (point in lineString.coordinates()) {
                latlngList.add(LatLng(point.latitude(), point.longitude()))
            }
        }

        if (latlngList.size >= 2) {
            val latLngBounds = latLngBoundsBuilder.includes(latlngList).build()
            mapboxMap.animateCamera(
                CameraUpdateFactory.newLatLngBounds(
                    latLngBounds,
                    paddingLeft/4,
                    paddingTop,
                    paddingRight/4,
                    paddingBottom
                )
            )
        }

    }

}
