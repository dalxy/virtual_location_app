package com.example.virtual_location_app

import android.content.Context
import android.content.Intent
import android.location.Criteria
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object MockLocationPlugin {

    private const val CHANNEL_NAME = "com.example.virtual_location_app/location_mock"
    private const val CHECK_PROVIDER = "__virtual_check__"
    private var context: Context? = null

    fun register(flutterEngine: FlutterEngine, ctx: Context) {
        context = ctx.applicationContext
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMock" -> handleStartMock(call, result)
                "stopMock" -> handleStopMock(result)
                "isMocking" -> handleIsMocking(result)
                "checkMockPermission" -> handleCheckMockPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleStartMock(call: MethodCall, result: MethodChannel.Result) {
        val lat = call.argument<Double>("latitude")
        val lng = call.argument<Double>("longitude")

        if (lat == null || lng == null) {
            result.error("INVALID_ARGS", "Latitude and longitude are required", null)
            return
        }
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            result.error("INVALID_COORDS", "Coordinates out of valid range", null)
            return
        }

        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Plugin not initialized", null)
            return
        }

        // Quick check: try to add a test provider to verify mock permission
        val locationManager = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.addTestProvider(
                CHECK_PROVIDER, false, false, false, false,
                true, true, true, Criteria.POWER_LOW, Criteria.ACCURACY_FINE
            )
            locationManager.removeTestProvider(CHECK_PROVIDER)
        } catch (_: SecurityException) {
            result.error(
                "MOCK_PERMISSION_NOT_GRANTED",
                "请在 开发者选项 → 选择模拟位置信息应用 中选中本应用",
                null
            )
            return
        }

        val intent = Intent(ctx, MockLocationService::class.java).apply {
            putExtra(MockLocationService.EXTRA_LATITUDE, lat)
            putExtra(MockLocationService.EXTRA_LONGITUDE, lng)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(ctx, intent)
        } else {
            ctx.startService(intent)
        }

        result.success(true)
    }

    private fun handleStopMock(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Plugin not initialized", null)
            return
        }
        val intent = Intent(ctx, MockLocationService::class.java)
        ctx.stopService(intent)
        result.success(true)
    }

    private fun handleIsMocking(result: MethodChannel.Result) {
        result.success(MockLocationService.isRunning)
    }

    private fun handleCheckMockPermission(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Plugin not initialized", null)
            return
        }
        val locationManager = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val map = try {
            locationManager.addTestProvider(
                CHECK_PROVIDER, false, false, false, false,
                true, true, true, Criteria.POWER_LOW, Criteria.ACCURACY_FINE
            )
            locationManager.removeTestProvider(CHECK_PROVIDER)
            hashMapOf<String, Any>(
                "isMockLocationGloballyEnabled" to true,
                "isAppDesignatedAsMockApp" to true,
                "message" to "模拟定位权限已就绪"
            )
        } catch (_: SecurityException) {
            hashMapOf<String, Any>(
                "isMockLocationGloballyEnabled" to false,
                "isAppDesignatedAsMockApp" to false,
                "message" to "请先开启 开发者选项 → 选择模拟位置信息应用 → 选择「虚拟定位」"
            )
        } catch (e: Exception) {
            hashMapOf<String, Any>(
                "isMockLocationGloballyEnabled" to false,
                "isAppDesignatedAsMockApp" to false,
                "message" to "无法检查模拟定位权限: ${e.message}"
            )
        }
        result.success(map)
    }
}
