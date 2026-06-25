package com.mugenstream.anime_stream

import android.content.Context
import android.media.MediaPlayer
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder

/**
 * Live wallpaper that loops a (muted) video. The video file path is written to
 * SharedPreferences by [MainActivity.setLiveWallpaper] before the system live-
 * wallpaper picker binds this service.
 */
class VideoWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = VideoEngine()

    inner class VideoEngine : WallpaperService.Engine() {
        private var player: MediaPlayer? = null

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            val path = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PATH, null) ?: return
            try {
                player = MediaPlayer().apply {
                    setSurface(holder.surface)
                    setDataSource(path)
                    isLooping = true
                    setVolume(0f, 0f)
                    setOnPreparedListener { mp -> if (isVisible) mp.start() }
                    prepareAsync()
                }
            } catch (_: Exception) {
                releasePlayer()
            }
        }

        override fun onVisibilityChanged(visible: Boolean) {
            try {
                if (visible) player?.start() else player?.pause()
            } catch (_: Exception) {
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            releasePlayer()
        }

        override fun onDestroy() {
            super.onDestroy()
            releasePlayer()
        }

        private fun releasePlayer() {
            try {
                player?.release()
            } catch (_: Exception) {
            }
            player = null
        }
    }

    companion object {
        const val PREFS = "wallpaper_prefs"
        const val KEY_PATH = "video_path"
    }
}
