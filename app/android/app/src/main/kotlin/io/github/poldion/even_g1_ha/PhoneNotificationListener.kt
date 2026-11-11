package io.github.poldion.even_g1_ha

import android.app.Notification
import android.content.ComponentName
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Receives the phone's notifications and hands them to Flutter, which
 * forwards them to the glasses. Runs in the app process; while Flutter is
 * not listening (app not running) notifications are simply dropped.
 */
class PhoneNotificationListener : NotificationListenerService() {

    companion object {
        /** Set by MainActivity while Flutter listens. */
        @Volatile
        var sink: EventChannel.EventSink? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        /** Last forwarded content per notification key, to drop repeated updates. */
        private val lastContent = HashMap<String, String>()

        /** Apps whose ongoing navigation notification goes to the glasses. */
        private val navigationApps = setOf("com.google.android.apps.maps")

        /** Side of the arrow icon sent with a navigation step (4 bpp). */
        private const val ICON = 50

        /** The notification key of the navigation shown, if any. */
        @Volatile
        private var navigationKey: String? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val target = sink ?: return
        if (sbn.packageName == packageName) return

        val notification = sbn.notification
        val flags = notification.flags
        if (sbn.packageName in navigationApps && sbn.isOngoing && isNavigation(notification)) {
            postNavigation(sbn, target)
            return
        }
        // Ongoing (music, navigation, downloads, our own service) and group
        // summaries would flood the glasses.
        if (sbn.isOngoing || (flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        if ((flags and Notification.FLAG_LOCAL_ONLY) != 0) return
        if (notification.category == Notification.CATEGORY_PROGRESS ||
            notification.category == Notification.CATEGORY_TRANSPORT ||
            notification.category == Notification.CATEGORY_SERVICE
        ) return

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty()) return

        val content = "$title\u0000$text"
        synchronized(lastContent) {
            if (lastContent[sbn.key] == content) return
            lastContent[sbn.key] = content
            if (lastContent.size > 200) lastContent.clear()
        }

        val event = hashMapOf<String, Any>(
            "key" to sbn.key,
            "package" to sbn.packageName,
            "app" to appLabel(sbn.packageName),
            "title" to title,
            "text" to text,
            "subText" to subText,
            "postTime" to sbn.postTime,
        )
        mainHandler.post { target.success(event) }
    }

    override fun onListenerDisconnected() {
        // Android may unbind the listener (e.g. memory pressure); without a
        // rebind it stays silent until access is toggled again.
        requestRebind(ComponentName(this, PhoneNotificationListener::class.java))
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        synchronized(lastContent) { lastContent.remove(sbn.key) }
        if (sbn.key == navigationKey) {
            navigationKey = null
            val target = sink ?: return
            val event = hashMapOf<String, Any>("type" to "navigationEnd", "key" to sbn.key)
            mainHandler.post { target.success(event) }
        }
    }

    /** Google Maps' turn-by-turn notification (not e.g. location sharing). */
    private fun isNavigation(n: Notification): Boolean =
        n.category == "navigation" ||
            (n.channelId ?: "").contains("nav", ignoreCase = true)

    /** A navigation step: its texts and the turn arrow (50 x 50, 4 bpp). */
    private fun postNavigation(sbn: StatusBarNotification, target: EventChannel.EventSink) {
        val n = sbn.notification
        val extras = n.extras
        fun text(key: String) = extras.getCharSequence(key)?.toString()?.trim().orEmpty()
        val title = text(Notification.EXTRA_TITLE)
        val body = text(Notification.EXTRA_BIG_TEXT).ifEmpty { text(Notification.EXTRA_TEXT) }
        val subText = text(Notification.EXTRA_SUB_TEXT)
        if (title.isEmpty() && body.isEmpty()) return
        val icon = arrowIcon(n)
        val content = "$title\u0000$body\u0000$subText\u0000${icon?.contentHashCode()}"
        synchronized(lastContent) {
            if (lastContent[sbn.key] == content) return
            lastContent[sbn.key] = content
        }
        navigationKey = sbn.key
        val event = hashMapOf<String, Any>(
            "type" to "navigation",
            "key" to sbn.key,
            "title" to title,
            "text" to body,
            "subText" to subText,
        )
        if (icon != null) event["icon"] = icon
        mainHandler.post { target.success(event) }
    }

    /**
     * The notification's large icon (Maps: the next turn) as 50 x 50 pixels
     * at 4 bpp, the left pixel in the high nibble: light where the icon is
     * opaque (or light, for an icon without transparency).
     */
    private fun arrowIcon(n: Notification): ByteArray? {
        val drawable = try {
            n.getLargeIcon()?.loadDrawable(this)
        } catch (e: Exception) {
            null
        } ?: return null
        val bitmap = Bitmap.createBitmap(ICON, ICON, Bitmap.Config.ARGB_8888)
        val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: ICON
        val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: ICON
        val scale = minOf(ICON.toFloat() / w, ICON.toFloat() / h)
        val dw = (w * scale).toInt().coerceAtLeast(1)
        val dh = (h * scale).toInt().coerceAtLeast(1)
        drawable.setBounds((ICON - dw) / 2, (ICON - dh) / 2, (ICON - dw) / 2 + dw, (ICON - dh) / 2 + dh)
        drawable.draw(Canvas(bitmap))
        val pixels = IntArray(ICON * ICON)
        bitmap.getPixels(pixels, 0, ICON, 0, 0, ICON, ICON)
        bitmap.recycle()
        val transparent = pixels.any { (it ushr 24) < 250 }
        val out = ByteArray(ICON * ICON / 2)
        var any = false
        for (i in pixels.indices) {
            val c = pixels[i]
            val a = c ushr 24
            val luma = (299 * (c shr 16 and 0xff) + 587 * (c shr 8 and 0xff) + 114 * (c and 0xff)) / 1000
            val v = if (transparent) a else luma
            val level = (v * 15 + 127) / 255
            if (level > 0) any = true
            val b = i / 2
            out[b] = if (i % 2 == 0) {
                (out[b].toInt() or (level shl 4)).toByte()
            } else {
                (out[b].toInt() or level).toByte()
            }
        }
        return if (any) out else null
    }

    private fun appLabel(pkg: String): String = try {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (e: PackageManager.NameNotFoundException) {
        pkg
    }
}
