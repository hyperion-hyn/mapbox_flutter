
import Mapbox

protocol MapboxMapOptionsSink {
    func setCameraTargetBounds(bounds: MGLCoordinateBounds?)
    func setCompassEnabled(compassEnabled: Bool)
    func setStyleString(styleString: String)
    func setMinMaxZoomPreference(min: Double, max: Double)
    func setRotateGesturesEnabled(rotateGesturesEnabled: Bool)
    func setScrollGesturesEnabled(scrollGesturesEnabled: Bool)
    func setTiltGesturesEnabled(tiltGesturesEnabled: Bool)
    func setTrackCameraPosition(trackCameraPosition: Bool)
    func setZoomGesturesEnabled(zoomGesturesEnabled: Bool)
    func setMyLocationEnabled(myLocationEnabled: Bool)
    func setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode)
    
    func setEnableLogo(enableLogo: Bool)
    func setEnableAttribution(enableAttribution: Bool)
    func setCompassMargins(left: Int, top: Int, right: Int, bottom: Int)
    func setLanguageCode(languageCode: String)
}
