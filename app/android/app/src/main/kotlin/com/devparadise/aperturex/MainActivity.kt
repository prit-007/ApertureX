package com.devparadise.aperturex

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayInputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Hosts spike B's zero-copy preview texture and the high-zoom ROI region
 * decoder (#16/#55).
 *
 * Android owns a `SurfaceProducer`-backed texture from the Flutter
 * `TextureRegistry`; Dart drives creation/binding over the [CHANNEL] method
 * channel, and Rust ([bindPreviewSurface]) writes graded frames straight into
 * the producer's `Surface`/`ANativeWindow`. When this class is absent
 * (iOS/tests) every call degrades and Dart keeps the return-frame path.
 *
 * [ROI_CHANNEL] decodes full-width source bands with `BitmapRegionDecoder`
 * so a >100 MP frame never materialises as a full RGBA buffer; any failure
 * raises a `PlatformException` and Dart falls back to the in-process Rust
 * decoder.
 */
class MainActivity : FlutterActivity() {
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()
    private val roiExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    /**
     * Enables 90 Hz / 120 Hz / 144 Hz display refresh rates on supported Android
     * devices (API 23+), unlocking full 120 FPS editing and viewport scrubbing.
     */
    private fun enableHighRefreshRate() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                val currentDisplay = display
                if (currentDisplay != null) {
                    val maxMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate }
                    if (maxMode != null && maxMode.refreshRate > 60.0f) {
                        val params = window.attributes
                        params.preferredDisplayModeId = maxMode.modeId
                        window.attributes = params
                    }
                }
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                @Suppress("DEPRECATION")
                val defaultDisplay = windowManager.defaultDisplay
                val maxMode = defaultDisplay?.supportedModes?.maxByOrNull { it.refreshRate }
                if (maxMode != null && maxMode.refreshRate > 60.0f) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    window.attributes = params
                }
            }
        } catch (t: Throwable) {
            NativeLog.record("enableHighRefreshRate failed", t, level = "warning")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ADR 0012 §6: every handler is fault-contained — a platform throw
        // becomes a Dart `PlatformException` (popup + log, app lives), never a
        // process death.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "create" -> createTexture(flutterEngine, call.argument("width"), call.argument("height"), result)
                        "bind" -> bindTexture(call.argument("textureId"), call.argument("handle"), result)
                        "dispose" -> disposeTexture(call.argument("textureId"), result)
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    NativeLog.record("preview channel '${call.method}' failed", t)
                    result.error("native_error", t.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROI_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "decodeBand" -> decodeBand(
                            call.argument<ByteArray>("jpeg"),
                            call.argument<Int>("x") ?: 0,
                            call.argument<Int>("y") ?: 0,
                            call.argument<Int>("width") ?: -1,
                            call.argument<Int>("height") ?: -1,
                            result,
                        )
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    NativeLog.record("roi channel '${call.method}' failed", t)
                    result.error("native_error", t.message, null)
                }
            }

        // Kotlin's own evidence, read by Dart at startup (ADR 0012 §4).
        NativeLog.init(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "readEntries" -> result.success(NativeLog.readEntries(call.argument<Int>("limit") ?: 100))
                        "readCrashMarker" -> result.success(NativeLog.readCrashMarker())
                        "clearCrashMarker" -> {
                            NativeLog.clearCrashMarker()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    NativeLog.record("native_log channel '${call.method}' failed", t)
                    result.error("native_error", t.message, null)
                }
            }
    }

    private fun createTexture(flutterEngine: FlutterEngine, widthArg: Int?, heightArg: Int?, result: MethodChannel.Result) {
        val width = widthArg ?: 1
        val height = heightArg ?: 1
        try {
            // SurfaceProducer, not createSurfaceTexture: the embedding logs a
            // migration warning for SurfaceTexture entries and Impeller prefers
            // this path. getSurface() below yields the Surface directly.
            val producer = flutterEngine.renderer.createSurfaceProducer()
            producer.setSize(width, height)
            producers[producer.id()] = producer
            result.success(producer.id().toInt())
        } catch (t: Throwable) {
            result.error("create_failed", t.message, null)
        }
    }

    private fun bindTexture(textureIdArg: Number?, handleArg: Number?, result: MethodChannel.Result) {
        val producer = producers[textureIdArg?.toLong()]
        if (producer == null) {
            result.success(false)
            return
        }
        val handle = handleArg?.toLong() ?: -1L
        val surface = try {
            producer.getSurface()
        } catch (t: Throwable) {
            result.success(false)
            return
        }
        val ptr = try {
            bindPreviewSurface(surface, handle)
        } catch (t: Throwable) {
            0L
        }
        result.success(ptr != 0L)
    }

    private fun disposeTexture(textureIdArg: Number?, result: MethodChannel.Result) {
        val id = textureIdArg?.toLong()
        if (id != null) {
            try {
                producers.remove(id)?.release()
            } catch (t: Throwable) {
                NativeLog.record("texture release failed", t, level = "warning")
            }
        }
        result.success(null)
    }

    /** Decodes the full-width band `(x, y, width, height)` of [jpeg] off the
     * platform thread; errors are reported as `PlatformException`s so Dart can
     * fall back to the Rust decoder. */
    private fun decodeBand(jpeg: ByteArray?, x: Int, y: Int, width: Int, height: Int, result: MethodChannel.Result) {
        if (jpeg == null || width <= 0 || height <= 0 || x < 0 || y < 0) {
            result.error("bad_args", "invalid band arguments", null)
            return
        }
        roiExecutor.execute {
            try {
                val pixels = regionDecode(jpeg, x, y, width, height)
                runOnUiThread { result.success(pixels) }
            } catch (t: Throwable) {
                runOnUiThread { result.error("decode_failed", t.message, null) }
            }
        }
    }

    /** `BitmapRegionDecoder` keeps only [width]×[height] resident — never the
     * full decoded frame — which is the entire point of this channel. The
     * result is tightly packed RGBA (ARGB_8888 stores R,G,B,A per pixel). */
    @Suppress("DEPRECATION") // InputStream variant is the API < 31 entry point.
    private fun regionDecode(jpeg: ByteArray, x: Int, y: Int, width: Int, height: Int): Map<String, Any> {
        val decoder = BitmapRegionDecoder.newInstance(ByteArrayInputStream(jpeg), false)
            ?: throw IllegalStateException("BitmapRegionDecoder unavailable")
        try {
            val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
            val bitmap = decoder.decodeRegion(Rect(x, y, x + width, y + height), opts)
                ?: throw IllegalStateException("decodeRegion returned null")
            try {
                val out = ByteArray(bitmap.width * bitmap.height * 4)
                if (bitmap.rowBytes == bitmap.width * 4) {
                    bitmap.copyPixelsToBuffer(ByteBuffer.wrap(out))
                } else {
                    // Rare padded rows: copy the strided buffer, then repack.
                    val stride = bitmap.rowBytes
                    val strided = ByteBuffer.allocate(stride * bitmap.height)
                    bitmap.copyPixelsToBuffer(strided)
                    for (row in 0 until bitmap.height) {
                        strided.position(row * stride)
                        strided.get(out, row * bitmap.width * 4, bitmap.width * 4)
                    }
                }
                return mapOf("width" to bitmap.width, "height" to bitmap.height, "rgba" to out)
            } finally {
                bitmap.recycle()
            }
        } finally {
            decoder.recycle()
        }
    }

    override fun onDestroy() {
        roiExecutor.shutdown()
        for (producer in producers.values) producer.release()
        producers.clear()
        super.onDestroy()
    }

    /** Wraps [surface] in an `ANativeWindow` and binds it to Rust preview [handle];
     * returns the window pointer (0 on failure). */
    private external fun bindPreviewSurface(surface: Surface, handle: Long): Long

    companion object {
        private const val CHANNEL = "aperturex/preview_texture"
        private const val ROI_CHANNEL = "aperturex/roi_decode"
        private const val NATIVE_CHANNEL = "aperturex/native_log"

        init {
            System.loadLibrary("rust_lib_aperturex")
        }
    }
}
