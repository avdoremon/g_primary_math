package vn.toanvandong.g_primary_math

import android.Manifest
import android.content.pm.PackageManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Cầu nối Flutter <-> lớp nhận diện native.
 *  - MethodChannel "tvd/pose": start(config), stop(), keepScreenOn(bool)
 *  - EventChannel  "tvd/pose/stream": mỗi khung hình gửi {lm, w, h, inf, luma, gpu}
 */
class MainActivity : FlutterFragmentActivity(), PoseEngine.Listener {

    private var engine: PoseEngine? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingStart: Pair<Map<*, *>, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "tvd/pose").setMethodCallHandler { call, result ->
            when (call.method) {
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
                    engine?.stop()
                    engine = null
                    result.success(null)
                }
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

    private fun hasCameraPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun doStart(args: Map<*, *>, result: MethodChannel.Result) {
        engine?.stop()
        val cfg = PoseEngine.Config(
            frontCamera = args["front"] == true,
            model = (args["model"] as? String) ?: "lite",
            useGpu = args["gpu"] != false,
            wideAngle = args["wide"] == true,
        )
        val e = PoseEngine(this, this, this)
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
    }
}
