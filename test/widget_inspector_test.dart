import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/widget_tree_node.dart';
import 'package:zero_inspector_kit/src/ui/inspector_panel.dart';

/// Widget 检查器单元测试 / Widget inspector unit tests.
///
/// 验证 buildWidgetTree 能采集业务树、正确排除 InspectorPanel 子树，
/// 并保持深度递增。在 testWidgets 上下文里真实挂载一棵 widget 树。
/// Verifies buildWidgetTree captures the business tree, excludes the
/// InspectorPanel subtree, and keeps depth increasing.
void main() {
  testWidgets(
    'buildWidgetTree captures business widgets and excludes InspectorPanel / 采集业务树并排除检查器自身',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('hi', key: ValueKey('leaf')),
                const InspectorPanel(onClose: _noop),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tree = buildWidgetTree();

      // 根之下应能看到 MaterialApp（业务树起点）
      // The business tree root should be reachable below the root.
      final names = _collectNames(tree);
      expect(names, contains('MaterialApp'));
      expect(names, contains('Scaffold'));
      expect(names, contains('Column'));
      expect(names, contains('Text'));

      // InspectorPanel 不应出现在树中
      // InspectorPanel must not appear in the tree.
      expect(names, isNot(contains('InspectorPanel')));
    },
  );

  testWidgets('depth increases by exactly 1 per level / 深度每层 +1', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: const Center(child: Text('x'))),
      ),
    );
    await tester.pumpAndSettle();
    final tree = buildWidgetTree();
    // 校验任意节点的 children depth 等于父 depth + 1。
    var ok = true;
    void walk(WidgetTreeNode n) {
      for (final c in n.children) {
        if (c.depth != n.depth + 1) ok = false;
        walk(c);
      }
    }

    walk(tree);
    expect(ok, isTrue);
  });
}

List<String> _collectNames(WidgetTreeNode node) {
  final out = [node.name];
  for (final c in node.children) {
    out.addAll(_collectNames(c));
  }
  return out;
}

void _noop() {}
