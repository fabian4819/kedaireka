package com.kedaireka.geoclarity

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val UNITY_CHANNEL = "com.kedaireka.geoclarity/unity"
    private val CAMERA_PERMISSION_REQUEST_CODE = 1001
    private var unityPlayerManager: UnityPlayerManager? = null
    private var pendingUnityLaunch = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create MethodChannel for Unity communication
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UNITY_CHANNEL)

        // Initialize Unity Player Manager
        unityPlayerManager = UnityPlayerManager(this, channel)
        UnityPlayerManager.setInstance(unityPlayerManager!!)

        // Handle method calls from Flutter
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "launchUnity" -> {
                    // Check camera permission before launching Unity
                    if (checkCameraPermission()) {
                        unityPlayerManager?.launchUnity()
                        result.success(null)
                    } else {
                        // Request permission and launch Unity after granted
                        pendingUnityLaunch = true
                        requestCameraPermission()
                        result.success(null)
                    }
                }
                "closeUnity" -> {
                    unityPlayerManager?.closeUnity()
                    result.success(null)
                }
                "sendToUnity" -> {
                    val gameObject = call.argument<String>("gameObject") ?: ""
                    val method = call.argument<String>("method") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    unityPlayerManager?.sendToUnity(gameObject, method, message)
                    result.success(null)
                }
                "pauseUnity" -> {
                    unityPlayerManager?.pauseUnity()
                    result.success(null)
                }
                "resumeUnity" -> {
                    unityPlayerManager?.resumeUnity()
                    result.success(null)
                }
                "isUnityLoaded" -> {
                    val loaded = unityPlayerManager?.isUnityLoaded() ?: false
                    result.success(loaded)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        unityPlayerManager?.dispose()
        super.onDestroy()
    }

    override fun onPause() {
        super.onPause()
        unityPlayerManager?.pauseUnity()
    }

    override fun onResume() {
        super.onResume()
        unityPlayerManager?.resumeUnity()
    }

    /**
     * Check if camera permission is granted
     */
    private fun checkCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Request camera permission
     */
    private fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE
        )
    }

    /**
     * Handle permission request result
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Permission granted, launch Unity if it was pending
                if (pendingUnityLaunch) {
                    pendingUnityLaunch = false
                    unityPlayerManager?.launchUnity()
                }
            } else {
                // Permission denied
                pendingUnityLaunch = false
                // Optionally show a message to the user
            }
        }
    }
}
