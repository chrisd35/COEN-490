package com.example.coen_490

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.coen_490/extract_features"
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            channel = MethodChannel(messenger, CHANNEL)
            channel?.setMethodCallHandler { call, result ->
                if (call.method == "extractFeatures") {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("NULL_PATH", "File path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    
                    // Use coroutines for background processing
                    GlobalScope.launch(Dispatchers.IO) {
                        val features = extractFeatures(filePath)
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

    private suspend fun extractFeatures(filePath: String): String = withContext(Dispatchers.IO) {
        try {
            // Create directory for extracted files
            val pythonDir = File(context.filesDir, "python_scripts")
            if (!pythonDir.exists()) pythonDir.mkdirs()
            
            // Extract Python script from assets
            val pythonScript = File(pythonDir, "extract_features.py")
            if (!pythonScript.exists()) {
                context.assets.open("backend/ModelTree/extract_features.py").use { input ->
                    pythonScript.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                pythonScript.setExecutable(true)
            }
            
            // Handle remote URL vs local file
            val actualFilePath = if (filePath.startsWith("http")) {
                // Download the file to a temp location
                downloadFile(filePath)
            } else {
                filePath
            }
            
            // Check if Python is available
            if (!isPythonAvailable()) {
                return@withContext "{\"error\": \"Python is not available on this device\"}"
            }
            
            // Execute Python script
            val process = Runtime.getRuntime().exec("python3 ${pythonScript.absolutePath} $actualFilePath")
            
            // Read output
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val errorReader = BufferedReader(InputStreamReader(process.errorStream))
            val output = StringBuilder()
            val error = StringBuilder()
            
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line)
            }
            
            while (errorReader.readLine().also { line = it } != null) {
                error.append(line)
            }
            
            val exitValue = process.waitFor()
            reader.close()
            errorReader.close()
            
            if (exitValue != 0 || error.isNotEmpty()) {
                val errorMsg = if (error.isNotEmpty()) error.toString() else "Unknown error (exit code: $exitValue)"
                return@withContext "{\"error\": \"${errorMsg.replace("\"", "\\\"")}\"}"
            }
            
            if (output.isEmpty()) {
                return@withContext "{\"error\": \"No output from Python script\"}"
            }
            
            output.toString()
        } catch (e: Exception) {
            "{\"error\": \"${e.message?.replace("\"", "\\\"")}\"}"
        }
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
    
    private fun isPythonAvailable(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("python3 --version")
            process.waitFor() == 0
        } catch (e: Exception) {
            try {
                val process = Runtime.getRuntime().exec("python --version")
                process.waitFor() == 0
            } catch (e: Exception) {
                false
            }
        }
    }
}