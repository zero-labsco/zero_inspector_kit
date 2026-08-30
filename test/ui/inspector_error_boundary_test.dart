import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  testWidgets('正常时渲染子组件 / renders child when no error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InspectorErrorBoundary(label: 'Demo', child: const Text('hello')),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets(
    '子组件构建异常时显示错误卡片 / shows error card when child throws during build',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InspectorErrorBoundary(
            label: 'Demo',
            child: Builder(builder: (_) => throw Exception('boom')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Demo 出错 / Demo failed'), findsOneWidget);
    },
  );
}
