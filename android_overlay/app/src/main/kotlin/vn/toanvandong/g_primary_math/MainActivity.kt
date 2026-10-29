package vn.toanvandong.g_primary_math

import android.Manifest
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Cầu nối Flutter <-> lớp nhận diện native.
 *  - MethodChannel "tvd/pose": start(config), stop(), keepScreenOn(bool),
 *    status() -> {startCrashed, lastCrash}, clearCrash()
 *  - EventChannel  "tvd/pose/stream": mỗi khung hình gửi {lm, w, h, inf, luma, gpu}
 */
class MainActivity : FlutterFragmentActivity(), PoseEngine.Listener {

    private var engine: PoseEngine? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingStart: Pair<Map<*, *>, MethodChannel.Result>? = null

    /** Lần chạy trước bị dừng khi đang bật camera (dấu "đang khởi động" còn nguyên). */
    private var startCrashed = false

    /** Mô tả lần app bị dừng bất thường gần nhất (lỗi Java, lỗi native, treo), null nếu không có. */
    private var lastCrash: String? = null

    private val prefs by lazy { getSharedPreferences("tvd_native", Context.MODE_PRIVATE) }
    private val crashFile by lazy { File(filesDir, "last_crash.txt") }

    override fun onCreate(savedInstanceState: Bundle?) {
        installCrashLogger()
        startCrashed = prefs.getBoolean(KEY_START_PENDING, false)
        prefs.edit().putBoolean(KEY_START_PENDING, false).apply()
        lastCrash = readLastCrash()
        super.onCreate(savedInstanceState)
    }

    /** Ghi lỗi Java chưa được bắt ra file trước khi app dừng, để lần sau xem được. */
    private fun installCrashLogger() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            try {
                val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
                crashFile.writeText("$time · luồng ${thread.name}\n${android.util.Log.getStackTraceString(e)}".take(8000))
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, e)
        }
    }

    /** Lần dừng bất thường gần nhất: file lỗi Java của app, rồi đến lý do hệ thống ghi lại (Android 11+). */
    private fun readLastCrash(): String? {
        val parts = mutableListOf<String>()
        prefs.getString(KEY_LAST_ERROR, null)?.let { parts.add("Lỗi bật camera gần nhất:\n$it") }
        try {
            if (crashFile.exists()) parts.add("Lỗi Java:\n" + crashFile.readText())
        } catch (_: Throwable) {
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val info = am.getHistoricalProcessExitReasons(packageName, 0, 1).firstOrNull()
                val seen = prefs.getLong(KEY_EXIT_SEEN, 0L)
                if (info != null && info.timestamp > seen) {
                    val reason = when (info.reason) {
                        ApplicationExitInfo.REASON_CRASH -> "lỗi Java"
                        ApplicationExitInfo.REASON_CRASH_NATIVE -> "lỗi native (thư viện C++)"
                        ApplicationExitInfo.REASON_ANR -> "treo (không phản hồi)"
                        ApplicationExitInfo.REASON_LOW_MEMORY -> "thiếu bộ nhớ"
                        else -> null
                    }
                    if (reason != null) {
                        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(info.timestamp))
                        parts.add("Hệ thống ghi: $reason lúc $time\n${info.description ?: ""}\nAndroid ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.MANUFACTURER} ${Build.MODEL}")
                    }
                }
            } catch (_: Throwable) {
            }
        }
        return if (parts.isEmpty()) null else parts.joinToString("\n\n")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "tvd/pose").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    lastCrash = readLastCrash()
                    result.success(mapOf("startCrashed" to startCrashed, "lastCrash" to lastCrash))
                }
                "clearCrash" -> {
                    startCrashed = false
                    lastCrash = null
                    try {
                        crashFile.delete()
                    } catch (_: Throwable) {
                    }
                    prefs.edit().putLong(KEY_EXIT_SEEN, System.currentTimeMillis()).remove(KEY_LAST_ERROR).apply()
                    result.success(null)
                }
                "start" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    if (hasCameraPermission()) {
                        doStart(args, result)
                    } else {
                        pendingStart = args to result
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA
                        )
                    }
                }
                "stop" -> {
                    prefs.edit().putBoolean(KEY_START_PENDING, false).apply()
                    engine?.stop()
                    engine = null
                    result.success(null)
                }
                "openCastSettings" -> result.success(openCastSettings())
                "keepScreenOn" -> {
                    val on = call.arguments as? Boolean ?: true
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "tvd/pose/stream").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })
    }

    /**
     * Mở màn phản chiếu màn hình (Smart View / Truyền / Cast). Thử lần lượt các màn cài đặt
     * mà máy hỗ trợ; trả về tên màn đã mở, hoặc null nếu máy không có màn nào.
     */
    private fun openCastSettings(): String? {
        val candidates = listOf(
            "cast" to Intent(Settings.ACTION_CAST_SETTINGS),
            "wifi_display" to Intent("android.settings.WIFI_DISPLAY_SETTINGS"),
            "display" to Intent(Settings.ACTION_DISPLAY_SETTINGS),
        )
        for ((name, intent) in candidates) {
            try {
                // Không dùng resolveActivity: Android 11+ giới hạn nhìn thấy gói khác, cứ mở rồi bắt lỗi.
                startActivity(intent)
                return name
            } catch (_: Throwable) {
            }
        }
        return null
    }

    private fun hasCameraPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun doStart(args: Map<*, *>, result: MethodChannel.Result) {
        // Dấu "đang khởi động": nếu app văng giữa chừng, lần mở sau sẽ biết và không tự bật lại camera.
        prefs.edit().putBoolean(KEY_START_PENDING, true).commit()
        engine?.stop()
        val cfg = PoseEngine.Config(
            frontCamera = args["front"] == true,
            model = (args["model"] as? String) ?: "lite",
            useGpu = args["gpu"] != false,
            wideAngle = args["wide"] == true,
        )
        val e = try {
            PoseEngine(this, this, this)
        } catch (t: Throwable) {
            prefs.edit().putBoolean(KEY_START_PENDING, false).apply()
            result.error("engine", "Không khởi tạo được lớp nhận diện: ${t.javaClass.simpleName}: ${t.message}", null)
            return
        }
        engine = e
        var replied = false
        e.start(
            cfg,
            onStarted = { info ->
                if (!replied) {
                    replied = true
                    result.success(info)
                }
            },
            onFailed = { code, message ->
                val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
                prefs.edit()
                    .putBoolean(KEY_START_PENDING, false)
                    .putString(KEY_LAST_ERROR, "$time · $code\n$message\nAndroid ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.MANUFACTURER} ${Build.MODEL}")
                    .apply()
                if (!replied) {
                    replied = true
                    result.error(code, message, null)
                }
            },
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CAMERA) return
        val p = pendingStart ?: return
        pendingStart = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            doStart(p.first, p.second)
        } else {
            p.second.error("permission", "Chưa cấp quyền camera cho ứng dụng", null)
        }
    }

    override fun onFrame(data: Map<String, Any?>) {
        // Khung hình đầu tiên về được nghĩa là khởi động xong an toàn.
        if (prefs.getBoolean(KEY_START_PENDING, false)) prefs.edit().putBoolean(KEY_START_PENDING, false).apply()
        sink?.success(data)
    }

    override fun onError(code: String, message: String) {
        sink?.error(code, message, null)
    }

    override fun onDestroy() {
        engine?.stop()
        engine = null
        super.onDestroy()
    }

    companion object {
        private const val REQUEST_CAMERA = 4201
        private const val KEY_START_PENDING = "poseStartPending"
        private const val KEY_EXIT_SEEN = "exitSeenAt"
        private const val KEY_LAST_ERROR = "lastStartError"
    }
}
