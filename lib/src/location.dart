// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of mapbox_gl;

/// A pair of latitude and longitude coordinates, stored as degrees.
class LatLng {
  /// Creates a geographical location specified in degrees [latitude] and
  /// [longitude].
  ///
  /// The latitude is clamped to the inclusive interval from -90.0 to +90.0.
  ///
  /// The longitude is normalized to the half-open interval from -180.0
  /// (inclusive) to +180.0 (exclusive)
  const LatLng(double latitude, double longitude)
      : assert(latitude != null),
        assert(longitude != null),
        latitude = (latitude < -90.0 ? -90.0 : (90.0 < latitude ? 90.0 : latitude)),
        longitude = (longitude + 180.0) % 360.0 - 180.0;

  /// The latitude in degrees between -90.0 and 90.0, both inclusive.
  final double latitude;

  /// The longitude in degrees between -180.0 (inclusive) and 180.0 (exclusive).
  final double longitude;

  dynamic _toJson() {
    return <double>[latitude, longitude];
  }

  static LatLng _fromJson(dynamic json) {
    if (json == null) {
      return null;
    }
    return LatLng(json[0], json[1]);
  }

  double distanceTo(LatLng other) {
    return TurfMeasurement.distance(LatLng(latitude, longitude), other);
  }

  @override
  String toString() => '$runtimeType($latitude, $longitude)';

  @override
  bool operator ==(Object o) {
    return o is LatLng && o.latitude == latitude && o.longitude == longitude;
  }

  @override
  int get hashCode => hashValues(latitude, longitude);
}

/// A latitude/longitude aligned rectangle.
///
/// The rectangle conceptually includes all points (lat, lng) where
/// * lat ∈ [`southwest.latitude`, `northeast.latitude`]
/// * lng ∈ [`southwest.longitude`, `northeast.longitude`],
///   if `southwest.longitude` ≤ `northeast.longitude`,
/// * lng ∈ [-180, `northeast.longitude`] ∪ [`southwest.longitude`, 180[,
///   if `northeast.longitude` < `southwest.longitude`
class LatLngBounds {
  /// Creates geographical bounding box with the specified corners.
  ///
  /// The latitude of the southwest corner cannot be larger than the
  /// latitude of the northeast corner.
  LatLngBounds({@required this.southwest, @required this.northeast})
      : assert(southwest != null),
        assert(northeast != null),
        assert(southwest.latitude <= northeast.latitude);

  /// The southwest corner of the rectangle.
  final LatLng southwest;

  /// The northeast corner of the rectangle.
  final LatLng northeast;

  dynamic _toList() {
    return <dynamic>[southwest._toJson(), northeast._toJson()];
  }

  @visibleForTesting
  static LatLngBounds fromList(dynamic json) {
    if (json == null) {
      return null;
    }
    return LatLngBounds(
      southwest: LatLng._fromJson(json[0]),
      northeast: LatLng._fromJson(json[1]),
    );
  }

  static LatLngBounds fromLatLngs(final List<LatLng> latLngs) {
    double minLat = 90;
    double minLon = double.maxFinite;
    double maxLat = -90;
    double maxLon = -double.maxFinite;

    for (final LatLng gp in latLngs) {
      final double latitude = gp.latitude;
      final double longitude = gp.longitude;
      minLat = min(minLat, latitude);
      minLon = min(minLon, longitude);
      maxLat = max(maxLat, latitude);
      maxLon = max(maxLon, longitude);
    }

    var southWest = LatLng(minLat,minLon);
    var northEast = LatLng(maxLat,maxLon);

    return new LatLngBounds(southwest:southWest,northeast:northEast);
  }

  @override
  String toString() {
    return '$runtimeType($southwest, $northeast)';
  }

  @override
  bool operator ==(Object o) {
    return o is LatLngBounds && o.southwest == southwest && o.northeast == northeast;
  }

  //test
  @override
  int get hashCode => hashValues(southwest, northeast);
}
