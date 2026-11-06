package com.wifimatch.wifi_match

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Android は省電力のため WiFi のブロードキャストを捨てることがあるので、
// アプリ起動中は MulticastLock を取って近くの端末のビーコンを受け取れるようにする。
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        lock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
