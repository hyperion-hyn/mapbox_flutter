part of mapbox_gl;

class MapboxMapParent extends InheritedWidget {
  final MapboxMapController controller;

  final Widget child;

  MapboxMapParent({Key key, @required this.child, this.controller});

  static MapboxMapParent of(BuildContext context) => context.inheritFromWidgetOfExactType(MapboxMapParent);

  @override
  bool updateShouldNotify(MapboxMapParent oldWidget) {
    return controller != oldWidget.controller;
  }

}