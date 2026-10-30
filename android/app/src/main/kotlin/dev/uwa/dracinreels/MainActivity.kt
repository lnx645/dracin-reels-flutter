package dev.uwa.dracinreels

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.content.ContentValues
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Saluran updater: pemeriksaan izin, tanda tangan, unduhan, installer.
 *
 * Instal sunyi penuh TIDAK MUNGKIN untuk APK sideload — Android selalu
 * menampilkan installer sistem dan meminta satu ketukan "Instal".
 *
 * URUTAN YANG BENAR (perbaikan keluhan "unduh lalu kembali malah
 * unduh lagi"): izin instal diperiksa dari Dart SEBELUM unduhan
 * dimulai (canRequestPackageInstalls). Bila belum ada, aplikasi membuka
 * Pengaturan dulu; unduhan baru jalan sesudah izin diberikan.
 *
 * PRA-CEK TANDA TANGAN: sebelum installer dibuka, tanda tangan APK
 * baru dibandingkan dengan aplikasi terinstal. Bila berbeda, installer
 * TIDAK dibuka (pasti ditolak samar) — gantinya dialog panduan
 * uninstall sekali + salinan APK di folder Downloads (bertahan meski
 * aplikasi di-uninstall).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.uwa.dracinreels/updater"
    private val updateChannelId = "dracin_update"
    private val updateNotificationId = 9001
    private val notificationPermissionCode = 9002
    private var pendingPermissionResult: MethodChannel.Result? = null

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
                    "openAppSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "canRequestPackageInstalls" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "getInstalledSignatureSha256" -> {
                        result.success(installedSignatureSha256())
                    }
                    "getApkSignatureSha256" -> {
                        val path = call.arguments as? String
                        if (path.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            result.success(apkSignatureSha256(path))
                        }
                    }
                    "saveToDownloads" -> {
                        val path = call.arguments as? String
                        if (path.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            saveToDownloads(File(path), result)
                        }
                    }
                    "ensureNotificationPermission" -> {
                        ensureNotificationPermission(result)
                    }
                    "showDownloadNotification" -> {
                        val progress = (call.arguments as? Int) ?: -1
                        showDownloadNotification(progress)
                        result.success(null)
                    }
                    "hideDownloadNotification" -> {
                        hideDownloadNotification()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
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

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        return digest.digest(bytes).joinToString("") { "%02x".format(it) }
    }

    private fun installedSignatureSha256(): String? {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES,
                )
            }
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }
            val first = signatures?.firstOrNull() ?: return null
            sha256Hex(first.toByteArray())
        } catch (e: Exception) {
            null
        }
    }

    private fun apkSignatureSha256(path: String): String? {
        return try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                @Suppress("DEPRECATION")
                PackageManager.GET_SIGNATURES
            }
            val info = packageManager.getPackageArchiveInfo(path, flags)
                ?: return null
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }
            val first = signatures?.firstOrNull() ?: return null
            sha256Hex(first.toByteArray())
        } catch (e: Exception) {
            null
        }
    }

    private fun saveToDownloads(file: File, result: MethodChannel.Result) {
        try {
            val name = file.name
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(
                        MediaStore.Downloads.MIME_TYPE,
                        "application/vnd.android.package-archive",
                    )
                    put(
                        MediaStore.Downloads.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS,
                    )
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                )
                if (uri == null) {
                    result.success(null)
                    return
                }
                contentResolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { input -> input.copyTo(out) }
                }
                result.success("Downloads/$name")
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS,
                )
                dir.mkdirs()
                val dest = File(dir, name)
                file.copyTo(dest, overwrite = true)
                result.success(dest.absolutePath)
            }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionCode,
        )
    }

    private fun ensureUpdateChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(updateChannelId) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        updateChannelId,
                        "Update Dracin Reels",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = "Progres unduhan pembaruan aplikasi"
                    },
                )
            }
        }
    }

    private fun showDownloadNotification(progress: Int) {
        ensureUpdateChannel()
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, updateChannelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
        builder
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Mengunduh update Dracin Reels")
            .setContentText(
                if (progress < 0) {
                    "Menghubungkan ke server…"
                } else {
                    "Terunduh $progress%"
                },
            )
            .setProgress(100, progress.coerceIn(0, 100), progress < 0)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(updateNotificationId, builder.build())
    }

    private fun hideDownloadNotification() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(updateNotificationId)
    }
}
