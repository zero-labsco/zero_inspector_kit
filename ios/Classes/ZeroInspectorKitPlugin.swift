import Flutter
import UIKit

public class ZeroInspectorKitPlugin: NSObject, FlutterPlugin {
    private var logs: [String] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zero_inspector_kit", binaryMessenger: registrar.messenger())
        let instance = ZeroInspectorKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getNativeLogs":
            if let limit = call.arguments as? [String: Any], let limitValue = limit["limit"] as? Int {
                result(getConsoleLogs(limit: limitValue))
            } else {
                result(getConsoleLogs(limit: 100))
            }
        case "startNativeLogListener":
            startLogListener()
            result(nil)
        case "stopNativeLogListener":
            stopLogListener()
            result(nil)
        case "getProcessMemoryInfo":
            result(getProcessMemoryInfo())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// 获取进程级内存信息 / Get process-level memory info
    /// 返回 Dictionary 包含以下字段（单位：字节）/ Returns Dictionary with following fields (in bytes):
    /// - rss:                   进程常驻内存 / Process resident memory size
    /// - physicalFootprint:    物理内存占用（最准确的 iOS 内存指标）/ Physical memory footprint (most accurate iOS memory metric)
    /// - internalCompressed:    已压缩内存 / Compressed memory
    /// - internalSize:          内部内存总量 / Total internal memory
    /// - virtualMemory:         虚拟内存 / Virtual memory
    /// - totalMem:              设备物理内存总量 / Device total physical memory
    /// - availMem:              设备可用物理内存 / Device available physical memory
    /// - lowMemory:            是否处于低内存状态 / Whether in low memory state
    private func getProcessMemoryInfo() -> [String: Any] {
        var info: [String: Any] = [:]

        // 1. 通过 mach task_basic_info 获取进程 RSS
        // 1. Get process RSS via mach task_basic_info
        var taskInfo = task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            info["rss"] = Int(taskInfo.resident_size)
            info["virtualMemory"] = Int(taskInfo.virtual_size)
        } else {
            info["rss"] = 0
            info["virtualMemory"] = 0
        }

        // 2. 通过 mach task_vm_info 获取详细 VM 信息（物理内存占用最准确指标）
        // 2. Get detailed VM info via mach task_vm_info (most accurate physical memory metric)
        var vmInfo = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let vmKerr = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        if vmKerr == KERN_SUCCESS {
            // physicalFootprint 是 iOS 上最准确的内存指标（包含压缩内存）
            // physicalFootprint is the most accurate memory metric on iOS (includes compressed memory)
            info["physicalFootprint"] = Int(vmInfo.phys_footprint)
            info["internalCompressed"] = Int(vmInfo.compressed)
            info["internalSize"] = Int(vmInfo.internal)
            // compressed_limit / internal_limit / phys_footprint_lifetime_max 仅存在于 macOS SDK，
            // iOS 上不存在该字段，填 0 保持 Map 结构一致
            // These fields are macOS-only; fill 0 on iOS to keep Map structure consistent
            #if os(macOS)
            info["internalCompressedLimit"] = Int(vmInfo.compressed_limit)
            info["internalSizeLimit"] = Int(vmInfo.internal_limit)
            info["physicalFootprintLifetimeMax"] = Int(vmInfo.phys_footprint_lifetime_max)
            #else
            info["internalCompressedLimit"] = 0
            info["internalSizeLimit"] = 0
            info["physicalFootprintLifetimeMax"] = 0
            #endif
        }

        // 3. 通过 NSProcessInfo 获取设备物理内存
        // 3. Get device physical memory via NSProcessInfo
        info["totalMem"] = Int(ProcessInfo.processInfo.physicalMemory)

        // 4. 通过 NSProcessInfo 获取可用内存（iOS 11+）
        // 4. Get available memory via NSProcessInfo (iOS 11+)
        if #available(iOS 11.0, *) {
            info["availMem"] = Int(ProcessInfo.processInfo.physicalMemory - getUsedMemory())
            info["lowMemory"] = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            info["availMem"] = 0
            info["lowMemory"] = false
        }

        // 5. iOS 没有 Dalvik/Native PSS 分项，统一填 0 以保持 Map 结构一致
        // 5. iOS doesn't have Dalvik/Native PSS breakdown, fill 0 to keep Map structure consistent
        info["dalvikPss"] = 0
        info["nativePss"] = 0
        info["otherPss"] = 0
        info["totalPss"] = 0
        info["dalvikPrivateDirty"] = 0
        info["nativePrivateDirty"] = 0
        info["otherPrivateDirty"] = 0
        info["totalPrivateDirty"] = 0
        info["dalvikRss"] = 0
        info["nativeRss"] = 0
        info["otherRss"] = 0
        info["totalRss"] = 0
        info["totalSwapPss"] = 0
        info["graphics"] = 0

        return info
    }

    /// 获取已使用物理内存（粗略估算）/ Get used physical memory (rough estimate)
    private func getUsedMemory() -> UInt64 {
        var taskInfo = task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return UInt64(taskInfo.resident_size)
        }
        return 0
    }

    private func getConsoleLogs(limit: Int) -> [String] {
        return Array(logs.suffix(limit))
    }

    private func startLogListener() {
        let pipe = Pipe()
        let fileHandle = pipe.fileHandleForReading

        dup2(STDOUT_FILENO, pipe.fileHandleForWriting.fileDescriptor)
        dup2(STDERR_FILENO, pipe.fileHandleForWriting.fileDescriptor)

        fileHandle.readabilityHandler = { [weak self] handle in
            if let data = handle.availableData, let string = String(data: data, encoding: .utf8) {
                self?.logs.append(string.trimmingCharacters(in: .newlines))
            }
        }
    }

    private func stopLogListener() {
        logs.removeAll()
    }
}