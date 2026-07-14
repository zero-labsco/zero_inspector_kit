package com.zerolabsco.zero_inspector_kit

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.BufferedReader
import java.io.InputStreamReader

class ZeroInspectorKitPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "zero_inspector_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getNativeLogs" -> {
                val limit = call.argument<Int>("limit") ?: 100
                result.success(getLogcatLogs(limit))
            }
            "startNativeLogListener" -> {
                result.success(null)
            }
            "stopNativeLogListener" -> {
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getLogcatLogs(limit: Int): List<String> {
        val logs = mutableListOf<String>()
        try {
            val process = Runtime.getRuntime().exec("logcat -d -t $limit")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                logs.add(line!!)
            }
            reader.close()
            process.waitFor()
        } catch (e: Exception) {
            logs.add("Error reading logcat: ${e.message}")
        }
        return logs
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}