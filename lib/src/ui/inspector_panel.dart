import 'package:flutter/material.dart';

import 'theme/inspector_theme.dart';
import '../services/fps_service.dart';
import '../services/memory_inspector_service.dart';
import 'network_viewer.dart';
import 'log_viewer.dart';
import 'error_viewer.dart';
import 'database_viewer.dart';
import 'memory_viewer.dart';
import 'route_viewer.dart';
import 'fps_viewer.dart';
import 'alerts_viewer.dart';
import 'widget_tree_viewer.dart';
import 'widgets/inspector_error_boundary.dart';
import 'inspector_toast.dart';

import '../services/inspector_service.dart';
import '../services/ws_inspector_service.dart';
import '../services/error_service.dart';
import '../services/export_service.dart';
import '../services/persistence_service.dart';
import '../utils/device_info.dart';
import '../utils/formatters.dart';

/// 持久化数据管理面板里的可选动作 / Optional actions in the persisted-data panel
enum _PersistedDataAction { export, clearDisk, clearDiskAndLists }

/// 检查器面板 / Inspector panel
/// 包含网络、日志、数据库、内存、FPS、路由、告警、Widget 八个查看器
/// Contains eight viewers: network, logs, database, memory, FPS, routes, alerts, widgets
class InspectorPanel extends StatefulWidget {
  /// 关闭面板回调 / Close panel callback
  final VoidCallback onClose;

  const InspectorPanel({super.key, required this.onClose});

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel>
    with SingleTickerProviderStateMixin {
  /// 标签页控制器 / Tab controller
  late final TabController _tabController;

  /// 当前选中的 Tab 索引 / Currently selected tab index
  int _currentIndex = 0;

  /// "持久化数据管理"弹层的 OverlayEntry（手动插入 root overlay）。
  /// Persisted-data sheet OverlayEntry (inserted into the root overlay).
  OverlayEntry? _persistedSheetEntry;

  /// 各个标签页的内容 / Contents of each tab
  /// 仅当前激活页会被挂载到组件树（其余只构造、不监听全局 notifier），
  /// 因此每次 notify 只重建当前页；代价是切换标签会重建对应页面、瞬时状态（搜索词/筛选）重置。
  /// Only the active page is mounted into the tree (others are only constructed, not
  /// listening to the global notifier), so each notify rebuilds just the current page.
  /// Trade-off: switching tabs rebuilds the page and resets its transient state.
  late final List<Widget> _pages = [
    InspectorErrorBoundary(
      label: 'Network',
      child: NetworkViewer(key: ValueKey('network')),
    ),
    InspectorErrorBoundary(
      label: 'Logs',
      child: LogViewer(key: ValueKey('logs')),
    ),
    InspectorErrorBoundary(
      label: 'Errors',
      child: ErrorViewer(key: ValueKey('errors')),
    ),
    InspectorErrorBoundary(
      label: 'Database',
      child: DatabaseViewer(key: ValueKey('database')),
    ),
    InspectorErrorBoundary(
      label: 'Memory',
      child: MemoryViewer(key: ValueKey('memory')),
    ),
    InspectorErrorBoundary(
      label: 'FPS',
      child: FpsViewer(key: ValueKey('fps')),
    ),
    InspectorErrorBoundary(
      label: 'Routes',
      child: RouteViewer(key: ValueKey('routes')),
    ),
    InspectorErrorBoundary(
      label: 'Alerts',
      child: AlertsViewer(key: ValueKey('alerts')),
    ),
    InspectorErrorBoundary(
      label: 'Widgets',
      child: WidgetTreeInspector(key: ValueKey('widgets')),
    ),
  ];

  /// 标签页标题 / Tab titles
  final List<String> _titles = const [
    'Network',
    'Logs',
    'Errors',
    'Database',
    'Memory',
    'FPS',
    'Routes',
    'Alerts',
    'Widgets',
  ];

  /// 标签页图标 / Tab icons
  final List<IconData> _icons = const [
    Icons.http_rounded,
    Icons.article_rounded,
    Icons.error_outline_rounded,
    Icons.storage_rounded,
    Icons.memory_rounded,
    Icons.speed_rounded,
    Icons.route_rounded,
    Icons.notifications_active_rounded,
    Icons.visibility_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _titles.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    FpsService.instance.addListener(_onMonitorChanged);
    MemoryInspectorService.instance.addListener(_onMonitorChanged);
    WsInspectorService.instance.addListener(_onMonitorChanged);
    ErrorService.instance.addListener(_onErrorChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    FpsService.instance.removeListener(_onMonitorChanged);
    MemoryInspectorService.instance.removeListener(_onMonitorChanged);
    WsInspectorService.instance.removeListener(_onMonitorChanged);
    ErrorService.instance.removeListener(_onErrorChanged);
    // 面板销毁时收掉可能仍开着的持久化管理弹层，避免 OverlayEntry 泄漏。
    // Clean up a possibly-open persisted sheet when the panel is disposed so no
    // OverlayEntry leaks.
    try {
      _persistedSheetEntry?.remove();
    } catch (_) {}
    _persistedSheetEntry = null;
    _tabController.dispose();
    super.dispose();
  }

  /// 异常聚合变化 → 仅刷新标签栏上的错误红点（错误本身不频繁）/ Error count changed
  void _onErrorChanged() {
    if (mounted) setState(() {});
  }

  /// 监控开关变化 → 刷新头部状态行 / Monitor toggle → refresh header status row
  /// 仅在"已开启监控集合"真正变化时才重建面板，避免内存监控每 500ms 的数据
  /// 刷新（enabled 未变）持续重建整个面板、打断趋势图手势。
  /// Only rebuilds the panel when the set of active monitors actually changes,
  /// so the per-500ms data ticks (enabled unchanged) don't keep rebuilding the
  /// whole panel and interrupt trend-chart gestures.
  String? _lastActiveMonitors;
  void _onMonitorChanged() {
    final current = _activeMonitors.join(',');
    if (current == _lastActiveMonitors) return;
    _lastActiveMonitors = current;
    if (mounted) setState(() {});
  }

  /// 当前已开启的实时监控标签 / Currently active real-time monitor labels
  List<String> get _activeMonitors {
    final list = <String>[];
    if (FpsService.instance.isRunning) list.add('FPS');
    if (MemoryInspectorService.instance.isEnabled) list.add('Memory');
    if (WsInspectorService.instance.isEnabled) list.add('WebSocket');
    return list;
  }

  /// Tab 变化回调 / Tab change callback
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentIndex = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        border: Border.all(color: InspectorColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        // 透明 Material 祖先：面板作为浮层（Overlay）渲染，宿主不一定提供
        // Material，而搜索框(Switch/TextField 等)需要 Material 祖先，否则 debug
        // 模式会抛 "No Material widget found"。用透明 Material 既满足断言又不影响外观。
        // Transparent Material ancestor: the panel is rendered as an Overlay, so the
        // host may not provide a Material. Material widgets (TextField/Switch/…) need
        // one, else debug builds throw "No Material widget found". A transparent
        // Material satisfies the assertion without changing the appearance.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                // 仅挂载当前激活的页面，避免非激活 viewer 也监听全局 notifier 造成叠加重建。
                // Only mount the active page so inactive viewers don't also listen to the
                // global notifier and pile up rebuilds on every notify.
                child: _pages[_currentIndex],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建面板头部 / Build panel header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: InspectorColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.terminal_rounded,
              color: Colors.black87,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zero Inspector Kit',
                  style: TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Developer Tools',
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                _buildStatusRow(),
              ],
            ),
          ),
          IconButton(
            onPressed: _openPersistedDataPanel,
            tooltip:
                'Persisted data (disk): export session archive / clear disk',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.storage_rounded,
                color: InspectorColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shareBugReport(context),
            tooltip: 'Share bug report (device + memory + logs + network)',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bug_report_rounded,
                color: InspectorColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close_rounded,
                color: InspectorColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头部实时监控状态行 / Build header real-time monitor status row
  ///
  /// 显示当前已开启的监控（FPS / Memory），让用户直观知道开启了什么。
  /// Shows currently active monitors (FPS / Memory) so the user knows what's on.
  Widget _buildStatusRow() {
    final active = _activeMonitors;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active.isEmpty
                ? InspectorColors.textSecondary
                : InspectorColors.success,
          ),
        ),
        const SizedBox(width: 6),
        // Expanded + 省略号：窄屏或系统大字号下文本过长时收缩并省略，
        // 避免状态行 Row 在右侧溢出（实测窄屏溢出 12px、大字号溢出 47px）。
        // Expanded + ellipsis: on narrow screens / large system fonts the text can
        // outgrow the row; shrink-and-ellipsize instead of overflowing on the right.
        Expanded(
          child: Text(
            active.isEmpty
                ? 'No live monitor'
                : 'Monitoring: ${active.join(' · ')}',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 一键生成并分享 Bug 报告（设备信息 + 当前内存 + 最近日志 + 最近网络）
  /// One-click generate & share a bug report.
  Future<void> _shareBugReport(BuildContext context) async {
    final messenger = Overlay.of(context, rootOverlay: true);
    final memory = MemoryInspectorService.instance;
    final memoryInfo = <String>[
      '=== Memory (current) ===',
      'Process RSS: ${InspectorFormatters.formatBytes(memory.currentProcessRss)}',
      'Heap Usage: ${InspectorFormatters.formatBytes(memory.currentHeapUsage)}',
      'Native memory: ${memory.isNativeSupported ? 'supported' : 'unsupported'}',
    ].join('\n');

    final deviceInfo = DeviceInfoUtil.toReportString(
      await DeviceInfoUtil.collect(),
    );
    final inspector = InspectorService.instance;

    await ExportService.instance.exportBugReportAndShare(
      deviceInfo: deviceInfo,
      memoryInfo: memoryInfo,
      logs: inspector.logEntries.toList(),
      requests: inspector.networkRequests.toList(),
      maskSensitive: true,
    );

    if (mounted) {
      InspectorToast.showOn(messenger, 'Bug report shared');
    }
  }

  /// 打开"持久化数据管理"：查看磁盘环形缓冲行数、导出完整会话存档，
  /// 或清空磁盘——在导出上一次会话 / 崩溃后手动清空，下一次启动即干净，
  /// 不会被历史回放污染。
  /// Open the "Persisted data" manager: inspect on-disk ring-buffer rows,
  /// export the full session archive, or clear the disk — after exporting the
  /// previous session / crash, clearing lets the next launch start clean.
  ///
  /// 不用 showDialog：本面板是直接插进宿主 Navigator Overlay 的浮层。宿主若
  /// 使用嵌套 Navigator，showDialog 的 route 会被推入内层 Overlay，反而渲染在
  /// 面板之下（正是此前弹窗被主面板挡住的原因）。这里改向 root overlay 手动
  /// 插入一个全新 OverlayEntry —— 与 toast 同一条已被验证能显示在面板之上的
  /// 通道，且后插入的条目永远绘制在面板之上。
  /// Why not showDialog: this panel itself is an overlay layer inserted into the
  /// host Navigator's Overlay. When the host uses a nested Navigator, the dialog
  /// route can land on an inner Overlay and render *under* the panel (the exact
  /// bug reported). Instead we insert a dedicated OverlayEntry into the root
  /// overlay — the same channel the toast already uses (verified to paint above
  /// the panel) — and later-inserted entries always draw above the panel.
  Future<void> _openPersistedDataPanel() async {
    final svc = PersistenceService.instance;
    final enabled = svc.isEnabled;
    var logRows = 0;
    var netRows = 0;
    var errorRows = 0;
    if (enabled) {
      try {
        logRows = (await svc.loadLogs(limit: 1 << 16)).length;
      } catch (_) {}
      try {
        netRows = (await svc.loadNetworkJson(limit: 1 << 16)).length;
      } catch (_) {}
      try {
        errorRows = (await svc.loadErrors(limit: 1 << 16)).length;
      } catch (_) {}
    }
    if (!mounted) return;
    _dismissPersistedSheet();

    // 与 toast 相同的 root overlay / The same root overlay the toast uses.
    final messenger = Overlay.of(context, rootOverlay: true);
    final statusText = enabled
        ? 'logs: $logRows · network: $netRows · errors: $errorRows\n'
              'cap: ${svc.maxRowsPerTable} rows / table · replays on launch'
        : 'Persistence not enabled on this platform (SQLite unavailable)';

    final entry = OverlayEntry(
      builder: (_) => _buildPersistedSheet(
        svc: svc,
        enabled: enabled,
        statusText: statusText,
        messenger: messenger,
      ),
    );
    _persistedSheetEntry = entry;
    messenger.insert(entry);
  }

  /// 构建持久化管理弹层：独立全屏模态，常驻于面板 OverlayEntry 之上。
  /// Build the persisted-data sheet as its own full-screen modal, always above
  /// the panel's own OverlayEntry.
  Widget _buildPersistedSheet({
    required PersistenceService svc,
    required bool enabled,
    required String statusText,
    required OverlayState messenger,
  }) {
    final screen = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 全屏遮罩：点空白关闭 / Full-screen barrier: tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissPersistedSheet,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          SafeArea(
            child: Center(
              child: GestureDetector(
                // 消费点击，避免冒泡到遮罩把弹层误关
                // Consume taps so they never bubble to the dismiss barrier.
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screen.width * 0.8 > 440
                        ? 440
                        : screen.width * 0.8,
                    maxHeight: screen.height * 0.72,
                  ),
                  child: Material(
                    color: InspectorColors.card,
                    elevation: 16,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Persisted data',
                            style: TextStyle(
                              color: InspectorColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Logs / network / errors are stored in a SQLite '
                            'ring buffer and replayed into Logs / Errors on '
                            'launch, surviving crashes and restarts. After '
                            'exporting the session you need, clear the disk so '
                            'the next launch replays nothing and starts clean.',
                            style: TextStyle(
                              color: InspectorColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: InspectorColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: InspectorColors.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: const TextStyle(
                                color: InspectorColors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (enabled) ...[
                            const SizedBox(height: 12),
                            _buildDialogActionItem(
                              icon: Icons.share_rounded,
                              color: InspectorColors.accent,
                              title: 'Export session archive',
                              subtitle:
                                  'JSON with logs · network · errors '
                                  'from disk',
                              onTap: () {
                                _dismissPersistedSheet();
                                _runPersistedAction(
                                  _PersistedDataAction.export,
                                  svc,
                                  messenger,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildDialogActionItem(
                              icon: Icons.delete_forever_rounded,
                              color: InspectorColors.error,
                              title: 'Clear persisted data',
                              subtitle:
                                  'Remove disk rows only — next launch '
                                  'replays nothing',
                              onTap: () {
                                _dismissPersistedSheet();
                                _runPersistedAction(
                                  _PersistedDataAction.clearDisk,
                                  svc,
                                  messenger,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildDialogActionItem(
                              icon: Icons.delete_sweep_rounded,
                              color: InspectorColors.error,
                              title: 'Clear disk + current lists',
                              subtitle:
                                  'Also clear the Logs / Errors / Network '
                                  'lists in view now',
                              onTap: () {
                                _dismissPersistedSheet();
                                _runPersistedAction(
                                  _PersistedDataAction.clearDiskAndLists,
                                  svc,
                                  messenger,
                                );
                              },
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _dismissPersistedSheet,
                              style: TextButton.styleFrom(
                                foregroundColor: InspectorColors.textSecondary,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 收起持久化管理弹层 / Dismiss the persisted-data sheet
  void _dismissPersistedSheet() {
    try {
      _persistedSheetEntry?.remove();
    } catch (_) {}
    _persistedSheetEntry = null;
  }

  /// 执行弹层里选中的动作 / Run the action picked in the sheet
  Future<void> _runPersistedAction(
    _PersistedDataAction action,
    PersistenceService svc,
    OverlayState messenger,
  ) async {
    switch (action) {
      case _PersistedDataAction.export:
        final ok = await svc.exportSessionArchiveAndShare();
        InspectorToast.showOn(
          messenger,
          ok ? 'Session archive exported & shared' : 'Export failed',
        );
        break;
      case _PersistedDataAction.clearDisk:
        await svc.clearAll();
        InspectorToast.showOn(
          messenger,
          'Persisted data cleared — next launch replays nothing',
        );
        break;
      case _PersistedDataAction.clearDiskAndLists:
        await svc.clearAll();
        InspectorService.instance.clearAll();
        ErrorService.instance.clear();
        InspectorToast.showOn(
          messenger,
          'Persisted data and current lists cleared',
        );
        break;
    }
  }

  /// 持久化管理弹层内的可点动作行 / Tappable action row in the manager dialog
  Widget _buildDialogActionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InspectorColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: InspectorColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: InspectorColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: InspectorColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标签栏 / Build tab bar
  Widget _buildTabBar() {
    final errorsIndex = _titles.indexOf('Errors');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        // Errors 标签页索引，用于显示聚合异常数红点。
        // Index of the Errors tab, used to show the aggregated error-count badge.
        // 始终允许横向滚动：8 个带文字的标签页在窄屏或系统大字体下
        // 可能超出可用宽度，可滚动才能保证在所有设备/字号下都不溢出。
        // Always scrollable: with 8 labeled tabs and large system fonts the
        // row can overflow on some devices; scrolling keeps it safe everywhere.
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: InspectorColors.primary,
          borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
        ),
        // 始终使用 tab 宽度作为指示器大小，确保选中指示器填满整个 Tab
        // Always use tab width as indicator size to ensure selection indicator fills the entire tab
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        dividerColor: Colors.transparent,
        labelColor: InspectorColors.textPrimary,
        unselectedLabelColor: InspectorColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        tabs: List.generate(_titles.length, (index) {
          // 不设固定 height：让 tab 高度随图标 + 文字（含系统大字体缩放）自适应，
          // 否则固定 44 会约束内容，在系统大字体下文字被压出底部导致
          // RenderFlex bottom overflow。这样在任意设备/字号下都安全。
          // No fixed height: the tab sizes to its icon + label (including system
          // font scaling). A fixed 44 would clip/overflow the label on large
          // system fonts, so letting it size automatically is safe everywhere.
          final badge = index == errorsIndex
              ? ErrorService.instance.errorCount
              : 0;
          return Tab(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_icons[index], size: 18),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: InspectorColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            text: _titles[index],
          );
        }),
      ),
    );
  }
}
