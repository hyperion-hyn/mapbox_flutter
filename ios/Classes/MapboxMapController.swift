import Flutter
import UIKit
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import PodAsset


typealias JSONDictionary = [String: Any]

extension String {
    var nonEmptyString: String? {
        return !isEmpty ? self : nil
    }
}

class MapboxMapController: NSObject, FlutterPlatformView, MGLMapViewDelegate, MapboxMapOptionsSink {
    
    private var mapView: MGLMapView
    private var isMapReady = false
    private var mapReadyResult: FlutterResult?
    
    private var initialTilt: CGFloat?
    private var cameraTargetBounds: MGLCoordinateBounds?
    private var trackCameraPosition = false
    private var myLocationEnabled = false
    
    private var channel: FlutterMethodChannel
    
    private var vId: Int64
    private var currentStyle: String?
    
    func view() -> UIView {
        return mapView
    }
    
    init(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
        mapView = MGLMapView(frame: frame)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vId = viewId
        channel = FlutterMethodChannel(name: "plugins.flutter.io/mapbox_maps_\(viewId)", binaryMessenger: messenger)
        channel.invokeMethod("print", arguments: "mapbox controller init \(viewId)")
        
        super.init()
        
        channel.setMethodCallHandler(onMethodCall)
        
        mapView.delegate = self
        
        if let args = args as? [String: Any] {
            Convert.interpretMapboxMapOptions(options: args["options"], delegate: self)
            if let initialCameraPosition = args["initialCameraPosition"] as? [String: Any],
                let camera = MGLMapCamera.fromDict(initialCameraPosition, mapView: mapView),
                let zoom = initialCameraPosition["zoom"] as? Double {
                mapView.setCenter(camera.centerCoordinate, zoomLevel: zoom, direction: camera.heading, animated: false)
                initialTilt = camera.pitch
            }
        }
        
        // Add a single tap gesture recognizer. This gesture requires the built-in MGLMapView tap gestures (such as those for zoom and annotation selection) to fail.
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(sender:)))
        for recognizer in mapView.gestureRecognizers! where recognizer is UITapGestureRecognizer {
            singleTap.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(singleTap)
        // Add a long press gesture recognizer to the map view
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
    }
    
    @objc @IBAction func handleMapTap(sender: UITapGestureRecognizer) {
        // Get the CGPoint where the user tapped.
        let point = sender.location(in: mapView)
        var arguments: [String: Any] = [:]
        arguments["x"] = point.x
        arguments["y"] = point.y
        
        let touchCoordinate = mapView.convert(point, toCoordinateFrom: sender.view!)
        arguments["lng"] = touchCoordinate.longitude
        arguments["lat"] = touchCoordinate.latitude
        NSLog("mapClick \(arguments)")
        channel.invokeMethod("map#onMapClick", arguments: arguments)
    }
    
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: mapView)
        var arguments: [String: Any] = [:]
        arguments["x"] = point.x
        arguments["y"] = point.y
        
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        arguments["lng"] = coordinate.longitude
        arguments["lat"] = coordinate.latitude
        channel.invokeMethod("map#onMapLongPress", arguments: arguments)
    }
    
    func onMethodCall(methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(methodCall.method) {
        case "map#waitForMap":
            if isMapReady {
                result(true)
            } else {
                mapReadyResult = result
            }
        case "map#update":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            Convert.interpretMapboxMapOptions(options: arguments["options"], delegate: self)
            if let camera = getCamera() {
                result(camera.toDict(mapView: mapView))
            } else {
                result(nil)
            }
        case "location#enableLocation":
            setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode.follow)
            result(nil)
        case "location#disableLocation":
            setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode.none)
            result(nil)
        case "location#lastKnownLocation":
            if let coordinate = mapView.userLocation?.location?.coordinate {
                result([coordinate.latitude, coordinate.longitude])
            } else {
                result(nil)
            }
        case "camera#move":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, animated: false)
            }
        case "camera#animate":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, animated: true)
            }
        case "map#queryRenderedFeatures":
            channel.invokeMethod("print", arguments: "map#queryRenderedFeatures \(String(describing: methodCall.arguments))")
            var reply: [String: [String]] = [:]
            
            var features: [MGLFeature] = []
            if let arguments = methodCall.arguments as? [String: Any] {
                var predicate:NSPredicate?
                //TODO support expression
                if let filter = arguments["filter"] as? String {
                    predicate = NSPredicate(format: filter)
                }
                if let layerIds = arguments["layerIds"] as? [String] {
                    let layers = Set(layerIds)
                    if let x = arguments["x"] as? Double, let y = arguments["y"] as? Double {
                        let point = CGPoint(x: x, y: y)
                        features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: layers, predicate: predicate)
                    } else if let left = arguments["left"] as? Double,
                        let top = arguments["top"] as? Double,
                        let right = arguments["right"] as? Double,
                        let bottom = arguments["bottom"] as? Double {
                        let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                        features = mapView.visibleFeatures(in: rect, styleLayerIdentifiers: layers, predicate: predicate)
                    }
                }
            }
            var featuresJson: [String] = []
            for feature in features {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: feature.geoJSONDictionary(), options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) {
                        featuresJson.append(jsonString)
                    }
                } catch {
                    print("error \(error)")
                }
            }
            reply["features"] = featuresJson
            result(reply)
        case "symbol#add":
            channel.invokeMethod("print", arguments: "symbol#add \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let options = arguments["options"] as? [String: Any] else { return }
            let symbolId = addSymbol(data: options)
            result(symbolId)
        case "symbol#addList":
            channel.invokeMethod("print", arguments: "symbol#addList \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [[String: Any]] else { return }
            //            guard let options = arguments["options"] as? [String: Any] else { return }
            let symbolIds = addSymbols(datas: arguments)
            result(symbolIds)
        case "symbol#remove":
            channel.invokeMethod("print", arguments: "symbol#remove \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolId = arguments["symbol"] as? String else { return }
            removeSymbol(symbolId: symbolId)
            result(nil)
            /*plugins*/
        case "heaven_map#addData":
            channel.invokeMethod("print", arguments: "heaven_map#addData \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let model = arguments["model"] as? [String: Any] else { return }
            addHeavenMapSourceAndLayer(data: model)
            result(nil)
        case "heaven_map#removeData":
            channel.invokeMethod("print", arguments: "heaven_map#removeData \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let id = arguments["id"] as? String {
                removeHeavenMap(id: id)
            }
            result(nil)
        case "map_route#addRouteOverlay":
            channel.invokeMethod("print", arguments: "heaven_map#addRouteOverlay \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let model = arguments["model"] as? [String: Any] else { return }
            addHeavenMapRouteOverlay(data: model,channel: channel)
            result(nil)
        case "map_route#removeRouteOverlay":
            channel.invokeMethod("print", arguments: "heaven_map#removeRouteOverlay \(String(describing: methodCall.arguments))")
            removeHeavenMapRouteOverlay()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func updateMyLocationEnabled() {
        //TODO
    }
    
    private func getCamera() -> MGLMapCamera? {
        return trackCameraPosition ? mapView.camera : nil
    }
    
    
    /*
     *  MGLMapViewDelegate
     */
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        if(currentStyle != style.name) {
            channel.invokeMethod("map#onStyleLoaded", arguments: ["map": vId])
        }
        currentStyle = style.name
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        isMapReady = true
        updateMyLocationEnabled()
        
        if let initialTilt = initialTilt {
            let camera = mapView.camera
            camera.pitch = initialTilt
            mapView.setCamera(camera, animated: false)
        }
        
        mapReadyResult?(currentStyle != nil)
        mapReadyResult = nil
    }
    
    func mapView(_ mapView: MGLMapView, shouldChangeFrom oldCamera: MGLMapCamera, to newCamera: MGLMapCamera) -> Bool {
        guard let bbox = cameraTargetBounds else { return true }
        // Get the current camera to restore it after.
        let currentCamera = mapView.camera
        
        // From the new camera obtain the center to test if it’s inside the boundaries.
        let newCameraCenter = newCamera.centerCoordinate
        
        // Set the map’s visible bounds to newCamera.
        mapView.camera = newCamera
        let newVisibleCoordinates = mapView.visibleCoordinateBounds
        
        // Revert the camera.
        mapView.camera = currentCamera
        
        // Test if the newCameraCenter and newVisibleCoordinates are inside bbox.
        let inside = MGLCoordinateInCoordinateBounds(newCameraCenter, bbox)
        let intersects = MGLCoordinateInCoordinateBounds(newVisibleCoordinates.ne, bbox) && MGLCoordinateInCoordinateBounds(newVisibleCoordinates.sw, bbox)
        
        return inside && intersects
    }
    
    /*
     *  MapboxMapOptionsSink
     */
    func setCameraTargetBounds(bounds: MGLCoordinateBounds?) {
        cameraTargetBounds = bounds
    }
    func setCompassEnabled(compassEnabled: Bool) {
        mapView.compassView.isHidden = compassEnabled
        mapView.compassView.isHidden = !compassEnabled
    }
    func setMinMaxZoomPreference(min: Double, max: Double) {
        mapView.minimumZoomLevel = min
        mapView.maximumZoomLevel = max
    }
    func setStyleString(styleString: String) {
        // Check if json, url or plain string:
        if styleString.isEmpty {
            NSLog("setStyleString - string empty")
        } else if (styleString.hasPrefix("{") || styleString.hasPrefix("[")) {
            // Currently the iOS Mapbox SDK does not have a builder for json.
            NSLog("setStyleString - JSON style currently not supported")
        } else {
            currentStyle = nil
            mapView.styleURL = URL(string: styleString)
        }
    }
    func setRotateGesturesEnabled(rotateGesturesEnabled: Bool) {
        mapView.allowsRotating = rotateGesturesEnabled
    }
    func setScrollGesturesEnabled(scrollGesturesEnabled: Bool) {
        mapView.allowsScrolling = scrollGesturesEnabled
    }
    func setTiltGesturesEnabled(tiltGesturesEnabled: Bool) {
        mapView.allowsTilting = tiltGesturesEnabled
    }
    func setTrackCameraPosition(trackCameraPosition: Bool) {
        self.trackCameraPosition = trackCameraPosition
    }
    func setZoomGesturesEnabled(zoomGesturesEnabled: Bool) {
        mapView.allowsZooming = zoomGesturesEnabled
    }
    func setMyLocationEnabled(myLocationEnabled: Bool) {
        channel.invokeMethod("print", arguments: "location enable \(myLocationEnabled)")
        if (self.myLocationEnabled == myLocationEnabled) {
            return
        }
        self.myLocationEnabled = myLocationEnabled
        updateMyLocationEnabled()
    }
    func setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode) {
        mapView.userTrackingMode = myLocationTrackingMode
    }
    func setEnableLogo(enableLogo: Bool) {
        mapView.logoView.isHidden = !enableLogo
    }
    func setEnableAttribution(enableAttribution: Bool) {
        mapView.attributionButton.isHidden = !enableAttribution
    }
    func setCompassMargins(left: Int, top: Int, right: Int, bottom: Int) {
        mapView.compassViewMargins = CGPoint(x: right, y: top)
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        if let symbol = annotation as? Symbol,
            let iconImage = symbol.iconImage {
            var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: iconImage)
            if annotationImage == nil {
                annotationImage = MGLAnnotationImage(image: symbol.makeImage(), reuseIdentifier: iconImage)
            }
            return annotationImage
        }
        return nil
    }
    
    // MARK: symbol
    private func addSymbol(data: [String: Any]) -> String {
        if let symbol = parseToSymbol(data: data) {
            mapView.addAnnotation(symbol)
            return symbol.id
        }
        return ""
    }
    
    
    // MARK: symbol
    private func addSymbols(datas: [[String: Any]]) -> [String] {
        var symbolIds = [String]();
        var symbols = [Symbol]();
        for data in datas{
            if let symbol = parseToSymbol(data: data) {
                symbols.append(symbol);
            }
        }
        mapView.addAnnotations(symbols);
        
        for symbol in symbols{
            symbolIds.append(symbol.id);
        }
        return symbolIds
    }
    
    private func removeSymbol(symbolId: String) {
        if mapView.annotations?.count != nil, let existingAnnotations = mapView.annotations {
            for annotation in existingAnnotations {
                if let symbol = annotation as? Symbol {
                    if symbol.id == symbolId {
                        mapView.removeAnnotation(symbol)
                    }
                }
            }
        }
    }
    
    private func parseToSymbol(data: [String: Any]) -> Symbol? {
        if let geometry = data["geometry"] as? [Double] {
            let symbol = Symbol()
            symbol.coordinate = CLLocationCoordinate2D.fromArray(geometry)
            if let iconImage = data["iconImage"] as? String {
                symbol.iconImage = iconImage
            }
            if let iconOffset = data["iconOffset"] as? [Double] {
                symbol.iconOffset = iconOffset
            }
            if let iconSize = data["iconSize"] as? Double {
                symbol.iconSize = iconSize
            }
            if let iconAnchor = data["iconAnchor"] as? String {
                symbol.iconAnchor = iconAnchor
            }
            return symbol
        }
        return nil
    }
    
    // MARK: heaven map
    private func addHeavenMapSourceAndLayer(data: [String: Any]) {
        guard let id = data["id"] as? String,
            let sourceUrl = data["sourceUrl"] as? String,
            let color = data["color"] as? Int
            else { return }
        
        let sourcId = getHeavenMapSourceId(sourceId: id)
        guard mapView.style?.source(withIdentifier: sourcId) == nil else { return }
        let source = MGLVectorTileSource(identifier: sourcId, tileURLTemplates: [sourceUrl])
        mapView.style?.addSource(source)
        
        let layerId = getHeavenMapLayerId(id: id)
        guard mapView.style?.layer(withIdentifier: layerId) == nil else { return }
        let circlesLayer = MGLCircleStyleLayer(identifier: layerId, source: source)
        circlesLayer.sourceLayerIdentifier = "heaven"
        circlesLayer.circleRadius = NSExpression(forConstantValue: NSNumber(value: 8))
        circlesLayer.circleOpacity = NSExpression(forConstantValue: 0.8)
        circlesLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        circlesLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
        circlesLayer.circleColor = NSExpression(forConstantValue: UIColor.init(argb: color))
        //circlesLayer.predicate = NSPredicate(format: "cluster == YES")
        
        //let shapeID = "com.mapbox.annotations.shape."
        let pointLayerID = "com.mapbox.annotations.points"
        if let annotationPointLayer = mapView.style?.layer(withIdentifier: pointLayerID) {
            mapView.style?.insertLayer(circlesLayer, below: annotationPointLayer)
        } else {
            mapView.style?.addLayer(circlesLayer)
        }
    }
    
    
    private func removeHeavenMap(id: String) {
        let layerId = getHeavenMapLayerId(id: id)
        if let layer = mapView.style?.layer(withIdentifier: layerId) {
            mapView.style?.removeLayer(layer)
        }
        let sourcId = getHeavenMapSourceId(sourceId: id)
        if let source = mapView.style?.source(withIdentifier: sourcId) {
            mapView.style?.removeSource(source)
        }
    }
    
    private func getHeavenMapLayerId(id: String) -> String {
        return "layer-heaven-\(id)"
    }
    
    private func getHeavenMapSourceId(sourceId: String) -> String {
        return "source-heaven-\(sourceId)"
    }
    
    // MARK: router
    //TODO
    
    
    private func addHeavenMapRouteOverlay(data: [String: Any],channel: FlutterMethodChannel) {
        
        MapRouteDataModel.addToMap(data: data, mapview: mapView,channel:channel);
    }
    
    private func removeHeavenMapRouteOverlay(){
        
        MapRouteDataModel.removeFromMap( mapview: mapView,channel:channel);
        
    }
    
    
}

class Symbol: MGLPointAnnotation {
    var id: String = "symbol_\(hash())"
    var iconImage: String?
    var iconSize: Double?
    var iconOffset: [Double]?
    var iconAnchor: String?
    
    func makeImage() -> UIImage {
        let bundle = PodAsset.bundle(forPod: "MapboxGl")
        var image:UIImage;
        if(self.iconImage != nil){
            image = UIImage(named: self.iconImage!, in: bundle, compatibleWith: nil)!
        } else {
            image = UIImage(named: "marker_big", in: bundle, compatibleWith: nil)!
        }
        
        if let resizedImage = image.resize(maxWidthHeight: self.iconSize ?? 50.0) {
            image = resizedImage
        }
        
        let offsetX: CGFloat = CGFloat(iconOffset?[0] ?? 0)
        let offsetY: CGFloat = CGFloat(iconOffset?[1] ?? 0)
        let anchor: String = self.iconAnchor ?? "center"
        
        NSLog("anchor \(anchor) offsetX \(offsetX) offsetY \(offsetY)")
        
        if let offsetImage = image.offsetImage(anchor: anchor, offsetX: offsetX, offsetY: offsetY) {
            image = offsetImage
        }
    
//        image = image.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: image.size.height/2, right: 0))
        
        return image
    }
}


class MapRouteDataModel{
    // MARK: heaven map
    //Line
    static let ROUTE_LINE_SOURCE_NAME = "hyn-route-line-source"
    static let ROUTE_LINE_LAYER_NAME: String = "hyn-route-line-layer"
    //Arrow on line
    static let ROUTE_LINE_ARROW_LAYER_NAME: String = "hyn-route-line-arrow-layer"
    static let ROUTE_LINE_ARROW_ICON: String = "hyn-route-line-arrow-icon"
    //Supplement
    static let ROUTE_SUPPLEMENT_LINE_SOURCE_NAME = "hyn-route-supplement-line-source"
    static let ROUTE_SUPPLEMENT_LINE_LAYER_NAME = "hyn-route-supplement-line-layer"
    //Start & End Marker
    static let ROUTE_START_END_LAYER_NAME = "hyn-route-start-end-layer"
    static let ROUTE_START_END_SOURCE_NAME = "hyn-route-start-end-source"
    static let ROUTE_LINE_START_ICON: String = "hyn-route-line-start-icon"
    static let ROUTE_LINE_END_ICON: String = "hyn-route-line-end-icon"
    static let ROUTE_LINE_ICON_PROPERTY: String = "hyn-route-line-icon-property"
    static let ROUTE_LINE_ICON_ANCHOR_PROPERTY: String = "hyn-route-line-icon-anchor-property"
    
    
    public static let MBRouteLineWidthByZoomLevel: [Int: NSExpression] = [
        10: NSExpression(forConstantValue: 8),
        13: NSExpression(forConstantValue: 9),
        16: NSExpression(forConstantValue: 11),
        19: NSExpression(forConstantValue: 22),
        22: NSExpression(forConstantValue: 28)
    ]
    
    
    public static let MBRouteArrowSymbolSpaceByZoomLevel: [Int: NSExpression] = [
        5: NSExpression(forConstantValue: 1),
        22: NSExpression(forConstantValue: 1)
    ]
    
    
    public static let MBRouteArrowIconSizeByZoomLevel: [Int: NSExpression] = [
        7: NSExpression(forConstantValue: 0.1),
        22: NSExpression(forConstantValue: 0.18)
    ]
    
    
    public static func addToMap(data:[String: Any],mapview:MGLMapView,channel: FlutterMethodChannel) {
        guard let startLatLngDouble = data["startLatLng"] as? [Double] else {
            return
        }
        let startPoint = CLLocationCoordinate2D.fromArray(startLatLngDouble)
        
        guard let endLatLngDouble = data["endLatLng"] as? [Double] else{
            return
        }
        let endPoint = CLLocationCoordinate2D.fromArray(endLatLngDouble)
        
        let startWaypoint = Waypoint(coordinate: startPoint)
        let endWaypoint = Waypoint(coordinate: endPoint)
        
        let routeOptions = NavigationRouteOptions(waypoints: [startWaypoint, endWaypoint])
        
        
        
        let responseString = data["directionsResponse"] as! String;
        
        let responseData = responseString.data(using: .utf8)
        
        var response: JSONDictionary = [:]
        do{
            response = try JSONSerialization.jsonObject(with: responseData!, options: []) as! JSONDictionary
        }catch{
            channel.invokeMethod("print", arguments: "convert json to map error")
        }
        
        var namedWaypoints: [Waypoint]?
        if let jsonWaypoints = (response["waypoints"] as? [JSONDictionary]) {
            namedWaypoints = jsonWaypoints.map { (api) -> Waypoint in
                let location = api["location"] as! [Double]
                let coordinate = CLLocationCoordinate2D(latitude: location[1], longitude: location[0])
                let possibleAPIName = api["name"] as? String
                let apiName = possibleAPIName?.nonEmptyString;
                let waypoint = Waypoint(coordinate: coordinate)
                waypoint.name = waypoint.name ?? apiName
                return waypoint
            }
        }
        
        guard let waypoints = namedWaypoints else{
            return
        }
        waypoints.first?.separatesLegs = true
        waypoints.last?.separatesLegs = true
        let legSeparators = waypoints.filter { $0.separatesLegs }
        
        let routes = (response["routes"] as? [JSONDictionary])?.map {
            Route(json: $0, waypoints: legSeparators, options: routeOptions)
        }
        //        return (waypoints, routes)
        
        
        
        //添加连接线
        
        var supplementLineFeatures: [MGLPolylineFeature] = []
        
        
        let startSupplementCoordinates = [startPoint,waypoints[0].coordinate]
        
        let startSupplementPolyline = MGLPolylineFeature(coordinates: startSupplementCoordinates, count: UInt(startSupplementCoordinates.count))
        
        supplementLineFeatures.append(startSupplementPolyline)
        
        
        let endSupplementCoordinates = [waypoints.last!.coordinate,endPoint]
        
        let endSupplementPolyline = MGLPolylineFeature(coordinates: endSupplementCoordinates, count: UInt(endSupplementCoordinates.count))
        
        supplementLineFeatures.append(endSupplementPolyline)
        
        let supplementCollectionFeature =  MGLShapeCollectionFeature(shapes: supplementLineFeatures)
        
        let supplementLineSource = MGLShapeSource(identifier: ROUTE_SUPPLEMENT_LINE_SOURCE_NAME, shape: supplementCollectionFeature, options: [.lineDistanceMetrics: false])
        
        
        mapview.style?.addSource(supplementLineSource)
        
        
        let supplementLine = MGLLineStyleLayer(identifier: ROUTE_SUPPLEMENT_LINE_LAYER_NAME, source: supplementLineSource)
        supplementLine.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteLineWidthByZoomLevel)
        supplementLine.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.5882352941, green: 0.5882352941, blue: 0.5882352941, alpha: 1))
        supplementLine.lineDashPattern = NSExpression(forConstantValue: [0.7, 0.7])
        
        
        mapview.style?.addLayer(supplementLine)
        
        
        //添加导航线
        
        
        var altRoutes: [MGLPolylineFeature] = []
        
        
        let route = routes![0]
        
        let polyline = MGLPolylineFeature(coordinates: route.coordinates!, count: UInt(route.coordinates!.count))
        altRoutes.append(polyline)
        
        let lineShapeCollectionFeature =  MGLShapeCollectionFeature(shapes: altRoutes)
        
        let lineSource = MGLShapeSource(identifier: ROUTE_LINE_SOURCE_NAME, shape: lineShapeCollectionFeature, options: [.lineDistanceMetrics: false])
        
        
        mapview.style?.addSource(lineSource)
        
        
        let line = MGLLineStyleLayer(identifier: ROUTE_LINE_LAYER_NAME, source: lineSource)
        line.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteLineWidthByZoomLevel)
        line.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.2705882353, green: 0.5882352941, blue: 0.9960784314, alpha: 1))
        line.lineJoin = NSExpression(forConstantValue: "round")
        line.lineCap = NSExpression(forConstantValue: "round")
        
        mapview.style?.addLayer(line)
        channel.invokeMethod("print", arguments: "addLayer")
        let currentCamera = mapview.camera
        currentCamera.pitch = 0
        currentCamera.heading = 0
        
        
        let newCamera = mapview.camera(currentCamera, fitting: polyline, edgePadding: UIEdgeInsets.init(top: 100 , left: 50, bottom: 100, right: 50))
        
        mapview.setCamera(newCamera, withDuration: 1, animationTimingFunction: nil)
        
        
        
        
        //add marker
        
        
        var features = [MGLPointFeature]()
        
        //    for waypoint in waypoints{
        //        let feature = MGLPointFeature()
        //        feature.coordinate = waypoint.coordinate
        //        features.append(feature)
        //    }
        
        let startFeature = MGLPointFeature();
        startFeature.coordinate = startPoint;
        startFeature.attributes = [
            ROUTE_LINE_ICON_PROPERTY:ROUTE_LINE_START_ICON
        ]
        
        features.append(startFeature)
        
        
        let endFeature = MGLPointFeature();
        endFeature.coordinate = endPoint;
        endFeature.attributes = [
            ROUTE_LINE_ICON_PROPERTY:ROUTE_LINE_END_ICON
        ]
        
        features.append(endFeature)
        
        
        
        let markerSourceFeature =  MGLShapeCollectionFeature(shapes: features)
        
        let markerSource = MGLShapeSource(identifier: ROUTE_START_END_SOURCE_NAME, shape: markerSourceFeature)
        mapview.style?.addSource(markerSource)
        
        
        let startAnnotationImage = mapview.dequeueReusableAnnotationImage(withIdentifier: ROUTE_LINE_START_ICON);
        if(startAnnotationImage == nil){
            let bundle = PodAsset.bundle(forPod: "MapboxGl")
            if let image = UIImage(named: "route_start", in: bundle, compatibleWith: nil){
                mapview.style?.setImage(image, forName: ROUTE_LINE_START_ICON)
            }
        }
        
        
        let endAnnotationImage = mapview.dequeueReusableAnnotationImage(withIdentifier: ROUTE_LINE_END_ICON);
        if(endAnnotationImage == nil){
            let bundle = PodAsset.bundle(forPod: "MapboxGl")
            if let image = UIImage(named: "route_end", in: bundle, compatibleWith: nil){
                mapview.style?.setImage(image, forName: ROUTE_LINE_END_ICON)
            }
        }
        
        
        let symbolLayer = MGLSymbolStyleLayer(identifier: ROUTE_START_END_LAYER_NAME, source: markerSource)
        
        //    symbolLayer.iconImageName = NSExpression(forConstantValue: ROUTE_LINE_START_ICON)
        symbolLayer.iconImageName = NSExpression(forKeyPath: ROUTE_LINE_ICON_PROPERTY)
        symbolLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
        symbolLayer.iconScale =  NSExpression(forConstantValue: 0.4)
        symbolLayer.iconAnchor = NSExpression(forConstantValue: "bottom")
        //    symbolLayer.symbolSpacing = NSExpression(forConstantValue: 1)
        
        
        mapview.style?.addLayer(symbolLayer)
        
        
        //    添加箭头
        
        let arrowAnnotationImage = mapview.dequeueReusableAnnotationImage(withIdentifier: ROUTE_LINE_ARROW_ICON);
        if(arrowAnnotationImage == nil){
            let bundle = PodAsset.bundle(forPod: "MapboxGl")
            if let image = UIImage(named: "line_arrow_white", in: bundle, compatibleWith: nil){
                mapview.style?.setImage(image, forName: ROUTE_LINE_ARROW_ICON)
            }
        }
        
        let routeArrowLayer  = MGLSymbolStyleLayer(identifier: ROUTE_LINE_ARROW_LAYER_NAME, source: lineSource)
        
        routeArrowLayer.symbolPlacement = NSExpression(forConstantValue: "line")
        routeArrowLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
        routeArrowLayer.iconImageName = NSExpression(forConstantValue: ROUTE_LINE_ARROW_ICON)
        //    routeArrowLayer.symbolSpacing = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteArrowSymbolSpaceByZoomLevel)
        
        routeArrowLayer.symbolSpacing = NSExpression(forConstantValue: 1)
        routeArrowLayer.iconScale = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteArrowIconSizeByZoomLevel)
        
        mapview.style?.addLayer(routeArrowLayer)
        
        
        
        
        
    }
    
    
    public static func removeFromMap(mapview:MGLMapView,channel: FlutterMethodChannel) {
        
        //        移除导航线
        if let lineLayer =  mapview.style?.layer(withIdentifier: ROUTE_LINE_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(lineLayer)
        }
        
        if let lineSource = mapview.style?.source(withIdentifier: ROUTE_LINE_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(lineSource)
        }
        
        //        移除导航线箭头
        
        
        if let lineArrowLayer =  mapview.style?.layer(withIdentifier: ROUTE_LINE_ARROW_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(lineArrowLayer)
        }
        
        //移除起点和终点marker
        
        if let startEndMarkerLayer =  mapview.style?.layer(withIdentifier: ROUTE_START_END_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(startEndMarkerLayer)
        }
        
        if let startEndMarkerSource = mapview.style?.source(withIdentifier: ROUTE_START_END_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(startEndMarkerSource)
        }
        
        
        //移除辅助线
        
        
        if let supplementLineLayer =  mapview.style?.layer(withIdentifier: ROUTE_SUPPLEMENT_LINE_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(supplementLineLayer)
        }
        
        if let supplementLineSource = mapview.style?.source(withIdentifier: ROUTE_SUPPLEMENT_LINE_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(supplementLineSource)
        }
        
        
    }
    
    
    
}
