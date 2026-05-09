package com.stocker.inventorymanager

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		requestHighRefreshRate()
	}

	private fun requestHighRefreshRate() {
		val params = window.attributes

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			val highestRefreshMode = display?.supportedModes?.maxByOrNull { mode ->
				mode.refreshRate
			}
			if (highestRefreshMode != null) {
				params.preferredDisplayModeId = highestRefreshMode.modeId
				params.preferredRefreshRate = highestRefreshMode.refreshRate
				window.attributes = params
				return
			}
		}

		params.preferredRefreshRate = 120f
		window.attributes = params
	}
}