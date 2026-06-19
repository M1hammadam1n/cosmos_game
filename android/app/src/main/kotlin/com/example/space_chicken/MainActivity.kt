package com.space_chicken

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val vibrationChannel = "space_chicken/vibration"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            vibrationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "crash" -> {
                    vibrateCrash()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrateCrash() {
        val vibrator = getDeviceVibrator() ?: return
        if (!vibrator.hasVibrator()) {
            return
        }

        val timings = longArrayOf(0, 180, 70, 260)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val amplitudes = intArrayOf(0, 255, 0, 230)
            vibrator.vibrate(
                VibrationEffect.createWaveform(timings, amplitudes, -1)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
    }

    private fun getDeviceVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }
}
