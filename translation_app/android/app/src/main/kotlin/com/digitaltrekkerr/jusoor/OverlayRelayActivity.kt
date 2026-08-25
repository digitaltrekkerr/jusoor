package com.digitaltrekkerr.jusoor

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast

class OverlayRelayActivity : Activity() {

    companion object {
        private const val TAG = "OverlayRelayActivity"
        const val ACTION_CLIPBOARD_RESULT = "com.digitaltrekkerr.jusoor.CLIPBOARD_RESULT"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var pendingRead = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "OverlayRelayActivity created, action=${intent?.getStringExtra("action")}")

        when (intent?.getStringExtra("action")) {
            "read_clipboard" -> {
                readClipboard()
            }
            else -> {
                Log.i(TAG, "Starting overlay service")
                try {
                    val serviceIntent = Intent(
                        applicationContext,
                        TranslationOverlayService::class.java
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    Log.i(TAG, "TranslationOverlayService started successfully")
                    finish()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start overlay service: ${e.message}", e)
                    Toast.makeText(
                        this,
                        "Failed to start overlay service: ${e.message}",
                        Toast.LENGTH_SHORT
                    ).show()
                    finish()
                }
            }
        }
    }

    private fun readClipboard() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            readClipboardNow()
            return
        }

        if (hasWindowFocus()) {
            handler.postDelayed({ readClipboardNow() }, 50)
            return
        }

        pendingRead = true
    }

    private fun readClipboardNow() {
        try {
            val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val text = clipboardManager.primaryClip?.getItemAt(0)?.text?.toString() ?: ""
            sendResult(text)
        } catch (e: Exception) {
            Log.e(TAG, "Clipboard read error", e)
            sendResult("")
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.d(TAG, "onWindowFocusChanged: hasFocus=$hasFocus, pendingRead=$pendingRead")
        if (hasFocus && pendingRead) {
            pendingRead = false
            handler.postDelayed({
                try {
                    val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val text = clipboardManager.primaryClip?.getItemAt(0)?.text?.toString() ?: ""
                    sendResult(text)
                } catch (e: Exception) {
                    Log.e(TAG, "Clipboard read error", e)
                    sendResult("")
                }
            }, 50)
        }
    }

    private fun sendResult(text: String) {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "Clipboard read via Activity: ${text.length} chars")
        }
        val resultIntent = Intent(ACTION_CLIPBOARD_RESULT).apply {
            putExtra("text", text)
            setPackage(packageName)
        }
        sendBroadcast(resultIntent)
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.i(TAG, "OverlayRelayActivity onNewIntent, action=${intent.getStringExtra("action")}")
        when (intent.getStringExtra("action")) {
            "read_clipboard" -> {
                pendingRead = false
                readClipboard()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
        window.decorView.post {
            Log.d(TAG, "Window decor posted - focus should be gained")
        }
    }
}
