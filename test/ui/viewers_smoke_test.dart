import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 测试中用作 InspectorPanel.onClose 的空回调 / No-op callback for InspectorPanel.onClose in tests
void _noop() {}

/// 检查器面板（含 8 个 Tab）的冒烟 + 响应式测试：在常规、窄屏、大字号三种
/// 尺寸下构建，断言不抛异常（Flutter 在 debug 模式下会把布局溢出作为异常抛出，
/// 因此 takeException 能捕获溢出回归——正是历史版本里大量修复的场景）。
/// Smoke + responsive test for the inspector panel (all 8 tabs): builds at
/// normal, narrow, and large-text-scale sizes and asserts no exceptions. Flutter
/// throws on layout overflow in debug mode, so takeException catches the exact
/// overflow regressions fixed across earlier releases.
void main() {
  testWidgets('常规尺寸下无异常 / no exceptions at normal size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: InspectorPanel(onClose: _noop)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏下无溢出 / no overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: InspectorPanel(onClose: _noop)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('大系统字号下无溢出 / no overflow at large text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const InspectorPanel(onClose: _noop),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
