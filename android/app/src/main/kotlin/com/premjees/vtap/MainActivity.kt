package com.premjees.vtap

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.premjees.vtap/location_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startLocationService()
                    result.success(true)
                }
                "stopService" -> {
                    stopLocationService()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(isServiceRunning())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startLocationService() {
        val intent = Intent(this, VtapLocationService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLocationService() {
        val intent = Intent(this, VtapLocationService::class.java)
        stopService(intent)
    }

    private fun isServiceRunning(): Boolean {
        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (VtapLocationService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
