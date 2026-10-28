package vn.toanvandong.g_primary_math

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import android.view.WindowManager
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Lớp nhận diện: CameraX lấy khung hình -> MediaPipe Pose Landmarker (live stream).
 * Ảnh camera không rời khỏi lớp này; chỉ gửi 33 điểm khớp + vài số đo sang Flutter.
 */
class PoseEngine(
    private val context: Context,
    private val owner: LifecycleOwner,
    private val listener: Listener,
) {
    interface Listener {
        fun onFrame(data: Map<String, Any?>)
        fun onError(code: String, message: String)
    }

    data class Config(
        val frontCamera: Boolean,
        val model: String,      // "lite" | "full"
        val useGpu: Boolean,
        val wideAngle: Boolean, // camera sau: dùng mức zoom nhỏ nhất (ống góc rộng nếu máy có)
    )

    private val main = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val pending = ConcurrentHashMap<Long, FloatArray>() // ts -> [luma, width, height]

    @Volatile private var landmarker: PoseLandmarker? = null
    @Volatile private var stopped = false
    @Volatile private var usingGpu = false
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var lastTimestamp = 0L

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            analysis?.targetRotation = currentRotation()
        }
    }

    fun start(
        cfg: Config,
        onStarted: (Map<String, Any?>) -> Unit,
        onFailed: (String, String) -> Unit,
    ) {
        executor.execute {
            val lm = try {
                createLandmarker(cfg)
            } catch (e: Exception) {
                Log.e(TAG, "Không tạo được PoseLandmarker", e)
                main.post { onFailed("model", "Không tải được mô hình nhận diện: ${e.message}") }
                return@execute
            }
            if (stopped) {
                lm.close()
                return@execute
            }
            landmarker = lm
            main.post { bindCamera(cfg, onStarted, onFailed) }
        }
    }

    fun stop() {
        stopped = true
        try {
            displayManager.unregisterDisplayListener(displayListener)
        } catch (_: Exception) {
        }
        analysis?.clearAnalyzer()
        provider?.unbindAll()
        provider = null
        analysis = null
        executor.execute {
            landmarker?.close()
            landmarker = null
            pending.clear()
        }
        executor.shutdown()
    }

    // ---------------------------------------------------------------- MediaPipe

    private fun createLandmarker(cfg: Config): PoseLandmarker {
        val asset = if (cfg.model == "full") "pose_landmarker_full.task" else "pose_landmarker_lite.task"
        if (cfg.useGpu) {
            try {
                val lm = buildLandmarker(asset, Delegate.GPU)
                usingGpu = true
                return lm
            } catch (e: Exception) {
                Log.w(TAG, "GPU không dùng được, chuyển sang CPU", e)
            }
        }
        usingGpu = false
        return buildLandmarker(asset, Delegate.CPU)
    }

    private fun buildLandmarker(asset: String, delegate: Delegate): PoseLandmarker {
        val base = BaseOptions.builder()
            .setModelAssetPath(asset)
            .setDelegate(delegate)
            .build()
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener { result, input -> onResult(result, input) }
            .setErrorListener { e -> main.post { listener.onError("mediapipe", e.message ?: "Lỗi MediaPipe") } }
            .build()
        return PoseLandmarker.createFromOptions(context, options)
    }

    private fun onResult(result: PoseLandmarkerResult, input: MPImage) {
        if (stopped) return
        val ts = result.timestampMs()
        val meta = pending.remove(ts)
        val processingMs = SystemClock.uptimeMillis() - ts

        var points: DoubleArray? = null
        val poses = result.landmarks()
        if (poses.isNotEmpty()) {
            val pose = poses[0]
            val a = DoubleArray(pose.size * 4)
            for ((i, l) in pose.withIndex()) {
                a[i * 4] = l.x().toDouble()
                a[i * 4 + 1] = l.y().toDouble()
                a[i * 4 + 2] = l.z().toDouble()
                a[i * 4 + 3] = l.visibility().orElse(1f).toDouble()
            }
            points = a
        }

        val data = hashMapOf<String, Any?>(
            "lm" to points,
            "w" to (meta?.get(1)?.toInt() ?: input.width),
            "h" to (meta?.get(2)?.toInt() ?: input.height),
            "inf" to processingMs.toInt(),
            "luma" to (meta?.get(0)?.toDouble() ?: 0.0),
            "gpu" to usingGpu,
        )
        main.post { if (!stopped) listener.onFrame(data) }
    }

    // ---------------------------------------------------------------- CameraX

    private fun bindCamera(
        cfg: Config,
        onStarted: (Map<String, Any?>) -> Unit,
        onFailed: (String, String) -> Unit,
    ) {
        if (stopped) return
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (stopped) return@addListener
            try {
                val p = future.get()
                val selector = if (cfg.frontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                val strategy = ResolutionStrategy(
                    Size(640, 480),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                )
                val a = ImageAnalysis.Builder()
                    .setResolutionSelector(ResolutionSelector.Builder().setResolutionStrategy(strategy).build())
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setTargetRotation(currentRotation())
                    .build()
                a.setAnalyzer(executor) { image -> analyze(image) }

                p.unbindAll()
                val camera = p.bindToLifecycle(owner, selector, a)
                provider = p
                analysis = a
                displayManager.registerDisplayListener(displayListener, main)

                val minZoom = camera.cameraInfo.zoomState.value?.minZoomRatio ?: 1f
                var zoom = 1f
                if (cfg.wideAngle && !cfg.frontCamera && minZoom < 1f) {
                    camera.cameraControl.setZoomRatio(minZoom)
                    zoom = minZoom
                }
                onStarted(
                    mapOf(
                        "gpu" to usingGpu,
                        "zoom" to zoom.toDouble(),
                        "minZoom" to minZoom.toDouble(),
                        "camera" to if (cfg.frontCamera) "front" else "back",
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Không mở được camera", e)
                onFailed("camera", "Không mở được camera: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun analyze(image: ImageProxy) {
        val lm = landmarker
        if (lm == null || stopped) {
            image.close()
            return
        }
        val rotation = image.imageInfo.rotationDegrees
        val raw: Bitmap? = try {
            image.toBitmap()
        } catch (e: Exception) {
            Log.w(TAG, "toBitmap lỗi", e)
            null
        } finally {
            image.close()
        }
        if (raw == null) return

        val luma = centerLuma(raw)
        val upright = if (rotation != 0) {
            val m = Matrix().apply { postRotate(rotation.toFloat()) }
            Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
        } else {
            raw
        }

        var ts = SystemClock.uptimeMillis()
        if (ts <= lastTimestamp) ts = lastTimestamp + 1
        lastTimestamp = ts
        pending[ts] = floatArrayOf(luma, upright.width.toFloat(), upright.height.toFloat())
        if (pending.size > 20) {
            val cutoff = ts - 2000
            pending.keys.removeIf { it < cutoff }
        }

        try {
            lm.detectAsync(BitmapImageBuilder(upright).build(), ts)
        } catch (e: Exception) {
            pending.remove(ts)
            Log.w(TAG, "detectAsync lỗi", e)
        }
    }

    /** Độ sáng trung bình (0–255) của vùng 30% ở giữa khung hình, dùng cho bài đo độ trễ. */
    private fun centerLuma(b: Bitmap): Float {
        val x0 = (b.width * 0.35f).toInt()
        val y0 = (b.height * 0.35f).toInt()
        val w = (b.width * 0.3f).toInt().coerceAtLeast(1)
        val h = (b.height * 0.3f).toInt().coerceAtLeast(1)
        val steps = 16
        var sum = 0f
        for (i in 0 until steps) {
            for (j in 0 until steps) {
                val c = b.getPixel(x0 + i * w / steps, y0 + j * h / steps)
                sum += 0.299f * Color.red(c) + 0.587f * Color.green(c) + 0.114f * Color.blue(c)
            }
        }
        return sum / (steps * steps)
    }

    @Suppress("DEPRECATION")
    private fun currentRotation(): Int =
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation

    companion object {
        private const val TAG = "PoseEngine"
    }
}
