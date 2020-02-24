import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'dart:convert';

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
  CompassMargins compassMargins;
  bool enableLogo;
  bool enableAttribute;

  var layerId = "layer-heaven-1";

  var showingMarker;

  void _mapClick(point, latLng) async {
    print("${point.x},${point.y}   ${latLng.latitude}/${latLng.longitude}");

    var range = 10;
    Rect rect = Rect.fromLTRB(point.x - range, point.y + range, point.x + range, point.y - range);

    List features = await controller.queryRenderedFeaturesInRect(rect, [layerId], null);
    if (features.length > 0) {
      print(features[0]);
      if (showingMarker != null) {
        removeSymbol(showingMarker);
        showingMarker = null;
      }
      var clickFeatureJsonString = features[0];
      var clickFeatureJson = json.decode(clickFeatureJsonString);

      var coordinates = clickFeatureJson["geometry"]["coordinates"];

      var lon = coordinates[0];
      var lat = coordinates[1];

      showingMarker = await _addSymbol(new LatLng(lat, lon));

      setState(() {});
    } else {
      removeSymbol(showingMarker);
      showingMarker = null;
    }
  }

  Future<Symbol> _addSymbol(LatLng center) {
    return controller.addSymbol(
      SymbolOptions(
          geometry: center, iconImage: "hyn-marker-image", iconAnchor: "bottom", iconOffset: Offset(0.0, 3.0)),
    );
  }

  void removeSymbol(Symbol symbol) {
    controller.removeSymbol(symbol);
  }

  var heavenDataModels = <HeavenDataModel>[
    HeavenDataModel(
      id: 'c1b7c5102eca43029f0416892447e0ed',
      sourceLayer: 'embassy',
      sourceUrl: "https://store.tile.map3.network/maps/global/embassy/{z}/{x}/{y}.vector.pbf",
      color: 0xff59B45F,
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapboxMapParent(
          controller: controller,
          child: MapboxMap(
            enableAttribution: enableAttribute,
            enableLogo: enableLogo,
            compassMargins: compassMargins,
            initialCameraPosition: const CameraPosition(
              target: LatLng(35.6803997, 139.7690174),
              zoom: 8.0,
            ),
            styleString: 'https://static.hyn.space/maptiles/see-it-all.json',
            onStyleLoadedCallback: () {
              setState(() {
                print('heaven style ready');
              });
            },
            onMapCreated: (c) {
              controller = c;
            },
            onMapClick: _mapClick,
//            children: <Widget>[HeavenPlugin(models: heavenDataModels)],
            children: <Widget>[HeavenMapScene()],
          ),
        ),
        Positioned(
          top: 80,
          child: RaisedButton(
              onPressed: () {
                setState(() {
                  compassMargins = CompassMargins(left: 0, top: 80, right: 16, bottom: 0);
                  enableLogo = true;
                  enableAttribute = true;
                });
              },
              child: Text('update map options')),
        )
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
          child: Text('change heaven data'),
        )
      ],
    );
  }
}
