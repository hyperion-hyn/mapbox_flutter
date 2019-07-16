import Flutter
import UIKit
import Mapbox

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
                if let layerIds = arguments["layerIds"] as? [String] {
                    let layers = Set(layerIds)
                    if let x = arguments["x"] as? Double, let y = arguments["y"] as? Double {
                        let point = CGPoint(x: x, y: y)
                        features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: layers)
                    } else if let left = arguments["left"] as? Double,
                        let top = arguments["top"] as? Double,
                        let right = arguments["right"] as? Double,
                        let bottom = arguments["bottom"] as? Double {
                        let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                        features = mapView.visibleFeatures(in: rect, styleLayerIdentifiers: layers)
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
            //TODO
            result(FlutterMethodNotImplemented)
        case "map_route#removeRouteOverlay":
            //TODO
            result(FlutterMethodNotImplemented)
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
        channel.invokeMethod("print", arguments: "style ready \(String(describing: currentStyle)) \(String(describing: style.name))")
        if(currentStyle != style.name) {
            channel.invokeMethod("map#onStyleLoaded", arguments: ["map": vId])
        }
        currentStyle = style.name
    }

    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        channel.invokeMethod("print", arguments: "map finish loading")
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
        channel.invokeMethod("print", arguments: "setMyLocationTrackingMode \(myLocationTrackingMode.rawValue)")
        mapView.userTrackingMode = myLocationTrackingMode
    }
    func setEnableLogo(enableLogo: Bool) {
        channel.invokeMethod("print", arguments: "enable logo \(enableLogo)")
        mapView.logoView.isHidden = !enableLogo
    }
    func setEnableAttribution(enableAttribution: Bool) {
        channel.invokeMethod("print", arguments: "enable attribution \(enableAttribution)")
        mapView.attributionButton.isHidden = !enableAttribution
    }
    func setCompassMargins(left: Int, top: Int, right: Int, bottom: Int) {
        channel.invokeMethod("print", arguments: "set compass margins \(left) \(top) \(right) \(bottom)")
        mapView.compassViewMargins = CGPoint(x: right, y: top)
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        if let symbol = annotation as? Symbol,
            let iconImage = symbol.iconImage {
            var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: iconImage)
            if annotationImage == nil {
                var image = UIImage(named: "marker_big")!
                if let resizedImage = image.resize(maxWidthHeight: 50) {
                    image = resizedImage
                }
            
                if let iconOffset = symbol.iconOffset {
                    let bottom: CGFloat = CGFloat(iconOffset[1])
                    let right: CGFloat = CGFloat(iconOffset[0])
                    if let adjustImage = image.adjustImage(offsetX: right, offsetY: bottom) {
                        image = adjustImage
                    }
                } else {
                    if let adjustImage = image.adjustImage(offsetX: 0, offsetY: 0) {
                        image = adjustImage
                    }
                }
                
                image = image.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: image.size.height/2, right: 0))
                
                annotationImage = MGLAnnotationImage(image: image, reuseIdentifier: iconImage)
            }
            return annotationImage
        }
        return nil
    }
    
    // MARK: symbol
    private func addSymbol(data: [String: Any]) -> String {
        if let geometry = data["geometry"] as? [Double] {
            let symbol = Symbol()
            symbol.coordinate = CLLocationCoordinate2D.fromArray(geometry)
            if let iconImage = data["iconImage"] as? String {
                symbol.iconImage = iconImage
            }
            if let iconOffset = data["iconOffset"] as? [Double] {
                symbol.iconOffset = iconOffset
            }
            mapView.addAnnotation(symbol)
            return symbol.id
        }
        return ""
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
}

class Symbol: MGLPointAnnotation {
    var id: String = "symbol_\(hash())"
    var iconImage: String?
    var iconOffset: [Double]?
    var iconAnchor: [Int]?
}
