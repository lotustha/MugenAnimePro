package com.mugenstream.anime_stream

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "mugen/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWallpaper" -> setWallpaper(call.argument<String>("path"),
                        call.argument<Int>("which") ?: 0, result)
                    else -> result.notImplemented()
                }
            }
    }

    /** which: 0 = home, 1 = lock, 2 = both. */
    private fun setWallpaper(path: String?, which: Int, result: MethodChannel.Result) {
        if (path == null) {
            result.error("NO_PATH", "Missing image path", null)
            return
        }
        try {
            val bitmap = BitmapFactory.decodeFile(path)
                ?: throw IllegalStateException("Could not decode image")
            val wm = WallpaperManager.getInstance(applicationContext)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val flag = when (which) {
                    1 -> WallpaperManager.FLAG_LOCK
                    2 -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    else -> WallpaperManager.FLAG_SYSTEM
                }
                wm.setBitmap(bitmap, null, true, flag)
            } else {
                wm.setBitmap(bitmap)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_FAILED", e.message, null)
        }
    }
}
