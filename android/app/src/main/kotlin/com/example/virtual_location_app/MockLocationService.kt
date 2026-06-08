package com.example.virtual_location_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var mockLat: Double = 0.0
    private var mockLng: Double = 0.0

    private val updateRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val elapsed = SystemClock.elapsedRealtimeNanos()

            // Create fake location with high-quality GPS attributes
            val location = Location(LocationManager.GPS_PROVIDER).apply {
                latitude = mockLat
                longitude = mockLng
                altitude = 50.0
                accuracy = 3.0f   // 3 meters — looks like real GPS
                speed = 0.0f
                bearing = 0.0f
                time = now
                elapsedRealtimeNanos = elapsed
            }

            try {
                // Mock the GPS provider directly — this is what apps like DingTalk read
                locationManager.setTestProviderLocation(
                    LocationManager.GPS_PROVIDER,
                    location
                )
            } catch (_: SecurityException) {
                stopSelf()
                return
            } catch (_: Exception) {
                // Provider may not be available as test provider
            }

            // Also mock NETWORK provider as fallback
            try {
                val netLoc = Location(LocationManager.NETWORK_PROVIDER).apply {
                    latitude = mockLat
                    longitude = mockLng
                    altitude = 50.0
                    accuracy = 10.0f
                    speed = 0.0f
                    bearing = 0.0f
                    time = now
                    elapsedRealtimeNanos = elapsed
                }
                locationManager.setTestProviderLocation(
                    LocationManager.NETWORK_PROVIDER,
                    netLoc
                )
            } catch (_: Exception) {
                // Network provider may not be mockable
            }

            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        mockLat = intent?.getDoubleExtra(EXTRA_LATITUDE, 0.0) ?: 0.0
        mockLng = intent?.getDoubleExtra(EXTRA_LONGITUDE, 0.0) ?: 0.0

        val notification = buildNotification(mockLat, mockLng)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Try to enable test mode on GPS and network providers
        try {
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
        } catch (_: Exception) {
            // Provider might already be in test mode, or not mockable
        }
        try {
            locationManager.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, true)
        } catch (_: Exception) {
            // Provider might already be in test mode
        }

        handler.post(updateRunnable)
        isRunning = true

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        try {
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false)
        } catch (_: Exception) {}
        try {
            locationManager.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, false)
        } catch (_: Exception) {}
        stopForeground(STOP_FOREGROUND_REMOVE)
        isRunning = false
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "位置模拟服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "虚拟定位前台服务通知"
                setSound(null, null)
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(lat: Double, lng: Double) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("正在模拟位置")
            .setContentText("纬度: ${"%.6f".format(lat)}, 经度: ${"%.6f".format(lng)}")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    companion object {
        const val CHANNEL_ID = "location_mock_channel"
        const val NOTIFICATION_ID = 100
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        var isRunning = false
    }
}
