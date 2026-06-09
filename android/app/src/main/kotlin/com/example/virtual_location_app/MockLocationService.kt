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

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var mockLat: Double = 0.0
    private var mockLng: Double = 0.0
    private val activeProviders = linkedSetOf<String>()

    private val updateRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val elapsed = SystemClock.elapsedRealtimeNanos()

            for (provider in activeProviders) {
                try {
                    locationManager.setTestProviderLocation(
                        provider,
                        buildMockLocation(provider, now, elapsed)
                    )
                } catch (_: SecurityException) {
                    stopSelf()
                    return
                } catch (_: Exception) {
                    // Ignore a single provider failure and keep the service alive.
                }
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
        lastMockLat = mockLat
        lastMockLng = mockLng

        val notification = buildNotification(mockLat, mockLng)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        try {
            registerMockProviders()
        } catch (_: SecurityException) {
            stopSelf()
            return START_NOT_STICKY
        } catch (_: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }

        handler.post(updateRunnable)
        isRunning = true

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)

        clearMockProviders()

        stopForeground(STOP_FOREGROUND_REMOVE)
        isRunning = false
        lastMockLat = null
        lastMockLng = null
        super.onDestroy()
    }

    private fun registerMockProviders() {
        activeProviders.clear()

        ensureTestProvider(
            TEST_PROVIDER,
            requiresNetwork = false,
            requiresSatellite = false,
            requiresCell = false,
            accuracy = Criteria.ACCURACY_FINE
        )

        ensureTestProvider(
            LocationManager.GPS_PROVIDER,
            requiresNetwork = false,
            requiresSatellite = true,
            requiresCell = false,
            accuracy = Criteria.ACCURACY_FINE
        )

        ensureTestProvider(
            LocationManager.NETWORK_PROVIDER,
            requiresNetwork = true,
            requiresSatellite = false,
            requiresCell = true,
            accuracy = Criteria.ACCURACY_COARSE
        )
    }

    private fun ensureTestProvider(
        provider: String,
        requiresNetwork: Boolean,
        requiresSatellite: Boolean,
        requiresCell: Boolean,
        accuracy: Int
    ) {
        try {
            locationManager.removeTestProvider(provider)
        } catch (_: Exception) {
        }

        locationManager.addTestProvider(
            provider,
            requiresNetwork,
            requiresSatellite,
            requiresCell,
            false,
            true,
            true,
            true,
            Criteria.POWER_LOW,
            accuracy
        )
        locationManager.setTestProviderEnabled(provider, true)
        activeProviders.add(provider)
    }

    private fun clearMockProviders() {
        val providersToRemove = activeProviders.toList()
        for (provider in providersToRemove) {
            try {
                locationManager.clearTestProviderLocation(provider)
            } catch (_: Exception) {
            }
            try {
                locationManager.setTestProviderEnabled(provider, false)
            } catch (_: Exception) {
            }
            try {
                locationManager.removeTestProvider(provider)
            } catch (_: Exception) {
            }
        }
        activeProviders.clear()
    }

    private fun buildMockLocation(
        provider: String,
        now: Long,
        elapsedRealtimeNanos: Long
    ): Location {
        val isNetworkProvider = provider == LocationManager.NETWORK_PROVIDER
        return Location(provider).apply {
            latitude = mockLat
            longitude = mockLng
            altitude = if (isNetworkProvider) 0.0 else 50.0
            accuracy = if (isNetworkProvider) 12.0f else 3.0f
            speed = 0.0f
            bearing = 0.0f
            time = now
            this.elapsedRealtimeNanos = elapsedRealtimeNanos
        }
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
