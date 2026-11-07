package com.wifimatch.wifi_match

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Android は省電力のため WiFi のブロードキャストを捨てることがあるので、
// アプリ起動中は MulticastLock を取って近くの端末のビーコンを受け取れるようにする。
// あわせて、メッセージが届いたときの通知（端末内で出す通知。外部サーバーは使わない）を扱う。
class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

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
    }

    override fun onDestroy() {
        lock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
