import 'page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

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
            onStyleLoaded: (c) {
              setState(() {
                
                controller = c;
              });
            },
          ),
        )
      ],
    );
  }
}
