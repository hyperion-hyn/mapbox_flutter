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
    print('heaven build ${widget.models?.length}, ${MapboxMapParent.of(context).controller}');
    return Text('heaven ${MapboxMapParent.of(context).controller?.toString()}');
//    return SizedBox.shrink();
  }

  Future<dynamic> _addModel(HeavenDataModel model) async {
    if(MapboxMapParent.of(context).controller != null) {
      return await MapboxMapParent.of(context).controller.channel.invokeMethod("heaven_map#addData", <String, dynamic>{'model': model._toJson()});
    }
    return null;
  }

  Future<dynamic> _removeModel(String id) async {
    if(MapboxMapParent.of(context).controller != null) {
      return await MapboxMapParent.of(context).controller.channel.invokeMethod("heaven_map#removeData", <String, String>{'id': id});
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    print('heaven initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('heaven didChangeDependencies 111 ${widget.models?.length} ${MapboxMapParent.of(context).controller}');
    if(MapboxMapParent.of(context).controller != null) {  //如果没有引用 MapboxMapParent.of(context).controller ，第二次不会触发didChangeDependencies
      print('heaven didChangeDependencies 222 ${widget.models?.length}');
      if(widget.models != null && widget.models.isNotEmpty) {
        updateOptions([], widget.models);
      }
    }
  }

  @override
  void didUpdateWidget(HeavenPlugin oldWidget) {
    super.didUpdateWidget(oldWidget);
    var deletedModels = _findDeletedModels(widget.models, oldWidget.models);
    var newAddModels = _findNewAddModels(widget.models, oldWidget.models);
    print('heaven didUpdateWidget ${deletedModels.length} ${newAddModels.length}');
    updateOptions(deletedModels, newAddModels);
  }

  void updateOptions(List<HeavenDataModel> deletedModels, List<HeavenDataModel> newAddModels) async {
    print('heaven updateOptions ${deletedModels.length} ${newAddModels.length}');
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
    if(oldModels == null) {
      oldModels = [];
    }
    if(newModels == null) {
      newModels = [];
    }
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
    if(oldModels == null) {
      oldModels = [];
    }
    if(newModels == null) {
      newModels = [];
    }
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