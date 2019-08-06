import Mapbox

extension MGLMapCamera {
    func toDict(mapView: MGLMapView) -> [String: Any] {
        let zoom = MGLZoomLevelForAltitude(self.altitude, self.pitch, self.centerCoordinate.latitude, mapView.frame.size)
        return ["bearing": self.heading,
                "target": self.centerCoordinate.toArray(),
                "tilt": self.pitch,
                "zoom": zoom]
    }
    static func fromDict(_ dict: [String: Any], mapView: MGLMapView) -> MGLMapCamera? {
        guard let target = dict["target"] as? [Double],
            let zoom = dict["zoom"] as? Double,
            let tilt = dict["tilt"] as? CGFloat,
            let bearing = dict["bearing"] as? Double else { return nil }
        let location = CLLocationCoordinate2D.fromArray(target)
        let altitude = MGLAltitudeForZoomLevel(zoom, tilt, location.latitude, mapView.frame.size)
        return MGLMapCamera(lookingAtCenter: location, altitude: altitude, pitch: tilt, heading: bearing)
    }
}

extension CLLocationCoordinate2D {
    func toArray()  -> [Double] {
        return [self.latitude, self.longitude]
    }
    static func fromArray(_ array: [Double]) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: array[0], longitude: array[1])
    }
}

extension MGLCoordinateBounds {
    func toArray()  -> [[Double]] {
        return [self.sw.toArray(), self.ne.toArray()]
    }
    static func fromArray(_ array: [[Double]]) -> MGLCoordinateBounds {
        let southwest = CLLocationCoordinate2D.fromArray(array[0])
        let northeast = CLLocationCoordinate2D.fromArray(array[1])
        return MGLCoordinateBounds(sw: southwest, ne: northeast)
    }
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: CGFloat(alpha) / 255.0)
    }
    
    convenience init(argb: Int) {
        self.init(
            red: (argb >> 16) & 0xFF, green: (argb >> 8) & 0xFF, blue: argb & 0xFF, alpha: (argb >> 24) & 0xFF
        )
    }
}

extension UIImage {
    
    func resize(maxWidthHeight : Double)-> UIImage? {
        let actualHeight = Double(size.height)
        let actualWidth = Double(size.width)
        var maxWidth = 0.0
        var maxHeight = 0.0
        
        if actualWidth > actualHeight {
            maxWidth = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualWidth)
            maxHeight = (actualHeight * per) / 100.0
        }else{
            maxHeight = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualHeight)
            maxWidth = (actualWidth * per) / 100.0
        }
        
        let hasAlpha = true
        let scale: CGFloat = 0.0
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: maxHeight), !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: CGSize(width: maxWidth, height: maxHeight)))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage
    }
    
    func offsetImage(anchor: String, offsetX: CGFloat, offsetY: CGFloat) -> UIImage? {
        var newSize: CGSize
        var drawX: CGFloat = offsetX;
        var drawY: CGFloat = offsetY;
        if(anchor == "bottom" || anchor == "top") {
            newSize = CGSize(width: self.size.width + offsetX, height: self.size.height * 2 + offsetY)
            if(anchor == "top") {
                drawY = offsetY + self.size.height;
            }
        } else if(anchor == "left" || anchor == "right") {
            newSize = CGSize(width: self.size.width * 2 + offsetX, height: self.size.height + offsetY)
            if(anchor == "left") {
                drawX = offsetX + self.size.width
            }
        } else {    //default is center
            newSize = CGSize(width: self.size.width + offsetX, height: self.size.height + offsetY)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        
        self.draw(in: CGRect(x: drawX, y: drawY, width: self.size.width, height: self.size.height))
        let newIamge = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return newIamge
    }
}
