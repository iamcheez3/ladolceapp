package com.ladolce.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // In-app update (outside Google Play): see lib/services/app_update_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ladolce/app_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appVersion" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                        else @Suppress("DEPRECATION") info.versionCode.toLong()
                        result.success(mapOf("name" to info.versionName, "build" to code))
                    }
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        // "Install unknown apps" switch for this app (Android 8+).
                        if (Build.VERSION.SDK_INT >= 26) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !File(path).exists()) {
                            result.error("NO_FILE", "APK not found: $path", null)
                        } else {
                            val uri = FileProvider.getUriForFile(
                                this, "$packageName.appupdate", File(path)
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // Member card straight to one app (Instagram, Facebook, WhatsApp):
        // see lib/screens/share_card_screen.dart. Answers false when that app
        // is not installed, so Dart falls back to the system share sheet.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ladolce/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareImageToApp" -> {
                        val path = call.argument<String>("path")
                        val target = call.argument<String>("package")
                        if (path == null || target == null || !File(path).exists()) {
                            result.error("NO_FILE", "Image not found: $path", null)
                        } else {
                            val uri = FileProvider.getUriForFile(
                                this, "$packageName.appupdate", File(path)
                            )
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                call.argument<String>("text")?.let { putExtra(Intent.EXTRA_TEXT, it) }
                                setPackage(target)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
