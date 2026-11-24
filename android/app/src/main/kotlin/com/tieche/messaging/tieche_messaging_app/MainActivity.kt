package com.tieche.messaging.tieche_messaging_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var qiblaCompassHandler: QiblaCompassHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        qiblaCompassHandler = QiblaCompassHandler(this, messenger)
        // Channels: com.tieche.messaging/qibla_compass (EventChannel + MethodChannel)
    }

    override fun onResume() {
        super.onResume()
        qiblaCompassHandler?.onResume()
    }

    override fun onPause() {
        qiblaCompassHandler?.onPause()
        super.onPause()
    }
}