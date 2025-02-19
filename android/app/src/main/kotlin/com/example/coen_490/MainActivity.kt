package com.example.coen_490

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.coen_490/extract_features"
    private var channel: MethodChannel? = null
    private lateinit var tflite: Interpreter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize TFLite
        initializeTFLite()
        
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            channel = MethodChannel(messenger, CHANNEL)
            channel?.setMethodCallHandler { call, result ->
                if (call.method == "extractFeatures") {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("NULL_PATH", "File path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    
                    GlobalScope.launch(Dispatchers.IO) {
                        val features = analyzeAudio(filePath)
                        withContext(Dispatchers.Main) {
                            result.success(features)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeTFLite() {
        try {
            val modelFile = File(context.filesDir, "heart_murmur.tflite")
            tflite = Interpreter(modelFile)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private suspend fun analyzeAudio(filePath: String): String = withContext(Dispatchers.IO) {
        try {
            val actualFilePath = if (filePath.startsWith("http")) {
                downloadFile(filePath)
            } else {
                filePath
            }

            // Process audio file and extract features
            val audioData = processAudioFile(actualFilePath)
            
            // Run inference
            val outputArray = Array(1) { FloatArray(1) }
            tflite.run(audioData, outputArray)

            // Convert result to JSON
            "{\"result\": ${outputArray[0][0]}}"
        } catch (e: Exception) {
            "{\"error\": \"${e.message?.replace("\"", "\\\"")}\"}"
        }
    }

    private fun processAudioFile(filePath: String): ByteBuffer {
        // Read and process audio file
        val file = File(filePath)
        val buffer = ByteBuffer.allocateDirect(44100 * 4) // Adjust size based on your needs
        buffer.order(ByteOrder.nativeOrder())
        
        // Add your audio processing logic here
        // This is a simplified example
        return buffer
    }

    private suspend fun downloadFile(url: String): String = withContext(Dispatchers.IO) {
        try {
            val tempFile = File.createTempFile("recording", ".wav", context.cacheDir)
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.doInput = true
            connection.connect()
            
            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                throw Exception("HTTP error code: $responseCode")
            }
            
            FileOutputStream(tempFile).use { output ->
                connection.inputStream.use { input ->
                    input.copyTo(output)
                }
            }
            
            tempFile.absolutePath
        } catch (e: Exception) {
            throw Exception("Failed to download file: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::tflite.isInitialized) {
            tflite.close()
        }
    }
}