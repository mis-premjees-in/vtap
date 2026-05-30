package com.premjees.vtap

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject

class VtapLocationService : Service() {
    private var locationManager: LocationManager? = null
    private val channelId = "vtap_bg_channel"
    private val notificationId = 999

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            checkGeofenceTransition(location)
        }
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        addBackgroundLog("Native Android Service: Service starting...", this)
        startForegroundServiceNotification()
        startTracking()
        return START_STICKY
    }

    override fun onDestroy() {
        addBackgroundLog("Native Android Service: Service destroying...", this)
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (e: Exception) {
            // ignore
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun startForegroundServiceNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "VTAP Background Service",
                NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("VTAP Workspace active monitoring")
            .setContentText("Silent geofence safety matrix is running...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(notificationId, notification)
    }

    private fun startTracking() {
        try {
            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isGpsEnabled = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
            val isNetworkEnabled = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false

            if (!isGpsEnabled && !isNetworkEnabled) {
                addBackgroundLog("Native Android Service: Warning - GPS and Network location providers are disabled.", this)
                return
            }

            // Request updates from GPS (high accuracy)
            if (isGpsEnabled) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    10000L, // 10 seconds
                    5f,     // 5 meters
                    locationListener
                )
            }
            
            // Request updates from Network (fallback)
            if (isNetworkEnabled) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    10000L, // 10 seconds
                    5f,     // 5 meters
                    locationListener
                )
            }

            addBackgroundLog("Native Android Service: Location tracking started successfully.", this)
        } catch (e: SecurityException) {
            addBackgroundLog("Native Android Service: SecurityException - Missing location permission: ${e.message}", this)
        } catch (e: Exception) {
            addBackgroundLog("Native Android Service: Failed to start tracking: ${e.message}", this)
        }
    }

    private fun checkGeofenceTransition(location: Location) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.token", "") ?: ""
        val username = prefs.getString("flutter.username", "") ?: ""
        val whosId = prefs.getString("flutter.whos_id", "") ?: ""
        val whosPremiseId = prefs.getString("flutter.whos_premise", "") ?: ""
        val currentStatus = prefs.getString("flutter.attendance_status", "out") ?: "out"

        val latStr = prefs.getString("flutter.premise_lat_str", "") ?: ""
        val lngStr = prefs.getString("flutter.premise_lng_str", "") ?: ""
        val radiusStr = prefs.getString("flutter.premise_radius_str", "") ?: ""

        if (token.isEmpty() || username.isEmpty() || whosId.isEmpty() || whosPremiseId.isEmpty()) {
            return // Not fully logged in or configured
        }

        val lat = latStr.toDoubleOrNull()
        val lng = lngStr.toDoubleOrNull()
        val radius = radiusStr.toDoubleOrNull()

        if (lat == null || lng == null || radius == null) {
            return // Missing or invalid premise config
        }

        val results = FloatArray(1)
        Location.distanceBetween(location.latitude, location.longitude, lat, lng, results)
        val distance = results[0]

        // Check entry/exit transitions
        if (distance <= radius) {
            // Inside the premise
            if (currentStatus == "out") {
                addBackgroundLog("Native Android Service: ENTER boundary detected. Distance: ${"%.1f".format(distance)}m (Limit: ${radius}m). Initiating Auto Punch-In...", this)
                submitPunch(username, token, "In", whosPremiseId, whosId, this)
            }
        } else {
            // Outside the premise
            if (currentStatus == "in") {
                addBackgroundLog("Native Android Service: EXIT boundary detected. Distance: ${"%.1f".format(distance)}m (Limit: ${radius}m). Initiating Auto Punch-Out...", this)
                submitPunch(username, token, "Out", whosPremiseId, whosId, this)
            }
        }
    }

    private fun submitPunch(username: String, token: String, type: String, premiseId: String, whosId: String, context: Context) {
        Thread {
            try {
                val url = URL("https://tm.premjees.in/api/create_record.php")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.connectTimeout = 30000
                connection.readTimeout = 30000
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                if (token.isNotEmpty()) {
                    connection.setRequestProperty("Authorization", "Bearer $token")
                }

                val dataObject = JSONObject()
                dataObject.put("pnb_type", type)
                dataObject.put("pnb_premises_id", premiseId)
                dataObject.put("pnb_whos_id", whosId)

                val body = JSONObject()
                body.put("table_name", "pnb")
                body.put("username", username)
                body.put("access_token", token)
                body.put("data", dataObject)

                val writer = OutputStreamWriter(connection.outputStream)
                writer.write(body.toString())
                writer.flush()
                writer.close()

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val responseString = connection.inputStream.bufferedReader().use { it.readText() }
                    val responseJson = JSONObject(responseString)
                    val status = responseJson.optBoolean("status", false)
                    if (status) {
                        // Success! Update local SharedPreference state
                        val prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        prefs.edit().putString("flutter.attendance_status", type.lowercase()).apply()
                        
                        addBackgroundLog("Native Android Service: Auto Punch-$type success on server API.", context)
                        showTransitionNotification(type, context)
                    } else {
                        addBackgroundLog("Native Android Service: Auto Punch-$type failed. API status is false. Response: $responseString", context)
                    }
                } else {
                    addBackgroundLog("Native Android Service: Auto Punch-$type failed. HTTP code: $responseCode", context)
                }
                connection.disconnect()
            } catch (e: Exception) {
                addBackgroundLog("Native Android Service: HTTP Request error: ${e.message}", context)
            }
        }.start()
    }

    private fun showTransitionNotification(type: String, context: Context) {
        val mNotificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val title = if (type == "In") "Auto Punched In" else "Auto Punched Out"
        val body = if (type == "In") {
            "Aap assigned workspace boundary ke andar aa gaye hain. Aapka automatic IN mark ho chuka hai."
        } else {
            "Aap assigned workspace boundary se bahar nikal gaye hain. Aapka automatic OUT mark ho chuka hai."
        }

        // Tap notification to open main app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, "task_channel")
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        mNotificationManager.notify(888, notification)
    }

    private fun addBackgroundLog(message: String, context: Context) {
        try {
            val file = File(context.filesDir, "background_logs.txt")
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            val logLine = "[$timestamp] $message\n"
            
            file.appendText(logLine)
            
            if (file.exists() && file.length() > 100 * 1024) {
                val lines = file.readLines()
                if (lines.size > 300) {
                    val trimmedLines = lines.takeLast(300)
                    file.writeText(trimmedLines.joinToString("\n") + "\n")
                }
            }
        } catch (e: Exception) {
            // ignore
        }
    }
}
