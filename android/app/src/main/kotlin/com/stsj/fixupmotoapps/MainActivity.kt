package com.stsj.fixupmotoapps

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannel()
    }

    /**
     * The channel pushes arrive on (Android 8+). Without a high-importance one
     * of its own, Firebase files them under a generic "Miscellaneous" channel
     * that makes a sound but never pops up as a banner. The id must match
     * `default_notification_channel_id` in AndroidManifest.xml. Creating a
     * channel that already exists changes nothing, so running this on every
     * start is safe; once created, the member controls it in system settings.
     */
    private fun createPushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID,
            "Notifikasi FixUp Moto",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Info booking, servis, dan promo dari FixUp Moto"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // "Buka" on the receipt snackbar (receipt_storage_data_source.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECEIPT_VIEWER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPdf" -> {
                        val location = call.argument<String>("location")
                        if (location == null) {
                            result.error("InvalidArgument", "location is required", null)
                        } else {
                            result.success(openPdf(location))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Shows the PDF at [location], a `content://` URI the app itself saved into
     * Downloads. The read grant lets the viewer open it without any storage
     * permission of its own. Returns false when no app on the phone shows PDFs.
     */
    private fun openPdf(location: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(location), "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private companion object {
        const val PUSH_CHANNEL_ID = "fixup_moto_default"
        const val RECEIPT_VIEWER_CHANNEL = "com.stsj.fixupmotoapps/receipt_viewer"
    }
}
