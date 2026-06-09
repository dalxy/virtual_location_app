package com.example.virtual_location_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import kotlin.random.Random

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var mockLat: Double = 0.0
    private var mockLng: Double = 0.0
    private val rng = Random(System.currentTimeMillis())

    private val updateRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val elapsed = SystemClock.elapsedRealtimeNanos()

            // Tiny random jitter to look more realistic (sub-meter)
            val jitterLat = mockLat + (rng.nextDouble() - 0.5) * 0.00002
            val jitterLng = mockLng + (rng.nextDouble() - 0.5) * 0.00002

            // 1. Update our test provider (works on all devices, visible to other apps)
            try {
                val loc = Location(TEST_PROVIDER).apply {
                    latitude = jitterLat
                    longitude = jitterLng
                    altitude = 50.0 + rng.nextDouble() * 2
                    accuracy = 3.0f + rng.nextFloat()
                    speed = 0.5f + rng.nextFloat() * 0.5f
                    bearing = rng.nextFloat() * 360f
                    time = now
                    elapsedRealtimeNanos = elapsed
                }
                locationManager.setTestProviderLocation(TEST_PROVIDER, loc)
            } catch (_: SecurityException) {
                stopSelf(); return
            } catch (_: Exception) {}

            // 2. Also try GPS provider (works on some devices/ROMs)
            try {
                val gpsLoc = Location(LocationManager.GPS_PROVIDER).apply {
                    latitude = jitterLat
                    longitude = jitterLng
                    altitude = 50.0 + rng.nextDouble() * 2
                    accuracy = 3.0f + rng.nextFloat()
                    speed = 0.5f + rng.nextFloat() * 0.5f
                    bearing = rng.nextFloat() * 360f
                    time = now
                    elapsedRealtimeNanos = elapsed
                }
                locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, gpsLoc)
            } catch (_: Exception) {}

            // 3. Also try NETWORK provider
            try {
                val netLoc = Location(LocationManager.NETWORK_PROVIDER).apply {
                    latitude = jitterLat
                    longitude = jitterLng
                    altitude = 50.0
                    accuracy = 8.0f + rng.nextFloat() * 3
                    speed = 0.3f
                    bearing = rng.nextFloat() * 360f
                    time = now
                    elapsedRealtimeNanos = elapsed
                }
                locationManager.setTestProviderLocation(LocationManager.NETWORK_PROVIDER, netLoc)
            } catch (_: Exception) {}

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
        lastMockLat = mockLat
        lastMockLng = mockLng

        val notification = buildNotification(mockLat, mockLng)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Step 1: Add test provider (works everywhere)
        try {
            locationManager.addTestProvider(
                TEST_PROVIDER,
                false,  // requiresNetwork
                false,  // requiresSatellite
                false,  // requiresCell
                false,  // hasMonetaryCost
                true,   // supportsAltitude
                true,   // supportsSpeed
                true,   // supportsBearing
                Criteria.POWER_HIGH,
                Criteria.ACCURACY_FINE
            )
        } catch (_: IllegalArgumentException) {
            // Already exists from previous run — remove and re-add
            try { locationManager.removeTestProvider(TEST_PROVIDER) } catch (_: Exception) {}
            try {
                locationManager.addTestProvider(
                    TEST_PROVIDER, false, false, false, false,
                    true, true, true, Criteria.POWER_HIGH, Criteria.ACCURACY_FINE
                )
            } catch (_: Exception) {}
        }

        // Step 2: Enable test provider
        try {
            locationManager.setTestProviderEnabled(TEST_PROVIDER, true)
        } catch (_: SecurityException) {
            stopSelf(); return START_NOT_STICKY
        }

        // Step 3: Also try to enable test mode on real providers
        try { locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true) } catch (_: Exception) {}
        try { locationManager.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, true) } catch (_: Exception) {}

        handler.post(updateRunnable)
        isRunning = true

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)

        try { locationManager.setTestProviderEnabled(TEST_PROVIDER, false) } catch (_: Exception) {}
        try { locationManager.removeTestProvider(TEST_PROVIDER) } catch (_: Exception) {}
        try { locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false) } catch (_: Exception) {}
        try { locationManager.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, false) } catch (_: Exception) {}

        stopForeground(STOP_FOREGROUND_REMOVE)
        isRunning = false
        lastMockLat = null
        lastMockLng = null
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
        const val TEST_PROVIDER = "virtual_gps"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        var isRunning = false
        var lastMockLat: Double? = null
        var lastMockLng: Double? = null
    }
}
