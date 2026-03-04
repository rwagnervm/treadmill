package com.example.treadmill.wear

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.tasks.Tasks
import org.json.JSONObject

class MainActivity : Activity(), SensorEventListener {

    private val TAG = "WearCompanion"
    private val MESSAGE_PATH = "/sensor_data"

    private lateinit var sensorManager: SensorManager
    private var heartRateSensor: Sensor? = null
    private var stepSensor: Sensor? = null

    private var currentHeartRate: Int = -1
    private var currentSteps: Int = -1
    private var initialSteps: Int = -1 // Usado para calcular passos relativos da sessão

    private var lastSendTime: Long = 0
    private val SEND_INTERVAL_MS = 1000L // Envia no máximo a cada 1 segundo

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Mantém a tela ligada enquanto treina (opcional)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Criando uma UI puramente em código pra não complicar XML
        val textView = TextView(this).apply {
            text = "Treadmill Wear\nAguardando permissões..."
            textSize = 16f
            textAlignment = TextView.TEXT_ALIGNMENT_CENTER
            setPadding(16, 64, 16, 16)
        }
        setContentView(textView)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        // Verifica permissão ao iniciar
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BODY_SENSORS),
                100
            )
        } else {
            setupSensors()
            (this.window.decorView.rootView as? TextView)?.text = "Treadmill Wear\nTransmitindo..."
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == 100 && grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            setupSensors()
            (this.window.decorView.rootView as? TextView)?.text = "Treadmill Wear\nTransmitindo..."
        }
    }

    private fun setupSensors() {
        heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        heartRateSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        } ?: Log.e(TAG, "Sensor HR não encontrado!")

        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        } ?: Log.e(TAG, "Sensor de Passos não encontrado!")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        when (event.sensor.type) {
            Sensor.TYPE_HEART_RATE -> {
                val hr = event.values[0].toInt()
                if (hr > 0) currentHeartRate = hr
            }
            Sensor.TYPE_STEP_COUNTER -> {
                val totalSteps = event.values[0].toInt()
                if (initialSteps == -1) initialSteps = totalSteps
                currentSteps = totalSteps - initialSteps
            }
        }

        sendDataToPhone()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Ignorar
    }

    private fun sendDataToPhone() {
        val now = System.currentTimeMillis()
        if (now - lastSendTime < SEND_INTERVAL_MS) return // Throttle
        lastSendTime = now

        // Só envia se tiver dado útil
        if (currentHeartRate == -1 && currentSteps == -1) return

        val json = JSONObject().apply {
            if (currentHeartRate != -1) put("heart_rate", currentHeartRate)
            if (currentSteps != -1) put("steps", currentSteps)
        }

        val payload = json.toString().toByteArray(Charsets.UTF_8)

        // Busca todos os NÓS (celulares pareados/conectados na Data Layer)
        Thread {
            try {
                val nodes = Tasks.await(Wearable.getNodeClient(this).connectedNodes)
                for (node in nodes) {
                    Tasks.await(Wearable.getMessageClient(this).sendMessage(node.id, MESSAGE_PATH, payload))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao enviar via Wearable MessageClient: \${e.message}")
            }
        }.start()
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }
}
