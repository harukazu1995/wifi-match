package com.wifimatch.wifi_match

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

// Android は省電力のため WiFi のブロードキャストを捨てることがあるので、
// アプリ起動中は MulticastLock を取って近くの端末のビーコンを受け取れるようにする。
// あわせて、メッセージの通知と、すれ違い通信（Bluetooth）の操作を扱う。外部サーバーは使わない。
class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null
    private var pendingBle: MethodChannel.Result? = null

    private fun granted(p: String): Boolean =
        Build.VERSION.SDK_INT < 23 || checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun blePermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun startProximity() {
        val intent = Intent(this, ProximityService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4712) {
            val pending = pendingBle
            pendingBle = null
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (ok) {
                try {
                    startProximity()
                } catch (e: Exception) {
                    pending?.success("denied")
                    return
                }
            }
            pending?.success(if (ok) "started" else "denied")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wifimatch/net").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticast" -> {
                    if (lock == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        lock = wifi.createMulticastLock("wifimatch").apply {
                            setReferenceCounted(false)
                            acquire()
                        }
                    }
                    result.success(true)
                }
                "requestNotifPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4711)
                        }
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                "notify" -> {
                    try {
                        val title = call.argument<String>("title") ?: "WiFi Match"
                        val body = call.argument<String>("body") ?: ""
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val channelId = "messages"
                        if (Build.VERSION.SDK_INT >= 26) {
                            nm.createNotificationChannel(
                                NotificationChannel(channelId, "メッセージ", NotificationManager.IMPORTANCE_HIGH)
                            )
                        }
                        val launch = packageManager.getLaunchIntentForPackage(packageName)
                        val flags = if (Build.VERSION.SDK_INT >= 23) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        val pending = PendingIntent.getActivity(this, 0, launch, flags)
                        val builder = if (Build.VERSION.SDK_INT >= 26) {
                            Notification.Builder(this, channelId)
                        } else {
                            @Suppress("DEPRECATION")
                            Notification.Builder(this)
                        }
                        builder.setSmallIcon(android.R.drawable.stat_notify_chat)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setContentIntent(pending)
                            .setAutoCancel(true)
                        nm.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wifimatch/ble").setMethodCallHandler { call, result ->
            when (call.method) {
                "bleSupported" -> {
                    result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE))
                }
                "bleConfig" -> {
                    val blockedIds = call.argument<List<*>>("blockedIds") ?: emptyList<String>()
                    val blockedSigs = call.argument<List<*>>("blockedSigs") ?: emptyList<String>()
                    getSharedPreferences(ProximityService.PREFS, Context.MODE_PRIVATE).edit()
                        .putString("profileId", call.argument<String>("profileId") ?: "")
                        .putString("name", call.argument<String>("name") ?: "")
                        .putInt("emojiIdx", call.argument<Int>("emojiIdx") ?: 0)
                        .putString("notifTitle", call.argument<String>("notifTitle") ?: "")
                        .putString("notifBody", call.argument<String>("notifBody") ?: "")
                        .putString("ongoing", call.argument<String>("ongoing") ?: "")
                        .putString("blockedIds", JSONArray(blockedIds).toString())
                        .putString("blockedSigs", JSONArray(blockedSigs).toString())
                        .apply()
                    result.success(true)
                }
                "bleStart" -> {
                    val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
                    if (!packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) || adapter == null) {
                        result.success("unsupported")
                    } else if (!adapter.isEnabled) {
                        result.success("bt_off")
                    } else {
                        val missing = blePermissions().filter { !granted(it) }
                        if (missing.isEmpty()) {
                            try {
                                startProximity()
                                result.success("started")
                            } catch (e: Exception) {
                                result.success("denied")
                            }
                        } else if (Build.VERSION.SDK_INT >= 23) {
                            pendingBle = result
                            requestPermissions(missing.toTypedArray(), 4712)
                        } else {
                            result.success("denied")
                        }
                    }
                }
                "bleStop" -> {
                    stopService(Intent(this, ProximityService::class.java))
                    result.success(true)
                }
                "bleRunning" -> result.success(ProximityService.running)
                "bleEncounters" -> {
                    result.success(getSharedPreferences(ProximityService.PREFS, Context.MODE_PRIVATE).getString("encounters", "[]") ?: "[]")
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        lock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
