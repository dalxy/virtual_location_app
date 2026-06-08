package com.example.virtual_location_app

import android.os.Bundle
import com.baidu.mapapi.SDKInitializer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // MUST be called before super.onCreate() and before any MapView
        SDKInitializer.setAgreePrivacy(applicationContext, true)
        SDKInitializer.initialize(applicationContext)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MockLocationPlugin.register(flutterEngine, this)

        // Register Baidu Map platform view
        flutterEngine.platformViewsController.registry
            .registerViewFactory("baidu_map", BaiduMapViewFactory(flutterEngine.dartExecutor.binaryMessenger))
    }
}
