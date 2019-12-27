part of mapbox_gl;

// todo:jison_test_navigation
class Navigation {
  static Future navigation(BuildContext context, NavigationDataModel model) async {
    var channel = MapboxMapParent.of(context)?.controller?.channel;
    return await channel.invokeMethod('map_route#startNavigation', <String, dynamic>{'model': model._toJson()});
  }
}

class NavigationDataModel {
  final LatLng startLatLng;
  final LatLng endLatLng;
  final String directionsResponse;
  final String profile;

  NavigationDataModel({this.startLatLng, this.endLatLng, this.directionsResponse, this.profile});

  dynamic _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('startLatLng', startLatLng?._toJson());
    addIfPresent('endLatLng', endLatLng?._toJson());
    addIfPresent('directionsResponse', directionsResponse);
    addIfPresent('profile', profile);

    return json;
  }

  @override
  String toString() {
    return _toJson().toString();
  }
}
