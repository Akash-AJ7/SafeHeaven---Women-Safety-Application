package com.example.safeheaven

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
	private val CONTROL_CHANNEL = "safeheaven/voice_service"
	private val EVENT_CHANNEL = "safeheaven/voice_events"
	private var receiver: BroadcastReceiver? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

			// Register generated plugins with the FlutterEngine
			try {
				GeneratedPluginRegistrant.registerWith(flutterEngine)
			} catch (e: Exception) {
				// ignore - plugins may already be registered
			}

		val control = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
		val events = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)

		control.setMethodCallHandler { call, result ->
			when (call.method) {
				"startService" -> {
					val intent = Intent(this, VoiceForegroundService::class.java)
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
					result.success(null)
				}
				"stopService" -> {
					stopService(Intent(this, VoiceForegroundService::class.java))
					result.success(null)
				}
				else -> result.notImplemented()
			}
		}

		receiver = object: BroadcastReceiver() {
			override fun onReceive(context: Context?, intent: Intent?) {
				val phrase = intent?.getStringExtra("phrase") ?: return
				events.invokeMethod("onVoiceEvent", phrase)
			}
		}

		val filter = IntentFilter("com.example.safeheaven.VOICE_EVENT")
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			// On Android 13+ specify receiver export flags when registering non-system broadcasts
			registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
		} else {
			registerReceiver(receiver, filter)
		}
	}

	override fun onDestroy() {
		receiver?.let { unregisterReceiver(it) }
		super.onDestroy()
	}
}
