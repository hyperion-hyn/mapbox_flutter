import 'page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'global.dart';

class IosMapPage extends Page {
  IosMapPage() : super(const Icon(Icons.tablet_mac), 'IOS Map');

  @override
  Widget build(BuildContext context) {
    return IosMapScene();
  }
}

class IosMapScene extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _IosMapSceneState();
  }
}

class _IosMapSceneState extends State<IosMapScene> {
  MapboxMapController controller;

  CompassMargins compassMargins;
  bool enableLogo;
  bool enableAttribute;

  String mapStyle = 'https://static.hyn.space/maptiles/see-it-all-zh.json';
  var myLocationTrackingMode = MyLocationTrackingMode.None;

  void _onStyleLoaded() {
    logger.i('on style loaded');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapboxMapParent(
          controller: controller,
          child: MapboxMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(35.6803997, 139.7690174),
              zoom: 8.0,
            ),
            onStyleLoadedCallback: _onStyleLoaded,
            onMapCreated: (c) {
              print('on map loaded');
              controller = c;
            },
            styleString: mapStyle,
            myLocationEnabled: true,
            myLocationTrackingMode: myLocationTrackingMode,
            enableAttribution: enableAttribute,
            enableLogo: enableLogo,
            compassMargins: compassMargins,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: RaisedButton(
            onPressed: () {
              setState(() {
//                mapStyle = 'https://static.hyn.space/maptiles/see-it-all-en.json';
                compassMargins = CompassMargins(left: 0, top: 80, right: 16, bottom: 0);
                enableLogo = false;
                enableAttribute = false;
              });
            },
            child: Text('chagne style'),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  myLocationTrackingMode = MyLocationTrackingMode.Tracking;
                });
              },
              mini: true,
              child: Icon(Icons.location_city),
            ),
          ),
        ),
      ],
    );
  }
}
