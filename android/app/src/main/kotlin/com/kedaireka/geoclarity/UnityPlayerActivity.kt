package com.kedaireka.geoclarity

import android.app.Activity
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.Window
import android.view.WindowManager
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayer

/**
 * Activity to host Unity AR view
 * Based on Unity's default UnityPlayerActivity
 */
class UnityPlayerActivity : Activity(), IUnityPlayerLifecycleEvents {
    companion object {
        private const val TAG = "UnityPlayerActivity"
    }

    protected var mUnityPlayer: UnityPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        super.onCreate(savedInstanceState)

        // Set fullscreen and keep screen on
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Create Unity Player with lifecycle events
        mUnityPlayer = UnityPlayer(this, this)
        setContentView(mUnityPlayer)
        mUnityPlayer?.requestFocus()
    }

    // Unity lifecycle callbacks
    override fun onUnityPlayerUnloaded() {
        Log.d(TAG, "onUnityPlayerUnloaded called - Unity has unloaded")
        // Don't automatically close - let user press back button
        finish()
    }

    override fun onUnityPlayerQuitted() {
        Log.d(TAG, "onUnityPlayerQuitted called - Unity has quit")
        finish()
    }

    override fun onDestroy() {
        mUnityPlayer?.destroy()
        super.onDestroy()
    }

    override fun onStop() {
        super.onStop()
        mUnityPlayer?.onStop()
    }

    override fun onStart() {
        super.onStart()
        mUnityPlayer?.onStart()
    }

    override fun onPause() {
        super.onPause()
        mUnityPlayer?.onPause()
    }

    override fun onResume() {
        super.onResume()
        mUnityPlayer?.onResume()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        mUnityPlayer?.lowMemory()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level == TRIM_MEMORY_RUNNING_CRITICAL) {
            mUnityPlayer?.lowMemory()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        mUnityPlayer?.configurationChanged(newConfig)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        mUnityPlayer?.windowFocusChanged(hasFocus)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        return if (event.action == KeyEvent.ACTION_MULTIPLE) {
            mUnityPlayer?.injectEvent(event) ?: false
        } else super.dispatchKeyEvent(event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        return mUnityPlayer?.injectEvent(event) ?: super.onKeyUp(keyCode, event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        return mUnityPlayer?.injectEvent(event) ?: super.onKeyDown(keyCode, event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return mUnityPlayer?.injectEvent(event) ?: super.onTouchEvent(event)
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        return mUnityPlayer?.injectEvent(event) ?: super.onGenericMotionEvent(event)
    }
}
