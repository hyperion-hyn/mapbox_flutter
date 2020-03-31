part of mapbox_gl;

class HeavenPlugin extends StatefulWidget {
  final List<HeavenDataModel> models;

  HeavenPlugin({this.models});

  @override
  State<StatefulWidget> createState() {
    return _HeavenPluginState();
  }
}

class _HeavenPluginState extends State<HeavenPlugin> {
  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }

  Future<dynamic> _addModel(HeavenDataModel model) async {
    if (MapboxMapParent.of(context).controller != null) {
      //print('[mapbox_flutter] _addModel, controller not is null, ${model._toJson()}');
      var status = await MapboxMapParent.of(context)
          .controller
          .channel
          .invokeMethod("heaven_map#addData", <String, dynamic>{'model': model._toJson()});
      //print('[mapbox_flutter] _addModel, controller not is null, ${status}');

      return status;
    } else {
      //print('[mapbox_flutter] _addModel, controller is null');
    }
    return null;
  }

  Future<dynamic> _removeModel(String id) async {
    if (MapboxMapParent.of(context).controller != null) {
      return await MapboxMapParent.of(context)
          .controller
          .channel
          .invokeMethod("heaven_map#removeData", <String, String>{'id': id});
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MapboxMapParent.of(context).controller != null) {
      //如果没有引用 MapboxMapParent.of(context).controller ，第二次不会触发didChangeDependencies
      if (widget.models != null && widget.models.isNotEmpty) {
        updateOptions([], widget.models);
      }
    }
  }

  @override
  void didUpdateWidget(HeavenPlugin oldWidget) {
    super.didUpdateWidget(oldWidget);
    var deletedModels = _findDeletedModels(widget.models, oldWidget.models);
    var newAddModels = _findNewAddModels(widget.models, oldWidget.models);
    updateOptions(deletedModels, newAddModels);
  }

  void updateOptions(List<HeavenDataModel> deletedModels, List<HeavenDataModel> newAddModels) async {
    if (deletedModels.isNotEmpty) {
      for (var model in deletedModels) await _removeModel(model.id);
    }
    if (newAddModels.isNotEmpty) {
      for (var model in newAddModels) {
        await _addModel(model);
      }
    }
  }

  List<HeavenDataModel> _findDeletedModels(List<HeavenDataModel> newModels, List<HeavenDataModel> oldModels) {
    if (oldModels == null) {
      oldModels = [];
    }
    if (newModels == null) {
      newModels = [];
    }
    var retDeletedModels = <HeavenDataModel>[];
    for (var oldModel in oldModels) {
      var haveSame = false;
      for (var newModel in newModels) {
        if (oldModel.id == newModel.id) {
          haveSame = true;
          break;
        }
      }
      if (!haveSame) {
        retDeletedModels.add(oldModel);
      }
    }
    return retDeletedModels;
  }

  List<HeavenDataModel> _findNewAddModels(List<HeavenDataModel> newModels, List<HeavenDataModel> oldModels) {
    if (oldModels == null) {
      oldModels = [];
    }
    if (newModels == null) {
      newModels = [];
    }
    var retNewModels = <HeavenDataModel>[];
    for (var newModel in newModels) {
      var haveSame = false;
      for (var oldModel in oldModels) {
        if (oldModel.id == newModel.id) {
          haveSame = true;
          break;
        }
      }
      if (!haveSame) {
        retNewModels.add(newModel);
      }
    }
    return retNewModels;
  }
}

class HeavenDataModel {
  final String id;
  final String sourceUrl;
  final int color;
  final String sourceLayer;

  const HeavenDataModel({this.id, this.sourceUrl, this.color, this.sourceLayer});

  HeavenDataModel copyWith(HeavenDataModel changes) {
    if (changes == null) {
      return this;
    }
    return HeavenDataModel(
        id: changes.id ?? id,
        sourceUrl: changes.sourceUrl ?? sourceUrl,
        color: changes.color ?? color,
        sourceLayer: changes.sourceLayer ?? sourceLayer);
  }

  dynamic _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('id', id);
    addIfPresent('sourceUrl', sourceUrl);
    addIfPresent('color', color);
    addIfPresent('sourceLayer', sourceLayer);
    return json;
  }
}
