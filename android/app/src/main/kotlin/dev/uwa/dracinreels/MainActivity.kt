package dev.uwa.dracinreels

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Saluran updater: membuka installer sistem untuk APK yang sudah diunduh.
 *
 * Instal sunyi penuh TIDAK MUNGKIN untuk APK sideload — Android selalu
 * menampilkan installer sistem dan meminta satu ketukan "Instal".
 * Bila izin "pasang dari sumber ini" belum aktif (Android 8+),
 * installApk mengembalikan "permission_required" dan aplikasi membuka
 * halaman pengaturan izin tersebut.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.uwa.dracinreels/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUpdatesDir" -> {
                        val dir = File(getExternalFilesDir(null), "updates")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    }
                    "installApk" -> {
                        val path = call.arguments as? String
                        if (path.isNullOrEmpty()) {
                            result.error("invalid_path", "Berkas APK tidak ada.", null)
                        } else {
                            installApk(File(path), result)
                        }
                    }
                    "openInstallSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(file: File, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.success("permission_required")
            return
        }
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        result.success("opened")
    }
}
