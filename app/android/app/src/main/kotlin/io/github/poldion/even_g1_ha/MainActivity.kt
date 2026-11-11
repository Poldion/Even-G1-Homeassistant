package io.github.poldion.even_g1_ha

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val updater by lazy { AppUpdater(this) }
    private val video by lazy { VideoSource(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "even_g1/phone_notifications").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    PhoneNotificationListener.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    PhoneNotificationListener.sink = null
                }
            },
        )

        MethodChannel(messenger, "even_g1/notification_access").setMethodCallHandler { call, result ->
            when (call.method) {
                "isGranted" -> result.success(isNotificationAccessGranted())
                "openSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "even_g1/updater").setMethodCallHandler { call, result ->
            when (call.method) {
                "version" -> result.success(updater.versionName())
                "install" -> result.success(updater.download(call.argument<String>("url") ?: ""))
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "even_g1/video").setMethodCallHandler { call, result ->
            video.handle(call, result)
        }
    }

    override fun onResume() {
        super.onResume()
        updater.onResume()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!video.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        video.dispose()
        updater.onDestroy()
        super.onDestroy()
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        val me = ComponentName(this, PhoneNotificationListener::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == me }
    }
}
