import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // enable: false 时不挂载悬浮检查器按钮（其内部有延时 Timer / 呼吸动画），但穿透
  // 注入逻辑不受影响——_InspectorAppWrapper.initState 会无条件执行
  // _wrapAppWithRouteObserver，路由观察者仍会被注入到内层 MaterialApp。
  // With enable: false the floating inspector button (which has an internal delay
  // Timer / breathing animation) is not mounted, but penetration is unaffected
  // because _InspectorAppWrapper.initState runs _wrapAppWithRouteObserver
  // unconditionally, so the route observer is still injected.
  //
  // 每个测试结束前调用 flush() 卸载 widget 树（触发 OverlayEntry 移除以释放面板资源），
  // 并推进虚拟时钟让 route 观察者的 16ms 节流 Timer（didPush/didPop 经 _notifyThrottled
  // 创建）触发；tearDown 再释放 InspectorService 的节流 Timer，确保无残留 pending Timer。
  // Before each test ends, flush() unmounts the tree (freeing panel resources via
  // OverlayEntry removal) and advances the fake clock so the route observer's 16ms
  // throttling timer (created by didPush/didPop via _notifyThrottled) fires; the
  // tearDown then disposes InspectorService's throttling timer, leaving nothing pending.
  tearDown(() {
    InspectorService.instance.disposeService();
  });

  Widget inspectorApp(Widget app) =>
      ZeroInspectorKit.wrapApp(app, enable: false);

  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('injects observer into a plain MaterialApp', (tester) async {
    await tester.pumpWidget(inspectorApp(const MaterialApp(home: SizedBox())));
    final apps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
    expect(
      apps.any(
        (m) => (m.navigatorObservers ?? []).any(
          (o) => o is InspectorRouteObserver,
        ),
      ),
      isTrue,
    );
    await flush(tester);
  });

  testWidgets('penetrates a StatelessWidget wrapper', (tester) async {
    await tester.pumpWidget(inspectorApp(const _StatelessWrapper()));
    final apps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
    expect(
      apps.any(
        (m) => (m.navigatorObservers ?? []).any(
          (o) => o is InspectorRouteObserver,
        ),
      ),
      isTrue,
    );
    await flush(tester);
  });

  // ignore: avoid_unnecessary_containers
  testWidgets('penetrates a Container wrapper', (tester) async {
    await tester.pumpWidget(inspectorApp(const _ContainerWrapper()));
    final apps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
    expect(
      apps.any(
        (m) => (m.navigatorObservers ?? []).any(
          (o) => o is InspectorRouteObserver,
        ),
      ),
      isTrue,
    );
    await flush(tester);
  });

  testWidgets('penetrates a Center wrapper', (tester) async {
    await tester.pumpWidget(inspectorApp(const _CenterWrapper()));
    final apps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
    expect(
      apps.any(
        (m) => (m.navigatorObservers ?? []).any(
          (o) => o is InspectorRouteObserver,
        ),
      ),
      isTrue,
    );
    await flush(tester);
  });

  testWidgets('penetrates a Padding wrapper', (tester) async {
    await tester.pumpWidget(inspectorApp(const _PaddingWrapper()));
    final apps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
    expect(
      apps.any(
        (m) => (m.navigatorObservers ?? []).any(
          (o) => o is InspectorRouteObserver,
        ),
      ),
      isTrue,
    );
    await flush(tester);
  });

  testWidgets('falls back gracefully for a non-MaterialApp root', (
    tester,
  ) async {
    // 根不是 MaterialApp、且内部也没有 MaterialApp：应回退为外层包裹，不崩溃。
    // Root is not a MaterialApp and has none inside: falls back, no crash.
    await tester.pumpWidget(inspectorApp(const Center(child: Text('hello'))));
    expect(find.byType(MaterialApp), findsWidgets);
    await flush(tester);
  });
}

// ─── 包裹壳：用于验证穿透 / Shell wrappers used to exercise penetration ───

class _StatelessWrapper extends StatelessWidget {
  const _StatelessWrapper();

  @override
  Widget build(BuildContext context) => const MaterialApp(home: SizedBox());
}

class _ContainerWrapper extends StatelessWidget {
  const _ContainerWrapper();

  @override
  Widget build(BuildContext context) {
    // 故意用 Container 包裹以验证穿透 / Deliberately wrap to exercise penetration.
    // ignore: avoid_unnecessary_containers
    return Container(child: const MaterialApp(home: SizedBox()));
  }
}

class _CenterWrapper extends StatelessWidget {
  const _CenterWrapper();

  @override
  Widget build(BuildContext context) =>
      const Center(child: MaterialApp(home: SizedBox()));
}

class _PaddingWrapper extends StatelessWidget {
  const _PaddingWrapper();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(8),
    child: MaterialApp(home: SizedBox()),
  );
}
