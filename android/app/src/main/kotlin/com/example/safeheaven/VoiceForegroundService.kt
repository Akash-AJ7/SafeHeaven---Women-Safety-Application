package com.example.safeheaven

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.*
import android.speech.*
import android.util.Log
import java.util.*

class VoiceForegroundService : Service() {

    private val CHANNEL_ID = "safeheaven_voice_channel"
    private var speechRecognizer: SpeechRecognizer? = null
    private lateinit var speechIntent: Intent

    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()
        startForeground(1001, buildNotification("Listening for 'Help AJ'"))

        initSpeechRecognizer()
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (e: Exception) {
            Log.e("VOICE", "Destroy error: $e")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ------------------ Notification ------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeHeaven Voice",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("SafeHeaven Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()
    }

    // ------------------ Speech Setup ------------------

    private fun initSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e("VOICE", "Speech recognition not available")
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        speechIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        speechIntent.putExtra(
            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
        )
        speechIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
        speechIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        speechIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)

        // 🔥 IMPORTANT FIX (reduces error 8)
        speechIntent.putExtra(
            RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000
        )
        speechIntent.putExtra(
            RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000
        )

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                Log.e("VOICE", "Error: $error")

                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        restartListening(800)
                    }

                    SpeechRecognizer.ERROR_CLIENT -> {
                        restartListening(1500)
                    }

                    else -> {
                        restartListening(2000)
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                val matches =
                    results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)

                matches?.forEach {
                    handleRecognized(it)
                }

                restartListening(800)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches =
                    partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)

                matches?.forEach {
                    handleRecognized(it)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
    }

    // ------------------ Listening Control ------------------

    private fun startListening() {
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.startListening(speechIntent)

            Log.d("VOICE", "Listening...")

        } catch (e: Exception) {
            Log.e("VOICE", "Start failed: $e")
        }
    }

    private fun restartListening(delay: Long) {
        Handler(mainLooper).postDelayed({
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.cancel()
                speechRecognizer?.startListening(speechIntent)

                Log.d("VOICE", "Restarted listening")

            } catch (e: Exception) {
                Log.e("VOICE", "Restart failed: $e")
            }
        }, delay)
    }

    // ------------------ Keyword Detection ------------------

    private fun handleRecognized(input: String) {
        val text = input.lowercase()
        Log.d("VOICE", "Detected: $text")

        if (text.contains("help aj")) {
            Log.d("VOICE", "🚨 HELP AJ DETECTED")

            val intent = Intent("com.example.safeheaven.VOICE_EVENT")
            intent.putExtra("phrase", "help aj")
            sendBroadcast(intent)

        } else if (text.contains("cancel")) {
            Log.d("VOICE", "❌ CANCEL DETECTED")

            val intent = Intent("com.example.safeheaven.VOICE_EVENT")
            intent.putExtra("phrase", "cancel")
            sendBroadcast(intent)
        }
    }
}