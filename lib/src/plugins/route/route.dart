part of mapbox_gl;

class RoutePlugin extends StatefulWidget {
  final RouteDataModel model;

  RoutePlugin({this.model});

  @override
  State<StatefulWidget> createState() {
    return _RoutePluginState();
  }
}

class _RoutePluginState extends State<RoutePlugin> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MapboxMapParent.of(context).controller != null) {
      if (widget.model != null) {
        _addRouteOverlay(widget.model);
      }
    }
  }

  @override
  void didUpdateWidget(RoutePlugin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model == null && oldWidget.model != null) {
      _removeRouteOverlay();
    } else if (widget.model != null && widget.model != oldWidget.model) {
      _addRouteOverlay(widget.model);
    }
  }

  void _addRouteOverlay(RouteDataModel model) async {
    await _removeRouteOverlay();
    var channel = MapboxMapParent.of(context)?.controller?.channel;
    channel.invokeMethod('map_route#addRouteOverlay', <String, dynamic>{'model': model._toJson()});
  }

  Future<dynamic> _removeRouteOverlay() async {
    var channel = MapboxMapParent.of(context)?.controller?.channel;
    return channel?.invokeMethod("map_route#removeRouteOverlay");
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
    ;
  }
}

class RouteDataModel {
  final LatLng startLatLng;
  final LatLng endLatLng;
  final String directionsResponse;
  final int paddingTop;
  final int paddingLeft;
  final int paddingRight;
  final int paddingBottom;

  RouteDataModel(
      {this.startLatLng,
      this.endLatLng,
      this.directionsResponse,
      this.paddingTop,
      this.paddingLeft,
      this.paddingRight,
      this.paddingBottom});

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
    addIfPresent('paddingTop', paddingTop);
    addIfPresent('paddingLeft', paddingLeft);
    addIfPresent('paddingRight', paddingRight);
    addIfPresent('paddingBottom', paddingBottom);

    return json;
  }
}
