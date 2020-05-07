package com.mapbox.mapboxgl.plugins.route;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;
import android.location.GpsSatellite;
import android.location.GpsStatus;
import android.location.Location;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Parcelable;
import android.preference.PreferenceManager;
import android.speech.tts.TextToSpeech;
import android.util.Log;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.mapbox.api.directions.v5.DirectionsCriteria;
import com.mapbox.api.directions.v5.models.DirectionsRoute;
import com.mapbox.mapboxgl.R;
import com.mapbox.mapboxgl.plugins.route.tts.AndroidSpeechPlayer;
import com.mapbox.mapboxsdk.camera.CameraPosition;
import com.mapbox.mapboxsdk.location.modes.RenderMode;
import com.mapbox.services.android.navigation.ui.v5.MapOfflineOptions;
import com.mapbox.services.android.navigation.ui.v5.NavigationView;
import com.mapbox.services.android.navigation.ui.v5.NavigationViewOptions;
import com.mapbox.services.android.navigation.ui.v5.OnNavigationReadyCallback;
import com.mapbox.services.android.navigation.ui.v5.instruction.NavigationAlertView;
import com.mapbox.services.android.navigation.ui.v5.listeners.NavigationListener;
import com.mapbox.services.android.navigation.ui.v5.map.WayNameView;
import com.mapbox.services.android.navigation.ui.v5.utils.DelayFirstUtils;
import com.mapbox.services.android.navigation.ui.v5.voice.SpeechAnnouncement;
import com.mapbox.services.android.navigation.ui.v5.voice.SpeechPlayer;
import com.mapbox.services.android.navigation.v5.navigation.MapboxNavigationOptions;
import com.mapbox.services.android.navigation.v5.navigation.NavigationConstants;
import com.mapbox.services.android.navigation.v5.routeprogress.ProgressChangeListener;
import com.mapbox.services.android.navigation.v5.routeprogress.RouteProgress;
import com.mapbox.services.android.navigation.v5.utils.RouteUtils;


import java.util.Iterator;
import java.util.Locale;

import timber.log.Timber;

/**
 * Serves as a launching point for the custom drop-in UI, {@link NavigationView}.
 * <p>
 * Demonstrates the proper setup and usage of the view, including all lifecycle methods.
 */
public class NavigationActivity extends AppCompatActivity implements OnNavigationReadyCallback,
        NavigationListener, ProgressChangeListener {

    private NavigationView navigationView;

    private static final String COMPONENT_NAVIGATION_INSTRUCTION_CACHE = "hyn-component-navigation-instruction-cache";
    private static final long TEN_MEGABYTE_CACHE_SIZE = 10 * 1024 * 1024;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        setTheme(R.style.Theme_AppCompat_NoActionBar);
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_navigation);
        navigationView = findViewById(R.id.navigationView);
        navigationView.onCreate(savedInstanceState);
        initialize();
    }

    @Override
    public void onStart() {
        super.onStart();
        navigationView.onStart();
    }

    @Override
    public void onResume() {
        super.onResume();
        navigationView.onResume();
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        navigationView.onLowMemory();
    }

    @Override
    public void onBackPressed() {
        // If the navigation view didn't need to do anything, call super
        if (!navigationView.onBackPressed()) {
            super.onBackPressed();
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        navigationView.onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onRestoreInstanceState(Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);
        navigationView.onRestoreInstanceState(savedInstanceState);
    }

    @Override
    public void onPause() {
        super.onPause();
        navigationView.onPause();
    }

    @Override
    public void onStop() {
        super.onStop();
        navigationView.onStop();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        navigationView.onDestroy();
    }

    private SpeechPlayer speechPlayer = null;

    @Override
    public void onNavigationReady(boolean isRunning) {
        initSpeechPlayer();
        NavigationViewOptions.Builder options = NavigationViewOptions.builder();
        options.navigationListener(this);
        options.progressChangeListener(this);
        options.speechPlayer(speechPlayer);
        extractRoute(options);
        extractConfiguration(options);
        options.navigationOptions(MapboxNavigationOptions.builder().build());
        NavigationViewOptions navigationViewOptions = options.build();
        navigationView.startNavigation(navigationViewOptions);
        navigationView.findViewById(R.id.feedbackFab).setVisibility(View.GONE);
        NavigationAlertView navigationAlertView = navigationView.findViewById(R.id.alertView);
        navigationAlertView.updateEnabled(false);
        WayNameView wayNameView = navigationView.findViewById(R.id.wayNameView);
        TextView wayNameTextView = wayNameView.findViewById(R.id.waynameText);
        wayNameTextView.setVisibility(View.INVISIBLE);

        String profile = navigationViewOptions.directionsRoute().routeOptions().profile();
        if (profile.equals(DirectionsCriteria.PROFILE_CYCLING) || profile.equals(DirectionsCriteria.PROFILE_WALKING)) {
            navigationView.retrieveNavigationMapboxMap().updateLocationLayerRenderMode(RenderMode.COMPASS);
        } else {
            navigationView.retrieveNavigationMapboxMap().updateLocationLayerRenderMode(RenderMode.GPS);
        }
    }


    private LocationManager locationManager;

    @SuppressLint("MissingPermission")
    private void initLocationEngine() {
        locationManager = (LocationManager) getApplication().getSystemService(Context.LOCATION_SERVICE);
        locationManager.addGpsStatusListener(gpsStatusListener);
    }

    private boolean isNoticeGpsWeek = true;
    @SuppressLint("MissingPermission")
    private GpsStatus.Listener gpsStatusListener = new GpsStatus.Listener() {
        @Override
        public void onGpsStatusChanged(int event) {
            //卫星状态改变
            if (event == GpsStatus.GPS_EVENT_SATELLITE_STATUS) {
                Timber.i("卫星状态改变");
                //获取当前状态 
                GpsStatus gpsStatus = locationManager.getGpsStatus(null);
                //获取卫星颗数的默认最大值 
                int maxSatellites = gpsStatus.getMaxSatellites();
                //创建一个迭代器保存所有卫星  
                Iterator<GpsSatellite> iters = gpsStatus.getSatellites().iterator();
                int count = 0;
                while (iters.hasNext() && count <= maxSatellites) {
                    GpsSatellite s = iters.next();
                    if (s.getSnr() > 30) {
                        count++;
                    }
                }
                if (count >= 4) {
                    String message = "搜索到有效：" + count + "颗卫星";
                    Timber.i(message);
                    if (!isNoticeGpsWeek) {
                        SpeechAnnouncement speechAnnouncement = SpeechAnnouncement.builder().announcement(getString(R.string.gps_signal_resume)).build();
                        speechPlayer.play(speechAnnouncement);
                        isNoticeGpsWeek = true;
                    }
                } else {
                    if (isNoticeGpsWeek) {
                        SpeechAnnouncement speechAnnouncement = SpeechAnnouncement.builder().announcement(getString(R.string.gps_signal_weak)).build();
                        speechPlayer.play(speechAnnouncement);
                        isNoticeGpsWeek = false;
                    }
                }
            }
        }
    };


    private void initSpeechPlayer() {

        String language = Locale.getDefault().getLanguage();
        this.speechPlayer = new AndroidSpeechPlayer(this, language, status -> {
            if (status == TextToSpeech.SUCCESS) {
                playStartNavigationSpeech();
            }
        });
    }

    @Override
    public void onCancelNavigation() {
        finishNavigation();
    }

    @Override
    public void onNavigationFinished() {
        finishNavigation();
    }

    @Override
    public void onNavigationRunning() {
        // Intentionally empty
    }

    private void initialize() {
        Parcelable position = getIntent().getParcelableExtra(NavigationConstants.NAVIGATION_VIEW_INITIAL_MAP_POSITION);
        if (position != null) {
            navigationView.initialize(this, (CameraPosition) position);
        } else {
            navigationView.initialize(this);
        }
    }

    private void extractRoute(NavigationViewOptions.Builder options) {
        DirectionsRoute route = NavigationLauncher.extractRoute(this);
        options.directionsRoute(route);
    }

    private void extractConfiguration(NavigationViewOptions.Builder options) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);
        options.shouldSimulateRoute(preferences.getBoolean(NavigationConstants.NAVIGATION_VIEW_SIMULATE_ROUTE, false));
        String offlinePath = preferences.getString(NavigationConstants.OFFLINE_PATH_KEY, "");
        if (!offlinePath.isEmpty()) {
            options.offlineRoutingTilesPath(offlinePath);
        }
        String offlineVersion = preferences.getString(NavigationConstants.OFFLINE_VERSION_KEY, "");
        if (!offlineVersion.isEmpty()) {
            options.offlineRoutingTilesVersion(offlineVersion);
        }
        String offlineMapDatabasePath = preferences.getString(NavigationConstants.MAP_DATABASE_PATH_KEY, "");
        String offlineMapStyleUrl = preferences.getString(NavigationConstants.MAP_STYLE_URL_KEY, "");
        if (!offlineMapDatabasePath.isEmpty() && !offlineMapStyleUrl.isEmpty()) {
            MapOfflineOptions mapOfflineOptions = new MapOfflineOptions(offlineMapDatabasePath, offlineMapStyleUrl);
            options.offlineMapOptions(mapOfflineOptions);
        }
    }

    private void finishNavigation() {
        NavigationLauncher.cleanUpPreferences(this);
        if (locationManager != null) {
            locationManager.removeGpsStatusListener(gpsStatusListener);
        }
        finish();
    }

    private RouteUtils routeUtils = new RouteUtils();

    private DelayFirstUtils delayFirstUtils = new DelayFirstUtils(new Runnable() {
        @Override
        public void run() {
            finishNavigation();
        }
    }, 8 * 1000);

    @Override
    public void onProgressChange(Location location, RouteProgress routeProgress) {
        if (routeUtils.isArrivalEvent(routeProgress) && routeUtils.isLastLeg(routeProgress)) {
            delayFirstUtils.addEvent();
        }
    }

    private void playStartNavigationSpeech() {
        String startNavigation = getIntent().getStringExtra("startNavigationTips");
        SpeechAnnouncement speechAnnouncement = SpeechAnnouncement.builder().announcement(startNavigation.isEmpty() ? getString(R.string.start_navigation) : startNavigation).build();
        speechPlayer.play(speechAnnouncement);
    }

//    private BaiduSpeechPlayer.StateCallBack stateCallBack = new BaiduSpeechPlayer.StateCallBack() {
//        @Override
//        public void onInit() {
//            playStartNavigationSpeech();
//        }
//
//        @Override
//        public void onRelease() {
//
//        }
//    };
}
