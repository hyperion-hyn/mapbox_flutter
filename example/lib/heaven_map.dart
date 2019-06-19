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
            styleString: 'https://static.hyn.space/maptiles/see-it-all.json',
            onStyleLoaded: (mapboxController) {
              setState(() {
                print('heaven style ready');
                controller = mapboxController;
              });
            },
            children: <Widget>[HeavenMapScene()],
          ),
        ),
      ],
    );
  }
}

class HeavenMapScene extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HeavenMapSceneState();
  }
}

class _HeavenMapSceneState extends State<HeavenMapScene> {
  List<HeavenDataModel> models = <HeavenDataModel>[
    HeavenDataModel(
        id: '1',
        sourceUrl: 'http://10.10.1.119:8080/maps/test/road/{z}/{x}/{y}.vector.pbf?auth=false',
        color: Colors.grey.value)
  ];

  //第二次只有 绑定了ui or 使用了相关的InheritedWidget 才会触发
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('heaven xxxx');
  }

  @override
  Widget build(BuildContext context) {
    print(MapboxMapParent.of(context).controller == null);
    return Stack(
      children: <Widget>[
        HeavenPlugin(models: models),
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
          child: Text('yy'),
        )
      ],
    );
  }
}
