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
  var models = <HeavenDataModel>[
    HeavenDataModel(
        id: '1',
        sourceUrl: 'http://10.10.1.119:8080/maps/test/road/{z}/{x}/{y}.vector.pbf?auth=false',
        color: Colors.blue.value)
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapboxMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(35.6803997, 139.7690174),
            zoom: 8.0,
          ),
          styleString: 'https://static.hyn.space/maptiles/see-it-all.json',
          plugins: <Widget>[HeavenPlugin(models: models)],
        ),
        RaisedButton(
          onPressed: () {
            setState(() {
              models = <HeavenDataModel>[
                HeavenDataModel(
                    id: '2',
                    sourceUrl: 'http://10.10.1.119:8080/maps/test/road/{z}/{x}/{y}.vector.pbf?auth=false',
                    color: Colors.red.value)
              ];
            });
          },
          child: Text('ttt'),
        )
      ],
    );
  }
}
