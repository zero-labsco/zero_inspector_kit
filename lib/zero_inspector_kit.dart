export 'src/ui/floating_button.dart';
export 'src/ui/conditional_inspector.dart';
export 'src/interceptors/log_interceptor.dart';
export 'src/interceptors/http_interceptor.dart';
export 'src/interceptors/dio_interceptor.dart';
export 'src/interceptors/route_observer.dart';
export 'src/services/inspector_service.dart';
export 'src/services/database_service.dart';
export 'src/services/sqlite_provider.dart';
export 'src/services/database_provider.dart';
export 'src/ui/inspector_panel.dart';
export 'src/ui/log_viewer.dart';
export 'src/ui/network_viewer.dart';
export 'src/ui/database_viewer.dart';
export 'src/ui/route_viewer.dart';
export 'src/utils/environment.dart';

export 'zero_inspector_kit_platform_interface.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'src/interceptors/log_interceptor.dart';
import 'src/interceptors/http_interceptor.dart';
import 'src/ui/floating_button.dart';
import 'src/models/log_entry.dart';
import 'src/services/database_provider.dart';
import 'src/services/sqlite_provider.dart';

/// ZeroInspectorKit 插件入口类
/// 提供一键初始化和应用包装功能，实现零侵入集成
///
/// 使用方式：
/// ```dart
/// void main() {
///   ZeroInspectorKit.init();
///   runApp(ZeroInspectorKit.wrapApp(const MyApp()));
/// }
/// ```
///
/// 以上两行代码即可启用所有检查器功能，无需修改项目其他代码：
/// - 自动捕获所有日志（print/debugPrint/Flutter错误）
/// - 自动拦截所有网络请求（http包/Dio）
/// - 自动扫描SQLite数据库
/// - 自动跟踪路由导航
/// - 自动显示悬浮检查器按钮
class ZeroInspectorKit {
  static bool _initialized = false;

  /// 初始化检查器
  /// [enable] 是否启用检查器（默认 true，release模式下自动为 false）
  /// [enableLogCapture] 是否启用日志捕获（默认 true）
  /// [enableNetworkCapture] 是否启用网络请求捕获（默认 true）
  /// [enableDatabaseScan] 是否启用数据库扫描（默认 true）
  /// [enableRouteTracking] 是否启用路由跟踪（默认 true）
  /// [customButton] 自定义悬浮按钮组件（可选）
  /// [onLogCaptured] 日志捕获回调，用于集成第三方日志库（可选）
  static void init({
    bool enable = true,
    bool enableLogCapture = true,
    bool enableNetworkCapture = true,
    bool enableDatabaseScan = true,
    bool enableRouteTracking = true,
    Widget? customButton,
    void Function(LogEntry)? onLogCaptured,
  }) {
    if (_initialized) return;
    _initialized = true;

    if (!enable) return;

    if (enableLogCapture) {
      InspectorLogInterceptor.instance.start();
      if (onLogCaptured != null) {
        InspectorLogInterceptor.instance.onLogCaptured = onLogCaptured;
      }
    }

    if (enableNetworkCapture) {
      InspectorHttpInterceptor.instance.start();
    }

    if (enableDatabaseScan) {
      DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
    }
  }

  static Widget wrapApp(Widget app, {bool enable = true}) {
    return _InspectorAppWrapper(app: app, enable: enable);
  }

  /// 使用检查器 Zone 运行应用，确保所有 print() 调用都能被捕获
  /// 此方法会自动调用 init()
  static void runAppWithInspector(Widget app, {bool enable = true}) {
    init(enable: enable);

    runZonedGuarded(
      () => runApp(wrapApp(app, enable: enable)),
      (error, stackTrace) {
        InspectorLogInterceptor.instance.error(error.toString());
        InspectorLogInterceptor.instance.error(stackTrace.toString());
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line);
          final level = InspectorLogInterceptor.instance.detectLogLevel(
            line.toString(),
          );
          InspectorLogInterceptor.instance.captureLog(line.toString(), level);
        },
      ),
    );
  }
}

class _InspectorAppWrapper extends StatefulWidget {
  final Widget app;
  final bool enable;

  const _InspectorAppWrapper({required this.app, this.enable = true});

  @override
  State<_InspectorAppWrapper> createState() => _InspectorAppWrapperState();
}

class _InspectorAppWrapperState extends State<_InspectorAppWrapper>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  bool _hasAddedOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _addOverlay();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addOverlay();
        }
      });
    }
  }

  void _addOverlay() {
    if (!widget.enable || _overlayEntry != null || _hasAddedOverlay) return;

    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      _overlayEntry = OverlayEntry(
        builder: (context) => const FloatingInspectorButton(),
      );
      overlay.insert(_overlayEntry!);
      _hasAddedOverlay = true;
    } catch (e) {
      // 忽略 overlay 添加失败的情况
    }
  }

  void _removeOverlay() {
    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _hasAddedOverlay = false;
    } catch (e) {
      // 忽略 overlay 移除失败的情况
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.app;
  }
}
