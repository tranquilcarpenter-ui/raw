package com.example.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Enable high refresh rate (120Hz) support for Android 11+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window?.let { window ->
                // Request highest refresh rate available on the device
                window.attributes?.preferredDisplayModeId = getHighestRefreshRateDisplayModeId()
            }
        }
    }

    private fun getHighestRefreshRateDisplayModeId(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = windowManager.defaultDisplay
            val supportedModes = display.supportedModes
            var highestRefreshRate = 0f
            var selectedModeId = 0

            for (mode in supportedModes) {
                if (mode.refreshRate > highestRefreshRate) {
                    highestRefreshRate = mode.refreshRate
                    selectedModeId = mode.modeId
                }
            }
            return selectedModeId
        }
        return 0
    }
}
