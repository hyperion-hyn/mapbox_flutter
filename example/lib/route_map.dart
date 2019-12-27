import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'page.dart';

class RouteMap extends Page {
  RouteMap() : super(const Icon(Icons.linear_scale), 'Map Route');

  @override
  Widget build(BuildContext context) {
    return _RouteMapScnene();
  }
}

class _RouteMapScnene extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _RouteMapScneneState();
  }
}

class _RouteMapScneneState extends State<_RouteMapScnene> {
  MapboxMapController controller;

  @override
  Widget build(BuildContext context) {
    return MapboxMapParent(
      controller: controller,
      child: MapboxMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(23.12076, 113.322058),
          zoom: 8.0,
        ),
        styleString: 'https://static.hyn.space/maptiles/see-it-all.json',
        onStyleLoaded: (mapboxController) {
          setState(() {
            controller = mapboxController;
          });
        },
        children: <Widget>[RouteMapPluginScene()],
      ),
    );
  }
}

class RouteMapPluginScene extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _RouteMapPluginSceneState();
  }
}

class _RouteMapPluginSceneState extends State<RouteMapPluginScene> {
  RouteDataModel model;

  Future<String> _fetchRoute(LatLng start, LatLng end) async {
    var url =
        'https://api.hyn.space/directions/v5/hyperion/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline6&language=en&steps=true&banner_instructions=true&voice_instructions=true&voice_units=metric&access_token=pk.hyn';
    var httpClient = new HttpClient();
    String result;
    try {
      var request = await httpClient.getUrl(Uri.parse(url));
      var response = await request.close();
      if (response.statusCode == HttpStatus.OK) {
        var responseBody = await response.transform(utf8.decoder).join();
        result = responseBody;
//        var data = jsonDecode(json);
//        result = data['origin'];
      } else {
        result = 'Error getting IP address:\nHttp status ${response.statusCode}';
      }
    } catch (exception) {
      result = 'Failed getting IP address';
    }

    // If the widget was removed from the tree while the message was in flight,
    // we want to discard the reply rather than calling setState to update our
    // non-existent appearance.
    if (!mounted) return null;

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 90,
      child: Stack(
        children: <Widget>[
          RoutePlugin(model: model),
          Container(
            child: Column(
              children: <Widget>[
                RaisedButton(
                    onPressed: () async {
                      var start = LatLng(23.12076, 113.322058);
                      var end = LatLng(23.135843, 113.326554);
                      var result = await _fetchRoute(start, end);
                      setState(() {
                        var padding = Random().nextInt(300);
                        model = RouteDataModel(
                            startLatLng: start,
                            endLatLng: end,
                            directionsResponse: result,
                            paddingTop: padding,
                            paddingLeft: padding,
                            paddingBottom: padding,
                            paddingRight: padding);
                      });
                    },
                    child: Text('fetch')),
                // todo: jison_test_navigation
                RaisedButton(
                  onPressed: () {
                    var start = LatLng(23.12076, 113.322058);
                    var end = LatLng(23.135843, 113.326554);
                    var result = model.directionsResponse;
                    var navigatonModel = NavigationDataModel(
                        startLatLng: start, endLatLng: end, directionsResponse: result, profile: "driving");
                    Navigation.navigation(context, navigatonModel);
                  },
                  child: Text("navigation"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
