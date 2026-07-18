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
import 'src/interceptors/route_observer.dart';
import 'src/ui/floating_button.dart';
import 'src/models/log_entry.dart';
import 'src/services/database_provider.dart';
import 'src/services/sqlite_provider.dart';

/// ZeroInspectorKit 插件入口类 / ZeroInspectorKit plugin entry class
/// 提供一键初始化和应用包装功能，实现零侵入集成 / Provides one-click initialization and app wrapping for zero-invasion integration
///
/// 使用方式 / Usage:
/// ```dart
/// void main() {
///   ZeroInspectorKit.init();
///   runApp(ZeroInspectorKit.wrapApp(const MyApp()));
/// }
/// ```
///
/// 以上两行代码即可启用所有检查器功能，无需修改项目其他代码 / The above two lines enable all inspector features without modifying other project code:
/// - 自动捕获所有日志（print/debugPrint/Flutter错误）/ Auto-capture all logs (print/debugPrint/Flutter errors)
/// - 自动拦截所有网络请求（http包/Dio）/ Auto-intercept all network requests (http package/Dio)
/// - 自动扫描SQLite数据库 / Auto-scan SQLite databases
/// - 自动跟踪路由导航 / Auto-track route navigation
/// - 自动显示悬浮检查器按钮 / Auto-show floating inspector button
class ZeroInspectorKit {
  static bool _initialized = false;

  /// 初始化检查器 / Initialize inspector
  /// [enable] 是否启用检查器（默认 true，release模式下自动为 false）/ Whether to enable inspector (default true, auto false in release mode)
  /// [enableLogCapture] 是否启用日志捕获（默认 true）/ Whether to enable log capture (default true)
  /// [enableNetworkCapture] 是否启用网络请求捕获（默认 true）/ Whether to enable network request capture (default true)
  /// [enableDatabaseScan] 是否启用数据库扫描（默认 true）/ Whether to enable database scan (default true)
  /// [enableRouteTracking] 是否启用路由跟踪（默认 true）/ Whether to enable route tracking (default true)
  /// [customButton] 自定义悬浮按钮组件（可选）/ Custom floating button widget (optional)
  /// [onLogCaptured] 日志捕获回调，用于集成第三方日志库（可选）/ Log capture callback for third-party logging library integration (optional)
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

  /// 包装应用并显示悬浮检查器按钮 / Wrap app and show floating inspector button
  /// [app] 应用根组件 / App root widget
  /// [enable] 是否启用检查器（默认 true）/ Whether to enable inspector (default true)
  static Widget wrapApp(Widget app, {bool enable = true}) {
    return _InspectorAppWrapper(app: app, enable: enable);
  }

  /// 使用检查器 Zone 运行应用，确保所有 print() 调用都能被捕获 / Run app with inspector Zone to ensure all print() calls are captured
  /// 此方法会自动调用 init() / This method automatically calls init()
  /// [app] 应用根组件 / App root widget
  /// [enable] 是否启用检查器（默认 true）/ Whether to enable inspector (default true)
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

/// 检查器应用包装器 / Inspector app wrapper
/// 通过 Overlay 自动显示悬浮检查器按钮 / Auto-show floating inspector button via Overlay
class _InspectorAppWrapper extends StatefulWidget {
  /// 应用根组件 / App root widget
  final Widget app;

  /// 是否启用检查器 / Whether to enable inspector
  final bool enable;

  const _InspectorAppWrapper({required this.app, this.enable = true});

  @override
  State<_InspectorAppWrapper> createState() => _InspectorAppWrapperState();
}

class _InspectorAppWrapperState extends State<_InspectorAppWrapper>
    with WidgetsBindingObserver {
  /// Overlay 条目 / Overlay entry
  OverlayEntry? _overlayEntry;

  /// 是否已添加 Overlay / Whether overlay has been added
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

  /// 添加 Overlay / Add overlay
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
      // 忽略 overlay 添加失败的情况 / Ignore overlay add failure
    }
  }

  /// 移除 Overlay / Remove overlay
  void _removeOverlay() {
    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _hasAddedOverlay = false;
    } catch (e) {
      // 忽略 overlay 移除失败的情况 / Ignore overlay remove failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return _wrapAppWithRouteObserver(widget.app);
  }

  /// 包装应用并自动注入路由观察者 / Wrap app and auto-inject route observer
  /// 如果应用根组件是 MaterialApp 或 CupertinoApp，自动添加 InspectorRouteObserver
  /// 对于自定义 Navigator 用户，可以手动添加 InspectorRouteObserver
  /// If app root widget is MaterialApp or CupertinoApp, auto-add InspectorRouteObserver
  /// For custom Navigator users, InspectorRouteObserver can be added manually
  Widget _wrapAppWithRouteObserver(Widget app) {
    if (app is MaterialApp) {
      return MaterialApp(
        key: app.key,
        navigatorKey: app.navigatorKey,
        scaffoldMessengerKey: app.scaffoldMessengerKey,
        navigatorObservers: [
          ...(app.navigatorObservers ?? []),
          InspectorRouteObserver(),
        ],
        initialRoute: app.initialRoute,
        onGenerateInitialRoutes: app.onGenerateInitialRoutes,
        onGenerateRoute: app.onGenerateRoute,
        onUnknownRoute: app.onUnknownRoute,
        routes: app.routes ?? {},
        builder: app.builder,
        title: app.title,
        onGenerateTitle: app.onGenerateTitle,
        color: app.color,
        theme: app.theme,
        darkTheme: app.darkTheme,
        themeMode: app.themeMode,
        locale: app.locale,
        localizationsDelegates: app.localizationsDelegates,
        localeListResolutionCallback: app.localeListResolutionCallback,
        localeResolutionCallback: app.localeResolutionCallback,
        supportedLocales: app.supportedLocales,
        debugShowMaterialGrid: app.debugShowMaterialGrid,
        showPerformanceOverlay: app.showPerformanceOverlay,
        checkerboardRasterCacheImages: app.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: app.checkerboardOffscreenLayers,
        showSemanticsDebugger: app.showSemanticsDebugger,
        debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
        shortcuts: app.shortcuts,
        actions: app.actions,
        restorationScopeId: app.restorationScopeId,
        scrollBehavior: app.scrollBehavior,
        home: app.home,
      );
    }
    return app;
  }
}
