import Flutter
import UIKit
import Mapbox
import MapboxAnnotationExtension
import MapboxDirections
import MapboxCoreNavigation
import PodAsset
import MapboxNavigation


typealias JSONDictionary = [String: Any]

extension String {
    var nonEmptyString: String? {
        return !isEmpty ? self : nil
    }
}

class MapboxMapController: NSObject, FlutterPlatformView, MGLMapViewDelegate, MapboxMapOptionsSink, MGLAnnotationControllerDelegate {

    private var registrar: FlutterPluginRegistrar
    private var channel: FlutterMethodChannel?
    
    private var mapView: MGLMapView
    private var isMapReady = false
    private var mapReadyResult: FlutterResult?
    
    private var initialTilt: CGFloat?
    private var cameraTargetBounds: MGLCoordinateBounds?
    private var trackCameraPosition = false
    private var myLocationEnabled = false

    private var symbolAnnotationController: MGLSymbolAnnotationController?
    private var circleAnnotationController: MGLCircleAnnotationController?
    private var lineAnnotationController: MGLLineAnnotationController?


    private var vId: Int64
    private var currentStyle: String?

    private var symbolIndex = 0;

    private var languageCode :String?;

    private var languageEnable :Bool?;


    func view() -> UIView {
        return mapView
    }
    
    init(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, registrar: FlutterPluginRegistrar) {
        mapView = MGLMapView(frame: frame)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.registrar = registrar
        vId = viewId
        super.init()
        
        channel = FlutterMethodChannel(name: "plugins.flutter.io/mapbox_maps_\(viewId)", binaryMessenger: registrar.messenger())
        channel!.setMethodCallHandler(onMethodCall)
        
        mapView.delegate = self
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(sender:)))
        for recognizer in mapView.gestureRecognizers! where recognizer is UITapGestureRecognizer {
            singleTap.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(singleTap)

        // Add a long press gesture recognizer to the map view

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        mapView.addGestureRecognizer(longPress)

        if let args = args as? [String: Any] {
            Convert.interpretMapboxMapOptions(options: args["options"], delegate: self)
            if let initialCameraPosition = args["initialCameraPosition"] as? [String: Any],
                let camera = MGLMapCamera.fromDict(initialCameraPosition, mapView: mapView),
                let zoom = initialCameraPosition["zoom"] as? Double {
                mapView.setCenter(camera.centerCoordinate, zoomLevel: zoom, direction: camera.heading, animated: false)
                initialTilt = camera.pitch
            }
        }
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
        case "map#invalidateAmbientCache":
            MGLOfflineStorage.shared.invalidateAmbientCache{
                (error) in
                if let error = error {
                    result(error)
                } else{
                    result(nil)
                }
            }
        case "map#updateMyLocationTrackingMode":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let myLocationTrackingMode = arguments["mode"] as? UInt, let trackingMode = MGLUserTrackingMode(rawValue: myLocationTrackingMode) {
                setMyLocationTrackingMode(myLocationTrackingMode: trackingMode)
            }
            result(nil)
        case "map#matchMapLanguageWithDeviceDefault":
            if let style = mapView.style {
                style.localizeLabels(into: nil)
            }
            result(nil)
        case "map#updateContentInsets":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }

            if let bounds = arguments["bounds"] as? [String: Any],
                let top = bounds["top"] as? CGFloat,
                let left = bounds["left"]  as? CGFloat,
                let bottom = bounds["bottom"] as? CGFloat,
                let right = bounds["right"] as? CGFloat,
                let animated = arguments["animated"] as? Bool {
                mapView.setContentInset(UIEdgeInsets(top: top, left: left, bottom: bottom, right: right), animated: animated) {
                    result(nil)
                }
            } else {
                result(nil)
            }
        case "map#setMapLanguage":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let localIdentifier = arguments["language"] as? String, let style = mapView.style {
                let locale = Locale(identifier: localIdentifier)
                style.localizeLabels(into: locale)
            }
            result(nil)
        case "map#setTelemetryEnabled":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            let telemetryEnabled = arguments["enabled"] as? Bool
            UserDefaults.standard.set(telemetryEnabled, forKey: "MGLMapboxMetricsEnabled")
            result(nil)
        case "map#getTelemetryEnabled":
            let telemetryEnabled = UserDefaults.standard.bool(forKey: "MGLMapboxMetricsEnabled")
            result(telemetryEnabled)
        case "map#getVisibleRegion":
            var reply = [String: NSObject]()
            let visibleRegion = mapView.visibleCoordinateBounds
            reply["sw"] = [visibleRegion.sw.latitude, visibleRegion.sw.longitude] as NSObject
            reply["ne"] = [visibleRegion.ne.latitude, visibleRegion.ne.longitude] as NSObject
            result(reply)

        case "map#getCameraPosition":
            let camera = mapView.camera;
            result(["position":camera.toDict(mapView: mapView)])

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
            result(nil)
        case "camera#animate":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, animated: true)
            }
            result(nil)

         case "camera#animateWithTime":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            guard let durationMs = arguments["durationMs"] as? String else { return }
            guard let duration = TimeInterval(durationMs) else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, withDuration: duration / 1000.0, animationTimingFunction: nil)
            }

        case "map#queryRenderedFeatures":
            channel!.invokeMethod("print", arguments: "map#queryRenderedFeatures \(String(describing: methodCall.arguments))")
            var reply: [String: [String]] = [:]

            var features: [MGLFeature] = []
            if let arguments = methodCall.arguments as? [String: Any] {
                var predicate:NSPredicate?
                //TODO support expression
                if let filter = arguments["filter"] as? String {
                    print("filter \(filter)")
                    if(!filter.isEmpty){
                        predicate = NSPredicate(format:filter)
                    }
                }
                var layers:Set<String>?
                if let layerIds = arguments["layerIds"] as? [String] {
                    print("layerIds \(layerIds)")
                    if(!layerIds.isEmpty){
                        layers = Set(layerIds)
                        print("layerIds set \(layerIds)")
                    }
                }
                if let x = arguments["x"] as? Double, let y = arguments["y"] as? Double {
                    let point = CGPoint(x: x, y: y)
                    features = mapView.visibleFeatures(at: point,styleLayerIdentifiers: layers, predicate: predicate)
                } else if let left = arguments["left"] as? Double,
                    let top = arguments["top"] as? Double,
                    let right = arguments["right"] as? Double,
                    let bottom = arguments["bottom"] as? Double {
                    let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                    features = mapView.visibleFeatures(in: rect, styleLayerIdentifiers: layers,predicate: predicate)
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
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }

            // Parse geometry
            if let options = arguments["options"] as? [String: Any],
                let geometry = options["geometry"] as? [Double] {
                // Convert geometry to coordinate and create symbol.
                let coordinate = CLLocationCoordinate2DMake(geometry[0], geometry[1])
                let symbol = MGLSymbolStyleAnnotation(coordinate: coordinate)
                Convert.interpretSymbolOptions(options: arguments["options"], delegate: symbol)
                // Load icon image from asset if an icon name is supplied.
                if let iconImage = options["iconImage"] as? String {
                    addIconImageToMap(iconImageName: iconImage)
                }
                symbolAnnotationController.addStyleAnnotation(symbol)
                result(symbol.identifier)
            } else {
                result(nil)
            }
         case "symbol#addList":
            channel!.invokeMethod("print", arguments: "symbol#addList \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [[String: Any]] else { return }

            let symbolIds = batchAddMarkerToLayer( datas: arguments)
            result(symbolIds)
        case "symbol#update":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolId = arguments["symbol"] as? String else { return }

            for symbol in symbolAnnotationController.styleAnnotations(){
                if symbol.identifier == symbolId {
                    Convert.interpretSymbolOptions(options: arguments["options"], delegate: symbol as! MGLSymbolStyleAnnotation)
                    // Load (updated) icon image from asset if an icon name is supplied.
                    if let options = arguments["options"] as? [String: Any],
                        let iconImage = options["iconImage"] as? String {
                        addIconImageToMap(iconImageName: iconImage)
                    }
                    symbolAnnotationController.updateStyleAnnotation(symbol)
                    break;
                }
            }
            result(nil)
        case "symbol#remove":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolId = arguments["symbol"] as? String else { return }

            for symbol in symbolAnnotationController.styleAnnotations(){
                if symbol.identifier == symbolId {
                    symbolAnnotationController.removeStyleAnnotation(symbol)
                    break;
                }
            }
            result(nil)
         case "symbol#removeList":
            channel!.invokeMethod("print", arguments: "symbol#removeList \(String(describing: methodCall.arguments))")
            removeBatchAddMarker()
            result(nil)
        case "circle#add":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            // Parse geometry
            if let options = arguments["options"] as? [String: Any],
                let geometry = options["geometry"] as? [Double] {
                // Convert geometry to coordinate and create circle.
                let coordinate = CLLocationCoordinate2DMake(geometry[0], geometry[1])
                let circle = MGLCircleStyleAnnotation(center: coordinate)
                Convert.interpretCircleOptions(options: arguments["options"], delegate: circle)
                circleAnnotationController.addStyleAnnotation(circle)
                result(circle.identifier)
            } else {
                result(nil)
            }
        case "circle#update":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let circleId = arguments["circle"] as? String else { return }

            for circle in circleAnnotationController.styleAnnotations() {
                if circle.identifier == circleId {
                    Convert.interpretCircleOptions(options: arguments["options"], delegate: circle as! MGLCircleStyleAnnotation)
                    circleAnnotationController.updateStyleAnnotation(circle)
                    break;
                }
            }
            result(nil)
        case "circle#remove":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let circleId = arguments["circle"] as? String else { return }

            for circle in circleAnnotationController.styleAnnotations() {
                if circle.identifier == circleId {
                    circleAnnotationController.removeStyleAnnotation(circle)
                    break;
                }
            }
            result(nil)
        case "line#add":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            // Parse geometry
            if let options = arguments["options"] as? [String: Any],
                let geometry = options["geometry"] as? [[Double]] {
                // Convert geometry to coordinate and create a line.
                var lineCoordinates: [CLLocationCoordinate2D] = []
                for coordinate in geometry {
                    lineCoordinates.append(CLLocationCoordinate2DMake(coordinate[0], coordinate[1]))
                }
                let line = MGLLineStyleAnnotation(coordinates: lineCoordinates, count: UInt(lineCoordinates.count))
                Convert.interpretLineOptions(options: arguments["options"], delegate: line)
                lineAnnotationController.addStyleAnnotation(line)
                result(line.identifier)
            } else {
                result(nil)
            }
        case "line#update":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let lineId = arguments["line"] as? String else { return }

            for line in lineAnnotationController.styleAnnotations() {
                if line.identifier == lineId {
                    Convert.interpretLineOptions(options: arguments["options"], delegate: line as! MGLLineStyleAnnotation)
                    lineAnnotationController.updateStyleAnnotation(line)
                    break;
                }
            }
            result(nil)
        case "line#remove":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let lineId = arguments["line"] as? String else { return }

            for line in lineAnnotationController.styleAnnotations() {
                if line.identifier == lineId {
                    lineAnnotationController.removeStyleAnnotation(line)
                    break;
                }
            }
            result(nil)

        /*plugins*/

        case "heaven_map#addData":
            //channel.invokeMethod("print", arguments: "heaven_map#addData \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let model = arguments["model"] as? [String: Any] else { return }
            addHeavenMapSourceAndLayer(data: model)
            result(nil)

        case "heaven_map#removeData":
            //channel.invokeMethod("print", arguments: "heaven_map#removeData \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let id = arguments["id"] as? String {
                removeHeavenMap(id: id)
            }
            result(nil)

        case "map_route#addRouteOverlay":
            //channel.invokeMethod("print", arguments: "heaven_map#addRouteOverlay \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let model = arguments["model"] as? [String: Any] else { return }
            addHeavenMapRouteOverlay(data: model, channel: channel!)
            result(nil)

        case "map_route#removeRouteOverlay":
            //channel.invokeMethod("print", arguments: "heaven_map#removeRouteOverlay \(String(describing: methodCall.arguments))")
            removeHeavenMapRouteOverlay()
            result(nil)

        // todo: jison_test_navigation
        case "map_route#startNavigation":
            //channel.invokeMethod("print", arguments: "heaven_map#startNavigation \(String(describing: methodCall.arguments))")
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let model = arguments["model"] as? [String: Any] else { return }
            startNavigation(data: model, channel: channel!)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func addIconImageToMap(iconImageName: String) {
        // Check if the image has already been added to the map.
        if self.mapView.style?.image(forName: iconImageName) == nil {
            // Build up the full path of the asset.
            // First find the last '/' ans split the image name in the asset directory and the image file name.
            if let range = iconImageName.range(of: "/", options: [.backwards]) {
                let directory = String(iconImageName[..<range.lowerBound])
                let assetPath = registrar.lookupKey(forAsset: "\(directory)/")
                let fileName = String(iconImageName[range.upperBound...])
                // If we can load the image from file then add it to the map.
                if let imageFromAsset = UIImage.loadFromFile(imagePath: assetPath, imageName: fileName) {
                    self.mapView.style?.setImage(imageFromAsset, forName: iconImageName)
                }
            }else{
                let bundle = PodAsset.bundle(forPod: "MapboxGl")
                if let imageFromAsset = UIImage(named: iconImageName, in: bundle, compatibleWith: nil){
                    if let resizedImage = imageFromAsset.resize(maxWidthHeight:50.0) {
                        self.mapView.style?.setImage(resizedImage, forName: iconImageName)
                    }
                   
                }
            }
        }
    }

    private func updateMyLocationEnabled() {
        mapView.showsUserLocation = self.myLocationEnabled
    }
    
    private func getCamera() -> MGLMapCamera? {
        return trackCameraPosition ? mapView.camera : nil

    }

    /*
    *  UITapGestureRecognizer
    *  On tap invoke the map#onMapClick callback.
    */
    @objc @IBAction func handleMapTap(sender: UITapGestureRecognizer) {
        // Get the CGPoint where the user tapped.
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        channel?.invokeMethod("map#onMapClick", arguments: [
                      "x": point.x,
                      "y": point.y,
                      "lng": coordinate.longitude,
                      "lat": coordinate.latitude,
                  ])
    }
    /*
    *  UITapGestureRecognizer
    *  On long press invoke the map#onMapLongPress callback.
    */
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
        channel!.invokeMethod("map#onMapLongPress", arguments: arguments)
    }

    /*
     *  MGLAnnotationControllerDelegate
     */
    func annotationController(_ annotationController: MGLAnnotationController, didSelect styleAnnotation: MGLStyleAnnotation) {
        guard let channel = channel else {
            return
        }

        if let symbol = styleAnnotation as? MGLSymbolStyleAnnotation {
            channel.invokeMethod("symbol#onTap", arguments: ["symbol" : "\(symbol.identifier)"])
        } else if let circle = styleAnnotation as? MGLCircleStyleAnnotation {
            channel.invokeMethod("circle#onTap", arguments: ["circle" : "\(circle.identifier)"])
        } else if let line = styleAnnotation as? MGLLineStyleAnnotation {
            channel.invokeMethod("line#onTap", arguments: ["line" : "\(line.identifier)"])
        }
    }

    // This is required in order to hide the default Maps SDK pin
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        if annotation is MGLUserLocation {
            return nil
        }
        return MGLAnnotationView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    
    // MARK: heaven map <警察局、大使馆>
    private func addHeavenMapSourceAndLayer(data: [String: Any]) {
        guard let id = data["id"] as? String,
            let sourceUrl = data["sourceUrl"] as? String,
            let sourceLayer = data["sourceLayer"] as? String,
            let color = data["color"] as? Int
            else { return }

        print("[Mapbox] --> addHeavenMapSourceAndLayer, data:\(data)")

        let sourcId = getHeavenMapSourceId(sourceId: id)
        let layerId = getHeavenMapLayerId(id: id)

        guard mapView.style?.source(withIdentifier: sourcId) == nil else { return }
        var source: MGLSource!
        source = MGLVectorTileSource(identifier: sourcId, tileURLTemplates: [sourceUrl])
        mapView.style?.addSource(source)

        let bundle = PodAsset.bundle(forPod: "MapboxGl")
        let image = UIImage(named: sourceLayer, in: bundle, compatibleWith: nil)
        var layer: MGLVectorStyleLayer!       
         
        if sourceLayer == "poi" {
                 
            let zoomLevel = 12
             
            // Create a heatmap layer.
            let heatmapLayer = MGLHeatmapStyleLayer(identifier: sourcId, source: source)
            heatmapLayer.sourceLayerIdentifier = sourceLayer

            // Adjust the color of the heatmap based on the point density.
            
            let colorDictionary: [NSNumber: UIColor] = [
            0.0: .clear,
            0.01: .white,
            0.15: UIColor(red: 0.19, green: 0.30, blue: 0.80, alpha: 1.0),
            0.5: UIColor(red: 0.73, green: 0.23, blue: 0.25, alpha: 1.0),
            1: .yellow
            ]
            
//            let colorDictionary: [NSNumber: UIColor] = [
//            0.0: .init(red: 33, green: 102, blue: 172, alpha: 0),
//            0.2: .init(red: 103, green: 169, blue: 207, alpha: 1),
//            0.4: .init(red: 209, green: 229, blue: 240, alpha: 1),
//            0.6: .init(red: 253, green: 219, blue: 199, alpha: 1),
//            0.8: .init(red: 239, green: 138, blue: 98, alpha: 1),
//            1.0: .init(red: 178, green: 24, blue: 43, alpha: 1),
//            ]
            
            heatmapLayer.heatmapColor = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($heatmapDensity, 'linear', nil, %@)", colorDictionary)
             
            // Heatmap weight measures how much a single data point impacts the layer's appearance.
            heatmapLayer.heatmapWeight = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:(mag, 'linear', nil, %@)",
            [0: 0,
            6: 1])
             
            // Heatmap intensity multiplies the heatmap weight based on zoom level.
            heatmapLayer.heatmapIntensity = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
            [0: 1,
            zoomLevel: 3])
            
            heatmapLayer.heatmapRadius = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
            [0: 2,
            zoomLevel: 20])

            // The heatmap layer should be visible up to zoom level 9.
            heatmapLayer.heatmapOpacity = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
            [7: 1,
            zoomLevel: 0])
//            heatmapLayer.heatmapOpacity = NSExpression(format: "mgl_step:from:stops:($zoomLevel, 'linear', %@)", [7: 1, zoomLevel: 0])
            mapView.style?.addLayer(heatmapLayer)
          
           
            let circleLayer = MGLCircleStyleLayer(identifier: layerId, source: source)
            circleLayer.sourceLayerIdentifier = sourceLayer
            circleLayer.circleRadius = NSExpression(forConstantValue: NSNumber(value: 8))
            circleLayer.circleOpacity = NSExpression(format: "mgl_step:from:stops:($zoomLevel, 0, %@)", [0: 0, zoomLevel: 0.75])
            
            circleLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            circleLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
            circleLayer.circleColor = NSExpression(forConstantValue: UIColor.init(argb: color))
            layer = circleLayer
             
            
            /*
            // Add a circle layer to represent the earthquakes at higher zoom levels.
            let circleLayer = MGLCircleStyleLayer(identifier: "circle-layer", source: source)
            circleLayer.sourceLayerIdentifier = sourceLayer
            circleLayer.circleRadius = NSExpression(forConstantValue: 8)
            
            // The heatmap layer will have an opacity of 0.75 up to zoom level 9, when the opacity becomes 0.
            circleLayer.circleOpacity = NSExpression(format: "mgl_step:from:stops:($zoomLevel, 0, %@)", [0: 0, zoomLevel: 0.75])
            
            let magnitudeDictionary: [NSNumber: UIColor] = [
            0: .white,
            0.5: .yellow,
            2.5: UIColor(red: 0.73, green: 0.23, blue: 0.25, alpha: 1.0),
            5: UIColor(red: 0.19, green: 0.30, blue: 0.80, alpha: 1.0)
            ]
            circleLayer.circleColor = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:(mag, 'linear', nil, %@)", magnitudeDictionary)
            circleLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            circleLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
            layer = circleLayer
            */
        } else {
            if image != nil {
                       mapView.style?.setImage(image!, forName: sourceLayer)
                       guard mapView.style?.layer(withIdentifier: layerId) == nil else { return }
                       let circlesLayer = MGLSymbolStyleLayer(identifier: layerId, source: source)
                       circlesLayer.sourceLayerIdentifier = sourceLayer
                       circlesLayer.iconImageName = NSExpression(forConstantValue: sourceLayer);
                       layer = circlesLayer
                   }
                   else {
                       let circleLayer = MGLCircleStyleLayer(identifier: layerId, source: source)
                       circleLayer.sourceLayerIdentifier = sourceLayer
                       circleLayer.circleRadius = NSExpression(forConstantValue: NSNumber(value: 8))
                       circleLayer.circleOpacity = NSExpression(forConstantValue: 0.8)
                       circleLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
                       circleLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
                       circleLayer.circleColor = NSExpression(forConstantValue: UIColor.init(argb: color))
                       layer = circleLayer
                   }
        }
        //let shapeID = "com.mapbox.annotations.shape."
        let pointLayerID = "com.mapbox.annotations.points"
        if let annotationPointLayer = mapView.style?.layer(withIdentifier: pointLayerID) {
            guard layer != nil else {
                return
            }
            mapView.style?.insertLayer(layer, below: annotationPointLayer)
        } else {
            mapView.style?.addLayer(layer)
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

        MapRouteDataModel.removeFromMap( mapview: mapView,channel:channel!);
    }

    // MARK: navigation
    //TODO
    private func startNavigation(data: [String: Any], channel: FlutterMethodChannel){
        print("[MapboxMapController] --> startNavigation")

        guard let route = MapRouteDataModel.editData(data: data, type: "startNavigation")?.routes.first else { return }

        //        print("[MapRouteDataModel] --> startNavigation, mapview: \(mapview)")

        guard let window = UIApplication.shared.delegate?.window else { return }

        if let vc = window?.rootViewController {
            print("[MapRouteDataModel] --> vc: \(vc)");

            // editRouteOptions
            // android
            /*
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
            */


            // ios
            /*
            let ACCESS_TOKEN = "pk.hyn"
            //let NAVIGATION_USER = "hyperion"
            let NAVIGATION_UUID = "UUID"
            let DOMAIN = "api.hyn.space/"
            let directions = NavigationDirections(accessToken: ACCESS_TOKEN, host: DOMAIN)
            route.directionsOptions.profileIdentifier = .automobile
            route.directionsOptions.locale = Locale(identifier: "zh")
            route.speechLocale = Locale(identifier: "zh")
            route.routeIdentifier = NAVIGATION_UUID
            */

            let directions = NavigationDirections()
            let service = MapboxNavigationService(route: route, directions: directions, simulating: .never)
            let navigationViewController = self.navigationViewController(navigationService: service)
            navigationViewController.modalPresentationStyle = .fullScreen
            vc.present(navigationViewController, animated: true) {

                print("[MapRouteDataModel] --> finish");
            }
        }
    }

    func navigationViewController(navigationService: NavigationService) -> NavigationViewController {
        let route = navigationService.route
        let styles = [TTCustomStyle()]
        let options = NavigationOptions(styles: styles, navigationService: navigationService)
        let navigationViewController = NavigationViewController(for: route, options: options)

//        navigationViewController.delegate = self
//        navigationViewController.mapView?.delegate = self
//        navigationViewController.voiceController.voiceControllerDelegate = self;

        return navigationViewController
    }

    func beginCarPlayNavigation() {
        print("[MapRouteDataModel] --> beginCarPlayNavigation")

    }

    deinit {
        print("[MapboxMapController] --> deinit")
    }

    // MARK:
    let BATCH_ADD_MARKER_SOURCE_NAME = "hyn-batch-add-marker-source";

    let BATCH_ADD_MARKER_LAYER_NAME = "hyn-batch-add-marker-layer";

    let BATCH_ADD_MARKER_IMAGE_NAME = "hyn-batch-add-marker-image";

    private func removeBatchAddMarker(){

        if let layer =  mapView.style?.layer(withIdentifier: BATCH_ADD_MARKER_LAYER_NAME) as MGLStyleLayer?{
            mapView.style?.removeLayer(layer)
        }

        if let source = mapView.style?.source(withIdentifier: BATCH_ADD_MARKER_SOURCE_NAME) as MGLSource?{
            mapView.style?.removeSource(source)
        }
    }

    private func batchAddMarkerToLayer(datas: [[String: Any]]) -> [String]{

        var features = [MGLPointFeature]()
        var ids = [String]()

        for data in datas{

            symbolIndex += 1
            let feature = MGLPointFeature();

            if let geometry = data["geometry"] as? [Double] {
                feature.coordinate = CLLocationCoordinate2D.fromArray(geometry)
            }

            var attributes  =  [String:Any]();
            if let iconImage = data["iconImage"] as? String {
                attributes["iconImage"] = iconImage
                //添加图标到mapbox 地图中
                let markerAnnotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: iconImage);
                if(markerAnnotationImage == nil){
                    let bundle = PodAsset.bundle(forPod: "MapboxGl")
                    if let image = UIImage(named: iconImage, in: bundle, compatibleWith: nil){
                        mapView.style?.setImage(image, forName: iconImage)
                    }
                }
            }

            if let iconOffset = data["iconOffset"] as? [Double] {
                attributes["iconOffset"] = iconOffset
            }

            if let iconSize = data["iconSize"] as? Double {
                attributes["iconSize"] = iconSize

            }

            if let iconAnchor = data["iconAnchor"] as? String {
                attributes["iconAnchor"] = iconAnchor
            }

            attributes["id"] = symbolIndex
            feature.attributes = attributes
            features.append(feature)
            ids.append(String(symbolIndex))
        }

        let markerSourceFeature =  MGLShapeCollectionFeature(shapes: features)

        var markerSource = mapView.style?.source(withIdentifier: BATCH_ADD_MARKER_SOURCE_NAME)
        if(markerSource == nil){
            markerSource = MGLShapeSource(identifier: BATCH_ADD_MARKER_SOURCE_NAME, shape: markerSourceFeature)
            mapView.style?.addSource(markerSource!)
        }else{
            (markerSource as! MGLShapeSource).shape = markerSourceFeature
        }

        let symbolLayer = mapView.style?.layer(withIdentifier: BATCH_ADD_MARKER_LAYER_NAME);
        if(symbolLayer == nil){
            let  symbolLayerTemp = MGLSymbolStyleLayer(identifier: BATCH_ADD_MARKER_LAYER_NAME, source: markerSource!)
            //    symbolLayer.iconImageName = NSExpression(forConstantValue: ROUTE_LINE_START_ICON)
            symbolLayerTemp.iconImageName = NSExpression(forKeyPath: "iconImage")
            symbolLayerTemp.iconAllowsOverlap = NSExpression(forConstantValue: true)
            symbolLayerTemp.iconAnchor = NSExpression(forKeyPath:"iconAnchor")
            symbolLayerTemp.iconScale = NSExpression(forKeyPath:"iconSize")
            //    symbolLayer.symbolSpacing = NSExpression(forConstantValue: 1)
            let systemAnnotationLayer = mapView.style?.layer(withIdentifier: "com.mapbox.annotations.points")
            if(systemAnnotationLayer != nil){
                mapView.style?.insertLayer(symbolLayerTemp, below: systemAnnotationLayer!)
            }else{
                mapView.style?.addLayer(symbolLayerTemp)
            }
        }

        return ids
    }


    /*
     *  MGLMapViewDelegate
     */
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        isMapReady = true
        updateMyLocationEnabled()
        currentStyle = style.name
        if let initialTilt = initialTilt {
            let camera = mapView.camera
            camera.pitch = initialTilt
            mapView.setCamera(camera, animated: false)
        }

        lineAnnotationController = MGLLineAnnotationController(mapView: self.mapView)
        lineAnnotationController!.annotationsInteractionEnabled = true
        lineAnnotationController?.delegate = self

        symbolAnnotationController = MGLSymbolAnnotationController(mapView: self.mapView)
        symbolAnnotationController!.annotationsInteractionEnabled = true
        symbolAnnotationController?.delegate = self

        circleAnnotationController = MGLCircleAnnotationController(mapView: self.mapView)
        circleAnnotationController!.annotationsInteractionEnabled = true
        circleAnnotationController?.delegate = self

        mapReadyResult?(nil)
        if let channel = channel {
            channel.invokeMethod("map#onStyleLoaded", arguments: nil)
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        if(languageEnable!){
            setLanguageCode(languageCode: self.languageCode!)
        }

        //mapReadyResult?(currentStyle != nil)
        //mapReadyResult = nil
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
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        // Only for Symbols images should loaded.
        guard let symbol = annotation as? Symbol,
            let iconImageFullPath = symbol.iconImage else {
                return nil
        }
        // Reuse existing annotations for better performance.
        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: iconImageFullPath)
        if annotationImage == nil {
            // Initialize the annotation image (from predefined assets symbol folder).
            if let range = iconImageFullPath.range(of: "/", options: [.backwards]) {
                let directory = String(iconImageFullPath[..<range.lowerBound])
                let assetPath = registrar.lookupKey(forAsset: "\(directory)/")
                let iconImageName = String(iconImageFullPath[range.upperBound...])
                let image = UIImage.loadFromFile(imagePath: assetPath, imageName: iconImageName)
                if let image = image {
                    annotationImage = MGLAnnotationImage(image: image, reuseIdentifier: iconImageFullPath)
                }
            }
        }
        return annotationImage
    }

    // On tap invoke the symbol#onTap callback.
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {

       if let symbol = annotation as? Symbol {
            channel?.invokeMethod("symbol#onTap", arguments: ["symbol" : "\(symbol.id)"])

        }
    }

    // Allow callout view to appear when an annotation is tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }

    func mapView(_ mapView: MGLMapView, didChange mode: MGLUserTrackingMode, animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("map#onCameraTrackingChanged", arguments: ["mode": mode.rawValue])
            if mode == .none {
                channel.invokeMethod("map#onCameraTrackingDismissed", arguments: [])
            }
        }
    }

    func mapViewDidBecomeIdle(_ mapView: MGLMapView) {
        if let channel = channel {
            channel.invokeMethod("map#onIdle", arguments: []);
        }
    }

    func mapView(_ mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("camera#onMoveStarted", arguments: []);
        }
    }

    func mapViewRegionIsChanging(_ mapView: MGLMapView) {
        if !trackCameraPosition { return };
        if let channel = channel {
            channel.invokeMethod("camera#onMove", arguments: [
                "position": getCamera()?.toDict(mapView: mapView)
            ]);
        }
    }

    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("camera#onIdle", arguments: []);
        }
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
        if (self.myLocationEnabled == myLocationEnabled) {
            return
        }
        self.myLocationEnabled = myLocationEnabled
        updateMyLocationEnabled()
    }
    func setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode) {
        mapView.userTrackingMode = myLocationTrackingMode
    }
    func setLogoViewMargins(x: Double, y: Double) {
        mapView.logoViewMargins = CGPoint(x: x, y: y)
    }
    func setCompassViewPosition(position: MGLOrnamentPosition) {
        mapView.compassViewPosition = position
    }
    func setCompassViewMargins(x: Double, y: Double) {
        mapView.compassViewMargins = CGPoint(x: x, y: y)
    }
    func setAttributionButtonMargins(x: Double, y: Double) {
        mapView.attributionButtonMargins = CGPoint(x: x, y: y)
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

    func setLanguageCode(languageCode: String) {
        self.languageCode = languageCode
        if(mapView.style==nil){
            return;
        }
        if(languageEnable!){
            setLanguageCode(style: mapView.style!, languageCode: languageCode);
        }

    }

    func setLanguageEnable(languageEnable: Bool) {
        self.languageEnable = languageEnable
    }

    func setLanguageCode(style: MGLStyle,languageCode: String) {
        let layers = style.layers;
        for layer in layers{
            if layer is MGLSymbolStyleLayer{
                let layerTemp = layer as! MGLSymbolStyleLayer
                layerTemp.text = getLanguageExpression(languageCode: languageCode)

            }
        }
    }

    func getLanguageExpression(languageCode:String) -> NSExpression{
        let firstName = "name:" + languageCode;
        return NSExpression(format: "mgl_coalesce({%K,%K,%K})",argumentArray:["\(firstName)","name_en","name"])

    }
}


//class Symbol: MGLPointAnnotation {
//
//    var id: String = "symbol_\(hash())"
//    var iconImage: String?
//    var iconSize: Double?
//    var iconOffset: [Double]?
//    var iconAnchor: String?
//
//    func makeImage() -> UIImage {
//        let bundle = PodAsset.bundle(forPod: "MapboxGl")
//        var image:UIImage;
//        if(self.iconImage != nil){
//            image = UIImage(named: self.iconImage!, in: bundle, compatibleWith: nil)!
//        } else {
//            image = UIImage(named: "hyn_marker_big", in: bundle, compatibleWith: nil)!
//        }
//
//        if let resizedImage = image.resize(maxWidthHeight: self.iconSize ?? 50.0) {
//            image = resizedImage
//        }
//
//        let offsetX: CGFloat = CGFloat(iconOffset?[0] ?? 0)
//        let offsetY: CGFloat = CGFloat(iconOffset?[1] ?? 0)
//        let anchor: String = self.iconAnchor ?? "center"
//
//        NSLog("anchor \(anchor) offsetX \(offsetX) offsetY \(offsetY)")
//
//        if let offsetImage = image.offsetImage(anchor: anchor, offsetX: offsetX, offsetY: offsetY) {
//            image = offsetImage
//        }
//
//        //  image = image.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: image.size.height/2, right: 0))
//
//        return image
//    }
//}

class MapRouteDataModel {

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


    public static func addToMap(data:[String: Any], mapview:MGLMapView, channel: FlutterMethodChannel) {

        print("[MapRouteDataModel] --> addToMap, mapView: \(mapview)")
        guard let pair = editData(data: data, type: "addToMap"),
              let route = pair.routes.first,
              let startPoint = pair.sourPoints.first,
              let endPoint = pair.sourPoints.last
        else { return }
        let waypoints = pair.wayPoints

        print("[MapRouteDataModel] --> addToMap, norma, mapView: \(mapview)")

        // MARK:  1.MapView --> Style --> 添加连接线 -->Source

        var supplementLineFeatures: [MGLPolylineFeature] = []

        // startSupplementPolyline
        let startSupplementCoordinates = [startPoint, waypoints[0].coordinate]
        let startSupplementPolyline = MGLPolylineFeature(coordinates: startSupplementCoordinates, count: UInt(startSupplementCoordinates.count))
        supplementLineFeatures.append(startSupplementPolyline)

        // endSupplementPolyline
        let endSupplementCoordinates = [waypoints.last!.coordinate, endPoint]
        let endSupplementPolyline = MGLPolylineFeature(coordinates: endSupplementCoordinates, count: UInt(endSupplementCoordinates.count))
        supplementLineFeatures.append(endSupplementPolyline)

        let supplementCollectionFeature =  MGLShapeCollectionFeature(shapes: supplementLineFeatures)

        let supplementLineSource = MGLShapeSource(identifier: ROUTE_SUPPLEMENT_LINE_SOURCE_NAME, shape: supplementCollectionFeature, options: [.lineDistanceMetrics: false])
        mapview.style?.addSource(supplementLineSource)

        // MARK:  2.MapView --> Style --> 添加连接线 -->Layer
        let supplementLine = MGLLineStyleLayer(identifier: ROUTE_SUPPLEMENT_LINE_LAYER_NAME, source: supplementLineSource)
        supplementLine.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteLineWidthByZoomLevel)
        supplementLine.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.5882352941, green: 0.5882352941, blue: 0.5882352941, alpha: 1))
        supplementLine.lineDashPattern = NSExpression(forConstantValue: [0.7, 0.7])
        mapview.style?.addLayer(supplementLine)

        // MARK:  3.MapView --> Style --> 添加导航线 --> Source
        var altRoutes: [MGLPolylineFeature] = []
        let polyline = MGLPolylineFeature(coordinates: route.coordinates!, count: UInt(route.coordinates!.count))
        altRoutes.append(polyline)

        let lineShapeCollectionFeature =  MGLShapeCollectionFeature(shapes: altRoutes)
        let lineSource = MGLShapeSource(identifier: ROUTE_LINE_SOURCE_NAME, shape: lineShapeCollectionFeature, options: [.lineDistanceMetrics: false])
        mapview.style?.addSource(lineSource)

        // MARK:  4.MapView --> Style --> 添加导航线 --> Layer
        let line = MGLLineStyleLayer(identifier: ROUTE_LINE_LAYER_NAME, source: lineSource)
        line.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteLineWidthByZoomLevel)
        line.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.2705882353, green: 0.5882352941, blue: 0.9960784314, alpha: 1))
        line.lineJoin = NSExpression(forConstantValue: "round")
        line.lineCap = NSExpression(forConstantValue: "round")
        mapview.style?.addLayer(line)

        channel.invokeMethod("print", arguments: "addLayer")

        // MARK:  5.MapView --> Style --> Camera
        let paddingTop:CGFloat = data["paddingTop"] as? CGFloat ?? 100.0
        let paddingLeft:CGFloat = data["paddingLeft"] as? CGFloat ?? 100.0
        let paddingRight:CGFloat = data["paddingRight"] as? CGFloat ?? 100.0
        let paddingBottom:CGFloat = data["paddingBottom"] as? CGFloat ?? 100.0

//        print("padding")
//        print("paddingTop:\(paddingTop)")
//        print("paddingLeft:\(paddingLeft)")
//        print("paddingRight:\(paddingRight)")
//        print("paddingBottom:\(paddingBottom)")

        let currentCamera = mapview.camera
        currentCamera.pitch = 0
        currentCamera.heading = 0

        let newCamera = mapview.camera(currentCamera, fitting: polyline, edgePadding: UIEdgeInsets.init(top: paddingTop/2 , left: paddingLeft/8, bottom: paddingBottom/2, right: paddingRight/8))
        mapview.setCamera(newCamera, withDuration: 1, animationTimingFunction: nil)


        // MARK:  6.MapView --> Style --> PointFeature --> Source
        var features = [MGLPointFeature]()

        // startFeature
        let startFeature = MGLPointFeature();
        startFeature.coordinate = startPoint;
        startFeature.attributes = [
            ROUTE_LINE_ICON_PROPERTY:ROUTE_LINE_START_ICON
        ]
        features.append(startFeature)

        // endFeature
        let endFeature = MGLPointFeature();
        endFeature.coordinate = endPoint;
        endFeature.attributes = [
            ROUTE_LINE_ICON_PROPERTY:ROUTE_LINE_END_ICON
        ]
        features.append(endFeature)

        let markerSourceFeature = MGLShapeCollectionFeature(shapes: features)
        let markerSource = MGLShapeSource(identifier: ROUTE_START_END_SOURCE_NAME, shape: markerSourceFeature)
        mapview.style?.addSource(markerSource)

        // MARK:  7.MapView --> Style --> Layer
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
        symbolLayer.iconImageName = NSExpression(forKeyPath: ROUTE_LINE_ICON_PROPERTY)
        symbolLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
        symbolLayer.iconScale =  NSExpression(forConstantValue: 0.4)
        symbolLayer.iconAnchor = NSExpression(forConstantValue: "bottom")
        mapview.style?.addLayer(symbolLayer)


        // MARK:  8.MapView --> Style --> 添加箭头 --> 图片
        let arrowAnnotationImage = mapview.dequeueReusableAnnotationImage(withIdentifier: ROUTE_LINE_ARROW_ICON);
        if(arrowAnnotationImage == nil){
            let bundle = PodAsset.bundle(forPod: "MapboxGl")
            if let image = UIImage(named: "line_arrow_white", in: bundle, compatibleWith: nil){
                mapview.style?.setImage(image, forName: ROUTE_LINE_ARROW_ICON)
            }
        }

        // MARK:  9.MapView --> Style --> 添加箭头 --> Layer
        let routeArrowLayer  = MGLSymbolStyleLayer(identifier: ROUTE_LINE_ARROW_LAYER_NAME, source: lineSource)
        routeArrowLayer.symbolPlacement = NSExpression(forConstantValue: "line")
        routeArrowLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
        routeArrowLayer.iconImageName = NSExpression(forConstantValue: ROUTE_LINE_ARROW_ICON)
        routeArrowLayer.symbolSpacing = NSExpression(forConstantValue: 1)
        routeArrowLayer.iconScale = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", MBRouteArrowIconSizeByZoomLevel)
        mapview.style?.addLayer(routeArrowLayer)
    }


    public static func removeFromMap(mapview:MGLMapView,channel: FlutterMethodChannel) {

        //  移除导航线 --> Layer
        if let lineLayer =  mapview.style?.layer(withIdentifier: ROUTE_LINE_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(lineLayer)
        }

        //  移除导航线 --> Source
        if let lineSource = mapview.style?.source(withIdentifier: ROUTE_LINE_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(lineSource)
        }

        //  移除导航线箭头 --> Layer
        if let lineArrowLayer =  mapview.style?.layer(withIdentifier: ROUTE_LINE_ARROW_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(lineArrowLayer)
        }

        //  移除起点和终点marker --> Layer
        if let startEndMarkerLayer =  mapview.style?.layer(withIdentifier: ROUTE_START_END_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(startEndMarkerLayer)
        }

        //  移除起点和终点marker --> Source
        if let startEndMarkerSource = mapview.style?.source(withIdentifier: ROUTE_START_END_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(startEndMarkerSource)
        }

        //  移除辅助线 --> Layer
        if let supplementLineLayer =  mapview.style?.layer(withIdentifier: ROUTE_SUPPLEMENT_LINE_LAYER_NAME) as MGLStyleLayer?{
            mapview.style?.removeLayer(supplementLineLayer)
        }

        //  移除辅助线 --> Source
        if let supplementLineSource = mapview.style?.source(withIdentifier: ROUTE_SUPPLEMENT_LINE_SOURCE_NAME) as MGLSource?{
            mapview.style?.removeSource(supplementLineSource)
        }
    }


    deinit {

        print("[MapRouteDataModel] --> deinit")
    }

    public static func editData(data:[String: Any], type: String = "") -> (wayPoints: [Waypoint], routes: [Route], sourPoints: [CLLocationCoordinate2D])? {

        print("[MapRouteDataModel] --> editData ")

        guard let startLatLngDouble = data["startLatLng"] as? [Double] else {
            return nil
        }
        let startPoint = CLLocationCoordinate2D.fromArray(startLatLngDouble)

        guard let endLatLngDouble = data["endLatLng"] as? [Double] else{
            return nil
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
            //print("[MapBoxController] -->editData, response:\(response)")
        }catch{
            print("[MapBoxController] -->editData, convert json to map error")
        }

        var namedWaypoints: [Waypoint]?
        if let jsonWaypoints = (response["waypoints"] as? [JSONDictionary]) {
            namedWaypoints = jsonWaypoints.map { (api) -> Waypoint in
                print("[MapBoxController] -->\(type), editData, api:\(api)")

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
            return nil
        }

        waypoints.first?.separatesLegs = true
        waypoints.last?.separatesLegs = true
        let legSeparators = waypoints.filter { $0.separatesLegs }
        let routes = (response["routes"] as? [JSONDictionary])?.map {
            Route(json: $0, waypoints: legSeparators, options: routeOptions)
        }

        return (waypoints, routes, [startPoint, endPoint]) as? ([Waypoint], [Route], [CLLocationCoordinate2D])
    }

}


class TTCustomStyle: DayStyle {

    required init() {
        super.init()

        mapStyleURL = URL(string: "https://cn.tile.map3.network/see-it-all-boundary-cdn-en.json")!
        styleType = .night
    }

    override func apply() {
        super.apply()

        //BottomBannerView.appearance().backgroundColor = .orange
    }
}
