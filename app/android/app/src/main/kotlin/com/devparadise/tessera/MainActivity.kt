package com.devparadise.tessera

import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Hosts spike B's zero-copy preview texture.
 *
 * Android owns a `SurfaceTexture`-backed texture from the Flutter
 * `TextureRegistry`; Dart drives creation/binding over the
 * [CHANNEL] method channel, and Rust ([bindPreviewSurface]) writes graded
 * frames straight into the surface's `ANativeWindow`. When this class is
 * absent (iOS/tests) every call degrades and Dart keeps the return-frame path.
 */
class MainActivity : FlutterActivity() {
    private val textures = mutableMapOf<Long, TextureRegistry.SurfaceTextureEntry>()

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
        val ptr = try {
            bindPreviewSurface(entry.surface(), handle)
        } catch (t: Throwable) {
            0L
        }
        result.success(ptr != 0L)
    }

    private fun disposeTexture(textureIdArg: Number?, result: MethodChannel.Result) {
        textures.remove(textureIdArg?.toLong())?.release()
        result.success(null)
    }

    override fun onDestroy() {
        for (entry in textures.values) entry.release()
        textures.clear()
        super.onDestroy()
    }

    /** Wraps [surface] in an `ANativeWindow` and binds it to Rust preview [handle];
     * returns the window pointer (0 on failure). */
    private external fun bindPreviewSurface(surface: Surface, handle: Long): Long

    companion object {
        private const val CHANNEL = "aperturex/preview_texture"

        init {
            System.loadLibrary("rust_lib_tessera")
        }
    }
}
