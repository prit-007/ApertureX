package com.devparadise.tessera

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
 * Android owns a `SurfaceTexture`-backed texture from the Flutter
 * `TextureRegistry`; Dart drives creation/binding over the [CHANNEL] method
 * channel, and Rust ([bindPreviewSurface]) writes graded frames straight into
 * the surface's `ANativeWindow`. When this class is absent (iOS/tests) every
 * call degrades and Dart keeps the return-frame path.
 *
 * [ROI_CHANNEL] decodes full-width source bands with `BitmapRegionDecoder`
 * so a >100 MP frame never materialises as a full RGBA buffer; any failure
 * raises a `PlatformException` and Dart falls back to the in-process Rust
 * decoder.
 */
class MainActivity : FlutterActivity() {
    private val textures = mutableMapOf<Long, TextureRegistry.SurfaceTextureEntry>()
    private val surfaces = mutableMapOf<Long, Surface>()
    private val roiExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "create" -> createTexture(flutterEngine, call.argument("width"), call.argument("height"), result)
                    "bind" -> bindTexture(call.argument("textureId"), call.argument("handle"), result)
                    "dispose" -> disposeTexture(call.argument("textureId"), result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROI_CHANNEL)
            .setMethodCallHandler { call, result ->
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
            }
    }

    private fun createTexture(flutterEngine: FlutterEngine, widthArg: Int?, heightArg: Int?, result: MethodChannel.Result) {
        val width = widthArg ?: 1
        val height = heightArg ?: 1
        try {
            val entry = flutterEngine.renderer.createSurfaceTexture()
            entry.surfaceTexture().setDefaultBufferSize(width, height)
            textures[entry.id()] = entry
            result.success(entry.id().toInt())
        } catch (t: Throwable) {
            result.error("create_failed", t.message, null)
        }
    }

    private fun bindTexture(textureIdArg: Number?, handleArg: Number?, result: MethodChannel.Result) {
        val entry = textures[textureIdArg?.toLong()]
        if (entry == null) {
            result.success(false)
            return
        }
        val handle = handleArg?.toLong() ?: -1L
        // `SurfaceTextureEntry` exposes only `surfaceTexture()` (no `surface()`
        // in the embedding); wrap it in a Surface the way the producer would.
        val surface = surfaces.getOrPut(entry.id()) { Surface(entry.surfaceTexture()) }
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
            textures.remove(id)?.release()
            surfaces.remove(id)?.release()
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
        for (surface in surfaces.values) surface.release()
        surfaces.clear()
        for (entry in textures.values) entry.release()
        textures.clear()
        super.onDestroy()
    }

    /** Wraps [surface] in an `ANativeWindow` and binds it to Rust preview [handle];
     * returns the window pointer (0 on failure). */
    private external fun bindPreviewSurface(surface: Surface, handle: Long): Long

    companion object {
        private const val CHANNEL = "aperturex/preview_texture"
        private const val ROI_CHANNEL = "aperturex/roi_decode"

        init {
            System.loadLibrary("rust_lib_tessera")
        }
    }
}
