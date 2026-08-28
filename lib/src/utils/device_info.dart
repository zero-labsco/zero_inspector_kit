import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// 设备与环境信息收集 / Device & environment info collection
///
/// 用于一键 Bug 报告：通过 device_info_plus 获取真实设备型号，并聚合 OS、版本、
/// 区域、Dart 运行时等可安全获取的信息，便于 QA 报 bug 时附上环境上下文。
/// Used by the one-click bug report to attach environment context (incl. the real
/// device model) via device_info_plus.
class DeviceInfoUtil {
  DeviceInfoUtil._();

  /// 收集设备/环境信息 / Collect device/environment info
  ///
  /// [model] 通过 device_info_plus 获取真实设备型号（如 "Pixel 8 Pro" /
  /// "iPhone (iPhone16,1)"）；获取失败或在不支持的平台回退到 OS 名称。
  /// 该调用依赖原生插件，故为异步 / Async because device_info_plus uses platform channels.
  static Future<Map<String, String>> collect() async {
    String model;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        model = android.model.isNotEmpty ? android.model : android.product;
      } else if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        final machine = ios.utsname.machine;
        model = machine.isNotEmpty ? '${ios.model} ($machine)' : ios.model;
      } else {
        model = Platform.operatingSystem;
      }
    } catch (_) {
      model = Platform.operatingSystem;
    }

    return <String, String>{
      'model': model,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'dartVersion': Platform.version.split(' ').first,
      'processors': Platform.numberOfProcessors.toString(),
    };
  }

  /// 将收集到的信息渲染为报告文本 / Render collected info to report text
  static String toReportString(Map<String, String> info) {
    final buf = StringBuffer()..writeln('=== Device / Environment ===');
    for (final entry in info.entries) {
      buf.writeln('${entry.key}: ${entry.value}');
    }
    return buf.toString();
  }
}
