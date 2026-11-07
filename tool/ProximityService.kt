package com.wifimatch.wifi_match

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

// すれ違い通信: Bluetooth LE で「自分の情報」を発信しつつ、近くの同じアプリの端末を探す。
// 見つけたら通知を出し、一覧を端末の中に保存する（サーバーは使わない）。
// 発信する識別番号は、プロフィールIDと日付から作るので、毎日変わる。
class ProximityService : Service() {
    companion object {
        const val PREFS = "wm_ble"
        const val CH_ONGOING = "proximity_ongoing"
        const val CH_ENCOUNTER = "encounters"
        const val COMPANY_ID = 0xFFFF
        @Volatile
        var running = false

        fun fnv(s: String): Int {
            var h = 0x811c9dc5.toInt()
            for (b in s.toByteArray(Charsets.UTF_8)) {
                h = h xor (b.toInt() and 0xff)
                h *= 16777619
            }
            return h
        }

        fun today(): Long = System.currentTimeMillis() / 86400000L

        fun tokenFor(profileId: String, day: Long): Int = fnv("$profileId|$day")
    }

    private val handler = Handler(Looper.getMainLooper())
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var advCallback: AdvertiseCallback? = null
    private var scanCallback: ScanCallback? = null
    private val seen = HashMap<Int, Long>()
    private var advDay = -1L

    private val tick = object : Runnable {
        override fun run() {
            try {
                if (today() != advDay) restartAdvertising()
            } catch (e: Exception) {
            }
            handler.postDelayed(this, 10 * 60 * 1000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun pendingFlags(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(NotificationChannel(CH_ONGOING, "Proximity", NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel(CH_ENCOUNTER, "Encounters", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private fun buildOngoing(text: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 1, launch, pendingFlags())
        return builder(CH_ONGOING)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("WiFi Match")
            .setContentText(text)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannels()
        val ongoing = prefs().getString("ongoing", "") ?: ""
        val notif = buildOngoing(if (ongoing.isEmpty()) "Bluetooth" else ongoing)
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(1001, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(1001, notif)
            }
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            startBle()
        }
        return START_STICKY
    }

    private fun truncateUtf8(s: String, maxBytes: Int): ByteArray {
        val sb = StringBuilder()
        var n = 0
        var i = 0
        while (i < s.length) {
            val cp = s.codePointAt(i)
            val ch = String(Character.toChars(cp))
            val len = ch.toByteArray(Charsets.UTF_8).size
            if (n + len > maxBytes) break
            sb.append(ch)
            n += len
            i += Character.charCount(cp)
        }
        return sb.toString().toByteArray(Charsets.UTF_8)
    }

    private fun startBle() {
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = bm.adapter
        if (adapter == null || !adapter.isEnabled || prefs().getString("profileId", "").isNullOrEmpty()) {
            running = false
            stopSelf()
            return
        }
        advertiser = adapter.bluetoothLeAdvertiser
        scanner = adapter.bluetoothLeScanner
        try {
            startAdvertising()
            startScanning()
        } catch (e: Exception) {
            running = false
            stopSelf()
            return
        }
        handler.postDelayed(tick, 10 * 60 * 1000L)
    }

    private fun startAdvertising() {
        val adv = advertiser ?: return
        val p = prefs()
        val profileId = p.getString("profileId", "") ?: ""
        val name = truncateUtf8(p.getString("name", "") ?: "", 12)
        val tok = tokenFor(profileId, today())
        val payload = ByteArray(8 + name.size)
        payload[0] = 'W'.code.toByte()
        payload[1] = 'M'.code.toByte()
        payload[2] = 1
        payload[3] = (tok ushr 24).toByte()
        payload[4] = (tok ushr 16).toByte()
        payload[5] = (tok ushr 8).toByte()
        payload[6] = tok.toByte()
        payload[7] = p.getInt("emojiIdx", 0).toByte()
        System.arraycopy(name, 0, payload, 8, name.size)
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .setTimeout(0)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(COMPANY_ID, payload)
            .build()
        val cb = object : AdvertiseCallback() {}
        advCallback = cb
        advDay = today()
        adv.startAdvertising(settings, data, cb)
    }

    private fun restartAdvertising() {
        try {
            advCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (e: Exception) {
        }
        startAdvertising()
    }

    private fun startScanning() {
        val sc = scanner ?: return
        val filter = ScanFilter.Builder()
            .setManufacturerData(COMPANY_ID, byteArrayOf(0x57, 0x4D, 0x01), byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte()))
            .build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                try {
                    handle(result)
                } catch (e: Exception) {
                }
            }
        }
        scanCallback = cb
        sc.startScan(listOf(filter), settings, cb)
    }

    private fun handle(result: ScanResult) {
        val bytes = result.scanRecord?.getManufacturerSpecificData(COMPANY_ID) ?: return
        if (bytes.size < 8 || bytes[0] != 0x57.toByte() || bytes[1] != 0x4D.toByte() || bytes[2] != 1.toByte()) return
        val tok = ((bytes[3].toInt() and 0xff) shl 24) or ((bytes[4].toInt() and 0xff) shl 16) or
            ((bytes[5].toInt() and 0xff) shl 8) or (bytes[6].toInt() and 0xff)
        val emojiIdx = bytes[7].toInt() and 0xff
        val name = String(bytes, 8, bytes.size - 8, Charsets.UTF_8).trim()
        if (name.isEmpty()) return
        val p = prefs()
        val me = p.getString("profileId", "") ?: ""
        val d = today()
        if (tok == tokenFor(me, d) || tok == tokenFor(me, d - 1) || tok == tokenFor(me, d + 1)) return
        if (isBlocked(tok, name, emojiIdx)) return
        val now = System.currentTimeMillis()
        val last = seen[tok]
        if (last != null && now - last < 6 * 3600 * 1000L) return
        seen[tok] = now
        record(tok, name, emojiIdx, now)
        notifyEncounter(name)
    }

    private fun isBlocked(tok: Int, name: String, emojiIdx: Int): Boolean {
        val p = prefs()
        val sigs = try { JSONArray(p.getString("blockedSigs", "[]")) } catch (e: Exception) { JSONArray() }
        for (i in 0 until sigs.length()) if (sigs.optString(i) == "$name|$emojiIdx") return true
        val ids = try { JSONArray(p.getString("blockedIds", "[]")) } catch (e: Exception) { JSONArray() }
        val d = today()
        for (i in 0 until ids.length()) {
            val id = ids.optString(i)
            if (tok == tokenFor(id, d) || tok == tokenFor(id, d - 1) || tok == tokenFor(id, d + 1)) return true
        }
        return false
    }

    private fun record(tok: Int, name: String, emojiIdx: Int, at: Long) {
        val p = prefs()
        val arr = try { JSONArray(p.getString("encounters", "[]")) } catch (e: Exception) { JSONArray() }
        val o = JSONObject()
        o.put("token", tok)
        o.put("name", name)
        o.put("emojiIdx", emojiIdx)
        o.put("at", at)
        arr.put(o)
        val out = JSONArray()
        val start = maxOf(0, arr.length() - 100)
        for (i in start until arr.length()) out.put(arr.get(i))
        p.edit().putString("encounters", out.toString()).apply()
    }

    private fun notifyEncounter(name: String) {
        val p = prefs()
        val title = p.getString("notifTitle", "") ?: ""
        val tpl = p.getString("notifBody", "") ?: ""
        val body = (if (tpl.isEmpty()) "{name}" else tpl).replace("{name}", name)
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 2, launch, pendingFlags())
        val n = builder(CH_ENCOUNTER)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(if (title.isEmpty()) "WiFi Match" else title)
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(2000 + (System.currentTimeMillis() % 1000).toInt(), n)
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        try {
            advCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (e: Exception) {
        }
        try {
            scanCallback?.let { scanner?.stopScan(it) }
        } catch (e: Exception) {
        }
        super.onDestroy()
    }
}
