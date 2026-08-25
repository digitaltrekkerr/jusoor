package com.digitaltrekkerr.jusoor

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log

class MediaProjectionRequestActivity : Activity() {
    companion object {
        private const val TAG = "MediaProjectionRequest"
        private const val REQUEST_CODE_MEDIA_PROJECTION = 1001
        const val PROJECTION_RESULT_ACTION = "com.digitaltrekkerr.jusoor.PROJECTION_RESULT"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "Requesting MediaProjection")

        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = manager.createScreenCaptureIntent()
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_CODE_MEDIA_PROJECTION)
    }

    @Deprecated("Deprecated in API 29, required for backwards compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        Log.d(TAG, "onActivityResult: requestCode=$requestCode, resultCode=$resultCode")

        if (requestCode == REQUEST_CODE_MEDIA_PROJECTION) {
            if (resultCode == android.app.Activity.RESULT_OK && data != null) {
                val resultIntent = Intent(PROJECTION_RESULT_ACTION).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    setPackage(packageName)
                }
                sendBroadcast(resultIntent)
                Log.d(TAG, "Broadcast scoped projection result: resultCode=$resultCode")
            } else {
                Log.d(TAG, "MediaProjection permission denied or cancelled")
            }
        }

        finish()
    }
}