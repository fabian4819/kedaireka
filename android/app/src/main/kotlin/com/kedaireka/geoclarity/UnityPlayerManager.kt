package com.kedaireka.geoclarity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import com.unity3d.player.UnityPlayer
import io.flutter.plugin.common.MethodChannel

class UnityPlayerManager(
    private val activity: Activity,
    private val methodChannel: MethodChannel
) {
    private var unityPlayer: UnityPlayer? = null
    private var isUnityLoaded = false
    private var unityContainer: FrameLayout? = null

    /**
     * Launch Unity AR view in a new activity
     */
    fun launchUnity() {
        if (isUnityLoaded) {
            return
        }

        try {
            val intent = Intent(activity, UnityPlayerActivity::class.java)
            activity.startActivity(intent)
            isUnityLoaded = true
        } catch (e: Exception) {
            e.printStackTrace()
            isUnityLoaded = false
        }
    }

    /**
     * Close Unity view
     */
    fun closeUnity() {
        unityPlayer?.quit()
        unityPlayer = null
        isUnityLoaded = false
    }

    /**
     * Send message to Unity GameObject
     */
    fun sendToUnity(gameObject: String, method: String, message: String) {
        try {
            UnityPlayer.UnitySendMessage(gameObject, method, message)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Pause Unity
     */
    fun pauseUnity() {
        unityPlayer?.pause()
    }

    /**
     * Resume Unity
     */
    fun resumeUnity() {
        unityPlayer?.resume()
    }

    /**
     * Check if Unity is loaded
     */
    fun isUnityLoaded(): Boolean {
        return isUnityLoaded
    }

    /**
     * Handle Unity message to Flutter
     */
    fun sendMessageToFlutter(message: String) {
        activity.runOnUiThread {
            methodChannel.invokeMethod("onUnityMessage", message)
        }
    }

    /**
     * Cleanup
     */
    fun dispose() {
        closeUnity()
    }

    companion object {
        // Static reference for Unity to call back to Flutter
        private var instance: UnityPlayerManager? = null

        fun getInstance(): UnityPlayerManager? {
            return instance
        }

        fun setInstance(manager: UnityPlayerManager) {
            instance = manager
        }

        /**
         * Called from Unity C# scripts to send messages to Flutter
         */
        @JvmStatic
        fun sendToFlutter(message: String) {
            instance?.sendMessageToFlutter(message)
        }
    }
}
