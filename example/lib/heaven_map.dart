import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'page.dart';

class HeavenMap extends Page {
  HeavenMap() : super(const Icon(Icons.airline_seat_legroom_extra), 'Heaven Map');

  @override
  Widget build(BuildContext context) {
    return _HeavenMapPage();
  }
}

class _HeavenMapPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HeavenMapPageState();
  }
}

class _HeavenMapPageState extends State<_HeavenMapPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapboxMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(23.122592, 113.327356),
              zoom: 11.0,
            ),
            styleString: 'https://static.hyn.space/maptiles/see-it-all.json')
      ],
    );
  }
}
