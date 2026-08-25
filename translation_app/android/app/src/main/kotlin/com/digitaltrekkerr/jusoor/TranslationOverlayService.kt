package com.digitaltrekkerr.jusoor

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Point
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Choreographer
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.widget.Toast
import androidx.annotation.Nullable
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

const val ACTION_OVERLAY_CLOSED = "com.digitaltrekkerr.jusoor.OVERLAY_CLOSED"
const val ACTION_STOP_SERVICE = "com.digitaltrekkerr.jusoor.STOP_SERVICE"

@SuppressLint("Wakelock")
class TranslationOverlayService : Service(), View.OnTouchListener {
    companion object {
        private const val TAG = "TranslationOverlay"
        private const val CHANNEL_ID = "TranslationOverlayChannel"
        private const val NOTIFICATION_ID = 8924
        private const val CACHED_TAG = "translationOverlayEngine"
        private const val SCREENSHOT_CHANNEL = "dev.flutter.org/screenshot"
        private const val PROJECTION_RESULT_ACTION = "com.digitaltrekkerr.jusoor.PROJECTION_RESULT"
        private const val ACTION_CLIPBOARD_RESULT = "com.digitaltrekkerr.jusoor.CLIPBOARD_RESULT"
        private const val DEFAULT_NAV_BAR_HEIGHT_DP = 48
        private const val DEFAULT_STATUS_BAR_HEIGHT_DP = 25
    }

    private var statusBarHeight = -1
    private var navigationBarHeight = -1
    private lateinit var resources: Resources

    private var windowManager: WindowManager? = null
    private var scrimView: View? = null
    private var navBarSentinel: View? = null
    private var flutterView: FlutterView? = null
    private var flutterChannel: MethodChannel? = null
    private var overlayMessageChannel: BasicMessageChannel<Any>? = null
    private var screenshotChannel: MethodChannel? = null

    private var flutterParams: WindowManager.LayoutParams? = null
    private var scrimParams: WindowManager.LayoutParams? = null
    private var navBarParams: WindowManager.LayoutParams? = null

    private var lastX = 0f
    private var lastY = 0f
    private var dragging = false
    private val windowSize = Point()

    private var isHidden = false
    private var hasWindowFocus = true
    private var isFocusable = false
    private var systemDialogReceiver: BroadcastReceiver? = null
    private var stopServiceReceiver: BroadcastReceiver? = null
    private var projectionResultReceiver: BroadcastReceiver? = null

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var pendingScreenshotResult: MethodChannel.Result? = null
    private var isWaitingForProjection = false
    private var isRequestingMediaProjection = false
    private var isScreenshotInProgress = false
    private var overlayClosedByUser = false
    private var isReadingClipboard = false
    private var pendingClipboardResult: MethodChannel.Result? = null
    private var clipboardResultReceiver: BroadcastReceiver? = null
    private var captureThread: HandlerThread? = null
    private var captureHandler: Handler? = null

    private val windowFocusListener = ViewTreeObserver.OnWindowFocusChangeListener { hasFocus ->
        Log.d(TAG, "Window focus changed: hasFocus=$hasFocus, isHidden=$isHidden, isRequestingMediaProjection=$isRequestingMediaProjection, isScreenshotInProgress=$isScreenshotInProgress, isReadingClipboard=$isReadingClipboard")
        if (!hasFocus && !isHidden && hasWindowFocus && !isRequestingMediaProjection && !isScreenshotInProgress && !isReadingClipboard) {
            Log.d(TAG, "Lost focus while not hidden - closing overlay")
            hasWindowFocus = false
            closeOverlay()
        } else if (hasFocus) {
            hasWindowFocus = true
        }
    }

    @Nullable
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        resources = applicationContext.resources

        captureThread = HandlerThread("ScreenshotCapture")
        captureThread?.start()
        captureHandler = captureThread?.looper?.let { Handler(it) }

        var engine = FlutterEngineCache.getInstance().get(CACHED_TAG)
        if (engine == null) {
            Log.e(TAG, "Flutter engine not found, creating new one")
            val engineGroup = FlutterEngineGroup(this)
            val entryPoint = DartExecutor.DartEntrypoint(
                io.flutter.FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain"
            )
            engine = engineGroup.createAndRunEngine(this, entryPoint)
            FlutterEngineCache.getInstance().put(CACHED_TAG, engine)
        }

        if (engine != null) {
            flutterChannel = MethodChannel(engine.dartExecutor, "x-slayer/overlay")
            overlayMessageChannel = BasicMessageChannel(engine.dartExecutor, "x-slayer/overlay_messenger", JSONMessageCodec.INSTANCE)
            screenshotChannel = MethodChannel(engine.dartExecutor, SCREENSHOT_CHANNEL)
            screenshotChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureScreen" -> captureScreen(result)
                    "hasMediaProjection" -> result.success(mediaProjection != null)
                    else -> result.notImplemented()
                }
            }
        }

        registerReceivers()
        createNotificationChannel()
        startForegroundCompat(NOTIFICATION_ID, createNotification())
    }

    @Suppress("UnspecifiedRegisterReceiverFlag")
    private fun safeRegisterReceiver(
        receiver: BroadcastReceiver?,
        filter: IntentFilter?,
        exportBehavior: Int
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, exportBehavior)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun registerReceivers() {
        try {
            val dialogFilter = IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            systemDialogReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (Intent.ACTION_CLOSE_SYSTEM_DIALOGS == intent?.action) {
                        if (isRequestingMediaProjection || isScreenshotInProgress) {
                            Log.d(TAG, "System dialog closing - ignored (screenshot/projection in progress)")
                            return
                        }
                        Log.d(TAG, "System dialog closing - Home/Recents pressed, closing overlay")
                        closeOverlay()
                    }
                }
            }
            // ACTION_CLOSE_SYSTEM_DIALOGS is a system broadcast — the system
            // delivers it even to NOT_EXPORTED receivers, and no third-party
            // app needs to trigger this receiver directly.
            safeRegisterReceiver(systemDialogReceiver, dialogFilter, RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Registered system dialog receiver")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register system dialog receiver", e)
        }

        try {
            val stopFilter = IntentFilter(ACTION_STOP_SERVICE)
            stopServiceReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (ACTION_STOP_SERVICE == intent?.action) {
                        Log.d(TAG, "Stop service requested")
                        stopServiceCompletely()
                    }
                }
            }
            safeRegisterReceiver(stopServiceReceiver, stopFilter, RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Registered stop service receiver")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register stop service receiver", e)
        }

        try {
            val projectionFilter = IntentFilter(PROJECTION_RESULT_ACTION)
            projectionResultReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (PROJECTION_RESULT_ACTION == intent?.action) {
                        val resultCode = intent.getIntExtra("resultCode", 0)
                        val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra("data", Intent::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra<Intent>("data")
                        }
                        onProjectionResult(resultCode, data)
                    }
                }
            }
            safeRegisterReceiver(projectionResultReceiver, projectionFilter, RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Registered projection result receiver")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register projection result receiver", e)
        }

        try {
            val clipboardFilter = IntentFilter(ACTION_CLIPBOARD_RESULT)
            clipboardResultReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (ACTION_CLIPBOARD_RESULT == intent?.action) {
                        val text = intent.getStringExtra("text") ?: ""
                        if (BuildConfig.DEBUG) {
                            Log.d("ClipboardDebug", "served via: relay, ${text.length} chars")
                        }
                        pendingClipboardResult?.success(mapOf(
                            "text" to text,
                            "source" to "relay",
                            "timestamp" to System.currentTimeMillis(),
                            "stale" to false
                        ))
                        pendingClipboardResult = null
                        isReadingClipboard = false
                    }
                }
            }
            safeRegisterReceiver(clipboardResultReceiver, clipboardFilter, RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Registered clipboard result receiver")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register clipboard result receiver", e)
        }
    }

    private fun unregisterReceivers() {
        try {
            systemDialogReceiver?.let {
                unregisterReceiver(it)
                systemDialogReceiver = null
                Log.d(TAG, "Unregistered system dialog receiver")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister system dialog receiver", e)
        }

        try {
            stopServiceReceiver?.let {
                unregisterReceiver(it)
                stopServiceReceiver = null
                Log.d(TAG, "Unregistered stop service receiver")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister stop service receiver", e)
        }

        try {
            projectionResultReceiver?.let {
                unregisterReceiver(it)
                projectionResultReceiver = null
                Log.d(TAG, "Unregistered projection result receiver")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister projection result receiver", e)
        }

        try {
            clipboardResultReceiver?.let {
                unregisterReceiver(it)
                clipboardResultReceiver = null
                Log.d(TAG, "Unregistered clipboard result receiver")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister clipboard result receiver", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun startForegroundCompat(notificationId: Int, notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Translation Overlay",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val mainIntent = Intent(this, MainActivity::class.java)
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val mainPendingIntent = PendingIntent.getActivity(this, 0, mainIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Translator Overlay")
            .setContentText("Translation overlay is active")
            .setSmallIcon(R.drawable.ic_translate_tile)
            .setContentIntent(mainPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")

        when {
            intent?.getBooleanExtra("stop", false) == true -> {
                stopServiceCompletely()
                return START_NOT_STICKY
            }
            intent?.getBooleanExtra("close", false) == true -> {
                closeOverlay()
                if (!isScreenshotInProgress) {
                    stopSelf()
                }
                return START_NOT_STICKY
            }
            intent?.getBooleanExtra("hide", false) == true -> {
                hideOverlay()
                return START_STICKY
            }
        }

        if (isHidden && flutterView != null) {
            showOverlayAfterHide()
            return START_STICKY
        }

        showOverlay()
        return START_STICKY
    }

    private fun requestMediaProjection() {
        if (mediaProjection != null) {
            performCapture()
            return
        }

        if (isWaitingForProjection) {
            Log.d(TAG, "Already waiting for projection permission")
            return
        }

        Log.d(TAG, "Requesting MediaProjection permission")
        isWaitingForProjection = true
        isRequestingMediaProjection = true

        val intent = Intent(this, MediaProjectionRequestActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun onProjectionResult(resultCode: Int, data: Intent?) {
        Log.d(TAG, "onProjectionResult: resultCode=$resultCode")
        isWaitingForProjection = false
        isRequestingMediaProjection = false

        if (resultCode == android.app.Activity.RESULT_OK && data != null) {
            val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = manager.getMediaProjection(resultCode, data)

            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    Log.d(TAG, "MediaProjection stopped")
                    mediaProjection = null
                    releaseVirtualDisplay()
                }
            }, null)

            Log.i(TAG, "MediaProjection created successfully")
            performCapture()
            Toast.makeText(this, "Screen capture enabled", Toast.LENGTH_SHORT).show()
        } else {
            Log.e(TAG, "MediaProjection permission denied")
            isScreenshotInProgress = false
            if (!overlayClosedByUser) {
                setOverlayAlpha(1f)
            }
            pendingScreenshotResult?.error("PERMISSION_DENIED", "Screen capture permission denied", null)
            pendingScreenshotResult = null
            Toast.makeText(this, "Screen capture permission denied", Toast.LENGTH_SHORT).show()
        }
    }

    private fun captureScreen(result: MethodChannel.Result) {
        if (pendingScreenshotResult != null) {
            result.error("IN_PROGRESS", "A screenshot is already being captured", null)
            return
        }
        pendingScreenshotResult = result
        isScreenshotInProgress = true

        setOverlayAlpha(0f)

        Choreographer.getInstance().postFrameCallback {
            Choreographer.getInstance().postFrameCallback {
                if (mediaProjection == null) {
                    requestMediaProjection()
                } else {
                    performCapture()
                }
            }
        }
    }

    private fun detachOverlayViews() {
        Log.d(TAG, "Detaching overlay views for screenshot")
        isHidden = true
        hasWindowFocus = false
        try {
            windowManager?.let { wm ->
                scrimView?.let {
                    wm.removeViewImmediate(it)
                    scrimView = null
                }
                navBarSentinel?.let {
                    wm.removeViewImmediate(it)
                    navBarSentinel = null
                }
                flutterView?.let {
                    it.viewTreeObserver?.removeOnWindowFocusChangeListener(windowFocusListener)
                    it.detachFromFlutterEngine()
                    wm.removeViewImmediate(it)
                    flutterView = null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error detaching overlay views", e)
        }
    }

    private fun performCapture() {
        if (mediaProjection == null) {
            Log.e(TAG, "performCapture: MediaProjection is null")
            isScreenshotInProgress = false
            if (!overlayClosedByUser) {
                setOverlayAlpha(1f)
            }
            pendingScreenshotResult?.error("NO_PROJECTION", "MediaProjection not available", null)
            pendingScreenshotResult = null
            return
        }

        val metrics = Resources.getSystem().displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        releaseVirtualDisplay()

        try {
            imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)

            val flags = DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC or DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "OverlayCapture",
                width, height, density,
                flags,
                imageReader!!.surface,
                null, null
            )
            Log.d(TAG, "VirtualDisplay created: ${width}x${height}")

            Handler(Looper.getMainLooper()).postDelayed({
                acquireImageWithRetry(3, width, height)
            }, 100)
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing screen", e)
            isScreenshotInProgress = false
            if (!overlayClosedByUser) {
                setOverlayAlpha(1f)
            }
            pendingScreenshotResult?.error("CAPTURE_ERROR", e.message, null)
            pendingScreenshotResult = null
        }
    }

    private fun acquireImageWithRetry(remainingRetries: Int, width: Int, height: Int) {
        val image = imageReader?.acquireLatestImage()
        
        if (image == null) {
            if (remainingRetries > 0) {
                Log.d(TAG, "No image available, retrying... ($remainingRetries retries left)")
                Handler(Looper.getMainLooper()).postDelayed({
                    acquireImageWithRetry(remainingRetries - 1, width, height)
                }, 50)
            } else {
                Log.e(TAG, "Failed to acquire image after all retries")
                isScreenshotInProgress = false
                if (!overlayClosedByUser) {
                    setOverlayAlpha(1f)
                }
                pendingScreenshotResult?.error("CAPTURE_FAILED", "Failed to acquire image", null)
                pendingScreenshotResult = null
            }
            return
        }

        val handler = captureHandler
        if (handler != null) {
            handler.post {
                try {
                    val planes = image.planes
                    val buffer = planes[0].buffer
                    val pixelStride = planes[0].pixelStride
                    val rowStride = planes[0].rowStride
                    val rowPadding = rowStride - pixelStride * width

                    val bitmapWidth = width + if (rowPadding > 0) rowPadding / pixelStride else 0
                    var bitmap = Bitmap.createBitmap(
                        bitmapWidth,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.copyPixelsFromBuffer(buffer)
                    image.close()

                    if (rowPadding > 0) {
                        val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                        bitmap.recycle()
                        bitmap = croppedBitmap
                    }

                    val outputStream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
                    val byteArray = outputStream.toByteArray()
                    bitmap.recycle()

                    if (BuildConfig.DEBUG) {
                        Log.d(TAG, "Screenshot captured: ${byteArray.size} bytes")
                    }

                    Handler(Looper.getMainLooper()).post {
                        releaseVirtualDisplay()
                        isScreenshotInProgress = false
                        if (!overlayClosedByUser) {
                            setOverlayAlpha(1f)
                        }

                        pendingScreenshotResult?.success(
                            mapOf(
                                "bytes" to byteArray,
                                "width" to width,
                                "height" to height
                            )
                        )
                        pendingScreenshotResult = null
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error processing screenshot", e)
                    image.close()
                    Handler(Looper.getMainLooper()).post {
                        releaseVirtualDisplay()
                        isScreenshotInProgress = false
                        if (!overlayClosedByUser) {
                            setOverlayAlpha(1f)
                        }
                        pendingScreenshotResult?.error("PROCESSING_ERROR", e.message, null)
                        pendingScreenshotResult = null
                    }
                }
            }
        } else {
            Log.e(TAG, "captureHandler is null, cannot process bitmap off main thread")
            image.close()
            releaseVirtualDisplay()
            isScreenshotInProgress = false
            if (!overlayClosedByUser) {
                setOverlayAlpha(1f)
            }
            pendingScreenshotResult?.error("CAPTURE_ERROR", "Capture thread not available", null)
            pendingScreenshotResult = null
        }
    }

    private fun releaseVirtualDisplay() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        Log.d(TAG, "VirtualDisplay released")
    }

    private fun hideOverlay() {
        Log.d(TAG, "Hiding overlay (temporary)")
        flutterView?.viewTreeObserver?.removeOnWindowFocusChangeListener(windowFocusListener)
        isHidden = true
        hasWindowFocus = false
        try {
            scrimView?.visibility = View.INVISIBLE
            navBarSentinel?.visibility = View.INVISIBLE
            flutterView?.visibility = View.INVISIBLE
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding overlay", e)
        }
    }

    private fun setOverlayAlpha(alpha: Float) {
        try {
            windowManager?.let { wm ->
                scrimView?.let { v -> scrimParams?.let { p -> p.alpha = alpha; wm.updateViewLayout(v, p) } }
                flutterView?.let { v -> flutterParams?.let { p -> p.alpha = alpha; wm.updateViewLayout(v, p) } }
                navBarSentinel?.let { v -> navBarParams?.let { p -> p.alpha = alpha; wm.updateViewLayout(v, p) } }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting overlay alpha", e)
        }
    }

    private fun showOverlayAfterHide() {
        Log.d(TAG, "Showing overlay after hide")
        isHidden = false

        if (flutterView == null || scrimView == null || navBarSentinel == null) {
            showOverlay()
            return
        }

        try {
            scrimView?.visibility = View.VISIBLE
            navBarSentinel?.visibility = View.VISIBLE
            flutterView?.visibility = View.VISIBLE
            flutterView?.viewTreeObserver?.addOnWindowFocusChangeListener(windowFocusListener)
            hasWindowFocus = true
            Log.d(TAG, "Overlay re-shown after hide")
        } catch (e: Exception) {
            Log.e(TAG, "Error re-showing overlay", e)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private fun showOverlay() {
        Log.d(TAG, "Showing overlay (fresh)")
        isHidden = false

        navBarSentinel?.let {
            windowManager?.removeViewImmediate(it)
        }
        flutterView?.let {
            windowManager?.removeViewImmediate(it)
        }
        scrimView?.let {
            windowManager?.removeViewImmediate(it)
        }
        navBarSentinel = null
        flutterView = null
        scrimView = null

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            windowManager?.defaultDisplay?.getSize(windowSize)
        } else {
            val dm = DisplayMetrics()
            windowManager?.defaultDisplay?.getMetrics(dm)
            windowSize.set(dm.widthPixels, dm.heightPixels)
        }

        val engine = FlutterEngineCache.getInstance().get(CACHED_TAG)
        if (engine != null) {
            engine.lifecycleChannel.appIsResumed()
        }

        flutterView = FlutterView(applicationContext, FlutterTextureView(applicationContext)).apply {
            val flutterEngine = engine
            if (flutterEngine != null) {
                attachToFlutterEngine(flutterEngine)
            }
            fitsSystemWindows = true
            isFocusable = true
            isFocusableInTouchMode = true
            setBackgroundColor(Color.TRANSPARENT)
        }

        flutterChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "close" -> {
                    closeOverlay()
                    result.success(true)
                }
                "hide" -> {
                    hideOverlay()
                    result.success(true)
                }
                "show" -> {
                    showOverlayAfterHide()
                    result.success(true)
                }
                "focusable" -> {
                    val focusable = call.argument<Boolean>("enable") ?: false
                    updateFlags(focusable)
                    result.success(true)
                }
                "readClipboard" -> {
                    if (pendingClipboardResult != null) {
                        Log.w(TAG, "Previous clipboard read still pending, rejecting")
                        result.error("BUSY", "A previous clipboard read is still in progress", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val clipboardManager = applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                        val clipData = clipboardManager.primaryClip
                        if (clipData != null && clipData.itemCount > 0) {
                            val text = clipData.getItemAt(0).text?.toString() ?: ""
                            if (BuildConfig.DEBUG) {
                                Log.d("ClipboardDebug", "served via: direct, ${text.length} chars")
                            }
                            result.success(mapOf(
                                "text" to text,
                                "source" to "direct",
                                "timestamp" to System.currentTimeMillis(),
                                "stale" to false
                            ))
                        } else {
                            Log.d(TAG, "Clipboard direct read null, trying relay Activity")
                            pendingClipboardResult = result
                            isReadingClipboard = true
                            val intent = Intent(this@TranslationOverlayService, OverlayRelayActivity::class.java).apply {
                                putExtra("action", "read_clipboard")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            startActivity(intent)
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (pendingClipboardResult != null) {
                                    val cacheText = MainActivity.clipboardCache
                                    if (cacheText.isNotEmpty()) {
                                        val ageMs = System.currentTimeMillis() - MainActivity.clipboardCacheTimestamp
                                        val isStale = ageMs > MainActivity.CACHE_TTL_MS
                                        pendingClipboardResult?.success(mapOf(
                                            "text" to cacheText,
                                            "source" to "cache",
                                            "timestamp" to MainActivity.clipboardCacheTimestamp,
                                            "stale" to isStale
                                        ))
                                    } else {
                                        pendingClipboardResult?.error("EMPTY", "Clipboard is empty", null)
                                    }
                                    pendingClipboardResult = null
                                    isReadingClipboard = false
                                }
                            }, 800)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to read clipboard", e)
                        val cacheText = MainActivity.clipboardCache
                        if (cacheText.isNotEmpty()) {
                            val ageMs = System.currentTimeMillis() - MainActivity.clipboardCacheTimestamp
                        if (BuildConfig.DEBUG) {
                            Log.d("ClipboardDebug", "served via: cache (exception fallback), age=${ageMs}ms")
                        }
                        val isStale = ageMs > MainActivity.CACHE_TTL_MS
                            result.success(mapOf(
                                "text" to cacheText,
                                "source" to "cache",
                                "timestamp" to MainActivity.clipboardCacheTimestamp,
                                "stale" to isStale
                            ))
                        } else {
                            result.error("CLIPBOARD_ERROR", e.message, null)
                        }
                        isReadingClipboard = false
                        pendingClipboardResult = null
                    }
                }
                "writeClipboard" -> {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        val clipboard = applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("translated", text))
                        if (BuildConfig.DEBUG) {
                            Log.d("ClipboardDebug", "write: ${text.length} chars")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to write clipboard", e)
                        result.error("CLIPBOARD_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        overlayMessageChannel?.setMessageHandler { _, _ -> }
        flutterView?.setOnTouchListener(this)

        flutterView?.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.d(TAG, "Back button pressed (DOWN) while focusable - closing overlay")
                    closeOverlay()
                    return@setOnKeyListener true
                }
                return@setOnKeyListener true
            }
            false
        }

        val overlayHeight = contentHeight()

        val scrimLayoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayHeight,
            0, 0,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )
        scrimLayoutParams.gravity = Gravity.TOP

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayHeight,
            0, 0,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP

        scrimView = View(this).apply {
            setBackgroundColor(Color.parseColor("#80000000"))
            setOnTouchListener(this@TranslationOverlayService)
        }

        val navBarHeight = navigationBarHeightPx()
        val navBarLayoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            navBarHeight,
            0, screenHeight() - navBarHeight,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        navBarLayoutParams.gravity = Gravity.TOP

        navBarSentinel = View(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setOnTouchListener { _, event ->
                Log.d(TAG, "Nav bar sentinel touched: action=${event.action}")
                if (event.action == MotionEvent.ACTION_DOWN || event.action == MotionEvent.ACTION_OUTSIDE) {
                    closeOverlay()
                    true
                } else false
            }
        }

        try {
            scrimParams = scrimLayoutParams
            navBarParams = navBarLayoutParams
            flutterParams = params
            windowManager?.addView(scrimView, scrimParams)
            windowManager?.addView(navBarSentinel, navBarParams)
            windowManager?.addView(flutterView, flutterParams)
            flutterView?.viewTreeObserver?.addOnWindowFocusChangeListener(windowFocusListener)
            Log.d(TAG, "Overlay added successfully with scrim and nav bar sentinel")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay", e)
        }
    }

    private fun updateFlags(focusable: Boolean) {
        try {
            val currentParams = flutterView?.layoutParams as? WindowManager.LayoutParams ?: return
            val newFlags = if (focusable) {
                currentParams.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
            } else {
                currentParams.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            }
            currentParams.flags = newFlags
            windowManager?.updateViewLayout(flutterView, currentParams)
            isFocusable = focusable
            Log.d(TAG, "Updated focusable: $focusable")

            if (focusable) {
                flutterView?.requestFocus()
                Log.d(TAG, "Requested focus on flutterView")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update flags", e)
        }
    }

    private fun closeOverlay() {
        Log.d(TAG, "Closing overlay, isScreenshotInProgress=$isScreenshotInProgress")
        overlayClosedByUser = true
        isHidden = false
        hasWindowFocus = true
        isFocusable = false
        try {
            scrimView?.let {
                windowManager?.removeViewImmediate(it)
            }
            navBarSentinel?.let {
                windowManager?.removeViewImmediate(it)
            }
            flutterView?.let {
                it.viewTreeObserver?.removeOnWindowFocusChangeListener(windowFocusListener)
                windowManager?.removeViewImmediate(it)
                it.detachFromFlutterEngine()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error closing overlay", e)
        }
        scrimView = null
        navBarSentinel = null
        flutterView = null
        windowManager = null

        if (!isScreenshotInProgress) {
            val closedIntent = Intent(ACTION_OVERLAY_CLOSED)
            sendBroadcast(closedIntent)
            Log.d(TAG, "No screenshot in progress, stopping service")
            stopSelf()
        } else {
            Log.d(TAG, "Screenshot in progress, keeping service alive")
        }
    }

    private fun stopServiceCompletely() {
        Log.d(TAG, "Stopping service completely")
        mediaProjection?.stop()
        mediaProjection = null
        releaseVirtualDisplay()
        closeOverlay()
        stopSelf()
    }

    private fun screenHeight(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager?.currentWindowMetrics?.bounds?.height() ?: 0
        } else {
            @Suppress("DEPRECATION")
            val dm = DisplayMetrics()
            windowManager?.defaultDisplay?.getRealMetrics(dm)
            dm.heightPixels
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private fun contentHeight(): Int {
        return screenHeight() - navigationBarHeightPx()
    }

    private fun statusBarHeightPx(): Int {
        if (statusBarHeight == -1) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                windowManager?.let { wm ->
                    val insets = wm.currentWindowMetrics.windowInsets.getInsets(
                        android.view.WindowInsets.Type.statusBars()
                    )
                    if (insets.top > 0) {
                        statusBarHeight = insets.top
                        return statusBarHeight
                    }
                }
            }
            val id = resources.getIdentifier("status_bar_height", "dimen", "android")
            statusBarHeight = if (id > 0) {
                resources.getDimensionPixelSize(id)
            } else {
                dpToPx(DEFAULT_STATUS_BAR_HEIGHT_DP)
            }
        }
        return statusBarHeight
    }

    private fun navigationBarHeightPx(): Int {
        if (navigationBarHeight == -1) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                windowManager?.let { wm ->
                    val insets = wm.currentWindowMetrics.windowInsets.getInsets(
                        android.view.WindowInsets.Type.navigationBars()
                    )
                    if (insets.bottom > 0) {
                        navigationBarHeight = insets.bottom
                        return navigationBarHeight
                    }
                }
            }
            val id = resources.getIdentifier("navigation_bar_height", "dimen", "android")
            navigationBarHeight = if (id > 0) {
                resources.getDimensionPixelSize(id)
            } else {
                dpToPx(DEFAULT_NAV_BAR_HEIGHT_DP)
            }
        }
        return navigationBarHeight
    }

    private fun dpToPx(dp: Int): Int {
        return (android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        )).toInt()
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy called")
        unregisterReceivers()
        mediaProjection?.stop()
        mediaProjection = null
        releaseVirtualDisplay()
        closeOverlay()

        flutterChannel = null
        overlayMessageChannel = null
        screenshotChannel?.setMethodCallHandler(null)
        screenshotChannel = null

        val engine = FlutterEngineCache.getInstance().get(CACHED_TAG)
        if (engine != null) {
            engine.destroy()
            FlutterEngineCache.getInstance().remove(CACHED_TAG)
        }

        captureThread?.quitSafely()
        captureThread = null
        captureHandler = null

        super.onDestroy()
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouch(view: View, event: MotionEvent): Boolean {
        Log.d(TAG, "onTouch action: ${event.action}, view: ${view::class.simpleName}, isHidden: $isHidden")
        if (isHidden) {
            return false
        }
        when (event.action) {
            MotionEvent.ACTION_OUTSIDE -> {
                Log.d(TAG, "ACTION_OUTSIDE detected - closing overlay")
                closeOverlay()
                return true
            }
            MotionEvent.ACTION_DOWN -> {
                dragging = false
                lastX = event.rawX
                lastY = event.rawY
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - lastX
                val dy = event.rawY - lastY
                if (!dragging && dx * dx + dy * dy < 25) {
                    return false
                }
                lastX = event.rawX
                lastY = event.rawY
                dragging = true
            }
        }
        return false
    }
}