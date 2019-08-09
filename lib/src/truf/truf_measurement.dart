part of mapbox_gl;

class TurfMeasurement{

   static double distance( LatLng point1,  LatLng point2) {
    double difLat = TurfConversion.degreesToRadians(point2.latitude - point1.latitude);
    double difLon = TurfConversion.degreesToRadians(point2.longitude - point1.longitude);
    double lat1 = TurfConversion.degreesToRadians(point1.latitude);
    double lat2 = TurfConversion.degreesToRadians(point2.latitude);
    double value = pow(sin(difLat / 2.0), 2.0) + pow(sin(difLon / 2.0), 2.0) * cos(lat1) * cos(lat2);
    return TurfConversion.radiansToLength(2.0 * atan2(sqrt(value), sqrt(1.0 - value)));
  }

}



class TurfConversion{

  static double degreesToRadians(double degrees) {
    double radians = degrees % 360.0;
    return radians * 3.141592653589793 / 180.0;
  }

  static double radiansToLength(double radians) {
    return radians * 6373000.0;
  }

}