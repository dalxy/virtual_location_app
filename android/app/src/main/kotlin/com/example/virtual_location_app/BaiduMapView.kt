package com.example.virtual_location_app

import android.content.Context
import android.os.Bundle
import android.view.View
import com.baidu.mapapi.map.*
import com.baidu.mapapi.model.LatLng
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class BaiduMapView(
    context: Context,
    viewId: Int,
    creationParams: Map<String?, Any?>?,
    private val methodChannel: MethodChannel
) : PlatformView {

    private val mapView: MapView
    private var baiduMap: BaiduMap? = null

    init {
        mapView = MapView(context)
        mapView.onCreate(context, Bundle())
        setupMap(creationParams)
    }

    private fun setupMap(creationParams: Map<String?, Any?>?) {
        baiduMap = mapView.map
        baiduMap?.let { bMap ->
            bMap.mapType = BaiduMap.MAP_TYPE_NORMAL
            bMap.isTrafficEnabled = false

            val ui = bMap.uiSettings
            ui.isZoomGesturesEnabled = true
            ui.isScrollGesturesEnabled = true
            ui.isRotateGesturesEnabled = false
            ui.isOverlookingGesturesEnabled = false
            ui.isCompassEnabled = false

            // Tap → center map at tapped point
            bMap.setOnMapClickListener(object : BaiduMap.OnMapClickListener {
                override fun onMapClick(point: LatLng) {
                    bMap.setMapStatus(MapStatusUpdateFactory.newLatLng(point))
                    methodChannel.invokeMethod("onMapClick", mapOf(
                        "latitude" to point.latitude,
                        "longitude" to point.longitude
                    ))
                }
                override fun onMapPoiClick(poi: MapPoi?) {}
            })

            // Drag → report new center
            bMap.setOnMapStatusChangeListener(object : BaiduMap.OnMapStatusChangeListener {
                override fun onMapStatusChangeStart(status: MapStatus) {}
                override fun onMapStatusChangeStart(status: MapStatus, reason: Int) {}
                override fun onMapStatusChange(status: MapStatus) {}
                override fun onMapStatusChangeFinish(status: MapStatus) {
                    val center = status.target
                    methodChannel.invokeMethod("onMapMoveEnd", mapOf(
                        "latitude" to center.latitude,
                        "longitude" to center.longitude
                    ))
                }
            })

            // Initial position
            val lat = (creationParams?.get("latitude") as? Number)?.toDouble()
            val lng = (creationParams?.get("longitude") as? Number)?.toDouble()
            if (lat != null && lng != null) {
                bMap.setMapStatus(MapStatusUpdateFactory.newLatLngZoom(LatLng(lat, lng), 18f))
            }

            methodChannel.invokeMethod("onMapReady", null)
        }
    }

    override fun getView(): View = mapView

    override fun dispose() {
        mapView.onDestroy()
    }

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val bMap = baiduMap ?: return result.error("NOT_READY", "Map not ready", null)
        when (call.method) {
            "setCenter" -> {
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                if (lat == null || lng == null) return result.error("ARGS", "lat/lng required", null)
                bMap.setMapStatus(MapStatusUpdateFactory.newLatLngZoom(LatLng(lat, lng), 18f))
                result.success(null)
            }
            "getCenter" -> {
                val center = bMap.mapStatus.target
                result.success(mapOf("latitude" to center.latitude, "longitude" to center.longitude))
            }
            else -> result.notImplemented()
        }
    }
}
