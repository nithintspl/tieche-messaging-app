package com.tieche.messaging.tieche_messaging_app

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class QiblaCompassHandler(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
) : EventChannel.StreamHandler, SensorEventListener, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.tieche.messaging/qibla_compass"
        private const val SENSOR_FILTER_ALPHA = 0.8f
        private const val ROTATION_VECTOR_WATCHDOG_MS = 1500L
    }

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var rotationVectorSensor: Sensor? = null
    private var accelerometerSensor: Sensor? = null
    private var magnetometerSensor: Sensor? = null

    /** When true, heading is taken from TYPE_ROTATION_VECTOR; otherwise accel + mag fusion. */
    private var useRotationVector = false

    private var gravity: FloatArray? = null
    private var geomagnetic: FloatArray? = null
    private var hasGravity = false
    private var hasGeomagnetic = false

    private var magnetometerAccuracy: Int = SensorManager.SENSOR_STATUS_UNRELIABLE

    private var latitude = 0.0
    private var longitude = 0.0
    private var altitude = 0.0
    private var hasLocation = false

    private val rotationMatrix = FloatArray(9)
    private val inclinationMatrix = FloatArray(9)
    private val remappedMatrix = FloatArray(9)
    private val orientation = FloatArray(3)

    private var listening = false

    private var rotationVectorEventCount = 0
    private var sawNonZeroRotationVector = false
    private var rotationWatchdogPosted = false

    init {
        EventChannel(messenger, CHANNEL_NAME).setStreamHandler(this)
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(this)
    }

    fun hasCompassSensor(): Boolean {
        rotationVectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        return rotationVectorSensor != null ||
            (accelerometerSensor != null && magnetometerSensor != null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCompassSensor" -> result.success(hasCompassSensor())
            "setLocation" -> {
                latitude = call.argument<Double>("latitude") ?: 0.0
                longitude = call.argument<Double>("longitude") ?: 0.0
                altitude = call.argument<Double>("altitude") ?: 0.0
                hasLocation = true
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startSensors()
    }

    override fun onCancel(arguments: Any?) {
        stopSensors()
        eventSink = null
    }

    fun onResume() {
        if (eventSink != null && !listening) {
            startSensors()
        }
    }

    fun onPause() {
        if (listening) {
            stopSensors()
        }
    }

    private fun startSensors() {
        mainHandler.removeCallbacks(rotationVectorWatchdog)

        if (!hasCompassSensor()) {
            mainHandler.post {
                eventSink?.error(
                    "NO_SENSOR",
                    "No compass sensor available on this device",
                    null,
                )
            }
            return
        }

        rotationVectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

        gravity = null
        geomagnetic = null
        hasGravity = false
        hasGeomagnetic = false
        rotationVectorEventCount = 0
        sawNonZeroRotationVector = false
        rotationWatchdogPosted = false

        val hasAccelMag =
            accelerometerSensor != null && magnetometerSensor != null
        // Use rotation vector when present; 1.5s watchdog falls back to accel + mag fusion.
        useRotationVector = rotationVectorSensor != null

        magnetometerSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        accelerometerSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        if (useRotationVector && rotationVectorSensor != null) {
            sensorManager.registerListener(
                this,
                rotationVectorSensor,
                SensorManager.SENSOR_DELAY_UI,
            )
            scheduleRotationVectorWatchdog()
        } else {
            useRotationVector = false
        }

        if (!hasAccelMag && !useRotationVector) {
            mainHandler.post {
                eventSink?.error(
                    "NO_SENSOR",
                    "No compass sensor available on this device",
                    null,
                )
            }
            return
        }

        listening = true
    }

    private fun scheduleRotationVectorWatchdog() {
        if (rotationWatchdogPosted) return
        rotationWatchdogPosted = true
        mainHandler.postDelayed(rotationVectorWatchdog, ROTATION_VECTOR_WATCHDOG_MS)
    }

    private val rotationVectorWatchdog = Runnable {
        val shouldFallback = rotationVectorEventCount == 0 ||
            (rotationVectorEventCount > 0 && !sawNonZeroRotationVector)
        if (shouldFallback && useRotationVector) {
            useRotationVector = false
            rotationVectorSensor?.let { sensor ->
                sensorManager.unregisterListener(this, sensor)
            }
            // Accel + mag remain registered; fused heading will emit on next events.
            tryFusedHeading()
        }
    }

    private fun stopSensors() {
        mainHandler.removeCallbacks(rotationVectorWatchdog)
        sensorManager.unregisterListener(this)
        listening = false
        rotationWatchdogPosted = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                if (!useRotationVector) return
                rotationVectorEventCount++
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                val azimuth = computeAzimuthDegrees(rotationMatrix)
                if (azimuth > 0.5 && azimuth < 359.5) {
                    sawNonZeroRotationVector = true
                }
                emitHeading(azimuth)
            }
            Sensor.TYPE_ACCELEROMETER -> {
                gravity = lowPassFilter(event.values, gravity)
                hasGravity = true
                if (!useRotationVector) {
                    tryFusedHeading()
                }
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                geomagnetic = lowPassFilter(event.values, geomagnetic)
                hasGeomagnetic = true
                if (!useRotationVector) {
                    tryFusedHeading()
                }
            }
        }
    }

    private fun lowPassFilter(input: FloatArray, output: FloatArray?): FloatArray {
        if (output == null) return input.clone()
        val result = FloatArray(input.size)
        for (i in input.indices) {
            result[i] = output[i] + SENSOR_FILTER_ALPHA * (input[i] - output[i])
        }
        return result
    }

    private fun tryFusedHeading() {
        if (!hasGravity || !hasGeomagnetic) return
        val g = gravity ?: return
        val m = geomagnetic ?: return
        if (!SensorManager.getRotationMatrix(rotationMatrix, inclinationMatrix, g, m)) {
            return
        }
        val azimuth = computeAzimuthDegrees(rotationMatrix)
        emitHeading(azimuth)
    }

    private fun computeAzimuthDegrees(rotMatrix: FloatArray): Double {
        val rotation = currentDisplayRotation()
        val (xAxis, yAxis) = when (rotation) {
            Surface.ROTATION_0 -> SensorManager.AXIS_X to SensorManager.AXIS_Y
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotMatrix, xAxis, yAxis, remappedMatrix)
        SensorManager.getOrientation(remappedMatrix, orientation)
        return (Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0
    }

    private fun emitHeading(azimuthDegrees: Double) {
        var azimuth = azimuthDegrees
        var isTrueNorth = false
        if (hasLocation) {
            val field = GeomagneticField(
                latitude.toFloat(),
                longitude.toFloat(),
                altitude.toFloat(),
                System.currentTimeMillis(),
            )
            azimuth = (azimuth + field.declination + 360.0) % 360.0
            isTrueNorth = true
        }

        val payload = mapOf(
            "heading" to azimuth,
            "accuracy" to magnetometerAccuracy,
            "isTrueNorth" to isTrueNorth,
        )

        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun currentDisplayRotation(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return context.display?.rotation ?: Surface.ROTATION_0
        }
        @Suppress("DEPRECATION")
        val display = (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager)
            .defaultDisplay
        return display?.rotation ?: Surface.ROTATION_0
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD ||
            sensor?.type == Sensor.TYPE_ROTATION_VECTOR
        ) {
            magnetometerAccuracy = accuracy
        }
    }
}