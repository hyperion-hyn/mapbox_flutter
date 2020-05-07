package com.mapbox.mapboxgl.plugins.route;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.Log;

import com.mapbox.api.directions.v5.models.DirectionsRoute;
import com.mapbox.services.android.navigation.ui.v5.NavigationLauncherOptions;
import com.mapbox.services.android.navigation.v5.navigation.NavigationConstants;

import static android.content.Intent.FLAG_ACTIVITY_NEW_TASK;


public class NavigationLauncher {

    public static void startNavigation(Context context, NavigationLauncherOptions options, String startNavigationTips) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        SharedPreferences.Editor editor = preferences.edit();

        storeDirectionsRouteValue(options, editor);
        storeConfiguration(options, editor);

        storeThemePreferences(options, editor);
        storeOfflinePath(options, editor);
        storeOfflineVersion(options, editor);

        editor.apply();

        Intent navigationActivity = new Intent(context, NavigationActivity.class);
        if (!(context instanceof Activity)) {
            navigationActivity.addFlags(FLAG_ACTIVITY_NEW_TASK);
        }
        storeInitialMapPosition(options, navigationActivity);
        navigationActivity.putExtra("startNavigationTips",startNavigationTips);
        context.startActivity(navigationActivity);
    }


    static DirectionsRoute extractRoute(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String directionsRouteJson = preferences.getString(NavigationConstants.NAVIGATION_VIEW_ROUTE_KEY, "");
        return DirectionsRoute.fromJson(directionsRouteJson);
    }

    static void cleanUpPreferences(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        SharedPreferences.Editor editor = preferences.edit();
        editor
                .remove(NavigationConstants.NAVIGATION_VIEW_ROUTE_KEY)
                .remove(NavigationConstants.NAVIGATION_VIEW_SIMULATE_ROUTE)
                .remove(NavigationConstants.NAVIGATION_VIEW_PREFERENCE_SET_THEME)
                .remove(NavigationConstants.NAVIGATION_VIEW_PREFERENCE_SET_THEME)
                .remove(NavigationConstants.NAVIGATION_VIEW_LIGHT_THEME)
                .remove(NavigationConstants.NAVIGATION_VIEW_DARK_THEME)
                .remove(NavigationConstants.OFFLINE_PATH_KEY)
                .remove(NavigationConstants.OFFLINE_VERSION_KEY)
                .apply();
    }

    private static void storeDirectionsRouteValue(NavigationLauncherOptions options, SharedPreferences.Editor editor) {
        editor.putString(NavigationConstants.NAVIGATION_VIEW_ROUTE_KEY, options.directionsRoute().toJson());
    }

    private static void storeConfiguration(NavigationLauncherOptions options, SharedPreferences.Editor editor) {
        editor.putBoolean(NavigationConstants.NAVIGATION_VIEW_SIMULATE_ROUTE, options.shouldSimulateRoute());
    }

    private static void storeThemePreferences(NavigationLauncherOptions options, SharedPreferences.Editor editor) {
        boolean preferenceThemeSet = options.lightThemeResId() != null || options.darkThemeResId() != null;
        editor.putBoolean(NavigationConstants.NAVIGATION_VIEW_PREFERENCE_SET_THEME, preferenceThemeSet);

        if (preferenceThemeSet) {
            if (options.lightThemeResId() != null) {
                editor.putInt(NavigationConstants.NAVIGATION_VIEW_LIGHT_THEME, options.lightThemeResId());
            }
            if (options.darkThemeResId() != null) {
                editor.putInt(NavigationConstants.NAVIGATION_VIEW_DARK_THEME, options.darkThemeResId());
            }
        }
    }

    private static void storeInitialMapPosition(NavigationLauncherOptions options, Intent navigationActivity) {
        if (options.initialMapCameraPosition() != null) {
            navigationActivity.putExtra(
                    NavigationConstants.NAVIGATION_VIEW_INITIAL_MAP_POSITION, options.initialMapCameraPosition()
            );
        }
    }

    private static void storeOfflinePath(NavigationLauncherOptions options, SharedPreferences.Editor editor) {
        editor.putString(NavigationConstants.OFFLINE_PATH_KEY, options.offlineRoutingTilesPath());
    }

    private static void storeOfflineVersion(NavigationLauncherOptions options, SharedPreferences.Editor editor) {
        editor.putString(NavigationConstants.OFFLINE_VERSION_KEY, options.offlineRoutingTilesVersion());
    }

}
