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
        default:
            result(FlutterMethodNotImplemented)
        }
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