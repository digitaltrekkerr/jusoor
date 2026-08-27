package com.digitaltrekkerr.jusoor

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

const val ACTION_SHOW_OVERLAY = "com.digitaltrekkerr.jusoor.SHOW_OVERLAY"

class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "MainActivity"
        var clipboardCache: String = ""
        var clipboardCacheTimestamp: Long = 0L
        const val CACHE_TTL_MS = 60 * 1000L
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001

        /** 50 MB ceiling for shared-file reads, matching the Dart side. */
        private const val MAX_SHARED_FILE_BYTES: Long = 50L * 1024L * 1024L
    }

    private val CHANNEL = "dev.flutter.org/overlay_permission"
    private val OVERLAY_CHANNEL = "x-slayer/overlay"
    private val SHARE_CHANNEL = "dev.flutter.org/share"
    private var clipboardManager: ClipboardManager? = null
    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        cacheClipboard()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clipboardManager =
            getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume — caching clipboard")
        cacheClipboard()
        clipboardManager?.addPrimaryClipChangedListener(clipboardListener)
    }

    override fun onPause() {
        super.onPause()
        clipboardManager?.removePrimaryClipChangedListener(clipboardListener)
    }

    override fun onDestroy() {
        // Do not let clipboard content outlive the activity (audit L-2).
        clipboardManager?.removePrimaryClipChangedListener(clipboardListener)
        clipboardCache = ""
        clipboardCacheTimestamp = 0L
        super.onDestroy()
    }

    private fun cacheClipboard() {
        try {
            val clipData = clipboardManager?.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val text = clipData.getItemAt(0).text?.toString() ?: ""
                if (text.isNotEmpty()) {
                    clipboardCache = text
                    clipboardCacheTimestamp = System.currentTimeMillis()
                    if (BuildConfig.DEBUG) {
                        Log.d(TAG, "Clipboard cached: ${text.length} chars")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cache clipboard", e)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.i(TAG, "POST_NOTIFICATIONS permission granted")
            } else {
                Log.w(TAG, "POST_NOTIFICATIONS permission denied")
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
    }

    private fun showOverlay(): Boolean {
        Log.i(TAG, "Starting overlay service")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Overlay permission not granted")
            return false
        }
        
        val serviceIntent = Intent(this, TranslationOverlayService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.i(TAG, "Overlay service started successfully")
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException starting overlay service", e)
            return false
        } catch (e: RuntimeException) {
            Log.e(TAG, "RuntimeException starting overlay service", e)
            return false
        }
    }

    private fun getFullScreenHeight(): Int {
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val displayMetrics = DisplayMetrics()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return bounds.height()
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(displayMetrics)
            return displayMetrics.heightPixels
        }
    }

    private fun getNavBarHeight(): Int {
        val resources = resources
        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    private fun getStatusBarHeight(): Int {
        val resources = resources
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkOverlayPermission" -> {
                        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        }
                        result.success(hasPermission)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }
                    "checkNotificationPermission" -> {
                        // NotificationManagerCompat handles pre-O devices gracefully
                        // (returns true when the runtime permission does not exist).
                        // For Android 13+ this reflects whether POST_NOTIFICATIONS
                        // is granted; on older versions it tracks the global
                        // notifications-enabled switch in system settings.
                        val granted = NotificationManagerCompat.from(this).areNotificationsEnabled()
                        result.success(granted)
                    }
                    "getScreenDimensions" -> {
                        val fullHeight = getFullScreenHeight()
                        val navBarHeight = getNavBarHeight()
                        val statusBarHeight = getStatusBarHeight()
                        val resultData = mapOf(
                            "fullHeight" to fullHeight,
                            "navBarHeight" to navBarHeight,
                            "statusBarHeight" to statusBarHeight
                        )
                        Log.d(TAG, "Screen dimensions: fullHeight=$fullHeight, navBar=$navBarHeight, statusBar=$statusBarHeight")
                        result.success(resultData)
                    }
                    "getSupportedAbis" -> {
                        // Ordered by the system's preference; pick the first
                        // entry that matches a published APK variant so the
                        // update checker downloads the right split-per-abi
                        // artifact instead of guessing.
                        result.success(Build.SUPPORTED_ABIS.toList())
                    }
                    "setWindowFullScreen" -> {
                        try {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                            )
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                window.setDecorFitsSystemWindows(false)
                            } else {
                                @Suppress("DEPRECATION")
                                window.decorView.systemUiVisibility = (
                                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                                )
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to set full screen mode", e)
                            result.success(false)
                        }
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST_CODE
                            )
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to open app settings", e)
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val success = showOverlay()
                        result.success(success)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readContentUri" -> {
                        val uri = call.arguments as String
                        try {
                            val parsed = android.net.Uri.parse(uri)
                            // Size ceiling: refuse to read shared files over
                            // 50 MB so a giant content URI never OOMs the
                            // process. Read the descriptor length before
                            // loading bytes into memory.
                            val afd = contentResolver.openAssetFileDescriptor(parsed, "r")
                            if (afd == null) {
                                result.error(
                                    "READ_ERROR",
                                    "Failed to open content URI: $uri",
                                    null
                                )
                            } else {
                                afd.use { descriptor ->
                                    val length = descriptor.length
                                    if (length > MAX_SHARED_FILE_BYTES) {
                                        result.error(
                                            "FILE_TOO_LARGE",
                                            "Shared file exceeds 50 MB limit",
                                            length
                                        )
                                    } else {
                                        val bytes = descriptor
                                            .createInputStream()
                                            .buffered()
                                            .readBytes()
                                        result.success(bytes)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to read content URI: $uri", e)
                            result.error("READ_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}