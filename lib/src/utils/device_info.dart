import 'dart:io';

/// 设备与环境信息收集 / Device & environment info collection
///
/// 用于一键 Bug 报告：聚合运行时可安全获取的 OS、版本、区域、Dart 运行时等信息，
/// 不引入额外依赖，便于 QA 报 bug 时附上环境上下文。
/// Used by the one-click bug report to attach environment context without extra deps.
class DeviceInfoUtil {
  DeviceInfoUtil._();

  /// 收集设备/环境信息 / Collect device/environment info
  static Map<String, String> collect() {
    return <String, String>{
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
