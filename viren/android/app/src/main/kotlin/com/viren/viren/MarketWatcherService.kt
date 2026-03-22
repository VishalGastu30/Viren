package com.viren.viren

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MarketWatcherService : Service() {
    private val TAG = "MarketWatcherService"
    private val CHANNEL_ID = "viren_market_watcher"
    private val NOTIFICATION_ID = 998

    private val serviceScope = CoroutineScope(Dispatchers.IO)
    private var pollingJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "MarketWatcherService created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "MarketWatcherService started")
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        startPolling()

        return START_STICKY
    }

    private fun startPolling() {
        pollingJob?.cancel()
        pollingJob = serviceScope.launch {
            while (true) {
                Log.d(TAG, "Polling market data (simulated background tick)")
                
                // Broadcast intent so Flutter can pick it up if registered
                val broadcastIntent = Intent("com.viren.MARKET_POLL")
                sendBroadcast(broadcastIntent)

                // Poll every 3 minutes
                delay(3 * 60 * 1000L)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Market Watcher"
            val descriptionText = "Monitors live prices during market hours"
            // Importance LOW means no sound/vibration, just silent icon
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Viren is active")
            .setContentText("Monitoring live market data")
            .setSmallIcon(android.R.drawable.ic_menu_compass) // Placeholder icon
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "MarketWatcherService destroyed")
        pollingJob?.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // We don't use binding, just startService
    }
}
