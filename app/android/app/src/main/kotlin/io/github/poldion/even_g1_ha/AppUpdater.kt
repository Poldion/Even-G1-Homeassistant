package io.github.poldion.even_g1_ha

import android.app.Activity
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.widget.Toast
import java.io.File

/**
 * Downloads a release APK and opens the system installer (same approach as
 * the BasaltNotes app). Android only installs it as an update if it is signed
 * with the same key as the installed app.
 */
class AppUpdater(private val activity: Activity) {

    companion object {
        /** Only APKs from this repository's releases are installed. */
        const val DOWNLOAD_PREFIX =
            "https://github.com/Poldion/Even-G1-Homeassistant/releases/download/"
        private const val APK_NAME = "update.apk"
    }

    private var downloadId = -1L
    private var readyToInstall: Uri? = null
    private var receiver: BroadcastReceiver? = null

    fun versionName(): String =
        activity.packageManager.getPackageInfo(activity.packageName, 0).versionName ?: ""

    /** Returns false if the URL is not one of our release downloads. */
    fun download(url: String): Boolean {
        if (!url.startsWith(DOWNLOAD_PREFIX) || !url.endsWith(".apk")) return false
        File(activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), APK_NAME).delete()
        val dm = activity.getSystemService(DownloadManager::class.java)
        if (receiver == null) {
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1) == downloadId) {
                        downloaded()
                    }
                }
            }
            val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                activity.registerReceiver(receiver, filter)
            }
        }
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("Even G1 HA – Update")
            .setMimeType("application/vnd.android.package-archive")
            .setDestinationInExternalFilesDir(activity, Environment.DIRECTORY_DOWNLOADS, APK_NAME)
        downloadId = dm.enqueue(request)
        toast("Update wird geladen …")
        return true
    }

    private fun downloaded() {
        val dm = activity.getSystemService(DownloadManager::class.java)
        var ok = false
        dm.query(DownloadManager.Query().setFilterById(downloadId))?.use { c ->
            if (c.moveToFirst()) {
                ok = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)) ==
                    DownloadManager.STATUS_SUCCESSFUL
            }
        }
        if (!ok) {
            toast("Das Update konnte nicht geladen werden.")
            return
        }
        readyToInstall = dm.getUriForDownloadedFile(downloadId)
        installIfAllowed()
    }

    /** First update: Android asks once whether this app may install apps; continues in onResume. */
    private fun installIfAllowed() {
        val apk = readyToInstall ?: return
        if (!activity.packageManager.canRequestPackageInstalls()) {
            toast("Bitte „Apps aus dieser Quelle zulassen“ aktivieren und zurückkehren.")
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
            return
        }
        readyToInstall = null
        activity.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(apk, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    fun onResume() {
        if (readyToInstall != null && activity.packageManager.canRequestPackageInstalls()) {
            installIfAllowed()
        }
    }

    fun onDestroy() {
        receiver?.let { activity.unregisterReceiver(it) }
        receiver = null
    }

    private fun toast(text: String) {
        Toast.makeText(activity, text, Toast.LENGTH_LONG).show()
    }
}
