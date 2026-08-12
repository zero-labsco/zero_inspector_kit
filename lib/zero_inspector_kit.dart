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
export 'src/services/shared_prefs_provider.dart';
export 'src/services/hive_provider.dart';
export 'src/services/widget_tree_service.dart';
export 'src/services/fps_service.dart';
export 'src/services/export_service.dart';
export 'src/ui/inspector_panel.dart';
export 'src/ui/log_viewer.dart';
export 'src/ui/network_viewer.dart';
export 'src/ui/database_viewer.dart';
export 'src/ui/route_viewer.dart';
export 'src/ui/fps_viewer.dart';
export 'src/utils/environment.dart';
export 'src/utils/inspector_internal_log.dart';
export 'src/utils/inspector_log.dart';
export 'src/utils/memory_leak_tracking.dart';

export 'zero_inspector_kit_platform_interface.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'src/interceptors/log_interceptor.dart';
import 'src/interceptors/http_interceptor.dart';
import 'src/interceptors/route_observer.dart';
import 'src/ui/floating_button.dart';
import 'src/ui/inspector_panel.dart';
import 'src/models/log_entry.dart';
import 'src/services/database_provider.dart';
import 'src/services/sqlite_provider.dart';
import 'src/services/inspector_service.dart';
import 'src/services/shared_prefs_provider.dart';
import 'src/services/hive_provider.dart';
import 'src/services/widget_tree_service.dart';

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
  /// [maxNetworkItems] 网络请求缓存上限（默认 100）/ Network request cache cap (default 100)
  /// [maxLogItems] 日志条目缓存上限（默认 500）/ Log entry cache cap (default 500)
  /// [maxRouteItems] 路由记录缓存上限（默认 200）/ Route record cache cap (default 200)
  /// [maxBodyPreviewBytes] body 预览字节上限，超出截断（默认 32KB）/ Body preview cap, longer bodies truncated (default 32KB)
  static void init({
    bool enable = true,
    bool enableLogCapture = true,
    bool enableNetworkCapture = true,
    bool enableDatabaseScan = true,
    bool enableRouteTracking = true,
    bool enableWidgetInspector = true,
    bool enableNetworkTimeline = true,
    Widget? customButton,
    void Function(LogEntry)? onLogCaptured,
    int? maxNetworkItems,
    int? maxLogItems,
    int? maxRouteItems,
    int? maxBodyPreviewBytes,
  }) {
    if (_initialized) return;
    _initialized = true;

    if (!enable) return;

    // 应用容量与 body 预览配置（全部命名可选，向后兼容）
    // Apply capacity & body preview configuration (all optional, backward compatible)
    InspectorService.instance.configure(
      maxNetworkItems: maxNetworkItems,
      maxLogItems: maxLogItems,
      maxRouteItems: maxRouteItems,
      maxBodyPreviewBytes: maxBodyPreviewBytes,
    );

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

    // Widget 树与网络瀑布图默认开启（快照式，不影响运行时性能，无需开关）。
    // Widget tree & network waterfall are on by default (snapshot-based, no
    // runtime cost, so no user toggle needed).
    if (enableWidgetInspector) {
      WidgetTreeService.instance.isEnabled = true;
    }
    // 预置网络瀑布图偏好（详情页默认展示时间轴）。
    // Pre-seed the timeline preference (detail page shows the timeline by default).
    InspectorService.instance.preferNetworkTimeline = enableNetworkTimeline;
  }

  // ────────────────────────────────────────────────────────────────
  // 自定义数据库源（SP / Hive）一行注册 / One-line custom DB registration
  // ────────────────────────────────────────────────────────────────

  /// 注册 SharedPreferences 作为可查看的"数据库"源 / Register SharedPreferences as a viewable DB source.
  ///
  /// 仅需一行，无需引入任何第三方包依赖 / Just one line, no extra package dependency:
  /// ```dart
  /// final prefs = await SharedPreferences.getInstance();
  /// ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs));
  /// ```
  /// 适配器 [SharedPreferencesAdapter] 随本包导出，零插件依赖 / The
  /// [SharedPreferencesAdapter] adapter ships with this package (zero plugin dep).
  static void registerSharedPrefs(SharedPrefsLike prefs) {
    DatabaseRegistry.instance.registerProvider(
      SharedPrefsProvider(prefs: prefs),
    );
  }

  /// 注册一个或多个 Hive Box 作为可查看的"数据库"源 / Register one or more Hive boxes as viewable DB sources.
  ///
  /// 仅需一行，无需引入 hive 包依赖 / Just one line, no hive dependency:
  /// ```dart
  /// final settings = await Hive.openBox('settings');
  /// final cache = await Hive.openBox('cache');
  /// ZeroInspectorKit.registerHive({
  ///   'settings': HiveBoxAdapter(settings),
  ///   'cache': HiveBoxAdapter(cache),
  /// });
  /// ```
  /// 适配器 [HiveBoxAdapter] 随本包导出，零插件依赖 / The [HiveBoxAdapter]
  /// adapter ships with this package (zero plugin dep).
  static void registerHive(Map<String, HiveBoxLike> boxes) {
    for (final entry in boxes.entries) {
      DatabaseRegistry.instance.registerProvider(
        HiveProvider(box: entry.value, name: entry.key),
      );
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
  static void runAppWithInspector(
    Widget app, {
    bool enable = true,
    bool enableWidgetInspector = true,
    bool enableNetworkTimeline = true,
  }) {
    init(
      enable: enable,
      enableWidgetInspector: enableWidgetInspector,
      enableNetworkTimeline: enableNetworkTimeline,
    );

    // 用 zone 包裹 runApp 以捕获 print() 日志（InspectorLogInterceptor 的
    // debugPrint 覆写 + ZoneSpecification.print 共同生效）。
    // 注意：binding 必须在该 zone 内首次初始化 —— 调用方不要在 runAppWithInspector
    // 之前调用 WidgetsFlutterBinding.ensureInitialized() 或 await 任何会触发
    // platform channel 的插件（如 SharedPreferences），否则 binding 会在外层
    // zone 初始化，与 runApp 所在 zone 不一致，触发 "Zone mismatch" 断言。
    // The binding must be initialized in this same zone — callers must NOT
    // call ensureInitialized() or await plugin/platform-channel calls before
    // runAppWithInspector, or the binding gets initialized in the outer zone
    // and Flutter throws "Zone mismatch".
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
///
/// 通过 ValueNotifier 管理面板状态，OverlayEntry 常驻不销毁，
/// 使用 Offstage 控制显示/隐藏，确保 Tab 状态不丢失。
/// Manages panel state via ValueNotifier, keeps OverlayEntry persistent,
/// uses Offstage to control show/hide, ensuring Tab state is preserved.
class _InspectorAppWrapper extends StatefulWidget {
  /// 应用根组件 / App root widget
  final Widget app;

  /// 是否启用检查器 / Whether to enable inspector
  final bool enable;

  const _InspectorAppWrapper({required this.app, this.enable = true});

  @override
  State<_InspectorAppWrapper> createState() => _InspectorAppWrapperState();
}

class _InspectorAppWrapperState extends State<_InspectorAppWrapper> {
  /// MaterialApp 的 navigatorKey / MaterialApp's navigatorKey
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// 面板打开状态监听 / Panel open state notifier
  final ValueNotifier<bool> _isPanelOpenNotifier = ValueNotifier(false);

  /// 检查器按钮 Overlay 条目 / Inspector button overlay entry
  OverlayEntry? _buttonOverlayEntry;

  /// 面板 Overlay 条目（常驻）/ Panel overlay entry (persistent)
  OverlayEntry? _panelOverlayEntry;

  /// 缓存的面板内容 widget，避免重复创建 / Cached panel content widget
  late final Widget _panelContent;

  /// 缓存的 MaterialApp widget，避免重复创建 / Cached MaterialApp widget
  late final Widget _wrappedApp;

  /// 是否已初始化 / Whether initialized
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _panelContent = _buildPanelContent();
    _wrappedApp = _wrapAppWithRouteObserver(widget.app);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initEntries();
      }
    });
  }

  @override
  void dispose() {
    _removeAllEntries();
    _isPanelOpenNotifier.dispose();
    super.dispose();
  }

  /// 初始化 OverlayEntry / Initialize overlay entries
  void _initEntries() {
    if (_initialized) return;

    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      // Navigator 尚未挂载，下一帧重试 / Navigator not mounted yet, retry next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initEntries();
      });
      return;
    }

    // 直接从 Navigator 获取其内部 Overlay / Get Overlay directly from Navigator
    // 注意：不能用 Overlay.of(context, rootOverlay: true)，因为 Overlay 是 Navigator 的子组件，不是祖先
    // Note: Cannot use Overlay.of(context, rootOverlay: true) because Overlay is a child of Navigator, not an ancestor
    final overlay = navigatorState.overlay;
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initEntries();
      });
      return;
    }

    // 1. 按钮独立 OverlayEntry（直接在 Overlay 的 Stack 中）
    //    这样按钮的 Positioned 子组件能正确使用全屏尺寸
    //    Button in its own OverlayEntry (directly in Overlay's Stack)
    //    so Positioned children can use full-screen dimensions
    //
    //    注意：FloatingInspectorButton 内部没有 InkWell/InkResponse，
    //    不需要 Material 祖先。不能用 Material(color: transparent) 包裹，
    //    因为 RenderMaterial 会占满 Overlay Stack 并在 hitTestSelf 返回 true，
    //    吃掉所有触摸事件，导致下方页面无法点击
    //    Note: FloatingInspectorButton has no InkWell/InkResponse and doesn't
    //    need Material ancestor. Must NOT wrap with Material(color: transparent)
    //    because RenderMaterial fills the Overlay Stack and returns true from
    //    hitTestSelf, consuming all touch events and making the page unclickable
    if (widget.enable && !kReleaseMode) {
      _buttonOverlayEntry = OverlayEntry(
        builder: (context) =>
            FloatingInspectorButton(onPanelToggle: _togglePanel),
      );
      overlay.insert(_buttonOverlayEntry!);
    }

    // 2. 面板独立 OverlayEntry（使用 Offstage 控制显隐）
    //    Panel in its own OverlayEntry (toggled by Offstage)
    //    Material 放在 Offstage 内部，避免关闭面板时仍拦截点击
    //    Material is placed inside Offstage to prevent click interception when closed
    _panelOverlayEntry = OverlayEntry(
      builder: (context) => _buildPersistentPanel(),
    );
    overlay.insert(_panelOverlayEntry!);

    _initialized = true;
  }

  /// 构建常驻面板 / Build persistent panel
  Widget _buildPersistentPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isPanelOpenNotifier,
      child: _panelContent,
      builder: (context, isOpen, child) {
        // Material 必须放在 Offstage 内部！
        // RenderMaterial 只要设置了 color（即使 transparent）就会在 hitTestSelf 返回 true，
        // 导致面板关闭时仍拦截所有点击。放在 Offstage 内，offstage=true 时
        // RenderOffstage.hitTest 直接返回 false，Material 不参与命中测试。
        // Material MUST be inside Offstage!
        // RenderMaterial with any color returns true from hitTestSelf,
        // causing it to intercept all clicks even when panel is closed.
        // By placing Material inside Offstage, when offstage=true,
        // RenderOffstage.hitTest returns false directly, Material never hit-tests.
        return Offstage(
          offstage: !isOpen,
          child: Material(color: Colors.transparent, child: child!),
        );
      },
    );
  }

  /// 构建面板内容 / Build panel content
  Widget _buildPanelContent() {
    return GestureDetector(
      onTap: _togglePanel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 全透明遮罩，不阻挡背景显示
        // Fully transparent overlay
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: InspectorPanel(onClose: _togglePanel),
          ),
        ),
      ),
    );
  }

  /// 切换面板显示状态 / Toggle panel visibility
  void _togglePanel() {
    _isPanelOpenNotifier.value = !_isPanelOpenNotifier.value;
  }

  /// 移除所有 OverlayEntry / Remove all overlay entries
  void _removeAllEntries() {
    try {
      _buttonOverlayEntry?.remove();
      _buttonOverlayEntry = null;
    } catch (_) {}

    try {
      _panelOverlayEntry?.remove();
      _panelOverlayEntry = null;
    } catch (_) {}

    _initialized = false;
  }

  @override
  Widget build(BuildContext context) {
    // 使用缓存的 _wrappedApp，避免每次重建都创建新的 MaterialApp
    // Use cached _wrappedApp to avoid creating new MaterialApp on every rebuild
    return _wrappedApp;
  }

  /// 包装应用并自动注入路由观察者 / Wrap app and auto-inject route observer
  Widget _wrapAppWithRouteObserver(Widget app) {
    if (app is MaterialApp) {
      return MaterialApp(
        key: app.key,
        navigatorKey: app.navigatorKey ?? _navigatorKey,
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

    // 非 MaterialApp 情况，创建包装器
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(data: MediaQuery.of(context), child: child ?? app),
        );
      },
      home: Scaffold(body: app),
    );
  }
}
