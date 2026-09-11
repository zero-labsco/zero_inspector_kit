import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 模拟 App 里「用页面对象 / 参数类当路由参数」的写法。
/// Stands in for apps passing a page object as the route argument.
class _PageArgs {
  const _PageArgs(this.url);

  final String url;

  @override
  String toString() => 'PageArgs(url: $url)';
}

/// 模拟可 JSON 化的参数对象（freezed / json_serializable 风格）。
/// Stands in for a JSON-encodable argument object.
class _JsonArgs {
  const _JsonArgs(this.id);

  final String id;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    InspectorService.instance.clearRoutes();
    InspectorInternalLog.clear();
  });

  tearDown(() {
    InspectorService.instance.disposeService();
  });

  /// 推入一个带指定参数的路由 / Push a route carrying [arguments].
  Future<void> pushWithArguments(WidgetTester tester, Object? arguments) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[InspectorRouteObserver()],
        home: const Scaffold(body: SizedBox.shrink()),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    unawaited(
      navigatorKey.currentState!.pushNamed<void>(
        '/detail',
        arguments: arguments,
      ),
    );
    await tester.pumpAndSettle();
    // 让路由观察者的节流通知 Timer 触发，避免用例结束时留下 pending Timer。
    // Advance the throttle timer so no pending timer is left behind.
    await tester.pump(const Duration(milliseconds: 20));
  }

  RouteEntry entryFor(String routeName) => InspectorService
      .instance
      .routeEntries
      .firstWhere((entry) => entry.routeName == routeName);

  testWidgets('非 Map 参数不会中断导航 / non-Map arguments do not abort navigation', (
    tester,
  ) async {
    // 修复前：`arguments as Map<String, dynamic>?` 抛 TypeError，异常冒泡进
    // Navigator 并中断这次跳转（还会让 Navigator 卡在 _debugLocked）。
    // Before the fix the cast threw a TypeError that bubbled into Navigator and
    // aborted the navigation (leaving Navigator._debugLocked set).
    await pushWithArguments(
      tester,
      const _PageArgs('https://example.com/privacy'),
    );

    expect(entryFor('/detail').arguments, <String, dynamic>{
      'value': 'PageArgs(url: https://example.com/privacy)',
    });
    expect(InspectorInternalLog.hasErrors, isFalse);
  });

  testWidgets(
    '可 JSON 化的参数对象展开为字段 / JSON-encodable arguments expand into fields',
    (tester) async {
      await pushWithArguments(tester, const _JsonArgs('inv-001'));

      expect(entryFor('/detail').arguments, <String, dynamic>{'id': 'inv-001'});
    },
  );

  testWidgets('Map 参数原样记录 / Map arguments are kept', (tester) async {
    await pushWithArguments(tester, <String, dynamic>{
      'pdfBytes': 'x',
      'addWatermark': true,
    });

    expect(entryFor('/detail').arguments, <String, dynamic>{
      'pdfBytes': 'x',
      'addWatermark': true,
    });
  });

  testWidgets(
    '非 String 键的 Map 会把键转成 String / non-String map keys become String',
    (tester) async {
      await pushWithArguments(tester, <int, String>{1: 'a'});

      expect(entryFor('/detail').arguments, <String, dynamic>{'1': 'a'});
    },
  );
}
