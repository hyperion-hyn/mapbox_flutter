part of mapbox_gl;

class HeavenPlugin extends StatefulWidget with MapPluginMixin {

  final List<HeavenDataModel> models;

  HeavenPlugin({this.models});

  @override
  State<StatefulWidget> createState() {
    return _HeavenPluginState();
  }

  @override
  String getName() {
    return 'heaven_map';
  }
}

class _HeavenPluginState extends State<HeavenPlugin> {
  MapboxMapController _controller;
  
  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }

  Future<dynamic> _addModel(HeavenDataModel model) async {
    return await _controller._channel.invokeMethod("${widget.getName()}#addData", <String, dynamic>{'model': model._toJson()});
  }

  Future<dynamic> _removeModel(String id) async {
    return await _controller._channel.invokeMethod("${widget.getName()}#removeData", <String, String>{'id': id});
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }
  
  void _initController() async {
    _controller = await widget._controller.future;
    for(var model in widget.models) {
      _addModel(model);
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
    if(deletedModels.isNotEmpty) {
      for(var model in deletedModels)
        await _removeModel(model.id);
    }
    if(newAddModels.isNotEmpty) {
      for(var model in newAddModels) {
        await _addModel(model);
      }
    }
  }

  List<HeavenDataModel> _findDeletedModels(List<HeavenDataModel> newModels, List<HeavenDataModel> oldModels) {
    var retDeletedModels = <HeavenDataModel>[];
    for(var oldModel in oldModels) {
      var haveSame = false;
      for(var newModel in newModels) {
        if(oldModel.id == newModel.id) {
          haveSame = true;
          break;
        }
      }
      if(!haveSame) {
        retDeletedModels.add(oldModel);
      }
    }
    return retDeletedModels;
  }

  List<HeavenDataModel> _findNewAddModels(List<HeavenDataModel> newModels, List<HeavenDataModel> oldModels) {
    var retNewModels = <HeavenDataModel>[];
    for(var newModel in newModels) {
      var haveSame = false;
      for(var oldModel in oldModels) {
        if(oldModel.id == newModel.id) {
          haveSame = true;
          break;
        }
      }
      if(!haveSame) {
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

  const HeavenDataModel({this.id, this.sourceUrl, this.color});

  HeavenDataModel copyWith(HeavenDataModel changes) {
    if(changes == null) {
      return this;
    }
    return HeavenDataModel(
      id: changes.id ?? id,
      sourceUrl: changes.sourceUrl ?? sourceUrl,
      color: changes.color ?? color
    );
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
    return json;
  }
}