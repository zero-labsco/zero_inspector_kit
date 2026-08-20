import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';
import 'package:zero_inspector_kit/src/ui/log_viewer.dart';
import 'package:zero_inspector_kit/src/ui/widgets/widgets.dart';

/// 日志查看器增强单元测试 / Log viewer enhancement tests
///
/// 覆盖自动滚动默认开启、正则搜索、标签过滤、单条复制等新增行为。
/// Covers auto-scroll default, regex search, tag filtering and per-entry copy.
void main() {
  setUp(() {
    InspectorService.instance.clearLogs();
  });

  tearDown(() {
    InspectorService.instance.clearLogs();
  });

  /// 辅助：添加一条日志 / Helper: add a log entry
  LogEntry log(String message, LogLevel level, {String? tag}) {
    final entry = LogEntry(
      id: UniqueKey().toString(),
      level: level,
      message: message,
      timestamp: DateTime.now(),
      tag: tag,
    );
    InspectorService.instance.addLogEntry(entry);
    return entry;
  }

  testWidgets('自动滚动开关默认开启 / auto-scroll toggle defaults on', (tester) async {
    log('hello', LogLevel.info);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    // 默认开启态显示置顶图标（点击后切换为暂停图标）。
    // In the default on-state the top-align icon shows (tapping switches to pause).
    expect(find.byIcon(Icons.vertical_align_top_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);

    // 点击可切换为暂停 / tapping toggles to paused
    await tester.tap(find.byIcon(Icons.vertical_align_top_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('正则搜索可命中 / regex search matches', (tester) async {
    log('User logged in', LogLevel.info, tag: 'auth');
    log('Network timeout', LogLevel.error, tag: 'net');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    // 开启正则模式 / enable regex mode
    await tester.tap(find.byIcon(Icons.code_rounded));
    await tester.pumpAndSettle();

    // 输入正则 / type regex
    final searchField = find.descendant(
      of: find.byType(InspectorSearchField),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, r'logg.*in');
    await tester.pumpAndSettle();

    expect(find.text('User logged in'), findsOneWidget);
    expect(find.text('Network timeout'), findsNothing);
  });

  testWidgets('无效正则不崩溃 / invalid regex does not crash', (tester) async {
    log('plain message', LogLevel.info);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.code_rounded));
    await tester.pumpAndSettle();

    // 非法正则图案 / illegal pattern
    final searchField2 = find.descendant(
      of: find.byType(InspectorSearchField),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField2, r'(');
    await tester.pumpAndSettle();

    // 不抛出异常，且 UI 仍然渲染。
    // No exception thrown and UI still renders.
    expect(find.byType(LogViewer), findsOneWidget);
  });

  testWidgets('标签过滤下拉（视图内面板）/ tag filter dropdown (in-view panel)', (
    tester,
  ) async {
    log('a', LogLevel.info, tag: 'tagA');
    log('b', LogLevel.info, tag: 'tagB');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    // 点击 tag chip 打开视图内下拉面板 / tap the tag chip to open the panel
    await tester.tap(find.byIcon(Icons.local_offer_outlined));
    await tester.pumpAndSettle();
    // 面板内选择 tagB / pick tagB from the panel
    await tester.tap(find.text('tagB').last);
    await tester.pumpAndSettle();

    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('窄屏不溢出 / no overflow on narrow width', (tester) async {
    // 模拟悬浮窗窄屏 / emulate a narrow overlay width
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    log('hello', LogLevel.info);
    log('world', LogLevel.error, tag: 'net');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    // 不抛 RenderFlex 溢出 / no RenderFlex overflow
    expect(tester.takeException(), isNull);
  });

  testWidgets('超长 tag 不溢出 / long tag does not overflow', (tester) async {
    log(
      'msg',
      LogLevel.warning,
      tag: 'veryLongTagLabelThatShouldEllipsisNicely',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('veryLongTagLabelThatShouldEllipsisNicely'),
      findsOneWidget,
    );
  });

  testWidgets('详情页不溢出 / detail page does not overflow', (tester) async {
    // 用中等长度消息，确保列表项渲染出首行文本且详情页内容较长。
    // Moderately long message so the first line renders in the list and the
    // detail page content is tall enough to exercise the overflow fix.
    final longMsg = List.generate(25, (i) => 'line $i: ${'x' * 80}').join('\n');
    log(longMsg, LogLevel.error, tag: 'detailTag');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogViewer())),
    );
    await tester.pumpAndSettle();

    // 进入详情页：点击列表项里的 tag（触发整行 onTap）。
    // Open the detail page by tapping the tag text in the list row.
    await tester.tap(find.text('detailTag').first);
    await tester.pumpAndSettle();

    // 不抛 RenderFlex 溢出 / no RenderFlex overflow
    expect(tester.takeException(), isNull);
    expect(find.text('detailTag'), findsWidgets);
  });
}
