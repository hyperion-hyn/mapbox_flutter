part of mapbox_gl;

mixin MapPluginMixin {
  final Completer<MapboxMapController> _controller = Completer<MapboxMapController>();

  void onMapReady(MapboxMapController controller) {
    _controller.complete(controller);
  }

  String getName();
}