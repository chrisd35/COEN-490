package com.example.coen_490

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.coen_490/extract_features"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "extractFeatures") {
                val filePath = call.argument<String>("filePath")
                val features = extractFeatures(filePath!!)
                result.success(features)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractFeatures(filePath: String): String {
        val process = Runtime.getRuntime().exec("python3 /c:/Users/chris/Downloads/COEN-490/backend/ModelTree/extract_features.py $filePath")
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val output = StringBuilder()
        var line: String?

        while (reader.readLine().also { line = it } != null) {
            output.append(line)
        }

        reader.close()
        process.waitFor()
        return output.toString()
    }
}
