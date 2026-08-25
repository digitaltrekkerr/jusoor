package com.digitaltrekkerr.jusoor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast

class OverlayTileService : TileService() {

    companion object {
        private const val TAG = "OverlayTileService"
        var isOverlayShowing = false
            private set
    }

    private val overlayClosedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_OVERLAY_CLOSED) {
                Log.i(TAG, "Overlay closed broadcast received")
                isOverlayShowing = false
                qsTile?.let { tile ->
                    tile.state = Tile.STATE_INACTIVE
                    tile.updateTile()
                }
            }
        }
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

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter(ACTION_OVERLAY_CLOSED)
        safeRegisterReceiver(overlayClosedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        unregisterReceiver(overlayClosedReceiver)
        super.onDestroy()
    }

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = if (isOverlayShowing) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            tile.label = "Translate"
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        Log.i(TAG, "Tile clicked - attempting to show overlay")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "No overlay permission - requesting")
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivityAndCollapse(intent)
            return
        }

        if (isOverlayShowing) {
            Log.i(TAG, "Overlay already showing, closing it")
            closeOverlay()
            return
        }

        val relayIntent = Intent(this, OverlayRelayActivity::class.java)
        relayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivityAndCollapse(relayIntent)
        Log.i(TAG, "Started OverlayRelayActivity to collapse shade and show overlay")
    }

    private fun closeOverlay() {
        try {
            val serviceIntent = Intent(
                applicationContext,
                TranslationOverlayService::class.java
            )
            serviceIntent.putExtra("stop", true)
            startService(serviceIntent)
            isOverlayShowing = false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close overlay", e)
        }
    }
}