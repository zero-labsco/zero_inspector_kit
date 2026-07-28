package com.zerolabsco.zero_inspector_kit

import android.app.ActivityManager
import android.content.Context
import android.os.Debug
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
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "zero_inspector_kit")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
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
            "getProcessMemoryInfo" -> {
                result.success(getProcessMemoryInfo())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /// 获取进程级内存信息 / Get process-level memory info
    ///
    /// 返回 Map 包含以下字段（单位：字节）/ Returns Map with following fields (in bytes):
    /// - dalvikPrivateDirty:   Dalvik/ART 私有脏页 / Dalvik/ART private dirty
    /// - nativePrivateDirty:   Native 私有脏页 / Native private dirty
    /// - otherPrivateDirty:    其他私有脏页 / Other private dirty
    /// - totalPrivateDirty:    总私有脏页 / Total private dirty
    /// - dalvikPss:            Dalvik/ART PSS / Dalvik/ART Proportional Set Size
    /// - nativePss:            Native PSS / Native PSS
    /// - otherPss:             其他 PSS / Other PSS
    /// - totalPss:             总 PSS / Total PSS
    /// - totalSwapPss:         总 Swap PSS / Total Swap PSS
    /// - rss:                  进程总 RSS（来自 /proc/self/status 的 VmRSS 字段）
    ///                        Process total RSS (from VmRSS field in /proc/self/status)
    /// - totalMem:             设备物理内存总量 / Device total physical memory
    /// - availMem:             设备可用物理内存 / Device available physical memory
    /// - threshold:            系统低内存阈值 / System low memory threshold
    /// - lowMemory:            是否处于低内存状态 / Whether in low memory state
    /// - graphics:             Graphics 内存（暂不获取，设为 0）
    ///                        Graphics memory (not fetched, set to 0)
    ///
    /// 注意：Android 公开 API 不提供 RSS 分项字段（dalvikRss/nativeRss 等）
    /// Note: Android public API doesn't provide RSS breakdown fields (dalvikRss/nativeRss etc.)
    /// 进程 RSS 通过读取 /proc/self/status 的 VmRSS 字段获取
    /// Process RSS is obtained by reading VmRSS field from /proc/self/status
    private fun getProcessMemoryInfo(): Map<String, Any> {
        val info = HashMap<String, Any>()

        // 1. 通过 Debug.MemoryInfo 获取 PSS 和 Private Dirty 详细信息
        // 1. Get PSS and Private Dirty details via Debug.MemoryInfo
        try {
            val memoryInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(memoryInfo)

            // Private Dirty 字段（单位 KB，需转换为字节）
            // Private Dirty fields (in KB, need to convert to bytes)
            info["dalvikPrivateDirty"] = memoryInfo.dalvikPrivateDirty * 1024L
            info["nativePrivateDirty"] = memoryInfo.nativePrivateDirty * 1024L
            info["otherPrivateDirty"] = memoryInfo.otherPrivateDirty * 1024L
            info["totalPrivateDirty"] = memoryInfo.getTotalPrivateDirty() * 1024L

            // PSS 字段（单位 KB，需转换为字节）
            // PSS fields (in KB, need to convert to bytes)
            info["dalvikPss"] = memoryInfo.dalvikPss * 1024L
            info["nativePss"] = memoryInfo.nativePss * 1024L
            info["otherPss"] = memoryInfo.otherPss * 1024L
            info["totalPss"] = memoryInfo.getTotalPss() * 1024L

            // Swap PSS
            info["totalSwapPss"] = memoryInfo.getTotalSwappablePss() * 1024L
        } catch (e: Exception) {
            // Debug.MemoryInfo 失败时填 0 / Fill 0 when Debug.MemoryInfo fails
            info["dalvikPrivateDirty"] = 0L
            info["nativePrivateDirty"] = 0L
            info["otherPrivateDirty"] = 0L
            info["totalPrivateDirty"] = 0L
            info["dalvikPss"] = 0L
            info["nativePss"] = 0L
            info["otherPss"] = 0L
            info["totalPss"] = 0L
            info["totalSwapPss"] = 0L
        }

        // 2. RSS 分项字段（Android 公开 API 不提供，填 0 保持 Map 结构一致）
        // 2. RSS breakdown fields (Android public API doesn't provide, fill 0 to keep Map structure consistent)
        info["dalvikRss"] = 0L
        info["nativeRss"] = 0L
        info["otherRss"] = 0L
        info["totalRss"] = 0L

        // 3. 通过读取 /proc/self/status 获取进程 RSS（KB）
        // 3. Get process RSS by reading /proc/self/status (KB)
        // Android 没有 Process.myRss() 公开 API，通过解析 /proc 文件系统获取
        // Android doesn't have Process.myRss() public API,
        // obtain by parsing /proc filesystem
        info["rss"] = readProcessRssFromProcStatus() * 1024L

        // 4. 通过 ActivityManager.MemoryInfo 获取系统内存信息
        // 4. Get system memory info via ActivityManager.MemoryInfo
        try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (activityManager != null) {
                val memInfo = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memInfo)
                info["availMem"] = memInfo.availMem
                info["totalMem"] = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
                    memInfo.totalMem
                } else {
                    0L
                }
                info["threshold"] = memInfo.threshold
                info["lowMemory"] = memInfo.lowMemory
            }
        } catch (e: Exception) {
            // 忽略系统内存信息获取失败 / Ignore system memory info failure
        }

        // 5. Graphics 内存 / Graphics memory
        // Debug.MemoryInfo 未直接暴露 Graphics 字段，需通过 dumpsys meminfo 或反射获取
        // Debug.MemoryInfo doesn't expose Graphics field directly,
        // needs dumpsys meminfo or reflection
        // 此处设为 0，由 Dart 层通过 VM Service 获取（可用时）
        // Set to 0 here, fetched via VM Service on Dart side (if available)
        info["graphics"] = 0L

        return info
    }

    /// 从 /proc/self/status 读取 VmRSS 字段获取进程 RSS（单位 KB）
    /// Read VmRSS field from /proc/self/status to get process RSS (in KB)
    ///
    /// /proc/self/status 文件包含形如 "VmRSS:      12345 kB" 的行
    /// /proc/self/status file contains lines like "VmRSS:      12345 kB"
    /// 这是 Android 上获取进程 RSS 最可靠的方式（无需特殊权限）
    /// This is the most reliable way to get process RSS on Android (no special permission needed)
    private fun readProcessRssFromProcStatus(): Long {
        try {
            val reader = BufferedReader(InputStreamReader(java.io.FileInputStream("/proc/self/status")))
            reader.use { r ->
                var line: String?
                while (r.readLine().also { line = it } != null) {
                    if (line!!.startsWith("VmRSS:")) {
                        // 行格式："VmRSS:     12345 kB"
                        // Line format: "VmRSS:     12345 kB"
                        val parts = line.trim().split("\\s+".toRegex())
                        if (parts.size >= 2) {
                            return parts[1].toLongOrNull() ?: 0L
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // 读取失败返回 0 / Return 0 on read failure
        }
        return 0L
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