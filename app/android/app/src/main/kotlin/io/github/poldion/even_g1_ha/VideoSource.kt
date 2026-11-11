package io.github.poldion.even_g1_ha

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The hidden video player's source: lets the user pick a video, decodes its
 * frames to 1 bit per pixel at the size the glasses show (rows of
 * (width + 7) / 8 bytes, the leftmost pixel the high bit, set = light) and
 * plays its sound on the phone.
 */
class VideoSource(private val activity: Activity) {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pick: MethodChannel.Result? = null
    private var retriever: MediaMetadataRetriever? = null
    private var player: MediaPlayer? = null
    private var uri: Uri? = null
    private var width = 0
    private var height = 0
    private var fps = 15.0
    private var sourceFrames = 0
    private var sourceFps = 0.0
    private var durationUs = 0L
    private var threshold = 128
    private var invert = false

    // Frames decoded in order (API 28+): the next source index and a batch.
    private var nextSource = 0
    private val batch = ArrayDeque<Pair<Int, Bitmap>>()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> {
                pick = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("video/*")
                activity.startActivityForResult(intent, REQUEST)
            }
            "open" -> {
                val u = Uri.parse(call.argument<String>("uri") ?: "")
                val maxW = call.argument<Int>("maxWidth") ?: 480
                val maxH = call.argument<Int>("maxHeight") ?: 360
                val maxFps = call.argument<Double>("maxFps") ?: 15.0
                threshold = call.argument<Int>("threshold") ?: 128
                invert = call.argument<Boolean>("invert") ?: false
                background(result) { open(u, maxW, maxH, maxFps) }
            }
            "frames" -> {
                val start = call.argument<Int>("start") ?: 0
                val count = call.argument<Int>("count") ?: 1
                background(result) { frames(start, count) }
            }
            "audioStart" -> {
                val p = player
                if (p == null) {
                    result.success(false)
                } else {
                    p.start()
                    result.success(true)
                }
            }
            "audioStop" -> {
                audioStop()
                result.success(null)
            }
            "close" -> {
                audioStop()
                worker.execute { release() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** The picked document, from MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val r = pick ?: return true
        pick = null
        val u = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (u == null) {
            r.success(null)
            return true
        }
        r.success(mapOf("uri" to u.toString(), "name" to displayName(u)))
        return true
    }

    fun dispose() {
        audioStop()
        worker.execute { release() }
        worker.shutdown()
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("video", e.message ?: e.toString(), null) }
            }
        }
    }

    private fun displayName(u: Uri): String {
        activity.contentResolver.query(u, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) return c.getString(0) ?: "" }
        return u.lastPathSegment ?: ""
    }

    private fun open(u: Uri, maxW: Int, maxH: Int, maxFps: Double): Map<String, Any> {
        release()
        val r = MediaMetadataRetriever()
        r.setDataSource(activity, u)
        fun meta(key: Int) = r.extractMetadata(key)
        var vw = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        var vh = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val rotation = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        if (rotation == 90 || rotation == 270) vw = vh.also { vh = vw }
        val durationMs = meta(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        if (vw <= 0 || vh <= 0 || durationMs <= 0) {
            r.release()
            throw IllegalArgumentException("no video track")
        }
        durationUs = durationMs * 1000
        sourceFrames = if (Build.VERSION.SDK_INT >= 28) {
            meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)?.toIntOrNull() ?: 0
        } else {
            0
        }
        sourceFps = if (sourceFrames > 0) sourceFrames * 1000.0 / durationMs else 30.0
        fps = min(maxFps, sourceFps)
        val s = min(maxW.toDouble() / vw, maxH.toDouble() / vh)
        width = max(1, min(maxW, (vw * s).roundToInt()))
        height = max(1, min(maxH, (vh * s).roundToInt()))
        retriever = r
        uri = u
        nextSource = 0
        batch.clear()
        player = try {
            MediaPlayer().apply {
                setDataSource(activity, u)
                prepare()
            }
        } catch (e: Exception) {
            null
        }
        val frames = max(1, (durationUs / 1e6 * fps).toInt())
        return mapOf(
            "width" to width,
            "height" to height,
            "fps" to fps,
            "frames" to frames,
            "durationMs" to durationMs,
            "audio" to (player != null),
        )
    }

    /** [count] frames from [start] on, at the player's frame rate. */
    private fun frames(start: Int, count: Int): ByteArray {
        val r = retriever ?: throw IllegalStateException("not open")
        val nb = (width + 7) / 8
        val out = ByteArray(nb * height * count)
        val pixels = IntArray(width * height)
        for (k in 0 until count) {
            val t = (start + k) / fps
            val inOrder = Build.VERSION.SDK_INT >= 28 && sourceFrames > 0
            val bitmap = if (inOrder) {
                sequential(r, min(sourceFrames - 1, (t * sourceFps).toInt()))
            } else {
                r.getFrameAtTime((t * 1e6).toLong(), MediaMetadataRetriever.OPTION_CLOSEST)
            } ?: continue
            val small = Bitmap.createScaledBitmap(bitmap, width, height, true)
            small.getPixels(pixels, 0, width, 0, 0, width, height)
            if (small !== bitmap) small.recycle()
            if (!inOrder) bitmap.recycle()
            val o = k * nb * height
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val c = pixels[y * width + x]
                    val luma = (299 * (c shr 16 and 0xff) + 587 * (c shr 8 and 0xff) + 114 * (c and 0xff)) / 1000
                    if ((luma >= threshold) != invert) {
                        val i = o + y * nb + (x shr 3)
                        out[i] = (out[i].toInt() or (0x80 shr (x and 7))).toByte()
                    }
                }
            }
        }
        return out
    }

    /** Source frame [index], decoded in order in batches (fast on API 28+). */
    private fun sequential(r: MediaMetadataRetriever, index: Int): Bitmap? {
        if (Build.VERSION.SDK_INT < 28) return null
        while (batch.isNotEmpty() && batch.first().first < index) batch.removeFirst().second.recycle()
        if (batch.isEmpty() || index < nextSource - batch.size) {
            batch.forEach { it.second.recycle() }
            batch.clear()
            val first = max(index, 0)
            val n = min(BATCH, sourceFrames - first)
            if (n <= 0) return null
            val params = MediaMetadataRetriever.BitmapParams()
            params.preferredConfig = Bitmap.Config.RGB_565
            val list = r.getFramesAtIndex(first, n, params)
            list.forEachIndexed { i, b -> batch.addLast(first + i to b) }
            nextSource = first + n
        }
        return batch.firstOrNull { it.first == index }?.second
    }

    private fun audioStop() {
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
    }

    private fun release() {
        audioStop()
        batch.forEach { it.second.recycle() }
        batch.clear()
        retriever?.release()
        retriever = null
    }

    companion object {
        private const val REQUEST = 4711
        private const val BATCH = 6
    }
}
