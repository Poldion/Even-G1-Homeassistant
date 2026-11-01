package io.github.poldion.even_g1_ha

import android.app.Notification
import android.content.pm.PackageManager
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
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val target = sink ?: return
        if (sbn.packageName == packageName) return

        val notification = sbn.notification
        val flags = notification.flags
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

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        synchronized(lastContent) { lastContent.remove(sbn.key) }
    }

    private fun appLabel(pkg: String): String = try {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (e: PackageManager.NameNotFoundException) {
        pkg
    }
}
