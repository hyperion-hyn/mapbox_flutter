package com.mapbox.mapboxgl;

import static io.flutter.plugin.common.PluginRegistry.Registrar;

import android.content.Context;
import android.util.Log;

import com.mapbox.mapboxgl.plugins.MapPluginsManager;
import com.mapbox.mapboxgl.plugins.heaven.HeavenMapBuilder;
import com.mapbox.mapboxgl.plugins.route.MapRouteBuilder;
import com.mapbox.mapboxsdk.camera.CameraPosition;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

public class MapboxMapFactory extends PlatformViewFactory {

  private final AtomicInteger mActivityState;
  private final Registrar mPluginRegistrar;

  public MapboxMapFactory(AtomicInteger state, Registrar registrar) {
    super(StandardMessageCodec.INSTANCE);
    mActivityState = state;
    mPluginRegistrar = registrar;
  }

  @Override
  public PlatformView create(Context context, int id, Object args) {
    Log.i("MapboxMapFactory", "create PlatformView " + id);
    Map<String, Object> params = (Map<String, Object>) args;
    final MapboxMapBuilder builder = new MapboxMapBuilder();

    Convert.interpretMapboxMapOptions(params.get("options"), builder);
    if (params.containsKey("initialCameraPosition")) {
      CameraPosition position = Convert.toCameraPosition(params.get("initialCameraPosition"));
      builder.setInitialCameraPosition(position);
    }
    //register plugins
    MapPluginsManager.INSTANCE.registerBuilder(new HeavenMapBuilder().interpretOptions(params.get("plugins-options")));
    MapPluginsManager.INSTANCE.registerBuilder(new MapRouteBuilder().interpretOptions(params.get("plugins-options")));
    MapPluginsManager.INSTANCE.buildPlugins();
    return builder.build(id, context, mActivityState, mPluginRegistrar);
  }
}
