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
    private var marker: Marker? = null

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

            bMap.setOnMapClickListener(object : BaiduMap.OnMapClickListener {
                override fun onMapClick(point: LatLng) {
                    methodChannel.invokeMethod("onMapClick", mapOf(
                        "latitude" to point.latitude,
                        "longitude" to point.longitude
                    ))
                }

                override fun onMapPoiClick(poi: MapPoi?) {}
            })

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

            // Apply initial position
            val lat = (creationParams?.get("latitude") as? Number)?.toDouble()
            val lng = (creationParams?.get("longitude") as? Number)?.toDouble()
            if (lat != null && lng != null) {
                val target = LatLng(lat, lng)
                bMap.setMapStatus(MapStatusUpdateFactory.newLatLngZoom(target, 18f))
                addMarker(target)
            }

            methodChannel.invokeMethod("onMapReady", null)
        }
    }

    override fun getView(): View = mapView

    override fun dispose() {
        marker?.remove()
        mapView.onDestroy()
    }

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val bMap = baiduMap ?: return result.error("NOT_READY", "Map not ready", null)
        when (call.method) {
            "setCenter" -> {
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                if (lat == null || lng == null) return result.error("ARGS", "lat/lng required", null)
                val point = LatLng(lat, lng)
                bMap.setMapStatus(MapStatusUpdateFactory.newLatLngZoom(point, 18f))
                addMarker(point)
                result.success(null)
            }
            "getCenter" -> {
                val center = bMap.mapStatus.target
                result.success(mapOf("latitude" to center.latitude, "longitude" to center.longitude))
            }
            "setMarker" -> {
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                if (lat == null || lng == null) return result.error("ARGS", "lat/lng required", null)
                addMarker(LatLng(lat, lng))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun addMarker(point: LatLng) {
        marker?.remove()
        val opt = MarkerOptions()
            .position(point)
            .icon(BitmapDescriptorFactory.fromResource(android.R.drawable.ic_menu_mylocation))
            .anchor(0.5f, 1.0f)
            .zIndex(99)
        marker = baiduMap?.addOverlay(opt) as? Marker
    }
}
